-- Ultra Touch GUI (Tablet) + Fallbacks + Hit Aura + Aura Circular + Scroll fijo
-- Luis x Copilot — GUI táctil visible, Noclip real, velocidades persistentes,
-- Hit Aura (Handle scaling), escaneo Aura Circular (4..1000), y panel con desplazamiento vertical.

-- ========== Servicios ==========
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

-- ========== Util ==========
local function notify(t, d)
    pcall(function()
        StarterGui:SetCore("SendNotification", {Title="Ultra Touch", Text=t, Duration=d or 1.8})
    end)
end
local function clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi else return v end end

-- ========== Reabrir GUI si ya existe ==========
do
    local existing = PlayerGui:FindFirstChild("UltraTouchGUI")
    if existing then
        existing.Enabled = true
        existing.ResetOnSpawn = false
        _G.USH_ShowUI = function(v)
            existing.Enabled = true
            local main = existing:FindFirstChild("Root")
            local reopen = existing:FindFirstChild("ReopenButton")
            if main then main.Visible = (v ~= false) end
            if reopen then reopen.Visible = (v == false) end
        end
        return
    end
end

-- ========== Entorno compartido / Estado ==========
local ENV = (getgenv and getgenv()) or _G
if ENV.USH_GUI_LOADED then return end
ENV.USH_GUI_LOADED = true

ENV.USH_CFG = ENV.USH_CFG or {
    guiPos = {0.06, 0.16},
    uiScale = 1.0,
    opacity = 0.92,
}
ENV.USH_STATE = ENV.USH_STATE or {}
local S = ENV.USH_STATE

-- Fallback base
S.walkSpeed   = S.walkSpeed   or 16
S.sprintSpeed = S.sprintSpeed or 80
S.flySpeed    = S.flySpeed    or 60
S.sprint      = S.sprint      or false
S.noclip      = S.noclip      or false

-- Aura Hit + Aura Circular
S.aura        = S.aura        or false
S.auraSize    = clamp(S.auraSize or 8, 4, 1000)
S.auraScan    = S.auraScan    or false
S.auraDia     = clamp(S.auraDia or 100, 4, 1000)

-- ========== Character refs y conexiones ==========
local Conns = {char={}, noclip={}, speed={}, aura={}, scan={}}
local char, hum, hrp

local function disconnectAll(t) for _,c in ipairs(t) do pcall(function() c:Disconnect() end) end table.clear(t) end
local function getChar()
    local c = player.Character or player.CharacterAdded:Wait()
    return c, c:WaitForChild("Humanoid"), c:WaitForChild("HumanoidRootPart")
end

local function rebindCharacter()
    disconnectAll(Conns.char)
    char, hum, hrp = getChar()
    if S._desiredSpeed then hum.WalkSpeed = S._desiredSpeed end
    if S.noclip then _G.noclipOn_fallback(true) end
    if S.aura then Aura.tool, Aura.handle = nil, nil; heartbeatAura() end
end

table.insert(Conns.char, player.CharacterAdded:Connect(function()
    task.wait(0.15)
    rebindCharacter()
end))

-- ========== Velocidad persistente (fallback) ==========
local function applyWalkSpeed()
    if not hum then return end
    local target = S.sprint and S.sprintSpeed or S.walkSpeed
    S._desiredSpeed = target
    hum.WalkSpeed = target
end

local function startSpeedGuard()
    disconnectAll(Conns.speed)
    if hum then
        table.insert(Conns.speed, hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
            local target = S._desiredSpeed
            if target and math.abs((hum.WalkSpeed or 0) - target) > 0.5 then
                hum.WalkSpeed = target
            end
        end))
    end
    table.insert(Conns.speed, RunService.Heartbeat:Connect(function()
        if hum and S._desiredSpeed and math.abs(hum.WalkSpeed - S._desiredSpeed) > 0.5 then
            hum.WalkSpeed = S._desiredSpeed
        end
    end))
end

_G.setWalkSpeed_fallback = function(v)
    v = clamp(v, 8, 300)
    S.walkSpeed = v
    applyWalkSpeed()
end
_G.setSprintSpeed_fallback = function(v)
    v = clamp(v, 16, 800)
    S.sprintSpeed = v
    applyWalkSpeed()
end
_G.setFlySpeed_fallback = function(v)
    v = clamp(v, 10, 1200)
    S.flySpeed = v
end
_G.sprintOn_fallback = function() S.sprint = true;  applyWalkSpeed(); notify("Sprint ON", 1.2) end
_G.sprintOff_fallback= function() S.sprint = false; applyWalkSpeed(); notify("Sprint OFF",1.2) end

-- ========== Noclip real (fallback) ==========
local function setNoCollide(model, on)
    for _,v in ipairs(model:GetDescendants()) do
        if v:IsA("BasePart") then v.CanCollide = not on end
    end
end

_G.noclipOn_fallback = function(silent)
    if S.noclip then return end
    S.noclip = true
    if char and char.Parent then setNoCollide(char, true) end
    disconnectAll(Conns.noclip)
    table.insert(Conns.noclip, RunService.Stepped:Connect(function()
        if S.noclip and char and char.Parent then
            setNoCollide(char, true)
        end
    end))
    if not silent then notify("Noclip ON") end
end

_G.noclipOff_fallback = function(silent)
    if not S.noclip then return end
    S.noclip = false
    disconnectAll(Conns.noclip)
    if char and char.Parent then setNoCollide(char, false) end
    if not silent then notify("Noclip OFF") end
end

-- ========== Hit Aura (Handle scaling) ==========
local Aura = {
    enabled = false,
    size = S.auraSize,
    thickness = 6,
    tool = nil,
    handle = nil,
    saved = nil,
}

