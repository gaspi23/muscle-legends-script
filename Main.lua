-- Ultra Touch GUI - Wrapper visual para tu Hub (tablet-first)
-- No modifica tu lógica interna. Enlaza a tus funciones si existen.
-- Autor: Copilot x Luis - 2025-08

-- ============ Guardas / entorno ============
local function safeGetEnv()
    local ok, env = pcall(function()
        return (getgenv and getgenv()) or _G
    end)
    return ok and env or _G
end

local ENV = safeGetEnv()
if ENV.USH_GUI_LOADED then return end
ENV.USH_GUI_LOADED = true

ENV.USH_CFG = ENV.USH_CFG or {
    guiPos = {0.05, 0.15},
    uiScale = 1.0,
    opacity = 0.9,
}
ENV.USH_STATE = ENV.USH_STATE or {} -- fallback de estado si tu hub no lo expone

-- ============ Detección de API de tu hub ============
-- Intenta detectar tu API expuesta en alguno de estos objetos:
local EXPOSED = ENV.USH or ENV.USE or ENV.STEALTH or ENV.HUB or ENV -- ajustable

-- Mapea aquí los nombres de funciones y lectura de estado de tu hub.
-- Ajusta si tus nombres difieren.
local API = {
    -- TOGGLES
    Noclip = {
        get = function()
            return (EXPOSED.State and EXPOSED.State.noclip)
                or ENV.USH_STATE.noclip or false
        end,
        on = function() if typeof(EXPOSED.noclipOn)=="function" then EXPOSED.noclipOn() end ENV.USH_STATE.noclip=true end,
        off= function() if typeof(EXPOSED.noclipOff)=="function" then EXPOSED.noclipOff() end ENV.USH_STATE.noclip=false end,
        desc="Atravesar objetos",
    },
    Fly = {
        get = function() return (EXPOSED.State and EXPOSED.State.fly) or ENV.USH_STATE.fly or false end,
        on  = function() if typeof(EXPOSED.flyOn)=="function" then EXPOSED.flyOn() end ENV.USH_STATE.fly=true end,
        off = function() if typeof(EXPOSED.flyOff)=="function" then EXPOSED.flyOff() end ENV.USH_STATE.fly=false end,
        desc="Vuelo libre",
    },
    Sprint = {
        get = function() return (EXPOSED.State and EXPOSED.State.sprint) or ENV.USH_STATE.sprint or false end,
        on  = function() if typeof(EXPOSED.sprintOn)=="function" then EXPOSED.sprintOn() end ENV.USH_STATE.sprint=true end,
        off = function() if typeof(EXPOSED.sprintOff)=="function" then EXPOSED.sprintOff() end ENV.USH_STATE.sprint=false end,
        desc="Carrera",
    },
    Invis = {
        get = function() return (EXPOSED.State and EXPOSED.State.invisRep) or ENV.USH_STATE.invisRep or false end,
        on  = function() if typeof(EXPOSED.invisRepOn)=="function" then EXPOSED.invisRepOn() end ENV.USH_STATE.invisRep=true end,
        off = function() if typeof(EXPOSED.invisRepOff)=="function" then EXPOSED.invisRepOff() end ENV.USH_STATE.invisRep=false end,
        desc="Invisibilidad/replicación",
    },
    Ghost = {
        get = function() return (EXPOSED.State and EXPOSED.State.ghost) or ENV.USH_STATE.ghost or false end,
        on  = function() if typeof(EXPOSED.ghostOn)=="function" then EXPOSED.ghostOn() end ENV.USH_STATE.ghost=true end,
        off = function() if typeof(EXPOSED.ghostOff)=="function" then EXPOSED.ghostOff() end ENV.USH_STATE.ghost=false end,
        desc="Colisiones fantasma",
    },
    NoHit = {
        get = function() return (EXPOSED.State and EXPOSED.State.noHitBubble) or ENV.USH_STATE.noHitBubble or false end,
        on  = function() if typeof(EXPOSED.noHitOn)=="function" then EXPOSED.noHitOn() end ENV.USH_STATE.noHitBubble=true end,
        off = function() if typeof(EXPOSED.noHitOff)=="function" then EXPOSED.noHitOff() end ENV.USH_STATE.noHitBubble=false end,
        desc="Evitar hitbox/bubble",
    },
    AntiRestore = {
        get = function() return (EXPOSED.State and EXPOSED.State.antiRestore) or ENV.USH_STATE.antiRestore or false end,
        on  = function() if typeof(EXPOSED.antiRestoreOn)=="function" then EXPOSED.antiRestoreOn() end ENV.USH_STATE.antiRestore=true end,
        off = function() if typeof(EXPOSED.antiRestoreOff)=="function" then EXPOSED.antiRestoreOff() end ENV.USH_STATE.antiRestore=false end,
        desc="Anti-TPBack/restore",
    },
    -- SPEEDS
    WalkSpeed = {
        get = function()
            return (EXPOSED.State and EXPOSED.State.walkSpeed) or ENV.USH_STATE.walkSpeed or 16
        end,
        set = function(v)
            if typeof(EXPOSED.setWalkSpeed)=="function" then EXPOSED.setWalkSpeed(v) end
            ENV.USH_STATE.walkSpeed = v
        end,
        min=8, max=120, step=2,
        desc="Velocidad caminar",
    },
    SprintSpeed = {
        get = function() return (EXPOSED.State and EXPOSED.State.sprintSpeed) or ENV.USH_STATE.sprintSpeed or 24 end,
        set = function(v) if typeof(EXPOSED.setSprintSpeed)=="function" then EXPOSED.setSprintSpeed(v) end ENV.USH_STATE.sprintSpeed=v end,
        min=12, max=160, step=2,
        desc="Velocidad sprint",
    },
    FlySpeed = {
        get = function() return (EXPOSED.State and EXPOSED.State.flySpeed) or ENV.USH_STATE.flySpeed or 2 end,
        set = function(v) if typeof(EXPOSED.setFlySpeed)=="function" then EXPOSED.setFlySpeed(v) end ENV.USH_STATE.flySpeed=v end,
        min=1, max=50, step=1,
        desc="Velocidad vuelo",
    },
    -- TELEPORT
    TP_ModeNext = { call = function() if typeof(EXPOSED.tpModeNext)=="function" then EXPOSED.tpModeNext() end end, desc="Cambiar modo TP" },
    TP_Mouse    = { call = function() if typeof(EXPOSED.tpToMouse)=="function" then EXPOSED.tpToMouse() end end, desc="TP al cursor" },
    TP_Player   = { call = function(name) if typeof(EXPOSED.tpToPlayer)=="function" then EXPOSED.tpToPlayer(name) end end, desc="TP a jugador" },
    WP_Add      = { call = function() if typeof(EXPOSED.addWaypoint)=="function" then EXPOSED.addWaypoint() end end, desc="Guardar waypoint" },
    WP_Goto     = { call = function(idx) if typeof(EXPOSED.gotoWaypoint)=="function" then EXPOSED.gotoWaypoint(idx) end end, desc="Ir a waypoint" },
    WP_Remove   = { call = function(idx) if typeof(EXPOSED.removeWaypoint)=="function" then EXPOSED.removeWaypoint(idx) end end, desc="Borrar waypoint" },
}

