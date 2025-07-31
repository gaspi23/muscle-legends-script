-- ⚙️ Servicios
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local muscleEvent = LocalPlayer:WaitForChild("muscleEvent")

-- 📊 Estado de funciones
local autoPunchEnabled = false
local autoKillEnabled = false
local godModeEnabled = false

-- 🥊 Auto-punch loop
task.spawn(function()
    while true do
        if autoPunchEnabled and muscleEvent then
            muscleEvent:FireServer("punch", "rightHand", "leftHand")
        end
        task.wait(0.001)
    end
end)

-- 💀 Auto-kill loop
task.spawn(function()
    while true do
        if autoKillEnabled then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Humanoid") then
                    player.Character:BreakJoints()
                end
            end
        end
        task.wait(1)
    end
end)

-- 🛡️ Modo inmortal
LocalPlayer.CharacterAdded:Connect(function(char)
    char:WaitForChild("Humanoid").Died:Connect(function()
        if godModeEnabled then
            char:BreakJoints() -- revive instantáneo
        end
    end)
end)

-- 🧭 Crear panel
local screenGui = Instance.new("ScreenGui", game:GetService("CoreGui"))
screenGui.Name = "MuscleControlPanel"

local frame = Instance.new("Frame", screenGui)
frame.Size = UDim2.new(0, 250, 0, 180)
frame.Position = UDim2.new(0.02, 0, 0.6, 0)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.BorderSizePixel = 0

local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1, 0, 0, 30)
title.Text = "⚙️ Muscle Legends Panel"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.BackgroundTransparency = 1
title.Font = Enum.Font.SourceSansBold
title.TextSize = 18

-- 🔘 Botón genérico
local function createButton(text, yPos, callback)
    local btn = Instance.new("TextButton", frame)
    btn.Size = UDim2.new(0.9, 0, 0, 30)
    btn.Position = UDim2.new(0.05, 0, 0, yPos)
    btn.Text = text
    btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.SourceSans
    btn.TextSize = 16
    btn.MouseButton1Click:Connect(callback)
end

-- 🥊 Toggle auto-punch
createButton("🥊 Toggle Auto-Punch", 40, function()
    autoPunchEnabled = not autoPunchEnabled
end)

-- 💀 Toggle auto-kill
createButton("💀 Toggle Auto-Kill", 80, function()
    autoKillEnabled = not autoKillEnabled
end)

-- 🛡️ Toggle inmortalidad
createButton("🛡️ Toggle God Mode", 120, function()
    godModeEnabled = not godModeEnabled
end)
