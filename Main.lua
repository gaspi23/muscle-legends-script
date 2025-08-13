-- Ultra Touch GUI (Tablet) + Fallback funcional + AURA HIT Extendido (sin guante gigante)
-- Luis x Copilot

-- Servicios
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

-- Utilidades
local function notify(t, d)
    pcall(function()
        StarterGui:SetCore("SendNotification", { Title = "Ultra Touch", Text = t, Duration = d or 1.8 })
    end)
end

local function clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi else return v end
end

-- Entorno compartido
local ENV = (getgenv and getgenv()) or _G
if ENV.USH_GUI_LOADED then return end
ENV.USH_GUI_LOADED = true

ENV.USH_CFG = ENV.USH_CFG or {
    guiPos = {0.06, 0.16},
    uiScale = 1.0,
    opacity = 0.92,
}

ENV.USH_STATE = ENV.USH_STATE or {}
local STATE = ENV.USH_STATE

-- Conexiones
local Conns = { char = {}, noclip = {}, speed = {}, aura = {}, ui = {} }
local function disconnectAll(t)
    for _, c in ipairs(t) do pcall(function() c:Disconnect() end) end
    table.clear(t)
end

-- Referencias de character con auto-rebind
local char, hum, hrp
local function getChar()
    local c = player.Character or player.CharacterAdded:Wait()
    return c, c:WaitForChild("Humanoid"), c:WaitForChild("HumanoidRootPart")
end

local function isAlive(h) return h and h.Health > 0 end

--============================= Fallback: estado base =============================--
STATE.walkSpeed   = STATE.walkSpeed   or 16
STATE.sprintSpeed = STATE.sprintSpeed or 80
STATE.flySpeed    = STATE.flySpeed    or 60
STATE.sprint      = STATE.sprint      or false
STATE.noclip      = STATE.noclip      or false

--============================= AURA HIT Extendido (sin guante gigante) =========--
-- Configura alcance real por proyección (cono/cápsula) o esfera
STATE.aura            = STATE.aura            or false
STATE.auraRange       = clamp(STATE.auraRange or 25, 4, 1000) -- distancia máxima
STATE.auraWidth       = STATE.auraWidth       or 6            -- radio lateral (capsula)
STATE.auraDelay       = STATE.auraDelay       or 0.12         -- intervalo entre barridos
STATE.auraFOV         = STATE.auraFOV         or 90           -- ángulo de visión
STATE.auraFrontOnly   = STATE.auraFrontOnly ~= false          -- true=cono/cápsula
STATE.auraLOS         = STATE.auraLOS ~= false                -- línea de visión
STATE.auraIgnoreTeam  = STATE.auraIgnoreTeam ~= false         -- ignorar mismo equipo
STATE.auraHotkey      = STATE.auraHotkey or Enum.KeyCode.K

--============================= Velocidad: aplicación y guardia ==================--
local function applyWalkSpeed()
    if not hum then return end
    local target = STATE.sprint and STATE.sprintSpeed or STATE.walkSpeed
    STATE._desiredSpeed = target
    hum.WalkSpeed = target
end

local function startSpeedGuard()
    disconnectAll(Conns.speed)
    if hum then
        table.insert(Conns.speed, hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
            local target = STATE._desiredSpeed
            if target and math.abs((hum.WalkSpeed or 0) - target) > 0.5 then
                hum.WalkSpeed = target
            end
        end))
    end
    table.insert(Conns.speed, RunService.Heartbeat:Connect(function()
        if hum and STATE._desiredSpeed and math.abs(hum.WalkSpeed - STATE._desiredSpeed) > 0.5 then
            hum.WalkSpeed = STATE._desiredSpeed
        end
    end))
end

--============================= Noclip real (Stepped) ============================--
local function setNoCollide(model, on)
    for _, v in ipairs(model:GetDescendants()) do
        if v:IsA("BasePart") then
            v.CanCollide = not on
        end
    end
end

-- Exponer fallbacks (compatibilidad con otros hubs)
local G = ENV

G.noclipOn_fallback = function(silent)
    if STATE.noclip then return end
    STATE.noclip = true
    if not char or not char.Parent then return end
    setNoCollide(char, true)
    disconnectAll(Conns.noclip)
    table.insert(Conns.noclip, RunService.Stepped:Connect(function()
        if STATE.noclip and char and char.Parent then
            setNoCollide(char, true)
        end
    end))
    if not silent then notify("Noclip ON") end
