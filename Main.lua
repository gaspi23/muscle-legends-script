-- Inicialización del estado global
getgenv().AA_STATE = {
    AutoHit = false,
    AuraHit = false,
    LineOfSight = false
}

-- Funciones simuladas (reemplaza con tu lógica real)
local function runAutoHit()
    while getgenv().AA_STATE.AutoHit do
        print("AutoHit activo")
        task.wait(0.5)
    end
end

local function runAuraHit()
    while getgenv().AA_STATE.AuraHit do
        print("AuraHit activo")
        task.wait(0.5)
    end
end

-- GUI principal
local gui = Instance.new("ScreenGui")
gui.Name = "LuisHub"
gui.ResetOnSpawn = false
gui.Parent = game:GetService("CoreGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 160, 0, 140)
frame.Position = UDim2.new(0, 20, 0, 80)
frame.BackgroundColor3 = Color3.fromRGB(30,30,30)
frame.BorderSizePixel = 0
frame.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 28)
title.Text = "Luis Hub"
title.BackgroundColor3 = Color3.fromRGB(45,45,45)
title.TextColor3 = Color3.new(1,1,1)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.Parent = frame

-- Botón AutoHit
local btnAuto = Instance.new("TextButton")
btnAuto.Size = UDim2.new(0, 140, 0, 28)
btnAuto.Position = UDim2.new(0, 10, 0, 36)
btnAuto.Text = "AutoHit: OFF"
btnAuto.BackgroundColor3 = Color3.fromRGB(50,50,50)
btnAuto.TextColor3 = Color3.new(1,1,1)
btnAuto.Font = Enum.Font.Gotham
btnAuto.TextSize = 14
btnAuto.Parent = frame

btnAuto.MouseButton1Click:Connect(function()
    getgenv().AA_STATE.AutoHit = not getgenv().AA_STATE.AutoHit
    btnAuto.Text = "AutoHit: " .. (getgenv().AA_STATE.AutoHit and "ON" or "OFF")
    if getgenv().AA_STATE.AutoHit then
        task.spawn(runAutoHit)
    end
end)

-- Botón AuraHit
local btnAura = Instance.new("TextButton")
btnAura.Size = UDim2.new(0, 140, 0, 28)
btnAura.Position = UDim2.new(0, 10, 0, 70)
btnAura.Text = "AuraHit: OFF"
btnAura.BackgroundColor3 = Color3.fromRGB(50,50,50)
btnAura.TextColor3 = Color3.new(1,1,1)
btnAura.Font = Enum.Font.Gotham
btnAura.TextSize = 14
btnAura.Parent = frame

btnAura.MouseButton1Click:Connect(function()
    getgenv().AA_STATE.AuraHit = not getgenv().AA_STATE.AuraHit
    btnAura.Text = "AuraHit: " .. (getgenv().AA_STATE.AuraHit and "ON" or "OFF")
    if getgenv().AA_STATE.AuraHit then
        task.spawn(runAuraHit)
    end
end)

-- Botón LineOfSight (placeholder)
local btnLOS = Instance.new("TextButton")
btnLOS.Size = UDim2.new(0, 140, 0, 28)
btnLOS.Position = UDim2.new(0, 10, 0, 104)
btnLOS.Text = "LineOfSight: OFF"
btnLOS.BackgroundColor3 = Color3.fromRGB(50,50,50)
btnLOS.TextColor3 = Color3.new(1,1,1)
btnLOS.Font = Enum.Font.Gotham
btnLOS.TextSize = 14
btnLOS.Parent = frame

btnLOS.MouseButton1Click:Connect(function()
    getgenv().AA_STATE.LineOfSight = not getgenv().AA_STATE.LineOfSight
    btnLOS.Text = "LineOfSight: " .. (getgenv().AA_STATE.LineOfSight and "ON" or "OFF")
end)
