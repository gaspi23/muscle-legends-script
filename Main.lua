-- Ultra Touch GUI (Tablet) + GUI Autorestore + Scroll + Noclip/Speed + Hit Aura real (sin guante gigante)
-- Luis x Copilot

-- Servicios
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

-- Utils
local function notify(t, d) pcall(function() StarterGui:SetCore("SendNotification",{Title="Ultra Touch",Text=t,Duration=d or 1.8}) end) end
local function clamp(v, lo, hi) if v<lo then return lo elseif v>hi then return hi else return v end end

-- Si la GUI ya existe, muéstrala y sal sin duplicar
do
    local pg = player:WaitForChild("PlayerGui")
    local existing = pg:FindFirstChild("UltraTouchGUI")
    if existing then
        existing.Enabled = true
        existing.DisplayOrder = 999999
        local root = existing:FindFirstChild("Root")
        local reopen = existing:FindFirstChild("ReopenButton")
        if root then root.Visible = true end
        if reopen then reopen.Visible = false end
        _G.USH_ShowUI = function(v)
            existing.Enabled = true
            if root then root.Visible = (v ~= false) end
            if reopen then reopen.Visible = (v == false) end
        end
        return
    end
end

-- Entorno compartido / estado
local ENV = (getgenv and getgenv()) or _G
if ENV.USH_GUI_LOADED then return end
ENV.USH_GUI_LOADED = true

ENV.USH_CFG = ENV.USH_CFG or { guiPos = {0.06, 0.16}, uiScale = 1.0, opacity = 0.92 }
ENV.USH_STATE = ENV.USH_STATE or {}
local S = ENV.USH_STATE

-- Estado base
S.walkSpeed   = S.walkSpeed   or 16
S.sprintSpeed = S.sprintSpeed or 80
S.flySpeed    = S.flySpeed    or 60
S.sprint      = S.sprint      or false
S.noclip      = S.noclip      or false

-- Hit Aura extendido (sin guante gigante)
S.aura            = S.aura            or false
S.auraRange       = clamp(S.auraRange or 300, 4, 1000)  -- alcance aura continuo
S.auraWidth       = S.auraWidth       or 12             -- radio lateral cápsula
S.auraDelay       = S.auraDelay       or 0.08           -- intervalo aura
S.auraFOV         = S.auraFOV         or 140            -- FOV de cono
S.auraFrontOnly   = (S.auraFrontOnly ~= false)          -- true=cono/cápsula; false=esfera
S.auraLOS         = (S.auraLOS ~= false)                -- línea de visión
S.auraClickBoost  = (S.auraClickBoost ~= false)         -- burst de click/tap
S.auraClickRange  = clamp(S.auraClickRange or 900, 4, 1000) -- alcance burst click
S.auraPerTargetCD = S.auraPerTargetCD or 0.06           -- CD por objetivo
S.auraUseProxy    = (S.auraUseProxy ~= false)           -- usar proxy invisible
S.auraProxySize   = clamp(S.auraProxySize or 2, 1, 6)   -- tamaño proxy invisible
S.auraHotkey      = S.auraHotkey or Enum.KeyCode.K

-- Conexiones y refs
local Conns = { char={}, noclip={}, speed={}, aura={}, click={} }
local function disconnectAll(t) for _,c in ipairs(t) do pcall(function() c:Disconnect() end) end; table.clear(t) end

local char, hum, hrp
local function getChar()
    local c = player.Character or player.CharacterAdded:Wait()
    return c, c:WaitForChild("Humanoid"), c:WaitForChild("HumanoidRootPart")
end
local function isAlive(h) return h and h.Health and h.Health > 0 end

-- Velocidad persistente
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
            if target and math.abs((hum.WalkSpeed or 0) - target) > 0.5 then hum.WalkSpeed = target end
        end))
    end
    table.insert(Conns.speed, RunService.Heartbeat:Connect(function()
        if hum and S._desiredSpeed and math.abs(hum.WalkSpeed - S._desiredSpeed) > 0.5 then hum.WalkSpeed = S._desiredSpeed end
    end))