end

G.noclipOff_fallback = function(silent)
    if not STATE.noclip then return end
    STATE.noclip = false
    disconnectAll(Conns.noclip)
    if char and char.Parent then setNoCollide(char, false) end
    if not silent then notify("Noclip OFF") end
end

-- Speeds fallbacks
G.setWalkSpeed_fallback = function(v) v = clamp(v, 8, 300);  STATE.walkSpeed   = v; applyWalkSpeed() end
G.setSprintSpeed_fallback = function(v) v = clamp(v, 16, 800); STATE.sprintSpeed = v; applyWalkSpeed() end
G.setFlySpeed_fallback = function(v) v = clamp(v, 10, 1200); STATE.flySpeed    = v end
G.sprintOn_fallback = function() STATE.sprint = true;  applyWalkSpeed(); notify("Sprint ON", 1.2) end
G.sprintOff_fallback = function() STATE.sprint = false; applyWalkSpeed(); notify("Sprint OFF", 1.2) end

--============================= AURA HIT engine (alcance real) ===================--
-- Importante: ELIMINADO el escalado de Handle. No tocamos tamaño del guante.
local function dot(a, b) return a.X*b.X + a.Y*b.Y + a.Z*b.Z end
local function angleBetween(a, b)
    local m = (a.Magnitude * b.Magnitude)
    if m == 0 then return 180 end
    local d = math.clamp(dot(a, b) / m, -1, 1)
    return math.deg(math.acos(d))
end

local function teamEqual(p1, p2)
    if not p1 or not p2 then return false end
    if p1.Team == nil or p2.Team == nil then return false end
    return p1.Team == p2.Team
end

local function raycastClear(fromPos, toPos, blacklist)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = blacklist or {}
    local res = Workspace:Raycast(fromPos, (toPos - fromPos), params)
    return res
end

local function getEquippedTool()
    if not char then return nil end
    for _, c in ipairs(char:GetChildren()) do
        if c:IsA("Tool") and c:FindFirstChild("Handle") then
            return c
        end
    end
    return nil
end

local function activateAnyTool()
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") and tool:FindFirstChild("Handle") then
            tool:Activate()
        end
    end
end

local lastHitPerTarget = {} -- Player -> os.clock()

local function shouldHitTarget(myHRP, look, myPlr, otherPlr, oHRP, oHum)
    if not oHRP or not oHum or not isAlive(oHum) then return false end
    if STATE.auraIgnoreTeam and teamEqual(myPlr, otherPlr) then return false end

    local delta = oHRP.Position - myHRP.Position
    if STATE.auraFrontOnly then
        if angleBetween(delta, look) > (STATE.auraFOV / 2) then return false end
        local forward = dot(delta, look.Unit)
        if forward <= 0 or forward > STATE.auraRange then return false end
        local perp = delta - look.Unit * forward
        if perp.Magnitude > STATE.auraWidth then return false end
    else
        if delta.Magnitude > STATE.auraRange then return false end
    end

    if STATE.auraLOS then
        local res = raycastClear(myHRP.Position, oHRP.Position, {char, otherPlr.Character})
        if res and not res.Instance:IsDescendantOf(otherPlr.Character) then
            return false
        end
    end
    return true
end

local function heartbeatAura()
    disconnectAll(Conns.aura)
    if not STATE.aura then return end

    local acc = 0
    table.insert(Conns.aura, RunService.Heartbeat:Connect(function(dt)
        acc += dt
        if acc < (STATE.auraDelay or 0.12) then return end
        acc = 0

        char, hum, hrp = getChar()
        if not isAlive(hum) then return end

        local cam = Workspace.CurrentCamera
        local look = (cam and cam.CFrame.LookVector) or hrp.CFrame.LookVector
        local now = os.clock()

        for _, other in ipairs(Players:GetPlayers()) do
            if other ~= player and other.Character then
                local oHum = other.Character:FindFirstChildOfClass("Humanoid")
                local oHRP = other.Character:FindFirstChild("HumanoidRootPart")
                if shouldHitTarget(hrp, look, player, other, oHRP, oHum) then
                    local last = lastHitPerTarget[other] or 0
                    if now - last >= (STATE.auraDelay * 0.6) then
                        activateAnyTool()
                        lastHitPerTarget[other] = now
                    end
                end
            end
        end
    end))
