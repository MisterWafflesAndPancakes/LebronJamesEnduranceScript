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
	
	-- Main container (acts like a window: title bar + pages inside)
	local mainContainer = Instance.new("Frame")
	mainContainer.Size = UDim2.new(0, 450, 0, 300) -- 40 for title + 260 for page
	mainContainer.Position = UDim2.new(0.5, -225, 0.5, -190)
	mainContainer.BackgroundTransparency = 0.6
	mainContainer.BorderSizePixel = 0
	mainContainer.Parent = screenGui
	
	-- Shared Title Bar
	local titleBar = Instance.new("Frame")
	titleBar.Size = UDim2.new(1, 0, 0, 40)
	titleBar.Position = UDim2.new(0, 0, 0, 0)
	titleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	titleBar.BackgroundTransparency = 0.6
	titleBar.BorderSizePixel = 0
	titleBar.Parent = mainContainer
	
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
	
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -50, 1, 0)
	titleLabel.Position = UDim2.new(0, 0, 0, 0)
	titleLabel.Text = "LeBron James Endurance Script"
	titleLabel.Font = Enum.Font.Arcade
	titleLabel.TextSize = 24
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.BackgroundTransparency = 1 -- ✅ no box behind text
	titleLabel.TextXAlignment = Enum.TextXAlignment.Center
	titleLabel.Parent = titleBar
	
	-- Utility to create buttons
	local function createButton(text, position, parent, size)
	    local button = Instance.new("TextButton")
	    button.Size = size or UDim2.new(0, 200, 0, 40)
	    button.Position = position
	    button.Text = text
	    button.BackgroundColor3 = Color3.fromRGB(100, 170, 255)
	    button.TextColor3 = Color3.new(1, 1, 1)
	    button.Font = Enum.Font.Arcade
	    button.TextSize = 20
	    button.Active = true
	    button.Selectable = true
	    button.Parent = parent
	    return button
	end
	
	-- Page 1
	local page1 = Instance.new("Frame")
	page1.Position = UDim2.new(0, 0, 0, 0)   -- ✅ flush under the bar
	page1.Size = UDim2.new(1, 0, 0, 260)     -- keep height so total = 300
	page1.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	page1.BackgroundTransparency = 0.4
	page1.BorderSizePixel = 0
	page1.Parent = mainContainer
	
	local soloButton = createButton("SOLO MODE", UDim2.new(0, 20, 0, 60), page1)
	local onOffButton = createButton("OFF", UDim2.new(0, 230, 0, 60), page1)
	
	local usernameBox = Instance.new("TextBox")
	usernameBox.Size = UDim2.new(0, 200, 0, 40)
	usernameBox.Position = UDim2.new(0, 20, 0, 120)
	usernameBox.PlaceholderText = "Username"
	usernameBox.Font = Enum.Font.Arcade
	usernameBox.TextSize = 18
	usernameBox.TextColor3 = Color3.new(1, 1, 1)
	usernameBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	usernameBox.BorderSizePixel = 0
	usernameBox.Parent = page1
	
	local roleBox = Instance.new("TextBox")
	roleBox.Size = UDim2.new(0, 200, 0, 40)
	roleBox.Position = UDim2.new(0, 230, 0, 120)
	roleBox.PlaceholderText = "Enter role here!"
	roleBox.Font = Enum.Font.Arcade
	roleBox.TextSize = 18
	roleBox.TextColor3 = Color3.new(1, 1, 1)
	roleBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	roleBox.BorderSizePixel = 0
	roleBox.Parent = page1
	
	-- Smaller Next button (bottom right)
	local nextPageButton = createButton("NEXT >", UDim2.new(1, -100, 1, -40), page1, UDim2.new(0, 80, 0, 30))
	
	-- Page 2
	local page2 = Instance.new("Frame")
	page2.Position = UDim2.new(0, 0, 0, 0)
	page2.Size = UDim2.new(1, 0, 0, 260)
	page2.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	page2.BackgroundTransparency = 0.6
	page2.BorderSizePixel = 0
	page2.Visible = false
	page2.Parent = mainContainer
	
	-- Back button pinned bottom-left
	local backButton = createButton("< BACK", UDim2.new(0, 20, 1, -40), page2, UDim2.new(0, 80, 0, 30))
	
	-- Auto Toxic Shake toggle
	local toxicShakeButton = createButton("Auto Toxic Shake: OFF", UDim2.new(0.5, -100, 0, 30), page2)
	toxicShakeButton.TextSize = 16
	local toxicShakeActive = false
	toxicShakeButton.MouseButton1Click:Connect(function()
	    toxicShakeActive = not toxicShakeActive
	    toxicShakeButton.Text = toxicShakeActive and "Auto Toxic Shake: ON" or "Auto Toxic Shake: OFF"
	    if toxicShakeActive then
	        task.spawn(function()
	            while toxicShakeActive do
	                pcall(function()
	                    game.ReplicatedStorage["Drink_Shake"]:InvokeServer("Toxic")
	                end)
	                task.wait(2)
	            end
	        end)
	    end
	end)
	
	-- Anti-AFK button
	local antiAfkButton = createButton("Run Anti-AFK", UDim2.new(0.5, -100, 0, 80), page2)
	antiAfkButton.MouseButton1Click:Connect(function()
	    local VirtualUser = game:service("VirtualUser")
	    game:service("Players").LocalPlayer.Idled:Connect(function()
	        VirtualUser:CaptureController()
	        VirtualUser:ClickButton2(Vector2.new())
	    end)
	    print("✅ Anti-AFK script executed again")
	end)
	
	-- Endurance Checker label
	local enduranceLabel = Instance.new("TextLabel")
	enduranceLabel.Size = UDim2.new(0, 300, 0, 40)
	enduranceLabel.Position = UDim2.new(0.5, -150, 0, 130)
	enduranceLabel.Font = Enum.Font.Arcade
	enduranceLabel.TextSize = 18
	enduranceLabel.TextColor3 = Color3.new(1, 1, 1)
	enduranceLabel.BackgroundTransparency = 1
	enduranceLabel.TextXAlignment = Enum.TextXAlignment.Center
	enduranceLabel.Text = "Endurance: not found"
	enduranceLabel.Parent = page2
	
	-- Toxic Shake Checker label
	local shakeLabel = Instance.new("TextLabel")
	shakeLabel.Size = UDim2.new(0, 300, 0, 40)
	shakeLabel.Position = UDim2.new(0.5, -150, 0, 170)
	shakeLabel.Font = Enum.Font.Arcade
	shakeLabel.TextSize = 18
	shakeLabel.TextColor3 = Color3.new(1, 1, 1)
	shakeLabel.BackgroundTransparency = 1
	shakeLabel.TextXAlignment = Enum.TextXAlignment.Center
	shakeLabel.Text = "Toxic Shakes: not found"
	shakeLabel.Parent = page2
	
	-- Page switching
	local lastPage = "page1"
	nextPageButton.MouseButton1Click:Connect(function()
	    page1.Visible = false
	    page2.Visible = true
	    lastPage = "page2"
	end)
	backButton.MouseButton1Click:Connect(function()
	    page2.Visible = false
	    page1.Visible = true
	    lastPage = "page1"
	end)
	
	-- Minimise / Maximise Logic (affects the whole container)
	local minimized = false
	local originalSize = mainContainer.Size
	local originalPos = mainContainer.Position
	local titleBarHeight = titleBar.Size.Y.Offset
	
	minimizeButton.MouseButton1Click:Connect(function()
	    minimized = not minimized
	    minimizeButton.Text = minimized and "+" or "-"
	
	    if minimized then
	        -- Hide both pages
	        page1.Visible = false
	        page2.Visible = false
	        -- Shrink container to just the title bar
	        mainContainer.Size = UDim2.new(originalSize.X.Scale, originalSize.X.Offset, 0, titleBarHeight + 10)
	        mainContainer.Position = originalPos
	    else
	        -- Restore whichever page was last active
	        if lastPage == "page2" then
	            page2.Visible = true
	        else
	            page1.Visible = true
	        end
	        mainContainer.Size = originalSize
	        mainContainer.Position = originalPos
	    end
	end)
	
	-- Make GUI draggable by the title bar (moves the whole container)
	local UserInputService = game:GetService("UserInputService")
	
	local function makeDraggable(dragHandle, targetFrames)
	    local dragging = false
	    local dragStart, startPositions = nil, {}
	
	    dragHandle.InputBegan:Connect(function(input)
	        if input.UserInputType == Enum.UserInputType.MouseButton1 
	        or input.UserInputType == Enum.UserInputType.Touch then
	            dragging = true
	            dragStart = input.Position
	            startPositions = {}
	            for _, frame in ipairs(targetFrames) do
	                startPositions[frame] = frame.Position
	            end
	        end
	    end)
	
	    dragHandle.InputEnded:Connect(function(input)
	        if input.UserInputType == Enum.UserInputType.MouseButton1 
	        or input.UserInputType == Enum.UserInputType.Touch then
	            dragging = false
	        end
	    end)
	
	    UserInputService.InputChanged:Connect(function(input)
	        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement 
	        or input.UserInputType == Enum.UserInputType.Touch) then
	            local delta = input.Position - dragStart
	            for frame, pos in pairs(startPositions) do
	                frame.Position = UDim2.new(
	                    pos.X.Scale, pos.X.Offset + delta.X,
	                    pos.Y.Scale, pos.Y.Offset + delta.Y
	                )
	            end
	        end
	    end)
	end
	
	-- Apply draggable to both the title bar and the main container (so you can grab anywhere)
	makeDraggable(titleBar, {mainContainer})
	makeDraggable(mainContainer, {mainContainer})
	makeDraggable(page1, {mainContainer})
	makeDraggable(page2, {mainContainer})
		
	-- Live stat updates for Endurance and Toxic Shakes
	task.spawn(function()
	    local playerInfo = workspace:FindFirstChild("Player_Information")
	    local myStats = playerInfo and playerInfo:FindFirstChild(player.Name)
	
	    if not myStats then
	        enduranceLabel.Text = "Endurance: not found"
	        shakeLabel.Text = "Toxic Shakes: not found"
	        return
	    end
	
	    -- Toxic Shakes
	    local drinksFolder = myStats:FindFirstChild("Inventory") and myStats.Inventory:FindFirstChild("Drinks")
	    if drinksFolder then
	        local function updateShakes()
	            local count = 0
	            for _, item in ipairs(drinksFolder:GetChildren()) do
	                if item.Name == "T" then
	                    count += 1
	                end
	            end
	            shakeLabel.Text = "Toxic Shakes: " .. count
	        end
	        updateShakes()
	        drinksFolder.ChildAdded:Connect(updateShakes)
	        drinksFolder.ChildRemoved:Connect(updateShakes)
	    else
	        shakeLabel.Text = "Toxic Shakes: not found"
	    end
	
	    -- Endurance
	    local statsFolder = myStats:FindFirstChild("Stats")
	    local enduranceFolder = statsFolder and statsFolder:FindFirstChild("Endurance")
	    local level = enduranceFolder and enduranceFolder:FindFirstChild("Level")
	    local xp = enduranceFolder and enduranceFolder:FindFirstChild("XP")
	
	    if level and xp then
	        local function updateEndurance()
	            enduranceLabel.Text = string.format("Endurance Lv %d | XP %d", level.Value, xp.Value)
	        end
	        updateEndurance()
	        level:GetPropertyChangedSignal("Value"):Connect(updateEndurance)
	        xp:GetPropertyChangedSignal("Value"):Connect(updateEndurance)
	    else
	        enduranceLabel.Text = "Endurance: not found"
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
	            -- Reset flags (optionally preserve averages by commenting out the next 2 lines)
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
	            if action == "Play" and type(data) == "table" and data.Name == "WinP1" then
	                -- Player 1 is the winner
	                p1Won = true
	                print("✅ Player 1 declared winner")
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
	            if action == "Play" and type(data) == "table" and data.Name == "WinP2" then
	                -- Player 2 is the winner
	                p2Won = true
	                local avg = getCycleAverage(2) or (configs[2] and configs[2].cycleDelay) or 0
	                local delay = avg + 22.5
	                print(("⚠️ Player 2 declared winner — restarting after %.2fs (avg=%.3f+22.5)"):format(delay, avg))
	                restartRole(2, delay)
	            end
	        end)
	    end
	end
					
	-- Core loop (os.clock() based, drift-proof)
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
	            local fallbackTriggered = false  -- debounce
	            while activeRole == 1 and isActive do
	                local targetName = usernameBox.Text
	                local hasName = (targetName ~= nil and targetName ~= "")
	                local targetPlayer = hasName and Players:FindFirstChild(targetName) or nil
	
	                if not targetPlayer and hasName then
	                    if (os.clock() - checkStart) >= 10 and not fallbackTriggered then
	                        fallbackTriggered = true
	                        print(("⚠️ %s not found! Switching to solo mode... 🧍"):format(targetName))
	                        -- guard in case role flipped while waiting
	                        if activeRole == 1 and isActive then
	                            activeRole = nil
	                            if restartRole then
	                                restartRole(3, 1)
	                            else
	                                warn("runLoop: restartRole is nil; cannot switch to solo")
	                            end
	                        end
	                        return
	                    end
	                else
	                    -- reset timer when target is present (continuous-absence logic)
	                    checkStart = os.clock()
	                    fallbackTriggered = false
	                end
	
	                waitSeconds(1)
	            end
	        end)
	    end
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
	
	    -- Start loop and ARM WIN LISTENERS on first start
	    runLoop(activeRole)
	    if listenForWin then
	        listenForWin(activeRole)
	    else
	        warn("validateAndAssignRole: listenForWin not assigned yet")
	    end
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
