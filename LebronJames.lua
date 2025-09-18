return function()
    local Players = game:GetService("Players")
    local UserInputService = game:GetService("UserInputService")
    local player = Players.LocalPlayer

    local activeRole, targetName, loopRunning, hbConn = nil, nil, false, nil
    local minimized = false

    -- Your drift-proof loop here
    local function runLoop(role, target)
        if hbConn then hbConn:Disconnect() hbConn = nil end
        print(("Loop started for %s%s"):format(
            role == 1 and "Player 1" or role == 2 and "Player 2" or "SOLO",
            target and (", targeting " .. target) or ""
        ))
        hbConn = game:GetService("RunService").Heartbeat:Connect(function()
            -- Your teleport/kill cycle logic here
        end)
    end
    local function stopLoop()
        if hbConn then hbConn:Disconnect() hbConn = nil end
        print("Loop stopped")
    end

    local configs = {
        [1] = { name = "PLAYER 1: DUMMY" },
        [2] = { name = "PLAYER 2: MAIN" },
        [3] = { name = "SOLO MODE" }
    }

    -- GUI root
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AFKRoleGui"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = player:WaitForChild("PlayerGui")

    -- Main container
    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 420, 0, 220)
    main.Position = UDim2.new(0, 100, 0, 100)
    main.BackgroundColor3 = Color3.fromRGB(30, 36, 48)
    main.BackgroundTransparency = 0.15
    main.BorderSizePixel = 0
    main.Parent = screenGui
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)

    -- Topbar
    local topbar = Instance.new("Frame")
    topbar.Size = UDim2.new(1, 0, 0, 30)
    topbar.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
    topbar.BorderSizePixel = 0
    topbar.Parent = main
    Instance.new("UICorner", topbar).CornerRadius = UDim.new(0, 12)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -80, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "Lebron James Endurance Script"
    title.Parent = topbar

    local minimizeBtn = Instance.new("TextButton")
    minimizeBtn.Size = UDim2.new(0, 70, 0, 24)
    minimizeBtn.Position = UDim2.new(1, -75, 0.5, -12)
    minimizeBtn.Text = "Minimize"
    minimizeBtn.Font = Enum.Font.GothamSemibold
    minimizeBtn.TextSize = 12
    minimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    minimizeBtn.BackgroundColor3 = Color3.fromRGB(80, 90, 110)
    Instance.new("UICorner", minimizeBtn).CornerRadius = UDim.new(0, 6)
    minimizeBtn.Parent = topbar

    -- Content container
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, 0, 1, -30)
    content.Position = UDim2.new(0, 0, 0, 30)
    content.BackgroundTransparency = 1
    content.Parent = main

    local layout = Instance.new("UIListLayout", content)
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.Padding = UDim.new(0, 10)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Center

    -- Styling helper
    local function styleBox(box)
        box.Font = Enum.Font.Gotham
        box.TextSize = 14
        box.TextColor3 = Color3.fromRGB(255, 255, 255)
        box.BackgroundColor3 = Color3.fromRGB(50, 60, 80)
        box.BackgroundTransparency = 0.1
        Instance.new("UICorner", box).CornerRadius = UDim.new(0, 8)
        local bStroke = Instance.new("UIStroke", box)
        bStroke.Color = Color3.fromRGB(90, 100, 130)
        bStroke.Thickness = 1
    end

    -- Username + Command boxes
    local userBox = Instance.new("TextBox")
    userBox.Size = UDim2.new(0, 380, 0, 32)
    userBox.PlaceholderText = "Other player's username"
    userBox.Text = ""
    styleBox(userBox)
    userBox.Parent = content

    local cmdBox = Instance.new("TextBox")
    cmdBox.Size = UDim2.new(0, 380, 0, 32)
    cmdBox.PlaceholderText = "Type #AFK or #AFK2"
    cmdBox.Text = ""
    styleBox(cmdBox)
    cmdBox.Parent = content

    -- SOLO button
    local soloBtn = Instance.new("TextButton")
    soloBtn.Size = UDim2.new(0, 200, 0, 30)
    soloBtn.Text = "SOLO MODE"
    soloBtn.Font = Enum.Font.GothamBold
    soloBtn.TextSize = 14
    soloBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    soloBtn.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
    Instance.new("UICorner", soloBtn).CornerRadius = UDim.new(0, 8)
    local sStroke = Instance.new("UIStroke", soloBtn)
    sStroke.Color = Color3.fromRGB(255, 200, 80)
    soloBtn.Parent = content

    -- Toggle button
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, 200, 0, 34)
    toggleBtn.Text = "OFF"
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = 14
    toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 8)
    local tStroke = Instance.new("UIStroke", toggleBtn)
    tStroke.Color = Color3.fromRGB(80, 90, 110)
    toggleBtn.Parent = content
    toggleBtn.Active = false

    -- Validation for P1/P2
    local function validateInputs()
        local uname = userBox.Text
        local cmd = cmdBox.Text:upper()
        local otherPlayer = Players:FindFirstChild(uname)

        if otherPlayer and (cmd == "#AFK" or cmd == "#AFK2") then
            activeRole = (cmd == "#AFK") and 1 or 2
            targetName = uname
            toggleBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
            toggleBtn.Active = true
        elseif activeRole ~= 3 then
            activeRole, targetName = nil, nil
            toggleBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
            toggleBtn.Active = false
        end
    end

    userBox.FocusLost:Connect(validateInputs)
    cmdBox.FocusLost:Connect(validateInputs)

    -- SOLO button logic
    soloBtn.MouseButton1Click:Connect(function()
        activeRole = 3
        targetName = nil
        userBox.Text = ""
        cmdBox.Text = ""
        toggleBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
        toggleBtn.Active = true
        print("SOLO mode selected")
    end)

    -- Toggle ON/OFF
    toggleBtn.MouseButton1Click:Connect(function()
        if not activeRole then return end
        loopRunning = not loopRunning
        if loopRunning then
        toggleBtn.Text = "ON"
        toggleBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
        runLoop(activeRole, targetName)
    else
        toggleBtn.Text = "OFF"
        toggleBtn.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
        stopLoop()
    end
  end)
  
  -- Minimize logic
  minimizeBtn.MouseButton1Click:Connect(function()
      minimized = not minimized
      content.Visible = not minimized
      if minimized then
          main.Size = UDim2.new(0, 420, 0, 30) -- just topbar height
          minimizeBtn.Text = "Maximize"
      else
          main.Size = UDim2.new(0, 420, 0, 220) -- full height
          minimizeBtn.Text = "Minimize"
      end
  end)
  
  -- Make draggable (topbar only)
  do
      local dragging, dragStart, startPos
      topbar.InputBegan:Connect(function(input)
          if input.UserInputType == Enum.UserInputType.MouseButton1 then
              dragging = true
              dragStart = input.Position
              startPos = main.Position
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
              main.Position = UDim2.new(
                  startPos.X.Scale, startPos.X.Offset + delta.X,
                  startPos.Y.Scale, startPos.Y.Offset + delta.Y
              )
          end
      end)
  end

end