end

local function auraOn()
    if STATE.aura then return end
    STATE.aura = true
    heartbeatAura()
    notify("AURA HIT ON", 1.2)
end

local function auraOff()
    if not STATE.aura then return end
    STATE.aura = false
    disconnectAll(Conns.aura)
    notify("AURA HIT OFF", 1.2)
end

--============================= Rebind character y reaplicar =====================--
local function rebindCharacter()
    disconnectAll(Conns.char)
    char, hum, hrp = getChar()
    applyWalkSpeed()
    if STATE.noclip then G.noclipOn_fallback(true) end
    if STATE.aura then heartbeatAura() end
end

table.insert(Conns.char, player.CharacterAdded:Connect(function()
    task.wait(0.15)
    rebindCharacter()
end))

rebindCharacter()
applyWalkSpeed()
startSpeedGuard()

--============================= API de hub externo (si existe) ===================--
local EXPOSED = ENV.USH or ENV.USE or ENV.STEALTH or ENV.HUB or ENV
local API = {
    Noclip = {
        get = function() return (EXPOSED.State and EXPOSED.State.noclip) or STATE.noclip end,
        on  = function() if typeof(EXPOSED.noclipOn)  == "function" then EXPOSED.noclipOn()  else G.noclipOn_fallback()  end end,
        off = function() if typeof(EXPOSED.noclipOff) == "function" then EXPOSED.noclipOff() else G.noclipOff_fallback() end end,
        desc = "Atravesar objetos",
    },
    Sprint = {
        get = function() return (EXPOSED.State and EXPOSED.State.sprint) or STATE.sprint end,
        on  = function() if typeof(EXPOSED.sprintOn)  == "function" then EXPOSED.sprintOn()  else G.sprintOn_fallback()  end end,
        off = function() if typeof(EXPOSED.sprintOff) == "function" then EXPOSED.sprintOff() else G.sprintOff_fallback() end end,
        desc = "Correr más rápido",
    },
    Fly = {
        get = function() return (EXPOSED.State and EXPOSED.State.fly) or (STATE.fly or false) end,
        on  = function() if typeof(EXPOSED.flyOn)  == "function" then EXPOSED.flyOn()  else notify("Conecta tu Fly del hub") end end,
        off = function() if typeof(EXPOSED.flyOff) == "function" then EXPOSED.flyOff() else notify("Conecta tu Fly del hub") end end,
        desc = "Vuelo libre",
    },
    Invis = {
        get = function() return (EXPOSED.State and EXPOSED.State.invisRep) or (STATE.invisRep or false) end,
        on  = function() if typeof(EXPOSED.invisRepOn)  == "function" then EXPOSED.invisRepOn()  else notify("Conecta InvisRep del hub") end end,
        off = function() if typeof(EXPOSED.invisRepOff) == "function" then EXPOSED.invisRepOff() else notify("Conecta InvisRep del hub") end end,
        desc = "Invisibilidad replicada",
    },
    Ghost = {
        get = function() return (EXPOSED.State and EXPOSED.State.ghost) or (STATE.ghost or false) end,
        on  = function() if typeof(EXPOSED.ghostOn)  == "function" then EXPOSED.ghostOn()  else notify("Conecta Ghost del hub") end end,
        off = function() if typeof(EXPOSED.ghostOff) == "function" then EXPOSED.ghostOff() else notify("Conecta Ghost del hub") end end,
        desc = "Colisión fantasma",
    },

    -- Speeds
    WalkSpeed = {
        get = function() return (EXPOSED.State and (EXPOSED.State.walkSpeed or EXPOSED.State.speedWalk)) or STATE.walkSpeed end,
        set = function(v) if typeof(EXPOSED.setWalkSpeed) == "function" then EXPOSED.setWalkSpeed(v) else G.setWalkSpeed_fallback(v) end end,
        min=8, max=300, step=2, desc = "Velocidad caminar",
    },
    SprintSpeed = {
        get = function() return (EXPOSED.State and (EXPOSED.State.sprintSpeed or EXPOSED.State.speedSprint)) or STATE.sprintSpeed end,
        set = function(v) if typeof(EXPOSED.setSprintSpeed) == "function" then EXPOSED.setSprintSpeed(v) else G.setSprintSpeed_fallback(v) end end,
        min=16, max=800, step=5, desc = "Velocidad sprint",
    },
    FlySpeed = {
        get = function() return (EXPOSED.State and (EXPOSED.State.flySpeed or EXPOSED.State.speedFly)) or STATE.flySpeed end,
        set = function(v) if typeof(EXPOSED.setFlySpeed) == "function" then EXPOSED.setFlySpeed(v) else G.setFlySpeed_fallback(v) end end,
        min=10, max=1200, step=10, desc = "Velocidad vuelo",
    },

    -- Aura Hit extendido
    Aura = {
        get = function() return (EXPOSED.State and EXPOSED.State.aura) or STATE.aura end,
        on  = function() if typeof(EXPOSED.auraOn)  == "function" then EXPOSED.auraOn()  else auraOn()  end end,
        off = function() if typeof(EXPOSED.auraOff) == "function" then EXPOSED.auraOff() else auraOff() end end,
        desc = "Golpe de alcance extendido",
    },
    AuraRange = {
        get = function() return STATE.auraRange end,
        set = function(v) STATE.auraRange = clamp(v, 4, 1000) end,
        min=4, max=1000, step=2, desc = "Distancia (studs)",
    },
    AuraWidth = {
        get = function() return STATE.auraWidth end,
        set = function(v) STATE.auraWidth = clamp(v, 1, 50) end,
        min=1, max=50, step=1, desc = "Anchura cápsula (studs)",
    },
    AuraDelay = {
        get = function() return STATE.auraDelay end,
        set = function(v) STATE.auraDelay = clamp(v, 0.02, 0.5) end,
        min=0.02, max=0.5, step=0.01, desc = "Intervalo (s)",
    },
    AuraFOV = {
        get = function() return STATE.auraFOV end,
        set = function(v) STATE.auraFOV = clamp(v, 30, 180) end,
        min=30, max=180, step=5, desc = "Ángulo de visión",
    },
    AuraMode = {
        get = function() return STATE.auraFrontOnly end, -- true=Cono, false=Esfera
        toggle = function() STATE.auraFrontOnly = not STATE.auraFrontOnly end,
        desc = "Modo: Cono/Esfera",
    },
    AuraLOS = {
        get = function() return STATE.auraLOS end,
        toggle = function() STATE.auraLOS = not STATE.auraLOS end,
        desc = "Línea de visión",
    },
}