local function getEquippedTool()
    if not char then return end
    for _,c in ipairs(char:GetChildren()) do
        if c:IsA("Tool") and c:FindFirstChild("Handle") and c.Handle:IsA("BasePart") then
            return c, c.Handle
        end
    end
end

local function restoreHandle()
    if Aura.handle and Aura.saved then
        pcall(function()
            Aura.handle.Size = Aura.saved.Size
            Aura.handle.Massless = Aura.saved.Massless
            Aura.handle.CanCollide = Aura.saved.CanCollide
            if Aura.saved.Transparency ~= nil then Aura.handle.Transparency = Aura.saved.Transparency end
            local sm = Aura.handle:FindFirstChildOfClass("SpecialMesh")
            if sm and Aura.saved.MeshScale then sm.Scale = Aura.saved.MeshScale end
        end)
    end
    Aura.saved = nil
end

local function applyAuraTo(handle)
    if not handle then return end
    if not Aura.saved then
        local sm = handle:FindFirstChildOfClass("SpecialMesh")
        Aura.saved = {
            Size = handle.Size,
            Massless = handle.Massless,
            CanCollide = handle.CanCollide,
            Transparency = handle.Transparency,
            MeshScale = sm and sm.Scale or nil
        }
    end
    pcall(function()
        handle.Massless = true
        handle.CanCollide = false
        handle.Transparency = Aura.saved.Transparency
        local s = clamp(Aura.size, 4, 1000)
        handle.Size = Vector3.new(s, Aura.thickness, s)
    end)
end

function heartbeatAura()
    disconnectAll(Conns.aura)
    if not Aura.enabled then return end
    table.insert(Conns.aura, RunService.Heartbeat:Connect(function()
        if not char or not char.Parent then return end
        local t, h = getEquippedTool()
        if t ~= Aura.tool then
            if Aura.tool or Aura.handle then restoreHandle() end
            Aura.tool, Aura.handle = t, h
            if Aura.handle then applyAuraTo(Aura.handle) end
        else
            if Aura.handle then applyAuraTo(Aura.handle) end
        end
    end))
    table.insert(Conns.aura, char.ChildAdded:Connect(function(obj)
        if obj:IsA("Tool") and Aura.enabled then
            task.defer(function()
                local _, h = getEquippedTool()
                if h then applyAuraTo(h) end
            end)
        end
    end))
    table.insert(Conns.aura, char.ChildRemoved:Connect(function(obj)
        if obj == Aura.tool then
            restoreHandle()
            Aura.tool, Aura.handle = nil, nil
        end
    end))
end

local function auraOn()
    if Aura.enabled then return end
    Aura.enabled = true
    S.aura = true
    heartbeatAura()
    notify("AURA HIT ON", 1.2)
end

local function auraOff()
    if not Aura.enabled then return end
    Aura.enabled = false
    S.aura = false
    disconnectAll(Conns.aura)
    restoreHandle()
    Aura.tool, Aura.handle = nil, nil
    notify("AURA HIT OFF", 1.2)
end

local function setAuraSize(v)
    Aura.size = clamp(math.floor(v + 0.5), 4, 1000)
    S.auraSize = Aura.size
end

_G.auraOn_fallback      = auraOn
_G.auraOff_fallback     = auraOff
_G.setAuraSize_fallback = setAuraSize

-- ========== Aura Circular (escaneo en círculo con highlight) ==========
local SCAN_HZ = 10
local highlighted = {} -- [Model] = Highlight

local function getHRP(model)
    if not model then return end
    return model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso") or model:FindFirstChild("UpperTorso")
end

local function isEnemy(model)
    if not model or not model:IsA("Model") then return false end
    if Players:GetPlayerFromCharacter(model) then return false end
    if model == char then return false end
    local humx = model:FindFirstChildOfClass("Humanoid")
    if not humx or humx.Health <= 0 then return false end
    if CollectionService:HasTag(model, "Enemy") then return true end
    local enemiesFolder = Workspace:FindFirstChild("Enemies")
    if enemiesFolder and model:IsDescendantOf(enemiesFolder) then return true end
    return true
end

local function ensureHighlight(model)
    local h = highlighted[model]
    if h and h.Parent == model then return h end
    if h then pcall(function() h:Destroy() end) end
    h = Instance.new("Highlight")
    h.FillColor = Color3.fromRGB(255, 80, 80)
    h.OutlineColor = Color3.fromRGB(255, 255, 255)
    h.FillTransparency = 0.7
    h.OutlineTransparency = 0
    h.DepthMode = Enum.HighlightDepthMode.Occluded
    h.Parent = model
    highlighted[model] = h
    return h
end

local function clearOrphanHighlights()
    for m, h in pairs(highlighted) do
        if not m or not m.Parent then
            highlighted[m] = nil
            pcall(function() h:Destroy() end)
        end
    end
end

local function setHighlightsVisible(setMap)
    for m, h in pairs(highlighted) do
        h.Enabled = setMap and setMap[m] == true
    end
end

local accum = 0
local function startCircularScan()
    disconnectAll(Conns.scan)
    table.insert(Conns.scan, RunService.Heartbeat:Connect(function(dt)
        accum += dt
        if accum < (1/SCAN_HZ) then return end
        accum = 0
        if not S.auraScan then setHighlightsVisible({}) return end
        if not hrp then return end

        local dia = clamp(S.auraDia, 4, 1000)
        local radius = dia * 0.5

        local params = OverlapParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {char}

        local parts = Workspace:GetPartBoundsInRadius(hrp.Position, radius, params)
        local visible = {}
        for _, part in ipairs(parts) do
            local model = part:FindFirstAncestorOfClass("Model")
            if model and isEnemy(model) then
                visible[model] = true
                ensureHighlight(model)
            end
        end
        setHighlightsVisible(visible)
        clearOrphanHighlights()
    end))
