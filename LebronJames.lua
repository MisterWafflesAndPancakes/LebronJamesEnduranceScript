return function()
    -- Get Services
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local player = Players.LocalPlayer
    
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
    
    -- Make GUI Draggable
    local function makeDraggable(gui)
        local dragging = false
        local dragStart, startPos
    
        gui.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or
               input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = gui.Position
    
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                    end
                end)
            end
        end)
    
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or
                             input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                gui.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                                         startPos.Y.Scale, startPos.Y.Offset + delta.Y)
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
    
    -- GUI Elements (cleaned)
    local soloButton = createButton("SOLO MODE", UDim2.new(0, 20, 0, 60))
    local onOffButton = createButton("OFF", UDim2.new(0, 230, 0, 60))
    
    local usernameBox = Instance.new("TextBox")
    usernameBox.Size = UDim2.new(0, 200, 0, 40) -- match button height
    usernameBox.Position = UDim2.new(0, 20, 0, 120) -- bigger gap
    usernameBox.PlaceholderText = "Target Username"
    usernameBox.Font = Enum.Font.Arcade
    usernameBox.TextSize = 18
    usernameBox.TextColor3 = Color3.new(1, 1, 1)
    usernameBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    usernameBox.BorderSizePixel = 0
    usernameBox.Parent = mainFrame
    
    local roleBox = Instance.new("TextBox")
    roleBox.Size = UDim2.new(0, 200, 0, 40) -- match button height
    roleBox.Position = UDim2.new(0, 230, 0, 120) -- bigger gap
    roleBox.PlaceholderText = "#AFK or #AFK2"
    roleBox.Font = Enum.Font.Arcade
    roleBox.TextSize = 18
    roleBox.TextColor3 = Color3.new(1, 1, 1)
    roleBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    roleBox.BorderSizePixel = 0
    roleBox.Parent = mainFrame
    
    -- 🏷 GUI Title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 0, 40)
    titleLabel.Position = UDim2.new(0, 0, 0, 0)
    titleLabel.Text = "Lebron James Endurance Script"
    titleLabel.Font = Enum.Font.Arcade
    titleLabel.TextSize = 24
    titleLabel.TextColor3 = Color3.new(1, 1, 1)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Parent = mainFrame
    
    -- Minimize Button (bottom-right corner)
    local minimizeButton = Instance.new("TextButton")
    minimizeButton.Size = UDim2.new(0, 40, 0, 40)
    minimizeButton.AnchorPoint = Vector2.new(1, 1) -- anchor to bottom-right
    minimizeButton.Position = UDim2.new(1, -5, 1, -5) -- 5px padding from edges
    minimizeButton.Text = "-"
    minimizeButton.Font = Enum.Font.Arcade
    minimizeButton.TextSize = 24
    minimizeButton.TextColor3 = Color3.new(1, 1, 1)
    minimizeButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    minimizeButton.BorderSizePixel = 0
    minimizeButton.Parent = mainFrame
    
    -- Elements to hide when minimized
    local minimized = false
    local guiElements = {
        soloButton,
        onOffButton,
        usernameBox,
        roleBox
    }
    
    -- store the original frame size so we can restore it later
    local originalSize = mainFrame.Size
    local originalPos = mainFrame.Position
    
    minimizeButton.MouseButton1Click:Connect(function()
        minimized = not minimized
    
        for _, element in ipairs(guiElements) do
            element.Visible = not minimized
        end
    
        minimizeButton.Text = minimized and "+" or "-"
    
        if minimized then
            mainFrame.Size = UDim2.new(originalSize.X.Scale, originalSize.X.Offset, 0, 50)
            mainFrame.Position = UDim2.new(originalPos.X.Scale, originalPos.X.Offset, originalPos.Y.Scale, originalPos.Y.Offset + (originalSize.Y.Offset - 50)/2)
        else
            mainFrame.Size = originalSize
            mainFrame.Position = originalPos
        end
    end)
    
    -- Role Toggle Reset
    local function forceToggleOff()
        activeRole = nil
        onOffButton.Text = "OFF"
        onOffButton.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
    end
    
    -- Role Validation and Assignment
    local function validateAndAssignRole()
        local targetName = usernameBox.Text
        local roleCommand = roleBox.Text
        local targetPlayer = Players:FindFirstChild(targetName)
    
        if not targetPlayer or (roleCommand ~= "#AFK" and roleCommand ~= "#AFK2") then
            print("Validation failed")
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
        else
            validateAndAssignRole()
        end
    end)
    
    -- SOLO Button Logic
    soloButton.MouseButton1Click:Connect(function()
        forceToggleOff()
        task.wait(1)
        activeRole = 3
        onOffButton.Text = "SOLO"
        onOffButton.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
        runLoop(3)
    end)
    
    -- ⚙ Role Configurations
    local configs = {
        [1] = {
            name = "PLAYER 1: DUMMY",
            teleportDelay = 0.3,
            deathDelay = 0.5,
            cycleDelay = 5.8
        },
        [2] = {
            name = "PLAYER 2: MAIN",
            teleportDelay = 0.3,
            deathDelay = 0.5,
            cycleDelay = 5.8
        },
        [3] = {
            name = "SOLO MODE",
            teleportDelay = 0.3,
            deathDelay = 0.5,
            cycleDelay = 5.5
        }
    }
    
    -- Track win detection state for each role
    local winDetected = {
        [1] = false,
        [2] = false
    }
    
    -- RemoteEvent for win detection
    local SoundEvent = ReplicatedStorage:WaitForChild("Sound")
    
    -- Listen for any player's win (updates winDetected for both roles)
    SoundEvent.OnClientEvent:Connect(function(action, data, playerName)
        if action == "Play" and data and data.Name == "Win" then
            if playerName == "Player1" then
                winDetected[1] = true
                print("Player 1 win detected")
            elseif playerName == "Player2" then
                winDetected[2] = true
                print("Player 2 win detected")
            end
        end
    end)
    
    -- Role-specific listener for the local role
    local function listenForWin(role)
        local connection
        connection = SoundEvent.OnClientEvent:Connect(function(action, data, playerName)
            if activeRole ~= role then return end
            if action == "Play" and data and data.Name == "Win" and playerName == player.Name then
                print("Local win signal for role " .. role)
                winDetected[role] = true
                connection:Disconnect()
    
                -- Restart logic based on other role's win state
                if role == 1 and winDetected[2] and not winDetected[1] then
                    activeRole = nil
                    task.wait(17)
                    activeRole = 1
                    runLoop(1)
                elseif role == 2 and winDetected[1] and not winDetected[2] then
                    activeRole = nil
                    task.wait(13)
                    activeRole = 2
                    runLoop(2)
                end
            end
        end)
    end
    
    local RunService = game:GetService("RunService")
    
    local function runLoop(role)
        local points = role == 1 and {
            workspace.Spar_Ring1.Player1_Button.CFrame,
            workspace.Spar_Ring4.Player1_Button.CFrame
        } or role == 2 and {
            workspace.Spar_Ring1.Player2_Button.CFrame,
            workspace.Spar_Ring4.Player2_Button.CFrame
        } or role == 3 and {
            workspace.Spar_Ring2.Player1_Button.CFrame,
            workspace.Spar_Ring2.Player2_Button.CFrame,
            workspace.Spar_Ring4.Player1_Button.CFrame,
            workspace.Spar_Ring4.Player2_Button.CFrame
        }
    
        if not points then return end
    
        local config = configs[role]
        local index = 1
        local phase = "teleport"
        local phaseStart = os.clock()
    
        local connection
        connection = RunService.Heartbeat:Connect(function()
            if activeRole ~= role then
                connection:Disconnect()
                return
            end
    
            local now = os.clock()
            local elapsed = now - phaseStart
    
            if phase == "teleport" and elapsed >= config.teleportDelay then
                phase = "kill"
                phaseStart = now
    
                local char = player.Character or player.CharacterAdded:Wait()
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.CFrame = points[index]
                end
    
            elseif phase == "kill" and elapsed >= config.deathDelay then
                phase = "respawn"
                phaseStart = now
    
                local char = player.Character
                if char then
                    pcall(function()
                        char:BreakJoints()
                    end)
                end
    
            elseif phase == "respawn" then
                local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    phase = "wait"
                    phaseStart = os.clock()
                end
    
            elseif phase == "wait" and elapsed >= config.cycleDelay then
                phase = "teleport"
                phaseStart = os.clock()
                index = index % #points + 1
            end
        end)
    end

    -- SOLO fall back
    task.spawn(function()
        local checkStart = os.clock()
        while activeRole == 1 do
            local targetPlayer = Players:FindFirstChild(usernameBox.Text)
            if not targetPlayer and os.clock() - checkStart >= 10 then
                print("Player 2 missing — switching to SOLO")
                activeRole = nil
                task.wait(1)
                activeRole = 3
                runLoop(3)
                break
            elseif targetPlayer then
                checkStart = os.clock()
            end
            task.wait(1)
        end
    end)
end