--============================= GUI Builder (tablet-first) =======================--
local function New(c, p, children)
    local o = Instance.new(c)
    for k, v in pairs(p or {}) do o[k] = v end
    if children then for _, ch in ipairs(children) do ch.Parent = o end end
    return o
end

local Screen = New("ScreenGui", { Name = "UltraTouchGUI", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Global })
Screen.Parent = player:WaitForChild("PlayerGui")

local UIScale = New("UIScale", { Scale = ENV.USH_CFG.uiScale or 1.0 })
UIScale.Parent = Screen

local Root = New("Frame", {
    BackgroundColor3 = Color3.fromRGB(20, 20, 24),
    BackgroundTransparency = 1 - (ENV.USH_CFG.opacity or 0.92),
    Size = UDim2.new(0, 460, 0, 560),
    Position = UDim2.fromScale(ENV.USH_CFG.guiPos[1] or 0.06, ENV.USH_CFG.guiPos[2] or 0.16)
})
Root.Parent = Screen
New("UICorner", { CornerRadius = UDim.new(0, 12) }).Parent = Root
New("UIStroke", { Thickness = 1, Transparency = 0.5, Color = Color3.fromRGB(60, 60, 70) }).Parent = Root

local Top = New("Frame", { BackgroundColor3 = Color3.fromRGB(34, 34, 42), Size = UDim2.new(1, 0, 0, 50) })
Top.Parent = Root
local Title = New("TextLabel", {
    BackgroundTransparency = 1,
    Text = "Ultra Stealth Touch",
    Font = Enum.Font.GothamSemibold,
    TextSize = 18,
    TextColor3 = Color3.fromRGB(240, 240, 245),
    TextXAlignment = Enum.TextXAlignment.Left,
    Position = UDim2.new(0, 14, 0, 0),
    Size = UDim2.new(0.7, 0, 1, 0)
})
Title.Parent = Top

