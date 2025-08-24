-- 📦 Estado global persistente
getgenv().AA_STATE = getgenv().AA_STATE or {
    AutoHit = false,
    AuraHit = false,
    Reach = 20,
    AuraRadius = 15,
    MinHitInterval = 0.20,
    IgnoreTeammates = true,
    AutoEquip = true
}
getgenv().AA_WHITELIST = getgenv().AA_WHITELIST or { [game.Players.LocalPlayer.Name] = true }

-- 📦 Servicios
local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local LP = Players.LocalPlayer
local WS = game:GetService("Workspace")

-- 📦 Utilidades
local function now() return os.clock() end
local function getChar(plr) plr = plr or LP; return plr.Character end
local function getHRP(c) return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum(c) return c and c:FindFirstChildOfClass("Humanoid") end
local function alive(c) local h = getHum(c); return h and h.Health > 0 end
local function sameTeam(a,b) if not a or not b then return false end if a.Neutral or b.Neutral then return false end return a.Team == b.Team end
local function dist(a,b) return (a-b).Magnitude end

-- 📦 Herramienta
local lastHitAt = 0
local function getTool()
    local char = getChar()
    if not char then return nil end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then return tool end
    if getgenv().AA_STATE.AutoEquip then
        local bp = LP:FindFirstChildOfClass("Backpack")
        if bp then
            local t = bp:FindFirstChildOfClass("Tool")
            if t then
                local hum = getHum(char)
                if hum then pcall(function() hum:EquipTool(t) end) end
                return char:FindFirstChildOfClass("Tool")
            end
        end
    end
    return nil
end

local function canHit(tool)
    if not tool then return false end
    if (now() - lastHitAt) < getgenv().AA_STATE.MinHitInterval then return false end
    return true
end

local function doHit(tool)
    pcall(function() tool:Activate() end)
    lastHitAt = now()
end

-- 📦 Targeting
local function validEnemy(plr, range)
    if not plr or plr == LP then return false end
    if getgenv().AA_WHITELIST[plr.Name] then return false end
    if getgenv().AA_STATE.IgnoreTeammates and sameTeam(plr, LP) then return false end
    local c = getChar(plr)
    if not alive(c) then return false end
    local thrp = getHRP(c)
    if not thrp then return false end
    return dist(thrp.Position, getHRP(getChar())).Magnitude <= range
end

local function closestEnemy(range)
    local myChar = getChar()
    local myHRP = getHRP(myChar)
    if not myHRP then return nil end
    local best, bestD
    for _,plr in ipairs(Players:GetPlayers()) do
        if validEnemy(plr, range) then
            local d = dist(getHRP(plr.Character).Position, myHRP.Position)
            if not bestD or d < bestD then best, bestD = plr, d end
        end
    end
    return best
end

-- 📦 Loop principal
local currentTarget
RS.Heartbeat:Connect(function()
    local S = getgenv().AA_STATE
    local char = getChar()
    local myHRP = getHRP(char)
    if not myHRP then return end
    local tool = getTool()
    if not tool then return end

    -- AutoHit
    if S.AutoHit and canHit(tool) then
        for _,plr in ipairs(Players:GetPlayers()) do
            if validEnemy(plr, S.Reach) then
                doHit(tool)
                break
            end
        end
    end

    -- AuraHit
    if S.AuraHit then
        if not (currentTarget and validEnemy(currentTarget, S.AuraRadius)) then
            currentTarget = closestEnemy(S.AuraRadius)
        end
        if currentTarget and canHit(tool) then
            doHit(tool)
        end
    end
end)

-- 📦 GUI
local gui = Instance.new("ScreenGui")
gui.Name = "LuisHub"
gui.ResetOnSpawn = false
gui.Parent = game.CoreGui

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(180, 140)
frame.Position = UDim2.new(0, 20, 0, 80)
frame.BackgroundColor3 = Color3.fromRGB(30,30,30)
frame.Parent = gui

local function makeBtn(text, y, toggleKey)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 160, 0, 28)
    b.Position = UDim2.new(0, 10, 0, y)
    b.Text = text..": OFF"
    b.BackgroundColor3 = Color3.fromRGB(50,50,50)
    b.TextColor3 = Color3.new(1,1,1)
    b.Parent = frame
    b.MouseButton1Click:Connect(function()
        getgen
