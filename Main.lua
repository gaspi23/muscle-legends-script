-- Auto/Aura Hit PRO — estable, persistente y con GUI
-- Requiere: ejecutor con HttpGet, Parent en CoreGui permitido
-- Autor: Luis + Copilot

-- ========= Servicios =========
local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- ========= Estado/Persistencia =========
getgenv().AA_STATE = getgenv().AA_STATE or {
    AutoHit = false,
    AuraHit = false,
    Reach = 20,            -- radio para AutoHit
    AuraRadius = 15,       -- radio para AuraHit
    MinHitInterval = 0.20, -- cooldown mínimo entre Tool:Activate()
    UseLineOfSight = false,
    IgnoreTeammates = true,
    AutoEquip = true
}
local S = getgenv().AA_STATE
getgenv().AA_WHITELIST = getgenv().AA_WHITELIST or { [LocalPlayer.Name] = true }

-- ========= Utilidades =========
local function now() return os.clock() end

local function getCharacter(plr)
    plr = plr or LocalPlayer
    local c = plr.Character
    if c and c.Parent then return c end
    return nil
end

local function getHRP(char)
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHum(char)
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function alive(char)
    local h = getHum(char)
    return h and h.Health > 0
end

local function sameTeam(a, b)
    if not a or not b then return false end
    if a.Neutral or b.Neutral then return false end
    return a.Team ~= nil and b.Team ~= nil and a.Team == b.Team
end

-- Línea de visión
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Blacklist
local function hasLineOfSight(fromPos, toPos, ignoreList)
    rayParams.FilterDescendantsInstances = ignoreList
    local res = Workspace:Raycast(fromPos, toPos - fromPos, rayParams)
    -- true si no hay colisión entre ambos
    return res == nil
end

-- ========= Herramienta =========
local lastHitAt = 0
local function getTool()
    local char = getCharacter()
    if not char then return nil end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then return tool end
    if S.AutoEquip then
        local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
        if backpack then
            local t = backpack:FindFirstChildOfClass("Tool")
            if t then
                pcall(function() t.Parent = char end)
                return char:FindFirstChildOfClass("Tool")
            end
        end
    end
    return nil
end

local function canHit(tool)
    if not tool then return false end
    if not tool:FindFirstChild("Handle") then return false end
    local t = now()
    if (t - lastHitAt) < S.MinHitInterval then return false end
    if typeof(tool.Enabled) == "boolean" and tool.Enabled == false then return false end
    return true
end

local function doHit(tool)
    if not tool then return false end
    local ok = pcall(function() tool:Activate() end)
    if ok then lastHitAt = now() end
    return ok
end

-- ========= Validación de objetivos =========
local function inRange(a, b, maxDist)
    return (a - b).Magnitude <= maxDist
end

local function isValidEnemy(plr, myChar, myHRP)
    if not plr or plr == LocalPlayer then return false end
    if getgenv().AA_WHITELIST[plr.Name] then return false end
    if S.IgnoreTeammates and sameTeam(plr, LocalPlayer) then return false end

    local c = getCharacter(plr)
    if not alive(c) then return false end
    local thrp = getHRP(c)
    if not thrp or not myHRP then return false end

    local withinReach = inRange(thrp.Position, myHRP.Position, S.Reach)
    if not withinReach then return false end

    if S.UseLineOfSight then
        local ignore = { myChar, LocalPlayer.Character, Workspace.CurrentCamera }
        if not hasLineOfSight(myHRP.Position, thrp.Position, ignore) then return false end
    end
    return true
end

local function isValidEnemyAura(plr, myChar, myHRP)
    if not plr or plr == LocalPlayer then return false end
    if getgenv().AA_WHITELIST[plr.Name] then return false end
    if S.IgnoreTeammates and sameTeam(plr, LocalPlayer) then return false end

    local c = getCharacter(plr)
    if not alive(c) then return false end
    local thrp = getHRP(c)
    if not thrp or not myHRP then return false end

    local withinAura = inRange(thrp.Position, myHRP.Position, S.AuraRadius)
    if not withinAura then return false end

    if S.UseLineOfSight then
        local ignore = { myChar, LocalPlayer.Character, Workspace.CurrentCamera }
        if not hasLineOfSight(myHRP.Position, thrp.Position, ignore) then return false end
    end
    return true
