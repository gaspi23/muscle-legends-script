-- 📦 Servicios
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")

-- ⚙️ Variables
local autoHitEnabled = false
local reach = 20
local whitelist = {LocalPlayer.Name}

-- 🧠 Funciones
local function isEnemy(target)
    if not target or not target:FindFirstChild("HumanoidRootPart") then return false end
    local name = target.Name
    if table.find(whitelist, name) then return false end
    local dist = (target.HumanoidRootPart.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
    return dist <= reach
end

local function getTool()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChildOfClass("Tool")
end

-- 🔁 Loop AutoHit
RunService.RenderStepped:Connect(function()
    if not autoHitEnabled then return end
    local tool = getTool()
    if not tool or not tool:FindFirstChild("Handle") then return end

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and isEnemy(player.Character) then
            tool:Activate()
            break
        end
    end
end)

-- 🖥️ UI Panel
local gui = Instance.new("ScreenGui", game.CoreGui)
local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 240, 0, 180)
frame.Position = UDim2.new(0, 20, 0, 100)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true

local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1, 0, 0, 30)
title.Text = "⚔️ AutoHit Hub"
title.TextColor3 = Color3.new(1, 1, 1)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 18

local toggle = Instance.new("TextButton", frame)
toggle.Size = UDim2.new(0, 220, 0, 30)
toggle.Position = UDim2.new(0, 10, 0, 40)
toggle.Text = "Activar AutoHit: OFF"
toggle.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
toggle.TextColor3 = Color3.new(1, 1, 1)
toggle.Font = Enum.Font.Gotham
toggle.TextSize = 16

toggle.MouseButton1Click:Connect(function()
    autoHitEnabled = not autoHitEnabled
    toggle.Text = "Activar AutoHit: " .. (autoHitEnabled and "ON" or "OFF")
end)

local reachLabel = Instance.new("TextLabel", frame)
reachLabel.Size = UDim2.new(0, 220, 0, 20)
reachLabel.Position = UDim2.new(0, 10, 0, 75)
reachLabel.Text = "Reach: " .. reach
reachLabel.TextColor3 = Color3.new(1, 1, 1)
reachLabel.BackgroundTransparency = 1
reachLabel.Font = Enum.Font.Gotham
reachLabel.TextSize = 14

local minus = Instance.new("TextButton", frame)
minus.Size = UDim2.new(0, 30, 0, 20)
minus.Position = UDim2.new(0, 10, 0, 100)
minus.Text = "-"
minus.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
minus.TextColor3 = Color3.new(1, 1, 1)
minus.Font = Enum.Font.Gotham
minus.TextSize = 14

minus.MouseButton1Click:Connect(function()
    reach = math.max(1, reach - 1)
    reachLabel.Text = "Reach: " .. reach
end)

local plus = Instance.new("TextButton", frame)
plus.Size = UDim2.new(0, 30, 0, 20)
plus.Position = UDim2.new(0, 50, 0, 100)
plus.Text = "+"
plus.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
plus.TextColor3 = Color3.new(1, 1, 1)
plus.Font = Enum.Font.Gotham
plus.TextSize = 14

plus.MouseButton1Click:Connect(function()
    reach = reach + 1
    reachLabel.Text = "Reach: " .. reach
end)

local inputBox = Instance.new("TextBox", frame)
inputBox.Size = UDim2.new(0, 130, 0, 20)
inputBox.Position = UDim2.new(0, 90, 0, 100)
inputBox.PlaceholderText = "Escribe reach manual..."
inputBox.Text = ""
inputBox.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
inputBox.TextColor3 = Color3.new(1, 1, 1)
inputBox.Font = Enum.Font.Gotham
inputBox.TextSize = 14

inputBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        local val = tonumber(inputBox.Text)
        if val and val >= 1 then
            reach = val
            reachLabel.Text = "Reach: " .. reach
            inputBox.Text = ""
        end
    end
end)