local function hasToggle(name)
    local t = API[name]
    if not t then return false end
    return typeof(t.get)=="function" and typeof(t.on)=="function" and typeof(t.off)=="function"
end
local function hasCall(name) return API[name] and typeof(API[name].call)=="function" end
local function hasSet(name)  return API[name] and typeof(API[name].set)=="function" and typeof(API[name].get)=="function" end

-- ============ Servicios Roblox ============
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ============ UI Builder ============
local function new(inst, props, children)
    local o = Instance.new(inst)
    if props then
        for k,v in pairs(props) do o[k]=v end
    end
    if children then
        for _,c in ipairs(children) do c.Parent = o end
    end
    return o
end

local colors = {
    bg = Color3.fromRGB(18,18,22),
    panel = Color3.fromRGB(26,26,32),
    accent = Color3.fromRGB(0,170,120),
    accentOff = Color3.fromRGB(140,50,60),
    accentIdle = Color3.fromRGB(60,60,70),
    text = Color3.fromRGB(235,235,240),
    sub = Color3.fromRGB(180,180,190),
    line = Color3.fromRGB(50,50,60),
    tab = Color3.fromRGB(35,35,42),
}

local function makeDraggable(frame, dragArea)
    dragArea = dragArea or frame
    local dragging=false
    local startPos, startInput
    dragArea.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            dragging=true
            startPos = input.Position
            startInput = input
        end
    end)
    dragArea.InputEnded:Connect(function(input)
        if input==startInput then dragging=false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input==startInput or input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
            local delta = input.Position - startPos
            frame.Position = UDim2.fromScale(math.clamp(frame.Position.X.Scale + delta.X / workspace.CurrentCamera.ViewportSize.X,0,1),
                                             math.clamp(frame.Position.Y.Scale + delta.Y / workspace.CurrentCamera.ViewportSize.Y,0,1))
            startPos = input.Position
            ENV.USH_CFG.guiPos = {frame.Position.X.Scale, frame.Position.Y.Scale}
        end
    end)
