-- ⚙️ Servicios
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 🧠 Variables de estado
local autoPunchEnabled = false
local autoKillEnabled = false
local godModeEnabled = false

-- 🥊 Función para activar el botón de puño del juego
local function clickPunchButton()
    for _, gui in ipairs(LocalPlayer.PlayerGui:GetDescendants()) do
        if gui:IsA("ImageButton") and gui.Name:lower():find("punch") then
            gui:Activate()
        end
    end
end

-- 🔁 Auto-punch loop (golpes + botón visual)
task.spawn(function()
    while true do
        if autoPunchEnabled then
            local muscleEvent = LocalPlayer:FindFirstChild("muscleEvent")
            if muscleEvent then
                muscleEvent:FireServer("punch", "rightHand", "leftHand")
            end
            clickPunchButton()
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

-- 🖥️ Crear panel visual
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MuscleControlPanel"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local frame = Instance.new("Frame", screenGui)
frame.Size = UDim2.new(0, 260, 0, 200)
frame.Position = UDim2.new(0.02, 0, 0.6, 0)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true

local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1, 0, 0, 30)
title.Text = "💪 Muscle Legends Panel"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.BackgroundTransparency = 1
title.Font = Enum.Font.SourceSansBold
title.TextSize = 18

-- 🔘 Botón con estado visual
local function createToggleButton(text, yPos, stateGetter, stateSetter)
    local btn = Instance.new("TextButton", frame)
    btn.Size = UDim2.new(0.9, 0, 0, 35)
    btn.Position = UDim2.new(0.05, 0, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 16

    local function updateText()
        btn.Text = text .. " [" .. (stateGetter() and "ON" or "OFF") .. "]"
        btn.BackgroundColor3 = stateGetter() and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(170, 0, 0)
    end

    btn.MouseButton1Click:Connect(function()
        stateSetter(not stateGetter())
        updateText()
    end)

    updateText()
end

-- 🥊 Toggle Auto-Punch
createToggleButton("🥊 Auto-Punch", 40,
    function() return autoPunchEnabled end,
    function(val) autoPunchEnabled = val end)

-- 💀 Toggle Auto-Kill
createToggleButton("💀 Auto-Kill", 85,
    function() return autoKillEnabled end,
    function(val) autoKillEnabled = val end)

-- 🛡️ Toggle God Mode
createToggleButton("🛡️ God Mode", 130,
    function() return godModeEnabled end,
    function(val) godModeEnabled = val end)

-- ❌ Botón para cerrar panel
local closeBtn = Instance.new("TextButton", frame)
closeBtn.Size = UDim2.new(0.9, 0, 0, 30)
closeBtn.Position = UDim2.new(0.05, 0, 0, 175)
closeBtn.Text = "❌ Cerrar Panel"
closeBtn.BackgroundColor3 = Color3.fromRGB(100, 0, 0)
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.SourceSansBold
closeBtn.TextSize = 16
closeBtn.MouseButton1Click:Connect(function()
    screenGui:Destroy()
end)