end
_G.setWalkSpeed_fallback   = function(v) v=clamp(v,8,300);  S.walkSpeed=v;   applyWalkSpeed() end
_G.setSprintSpeed_fallback = function(v) v=clamp(v,16,800); S.sprintSpeed=v; applyWalkSpeed() end
_G.setFlySpeed_fallback    = function(v) v=clamp(v,10,1200); S.flySpeed=v end
_G.sprintOn_fallback       = function() S.sprint=true;  applyWalkSpeed(); notify("Sprint ON",1.2) end
_G.sprintOff_fallback      = function() S.sprint=false; applyWalkSpeed(); notify("Sprint OFF",1.2) end

-- Noclip real
local function setNoCollide(model,on)
    for _,v in ipairs(model:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide = not on end end
end
_G.noclipOn_fallback = function(silent)
    if S.noclip then return end
    S.noclip = true
    if char and char.Parent then setNoCollide(char,true) end
    disconnectAll(Conns.noclip)
    table.insert(Conns.noclip, RunService.Stepped:Connect(function()
        if S.noclip and char and char.Parent then setNoCollide(char,true) end
    end))
    if not silent then notify("Noclip ON") end
end
_G.noclipOff_fallback = function(silent)
    if not S.noclip then return end
    S.noclip = false
    disconnectAll(Conns.noclip)
    if char and char.Parent then setNoCollide(char,false) end
    if not silent then notify("Noclip OFF") end
end

-- Hit Aura real (sin guante gigante)
local function dot(a,b) return a.X*b.X + a.Y*b.Y + a.Z*b.Z end
local function angleBetween(a,b) local m=(a.Magnitude*b.Magnitude); if m==0 then return 180 end; return math.deg(math.acos(math.clamp(dot(a,b)/m,-1,1))) end

local proxy
local function ensureProxy()
    if proxy and proxy.Parent and proxy:IsA("BasePart") then return proxy end
    proxy = Instance.new("Part")
    proxy.Name = "UltraProxy"
    proxy.Size = Vector3.new(S.auraProxySize, S.auraProxySize, S.auraProxySize)
    proxy.Transparency = 1
    proxy.CanCollide = false
    proxy.CanQuery = false
    proxy.CanTouch = true
    proxy.Massless = true
    proxy.Anchored = false
    proxy.Parent = char
    return proxy
end

local function toolEquipped()
    for _,t in ipairs(char:GetChildren()) do if t:IsA("Tool") and t:FindFirstChild("Handle") then return t end end
end
local function equipAnyTool()
    if toolEquipped() then return true end
    local bp = player:FindFirstChildOfClass("Backpack")
    if not bp then return false end
    for _,t in ipairs(bp:GetChildren()) do
        if t:IsA("Tool") and t:FindFirstChild("Handle") then t.Parent = char; return true end
    end
    return false
end
local function activateAnyTool()
    for _,t in ipairs(char:GetChildren()) do
        if t:IsA("Tool") and t:FindFirstChild("Handle") then t:Activate() end
    end
end

local function fireTouchBetween(a, b)
    if typeof(firetouchinterest) == "function" then
        pcall(firetouchinterest, a, b, 0)
        task.wait()
        pcall(firetouchinterest, a, b, 1)
    end
end

local function doRemoteHit(targetChar)
    local h = targetChar:FindFirstChild("HumanoidRootPart") or targetChar:FindFirstChild("UpperTorso") or targetChar:FindFirstChild("Torso")
    if not h then return end
    if S.auraUseProxy then
        local p = ensureProxy()
        p.Size = Vector3.new(S.auraProxySize, S.auraProxySize, S.auraProxySize)
        p.CFrame = h.CFrame
        fireTouchBetween(p, h)
    else
        local t = toolEquipped() or (equipAnyTool() and toolEquipped())
        if t then t:Activate() end
    end
end

local function shouldHit(myHRP, look, otherPlr, range)
    local och = otherPlr.Character
    if not och then return false end
    local ohum = och:FindFirstChildOfClass("Humanoid")
    local ohrp = och:FindFirstChild("HumanoidRootPart")
    if not ohum or not ohrp or not isAlive(ohum) then return false end
    local delta = ohrp.Position - myHRP.Position
    range = range or S.auraRange
    if S.auraFrontOnly then
        if angleBetween(delta, look) > (S.auraFOV/2) then return false end
        local forward = dot(delta, look.Unit)
        if forward <= 0 or forward > range then return false end
        local perp = delta - look.Unit * forward
        if perp.Magnitude > S.auraWidth then return false end
    else
        if delta.Magnitude > range then return false end
    end
    if S.auraLOS then
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Blacklist
        params.FilterDescendantsInstances = {char, och}
        local res = Workspace:Raycast(myHRP.Position, ohrp.Position - myHRP.Position, params)
        if res and not res.Instance:IsDescendantOf(och) then return false end
    end
    return true
end

local lastHitPerTarget = {}
local function startAuraLoop()
    disconnectAll(Conns.aura)
    if not S.aura then return end
    local acc = 0
    table.insert(Conns.aura, RunService.Heartbeat:Connect(function(dt)
        acc += dt
        if acc < S.auraDelay then return end
        acc = 0
        char, hum, hrp = getChar()
        if not isAlive(hum) then return end
        local cam = Workspace.CurrentCamera
        local look = (cam and cam.CFrame.LookVector) or hrp.CFrame.LookVector
        local now = os.clock()
        for _,other in ipairs(Players:GetPlayers()) do
            if other ~= player and other.Character then
                if shouldHit(hrp, look, other, S.auraRange) then
                    local last = lastHitPerTarget[other] or 0
                    if now - last >= S.auraPerTargetCD then
                        equipAnyTool()
                        doRemoteHit(other.Character)
                        lastHitPerTarget[other] = now
                    end
                end
            end
        end
    end))
end

local function auraOn()
    if S.aura then return end
    S.aura = true
    startAuraLoop()
    notify("AURA HIT ON", 1.2)
end
local function auraOff()
    if not S.aura then return end
    S.aura = false
    disconnectAll(Conns.aura)
    notify("AURA HIT OFF", 1.2)
end

-- Click/tap burst de largo alcance
local lastClickBurst = 0
local function clickBurst()
    local now = os.clock()
    if now - lastClickBurst < (S.auraDelay * 0.5) then return end
    lastClickBurst = now
    char, hum, hrp = getChar()
    if not isAlive(hum) then return end
    local cam = Workspace.CurrentCamera
    local look = (cam and cam.CFrame.LookVector) or hrp.CFrame.LookVector
    equipAnyTool()
    for _,other in ipairs(Players:GetPlayers()) do
        if other ~= player and other.Character then
            if shouldHit(hrp, look, other, S.auraClickRange) then
                doRemoteHit(other.Character)
            end
        end
    end
end

-- Input: hotkey y click/tap
disconnectAll(Conns.click)
table.insert(Conns.click, UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == S.auraHotkey then
        if S.aura then auraOff() else auraOn() end
    end
    if S.auraClickBoost and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
        clickBurst()
    end
end))