local Close = New("TextButton", {
    Text = "X",
    Font = Enum.Font.GothamBold,
    TextSize = 18,
    BackgroundTransparency = 1,
    TextColor3 = Color3.fromRGB(240, 240, 245),
    Size = UDim2.new(0, 48, 1, 0),
    Position = UDim2.new(1, -48, 0, 0)
})
Close.Parent = Top
Close.MouseButton1Click:Connect(function() Screen.Enabled = false end)

-- Drag táctil/mouse
do
    local dragging, startPos, startInput
    Top.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            startPos = i.Position
            startInput = i
        end
    end)
    Top.InputEnded:Connect(function(i)
        if i == startInput then dragging = false end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and (i == startInput or i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseMovement) then
            local delta = i.Position - startPos
            local vp = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
            local nx = math.clamp(Root.Position.X.Scale + delta.X / vp.X, 0, 1)
            local ny = math.clamp(Root.Position.Y.Scale + delta.Y / vp.Y, 0, 1)
            Root.Position = UDim2.fromScale(nx, ny)
            ENV.USH_CFG.guiPos = { nx, ny }
            startPos = i.Position
        end
    end)
end

-- Tabs y contenido
local Tabs = New("Frame", { BackgroundColor3 = Color3.fromRGB(34, 34, 42), Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 0, 50) })
Tabs.Parent = Root

local Body = New("ScrollingFrame", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 1, -100),
    Position = UDim2.new(0, 0, 0, 90),
    ScrollBarThickness = 6,
    CanvasSize = UDim2.new(0, 0, 0, 0)
})
Body.Parent = Root

local Layout = New("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder })
Layout.Parent = Body

local Pad = New("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12) })
Pad.Parent = Body

local function updateCanvas()
    Body.CanvasSize = UDim2.new(0, 0, 0, Layout.AbsoluteContentSize.Y + 24)
end
Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)

local function pill(h)
    local f = New("Frame", { BackgroundColor3 = Color3.fromRGB(28, 28, 34), Size = UDim2.new(1, 0, 0, h or 52) })
    f.Parent = Body
    New("UICorner", { CornerRadius = UDim.new(0, 10) }).Parent = f
    New("UIStroke", { Thickness = 1, Transparency = 0.4, Color = Color3.fromRGB(55, 55, 65) }).Parent = f
    return f
end

local function text(parent, t, sub)
    local l = New("TextLabel", {
        BackgroundTransparency = 1,
        Text = t,
        Font = Enum.Font.GothamSemibold,
        TextSize = 16,
        TextColor3 = Color3.fromRGB(235, 235, 240),
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 12, 0, 6),
        Size = UDim2.new(1, -140, 0, 20)
    })
    l.Parent = parent
    if sub then
        local s = New("TextLabel", {
            BackgroundTransparency = 1,
            Text = sub,
            Font = Enum.Font.Gotham,
            TextSize = 12,
            TextColor3 = Color3.fromRGB(170, 170, 180),
            TextXAlignment = Enum.TextXAlignment.Left,
            Position = UDim2.new(0, 12, 0, 26),
            Size = UDim2.new(1, -140, 0, 18)
        })
        s.Parent = parent
    end
end

local function makeToggle(name, desc, getFn, onFn, offFn)
    local fr = pill(52); text(fr, name, desc)
    local btn = New("TextButton", {
        Text = "",
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = Color3.new(1,1,1),
        Size = UDim2.new(0, 108, 0, 34),
        Position = UDim2.new(1, -120, 0, 9),
        AutoButtonColor = true
    })
    btn.Parent = fr
    New("UICorner", { CornerRadius = UDim.new(0,8) }).Parent = btn
    local function refresh()
        local v = false; pcall(function() v = getFn() end)
        btn.Text = v and "ON" or "OFF"
        btn.BackgroundColor3 = v and Color3.fromRGB(30,140,90) or Color3.fromRGB(140,40,50)
    end
    btn.MouseButton1Click:Connect(function()
        local v = false; pcall(function() v = getFn() end)
        if v then offFn() else onFn() end
        refresh()
    end)
    refresh()
end