end

local function findClosestEnemy(maxRadius, validator)
    local myChar = getCharacter()
    local myHRP = getHRP(myChar)
    if not myHRP then return nil end
    local best, bestDist
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local c = getCharacter(plr)
            local thrp = getHRP(c)
            if thrp then
                local d = (thrp.Position - myHRP.Position).Magnitude
                if d <= maxRadius and validator(plr, myChar, myHRP) then
                    if not bestDist or d < bestDist then
                        best, bestDist = plr, d
                    end
                end
            end
        end
    end
    return best
end

-- ========= Respawn y limpieza =========
local connections = {}
local function bind(event, fn)
    local conn = event:Connect(fn)
    table.insert(connections, conn)
    return conn
end

local function cleanup()
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    connections = {}
    local gui = (game.CoreGui and game.CoreGui:FindFirstChild("AutoAuraHub")) or (LocalPlayer.PlayerGui and LocalPlayer.PlayerGui:FindFirstChild("AutoAuraHub"))
    if gui then pcall(function() gui:Destroy() end) end
end

bind(LocalPlayer.CharacterAdded, function()
    -- Evita referencias muertas al respawnear
    currentTarget = nil
end)

-- ========= Loop principal (cadencia fija) =========
local currentTarget
local nextSearchAt = 0
local searchPeriod = 0.15
local accum, fixed = 0, 1/90

bind(RS.Heartbeat, function(dt)
    accum += dt
    while accum >= fixed do
        local myChar = getCharacter()
        local myHRP = getHRP(myChar)
        if not myHRP then accum -= fixed; break end

        local tool = getTool()
        if tool then
            -- AutoHit: golpea si hay cualquiera en Reach
            if S.AutoHit and canHit(tool) then
                for _, plr in ipairs(Players:GetPlayers()) do
                    if isValidEnemy(plr, myChar, myHRP) then
                        doHit(tool); break
                    end
                end
            end

            -- AuraHit: objetivo persistente en AuraRadius
            if S.AuraHit then
                local t = now()
                if (not currentTarget) or (not isValidEnemyAura(currentTarget, myChar, myHRP)) or (t >= nextSearchAt) then
                    currentTarget = findClosestEnemy(S.AuraRadius, isValidEnemyAura)
                    nextSearchAt = t + searchPeriod
                end
                if currentTarget and canHit(tool) then
                    doHit(tool)
                end
            end
        end

        accum -= fixed
    end
end)

-- ========= GUI =========
local function safeParent(gui)
    gui.ResetOnSpawn = false
    local ok = pcall(function() gui.Parent = game.CoreGui end)
    if not ok then
        local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui")
        gui.Parent = pg
    end
end

-- destruye instancias previas
local old = (game.CoreGui and game.CoreGui:FindFirstChild("AutoAuraHub")) or (LocalPlayer.PlayerGui and LocalPlayer.PlayerGui:FindFirstChild("AutoAuraHub"))
if old then pcall(function() old:Destroy() end) end

local gui = Instance.new("ScreenGui")
gui.Name = "AutoAuraHub"
safeParent(gui)

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(280, 250)
frame.Position = UDim2.new(0, 20, 0, 100)
frame.BackgroundColor3 = Color3.fromRGB(28,28,28)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = gui

local function mkLabel(text, y)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -20, 0, 22)
    l.Position = UDim2.new(0, 10, 0, y)
    l.BackgroundTransparency = 1
    l.TextColor3 = Color3.new(1,1,1)
    l.Font = Enum.Font.GothamBold
    l.TextSize = 16
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Text = text
    l.Parent = frame
    return l
end

local function mkBtn(text, x, y, cb)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 130, 0, 28)
    b.Position = UDim2.new(0, x, 0, y)
    b.Text = text
    b.BackgroundColor3 = Color3.fromRGB(50,50,50)
    b.TextColor3 = Color3.new(1,1,1)
    b.Font = Enum.Font.Gotham
    b.TextSize = 14
    b.Parent = frame
    b.MouseButton1Click:Connect(cb)
    return b
