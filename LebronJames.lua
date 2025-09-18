return function()
    -- 🔧 Service Declarations
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local player = Players.LocalPlayer
    
    -- ⚙️ Role Configurations
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
            cycleDelay = 5.8
        }
    }
    
    -- 🌀 Core Loop
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
            workspace.Spar_Ring3.Player1_Button.CFrame,
            workspace.Spar_Ring3.Player2_Button.CFrame
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
                if hrp then hrp.CFrame = points[index] end
    
            elseif phase == "kill" and elapsed >= config.deathDelay then
                phase = "respawn"
                phaseStart = now
                local char = player.Character
                if char then pcall(function() char:BreakJoints() end) end
    
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
    
    -- 🥇 Win Detection via RemoteEvent
    local SoundEvent = game:GetService("ReplicatedStorage"):WaitForChild("Sound")
    
    local function listenForWin(role)
        local connection
        connection = SoundEvent.OnClientEvent:Connect(function(action, data)
            if activeRole ~= role then return end
            if action == "Play" and data and data.Name == "Win" then
                print("Win signal received for role " .. role)
                connection:Disconnect()
    
                if role == 1 then
                    activeRole = nil
                    task.wait(15)
                    activeRole = 1
                    runLoop(1)
                elseif role == 2 then
                    activeRole = nil
                    task.wait(12)
                    activeRole = 2
                    runLoop(2)
                end
            end
        end)
    end
    
    -- Call this inside runLoop(role) for roles 1 and 2:
    if role == 1 or role == 2 then
        listenForWin(role)
    end
    
        -- 🧍 SOLO Fallback (Player 1 only)
        if role == 1 then
            task.spawn(function()
                local checkStart = os.clock()
                while activeRole == 1 do
                    local targetPlayer = Players:FindFirstChild(usernameBox.Text)
                    if not targetPlayer and os.clock() - checkStart >= 15 then
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
    end
    
    -- 🧱 GUI Setup
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "RoleToggleGui"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = player:WaitForChild("PlayerGui")
    
    -- 🧊 Main Container Frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 450, 0, 300)
    mainFrame.Position = UDim2.new(0.5, -225, 0.5, -150)
    mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    mainFrame.BackgroundTransparency = 0.3
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    
    -- 🖱 Make GUI Draggable
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
    
    -- 🧠 Create Button Utility
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
    
    -- 🧱 GUI Elements
    local button1 = createButton("PLAYER 1: DUMMY", UDim2.new(0, 20, 0, 60))
    local button2 = createButton("PLAYER 2: MAIN", UDim2.new(0, 20, 0, 110))
    local soloButton = createButton("SOLO MODE", UDim2.new(0, 240, 0, 60))
    local onOffButton = createButton("OFF", UDim2.new(0, 240, 0, 110))
    
    local usernameBox = Instance.new("TextBox")
    usernameBox.Size = UDim2.new(0, 200, 0, 30)
    usernameBox.Position = UDim2.new(0, 20, 0, 170)
    usernameBox.PlaceholderText = "Target Username"
    usernameBox.Font = Enum.Font.Arcade
    usernameBox.TextSize = 18
    usernameBox.TextColor3 = Color3.new(1, 1, 1)
    usernameBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    usernameBox.BorderSizePixel = 0
    usernameBox.Parent = mainFrame
    
    local roleBox = Instance.new("TextBox")
    roleBox.Size = UDim2.new(0, 200, 0, 30)
    roleBox.Position = UDim2.new(0, 20, 0, 210)
    roleBox.PlaceholderText = "#AFK or #AFK2"
    roleBox.Font = Enum.Font.Arcade
    roleBox.TextSize = 18
    roleBox.TextColor3 = Color3.new(1, 1, 1)
    roleBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    roleBox.BorderSizePixel = 0
    roleBox.Parent = mainFrame
    
    -- 🏷️ GUI Title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 0, 40)
    titleLabel.Position = UDim2.new(0, 0, 0, 0)
    titleLabel.Text = "Lebron James Endurance Script"
    titleLabel.Font = Enum.Font.Arcade
    titleLabel.TextSize = 24
    titleLabel.TextColor3 = Color3.new(1, 1, 1)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Parent = mainFrame
    
    -- 🧠 Role Toggle Reset
    local function forceToggleOff()
        activeRole = nil
        onOffButton.Text = "OFF"
        onOffButton.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
    end
    
    -- 🧠 Role Validation and Assignment
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
    
    -- 🔘 ON/OFF Button Logic
    onOffButton.MouseButton1Click:Connect(function()
        if activeRole then
            forceToggleOff()
        else
            validateAndAssignRole()
        end
    end)
    
    -- 🧍 SOLO Button Logic
    soloButton.MouseButton1Click:Connect(function()
        forceToggleOff()
        task.wait(1)
        activeRole = 3
        onOffButton.Text = "SOLO"
        onOffButton.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
        runLoop(3)
    end)
end