-- Rebind / persistencia
local function rebindCharacter()
    disconnectAll(Conns.char)
    char, hum, hrp = getChar()
    applyWalkSpeed()
    if S.noclip then _G.noclipOn_fallback(true) end
    if S.aura then startAuraLoop() end
end
table.insert(Conns.char, player.CharacterAdded:Connect(function() task.wait(0.15) rebindCharacter() end))
rebindCharacter()
applyWalkSpeed()
startSpeedGuard()

-- API expuesta (para GUI)
local EXPOSED = ENV.USH or ENV.USE or ENV.STEALTH or ENV.HUB or ENV
local API = {
    Noclip = { get=function() return (EXPOSED.State and EXPOSED.State.noclip) or S.noclip end,
               on=function() if typeof(EXPOSED.noclipOn)=="function" then EXPOSED.noclipOn() else _G.noclipOn_fallback() end end,
               off=function() if typeof(EXPOSED.noclipOff)=="function" then EXPOSED.noclipOff() else _G.noclipOff_fallback() end end,
               desc="Atravesar objetos" },
    Sprint = { get=function() return (EXPOSED.State and EXPOSED.State.sprint) or S.sprint end,
               on=function() if typeof(EXPOSED.sprintOn)=="function" then EXPOSED.sprintOn() else _G.sprintOn_fallback() end end,
               off=function() if typeof(EXPOSED.sprintOff)=="function" then EXPOSED.sprintOff() else _G.sprintOff_fallback() end end,
               desc="Correr más rápido" },
    Fly    = { get=function() return (EXPOSED.State and EXPOSED.State.fly) or (S.fly or false) end,
               on=function() if typeof(EXPOSED.flyOn)=="function" then EXPOSED.flyOn() else notify("Conecta tu Fly del hub") end end,
               off=function() if typeof(EXPOSED.flyOff)=="function" then EXPOSED.flyOff() else notify("Conecta tu Fly del hub") end end,
               desc="Vuelo libre" },
    Invis  = { get=function() return (EXPOSED.State and EXPOSED.State.invisRep) or (S.invisRep or false) end,
               on=function() if typeof(EXPOSED.invisRepOn)=="function" then EXPOSED.invisRepOn() else notify("Conecta InvisRep del hub") end end,
               off=function() if typeof(EXPOSED.invisRepOff)=="function" then EXPOSED.invisRepOff() else notify("Conecta InvisRep del hub") end end,
               desc="Invisibilidad replicada" },
    Ghost  = { get=function() return (EXPOSED.State and EXPOSED.State.ghost) or (S.ghost or false) end,
               on=function() if typeof(EXPOSED.ghostOn)=="function" then EXPOSED.ghostOn() else notify("Conecta Ghost del hub") end end,
               off=function() if typeof(EXPOSED.ghostOff)=="function" then EXPOSED.ghostOff() else notify("Conecta Ghost del hub") end end,
               desc="Colisión fantasma" },
    WalkSpeed   = { get=function() return (EXPOSED.State and (EXPOSED.State.walkSpeed or EXPOSED.State.speedWalk)) or S.walkSpeed end,
                    set=function(v) if typeof(EXPOSED.setWalkSpeed)=="function" then EXPOSED.setWalkSpeed(v) else _G.setWalkSpeed_fallback(v) end end,
                    min=8,max=300,step=2,desc="Velocidad caminar" },
    SprintSpeed = { get=function() return (EXPOSED.State and (EXPOSED.State.sprintSpeed or EXPOSED.State.speedSprint)) or S.sprintSpeed end,
                    set=function(v) if typeof(EXPOSED.setSprintSpeed)=="function" then EXPOSED.setSprintSpeed(v) else _G.setSprintSpeed_fallback(v) end end,
                    min=16,max=800,step=5,desc="Velocidad sprint" },
    FlySpeed    = { get=function() return (EXPOSED.State and (EXPOSED.State.flySpeed or EXPOSED.State.speedFly)) or S.flySpeed end,
                    set=function(v) if typeof(EXPOSED.setFlySpeed)=="function" then EXPOSED.setFlySpeed(v) else _G.setFlySpeed_fallback(v) end end,
                    min=10,max=1200,step=10,desc="Velocidad vuelo" },
    -- Hit Aura real
    Aura           = { get=function() return (EXPOSED.State and EXPOSED.State.aura) or S.aura end,
                       on=function() if typeof(EXPOSED.auraOn)=="function" then EXPOSED.auraOn() else auraOn() end end,
                       off=function() if typeof(EXPOSED.auraOff)=="function" then EXPOSED.auraOff() else auraOff() end end,
                       desc="Golpe de alcance extendido" },
    AuraRange      = { get=function() return S.auraRange end, set=function(v) S.auraRange = clamp(v,4,1000) end, min=4,max=1000,step=5,desc="Distancia aura" },
    AuraWidth      = { get=function() return S.auraWidth end, set=function(v) S.auraWidth = clamp(v,1,50) end,   min=1,max=50,step=1,desc="Ancho cápsula" },
    AuraDelay      = { get=function() return S.auraDelay end, set=function(v) S.auraDelay = clamp(v,0.02,0.5) end, min=0.02,max=0.5,step=0.01,desc="Intervalo aura" },
    AuraFOV        = { get=function() return S.auraFOV end,   set=function(v) S.auraFOV = clamp(v,30,180) end,   min=30,max=180,step=5,desc="Ángulo visión" },
    AuraMode       = { get=function() return S.auraFrontOnly end, toggle=function() S.auraFrontOnly = not S.auraFrontOnly end, desc="Modo: Cono/Esfera" },
    AuraLOS        = { get=function() return S.auraLOS end, toggle=function() S.auraLOS = not S.auraLOS end, desc="Línea de visión" },
    AuraClick      = { get=function() return S.auraClickBoost end, toggle=function() S.auraClickBoost = not S.auraClickBoost end, desc="Burst por click" },
    AuraClickRange = { get=function() return S.auraClickRange end, set=function(v) S.auraClickRange = clamp(v,4,1000) end, min=4,max=1000,step=10,desc="Distancia click" },
    AuraProxySize  = { get=function() return S.auraProxySize end, set=function(v) S.auraProxySize = clamp(v,1,6) end, min=1,max=6,step=1,desc="Tamaño proxy" },
}

