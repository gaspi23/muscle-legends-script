-- Auto/Aura Hit PRO — estable, con GUI y depuración en vivo
-- Autor: Luis + Copilot

-- ========= Estado global =========
getgenv().AA_STATE = getgenv().AA_STATE or {
    AutoHit = false,
    AuraHit = false,
    Reach = 20,              -- rango AutoHit
    AuraRadius = 15,         -- rango AuraHit
    MinHitInterval = 0.20,   -- s entre activaciones
    UseLineOfSight = false,  -- raycast opcional
    IgnoreTeammates = true,  -- evita teammates
    AutoEquip = true,        -- equipar herramienta auto
    RequireHandle = false,   -- si tu juego exige Handle, pon true
    ToolNameFilter = ""      -- filtra por substring del nombre de la Tool (vacío = cualquiera)
}
getgenv().AA_WHITELIST = getgenv().AA_WHITELIST or { [game:GetService("Players").LocalPlayer.Name] = true }

-- ========= Servicios =========
local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local WS = game:GetService("Workspace")
local UIS = game:GetService("UserInputService")
local LP  = Players.LocalPlayer

-- ========= Utilidades núcleo =========
local function now() return os.clock() end
local function getChar(plr) plr = plr or LP; local c = plr.Character; if c and c.Parent then return c end end
local function getHRP(c) return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum(c) return c and c:FindFirstChildOfClass("Humanoid") end
local function alive(c) local h = getHum(c); return h and h.Health > 0 end
local function sameTeam(a,b) if not a or not b then return false end if a.Neutral or b.Neutral then return false end return a.Team and b.Team and a.Team == b.Team end
local function dist(a,b) return (a-b).Magnitude end

-- Línea de visión
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Blacklist
local function hasLOS(fromPos, toPos, ignoreList)
    rayParams.FilterDescendantsInstances = ignoreList
    return WS:Raycast(fromPos, toPos - fromPos, rayParams) == nil
end

-- ========= Herramienta =========
local lastHitAt = 0
local function passesFilter(tool, S)
    if not tool then return false end
    if S.ToolNameFilter ~= "" and not string.find(string.lower(tool.Name), string.lower(S.ToolNameFilter), 1, true) then
        return false
    end
    if S.RequireHandle and not tool:FindFirstChild("Handle") then return false end
    return true
end

local function getTool(S)
    local char = getChar()
    if not char then return nil end
    -- Preferir tool ya equipada
    local eq = char:FindFirstChildOfClass("Tool")
    if passesFilter(eq, S) then return eq end
    -- AutEquip desde Backpack
    if S.AutoEquip then
        local bp = LP:FindFirstChildOfClass("Backpack")
        if bp then
            -- Busca por filtro primero
            local candidate
            for _,t in ipairs(bp:GetChildren()) do
                if t:IsA("Tool") and passesFilter(t, S) then candidate = t break end
            end
            if not candidate then
                candidate = bp:FindFirstChildOfClass("Tool")
            end
            if candidate then
                local hum = getHum(char)
                if hum then pcall(function() hum:EquipTool(candidate) end) end
                -- fallback
                if candidate.Parent == bp then pcall(function() candidate.Parent = char end) end
                task.wait() -- dar un frame para equip
                return char:FindFirstChildOfClass("Tool")
            end
        end
    end
    return nil
end

local function canHit(S, tool)
    if not tool then return false, "NoTool" end
    if S.RequireHandle and not tool:FindFirstChild("Handle") then return false, "NoHandle" end
    if (now() - lastHitAt) < S.MinHitInterval then return false, "Cooldown" end
    -- Si la Tool expone .Enabled y está false, esperamos
    local ok, enabled = pcall(function() return tool.Enabled end)
    if ok and enabled == false then return false, "ToolDisabled" end
    return true
end

local function doHit(tool)
    local ok = pcall(function() tool:Activate() end)
    if ok then lastHitAt = now() end
    return ok
end

-- ========= Targeting =========
local function validEnemy(plr, S, myChar, myHRP, range)
    if not plr or plr == LP then return false end
    if getgenv().AA_WHITELIST[plr.Name] then return false end
    if S.IgnoreTeammates and sameTeam(plr, LP) then return false end
    local c = getChar(plr); if not alive(c) then return false end
    local thrp = getHRP(c); if not thrp or not myHRP then return false end
    if dist(thrp.Position, myHRP.Position) > range then return false end
    if S.UseLineOfSight then
        local ignore = { myChar, LP.Character, WS.CurrentCamera }
        if not hasLOS(myHRP.Position, thrp.Position, ignore) then return false end
    end
    return true
