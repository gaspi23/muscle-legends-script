-- 📦 Servicios
local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")

-- ⚙️ Config
local autoHit = false
local auraHit = false
local reach = 20
local auraRadius = 15
local whitelist = {[LocalPlayer.Name] = true}

-- 🔍 Funciones utilitarias
local function validTarget(player)
    if not player or player == LocalPlayer or whitelist[player.Name] then return false end
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return false end
    local dist = (hrp.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
    if dist > reach then return false end
    return true
end

local function getTool()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChildOfClass("Tool")
end

local currentTarget

-- 🔁 Loop
RS.Heartbeat:Connect(function()
    local tool = getTool()
    if not tool or not tool:FindFirstChild("Handle") then return end

    -- AutoHit directo
    if autoHit then
        for _,plr in ipairs(Players:GetPlayers()) do
            if validTarget(plr) then
                tool:Activate()
                break
            end
        end
    end

    -- AuraHit persistente
    if auraHit then
        -- Mantener target si es válido
        if not (currentTarget and validTarget(currentTarget)) then
            currentTarget = nil
            -- Buscar nuevo target más cercano en radio Aura
            local closest, minDist
            for _,plr in ipairs(Players:GetPlayers()) do
                if not whitelist[plr.Name] and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                    local dist = (plr.Character.HumanoidRootPart.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
                    if dist <= auraRadius and (not minDist or dist < minDist) and validTarget(plr) then
                        closest, minDist = plr, dist
                    end
                end
            end
            currentTarget = closest
        end
        if currentTarget then
            tool:Activate()
        end
    end
end)

-- 🖥 GUI rápida
local gui = Instance.new("ScreenGui", game.CoreGui)
local function makeBtn(text,pos,callback)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0,220,0,30)
    b.Position = pos
    b.BackgroundColor3 = Color3.fromRGB(50,50,50)
    b.TextColor3 = Color3.new(1,1,1)
    b.Text = text
    b.Parent = gui
    b.MouseButton1Click:Connect(callback)
    return b
end

local autoBtn = makeBtn("AutoHit: OFF", UDim2.new(0,20,0,100), function()
    autoHit = not autoHit
    autoBtn.Text = "AutoHit: "..(autoHit and "ON" or "OFF")
end)
local auraBtn = makeBtn("AuraHit: OFF", UDim2.new(0,20,0,140), function()
    auraHit = not auraHit
    auraBtn.Text = "AuraHit: "..(auraHit and "ON" or "OFF")
end)
