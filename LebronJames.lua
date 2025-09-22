return function()
	-- Get Services
	local RunService = game:GetService("RunService")
	local UserInputService = game:GetService("UserInputService")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local player = Players.LocalPlayer
	
	-- State and helpers
	local activeRole
	local loopConnection   -- Heartbeat loop connection
	local winConnection    -- Win detection connection
	
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
	
	-- Make GUI Universally Draggable (improved, no connection leaks)
	local function makeDraggable(gui)
	    local dragging = false
	    local dragStart, startPos
	
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
	
	-- Create Button Utility
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
	
	-- Force OFF
	local function forceToggleOff()
	    activeRole = nil
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
	
	    print("Loop stopped")
	end
	
	-- Configs
	local configs = {
	    [1] = { name = "PLAYER 1: DUMMY", teleportDelay = 0.3, deathDelay = 0.5, cycleDelay = 5.8 },
	    [2] = { name = "PLAYER 2: MAIN", teleportDelay = 0.3, deathDelay = 0.5, cycleDelay = 5.8 },
	    [3] = { name = "SOLO MODE", teleportDelay = 0.15, deathDelay = 0.05, cycleDelay = 5.55 }
	}
	
	-- Win detection
	local function listenForWin(role)
	    if role == 3 or not SoundEvent then return end
	
	    local won = false
	
	    -- Disconnect any previous listener
	    if winConnection and winConnection.Connected then
	        winConnection:Disconnect()
	        winConnection = nil
	    end
	
	     -- Attach listener
	    winConnection = SoundEvent.OnClientEvent:Connect(function(action, data)
	        if activeRole ~= role then return end
	        if action == "Play" and data and data.Name == "Win" then
	            won = true
	            print("✅ Win event received for role", role)
	
	            if winConnection and winConnection.Connected then
	                winConnection:Disconnect()
	                winConnection = nil
	            end
	
	            if role == 1 then
	                -- Player 1 win = expected, just continue
	                print("🎉 Player 1 won. Continuing as normal...")
	            elseif role == 2 then
	                -- Player 2 win = restart after 7.5s
	                print("⚠️ Player 2 won. Restarting after 22s!")
	                activeRole = nil
	                waitSeconds(22)
	                activeRole = 2
	                runLoop(2)
	            end
	        end
	    end)
	
	    -- Timeout logic for Player 1 only
	    if role == 1 then
	        task.spawn(function()
	            local startTime = os.clock()
	            while os.clock() - startTime < 15 do
	                if won or activeRole ~= role then
	                    return -- exit if win detected or role changed
	                end
	                RunService.Heartbeat:Wait()
	            end
	
	            -- If no win within 15s, restart after 10s
	            if not won and activeRole == role then
	                print("⚠️ Player 1 did not win within 15s! Restarting after 10s!")
	                if winConnection and winConnection.Connected then
	                    winConnection:Disconnect()
	                    winConnection = nil
	                end
	                activeRole = nil
	                waitSeconds(10)
	                activeRole = 1
	                runLoop(1)
	            end
	        end)
	    end
	end

	--Main loop
	function runLoop(role)
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
	
	    -- Start win listener for P1/P2
	    if role == 1 or role == 2 then
	        listenForWin(role)
	    end
	
	    local config = configs[role]
	    local index = 1
	    local phase = "teleport"
	    local phaseStart = os.clock()
	    local cycleCount = 0
	
	    -- Helper to advance phases cleanly
	    local function advancePhase(nextPhase)
	        phase = nextPhase
	        phaseStart = os.clock()
	    end
	
	    -- Disconnect any old loop before starting a new one
	    if loopConnection and loopConnection.Connected then
	        loopConnection:Disconnect()
	        loopConnection = nil
	    end
	
	    -- Store the loop connection globally so forceToggleOff() can stop it
	    loopConnection = RunService.Heartbeat:Connect(function()
	        if activeRole ~= role then
	            loopConnection:Disconnect()
	            loopConnection = nil
	            return
	        end
	
	        local now = os.clock()
	        local elapsed = now - phaseStart
	
	        if phase == "teleport" and elapsed >= config.teleportDelay then
	            advancePhase("kill")
	
	            local char = player.Character
	            if not char then return end
	            local hrp = char:FindFirstChild("HumanoidRootPart")
	            if hrp and points[index] then
	                hrp.CFrame = points[index]
	            end
	
	        elseif phase == "kill" and elapsed >= config.deathDelay then
	            advancePhase("respawn")
	
	            local char = player.Character
	            if char then
	                pcall(function()
	                    char:BreakJoints()
	                end)
	            end
	
	        elseif phase == "respawn" then
	            local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	            if hrp then
	                -- Drift-proof fix: only start wait timer once respawn is confirmed
	                advancePhase("wait")
	            end
	
	        elseif phase == "wait" and elapsed >= config.cycleDelay then
	            cycleCount += 1
	            advancePhase("teleport")
	            index = index % #points + 1
	        end
	    end)
	
	    -- SOLO fallback watcher (only runs if starting as Player 1)
	    if role == 1 then
	        task.spawn(function()
	            local checkStart = os.clock()
	            while activeRole == 1 do
	                local targetPlayer = Players:FindFirstChild(usernameBox.Text)
	                if not targetPlayer and os.clock() - checkStart >= 10 then
	                    print("Player 2 cannot be found in the server! Switching to solo mode now..🧍")
	                    activeRole = nil
	                    waitSeconds(1)
	                    activeRole = 3
	                    runLoop(3)
	                    return
	                elseif targetPlayer then
	                    checkStart = os.clock()
	                end
	                waitSeconds(1)
	            end
	        end)
	    end
	end
	
	-- Role Validation and Assignment
	local function validateAndAssignRole()
	    local targetName = usernameBox.Text
	    local roleCommand = roleBox.Text
	    local targetPlayer = Players:FindFirstChild(targetName)
	
	    if not targetPlayer or (roleCommand ~= "#AFK" and roleCommand ~= "#AFK2") then
	        print("Validation failed")
	        onOffButton.Text = "Validation failed"
	        onOffButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	        task.delay(3, function()
	            forceToggleOff()
	        end)
	        return
	    end
	
	    if roleCommand == "#AFK" then
	        activeRole = 1
	    elseif roleCommand == "#AFK2" then
	        activeRole = 2
	    end
	
	    print("Assigned role:", activeRole)
	    onOffButton.Text = "ON"
	    onOffButton.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
	    runLoop(activeRole)
	end
	
	-- ON/OFF Button Logic
	onOffButton.MouseButton1Click:Connect(function()
	    if activeRole then
	        forceToggleOff()
	        usernameBox.Text = ""
	        roleBox.Text = ""
	    else
	        validateAndAssignRole()
	    end
	end)
	
	-- SOLO Button Logic
	soloButton.MouseButton1Click:Connect(function()
	    forceToggleOff()
	    waitSeconds(1)
	    activeRole = 3
	    onOffButton.Text = "SOLO mode: ON"
	    onOffButton.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
	    runLoop(3)
	end)
end
