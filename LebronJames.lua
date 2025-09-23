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
	local winConnection
	local isActive = false
	local restartRole
	local listenForWin
	local runLoop
	
	-- Handlers (assigned later)
	local handleOnOffClick
	local handleSoloClick
	
	-- Adaptive restart state
	local won = false
	local timeoutElapsed = false
	
	-- Cycle tracking
	local cycleDurations10 = { [1] = {}, [2] = {} }
	local cycleDurations100 = { [1] = {}, [2] = {} }
	local lastCycleTime = { [1] = nil, [2] = nil }
	
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
	
	-- Title Label (auto‑calculate safe zone)
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
		activeRole = nil
		isActive = false
		onOffButton.Text = "OFF"
		onOffButton.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
		if loopConnection and loopConnection.Connected then
			loopConnection:Disconnect()
			loopConnection = nil
		end
		if winConnection and winConnection.Connected then
			winConnection:Disconnect()
			winConnection = nil
		end
		won, timeoutElapsed = false, false
		cycleDurations10[1], cycleDurations10[2] = {}, {}
		cycleDurations100[1], cycleDurations100[2] = {}, {}
		lastCycleTime[1], lastCycleTime[2] = nil, nil
		print("Script stopped")
	end
	
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
	
		-- Reset adaptive state
		won = false
		timeoutElapsed = false
		cycleDurations10[1], cycleDurations10[2] = {}, {}
		cycleDurations100[1], cycleDurations100[2] = {}, {}
		lastCycleTime[1], lastCycleTime[2] = nil, nil
	
	-- Configs
	local configs = {
		[1] = { name = "PLAYER 1: DUMMY", teleportDelay = 0.3, deathDelay = 0.5, cycleDelay = 5.8 },
		[2] = { name = "PLAYER 2: MAIN",  teleportDelay = 0.3, deathDelay = 0.5, cycleDelay = 5.8 },
		[3] = { name = "SOLO MODE",       teleportDelay = 0.15, deathDelay = 0.05, cycleDelay = 5.55 }
	}
	
	-- Central restart manager
	restartRole = function(role, delay)
	    if loopConnection and loopConnection.Connected then
	        loopConnection:Disconnect()
	        loopConnection = nil
	    end
	    if winConnection and winConnection.Connected then
	        winConnection:Disconnect()
	        winConnection = nil
	    end
	    activeRole = nil
	
	    task.spawn(function()
	        local start = os.clock()
	        repeat RunService.Heartbeat:Wait() until os.clock() - start >= delay
	
	        if isActive and activeRole == nil then
	            activeRole = role
	            print("🔄 Restarting as Player", role)
	            runLoop(role)
	            -- runLoop already calls listenForWin for roles 1/2
	        end
	    end)
	end
	
	-- Cycle tracking helpers
	local function recordCycle(role)
	    local now = os.clock()
	    if lastCycleTime[role] then
	        local duration = now - lastCycleTime[role]
	        table.insert(cycleDurations10[role], duration)
	        if #cycleDurations10[role] > 10 then table.remove(cycleDurations10[role], 1) end
	        table.insert(cycleDurations100[role], duration)
	        if #cycleDurations100[role] > 100 then table.remove(cycleDurations100[role], 1) end
	    end
	    lastCycleTime[role] = now
	end
	
	local function getAverage(tbl)
	    local sum = 0
	    for _, d in ipairs(tbl) do sum += d end
	    return (#tbl > 0) and (sum / #tbl) or nil
	end
	
	local function getCycleAverages(role)
	    return getAverage(cycleDurations10[role]), getAverage(cycleDurations100[role])
	end
	
	-- Adaptive restart logic
	local function adaptiveRestart(role, serverTime)
	    if role ~= 1 and role ~= 2 then return end
	
	    local t = tonumber(serverTime)
	    if not t then return end
	
	    local avg10, avg100 = getCycleAverages(role)
	    local cycleLength = avg10 or avg100 or 6.6
	    if cycleLength <= 0 then cycleLength = 6.6 end
	
	    local phase = t % cycleLength
	    local cyclesToSkip = 2
	
	    if role == 2 and won then
	        local baseDelay = (cyclesToSkip * cycleLength) - phase
	        if baseDelay < 0 then baseDelay = baseDelay + cycleLength end
	        local finalDelay = math.max(0, baseDelay - 2.5)
	        print(("P2 restart in %.2fs (cycle=%.3f, adjusted -2.5s)"):format(finalDelay, cycleLength))
	        restartRole(2, finalDelay)
	        recordCycle(2)
	
	    elseif role == 1 and timeoutElapsed then
	        local baseDelay = (cyclesToSkip * cycleLength) - phase + 2.5
	        if baseDelay < 0 then baseDelay = baseDelay + cycleLength end
	        local finalDelay = math.max(0, baseDelay - 15)
	        print(("P1 restart in %.2fs (cycle=%.3f, timeout=15s)"):format(finalDelay, cycleLength))
	        restartRole(1, finalDelay)
	        recordCycle(1)
	    end
	end
	
	-- Persistent pollers (RemoteFunctions)
	local valueFolder = ReplicatedStorage:WaitForChild("Get_Value_From_Workspace")
	
	local function pollRing(ring)
	    task.spawn(function()
	        local lastVal
	        while true do
	            if isActive and (activeRole == 1 or activeRole == 2) then
	                local ok, serverTime = pcall(function()
	                    return ring:InvokeServer()
	                end)
	                if ok then
	                    local t = tonumber(serverTime)
	                    if t and t ~= lastVal then
	                        adaptiveRestart(activeRole, t)
	                        lastVal = t
	                    end
	                else
	                    warn("Polling failed for", ring.Name, serverTime)
	                end
	            else
	                lastVal = nil
	            end
	            RunService.Heartbeat:Wait()
	        end
	    end)
	end
	
	pollRing(valueFolder:WaitForChild("Get_Time_Spar_Ring1"))
	pollRing(valueFolder:WaitForChild("Get_Time_Spar_Ring4"))
	
	-- Win/timeout detection with debouncing
	local timeoutGen = 0
	listenForWin = function(role)
	    if role == 3 or not SoundEvent then return end
	
	    if winConnection and winConnection.Connected then
	        winConnection:Disconnect()
	        winConnection = nil
	    end
	
	    if role == 1 then
	        timeoutGen += 1
	        local myGen = timeoutGen
	        task.spawn(function()
	            local startTime = os.clock()
	            while os.clock() - startTime < 15 do
	                if won or activeRole ~= role or myGen ~= timeoutGen then return end
	                RunService.Heartbeat:Wait()
	            end
	            if not won and activeRole == role and myGen == timeoutGen then
	                timeoutElapsed = true
	                print("⚠️ Player 1 timed out after 15s, waiting for adaptive restart...")
	            end
	        end)
	
	    elseif role == 2 then
	        if SoundEvent:IsA("RemoteEvent") then
	            winConnection = SoundEvent.OnClientEvent:Connect(function(action, data)
	                if activeRole ~= 2 then return end
	                if action == "Play" and data and data.Name == "Win" then
	                    won = true
	                    print("✅ Win event received for Player 2, waiting for adaptive restart...")
	                    if winConnection and winConnection.Connected then
	                        winConnection:Disconnect()
	                        winConnection = nil
	                    end
	                end
	            end)
	        else
	            warn("SoundEvent is not a RemoteEvent; win detection unavailable.")
	        end
	    end
	end
	
	-- Core loop logic
	runLoop = function(role)
	    if not isActive then return end
	
	    local points
	    if role == 1 then
	        points = {
	            workspace.Spar_Ring1.Player1_Button.CFrame,
	            workspace.Spar_Ring4.Player1_Button.CFrame
	        }
	    elseif role == 2 then
	        points = {
	            workspace.Spar_Ring1.Player2_Button.CFrame,
	            workspace.Spar_Ring4.Player2_Button.CFrame
	        }
	    elseif role == 3 then
	        points = {
	            workspace.Spar_Ring2.Player1_Button.CFrame,
	            workspace.Spar_Ring2.Player2_Button.CFrame,
	            workspace.Spar_Ring3.Player1_Button.CFrame,
	            workspace.Spar_Ring3.Player2_Button.CFrame
	        }
	    end
	    if not points then return end
	
	    won, timeoutElapsed = false, false
	    cycleDurations10[role] = {}
	    cycleDurations100[role] = {}
	    lastCycleTime[role] = nil
	
	    if role == 1 or role == 2 then
	        listenForWin(role)
	    end
	
	    local config = configs[role]
	    local index, phase, phaseStart = 1, "teleport", os.clock()
	
	    if loopConnection and loopConnection.Connected then
	        loopConnection:Disconnect()
	        loopConnection = nil
	    end
	
	    loopConnection = RunService.Heartbeat:Connect(function()
	        if activeRole ~= role or not isActive then
	            loopConnection:Disconnect()
	            loopConnection = nil
	            return
	        end
	
	        local now, elapsed = os.clock(), os.clock() - phaseStart
	
	        if phase == "teleport" and elapsed >= config.teleportDelay then
	            phase, phaseStart = "kill", now
	            local char = player.Character
	            if char then
	                local hrp = char:FindFirstChild("HumanoidRootPart")
	                if hrp and points[index] then
	                    hrp.CFrame = points[index]
	                end
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
	                phase, phaseStart = "wait", os.clock()
	            end
	
	        elseif phase == "wait" and elapsed >= config.cycleDelay then
	            -- ✅ Cycle complete, record it
	            recordCycle(role)
	
	            -- Move to next cycle
	            phase, phaseStart = "teleport", os.clock()
	            index = index % #points + 1
	        end
	    end)
	
	    -- Solo fallback logic (unchanged)
	    if role == 1 then
	        task.spawn(function()
	            local checkStart = os.clock()
	            while activeRole == 1 and isActive do
	                local targetPlayer = Players:FindFirstChild(usernameBox.Text)
	                if not targetPlayer and os.clock() - checkStart >= 10 then
	                    print("Player 2 cannot be found! Switching to solo mode now... 🧍")
	                    activeRole = nil
	                    restartRole(3, 1)
	                    return
	                elseif targetPlayer then
	                    checkStart = os.clock()
	                end
	                waitSeconds(1)
	            end
	        end)
	    end
	end
	
	-- Role validation and assignment
	local function validateAndAssignRole()
		local targetName = usernameBox.Text
		local roleCommand = roleBox.Text
		local targetPlayer = Players:FindFirstChild(targetName)
	
		if not targetPlayer or (roleCommand ~= "#AFK" and roleCommand ~= "#AFK2") then
			print("Validation failed")
			onOffButton.Text = "Validation failed"
			onOffButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
			task.delay(3, function() forceToggleOff() end)
			return
		end
	
		if roleCommand == "#AFK" then
			activeRole = 1
		elseif roleCommand == "#AFK2" then
			activeRole = 2
		end
	
		won, timeoutElapsed = false, false
		cycleDurations10[activeRole] = {}
		cycleDurations100[activeRole] = {}
		lastCycleTime[activeRole] = nil
	
		isActive = true
		onOffButton.Text = "ON"
		onOffButton.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
		runLoop(activeRole)
	end
	
	-- Assign handlers (instead of direct connections)
	handleOnOffClick = function()
		if activeRole then
			-- Turning OFF
			forceToggleOff()
			usernameBox.Text, roleBox.Text = "", ""
			won, timeoutElapsed = false, false
			if cycleDurations10[activeRole] then
				cycleDurations10[activeRole] = {}
				cycleDurations100[activeRole] = {}
				lastCycleTime[activeRole] = nil
			end
			if loopConnection and loopConnection.Connected then
				loopConnection:Disconnect()
				loopConnection = nil
			end
			activeRole, isActive = nil, false
			onOffButton.Text = "OFF"
			onOffButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
		else
			-- Turning ON
			validateAndAssignRole()
		end
	end
	
	handleSoloClick = function()
		forceToggleOff()
		waitSeconds(1)
		activeRole, isActive = 3, true
		won, timeoutElapsed = false, false
		cycleDurations10[3], cycleDurations100[3], lastCycleTime[3] = {}, {}, nil
		onOffButton.Text = "SOLO mode: ON"
		onOffButton.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
		runLoop(3)
	end
end