local function makeStepper(name, desc, getFn, setFn, min, max, step)
    local fr = pill(64); text(fr, name, desc)
    local minus = New("TextButton", {
        Text = "-",
        Font = Enum.Font.GothamBold,
        TextSize = 20,
        TextColor3 = Color3.new(1,1,1),
        BackgroundColor3 = Color3.fromRGB(40,40,48),
        Size = UDim2.new(0, 44, 0, 34),
        Position = UDim2.new(1, -210, 0, 22)
    })
    minus.Parent = fr; New("UICorner", { CornerRadius = UDim.new(0,8) }).Parent = minus

    local box = New("TextBox", {
        Text = "",
        PlaceholderText = "--",
        Font = Enum.Font.GothamSemibold,
        TextSize = 16,
        TextColor3 = Color3.new(1,1,1),
        BackgroundColor3 = Color3.fromRGB(40,40,48),
        ClearTextOnFocus = false,
        Size = UDim2.new(0, 110, 0, 34),
        Position = UDim2.new(1, -160, 0, 22)
    })
    box.Parent = fr; New("UICorner", { CornerRadius = UDim.new(0,8) }).Parent = box

    local plus = New("TextButton", {
        Text = "+",
        Font = Enum.Font.GothamBold,
        TextSize = 20,
        TextColor3 = Color3.new(1,1,1),
        BackgroundColor3 = Color3.fromRGB(40,40,48),
        Size = UDim2.new(0, 44, 0, 34),
        Position = UDim2.new(1, -44, 0, 22)
    })
    plus.Parent = fr; New("UICorner", { CornerRadius = UDim.new(0,8) }).Parent = plus

    local function current() local v=0 pcall(function() v = getFn() end) return v end
    local function set(v) pcall(function() setFn(v) end) end
    local function clampStep(v)
        v = math.clamp(v, min, max)
        local s = step or 1
        v = math.floor((v + s/2) / s) * s
        return v
    end
    local function refresh() box.Text = tostring(current()) end

    minus.MouseButton1Click:Connect(function() set(clampStep(current() - (step or 1))); refresh() end)
    plus.MouseButton1Click:Connect(function()  set(clampStep(current() + (step or 1))); refresh() end)
    box.FocusLost:Connect(function(enter)
        local n = tonumber(box.Text)
        if n then set(clampStep(n)) else box.Text = tostring(current()) end
    end)
    refresh()
end

local function makeButtonSmall(name, desc, getLabelFn, onClick)
    local fr = pill(64); text(fr, name, desc)
    local btn = New("TextButton", {
        Text = getLabelFn(),
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = Color3.new(1,1,1),
        BackgroundColor3 = Color3.fromRGB(40,40,48),
        Size = UDim2.new(0, 140, 0, 34),
        Position = UDim2.new(1, -150, 0, 22)
    })
    btn.Parent = fr; New("UICorner", { CornerRadius = UDim.new(0,8) }).Parent = btn
    btn.MouseButton1Click:Connect(function()
        onClick()
        btn.Text = getLabelFn()
    end)
end

-- Construcción de tabs
local function clearBody()
    for _, g in ipairs(Body:GetChildren()) do
        if g:IsA("GuiObject") then g:Destroy() end
    end
end

local function buildMovimiento()
    makeToggle("Noclip", "Atravesar objetos", API.Noclip.get, API.Noclip.on, API.Noclip.off)
    makeToggle("Sprint", "Correr más rápido", API.Sprint.get, API.Sprint.on, API.Sprint.off)
    makeToggle("Fly", "Vuelo (si tu hub lo expone)", API.Fly.get, API.Fly.on, API.Fly.off)

    makeStepper("WalkSpeed", "Velocidad al caminar", API.WalkSpeed.get, API.WalkSpeed.set, API.WalkSpeed.min, API.WalkSpeed.max, API.WalkSpeed.step)
    makeStepper("SprintSpeed", "Velocidad en sprint", API.SprintSpeed.get, API.SprintSpeed.set, API.SprintSpeed.min, API.SprintSpeed.max, API.SprintSpeed.step)
    makeStepper("FlySpeed", "Velocidad de vuelo (referencia)", API.FlySpeed.get, API.FlySpeed.set, API.FlySpeed.min, API.FlySpeed.max, API.FlySpeed.step)

    -- NUEVO: AURA HIT Extendido (sin guante gigante)
    makeToggle("AURA HIT", "Golpe a distancia (proyección real)", API.Aura.get, API.Aura.on, API.Aura.off)
    makeStepper("Aura Range", "Distancia (4 .. 1000 studs)", API.AuraRange.get, API.AuraRange.set, API.AuraRange.min, API.AuraRange.max, API.AuraRange.step)
    makeStepper("Aura Width", "Ancho cápsula (1 .. 50)", API.AuraWidth.get, API.AuraWidth.set, API.AuraWidth.min, API.AuraWidth.max, API.AuraWidth.step)
    makeStepper("Aura Delay", "Intervalo barrido (0.02 .. 0.5 s)", API.AuraDelay.get, API.AuraDelay.set, API.AuraDelay.min, API.AuraDelay.max, API.AuraDelay.step)
    makeStepper("Aura FOV", "Ángulo de visión (30 .. 180)", API.AuraFOV.get, API.AuraFOV.set, API.AuraFOV.min, API.AuraFOV.max, API.AuraFOV.step)

    makeButtonSmall("Modo Aura", "Alterna Cono / Esfera", function()
        return API.AuraMode.get() and "Mode: Cono" or "Mode: Esfera"
    end, function()
        API.AuraMode.toggle()
    end)

    makeButtonSmall("Línea de visión", "Evita golpear tras paredes", function()
        return API.AuraLOS.get() and "LOS: ON" or "LOS: OFF"
    end, function()
        API.AuraLOS.toggle()
    end)
