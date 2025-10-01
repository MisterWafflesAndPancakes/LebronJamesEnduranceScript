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
	local recordCycle
	local getCycleAverage   -- renamed for clarity (10‑cycle only)
	
	-- Handlers (assigned later)
	local handleOnOffClick
	local handleSoloClick
	
	-- Adaptive restart state
	local won = false          -- unified win flag (used for both roles)
	local timeoutElapsed = false
	
	-- Cycle tracking (10‑cycle buffer only)
	local cycleDurations10 = { [1] = {}, [2] = {} }
	local lastCycleTime    = { [1] = nil, [2] = nil }
	
	-- Drift‑proof wait helper
	local function waitSeconds(seconds)
		local start = os.clock()
		repeat RunService.Heartbeat:Wait() until os.clock() - start >= seconds
	end
	
	-- RemoteEvent reference (listen‑only)
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
	mainContainer.BackgroundColor3 = Color3.fromRGB(30, 30, 30) -- dark gray
	mainContainer.BackgroundTransparency = 0.3                  -- semi-transparent
	mainContainer.BorderSizePixel = 0
	mainContainer.Parent = screenGui
	
	-- Shared Title Bar
	local titleBar = Instance.new("Frame")
	titleBar.Size = UDim2.new(1, 0, 0, 40)
	titleBar.Position = UDim2.new(0, 0, 0, 0)
	titleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	titleBar.BackgroundTransparency = 0.3
	titleBar.BorderSizePixel = 0
	titleBar.ZIndex = 2
	titleBar.Parent = mainContainer
	
	local minimizeButton = Instance.new("TextButton")
	minimizeButton.Size = UDim2.new(0, 40, 0, 40)
	minimizeButton.AnchorPoint = Vector2.new(1, 0)
	minimizeButton.Position = UDim2.new(1, -5, 0, 0)
	minimizeButton.Text = "-"
	minimizeButton.Font = Enum.Font.Arcade
	minimizeButton.TextSize = 24
	minimizeButton.TextColor3 = Color3.new(1, 1, 1)
	minimizeButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80) -- darker gray
	minimizeButton.BackgroundTransparency = 0
	minimizeButton.BorderSizePixel = 0
	minimizeButton.ZIndex = 3
	minimizeButton.Parent = titleBar
	
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -50, 1, 0)
	titleLabel.Position = UDim2.new(0, 0, 0, 0)
	titleLabel.Text = "LeBron James Endurance Script"
	titleLabel.Font = Enum.Font.Arcade
	titleLabel.TextSize = 24
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.BackgroundTransparency = 1 -- no box behind text
	titleLabel.TextXAlignment = Enum.TextXAlignment.Center
	titleLabel.ZIndex = 3
	titleLabel.Parent = titleBar
	
	-- Utility to create buttons (bright blue accent style)
	local function createButton(text, position, parent, size)
		local button = Instance.new("TextButton")
		button.Size = size or UDim2.new(0, 200, 0, 40)
		button.Position = position
		button.Text = text
		button.BackgroundColor3 = Color3.fromRGB(100, 170, 255) -- bright blue
		button.TextColor3 = Color3.new(1, 1, 1)
		button.Font = Enum.Font.Arcade
		button.TextSize = 20
		button.Active = true
		button.Selectable = true
		button.BorderSizePixel = 0
		button.ZIndex = 1
		button.Parent = parent
		return button
	end
	
	-- Page 1 (offset below title bar)
	local page1 = Instance.new("Frame")
	page1.Position = UDim2.new(0, 0, 0, 40) -- push down below title bar
	page1.Size = UDim2.new(1, 0, 0, 260)    -- 300 total - 40 bar = 260
	page1.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	page1.BackgroundTransparency = 0.3
	page1.BorderSizePixel = 0
	page1.ZIndex = 1
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
	usernameBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50) -- solid gray
	usernameBox.BorderSizePixel = 0
	usernameBox.Parent = page1
	
	local roleBox = Instance.new("TextBox")
	roleBox.Size = UDim2.new(0, 200, 0, 40)
	roleBox.Position = UDim2.new(0, 230, 0, 120)
	roleBox.PlaceholderText = "Enter role here!"
	roleBox.Font = Enum.Font.Arcade
	roleBox.TextSize = 18
	roleBox.TextColor3 = Color3.new(1, 1, 1)
	roleBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50) -- solid gray
	roleBox.BorderSizePixel = 0
	roleBox.Parent = page1
	
	-- Smaller Next button (bottom right)
	local nextPageButton = createButton("NEXT >", UDim2.new(1, -100, 1, -40), page1, UDim2.new(0, 80, 0, 30))
	
	-- Page 2 (same offset)
	local page2 = Instance.new("Frame")
	page2.Position = UDim2.new(0, 0, 0, 40)
	page2.Size = UDim2.new(1, 0, 0, 260)
	page2.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	page2.BackgroundTransparency = 0.3
	page2.BorderSizePixel = 0
	page2.Visible = false
	page2.ZIndex = 1
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
		local VirtualUser = game:GetService("VirtualUser")
		game:GetService("Players").LocalPlayer.Idled:Connect(function()
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
	enduranceLabel.TextStrokeTransparency = 0.8
	enduranceLabel.TextStrokeColor3 = Color3.fromRGB(0,0,0)
	enduranceLabel.BackgroundTransparency = 1 -- keep transparent so text sits cleanly
	enduranceLabel.TextXAlignment = Enum.TextXAlignment.Center
	enduranceLabel.Text = "Endurance: not found"
	enduranceLabel.ZIndex = 2
	enduranceLabel.Parent = page2
	
	-- Toxic Shake Checker label
	local shakeLabel = Instance.new("TextLabel")
	shakeLabel.Size = UDim2.new(0, 300, 0, 40)
	shakeLabel.Position = UDim2.new(0.5, -150, 0, 170)
	shakeLabel.Font = Enum.Font.Arcade
	shakeLabel.TextSize = 18
	shakeLabel.TextColor3 = Color3.new(1, 1, 1)
	shakeLabel.TextStrokeTransparency = 0.8
	shakeLabel.TextStrokeColor3 = Color3.fromRGB(0,0,0)
	shakeLabel.BackgroundTransparency = 1
	shakeLabel.TextXAlignment = Enum.TextXAlignment.Center
	shakeLabel.Text = "Toxic Shakes: not found"
	shakeLabel.ZIndex = 2
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
			mainContainer.Size = UDim2.new(originalSize.X.Scale, originalSize.X.Offset, 0, titleBarHeight)
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
	    -- If already off, skip
	    if not activeRole then
	        return
	    end
	
	    -- Disconnect loop + win listener(s)
	    if loopConnection and loopConnection.Connected then
	        loopConnection:Disconnect()
	        loopConnection = nil
	    end
	    if winConnection and winConnection.Connected then
	        winConnection:Disconnect()
	        winConnection = nil
	    end
	
	    -- Reset cycle tracking for all roles (1, 2, 3)
	    for r = 1, 3 do
	        cycleDurations10[r] = {}
	        lastCycleTime[r]    = nil
	    end
	
	    -- Reset state flags
	    activeRole      = nil
	    isActive        = false
	    won             = false
	    timeoutElapsed  = false
	
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
	won            = false
	timeoutElapsed = false
	
	-- Reset cycle tracking for roles 1, 2, and 3
	cycleDurations10 = { [1] = {}, [2] = {}, [3] = {} }
	lastCycleTime    = { [1] = nil, [2] = nil, [3] = nil }
		
	-- Configs
	local configs = {
		[1] = { name = "PLAYER 1: DUMMY", teleportDelay = 0.3, deathDelay = 0.5, cycleDelay = 5.8 },
		[2] = { name = "PLAYER 2: MAIN",  teleportDelay = 0.3, deathDelay = 0.5, cycleDelay = 5.8 },
		[3] = { name = "SOLO MODE",       teleportDelay = 0.2, deathDelay = 0.2, cycleDelay = 5.6 }
	}
	
	-- Track wins
	local won = false
	local timeoutGen = 0
	
	-- Rolling buffer (10 cycles)
	local cycleDurations10 = { [1] = {}, [2] = {} }
	local lastCycleTime    = { [1] = nil, [2] = nil }
	
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
		for _, v in ipairs(tbl) do sum = sum + v end
		return sum / #tbl
	end
	
	-- Restart a role after a delay, ensuring the old loop is stopped first
	function restartRole(role, delay)
		-- Stop any existing loop/listeners
		if loopConnection and loopConnection.Connected then
			loopConnection:Disconnect()
			loopConnection = nil
		end
		if winConnection and winConnection.Connected then
			winConnection:Disconnect()
			winConnection = nil
		end
	
		isActive = false
	
		-- Schedule the restart
		task.delay(delay or 0, function()
			if activeRole == role then
				-- Reset flags (optionally preserve averages by commenting out the next 2 lines)
				cycleDurations10[role] = {}
				lastCycleTime[role] = nil
				won, timeoutElapsed = false, false
	
				-- Start fresh
				isActive = true
				if type(runLoop) == "function" then runLoop(role) end
				if type(listenForWin) == "function" then listenForWin(role) end
	
				print(("🔄 Role %d restarted after %.2fs"):format(role, delay or 0))
			else
				print(("ℹ️ Restart for role %d skipped (activeRole changed)"):format(role))
			end
		end)
	end
	
	-- Win/timeout detection
	function listenForWin(role)
		if role == 3 or not SoundEvent or not SoundEvent.OnClientEvent then return end
	
		-- Disconnect old connection
		if winConnection and winConnection.Connected then
			winConnection:Disconnect()
			winConnection = nil
		end
	
		-- Arm generation
		timeoutGen = timeoutGen + 1
		local myGen = timeoutGen
	
		if role == 1 then
			-- Reset win flag for this watchdog window
			won = false
	
			-- Player 1: detect win
			winConnection = SoundEvent.OnClientEvent:Connect(function(action, data)
				if activeRole ~= 1 then return end
				if action == "Play" and type(data) == "table" then
					if data.Name == "WinP1" or data.Name == "Win" then
						won = true
						timeoutElapsed = false
					end
				end
			end)
	
			-- Watchdog only triggers if NO win in window
			task.spawn(function()
				local startTime = os.clock()
				local windowSeconds = 15
				while os.clock() - startTime < windowSeconds do
					if won or activeRole ~= 1 or myGen ~= timeoutGen then
						return -- exit early if win or role change
					end
					RunService.Heartbeat:Wait()
				end
				if not won and activeRole == 1 and myGen == timeoutGen then
					timeoutElapsed = true
					timeoutGen = timeoutGen + 1 -- only increment when timeout actually fires
					local avg = getCycleAverage(1) or (configs[1] and configs[1].cycleDelay) or 0
					local delay = avg + 10
					print(("⚠️ Role 1 timed out — restarting after %.2fs (avg=%.3f+10)"):format(delay, avg))
					restartRole(1, delay)
				end
			end)
	
		elseif role == 2 then
			-- Player 2: restart immediately on win
			winConnection = SoundEvent.OnClientEvent:Connect(function(action, data)
				if activeRole ~= 2 then return end
				if action == "Play" and type(data) == "table" then
					if data.Name == "WinP2" or data.Name == "Win" then
						won = true
						timeoutElapsed = false
						local avg = getCycleAverage(2) or (configs[2] and configs[2].cycleDelay) or 0
						local delay = avg + 22.5
						print(("⚠️ Role 2 win detected — restarting after %.2fs (avg=%.3f+22.5) [event=%s]"):format(delay, avg, tostring(data.Name)))
						restartRole(2, delay)
					end
				end
			end)
		end
	end
					
	-- Core loop (os.clock() based, drift-proof, original style)
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
	        warn("runLoop: no points available for role " .. tostring(role))
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
	    local teleported = false
	
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
	
	        -- TELEPORT
	        if phase == "teleport" and elapsed >= config.teleportDelay then
	            local char = player.Character or player.CharacterAdded:Wait()
	            local hrp = char:WaitForChild("HumanoidRootPart")
	            hrp.CFrame = points[index]
	            teleported = true
	            phase = "kill"
	            phaseStart = phaseStart + config.teleportDelay
	
	        -- KILL
	        elseif phase == "kill" and elapsed >= config.deathDelay and teleported then
	            local char = player.Character
	            if char then
	                pcall(function() char:BreakJoints() end)
	            end
	            teleported = false
	            phase = "respawn"
	            phaseStart = phaseStart + config.deathDelay
	
	        -- RESPAWN
	        elseif phase == "respawn" then
	            local char = player.Character or player.CharacterAdded:Wait()
	            if char:FindFirstChild("HumanoidRootPart") then
	                if recordCycle then recordCycle(role) end
	                phase = "wait"
	                phaseStart = os.clock() -- re‑anchor here since respawn is async
	            end
	
	        -- WAIT
	        elseif phase == "wait" and elapsed >= config.cycleDelay then
	            phase = "teleport"
	            phaseStart = phaseStart + config.cycleDelay
	            index = index % #points + 1
	        end
	    end)
	end
	
	-- Variable to hold the chosen partner's username (set when Player1 types it)
	local partnerName = nil
	
	-- Capture the username when Player1 presses Enter in the box
	usernameBox.FocusLost:Connect(function(enterPressed)
	    if enterPressed then
	        local typed = usernameBox.Text:match("^%s*(.-)%s*$") -- trim whitespace
	        if typed ~= "" then
	            local partner = Players:FindFirstChild(typed)
	            if partner then
	                partnerName = partner.Name -- store canonical name
	                print("✅ Partner username set to:", partnerName)
	            else
	                warn("❌ No player found with that name")
	            end
	        end
	    end
	end)
	
	-- SOLO Fallback: strictly for role 1
	if role == 1 then
	    task.spawn(function()
	        local checkStart = os.clock()
	        local triggered = false
	
	        while activeRole == 1 and isActive do
	            local partner = partnerName and Players:FindFirstChild(partnerName)
	
	            if not partner then
	                -- specific partner not in server
	                if (os.clock() - checkStart) >= 10 and not triggered then
	                    triggered = true
	                    print("⚠️ Partner "..tostring(partnerName).." not found! Switching to SOLO mode 🧍")
	
	                    if activeRole == 1 and isActive then
	                        -- ✅ set state before starting loop
	                        activeRole = 3
	                        isActive   = true
	                        won, timeoutElapsed = false, false
	                        resetCycles(3)
	
	                        onOffButton.Text = "SOLO mode: ON"
	                        onOffButton.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
	
	                        -- ✅ guard: wait until character is ready before first Solo cycle
	                        local char = player.Character or player.CharacterAdded:Wait()
	                        char:WaitForChild("Humanoid")
	                        char:WaitForChild("HumanoidRootPart")
	
	                        runLoop(3)
	                    end
	                    break -- cleaner than return
	                end
	            else
	                -- partner present, reset timer
	                checkStart = os.clock()
	                triggered = false
	            end
	
	            waitSeconds(1) -- drift‑proof 1s wait
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
		won, timeoutElapsed = false, false
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
		else
			validateAndAssignRole()
		end
	end
	
	handleSoloClick = function()
	    -- cleanly stop any existing loop
	    forceToggleOff()
	    waitSeconds(1)
	
	    -- ✅ set state explicitly before starting loop
	    activeRole = 3
	    isActive   = true
	    won, timeoutElapsed = false, false
	    resetCycles(3)
	
	    onOffButton.Text = "SOLO mode: ON"
	    onOffButton.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
	
	    -- ✅ guard: ensure character is ready before first Solo cycle
	    local char = player.Character or player.CharacterAdded:Wait()
	    char:WaitForChild("Humanoid")
	    char:WaitForChild("HumanoidRootPart")
	
	    -- start the Solo loop
	    runLoop(3)
	end
end
