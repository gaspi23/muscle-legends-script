-- 📦 Estado global persistente
getgenv().AA_STATE = getgenv().AA_STATE or {
    AutoHit = false,
    AuraHit = false,
    Reach = 20,
    AuraRadius = 15,
    MinHitInterval = 0.05, -- 🔥 Golpeo ultra rápido (50 ms)
    IgnoreTeammates = true,
    AutoEquip = true
}
getgenv().AA_WHITELIST = getgenv().AA_WHITELIST or { [game.Players.LocalPlayer.Name] = true }

-- 📦 Servicios
local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local LP = Players.LocalPlayer

-- 📦 Utilidades optimizadas
local function now() return os.clock() end
local function getChar(p) p = p or LP return p.Character end
local function getHRP(c) return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum(c) return c and c:FindFirstChildOfClass("Humanoid") end
local function alive(c) local h=getHum(c) return h and h.Health>0 end
local function sameTeam(a,b) if not a or not b then return false end if a.Neutral or b.Neutral then return false end return a.Team==b.Team end
local function dist(a,b) return (a-b).Magnitude end

-- 📦 Tool
local lastHitAt = 0
local function getTool()
    local char = getChar()
    if not char then return nil end
    local t = char:FindFirstChildOfClass("Tool")
    if t then return t end
    if getgenv().AA_STATE.AutoEquip then
        local bp = LP:FindFirstChildOfClass("Backpack")
        if bp then
            local tb = bp:FindFirstChildOfClass("Tool")
            if tb then
                local hum = getHum(char)
                if hum then pcall(function() hum:EquipTool(tb) end) end
                task.wait()
                return char:FindFirstChildOfClass("Tool")
            end
        end
    end
    return nil
end

local function canHit(tool)
    if not tool then return false end
    if (now() - lastHitAt) < getgenv().AA_STATE.MinHitInterval then return false end
    local ok,en = pcall(function() return tool.Enabled end)
    if ok and en == false then return false end
    return true
end

local function doHit(tool)
    pcall(function() tool:Activate() end)
    lastHitAt = now()
end

-- 📦 Targeting
local function validEnemy(plr, range, myHRP)
    if not plr or plr == LP then return false end
    if getgenv().AA_WHITELIST[plr.Name] then return false end
    if getgenv().AA_STATE.IgnoreTeammates and sameTeam(plr, LP) then return false end
    local c = getChar(plr)
    if not alive(c) then return false end
    local thrp = getHRP(c)
    if not thrp or not myHRP then return false end
    return dist(thrp.Position, myHRP.Position) <= range
end

local function closestEnemy(range, myHRP)
    local best,bestD
    for _,p in ipairs(Players:GetPlayers()) do
        if validEnemy(p, range, myHRP) then
            local d = dist(getHRP(p.Character).Position, myHRP.Position)
            if not bestD or d < bestD then best,bestD = p,d end
        end
    end
    return best
end

-- ♻ Loop único optimizado
local currentTarget
RS.Stepped:Connect(function()
    local S = getgenv().AA_STATE
    local char = getChar()
    local myHRP = getHRP(char)
    if not myHRP then return end
    local tool = getTool()
    if not tool then return end

    if S.AutoHit and canHit(tool) then
        for _,p in ipairs(Players:GetPlayers()) do
            if validEnemy(p, S.Reach, myHRP) then
                doHit(tool)
                break
            end
        end
    end

    if S.AuraHit then
        if not (currentTarget and validEnemy(currentTarget, S.AuraRadius, myHRP)) then
            currentTarget = closestEnemy(S.AuraRadius, myHRP)
        end
        if currentTarget and canHit(tool) then
            doHit(tool)
        end
    end
end)

-- 🎯 HUD minimalista
pcall(function()
    local prev = (game.CoreGui and game.CoreGui:FindFirstChild("LuisHUD"))
    if prev then prev:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "LuisHUD"
local ok = pcall(function() gui.Parent = game.CoreGui end)
if not ok then gui.Parent = LP:WaitForChild("PlayerGui") end

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(140, 90)
frame.Position = UDim2.new(0, 10, 0, 60)
frame.BackgroundColor3 = Color3.fromRGB(25,25,25)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = gui

local function makeBtn(label, key, y)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 120, 0, 26)
    b.Position = UDim2.new(0, 10, 0, y)
    b.Text = label..": "..(getgenv().AA_STATE[key] and "ON" or "OFF")
    b.BackgroundColor3 = Color3.fromRGB(60,60,60)
    b.TextColor3 = Color3.new(1,1,1)
    b.Parent = frame
    b.MouseButton1Click:Connect(function()
        S = getgenv().AA_STATE
        S[key] = not S[key]
        b.Text = label..": "..(S[key] and "ON" or "OFF")
    end)
end

makeBtn("AutoHit","AutoHit",10)
makeBtn("AuraHit","AuraHit",42)
