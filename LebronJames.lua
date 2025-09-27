return function()
	-- Get Services
	local RunService = game:GetService("RunService")
	local UserInputService = game:GetService("UserInputService")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local player = Players.LocalPlayer
	
	-- State and helpers
	local activeRole
	local loopConnection
	local winConnection1
	local winConnection2
	local isActive = false
	local restartRole
	local listenForWin
	local runLoop
	local recordCycle
	local getCycleAverage   -- renamed for clarity (10‑cycle only)
	
	-- Handlers (assigned later)
	local handleOnOffClick
	local handleSoloClick
	
	-- Adaptive restart state
	local won = false
	local timeoutElapsed = false
	local p1Won, p2Won = false, false
	
	-- Cycle tracking (10‑cycle buffer only)
	local cycleDurations10 = { [1] = {}, [2] = {} }
	local lastCycleTime    = { [1] = nil, [2] = nil }
	
	-- Drift-proof wait helper
	local function waitSeconds(seconds)
	    local start = os.clock()
	    repeat RunService.Heartbeat:Wait() until os.clock() - start >= seconds
	end
	
	-- RemoteEvent reference (listen-only)
	local SoundEvent = ReplicatedStorage:WaitForChild("Sound", 5)
	if not SoundEvent then
	    warn("❌ 'Sound' RemoteEvent not found in ReplicatedStorage, win detection disabled.")
	end
	
	-- GUI Setup
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "RoleToggleGui"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = player:WaitForChild("PlayerGui")
	
	-- Main Container Frame
	local mainFrame = Instance.new("Frame")
	mainFrame.Size = UDim2.new(0, 450, 0, 300)
	mainFrame.Position = UDim2.new(0.5, -225, 0.5, -150)
	mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	mainFrame.BackgroundTransparency = 0.3
	mainFrame.BorderSizePixel = 0
	mainFrame.Parent = screenGui
	
	-- Make GUI draggable
	local function makeDraggable(gui)
	    local dragging, dragStart, startPos = false, nil, nil
	    gui.InputBegan:Connect(function(input)
	        if input.UserInputType == Enum.UserInputType.MouseButton1
	        or input.UserInputType == Enum.UserInputType.Touch then
	            dragging = true
	            dragStart = input.Position
	            startPos = gui.Position
	        end
	    end)
	    gui.InputEnded:Connect(function(input)
	        if input.UserInputType == Enum.UserInputType.MouseButton1
	        or input.UserInputType == Enum.UserInputType.Touch then
	            dragging = false
	        end
	    end)
	    UserInputService.InputChanged:Connect(function(input)
	        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
	        or input.UserInputType == Enum.UserInputType.Touch) then
	            local delta = input.Position - dragStart
	            gui.Position = UDim2.new(
	                startPos.X.Scale, startPos.X.Offset + delta.X,
	                startPos.Y.Scale, startPos.Y.Offset + delta.Y
	            )
	        end
	    end)
	end
	makeDraggable(mainFrame)
	
	-- Utility to create buttons
	local function createButton(text, position)
	    local button = Instance.new("TextButton")
	    button.Size = UDim2.new(0, 200, 0, 40)
	    button.Position = position
	    button.Text = text
	    button.BackgroundColor3 = Color3.fromRGB(100, 170, 255)
	    button.TextColor3 = Color3.new(1, 1, 1)
	    button.Font = Enum.Font.Arcade
	    button.TextSize = 20
	    button.Active = true
	    button.Selectable = true
	    button.Parent = mainFrame
	    return button
	end
	
	-- GUI Elements
	local soloButton = createButton("SOLO MODE", UDim2.new(0, 20, 0, 60))
	local onOffButton = createButton("OFF", UDim2.new(0, 230, 0, 60))
	
	-- Username Text Box
	local usernameBox = Instance.new("TextBox")
	usernameBox.Size = UDim2.new(0, 200, 0, 40)
	usernameBox.Position = UDim2.new(0, 20, 0, 120)
	usernameBox.PlaceholderText = "Username"
	usernameBox.Font = Enum.Font.Arcade
	usernameBox.TextSize = 18
	usernameBox.TextColor3 = Color3.new(1, 1, 1)
	usernameBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	usernameBox.BorderSizePixel = 0
	usernameBox.Parent = mainFrame
	
	-- Role Text Box
	local roleBox = Instance.new("TextBox")
	roleBox.Size = UDim2.new(0, 200, 0, 40)
	roleBox.Position = UDim2.new(0, 230, 0, 120)
	roleBox.PlaceholderText = "Enter role here!"
	roleBox.Font = Enum.Font.Arcade
	roleBox.TextSize = 18
	roleBox.TextColor3 = Color3.new(1, 1, 1)
	roleBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	roleBox.BorderSizePixel = 0
	roleBox.Parent = mainFrame
	
	-- Title Bar Container
	local titleBar = Instance.new("Frame")
	titleBar.Size = UDim2.new(1, 0, 0, 40)
	titleBar.BackgroundTransparency = 1
	titleBar.Parent = mainFrame
	
	-- Minimise Button
	local minimizeButton = Instance.new("TextButton")
	minimizeButton.Size = UDim2.new(0, 40, 0, 40)
	minimizeButton.AnchorPoint = Vector2.new(1, 0)
	minimizeButton.Position = UDim2.new(1, -5, 0, 0)
	minimizeButton.Text = "-"
	minimizeButton.Font = Enum.Font.Arcade
	minimizeButton.TextSize = 24
	minimizeButton.TextColor3 = Color3.new(1, 1, 1)
	minimizeButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
	minimizeButton.BorderSizePixel = 0
	minimizeButton.Parent = titleBar
	
	-- Title Label
	local padding = 10
	local safeZone = minimizeButton.Size.X.Offset + padding
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -safeZone, 1, 0)
	titleLabel.Position = UDim2.new(0, 0, 0, 0)
	titleLabel.Text = "LeBron James Endurance Script"
	titleLabel.Font = Enum.Font.Arcade
	titleLabel.TextSize = 24
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextXAlignment = Enum.TextXAlignment.Center
	titleLabel.Parent = titleBar
	
	-- Minimise / Maximise Logic
	local minimized = false
	local guiElements = { soloButton, onOffButton, usernameBox, roleBox }
	local originalSize = mainFrame.Size
	local originalPos = mainFrame.Position
	local titleBarHeight = titleBar.Size.Y.Offset
	
	minimizeButton.MouseButton1Click:Connect(function()
	    minimized = not minimized
	    for _, element in ipairs(guiElements) do
	        element.Visible = not minimized
	    end
	    minimizeButton.Text = minimized and "+" or "-"
	    if minimized then
	        mainFrame.Size = UDim2.new(originalSize.X.Scale, originalSize.X.Offset, 0, titleBarHeight + 10)
	        mainFrame.Position = UDim2.new(
	            originalPos.X.Scale,
	            originalPos.X.Offset,
	            originalPos.Y.Scale,
	            originalPos.Y.Offset + (originalSize.Y.Offset - (titleBarHeight + 10)) / 2
	        )
	    else
	        mainFrame.Size = originalSize
	        mainFrame.Position = originalPos
	    end
	end)
	
	-- Force toggle off helper
	local function forceToggleOff()
	    -- Disconnect loop + win listeners
	    if loopConnection and loopConnection.Connected then
	        loopConnection:Disconnect()
	        loopConnection = nil
	    end
	    if winConnection1 and winConnection1.Connected then
	        winConnection1:Disconnect()
	        winConnection1 = nil
	    end
	    if winConnection2 and winConnection2.Connected then
	        winConnection2:Disconnect()
	        winConnection2 = nil
	    end
	
	    -- Reset cycle tracking for the active role
	    if activeRole then
	        cycleDurations10[activeRole] = {}
	        lastCycleTime[activeRole] = nil
	    end
	
	    -- Reset state flags
	    activeRole = nil
	    isActive = false
	    won, timeoutElapsed = false, false
	    p1Won, p2Won = false, false
	
	    -- UI feedback
	    onOffButton.Text = "OFF"
	    onOffButton.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
	
	    print("Script stopped")
	end
	
	-- Button connections
	onOffButton.MouseButton1Click:Connect(function()
	    if handleOnOffClick then
	        handleOnOffClick()
	    else
	        print("ON/OFF clicked but handler not ready yet")
	    end
	end)
	
	soloButton.MouseButton1Click:Connect(function()
	    if handleSoloClick then
	        handleSoloClick()
	    else
	        print("SOLO clicked but handler not ready yet")
	    end
	end)
	
	-- Cold start reset (initialise state once at load)
	won = false
	timeoutElapsed = false
	p1Won, p2Won = false, false
	
	-- Reset cycle tracking for roles 1 and 2
	cycleDurations10 = { [1] = {}, [2] = {} }
	lastCycleTime    = { [1] = nil, [2] = nil }
	
	-- Configs
	local configs = {
	    [1] = { name = "PLAYER 1: DUMMY", teleportDelay = 0.3, deathDelay = 0.5, cycleDelay = 5.8 },
	    [2] = { name = "PLAYER 2: MAIN",  teleportDelay = 0.3, deathDelay = 0.5, cycleDelay = 5.8 },
	    [3] = { name = "SOLO MODE",       teleportDelay = 0.15, deathDelay = 0.05, cycleDelay = 5.55 }
	}
	
	-- Track wins
	local p1Won, p2Won = false, false
	local timeoutGen = 0
	
	-- Rolling buffer (10 cycles)
	local cycleDurations10 = { [1] = {}, [2] = {} }
	local lastCycleTime = { [1] = nil, [2] = nil }
	
	-- Record a completed cycle
	local function recordCycle(role)
	    local now = os.clock()
	    local last = lastCycleTime[role]
	    if last then
	        local duration = now - last
	        table.insert(cycleDurations10[role], duration)
	        if #cycleDurations10[role] > 10 then
	            table.remove(cycleDurations10[role], 1)
	        end
	    end
	    lastCycleTime[role] = now
	end
	
	-- Compute average cycle length
	local function getCycleAverage(role)
	    local tbl = cycleDurations10[role]
	    if not tbl or #tbl == 0 then return nil end
	    local sum = 0
	    for _, v in ipairs(tbl) do sum += v end
	    return sum / #tbl
	end
	
	-- Restart a role after a delay, ensuring the old loop is stopped first
	function restartRole(role, delay)
	    -- Stop any existing loop/listeners
	    if loopConnection and loopConnection.Connected then
	        loopConnection:Disconnect()
	        loopConnection = nil
	    end
	    if winConnection1 and winConnection1.Connected then
	        winConnection1:Disconnect()
	        winConnection1 = nil
	    end
	    if winConnection2 and winConnection2.Connected then
	        winConnection2:Disconnect()
	        winConnection2 = nil
	    end
	
	    isActive = false
	
	    -- Schedule the restart
	    task.delay(delay or 0, function()
	        if activeRole == role then
	            -- Reset cycle tracking and flags
	            cycleDurations10[role] = {}
	            lastCycleTime[role] = nil
	            p1Won, p2Won, timeoutElapsed = false, false, false
	
	            -- Start fresh
	            isActive = true
	            runLoop(role)
	            listenForWin(role)
	
	            print(("🔄 Role %d restarted after %.2fs"):format(role, delay or 0))
	        else
	            print(("ℹ️ Restart for role %d skipped (activeRole changed)"):format(role))
	        end
	    end)
	end
	
	-- Win/timeout detection
	local function listenForWin(role)
	    if role == 3 or not SoundEvent then return end
	
	    if role == 1 then
	        if winConnection1 and winConnection1.Connected then
	            winConnection1:Disconnect()
	        end
	        winConnection1 = SoundEvent.OnClientEvent:Connect(function(action, data)
	            if activeRole ~= 1 then return end
	            if action == "Play" and type(data) == "table" and data.Name == "Win" then
	                p1Won = true
	                print("✅ Win event received for Player 1")
	            end
	        end)
	
	        -- Watchdog: if no win in 15s, restart P1 using avg+10
	        timeoutGen += 1
	        local myGen = timeoutGen
	        task.spawn(function()
	            local startTime = os.clock()
	            while os.clock() - startTime < 15 do
	                if p1Won or activeRole ~= 1 or myGen ~= timeoutGen then return end
	                RunService.Heartbeat:Wait()
	            end
	            if not p1Won and activeRole == 1 and myGen == timeoutGen then
	                timeoutElapsed = true
	                local avg = getCycleAverage(1) or (configs[1] and configs[1].cycleDelay) or 0
	                local delay = avg + 10
	                print(("⚠️ P1 timed out — restarting after %.2fs (avg=%.3f+10)"):format(delay, avg))
	                restartRole(1, delay)
	            end
	        end)
	
	    elseif role == 2 then
	        if winConnection2 and winConnection2.Connected then
	            winConnection2:Disconnect()
	        end
	        winConnection2 = SoundEvent.OnClientEvent:Connect(function(action, data)
	            if activeRole ~= 2 then return end
	            if action == "Play" and type(data) == "table" and data.Name == "Win" then
	                p2Won = true
	                local avg = getCycleAverage(2) or (configs[2] and configs[2].cycleDelay) or 0
	                local delay = avg + 22.5
	                print(("✅ P2 win — restarting after %.2fs (avg=%.3f+22.5)"):format(delay, avg))
	                restartRole(2, delay)
	            end
	        end)
	    end
	end
					
	-- Core loop (os.clock() based, drift-proof) with role-1 watchdog
	function runLoop(role)
	    local points = role == 1 and {
	        workspace.Spar_Ring1.Player1_Button.CFrame,
	        workspace.Spar_Ring4.Player1_Button.CFrame
	    } or role == 2 and {
	        workspace.Spar_Ring1.Player2_Button.CFrame,
	        workspace.Spar_Ring4.Player2_Button.CFrame
	    } or role == 3 and {
	        workspace.Spar_Ring2.Player1_Button.CFrame,
	        workspace.Spar_Ring2.Player2_Button.CFrame,
	        workspace.Spar_Ring3.Player1_Button.CFrame,
	        workspace.Spar_Ring3.Player2_Button.CFrame
	    }
	
	    if not points then
	        warn("runLoop: no points available for role "..tostring(role))
	        return
	    end
	
	    local config = configs[role]
	    if not config then
	        warn(("runLoop: missing config for role %s"):format(tostring(role)))
	        return
	    end
	
	    local index = 1
	    local phase = "teleport"
	    local phaseStart = os.clock()
	
	    if loopConnection and loopConnection.Connected then
	        loopConnection:Disconnect()
	        loopConnection = nil
	    end
	
	    loopConnection = RunService.Heartbeat:Connect(function()
	        if activeRole ~= role or not isActive then
	            if loopConnection and loopConnection.Connected then
	                loopConnection:Disconnect()
	                loopConnection = nil
	            end
	            return
	        end
	
	        local now = os.clock()
	        local elapsed = now - phaseStart
	
	        if phase == "teleport" and elapsed >= config.teleportDelay then
	            phase, phaseStart = "kill", now
	            local char = player.Character or player.CharacterAdded:Wait()
	            local hrp = char:FindFirstChild("HumanoidRootPart")
	            if hrp then
	                hrp.CFrame = points[index]
	            end
	
	        elseif phase == "kill" and elapsed >= config.deathDelay then
	            phase, phaseStart = "respawn", now
	            local char = player.Character
	            if char then
	                pcall(function() char:BreakJoints() end)
	            end
	
	        elseif phase == "respawn" then
	            local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	            if hrp then
	                -- ✅ Record cycle at respawn (drift-proof anchor)
	                if recordCycle then recordCycle(role) end
	                phase, phaseStart = "wait", os.clock()
	            end
	
	        elseif phase == "wait" and elapsed >= config.cycleDelay then
	            phase, phaseStart = "teleport", os.clock()
	            index = index % #points + 1
	        end
	    end)
	
	-- SOLO Fallback: only for role 1
	if role == 1 then
	    task.spawn(function()
	        local checkStart = os.clock()
	        while activeRole == 1 and isActive do
	            local targetName = usernameBox.Text
	            local targetPlayer = targetName ~= "" and Players:FindFirstChild(targetName) or nil
	
	            if not targetPlayer then
	                if (os.clock() - checkStart) >= 10 then
	                    print(("⚠️ %s not found! Switching to solo mode... 🧍"):format(targetName ~= "" and targetName or "Player 2"))
	                    activeRole = nil
	                    if restartRole then
	                        restartRole(3, 1)
	                    else
	                        warn("runLoop: restartRole is nil; cannot switch to solo")
	                    end
	                    return
	                end
	            else
	                -- reset timer if the target player is present again
	                checkStart = os.clock()
	            end
	
	            waitSeconds(1)
	        end
	    end)
	end
			
	-- Reset cycle tracking for a given role
	local function resetCycles(role)
	    cycleDurations10[role] = {}
	    lastCycleTime[role] = nil
	end
	
	-- Role validation and assignment
	local function validateAndAssignRole()
	    local targetName = usernameBox.Text
	    local roleCommand = roleBox.Text
	    local targetPlayer = Players:FindFirstChild(targetName)
	
	    -- Validation
	    if not targetPlayer or (roleCommand ~= "#AFK" and roleCommand ~= "#AFK2") then
	        print("Validation failed")
	        onOffButton.Text = "Validation failed"
	        onOffButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	        task.delay(3, function() forceToggleOff() end)
	        return
	    end
	
	    -- Assign role
	    if roleCommand == "#AFK" then
	        activeRole = 1
	    elseif roleCommand == "#AFK2" then
	        activeRole = 2
	    end
	
	    -- Reset state + cycles
	    p1Won, p2Won, timeoutElapsed = false, false, false
	    resetCycles(activeRole)
	
	    isActive = true
	    onOffButton.Text = "ON"
	    onOffButton.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
	
	    runLoop(activeRole)
	end
	
	-- Assign handlers
	handleOnOffClick = function()
	    if activeRole then
	        forceToggleOff()
	        usernameBox.Text, roleBox.Text = "", ""
	    else
	        validateAndAssignRole()
	    end
	end
	
	handleSoloClick = function()
	    forceToggleOff()
	    waitSeconds(1)
	
	    activeRole, isActive = 3, true
	    p1Won, p2Won, timeoutElapsed = false, false, false
	    resetCycles(3)
	
	    onOffButton.Text = "SOLO mode: ON"
	    onOffButton.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
	
	    runLoop(3)
	end
end