end

local title = mkLabel("⚔️ Auto/Aura Hit PRO", 6)

local btnAuto = mkBtn("AutoHit: OFF", 10, 36, function()
    S.AutoHit = not S.AutoHit
    btnAuto.Text = "AutoHit: "..(S.AutoHit and "ON" or "OFF")
end)

local btnAura = mkBtn("AuraHit: OFF", 150, 36, function()
    S.AuraHit = not S.AuraHit
    btnAura.Text = "AuraHit: "..(S.AuraHit and "ON" or "OFF")
end)

local btnLOS = mkBtn("LineOfSight: OFF", 10, 70, function()
    S.UseLineOfSight = not S.UseLineOfSight
    btnLOS.Text = "LineOfSight: "..(S.UseLineOfSight and "ON" or "OFF")
end)

local btnTeam = mkBtn("Ignorar Team: ON", 150, 70, function()
    S.IgnoreTeammates = not S.IgnoreTeammates
    btnTeam.Text = "Ignorar Team: "..(S.IgnoreTeammates and "ON" or "OFF")
end)

local btnEquip = mkBtn("AutoEquip: ON", 10, 104, function()
    S.AutoEquip = not S.AutoEquip
    btnEquip.Text = "AutoEquip: "..(S.AutoEquip and "ON" or "OFF")
end)

local lblReach = mkLabel("", 138)
local btnRMinus = mkBtn("Reach -", 10, 162, function()
    S.Reach = math.max(1, S.Reach - 1); lblReach.Text = ("Reach: %d"):format(S.Reach)
end)
local btnRPlus = mkBtn("Reach +", 150, 162, function()
    S.Reach = S.Reach + 1; lblReach.Text = ("Reach: %d"):format(S.Reach)
end)

local lblAura = mkLabel("", 196)
local btnAMinus = mkBtn("Aura -", 10, 220, function()
    S.AuraRadius = math.max(1, S.AuraRadius - 1); lblAura.Text = ("Aura: %d"):format(S.AuraRadius)
end)
local btnAPlus = mkBtn("Aura +", 150, 220, function()
    S.AuraRadius = S.AuraRadius + 1; lblAura.Text = ("Aura: %d"):format(S.AuraRadius)
end)

local lblRate = mkLabel("", 248)
local btnRateMinus = mkBtn("Rate -", 10, 272, function()
    S.MinHitInterval = math.max(0.05, S.MinHitInterval - 0.05)
    lblRate.Text = ("Intervalo: %.2fs"):format(S.MinHitInterval)
end)
local btnRatePlus = mkBtn("Rate +", 150, 272, function()
    S.MinHitInterval = math.min(1.0, S.MinHitInterval + 0.05)
    lblRate.Text = ("Intervalo: %.2fs"):format(S.MinHitInterval)
end)

local lblTarget = mkLabel("Target: —", 306)

-- init textos
btnAuto.Text = "AutoHit: "..(S.AutoHit and "ON" or "OFF")
btnAura.Text = "AuraHit: "..(S.AuraHit and "ON" or "OFF")
btnLOS.Text  = "LineOfSight: "..(S.UseLineOfSight and "ON" or "OFF")
btnTeam.Text = "Ignorar Team: "..(S.IgnoreTeammates and "ON" or "OFF")
btnEquip.Text= "AutoEquip: "..(S.AutoEquip and "ON" or "OFF")
lblReach.Text= ("Reach: %d"):format(S.Reach)
lblAura.Text = ("Aura: %d"):format(S.AuraRadius)
lblRate.Text = ("Intervalo: %.2fs"):format(S.MinHitInterval)

-- Actualiza nombre del target ~10Hz sin cargar loop físico
bind(RS.RenderStepped, function(dt)
    local acc = acc or 0
    acc = (acc or 0) + dt
    if acc >= 0.1 then
        lblTarget.Text = "Target: "..(currentTarget and currentTarget.Name or "—")
        acc = 0
    end
end)

-- Kill-switch (Supr/Del): destruye GUI y detiene eventos
bind(game:GetService("UserInputService").InputBegan, function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.Delete then
        cleanup()
    end
end)

-- Fin del script
