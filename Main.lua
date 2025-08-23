-- 📦 UI + AutoHit Modular
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

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
local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
local Frame = Instance.new("Frame", ScreenGui)
Frame.Size = UDim2.new(0, 220, 0, 140)
Frame.Position = UDim2.new(0, 20, 0, 100)
Frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
Frame.BorderSizePixel = 0
Frame.Active = true
Frame.Draggable = true

local Title = Instance.new("TextLabel", Frame)
Title.Size = UDim2.new(1, 0, 0, 30)
Title.Text = "⚔️ AutoHit Hub"
Title.TextColor3 = Color3.new(1, 1, 1)
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.GothamBold
Title.TextSize = 18

local Toggle = Instance.new("TextButton", Frame)
Toggle.Size = UDim2.new(0, 200, 0, 30)
Toggle.Position = UDim2.new(0, 10, 0, 40)
Toggle.Text = "Activar AutoHit: OFF"
Toggle.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
Toggle.TextColor3 = Color3.new(1, 1, 1)
Toggle.Font = Enum.Font.Gotham
Toggle.TextSize = 16

Toggle.MouseButton1Click:Connect(function()
    autoHitEnabled = not autoHitEnabled
    Toggle.Text = "Activar AutoHit: " .. (autoHitEnabled and "ON" or "OFF")
end)

local SliderLabel = Instance.new("TextLabel", Frame)
SliderLabel.Size = UDim2.new(0, 200, 0, 20)
SliderLabel.Position = UDim2.new(0, 10, 0, 80)
SliderLabel.Text = "Reach: " .. reach
SliderLabel.TextColor3 = Color3.new(1, 1, 1)
SliderLabel.BackgroundTransparency = 1
SliderLabel.Font = Enum.Font.Gotham
SliderLabel.TextSize = 14

local Slider = Instance.new("TextButton", Frame)
Slider.Size = UDim2.new(0, 200, 0, 20)
Slider.Position = UDim2.new(0, 10, 0, 105)
Slider.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
Slider.Text = "⬅️ Ajustar Reach ⮕"
Slider.TextColor3 = Color3.new(1, 1, 1)
Slider.Font = Enum.Font.Gotham
Slider.TextSize = 14

Slider.MouseButton1Click:Connect(function()
    reach = reach + 5
    if reach > 50 then reach = 10 end
    SliderLabel.Text = "Reach: " .. reach
end)
