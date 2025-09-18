return function()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local player = Players.LocalPlayer

    local activeRole, targetName = nil, nil
    local loopRunning, hbConn, minimized = false, nil, false

    -- Configs
    local configs = {
        [1] = { name = "PLAYER 1: DUMMY", teleportDelay = 0.3, deathDelay = 0.5, cycleDelay = 5.8 },
        [2] = { name = "PLAYER 2: MAIN", teleportDelay = 0.3, deathDelay = 0.5, cycleDelay = 5.8 }
    }

    -- Drift-proof loop
    local function runLoop(role, target)
        if hbConn then hbConn:Disconnect() hbConn = nil end
        local points = role == 1 and {
            workspace.Spar_Ring1.Player1_Button.CFrame,
            workspace.Spar_Ring4.Player1_Button.CFrame
        } or role == 2 and {
            workspace.Spar_Ring1.Player2_Button.CFrame,
            workspace.Spar_Ring4.Player2_Button.CFrame
        }
        if not points then return end

        local config = configs[role]
        local index, phase, phaseStart = 1, "teleport", os.clock()

        hbConn = RunService.Heartbeat:Connect(function()
            if activeRole ~= role then
                hbConn:Disconnect()
                hbConn = nil
                return
            end

            local now, elapsed = os.clock(), os.clock() - phaseStart

            if phase == "teleport" and elapsed >= config.teleportDelay then
                phase, phaseStart = "kill", now
                local char = player.Character or player.CharacterAdded:Wait()
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.CFrame = points[index] end

            elseif phase == "kill" and elapsed >= config.deathDelay then
                phase, phaseStart = "respawn", now
                local char = player.Character
                if char then pcall(function() char:BreakJoints() end) end

            elseif phase == "respawn" then
                local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    phase, phaseStart = "wait", os.clock()
                end

            elseif phase == "wait" and elapsed >= config.cycleDelay then
                phase, phaseStart = "teleport", os.clock()
                index = index % #points + 1
            end
        end)
    end

    local function stopLoop()
        if hbConn then hbConn:Disconnect() hbConn = nil end
    end

    -- GUI
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "RoleToggleGui"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = player:WaitForChild("PlayerGui")

    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 500, 0, 50)
    mainFrame.Position = UDim2.new(0.5, -250, 0, 100)
    mainFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    mainFrame.Parent = screenGui
    Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 8)

    -- Topbar container for minimize
    local topbar = Instance.new("Frame")
    topbar.Size = UDim2.new(1, 0, 1, 0)
    topbar.BackgroundTransparency = 1
    topbar.Parent = mainFrame

    local layout = Instance.new("UIListLayout", topbar)
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.Padding = UDim.new(0, 5)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Center

    local function styleBox(box)
        box.Font = Enum.Font.Gotham
        box.TextSize = 14
        box.TextColor3 = Color3.fromRGB(0, 0, 0)
        box.BackgroundColor3 = Color3.fromRGB(230, 230, 230)
        Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)
    end

    local userBox = Instance.new("TextBox")
    userBox.Size = UDim2.new(0, 200, 0, 30)
    userBox.PlaceholderText = "Other player's username"
    styleBox(userBox)
    userBox.Parent = topbar

    local cmdBox = Instance.new("TextBox")
    cmdBox.Size = UDim2.new(0, 100, 0, 30)
    cmdBox.PlaceholderText = "#AFK / #AFK2"
    styleBox(cmdBox)
    cmdBox.Parent = topbar

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, 100, 0, 30)
    toggleBtn.Text = "OFF"
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = 14
    toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
    Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 6)
    toggleBtn.Parent = topbar

    local minimizeBtn = Instance.new("TextButton")
    minimizeBtn.Size = UDim2.new(0, 80, 0, 30)
    minimizeBtn.Text = "Minimize"
    minimizeBtn.Font = Enum.Font.GothamSemibold
    minimizeBtn.TextSize = 12
    minimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    minimizeBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    Instance.new("UICorner", minimizeBtn).CornerRadius = UDim.new(0, 6)
    minimizeBtn.Parent = topbar

    -- Validation
    local function validateInputs()
        local uname = userBox.Text
        local cmd = cmdBox.Text:upper()
        local otherPlayer = Players:FindFirstChild(uname)

        if otherPlayer and (cmd == "#AFK" or cmd == "#AFK2") then
            activeRole = (cmd == "#AFK") and 1 or 2
            targetName = uname
            toggleBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
            return true
        else
            activeRole, targetName = nil, nil
            toggleBtn.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
            return false
        end
    end

    userBox.FocusLost:Connect(validateInputs)
    cmdBox.FocusLost:Connect(validateInputs)

    -- Toggle logic
    toggleBtn.MouseButton1Click:Connect(function()
        if not loopRunning then
            if validateInputs() then
                loopRunning = true
                toggleBtn.Text = "ON"
                runLoop(activeRole, targetName)
            else
                warn("Invalid username or command")
            end
        else
            loopRunning = false
            toggleBtn.Text = "OFF"
            stopLoop()
        end
    end)

    -- Minimize logic
    minimizeBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        userBox.Visible = not minimized
        cmdBox.Visible = not minimized
        toggleBtn.Visible = not minimized
        if minimized then
            mainFrame.Size = UDim2.new(0, 200, 0, 40)
            minimizeBtn.Text = "Maximize"
        else
            mainFrame.Size = UDim2.new(0, 500, 0, 50)
            minimizeBtn.Text = "Minimize"
        end
    end)

    -- Draggable
    do
        local dragging, dragStart, startPos
        mainFrame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                dragStart = input.Position
                startPos = mainFrame.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                    end
                end)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local delta = input.Position - dragStart
                mainFrame.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
            end
        end)
    end
end