end

-- ============ Root GUI ============
local Screen = new("ScreenGui", {
    Name="UltraTouchGUI",
    ResetOnSpawn=false,
    IgnoreGuiInset=true,
    ZIndexBehavior=Enum.ZIndexBehavior.Global,
})
Screen.Parent = PlayerGui

local UIScale = new("UIScale", { Scale = ENV.USH_CFG.uiScale or 1.0 })
UIScale.Parent = Screen

local Root = new("Frame", {
    Name="Root",
    BackgroundColor3 = colors.bg,
    BackgroundTransparency = 1 - (ENV.USH_CFG.opacity or 0.9),
    Position = UDim2.fromScale(ENV.USH_CFG.guiPos[1] or 0.05, ENV.USH_CFG.guiPos[2] or 0.15),
    Size = UDim2.new(0, 420, 0, 480),
})
Root.Parent = Screen

local Corner = new("UICorner", { CornerRadius = UDim.new(0,12) }); Corner.Parent = Root
new("UIStroke", {Thickness=1, Color=colors.line, Transparency=0.4}).Parent = Root

local TopBar = new("Frame", {
    BackgroundColor3 = colors.tab,
    Size = UDim2.new(1,0,0,48),
    BorderSizePixel=0,
})
TopBar.Parent = Root
new("UICorner", {CornerRadius=UDim.new(0,12)}).Parent = TopBar

local Title = new("TextLabel", {
    Text = "Ultra Stealth • Touch",
    Font = Enum.Font.GothamSemibold,
    TextSize = 18,
    TextColor3 = colors.text,
    BackgroundTransparency=1,
    Position = UDim2.new(0,16,0,0),
    Size = UDim2.new(0.6,0,1,0),
    TextXAlignment=Enum.TextXAlignment.Left,
})
Title.Parent = TopBar

local CloseBtn = new("TextButton", {
    Text="✕",
    Font=Enum.Font.GothamBold, TextSize=18,
    TextColor3=colors.text,
    BackgroundTransparency=1,
    Size=UDim2.new(0,48,1,0),
    Position=UDim2.new(1,-48,0,0),
})
CloseBtn.Parent = TopBar

local TabBar = new("Frame", {
    BackgroundColor3 = colors.tab,
    Size = UDim2.new(1,0,0,40),
    Position = UDim2.new(0,0,0,48),
    BorderSizePixel=0,
})
TabBar.Parent = Root

local Content = new("Frame", {
    BackgroundColor3 = colors.panel,
    Position = UDim2.new(0,0,0,88),
    Size = UDim2.new(1,0,1,-88),
    BorderSizePixel=0,
})
Content.Parent = Root
new("UIStroke",{Thickness=1,Color=colors.line,Transparency=0.25}).Parent = Content

local Scroll = new("ScrollingFrame", {
    BackgroundTransparency=1,
    Size = UDim2.new(1,0,1,0),
    CanvasSize = UDim2.new(0,0,0,0),
    ScrollBarThickness = 6,
    BorderSizePixel=0,
})
Scroll.Parent = Content

local Layout = new("UIListLayout", {
    Padding = UDim.new(0,10),
    SortOrder = Enum.SortOrder.LayoutOrder,
})
Layout.Parent = Scroll

