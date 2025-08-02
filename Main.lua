print("Dupe GUI cargado correctamente")

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
status.Text = "Listo para duplicar"
status.Parent = gui

local boton = Instance.new("TextButton")
boton.Size = UDim2.new(0, 150, 0, 40)
boton.Position = UDim2.new(0.5, -75, 0.9, 0)
boton.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
boton.TextColor3 = Color3.fromRGB(255, 255, 255)
boton.Font = Enum.Font.SourceSansBold
boton.TextSize = 22
boton.Text = "Activar Dupe"
boton.Parent = gui

boton.MouseButton1Click:Connect(function()
    status.Text = "Dupe ejecutándose..."

    local r = game:GetService("ReplicatedStorage")
    local p = r:WaitForChild("Packages"):WaitForChild("Net")
    local e = p:FindFirstChild("RE/StealService/Grab")

    local function grab(id)
        print(">> [Server] Grab Queued:", id)
        task.wait(0.25)
        print(">> [Server] Processing:", id)
        e:FireServer("Grab", id)
    end

    local id = math.floor(os.clock() * 100000)
    grab(id)

    task.delay(0.5, function()
        status.Text = "Dupe ejecutado con ID: " .. tostring(id)
        gui:Destroy()
    end)
end)