end

-- ========== API expuesta ==========
local EXPOSED = ENV.USH or ENV.USE or ENV.STEALTH or ENV.HUB or ENV
local API = {
    Noclip = {
        get = function() return (EXPOSED.State and EXPOSED.State.noclip) or S.noclip end,
        on  = function() if typeof(EXPOSED.noclipOn)=="function" then EXPOSED.noclipOn() else _G.noclipOn_fallback() end end,
        off = function() if typeof(EXPOSED.noclipOff)=="function" then EXPOSED.noclipOff() else _G.noclipOff_fallback() end end,
        desc="Atravesar objetos",
    },
    Sprint = {
        get = function() return (EXPOSED.State and EXPOSED.State.sprint) or S.sprint end,
        on  = function() if typeof(EXPOSED.sprintOn)=="function" then EXPOSED.sprintOn() else _G.sprintOn_fallback() end end,
        off = function() if typeof(EXPOSED.sprintOff)=="function" then EXPOSED.sprintOff() else _G.sprintOff_fallback() end end,
        desc="Correr más rápido",
    },
    Fly = {
        get = function() return (EXPOSED.State and EXPOSED.State.fly) or (S.fly or false) end,
        on  = function() if typeof(EXPOSED.flyOn)=="function" then EXPOSED.flyOn() else notify("Conecta tu Fly del hub") end end,
        off = function() if typeof(EXPOSED.flyOff)=="function" then EXPOSED.flyOff() else notify("Conecta tu Fly del hub") end end,
        desc="Vuelo libre",
    },
    Invis = {
        get = function() return (EXPOSED.State and EXPOSED.State.invisRep) or (S.invisRep or false) end,
        on  = function() if typeof(EXPOSED.invisRepOn)=="function" then EXPOSED.invisRepOn() else notify("Conecta InvisRep del hub") end end,
        off = function() if typeof(EXPOSED.invisRepOff)=="function" then EXPOSED.invisRepOff() else notify("Conecta InvisRep del hub") end end,
        desc="Invisibilidad replicada",
    },
    Ghost = {
        get = function() return (EXPOSED.State and EXPOSED.State.ghost) or (S.ghost or false) end,
        on  = function() if typeof(EXPOSED.ghostOn)=="function" then EXPOSED.ghostOn() else notify("Conecta Ghost del hub") end end,
        off = function() if typeof(EXPOSED.ghostOff)=="function" then EXPOSED.ghostOff() else notify("Conecta Ghost del hub") end end,
        desc="Colisión fantasma",
    },
    -- Speeds
    WalkSpeed = {
        get = function() return (EXPOSED.State and (EXPOSED.State.walkSpeed or EXPOSED.State.speedWalk)) or S.walkSpeed end,
        set = function(v) if typeof(EXPOSED.setWalkSpeed)=="function" then EXPOSED.setWalkSpeed(v) else _G.setWalkSpeed_fallback(v) end end,
        min=8,max=300,step=2, desc="Velocidad caminar",
    },
    SprintSpeed = {
        get = function() return (EXPOSED.State and (EXPOSED.State.sprintSpeed or EXPOSED.State.speedSprint)) or S.sprintSpeed end,
        set = function(v) if typeof(EXPOSED.setSprintSpeed)=="function" then EXPOSED.setSprintSpeed(v) else _G.setSprintSpeed_fallback(v) end end,
        min=16,max=800,step=5, desc="Velocidad sprint",
    },
    FlySpeed = {
        get = function() return (EXPOSED.State and (EXPOSED.State.flySpeed or EXPOSED.State.speedFly)) or S.flySpeed end,
        set = function(v) if typeof(EXPOSED.setFlySpeed)=="function" then EXPOSED.setFlySpeed(v) else _G.setFlySpeed_fallback(v) end end,
        min=10,max=1200,step=10, desc="Velocidad vuelo",
    },
    -- Hit Aura
    Aura = {
        get = function() return (EXPOSED.State and EXPOSED.State.aura) or S.aura end,
        on  = function() if typeof(EXPOSED.auraOn)=="function" then EXPOSED.auraOn() else _G.auraOn_fallback() end end,
        off = function() if typeof(EXPOSED.auraOff)=="function" then EXPOSED.auraOff() else _G.auraOff_fallback() end end,
        desc="Amplía el rango del Tool al golpear",
    },
    AuraSize = {
        get = function() return (EXPOSED.State and (EXPOSED.State.auraSize)) or S.auraSize end,
        set = function(v) if typeof(EXPOSED.setAuraSize)=="function" then EXPOSED.setAuraSize(v) else _G.setAuraSize_fallback(v) end end,
        min=4,max=1000,step=10, desc="Diámetro Hit Aura (studs)",
    },
    -- Aura Circular (escaneo)
    AuraScan = {
        get = function() return S.auraScan end,
        on  = function() S.auraScan = true end,
        off = function() S.auraScan = false; setHighlightsVisible({}) end,
        desc="Escaneo circular (highlight)",
    },
    AuraDia = {
        get = function() return S.auraDia end,
        set = function(v) S.auraDia = clamp(math.floor(v+0.5), 4, 1000) end,
        min=4,max=1000,step=10, desc="Diámetro círculo (studs)",
    },
}

