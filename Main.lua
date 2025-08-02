print("Dupe GUI successfully loaded")

local gui = Instance.new("ScreenGui")
gui.Name = "DupeGUI"
gui.ResetOnSpawn = false
gui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")

local status = Instance.new("TextLabel")
status.Size = UDim2.new(0, 300, 0, 50)
status.Position = UDim2.new(0.5, -150, 0.8, 0)
status.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
status.BackgroundTransparency = 0.3
status.TextColor3 = Color3.fromRGB(0, 255, 0)
status.Font = Enum.Font.SourceSansBold
status.TextSize = 24
status.Text = "Ready to duplicate"
status.Parent = gui

local button = Instance.new("TextButton")
button.Size = UDim2.new(0, 150, 0, 40)
button.Position = UDim2.new(0.5, -75, 0.9, 0)
button.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
button.TextColor3 = Color3.fromRGB(255, 255, 255)
button.Font = Enum.Font.SourceSansBold
button.TextSize = 22
button.Text = "Activate Dupe"
button.Parent = gui

button.MouseButton1Click:Connect(function()
    local char = game:GetService("Players").LocalPlayer.Character
    local tool = char:FindFirstChildOfClass("Tool")

    if tool then
        local r = game:GetService("ReplicatedStorage")
        local p = r:WaitForChild("Packages"):WaitForChild("Net")
        local e = p:FindFirstChild("RE/StealService/Grab")
        if e then
            e:FireServer("Grab", tool)
            status.Text = "Duplication sent: " .. tool.Name
            print(">> Duplication requested for: " .. tool.Name)
        else
            status.Text = "Remote not found"
            print(">> Error: RE/StealService/Grab not found")
        end
    else
        status.Text = "No tool equipped"
        print(">> Error: No tool in hand")
    end

    task.delay(2, function()
        gui:Destroy()
    end)
end)