local Padding = new("UIPadding", {
    PaddingLeft = UDim.new(0,12),
    PaddingRight = UDim.new(0,12),
    PaddingTop = UDim.new(0,12),
    PaddingBottom = UDim.new(0,12),
})
Padding.Parent = Scroll

local function updateCanvas()
    Scroll.CanvasSize = UDim2.new(0,0,0, Layout.AbsoluteContentSize.Y + 24)
end
Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)

makeDraggable(Root, TopBar)

CloseBtn.MouseButton1Click:Connect(function()
    Screen.Enabled = false
end)

-- ============ Componentes ============
local function pill(color)
    local p = new("Frame", {BackgroundColor3=color, Size=UDim2.new(1,0,0,46), BorderSizePixel=0})
    new("UICorner",{CornerRadius=UDim.new(0,10)}).Parent = p
    new("UIStroke",{Thickness=1,Color=colors.line,Transparency=0.3}).Parent = p
    return p
end

local function label(parent, text, sub)
    local l = new("TextLabel", {
        BackgroundTransparency=1,
        Text=text,
        Font=Enum.Font.GothamSemibold,
        TextSize=16,
        TextXAlignment=Enum.TextXAlignment.Left,
        TextColor3=colors.text,
        Position=UDim2.new(0,14,0,6),
        Size=UDim2.new(1,-160,0,20),
    })
    l.Parent = parent
    if sub then
        local s = new("TextLabel", {
            BackgroundTransparency=1,
            Text=sub,
            Font=Enum.Font.Gotham,
            TextSize=12,
            TextXAlignment=Enum.TextXAlignment.Left,
            TextColor3=colors.sub,
            Position=UDim2.new(0,14,0,24),
            Size=UDim2.new(1,-160,0,18),
        })
        s.Parent = parent
    end
    return l
end

local function makeToggle(name, desc, getFn, onFn, offFn)
    local enabled = typeof(getFn)=="function" and (getFn() and true or false) or false
    local available = typeof(getFn)=="function" and typeof(onFn)=="function" and typeof(offFn)=="function"
    local p = pill(colors.panel)
    p.Parent = Scroll

    label(p, name, desc .. (available and "" or " (API no encontrada)"))

    local btn = new("TextButton", {
        Text = enabled and "ON" or "OFF",
        Font = Enum.Font.GothamBold,
        TextSize=16,
        TextColor3=Color3.fromRGB(255,255,255),
        BackgroundColor3 = available and (enabled and colors.accent or colors.accentOff) or colors.accentIdle,
        Size=UDim2.new(0,100,0,34),
        Position=UDim2.new(1,-114,0,6),
    })
    btn.Parent = p
    new("UICorner",{CornerRadius=UDim.new(0,8)}).Parent = btn

    if not available then
        btn.AutoButtonColor=false
        btn.Text="N/A"
        btn.TextColor3=Color3.fromRGB(220,220,220)
    else
        btn.MouseButton1Click:Connect(function()
            local now = getFn()
            if now then offFn() else onFn() end
            local st = getFn()
            btn.Text = st and "ON" or "OFF"
            btn.BackgroundColor3 = st and colors.accent or colors.accentOff
        end)
    end

    return p
end

