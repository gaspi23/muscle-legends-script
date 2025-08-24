-- 📦 Servicios
local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- ⚙️ Configuración
local autoHit = false
local auraHit = false
local reach = 20
local auraRadius = 15
local whitelist = {[LocalPlayer.Name] = true}

-- 🔍 Validación
local function validTarget(player)
    if not player or player == LocalPlayer or whitelist[player.Name] then return false end
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return false end
    local dist = (hrp.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
    return dist <= reach
end

local function getTool()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Tool")
end

-- 🎯 Loop
local currentTarget
RS.Heartbeat:Connect(function()
    local tool = getTool()
    if not tool or not tool:FindFirstChild("Handle") then return end

    if autoHit then
        for _,plr in ipairs(Players:GetPlayers()) do
            if validTarget(plr) then
                tool:Activate()
                break
            end
        end
    end

    if auraHit then
        if not (currentTarget and validTarget(currentTarget)) then
            currentTarget = nil
            local closest, minDist
            for _,plr in ipairs(Players:GetPlayers()) do
                if validTarget(plr) then
                    local dist = (plr.Character.HumanoidRootPart.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
                    if dist <= auraRadius and (not minDist or dist < minDist) then
                        closest, minDist = plr, dist
                    end
                end
            end
            currentTarget = closest
        end
        if currentTarget then tool:Activate() end
    end
end)

-- 🖥 GUI
local gui = Instance.new("ScreenGui")
gui.Name = "AutoAuraHub"
gui.ResetOnSpawn = false
gui.Parent = game.CoreGui

local function makeBtn(text,y,callback)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0,220,0,30)
    b.Position = UDim2.new(0,20,0,y)
    b.Text = text
    b.BackgroundColor3 = Color3.fromRGB(50,50,50)
    b.TextColor3 = Color3.new(1,1,1)
    b.Parent = gui
    b.MouseButton1Click:Connect(callback)
    return b
end

local autoBtn = makeBtn("AutoHit: OFF",100,function()
    autoHit = not autoHit
    autoBtn.Text = "AutoHit: "..(autoHit and "ON" or "OFF")
end)

local auraBtn = makeBtn("AuraHit: OFF",140,function()
    auraHit = not auraHit
    auraBtn.Text = "AuraHit: "..(auraHit and "ON" or "OFF")
end)

local reachLabel = makeBtn("Reach: "..reach,180,function() end)
reachLabel.AutoButtonColor = false

makeBtn("Reach -",220,function()
    reach = math.max(1,reach-1)
    reachLabel.Text = "Reach: "..reach
end)

makeBtn("Reach +",260,function()
    reach = reach+1
    reachLabel.Text = "Reach: "..reach
end)