-- UI builder (tablet-first + scroll + autoreopen)
local function New(c,p,children) local o=Instance.new(c) for k,v in pairs(p or {}) do o[k]=v end if children then for _,ch in ipairs(children) do ch.Parent=o end end return o end

local Screen = New("ScreenGui",{Name="UltraTouchGUI",ResetOnSpawn=false,IgnoreGuiInset=true,ZIndexBehavior=Enum.ZIndexBehavior.Global,DisplayOrder=999999})
Screen.Parent = player:WaitForChild("PlayerGui")

local UIScale = New("UIScale",{Scale=ENV.USH_CFG.uiScale or 1.0}); UIScale.Parent=Screen

local Root = New("Frame",{Name="Root",BackgroundColor3=Color3.fromRGB(20,20,24),BackgroundTransparency=1-(ENV.USH_CFG.opacity or 0.92),Size=UDim2.new(0,480,0,600),Position=UDim2.fromScale(ENV.USH_CFG.guiPos[1] or 0.06, ENV.USH_CFG.guiPos[2] or 0.16)})
Root.Parent=Screen
New("UICorner",{CornerRadius=UDim.new(0,12)}).Parent=Root
New("UIStroke",{Thickness=1,Transparency=0.5,Color=Color3.fromRGB(60,60,70)}).Parent=Root