-- ========== UI (tablet-first) ==========
local function New(c,p,children) local o=Instance.new(c) for k,v in pairs(p or {}) do o[k]=v end if children then for _,ch in ipairs(children) do ch.Parent=o end end return o end

local Screen = New("ScreenGui",{Name="UltraTouchGUI",ResetOnSpawn=false,IgnoreGuiInset=true, ZIndexBehavior=Enum.ZIndexBehavior.Global})
Screen.Parent = PlayerGui
local UIScale = New("UIScale",{Scale=ENV.USH_CFG.uiScale or 1.0}); UIScale.Parent=Screen

local Root = New("Frame",{
    Name="Root",
    BackgroundColor3=Color3.fromRGB(20,20,24),
    BackgroundTransparency = 1 - (ENV.USH_CFG.opacity or 0.92),
    Size=UDim2.new(0,480,0,600),
    Position=UDim2.fromScale(ENV.USH_CFG.guiPos[1] or 0.06, ENV.USH_CFG.guiPos[2] or 0.16)
})
Root.Parent=Screen
New("UICorner",{CornerRadius=UDim.new(0,12)}).Parent=Root
New("UIStroke",{Thickness=1,Transparency=0.5,Color=Color3.fromRGB(60,60,70)}).Parent=Root

local Top = New("Frame",{BackgroundColor3=Color3.fromRGB(34,34,42),Size=UDim2.new(1,0,0,50)}); Top.Parent=Root
local Title = New("TextLabel",{BackgroundTransparency=1,Text="Ultra Stealth • Touch",Font=Enum.Font.GothamSemibold,TextSize=18,TextColor3=Color3.fromRGB(240,240,245),TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2.new(0,14,0,0),Size=UDim2.new(0.7,0,1,0)}); Title.Parent=Top
local Close = New("TextButton",{Text="✕",Font=Enum.Font.GothamBold,TextSize=18,BackgroundTransparency=1,TextColor3=Color3.fromRGB(240,240,245),Size=UDim2.new(0,48,1,0),Position=UDim2.new(1,-48,0,0)}); Close.Parent=Top
Close.MouseButton1Click:Connect(function() Screen.Enabled=false end)

-- Reopen mini botón
local Reopen = New("TextButton",{Name="ReopenButton",Text="≡",Font=Enum.Font.GothamBold,TextSize=18,BackgroundColor3=Color3.fromRGB(60,60,72),TextColor3=Color3.fromRGB(240,240,245),Size=UDim2.new(0,44,0,44),Position=UDim2.new(0,12,1,-56),Visible=false})
Reopen.Parent = Screen
New("UICorner",{CornerRadius=UDim.new(0,10)}).Parent=Reopen
Reopen.MouseButton1Click:Connect(function() Root.Visible=true; Reopen.Visible=false; Screen.Enabled=true end)
Close.MouseButton1Click:Connect(function() Root.Visible=false; Reopen.Visible=true end)

-- Drag (mover panel principal, no afecta el scroll interno)
local dragging, startPos, startInput = false, nil, nil
Top.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then
        dragging=true; startPos=i.Position; startInput=i
    end
end)
Top.InputEnded:Connect(function(i) if i==startInput then dragging=false end end)
UIS.InputChanged:Connect(function(i)
    if dragging and (i==startInput or i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseMovement) then
        local delta = i.Position - startPos
        local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920,1080)
        local nx = math.clamp(Root.Position.X.Scale + delta.X/vp.X, 0, 1)
        local ny = math.clamp(Root.Position.Y.Scale + delta.Y/vp.Y, 0, 1)
        Root.Position = UDim2.fromScale(nx, ny)
        ENV.USH_CFG.guiPos = {nx, ny}
        startPos = i.Position
    end
end)

-- Tabs
local Tabs = New("Frame",{BackgroundColor3=Color3.fromRGB(34,34,42),Size=UDim2.new(1,0,0,40),Position=UDim2.new(0,0,0,50)}); Tabs.Parent=Root

-- Body (ScrollingFrame con desplazamiento vertical habilitado)
local Body = New("ScrollingFrame",{
    BackgroundTransparency = 1,
    Size = UDim2.new(1,0,1,-100),
    Position = UDim2.new(0,0,0,90),
    ScrollBarThickness = 10,
    ScrollingDirection = Enum.ScrollingDirection.Y,
    VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
    Active = true,
    ClipsDescendants = true,
    AutomaticCanvasSize = Enum.AutomaticSize.None
}); Body.Parent=Root

local Layout = New("UIListLayout",{Padding=UDim.new(0,10),SortOrder=Enum.SortOrder.LayoutOrder}); Layout.Parent=Body
local Pad = New("UIPadding",{PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12),PaddingTop=UDim.new(0,12),PaddingBottom=UDim.new(0,12)}); Pad.Parent=Body

local function updateCanvas() Body.CanvasSize = UDim2.new(0,0,0, Layout.AbsoluteContentSize.Y + 24) end
Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)

local function pill(h) local f=New("Frame",{BackgroundColor3=Color3.fromRGB(28,28,34),Size=UDim2.new(1,0,0,h or 52)}); f.Parent=Body; New("UICorner",{CornerRadius=UDim.new(0,10)}).Parent=f; New("UIStroke",{Thickness=1,Transparency=0.4,Color=Color3.fromRGB(55,55,65)}).Parent=f; return f end
local function text(parent, t, sub) local l=New("TextLabel",{BackgroundTransparency=1,Text=t,Font=Enum.Font.GothamSemibold,TextSize=16,TextColor3=Color3.fromRGB(235,235,240),TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2.new(0,12,0,6),Size=UDim2.new(1,-140,0,20)}); l.Parent=parent; if sub then local s=New("TextLabel",{BackgroundTransparency=1,Text=sub,Font=Enum.Font.Gotham,TextSize=12,TextColor3=Color3.fromRGB(170,170,180),TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2.new(0,12,0,26),Size=UDim2.new(1,-140,0,18)}); s.Parent=parent end end