end

local function closestEnemy(S, radius, myChar, myHRP)
    local best, bestD
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            if validEnemy(plr, S, myChar, myHRP, radius) then
                local d = dist(getHRP(plr.Character).Position, myHRP.Position)
                if not bestD or d < bestD then best, bestD = plr, d end
            end
        end
    end
    return best
end

-- ========= GUI =========
local function safeParent(gui)
    gui.ResetOnSpawn = false
    local ok = pcall(function() gui.Parent = game.CoreGui end)
    if not ok then gui.Parent = LP:WaitForChild("PlayerGui") end
end

local function buildGUI(S)
    -- destruye anterior
    local existing = (game.CoreGui and game.CoreGui:FindFirstChild("AutoAuraHub")) or (LP.PlayerGui and LP.PlayerGui:FindFirstChild("AutoAuraHub"))
    if existing then pcall(function() existing:Destroy() end) end

    local gui = Instance.new("ScreenGui"); gui.Name = "AutoAuraHub"; safeParent(gui)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(300, 290)
    frame.Position = UDim2.new(0, 20, 0, 100)
    frame.BackgroundColor3 = Color3.fromRGB(28,28,28)
    frame.BorderSizePixel = 0
    frame.Active = true; frame.Draggable = true
    frame.Parent = gui

    local function label(text, y)
        local l = Instance.new("TextLabel"); l.Size = UDim2.new(1, -20, 0, 20)
        l.Position = UDim2.new(0, 10, 0, y); l.BackgroundTransparency = 1
        l.Font = Enum.Font.GothamBold; l.TextSize = 15
        l.TextColor3 = Color3.new(1,1,1); l.TextXAlignment = Enum.TextXAlignment.Left
        l.Text = text; l.Parent = frame; return l
    end
    local function btn(text, x, y, cb)
        local b = Instance.new("TextButton"); b.Size = UDim2.new(0, 140, 0, 26)
        b.Position = UDim2.new(0, x, 0, y); b.Text = text
        b.BackgroundColor3 = Color3.fromRGB(50,50,50); b.TextColor3 = Color3.new(1,1,1)
        b.Font = Enum.Font.Gotham; b.TextSize = 14; b.Parent = frame
        b.MouseButton1Click:Connect(cb); return b
    end
    local function box(placeholder, x, y, cb)
        local t = Instance.new("TextBox"); t.Size = UDim2.new(0, 280, 0, 24)
        t.Position = UDim2.new(0, x, 0, y); t.BackgroundColor3 = Color3.fromRGB(38,38,38)
        t.TextColor3 = Color3.new(1,1,1); t.PlaceholderText = placeholder; t.Text = ""
        t.Font = Enum.Font.Gotham; t.TextSize = 14; t.Parent = frame
        t.FocusLost:Connect(function(enter) if enter then cb(t) end end); return t
    end

    label("⚔️ Auto/Aura Hit PRO", 6)

    local btnAuto = btn("AutoHit: "..(S.AutoHit and "ON" or "OFF"), 10, 36, function()
        S.AutoHit = not S.AutoHit; btnAuto.Text = "AutoHit: "..(S.AutoHit and "ON" or "OFF")
    end)
    local btnAura = btn("AuraHit: "..(S.AuraHit and "ON" or "OFF"), 150, 36, function()
        S.AuraHit = not S.AuraHit; btnAura.Text = "AuraHit: "..(S.AuraHit and "ON" or "OFF")
    end)
    local btnLOS  = btn("LineOfSight: "..(S.UseLineOfSight and "ON" or "OFF"), 10, 68, function()
        S.UseLineOfSight = not S.UseLineOfSight; btnLOS.Text = "LineOfSight: "..(S.UseLineOfSight and "ON" or "OFF")
    end)
    local btnTeam = btn("Ignorar Team: "..(S.IgnoreTeammates and "ON" or "OFF"), 150, 68, function()
        S.IgnoreTeammates = not S.IgnoreTeammates; btnTeam.Text = "Ignorar Team: "..(S.IgnoreTeammates and "ON" or "OFF")
    end)
    local btnEquip = btn("AutoEquip: "..(S.AutoEquip and "ON" or "OFF"), 10, 100, function()
        S.AutoEquip = not S.AutoEquip; btnEquip.Text = "AutoEquip: "..(S.AutoEquip and "ON" or "OFF")
    end)
    local btnHandle = btn("RequireHandle: "..(S.RequireHandle and "ON" or "OFF"), 150, 100, function()
        S.RequireHandle = not S.RequireHandle; btnHandle.Text = "RequireHandle: "..(S.RequireHandle and "ON" or "OFF")
    end)

    local lblReach = label(("Reach: %d"):format(S.Reach), 134)
    btn("Reach -", 10, 156, function() S.Reach = math.max(1, S.Reach-1); lblReach.Text = ("Reach: %d"):format(S.Reach) end)
    btn("Reach +", 150, 156, function() S.Reach = S.Reach+1; lblReach.Text = ("Reach: %d"):format(S.Reach) end)

    local lblAura = label(("Aura: %d"):format(S.AuraRadius), 186)
    btn("Aura -", 10, 208, function() S.AuraRadius = math.max(1, S.AuraRadius-1); lblAura.Text = ("Aura: %d"):format(S.AuraRadius) end)
    btn("Aura +", 150, 208, function() S.AuraRadius = S.AuraRadius+1; lblAura.Text = ("Aura: %d"):format(S.AuraRadius) end)

    local lblRate = label(("Intervalo: %.2fs"):format(S.MinHitInterval), 238)
    btn("Rate -", 10, 260, function() S.MinHitInterval = math.max(0.05, S.MinHitInterval-0.05); lblRate.Text = ("Intervalo: %.2fs"):format(S.MinHitInterval) end)
    btn("Rate +", 150, 260, function() S.MinHitInterval = math.min(1.0, S.MinHitInterval+0.05); lblRate.Text = ("Intervalo: %.2fs"):format(S.MinHitInterval) end)

    box("Filtro de Tool (substring del nombre, Enter para aplicar)", 10, 292, function(tb)
        S.ToolNameFilter = tb.Text or ""; tb.Text = ""
    end)

    local lblStatus = label("Estado: —", 324)

    -- Actualiza estado ~10 Hz
    local acc = 0
    RS.RenderStepped:Connect(function(dt)
        acc += dt
        if acc >= 0.1 then
            local char = getChar(); local hrp = getHRP(char)
            local t = getTool(S)
            local reason = "OK"
            if not t then reason = "NoTool" end
            if hrp == nil then reason = "NoChar" end
            lblStatus.Text = ("Estado: %s | Tool: %s"):format(reason, t and t.Name or "—")
            acc = 0
        end
    end)

    -- Kill-switch (Delete)
    UIS.InputBegan:Connect(function(input,gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.Delete then
            pcall(function() gui:Destroy() end)
        end
    end)
end

-- ========= Loop principal (timestep fijo) =========
local function main()
    local S = getgenv().AA_STATE
    buildGUI(S)

    local currentTarget, nextSearchAt = nil, 0
    local searchPeriod = 0.15

    local accum, fixed = 0, 1/90
    RS.Heartbeat:Connect(function(dt)
        accum += dt
        while accum >= fixed do
            local Sref = getgenv().AA_STATE -- por si S es reemplazado
            local char = getChar()
            local myHRP = getHRP(char)
            if not char or not myHRP then accum -= fixed; break end

            local tool = getTool(Sref)

            -- AutoHit: golpear si hay cualquiera en Reach
            if Sref.AutoHit and tool then
                local ok, reason = canHit(Sref, tool)
                if ok then
                    for _,plr in ipairs(Players:GetPlayers()) do
                        if plr ~= LP and validEnemy(plr, Sref, char, myHRP, Sref.Reach) then
                            doHit(tool); break
                        end
                    end
                end
            end

            -- AuraHit: mantener objetivo dentro de AuraRadius
            if Sref.AuraHit and tool then
                local t = now()
                if (not currentTarget)
                    or (not validEnemy(currentTarget, Sref, char, myHRP, Sref.AuraRadius))
                    or (t >= nextSearchAt) then
                    currentTarget = closestEnemy(Sref, Sref.AuraRadius, char, myHRP)
                    nextSearchAt = t + searchPeriod
                end
                if currentTarget then
                    local ok = select(1, canHit(Sref, tool))
                    if ok then doHit(tool) end
                end
            end

            accum -= fixed
        end
    end)
end

-- Autoclean GUIs anteriores y lanzar
pcall(function()
    local old = (game.CoreGui and game.CoreGui:FindFirstChild("AutoAuraHub")) or (LP.PlayerGui and LP.PlayerGui:FindFirstChild("AutoAuraHub"))
    if old then old:Destroy() end
end)
main()