local Top = New("Frame",{BackgroundColor3=Color3.fromRGB(34,34,42),Size=UDim2.new(1,0,0,50)}); Top.Parent=Root
local Title = New("TextLabel",{BackgroundTransparency=1,Text="Ultra Stealth • Touch",Font=Enum.Font.GothamSemibold,TextSize=18,TextColor3=Color3.fromRGB(240,240,245),TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2.new(0,14,0,0),Size=UDim2.new(0.7,0,1,0)}); Title.Parent=Top

local Close = New("TextButton",{Text="✕",Font=Enum.Font.GothamBold,TextSize=18,BackgroundTransparency=1,TextColor3=Color3.fromRGB(240,240,245),Size=UDim2.new(0,48,1,0),Position=UDim2.new(1,-48,0,0)}); Close.Parent=Top

-- Reopen flotante
local Reopen = New("TextButton",{Name="ReopenButton",Text="≡",Font=Enum.Font.GothamBold,TextSize=18,BackgroundColor3=Color3.fromRGB(60,60,72),TextColor3=Color3.fromRGB(240,240,245),Size=UDim2.new(0,44,0,44),Position=UDim2.new(0,12,1,-56),Visible=false}); Reopen.Parent=Screen
New("UICorner",{CornerRadius=UDim.new(0,10)}).Parent=Reopen
Reopen.MouseButton1Click:Connect(function() Root.Visible=true; Reopen.Visible=false; Screen.Enabled=true end)
Close.MouseButton1Click:Connect(function() Root.Visible=false; Reopen.Visible=true; Screen.Enabled=true end)