local function makeToggle(name, desc, getFn, onFn, offFn)
    local fr = pill(52); text(fr, name, desc)
    local btn = New("TextButton",{Text="",Font=Enum.Font.GothamBold,TextSize=14,TextColor3=Color3.new(1,1,1),Size=UDim2.new(0,108,0,34),Position=UDim2.new(1,-120,0,9)})
    btn.Parent=fr; New("UICorner",{CornerRadius=UDim.new(0,8)}).Parent=btn
    local function refresh() local v=false pcall(function() v=getFn() end); btn.Text = v and "ON" or "OFF"; btn.BackgroundColor3 = v and Color3.fromRGB(30,140,90) or Color3.fromRGB(140,40,50) end
    btn.MouseButton1Click:Connect(function() local v=false pcall(function() v=getFn() end); if v then offFn() else onFn() end; refresh() end)
    refresh()
end

local function makeStepper(name, desc, getFn, setFn, min, max, step)
    local fr = pill(64); text(fr, name, desc)
    local minus = New("TextButton",{Text="−",Font=Enum.Font.GothamBold,TextSize=20,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(40,40,48),Size=UDim2.new(0,44,0,34),Position=UDim2.new(1,-210,0,22)}); minus.Parent=fr; New("UICorner",{CornerRadius=UDim.new(0,8)}).Parent=minus
    local box = New("TextBox",{Text="",PlaceholderText="--",Font=Enum.Font.GothamSemibold,TextSize=16,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(40,40,48),ClearTextOnFocus=false,Size=UDim2.new(0,110,0,34),Position=UDim2.new(1,-160,0,22)}); box.Parent=fr; New("UICorner",{CornerRadius=UDim.new(0,8)}).Parent=box
    local plus = New("TextButton",{Text="+",Font=Enum.Font.GothamBold,TextSize=20,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(40,40,48),Size=UDim2.new(0,44,0,34),Position=UDim2.new(1,-44,0,22)}); plus.Parent=fr; New("UICorner",{CornerRadius=UDim.new(0,8)}).Parent=plus
    local function current() local v=0 pcall(function() v=getFn() end) return v end
    local function setv(v) pcall(function() setFn(v) end) end
    local function clampStep(v) v = math.clamp(v, min, max); local s=step or 1; v = math.floor((v + s/2)/s)*s; return v end
    local function refresh() box.Text = tostring(current()) end
    minus.MouseButton1Click:Connect(function() setv(clampStep(current() - (step or 1))); refresh() end)
    plus.MouseButton1Click:Connect(function() setv(clampStep(current() + (step or 1))); refresh() end)
    box.FocusLost:Connect(function()
        local n = tonumber(box.Text)
        if n then setv(clampStep(n)) else box.Text = tostring(current()) end
    end)
    refresh()
end

-- Construcción de tabs
local function clearBody() for _,g in ipairs(Body:GetChildren()) do if g:IsA("GuiObject") then g:Destroy() end end end
local function buildMovimiento()
    makeToggle("Noclip", "Atravesar objetos", API.Noclip.get, API.Noclip.on, API.Noclip.off)
    makeToggle("Sprint", "Correr más rápido", API.Sprint.get, API.Sprint.on, API.Sprint.off)
    makeToggle("Fly", "Vuelo (si tu hub lo expone)", API.Fly.get, API.Fly.on, API.Fly.off)

    makeStepper("WalkSpeed", "Velocidad al caminar", API.WalkSpeed.get, API.WalkSpeed.set, API.WalkSpeed.min, API.WalkSpeed.max, API.WalkSpeed.step)
    makeStepper("SprintSpeed", "Velocidad en sprint", API.SprintSpeed.get, API.SprintSpeed.set, API.SprintSpeed.min, API.SprintSpeed.max, API.SprintSpeed.step)
    makeStepper("FlySpeed", "Velocidad de vuelo (referencia)", API.FlySpeed.get, API.FlySpeed.set, API.FlySpeed.min, API.FlySpeed.max, API.FlySpeed.step)

    -- Hit Aura
    makeToggle("AURA HIT", "Amplía el área del golpe (Tool Handle)", API.Aura.get, API.Aura.on, API.Aura.off)
    makeStepper("Aura Size", "Diámetro Hit Aura (4..1000)", API.AuraSize.get, API.AuraSize.set, API.AuraSize.min, API.AuraSize.max, API.AuraSize.step)

    -- Aura Circular
    makeToggle("AURA CÍRCULAR", "Escaneo circular con highlight", API.AuraScan.get, API.AuraScan.on, API.AuraScan.off)
    makeStepper("Círculo (diámetro)", "4..1000 studs", API.AuraDia.get, API.AuraDia.set, API.AuraDia.min or 4, API.AuraDia.max or 1000, API.AuraDia.step or 10)
end
local function buildStealth()
    makeToggle("Invis", "Invisibilidad replicada (si tu hub la tiene)", API.Invis.get, API.Invis.on, API.Invis.off)
    makeToggle("Ghost", "Colisión fantasma (si tu hub la tiene)", API.Ghost.get, API.Ghost.on, API.Ghost.off)