end

local function buildStealth()
    makeToggle("Invis", "Invisibilidad replicada (si tu hub la tiene)", API.Invis.get, API.Invis.on, API.Invis.off)
    makeToggle("Ghost", "Colisión fantasma (si tu hub la tiene)", API.Ghost.get, API.Ghost.on, API.Ghost.off)
end

local function buildAjustes()
    makeStepper("Opacidad UI", "Transparencia (40-100%)",
        function() return math.floor((ENV.USH_CFG.opacity or 0.92)*100 + 0.5) end,
        function(v) ENV.USH_CFG.opacity = math.clamp(v/100, 0.4, 1.0); Root.BackgroundTransparency = 1 - ENV.USH_CFG.opacity end,
        40, 100, 5
    )
    makeStepper("Escala UI", "Tamaño (50-150%)",
        function() return math.floor((ENV.USH_CFG.uiScale or 1.0)*100 + 0.5) end,
        function(v) ENV.USH_CFG.uiScale = math.clamp(v/100, 0.5, 1.5); UIScale.Scale = ENV.USH_CFG.uiScale end,
        50, 150, 5
    )
    local fr = pill(52); text(fr, "Posición", "Recentrar GUI")
    local rec = New("TextButton", {
        Text = "Recentrar",
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        TextColor3 = Color3.new(1,1,1),
        BackgroundColor3 = Color3.fromRGB(40,40,48),
        Size = UDim2.new(0, 120, 0, 34),
        Position = UDim2.new(1, -130, 0, 9)
    })
    rec.Parent = fr; New("UICorner", { CornerRadius = UDim.new(0,8) }).Parent = rec
    rec.MouseButton1Click:Connect(function()
        Root.Position = UDim2.fromScale(0.06, 0.16)
        ENV.USH_CFG.guiPos = {0.06, 0.16}
        Screen.Enabled = true
    end)
end

local function tabBtn(label, x, idx, onClick)
    local b = New("TextButton", {
        Text = label,
        Font = Enum.Font.GothamSemibold,
        TextSize = 14,
        TextColor3 = Color3.fromRGB(235,235,240),
        BackgroundColor3 = Color3.fromRGB(34,34,42),
        Size = UDim2.new(0, 120, 1, 0),
        Position = UDim2.new(0, x, 0, 0)
    })
    b.Parent = Tabs
    b.MouseButton1Click:Connect(onClick)
    return b
end

local function buildTab(i)
    clearBody()
    if i == 1 then buildMovimiento()
    elseif i == 2 then buildStealth()
    else buildAjustes() end
    updateCanvas()
end

local currentTab = 1
tabBtn("Movimiento", 8, 1, function() currentTab = 1; buildTab(1) end)
tabBtn("Stealth",   136, 2, function() currentTab = 2; buildTab(2) end)
tabBtn("Ajustes",   264, 3, function() currentTab = 3; buildTab(3) end)
buildTab(1)

notify("GUI táctil lista. Noclip, velocidad y Aura extendido.")

--============================= Hotkey Aura =====================================--
UIS.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == STATE.auraHotkey then
        if STATE.aura then auraOff() else auraOn() end
    end
end)