-- Drag panel
do
    local dragging,startPos,startInput=false,nil,nil
    Top.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true; startPos=i.Position; startInput=i end end)
    Top.InputEnded:Connect(function(i) if i==startInput then dragging=false end end)
    UIS.InputChanged:Connect(function(i)
        if dragging and (i==startInput or i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseMovement) then
            local delta=i.Position-startPos
            local vp=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920,1080)
            local nx=math.clamp(Root.Position.X.Scale+delta.X/vp.X,0,1)
            local ny=math.clamp(Root.Position.Y.Scale+delta.Y/vp.Y,0,1)
            Root.Position=UDim2.fromScale(nx,ny)
            ENV.USH_CFG.guiPos={nx,ny}
            startPos=i.Position
        end
    end)
end

-- Tabs y cuerpo con scroll
local Tabs = New("Frame",{BackgroundColor3=Color3.fromRGB(34,34,42),Size=UDim2.new(1,0,0,40),Position=UDim2.new(0,0,0,50)}); Tabs.Parent=Root

local Body = New("ScrollingFrame",{BackgroundTransparency=1,Size=UDim2.new(1,0,1,-100),Position=UDim2.new(0,0,0,90),ScrollBarThickness=10,ScrollingDirection=Enum.ScrollingDirection.Y,VerticalScrollBarInset=Enum.ScrollBarInset.ScrollBar,Active=true,ClipsDescendants=true,AutomaticCanvasSize=Enum.AutomaticSize.None})
Body.Parent=Root
local Layout = New("UIListLayout",{Padding=UDim.new(0,10),SortOrder=Enum.SortOrder.LayoutOrder}); Layout.Parent=Body
local Pad = New("UIPadding",{PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12),PaddingTop=UDim.new(0,12),PaddingBottom=UDim.new(0,12)}); Pad.Parent=Body
local function updateCanvas() Body.CanvasSize = UDim2.new(0,0,0, Layout.AbsoluteContentSize.Y + 24) end
Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)

local function pill(h) local f=New("Frame",{BackgroundColor3=Color3.fromRGB(28,28,34),Size=UDim2.new(1,0,0,h or 52)}); f.Parent=Body; New("UICorner",{CornerRadius=UDim.new(0,10)}).Parent=f; New("UIStroke",{Thickness=1,Transparency=0.4,Color=Color3.fromRGB(55,55,65)}).Parent=f; return f end
local function text(parent,t,sub)
    local l=New("TextLabel",{BackgroundTransparency=1,Text=t,Font=Enum.Font.GothamSemibold,TextSize=16,TextColor3=Color3.fromRGB(235,235,240),TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2.new(0,12,0,6),Size=UDim2.new(1,-140,0,20)})
    l.Parent=parent
    if sub then local s=New("TextLabel",{BackgroundTransparency=1,Text=sub,Font=Enum.Font.Gotham,TextSize=12,TextColor3=Color3.fromRGB(170,170,180),TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2.new(0,12,0,26),Size=UDim2.new(1,-140,0,18)}); s.Parent=parent end