local function makeStepper(name, desc, getFn, setFn, min, max, step)
    local available = typeof(getFn)=="function" and typeof(setFn)=="function"
    local p = pill(colors.panel); p.Size = UDim2.new(1,0,0,56); p.Parent = Scroll
    label(p, name, desc .. (available and "" or " (API no encontrada)"))

    local minus = new("TextButton", {
        Text = "−", Font=Enum.Font.GothamBold, TextSize=20,
        TextColor3=colors.text,
        BackgroundColor3 = available and colors.tab or colors.accentIdle,
        Size=UDim2.new(0,40,0,34), Position=UDim2.new(1,-220,0,10),
    })
    local valBox = new("TextBox", {
        Text = available and tostring(getFn()) or "--",
        PlaceholderText = "--",
        Font=Enum.Font.GothamSemibold, TextSize=16,
        TextColor3=colors.text,
        BackgroundColor3 = colors.tab,
        Size=UDim2.new(0,100,0,34), Position=UDim2.new(1,-170,0,10),
        ClearTextOnFocus=false,
    })
    local plus = new("TextButton", {
        Text = "+", Font=Enum.Font.GothamBold, TextSize=20,
        TextColor3=colors.text,
        BackgroundColor3 = available and colors.tab or colors.accentIdle,
        Size=UDim2.new(0,40,0,34), Position=UDim2.new(1,-60,0,10),
    })
    minus.Parent=p; valBox.Parent=p; plus.Parent=p
    for _,b in ipairs({minus,plus,valBox}) do new("UICorner",{CornerRadius=UDim.new(0,8)}).Parent=b end

    local function clamp(v)
        v = math.clamp(v, min, max)
        local s = step or 1
        v = math.floor((v + (s/2)) / s) * s
        return v
    end

    if available then
        local function setFrom(delta)
            local cur = tonumber(getFn()) or min
            local nv = clamp(cur + delta)
            setFn(nv)
            valBox.Text = tostring(nv)
        end
        minus.MouseButton1Click:Connect(function() setFrom(-(step or 1)) end)
        plus.MouseButton1Click:Connect(function() setFrom( (step or 1)) end)
        valBox.FocusLost:Connect(function(enter)
            local v = tonumber(valBox.Text)
            if v then
                v = clamp(v)
                setFn(v)
                valBox.Text = tostring(v)
            else
                valBox.Text = tostring(getFn())
            end
        end)
    else
        minus.AutoButtonColor=false
        plus.AutoButtonColor=false
        valBox.TextEditable=false
    end

    return p
end

local function makeTabButton(text, order)
    local b = new("TextButton", {
        Text=text, Font=Enum.Font.GothamSemibold, TextSize=14,
        TextColor3=colors.text,
        BackgroundColor3=colors.tab,
        Size=UDim2.new(0,100,1,0),
        Position=UDim2.new(0,(order-1)*104,0,0),
        AutoButtonColor=true,
    })
    b.Parent = TabBar
    new("UIStroke",{Color=colors.line,Transparency=0.6,Thickness=1}).Parent = b
    return b
end