end
local function buildAjustes()
    makeStepper("Opacidad UI", "Transparencia (40-100%)",
        function() return math.floor((ENV.USH_CFG.opacity or 0.92)*100+0.5) end,
        function(v) ENV.USH_CFG.opacity = math.clamp(v/100, 0.4, 1.0); Root.BackgroundTransparency = 1 - ENV.USH_CFG.opacity end,
        40,100,5
    )
    makeStepper("Escala UI", "Tamaño (50-150%)",
        function() return math.floor((ENV.USH_CFG.uiScale or 1.0)*100+0.5) end,
        function(v) ENV.USH_CFG.uiScale = math.clamp(v/100, 0.5, 1.5); UIScale.Scale = ENV.USH_CFG.uiScale end,
        50,150,5
    )
    local fr = pill(52); text(fr, "Posición", "Recentrar GUI")
    local rec = New("TextButton",{Text="Recentrar",Font=Enum.Font.GothamBold,TextSize=16,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(40,40,48),Size=UDim2.new(0,120,0,34),Position=UDim2.new(1,-130,0,9)}); rec.Parent=fr; New("UICorner",{CornerRadius=UDim.new(0,8)}).Parent=rec
    rec.MouseButton1Click:Connect(function() Root.Position=UDim2.fromScale(0.06,0.16); ENV.USH_CFG.guiPos={0.06,0.16}; Screen.Enabled=true end)
end

local function buildTab(i)
    clearBody()
    if i==1 then buildMovimiento()
    elseif i==2 then buildStealth()
    else buildAjustes() end
    updateCanvas()
end

local function tabBtn(label, x, idx)
    local b = New("TextButton",{Text=label,Font=Enum.Font.GothamSemibold,TextSize=14,TextColor3=Color3.fromRGB(235,235,240),BackgroundColor3=Color3.fromRGB(34,34,42),Size=UDim2.new(0,140,1,0),Position=UDim2.new(0,x,0,0)})
    b.Parent=Tabs
    b.MouseButton1Click:Connect(function() buildTab(idx) end)
    return b
end

tabBtn("Movimiento", 8,   1)
tabBtn("Stealth",   156,  2)
tabBtn("Ajustes",   304,  3)
buildTab(1)

-- ========== Init ==========
rebindCharacter()
applyWalkSpeed()
startSpeedGuard()
startCircularScan()

_G.USH_ShowUI = function(v)
    Root.Visible = (v ~= false)
    Reopen.Visible = (v == false)
    Screen.Enabled = true
end