end
local function makeToggle(name,desc,getFn,onFn,offFn)
    local fr=pill(52); text(fr,name,desc)
    local btn=New("TextButton",{Text="",Font=Enum.Font.GothamBold,TextSize=14,TextColor3=Color3.new(1,1,1),Size=UDim2.new(0,108,0,34),Position=UDim2.new(1,-120,0,9)})
    btn.Parent=fr; New("UICorner",{CornerRadius=UDim.new(0,8)}).Parent=btn
    local function refresh() local v=false pcall(function() v=getFn() end); btn.Text=v and "ON" or "OFF"; btn.BackgroundColor3=v and Color3.fromRGB(30,140,90) or Color3.fromRGB(140,40,50) end
    btn.MouseButton1Click:Connect(function() local v=false pcall(function() v=getFn() end); if v then offFn() else onFn() end; refresh() end)
    refresh()
end
local function makeStepper(name,desc,getFn,setFn,min,max,step)
    local fr=pill(64); text(fr,name,desc)
    local minus=New("TextButton",{Text="−",Font=Enum.Font.GothamBold,TextSize=20,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(40,40,48),Size=UDim2.new(0,44,0,34),Position=UDim2.new(1,-210,0,22)}); minus.Parent=fr; New("UICorner",{CornerRadius=UDim.new(0,8)}).Parent=minus
    local box=New("TextBox",{Text="",PlaceholderText="--",Font=Enum.Font.GothamSemibold,TextSize=16,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(40,40,48),ClearTextOnFocus=false,Size=UDim2.new(0,110,0,34),Position=UDim2.new(1,-160,0,22)}); box.Parent=fr; New("UICorner",{CornerRadius=UDim.new(0,8)}).Parent=box
    local plus=New("TextButton",{Text="+",Font=Enum.Font.GothamBold,TextSize=20,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(40,40,48),Size=UDim2.new(0,44,0,34),Position=UDim2.new(1,-44,0,22)}); plus.Parent=fr; New("UICorner",{CornerRadius=UDim.new(0,8)}).Parent=plus
    local function current() local v=0 pcall(function() v=getFn() end) return v end
    local function setv(v) pcall(function() setFn(v) end) end
    local function clampStep(v) v=math.clamp(v,min,max); local s=step or 1; v=math.floor((v+s/2)/s)*s; return v end
    local function refresh() box.Text=tostring(current()) end
    minus.MouseButton1Click:Connect(function() setv(clampStep(current()-(step or 1))); refresh() end)
    plus.MouseButton1Click:Connect(function() setv(clampStep(current()+(step or 1))); refresh() end)
    box.FocusLost:Connect(function() local n=tonumber(box.Text); if n then setv(clampStep(n)) else box.Text=tostring(current()) end end)
    refresh()
end
local function makeButtonSmall(name,desc,getLabelFn,onClick)
    local fr=pill(64); text(fr,name,desc)
    local btn=New("TextButton",{Text=getLabelFn(),Font=Enum.Font.GothamBold,TextSize=14,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(40,40,48),Size=UDim2.new(0,140,0,34),Position=UDim2.new(1,-150,0,22)})
    btn.Parent=fr; New("UICorner",{CornerRadius=UDim.new(0,8)}).Parent=btn
    btn.MouseButton1Click:Connect(function() onClick(); btn.Text=getLabelFn() end)
end