-- ============ Tabs ============
local tabs = {
    {name="Movimiento", build=function()
        makeToggle("Noclip", API.Noclip.desc, API.Noclip.get, API.Noclip.on, API.Noclip.off)
        makeToggle("Fly", API.Fly.desc, API.Fly.get, API.Fly.on, API.Fly.off)
        makeToggle("Sprint", API.Sprint.desc, API.Sprint.get, API.Sprint.on, API.Sprint.off)

        makeStepper("WalkSpeed", API.WalkSpeed.desc, API.WalkSpeed.get, API.WalkSpeed.set, API.WalkSpeed.min, API.WalkSpeed.max, API.WalkSpeed.step)
        makeStepper("SprintSpeed", API.SprintSpeed.desc, API.SprintSpeed.get, API.SprintSpeed.set, API.SprintSpeed.min, API.SprintSpeed.max, API.SprintSpeed.step)
        makeStepper("FlySpeed", API.FlySpeed.desc, API.FlySpeed.get, API.FlySpeed.set, API.FlySpeed.min, API.FlySpeed.max, API.FlySpeed.step)
    end},
    {name="Stealth", build=function()
        makeToggle("Invis", API.Invis.desc, API.Invis.get, API.Invis.on, API.Invis.off)
        makeToggle("Ghost", API.Ghost.desc, API.Ghost.get, API.Ghost.on, API.Ghost.off)
    end},
    {name="Defensa", build=function()
        makeToggle("NoHit", API.NoHit.desc, API.NoHit.get, API.NoHit.on, API.NoHit.off)
        makeToggle("AntiRestore", API.AntiRestore.desc, API.AntiRestore.get, API.AntiRestore.on, API.AntiRestore.off)
    end},
    {name="Teleport", build=function()
        -- Modo TP
        local p1 = pill(colors.panel); p1.Parent = Scroll
        label(p1, "Modo TP", "Cambia entre modos configurados")
        local bMode = new("TextButton", {
            Text = "Cambiar",
            Font = Enum.Font.GothamBold, TextSize=16, TextColor3=colors.text,
            BackgroundColor3 = hasCall("TP_ModeNext") and colors.tab or colors.accentIdle,
            Size=UDim2.new(0,100,0,34), Position=UDim2.new(1,-114,0,6),
        })
        new("UICorner",{CornerRadius=UDim.new(0,8)}).Parent=bMode; bMode.Parent=p1
        if hasCall("TP_ModeNext") then
            bMode.MouseButton1Click:Connect(function() API.TP_ModeNext.call() end)
        else bMode.AutoButtonColor=false; bMode.Text="N/A" end

        -- TP al cursor
        local p2 = pill(colors.panel); p2.Parent = Scroll
        label(p2, "TP al cursor", "Teleporta hacia la posición del cursor")
        local bMouse = new("TextButton", {
            Text = "TP",
            Font = Enum.Font.GothamBold, TextSize=16, TextColor3=colors.text,
            BackgroundColor3 = hasCall("TP_Mouse") and colors.tab or colors.accentIdle,
            Size=UDim2.new(0,100,0,34), Position=UDim2.new(1,-114,0,6),
        })
        new("UICorner",{CornerRadius=UDim.new(0,8)}).Parent=bMouse; bMouse.Parent=p2
        if hasCall("TP_Mouse") then
            bMouse.MouseButton1Click:Connect(function() API.TP_Mouse.call() end)
        else bMouse.AutoButtonColor=false; bMouse.Text="N/A" end

        -- TP a jugador
        local p3 = pill(colors.panel); p3.Size=UDim2.new(1,0,0,70); p3.Parent = Scroll
        label(p3, "TP a jugador", "Escribe el nombre exacto o parcial")
        local nameBox = new("TextBox", {
            PlaceholderText="Nombre del jugador",
            Font=Enum.Font.Gotham, TextSize=14, TextColor3=colors.text,
            BackgroundColor3=colors.tab, ClearTextOnFocus=false,
            Size=UDim2.new(1,-130,0,34), Position=UDim2.new(0,14,0,28),
        })
        new("UICorner",{CornerRadius=UDim.new(0,8)}).Parent=nameBox; nameBox.Parent=p3
        local bTP = new("TextButton", {
            Text="TP", Font=Enum.Font.GothamBold, TextSize=16, TextColor3=colors.text,
            BackgroundColor3 = hasCall("TP_Player") and colors.tab or colors.accentIdle,
            Size=UDim2.new(0,80,0,34), Position=UDim2.new(1,-94,0,28),
        })
        new("UICorner",{CornerRadius=UDim.new(0,8)}).Parent=bTP; bTP.Parent=p3
        if hasCall("TP_Player") then
            bTP.MouseButton1Click:Connect(function()
                local q = nameBox.Text
                if q and #q>0 then API.TP_Player.call(q) end
            end)
        else bTP.AutoButtonColor=false; bTP.Text="N/A" end

        -- Waypoints
        local p4 = pill(colors.panel); p4.Parent = Scroll
        label(p4, "Waypoints", "Guardar / ir / borrar (usa índice)")
        local idxBox = new("TextBox", {
            PlaceholderText="Índice",
            Font=Enum.Font.Gotham, TextSize=14, TextColor3=colors.text,
            BackgroundColor3=colors.tab, ClearTextOnFocus=false,
            Size=UDim2.new(0,70,0,34), Position=UDim2.new(0,14,0,6),
        }); new("UICorner",{CornerRadius=UDim.new(0,8)}).Parent=idxBox; idxBox.Parent=p4

        local bAdd = new("TextButton", {Text="Guardar", Font=Enum.Font.GothamSemibold, TextSize=14, TextColor3=colors.text,
            BackgroundColor3 = hasCall("WP_Add") and colors.tab or colors.accentIdle,
            Size=UDim2.new(0,90,0,34), Position=UDim2.new(0,94,0,6),
        }); new("UICorner",{CornerRadius=UDim.new(0,8)}).Parent=bAdd; bAdd.Parent=p4
        local bGo = new("TextButton", {Text="Ir", Font=Enum.Font.GothamSemibold, TextSize=14, TextColor3=colors.text,
            BackgroundColor3 = hasCall("WP_Goto") and colors.tab or colors.accentIdle,
            Size=UDim2.new(0,60,0,34), Position=UDim2.new(0,194,0,6),
        }); new("UICorner",{CornerRadius=UDim.new(0,8)}).Parent=bGo; bGo.Parent=p4
        local bDel = new("TextButton", {Text="Borrar", Font=Enum.Font.GothamSemibold, TextSize=14, TextColor3=colors.text,
            BackgroundColor3 = hasCall("WP_Remove") and colors.tab or colors.accentIdle,
            Size=UDim2.new(0,90,0,34), Position=UDim2.new(0,264,0,6),
        }); new("UICorner",{CornerRadius=UDim.new(0,8)}).Parent=bDel; bDel.Parent=p4

        if hasCall("WP_Add") then
            bAdd.MouseButton1Click:Connect(function() API.WP_Add.call() end)
        else bAdd.AutoButtonColor=false; bAdd.Text="N/A" end

        if hasCall("WP_Goto") then
            bGo.MouseButton1Click:Connect(function()
                local idx = tonumber(idxBox.Text)
                if idx then API.WP_Goto.call(idx) end
            end)
        else bGo.AutoButtonColor=false; bGo.Text="N/A" end

        if hasCall("WP_Remove") then
            bDel.MouseButton1Click:Connect(function()
                local idx = tonumber(idxBox.Text)
                if idx then API.WP_Remove.call(idx) end
            end)
        else bDel.AutoButtonColor=false; bDel.Text="N/A" end
    end},
    {name="Ajustes", build=function()
        -- Opacidad
        makeStepper("Opacidad UI", "Transparencia del panel (0.4 - 1.0)", function()
            return math.floor((ENV.USH_CFG.opacity or 0.9)*100+0.5)
        end, function(v)
            ENV.USH_CFG.opacity = math.clamp(v/100, 0.4, 1.0)
            Root.BackgroundTransparency = 1 - ENV.USH_CFG.opacity
        end, 40, 100, 5)

        -- Escala
        makeStepper("Escala UI", "Tamaño global de la interfaz (50 - 150%)", function()
            return math.floor((ENV.USH_CFG.uiScale or 1.0)*100 + 0.5)
        end, function(v)
            ENV.USH_CFG.uiScale = math.clamp(v/100, 0.5, 1.5)
            UIScale.Scale = ENV.USH_CFG.uiScale
        end, 50, 150, 5)

        -- Recentrar UI
        local p = pill(colors.panel); p.Parent=Scroll
        label(p, "Posición", "Recentrar/mostrar GUI")
        local b = new("TextButton",{
            Text="Recentrar",
            Font=Enum.Font.GothamBold, TextSize=16, TextColor3=colors.text,
            BackgroundColor3=colors.tab, Size=UDim2.new(0,110,0,34), Position=UDim2.new(1,-124,0,6),
        }); new("UICorner",{CornerRadius=UDim.new(0,8)}).Parent=b; b.Parent=p
        b.MouseButton1Click:Connect(function()
            Root.Position = UDim2.fromScale(0.05, 0.15)
            ENV.USH_CFG.guiPos = {0.05, 0.15}
            Screen.Enabled = true
        end)
    end},
}

-- Tab buttons
local tabButtons = {}
local currentTab = 1

local function clearContent()
    for _,c in ipairs(Scroll:GetChildren()) do
        if c:IsA("GuiObject") then c:Destroy() end
    end
end
local function buildTab(index)
    currentTab = index
    clearContent()
    tabs[index].build()
    updateCanvas()
end

for i,t in ipairs(tabs) do
    local b = makeTabButton(t.name, i)
    tabButtons[i]=b
    b.MouseButton1Click:Connect(function()
        buildTab(i)
        for j,bb in ipairs(tabButtons) do
            bb.BackgroundColor3 = (j==i) and colors.panel or colors.tab
        end
    end)
end

-- Inicia en Movimiento
buildTab(1)
for j,bb in ipairs(tabButtons) do
    bb.BackgroundColor3 = (j==1) and colors.panel or colors.tab
end

-- ============ Mejores interacciones táctiles ============
-- Aumenta el padding si está en touch
if UserInputService.TouchEnabled then
    Root.Size = UDim2.new(0, 460, 0, 520)
end

-- ============ Persistencia básica en sesión ============
-- (ENV.USH_CFG ya persistirá mientras el ejecutor mantenga el estado)

-- ============ Fin ============