notify("GUI lista. Noclip, velocidad, Hit Aura y Aura Circular activos.", 2--[[ 
Ultra Stealth Hub + Hit Aura Extendido (sin guante gigante)
- Carga tu script original desde tu URL.
- Añade Hit Aura con alcance real hacia adelante (cono/cápsula) y modo esfera opcional.
- Sin escalado del guante. Incluye un "watchdog" opcional para revertir Handle enormes.
- UI compacta y táctil para activar, ajustar rango/anchura/retardo/FOV/filtros, y hotkey (K).
]]

--==== Cargar el script original tal como lo pediste ====--
do
    local SRC = "https://github.com/gaspi23/muscle-legends-script/raw/refs/heads/main/Main.lua"
    local ok, err = pcall(function()
        local src = game:HttpGet(SRC)
        local f = loadstring(src)
        if typeof(f) == "function" then f() end
    end)
    if not ok then warn("UltraStealth original no se pudo cargar: ", err) end
end

--==== Servicios ====--
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer

--==== Config Global Persistente (se guarda junto a tu CFG si existe) ====--
getgenv().USH_AuraExtCfg = getgenv().USH_AuraExtCfg or {
    enabled = false,
    range = 30,         -- distancia máxima hacia adelante (studs)
    width = 6,          -- radio lateral del "túnel" (studs) para cápsula/cone
    delay = 0.12,       -- intervalo entre barridos de golpe
    fovDeg = 90,        -- límite de apertura (0-180) alrededor de la mirada
    losCheck = true,    -- línea de visión (raycast) para evitar paredes
    frontOnly = true,   -- true = cono/cápsula al frente; false = esfera alrededor
    hitThroughFF = false, -- ignorar ForceField si se quisiera
    revertGiantHandle = true, -- si detecta Handle gigantes, los vuelve a escala normal
    ignoreSameTeam = true,
    tabletFriendlyUI = true,
    hotkey = Enum.KeyCode.K,
}

local CFG = getgenv().USH_AuraExtCfg

-- Integración opcional con el CFG principal si existe
local USH = rawget(getgenv(), "UltraStealthCfg")
if typeof(USH) == "table" then
    -- Solo espaciado de nombres, sin colisiones
end

--==== Utils ====--
local function safe(f, ...)
    local ok, r = pcall(f, ...)
    if not ok then warn(r) end
    return ok, r
end

local function getCharHumHrp(plr)
    local c = plr.Character or plr.CharacterAdded:Wait()
    return c, c:FindFirstChildOfClass("Humanoid"), c:FindFirstChild("HumanoidRootPart")
end

local function isAlive(hum)
    return hum and hum.Health and hum.Health > 0
end

local function dot(a,b) return a.X*b.X + a.Y*b.Y + a.Z*b.Z end

local function angleBetween(a, b)
    local m = (a.Magnitude * b.Magnitude)
    if m == 0 then return 180 end
    local d = math.clamp(dot(a, b) / m, -1, 1)
    return math.deg(math.acos(d))
end

local function teamEqual(p1, p2)
    local ok1 = p1 and p1.Team
    local ok2 = p2 and p2.Team
    return ok1 and ok2 and p1.Team == p2.Team
end

local function raycastVisible(from, to, blacklist)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = blacklist or {}
    local result = Workspace:Raycast(from, to - from, params)
    return result
end

--==== Watchdog para evitar el guante gigante (no toco nada si no hace falta) ====--
local function shrinkIfGiant(handle)
    if not CFG.revertGiantHandle or not handle or not handle:IsA("BasePart") then return end
    local big = (handle.Size.X > 4) or (handle.Size.Y > 4) or (handle.Size.Z > 4)
    if big then
        safe(function()
            -- Intenta respetar Mesh si existe, para no romper offsets.
            local mesh = handle:FindFirstChildOfClass("SpecialMesh") or handle:FindFirstChildOfClass("BlockMesh")
            if mesh then
                mesh.Scale = Vector3.new(1,1,1)
            end
            handle.Size = Vector3.new(1,1,1)
            handle.Transparency = math.clamp(handle.Transparency, 0, 0.8) -- no invisibilizamos a la fuerza
        end)
    end
end

local function attachHandleWatchdog(char)
    if not CFG.revertGiantHandle then return end
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            local h = tool:FindFirstChild("Handle")
            if h then shrinkIfGiant(h) end
        end
    end
    char.ChildAdded:Connect(function(inst)
        if inst:IsA("Tool") then
            local h = inst:WaitForChild("Handle", 2)
            if h then
                shrinkIfGiant(h)
                h:GetPropertyChangedSignal("Size"):Connect(function() shrinkIfGiant(h) end)
            end
        end
    end)
end

--==== Núcleo: Hit Aura extendido (proyección hacia adelante) ====--
local State = {
    lastSweep = 0,
    lastHit = {}, -- por Player => os.clock()
}

local function activateAnyTool(char)
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") and tool:FindFirstChild("Handle") then
            tool:Activate()
        end
    end
end

local function shouldHitTarget(myPlr, myHRP, myLook, myHum, targetPlr, tChar, tHum, tHRP)
    if not tChar or not tHRP or not isAlive(tHum) then return false end
    if CFG.ignoreSameTeam and teamEqual(myPlr, targetPlr) then return false end
    local delta = tHRP.Position - myHRP.Position
    if CFG.frontOnly then
        local ang = angleBetween(delta, myLook)
        if ang > (CFG.fovDeg/2) then return false end
        local forward = dot(delta, myLook.Unit)
        if forward <= 0 or forward > CFG.range then return false end
        local perp = delta - myLook.Unit * forward
        if perp.Magnitude > CFG.width then return false end
    else
        if delta.Magnitude > CFG.range then return false end
    end
    if CFG.losCheck then
        local res = raycastVisible(myHRP.Position, tHRP.Position, {tChar, myHum.Parent})
        if res and not res.Instance:IsDescendantOf(tChar) then
            return false
        end
    end
    if not CFG.hitThroughFF and tChar:FindFirstChildOfClass("ForceField") then
        return false
    end
    return true
end

local function sweepAndHit()
    if not CFG.enabled then return end
    local char, hum, hrp = getCharHumHrp(LocalPlayer)
    if not char or not hum or not hrp or not isAlive(hum) then return end

    local cam = Workspace.CurrentCamera
    local look = cam and cam.CFrame.LookVector or hrp.CFrame.LookVector
    local now = os.clock()

    for _, other in ipairs(Players:GetPlayers()) do
        if other ~= LocalPlayer then
            local och, ohum, ohrp = other.Character, nil, nil
            if och then
                ohum = och:FindFirstChildOfClass("Humanoid")
                ohrp = och:FindFirstChild("HumanoidRootPart")
            end
            if shouldHitTarget(LocalPlayer, hrp, look, hum, other, och, ohum, ohrp) then
                local last = State.lastHit[other] or 0
                if now - last >= CFG.delay * 0.6 then
                    activateAnyTool(char)
                    State.lastHit[other] = now
                end
            end
        end
    end
end

-- Bucle
task.spawn(function()
    -- enganchar watchdog de guante
    local c = (LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait())
    attachHandleWatchdog(c)
    LocalPlayer.CharacterAdded:Connect(function(newC)
        task.wait(0.25)
        attachHandleWatchdog(newC)
    end)

    -- latido del aura
    local acc = 0
    RunService.Heartbeat:Connect(function(dt)
        acc += dt
        if acc >= (CFG.delay) then
            acc = 0
            sweepAndHit()
        end
    end)
end)

--==== UI compacta (coexiste con tu hub; táctil y movible) ====--
local function makeButton(parent, text, size, pos)
    local b = Instance.new("TextButton")
    b.Size = size or UDim2.fromOffset(120, 34)
    b.Position = pos or UDim2.new(0,0,0,0)
    b.BackgroundColor3 = Color3.fromRGB(36,36,36)
    b.TextColor3 = Color3.new(1,1,1)
    b.Font = Enum.Font.GothamSemibold
    b.TextSize = 14
    b.TextWrapped = true
    b.Text = text
    b.AutoButtonColor = true
    b.Parent = parent
    return b
end

local function makeLabel(parent, text, size, pos, alignRight)
    local l = Instance.new("TextLabel")
    l.Size = size or UDim2.fromOffset(120, 26)
    l.Position = pos or UDim2.new(0,0,0,0)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = Color3.fromRGB(230,230,230)
    l.Font = Enum.Font.Gotham
    l.TextSize = 13
    l.TextXAlignment = alignRight and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left
    l.Parent = parent
    return l
end

local function makeMiniUI()
    local pg = LocalPlayer:WaitForChild("PlayerGui")
    local gui = Instance.new("ScreenGui")
    gui.Name = "USH_AuraExtUI"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = pg

    local frame = Instance.new("Frame")
    frame.Name = "Panel"
    frame.Size = UDim2.fromOffset(270, CFG.tabletFriendlyUI and 220 or 200)
    frame.Position = UDim2.new(1, -290, 1, -(CFG.tabletFriendlyUI and 240 or 220))
    frame.BackgroundColor3 = Color3.fromRGB(18,18,18)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = gui

    local title = makeLabel(frame, "Hit Aura (K)", UDim2.new(1, -12, 0, 26), UDim2.new(0, 6, 0, 6))
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16

    local toggle = makeButton(frame, CFG.enabled and "ON" or "OFF", UDim2.fromOffset(70, 30), UDim2.new(0, 6, 0, 40))
    local rangeL = makeLabel(frame, "Range", UDim2.fromOffset(120, 20), UDim2.new(0, 86, 0, 42))
    local rangeVal = makeLabel(frame, tostring(CFG.range), UDim2.fromOffset(50, 20), UDim2.new(1, -56, 0, 42), true)
    local rMinus = makeButton(frame, "-", UDim2.fromOffset(30, 28), UDim2.new(0, 86, 0, 64))
    local rPlus  = makeButton(frame, "+", UDim2.fromOffset(30, 28), UDim2.new(0, 120, 0, 64))

    local widthL = makeLabel(frame, "Width", UDim2.fromOffset(120, 20), UDim2.new(0, 86, 0, 98))
    local widthVal = makeLabel(frame, tostring(CFG.width), UDim2.fromOffset(50, 20), UDim2.new(1, -56, 0, 98), true)
    local wMinus = makeButton(frame, "-", UDim2.fromOffset(30, 28), UDim2.new(0, 86, 0, 120))
    local wPlus  = makeButton(frame, "+", UDim2.fromOffset(30, 28), UDim2.new(0, 120, 0, 120))

    local delayL = makeLabel(frame, "Delay", UDim2.fromOffset(120, 20), UDim2.new(0, 86, 0, 154))
    local delayVal = makeLabel(frame, tostring(CFG.delay), UDim2.fromOffset(50, 20), UDim2.new(1, -56, 0, 154), true)
    local dMinus = makeButton(frame, "-", UDim2.fromOffset(30, 28), UDim2.new(0, 86, 0, 176))
    local dPlus  = makeButton(frame, "+", UDim2.fromOffset(30, 28), UDim2.new(0, 120, 0, 176))

    local modeBtn = makeButton(frame, CFG.frontOnly and "Mode: Cono" : "Mode: Esfera", UDim2.fromOffset(110, 28), UDim2.new(1, -120, 0, 64))
    local fovBtn  = makeButton(frame, "FOV: " .. tostring(CFG.fovDeg), UDim2.fromOffset(110, 28), UDim2.new(1, -120, 0, 120))
    local losBtn  = makeButton(frame, CFG.losCheck and "LOS: ON" or "LOS: OFF", UDim2.fromOffset(110, 28), UDim2.new(1, -120, 0, 176))

    local function refresh()
        toggle.Text = CFG.enabled and "ON" or "OFF"
        rangeVal.Text = tostring(math.floor(CFG.range + 0.5))
        widthVal.Text = tostring(math.floor(CFG.width + 0.5))
        delayVal.Text = string.format("%.2f", CFG.delay)
        modeBtn.Text = CFG.frontOnly and "Mode: Cono" or "Mode: Esfera"
        fovBtn.Text  = "FOV: " .. tostring(CFG.fovDeg)
        losBtn.Text  = CFG.losCheck and "LOS: ON" or "LOS: OFF"
    end

    toggle.MouseButton1Click:Connect(function()
        CFG.enabled = not CFG.enabled
        refresh()
    end)
    rMinus.MouseButton1Click:Connect(function() CFG.range = math.max(4, CFG.range - 2); refresh() end)
    rPlus.MouseButton1Click:Connect(function() CFG.range = math.min(1000, CFG.range + 2); refresh() end)

    wMinus.MouseButton1Click:Connect(function() CFG.width = math.max(1, CFG.width - 1); refresh() end)
    wPlus.MouseButton1Click:Connect(function() CFG.width = math.min(50, CFG.width + 1); refresh() end)

    dMinus.MouseButton1Click:Connect(function() CFG.delay = math.max(0.02, CFG.delay - 0.01); refresh() end)
    dPlus.MouseButton1Click:Connect(function() CFG.delay = math.min(0.5,  CFG.delay + 0.01); refresh() end)

    modeBtn.MouseButton1Click:Connect(function() CFG.frontOnly = not CFG.frontOnly; refresh() end)
    fovBtn.MouseButton1Click:Connect(function()
        -- ciclo 60, 90, 120, 180
        local seq = {60, 90, 120, 180}
        local idx = 1
        for i,v in ipairs(seq) do if v == CFG.fovDeg then idx = i break end end
        CFG.fovDeg = seq[(idx % #seq) + 1]
        refresh()
    end)
    losBtn.MouseButton1Click:Connect(function() CFG.losCheck = not CFG.losCheck; refresh() end)

    -- gesto táctil: arrastre ya habilitado (Draggable)
    refresh()
end

task.defer(makeMiniUI)

--==== Hotkey ====--
UIS.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == CFG.hotkey then
        CFG.enabled = not CFG.enabled
    end
end)

--==== Nota: 
-- - No se escala el Handle en ningún momento.
-- - El "watchdog" solo corrige Handles gigantes si aparece alguno (opcional por CFG).
-- - El barrido golpea a distancia real usando proyección al frente (cono/cápsula).
-- - Coexiste con tu hub actual y su GUI. Este panel es independiente y movible.
-- - Ajusta el hotkey en CFG.hotkey si lo prefieres.