-- Tabs builders
local function clearBody() for _,g in ipairs(Body:GetChildren()) do if g:IsA("GuiObject") then g:Destroy() end end end
local function buildMovimiento()
    makeToggle("Noclip","Atravesar objetos",API.Noclip.get,API.Noclip.on,API.Noclip.off)
    makeToggle("Sprint","Correr más rápido",API.Sprint.get,API.Sprint.on,API.Sprint.off)
    makeToggle("Fly","Vuelo (si tu hub lo expone)",API.Fly.get,API.Fly.on,API.Fly.off)

    makeStepper("WalkSpeed","Velocidad al caminar",API.WalkSpeed.get,API.WalkSpeed.set,API.WalkSpeed.min,API.WalkSpeed.max,API.WalkSpeed.step)
    makeStepper("SprintSpeed","Velocidad en sprint",API.SprintSpeed.get,API.SprintSpeed.set,API.SprintSpeed.min,API.SprintSpeed.max,API.SprintSpeed.step)
    makeStepper("FlySpeed","Velocidad de vuelo (referencia)",API.FlySpeed.get,API.FlySpeed.set,API.FlySpeed.min,API.FlySpeed.max,API.FlySpeed.step)

    -- Hit Aura real
    makeToggle("AURA HIT","Golpe de alcance extendido",API.Aura.get,API.Aura.on,API.Aura.off)
    makeStepper("Aura Range","Distancia aura (4..1000)",API.AuraRange.get,API.AuraRange.set,API.AuraRange.min,API.AuraRange.max,API.AuraRange.step)
    makeStepper("Aura Width","Ancho cápsula (1..50)",API.AuraWidth.get,API.AuraWidth.set,API.AuraWidth.min,API.AuraWidth.max,API.AuraWidth.step)
    makeStepper("Aura Delay","Intervalo (0.02..0.5 s)",API.AuraDelay.get,API.AuraDelay.set,API.AuraDelay.min,API.AuraDelay.max,API.AuraDelay.step)
    makeStepper("Aura FOV","Ángulo de visión (30..180)",API.AuraFOV.get,API.AuraFOV.set,API.AuraFOV.min,API.AuraFOV.max,API.AuraFOV.step)

    makeButtonSmall("Modo Aura","Alterna Cono / Esfera",function() return API.AuraMode.get() and "Mode: Cono" or "Mode: Esfera" end,function() API.AuraMode.toggle() end)
    makeButtonSmall("Línea de visión","Evita golpear tras paredes",function() return API.AuraLOS.get() and "LOS: ON" or "LOS: OFF" end,function() API.AuraLOS.toggle() end)
    makeButtonSmall("Burst por click","Usa alcance extra al tocar/click",function() return API.AuraClick.get() and "Click: ON" or "Click: OFF" end,function() API.AuraClick.toggle() end)
    makeStepper("Click Range","Distancia click (4..1000)",API.AuraClickRange.get,API.AuraClickRange.set,API.AuraClickRange.min,API.AuraClickRange.max,API.AuraClickRange.step)
    makeStepper("Proxy Size","Tamaño proxy (1..6)",API.AuraProxySize.get,API.AuraProxySize.set,API.AuraProxySize.min,API.AuraProxySize.max,API.AuraProxySize.step)
end
local function buildStealth()
    makeToggle("Invis","Invisibilidad replicada (si tu hub la tiene)",API.Invis.get,API.Invis.on,API.Invis.off)
    makeToggle("Ghost","Colisión fantasma (si tu hub la tiene)",API.Ghost.get,API.Ghost.on,API.Ghost.off)
end
local function buildAjustes()
    makeStepper("Opacidad UI","Transparencia (40-100%)",
        function() return math.floor((ENV.USH_CFG.opacity or 0.92)*100+0.5) end,
        function(v) ENV.USH_CFG.opacity=math.clamp(v/100,0.4,1.0); Root.BackgroundTransparency=1-ENV.USH_CFG.opacity end,
        40,100,5
    )
    makeStepper("Escala UI","Tamaño (50-150%)",
        function() return math.floor((ENV.USH_CFG.uiScale or 1.0)*100+0.5) end,
        function(v) ENV.USH_CFG.uiScale=math.clamp(v/100
