-- Ultra Touch GUI (Tablet) + Fallback funcional + Aura Hit
-- Luis x Copilot — GUI táctil, Noclip real, velocidades persistentes, y AURA HIT ajustable (4..1000)
-- Mantiene la GUI y funciones previas. Solo se agrega el botón AURA HIT y su control de tamaño.

-- ===== Servicios =====
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local function notify(t,d) pcall(function() StarterGui:SetCore("SendNotification",{Title="Ultra Touch",Text=t,Duration=d or 1.8}) end) end
local function clamp(v, lo, hi) if v<lo then return lo elseif v>hi then return hi else return v end end

-- ===== Entorno compartido =====
local ENV = (getgenv and getgenv()) or _G
if ENV.USH_GUI_LOADED then return end
ENV.USH_GUI_LOADED = true

ENV.USH_CFG = ENV.USH_CFG or {
  guiPos = {0.06, 0.16},
  uiScale = 1.0,
  opacity = 0.92,
}
ENV.USH_STATE = ENV.USH_STATE or {}

-- ===== Referencias de character con auto-rebind =====
local Conns = { char={}, noclip={}, speed={}, ui={}, aura={} }
local char, hum, hrp

local function disconnectAll(t) for _,c in ipairs(t) do pcall(function() c:Disconnect() end) end; table.clear(t) end
local function getChar()
  local c = player.Character or player.CharacterAdded:Wait()
  return c, c:WaitForChild("Humanoid"), c:WaitForChild("HumanoidRootPart")
end

-- ===== Fallback: estado base (velocidades y noclip) =====
ENV.USH_STATE.walkSpeed   = ENV.USH_STATE.walkSpeed   or 16
ENV.USH_STATE.sprintSpeed = ENV.USH_STATE.sprintSpeed or 80
ENV.USH_STATE.flySpeed    = ENV.USH_STATE.flySpeed    or 60
ENV.USH_STATE.sprint      = ENV.USH_STATE.sprint      or false
ENV.USH_STATE.noclip      = ENV.USH_STATE.noclip      or false

-- ===== AURA HIT: estado base =====
ENV.USH_STATE.aura        = ENV.USH_STATE.aura        or false
ENV.USH_STATE.auraSize    = clamp(ENV.USH_STATE.auraSize or 8, 4, 1000)

-- ===== Velocidad: aplicación y guardia =====
local function applyWalkSpeed()
  if not hum then return end
  local target = ENV.USH_STATE.sprint and ENV.USH_STATE.sprintSpeed or ENV.USH_STATE.walkSpeed
  ENV.USH_STATE._desiredSpeed = target
  hum.WalkSpeed = target
end

local function startSpeedGuard()
  disconnectAll(Conns.speed)
  if hum then
    table.insert(Conns.speed, hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
      local target = ENV.USH_STATE._desiredSpeed
      if target and math.abs((hum.WalkSpeed or 0) - target) > 0.5 then
        hum.WalkSpeed = target
      end
    end))
  end
  table.insert(Conns.speed, RunService.Heartbeat:Connect(function()
    if hum and ENV.USH_STATE._desiredSpeed and math.abs(hum.WalkSpeed - ENV.USH_STATE._desiredSpeed) > 0.5 then
      hum.WalkSpeed = ENV.USH_STATE._desiredSpeed
    end
  end))
end

-- ===== Noclip real (Stepped) =====
local function setNoCollide(model,on)
  for _,v in ipairs(model:GetDescendants()) do
    if v:IsA("BasePart") then v.CanCollide = not on end
  end
end

_G.noclipOn_fallback = function(silent)
  if ENV.USH_STATE.noclip then return end
  ENV.USH_STATE.noclip = true
  if not char or not char.Parent then return end
  setNoCollide(char, true)
  disconnectAll(Conns.noclip)
  table.insert(Conns.noclip, RunService.Stepped:Connect(function()
    if ENV.USH_STATE.noclip and char and char.Parent then
      setNoCollide(char, true)
    end
  end))
  if not silent then notify("Noclip ON") end
end

_G.noclipOff_fallback = function(silent)
  if not ENV.USH_STATE.noclip then return end
  ENV.USH_STATE.noclip = false
  disconnectAll(Conns.noclip)
  if char and char.Parent then setNoCollide(char, false) end
  if not silent then notify("Noclip OFF") end
end

-- ===== Sprint fallbacks =====
_G.setWalkSpeed_fallback = function(v)
  v = clamp(v, 8, 300)
  ENV.USH_STATE.walkSpeed = v
  applyWalkSpeed()
end
_G.setSprintSpeed_fallback = function(v)
  v = clamp(v, 16, 800)
  ENV.USH_STATE.sprintSpeed = v
  applyWalkSpeed()
end
_G.setFlySpeed_fallback = function(v)
  v = clamp(v, 10, 1200)
  ENV.USH_STATE.flySpeed = v
end
_G.sprintOn_fallback = function() ENV.USH_STATE.sprint = true;  applyWalkSpeed(); notify("Sprint ON", 1.2) end
_G.sprintOff_fallback= function() ENV.USH_STATE.sprint = false; applyWalkSpeed(); notify("Sprint OFF",1.2) end

-- ===== AURA HIT engine =====
local Aura = {
  enabled = false,
  size = ENV.USH_STATE.auraSize,     -- lado XZ (cuadrado). Min 4, max 1000.
  thickness = 6,                      -- grosor Y seguro
  tool = nil,
  handle = nil,
  saved = nil,
}

local function getEquippedTool()
  if not char then return nil end
  -- Busca Tool con Handle dentro del Character (equipado)
  for _,c in ipairs(char:GetChildren()) do
    if c:IsA("Tool") and c:FindFirstChild("Handle") and c.Handle:IsA("BasePart") then
      return c, c.Handle
    end
  end
  return nil
end

local function restoreHandle()
  if Aura.handle and Aura.saved then
    pcall(function()
      Aura.handle.Size = Aura.saved.Size
      Aura.handle.Massless = Aura.saved.Massless
      Aura.handle.CanCollide = Aura.saved.CanCollide
      if Aura.handle:IsA("BasePart") then
        if Aura.saved.Transparency ~= nil then Aura.handle.Transparency = Aura.saved.Transparency end
        if Aura.handle:FindFirstChildOfClass("SpecialMesh") and Aura.saved.MeshScale then
          local sm = Aura.handle:FindFirstChildOfClass("SpecialMesh")
          pcall(function() sm.Scale = Aura.saved.MeshScale end)
        end
      end
    end)
  end
  Aura.saved = nil
end

local function applyAuraTo(handle)
  if not handle then return end
  -- Guarda valores originales una vez
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
  -- Ajusta propiedades para hitbox grande y estable
  pcall(function()
    handle.Massless = true
    handle.CanCollide = false
    handle.Transparency = Aura.saved.Transparency -- no forzamos invisibilidad; evita flags visuales
    -- Importantísimo: el tamaño del Handle es el hitbox que muchos juegos usan para Tool.Touched
    local s = clamp(Aura.size, 4, 1000)
    handle.Size = Vector3.new(s, Aura.thickness, s)
    -- Mantén la posición siguiendo la mano (RightGrip ya lo hace). Si el juego usa otra soldadura, el tamaño igual sirve.
  end)
end

local function heartbeatAura()
  disconnectAll(Conns.aura)
  if not Aura.enabled then return end
  -- Track equip/unequip y aplica tamaño continuamente
  table.insert(Conns.aura, RunService.Heartbeat:Connect(function()
    if not char or not char.Parent then return end
    local t, h = getEquippedTool()
    if t ~= Aura.tool then
      -- Cambió el tool: restaura anterior y prepara nuevo
      if Aura.tool or Aura.handle then restoreHandle() end
      Aura.tool, Aura.handle = t, h
      if Aura.handle then applyAuraTo(Aura.handle) end
    else
      -- Igual tool: refresca tamaño por si cambió el slider
      if Aura.handle then applyAuraTo(Aura.handle) end
    end
  end))
  -- También escucha equip/des-equip explícito
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
  ENV.USH_STATE.aura = true
  heartbeatAura()
  notify("AURA HIT ON", 1.2)
end

local function auraOff()
  if not Aura.enabled then return end
  Aura.enabled = false
  ENV.USH_STATE.aura = false
  disconnectAll(Conns.aura)
  restoreHandle()
  Aura.tool, Aura.handle = nil, nil
  notify("AURA HIT OFF", 1.2)
end

local function setAuraSize(v)
  Aura.size = clamp(math.floor(v+0.5), 4, 1000)
  ENV.USH_STATE.auraSize = Aura.size
  -- En el próximo Heartbeat se re-aplica a handle si existe
end

-- Exponer fallbacks para la GUI (en caso tu hub no los tenga)
_G.auraOn_fallback      = auraOn
_G.auraOff_fallback     = auraOff
_G.setAuraSize_fallback = setAuraSize

-- ===== Rebind character y reaplicar estados =====
local function rebindCharacter()
  disconnectAll(Conns.char)
  char, hum, hrp = getChar()
  applyWalkSpeed()
  if ENV.USH_STATE.noclip then _G.noclipOn_fallback(true) end
  -- Reaplica AURA si está ON
  if ENV.USH_STATE.aura then
    Aura.tool, Aura.handle = nil, nil
    heartbeatAura()
  end
end

table.insert(Conns.char, player.CharacterAdded:Connect(function()
  task.wait(0.15)
  rebindCharacter()
end))

-- ===== Inicialización base =====
rebindCharacter()
applyWalkSpeed()
startSpeedGuard()

-- ===== Detección de API de tu hub (si existe) =====
local EXPOSED = ENV.USH or ENV.USE or ENV.STEALTH or ENV.HUB or ENV
local API = {
  Noclip = {
    get = function() return (EXPOSED.State and EXPOSED.State.noclip) or ENV.USH_STATE.noclip end,
    on  = function() if typeof(EXPOSED.noclipOn)=="function" then EXPOSED.noclipOn() else _G.noclipOn_fallback() end end,
    off = function() if typeof(EXPOSED.noclipOff)=="function" then EXPOSED.noclipOff() else _G.noclipOff_fallback() end end,
    desc="Atravesar objetos",
  },
  Sprint = {
    get = function() return (EXPOSED.State and EXPOSED.State.sprint) or ENV.USH_STATE.sprint end,
    on  = function() if typeof(EXPOSED.sprintOn)=="function" then EXPOSED.sprintOn() else _G.sprintOn_fallback() end end,
    off = function() if typeof(EXPOSED.sprintOff)=="function" then EXPOSED.sprintOff() else _G.sprintOff_fallback() end end,
    desc="Correr más rápido",
  },
  Fly = {
    get = function() return (EXPOSED.State and EXPOSED.State.fly) or (ENV.USH_STATE.fly or false) end,
    on  = function() if typeof(EXPOSED.flyOn)=="function" then EXPOSED.flyOn() else notify("Conecta tu Fly del hub") end end,
    off = function() if typeof(EXPOSED.flyOff)=="function" then EXPOSED.flyOff() else notify("Conecta tu Fly del hub") end end,
    desc="Vuelo libre",
  },
  Invis = {
    get = function() return (EXPOSED.State and EXPOSED.State.invisRep) or (ENV.USH_STATE.invisRep or false) end,
    on  = function() if typeof(EXPOSED.invisRepOn)=="function" then EXPOSED.invisRepOn() else notify("Conecta InvisRep del hub") end end,
    off = function() if typeof(EXPOSED.invisRepOff)=="function" then EXPOSED.invisRepOff() else notify("Conecta InvisRep del hub") end end,
    desc="Invisibilidad replicada",
  },
  Ghost = {
    get = function() return (EXPOSED.State and EXPOSED.State.ghost) or (ENV.USH_STATE.ghost or false) end,
    on  = function() if typeof(EXPOSED.ghostOn)=="function" then EXPOSED.ghostOn() else notify("Conecta Ghost del hub") end end,
    off = function() if typeof(EXPOSED.ghostOff)=="function" then EXPOSED.ghostOff() else notify("Conecta Ghost del hub") end end,
    desc="Colisión fantasma",
  },
  -- Speeds
  WalkSpeed = {
    get = function() return (EXPOSED.State and (EXPOSED.State.walkSpeed or EXPOSED.State.speedWalk)) or ENV.USH_STATE.walkSpeed end,
    set = function(v) if typeof(EXPOSED.setWalkSpeed)=="function" then EXPOSED.setWalkSpeed(v) else _G.setWalkSpeed_fallback(v) end end,
    min=8,max=300,step=2, desc="Velocidad caminar",
  },
  SprintSpeed = {
    get = function() return (EXPOSED.State and (EXPOSED.State.sprintSpeed or EXPOSED.State.speedSprint)) or ENV.USH_STATE.sprintSpeed end,
    set = function(v) if typeof(EXPOSED.setSprintSpeed)=="function" then EXPOSED.setSprintSpeed(v) else _G.setSprintSpeed_fallback(v) end end,
    min=16,max=800,step=5, desc="Velocidad sprint",
  },
  FlySpeed = {
    get = function() return (EXPOSED.State and (EXPOSED.State.flySpeed or EXPOSED.State.speedFly)) or ENV.USH_STATE.flySpeed end,
    set = function(v) if typeof(EXPOSED.setFlySpeed)=="function" then EXPOSED.setFlySpeed(v) else _G.setFlySpeed_fallback(v) end end,
    min=10,max=1200,step=10, desc="Velocidad vuelo",
  },
  -- Aura Hit
  Aura = {
    get = function() return (EXPOSED.State and EXPOSED.State.aura) or ENV.USH_STATE.aura end,
    on  = function() if typeof(EXPOSED.auraOn)=="function" then EXPOSED.auraOn() else _G.auraOn_fallback() end end,
    off = function() if typeof(EXPOSED.auraOff)=="function" then EXPOSED.auraOff() else _G.auraOff_fallback() end end,
    desc="Amplía el rango del Tool al golpear",
  },
  AuraSize = {
    get = function() return (EXPOSED.State and (EXPOSED.State.auraSize)) or ENV.USH_STATE.auraSize end,
    set = function(v) if typeof(EXPOSED.setAuraSize)=="function" then EXPOSED.setAuraSize(v) else _G.setAuraSize_fallback(v) end end,
    min=4,max=1000,step=10, desc="Tamaño del área (studs)",
  },
}

-- ===== UI Builder (tablet-first) =====
local function New(c,p,children) local o=Instance.new(c) for k,v in pairs(p or {}) do o[k]=v end if children then for _,ch in ipairs(children) do ch.Parent=o end end return o end

local Screen = New("ScreenGui",{Name="UltraTouchGUI",ResetOnSpawn=false,IgnoreGuiInset=true, ZIndexBehavior=Enum.ZIndexBehavior.Global})
Screen.Parent = player:WaitForChild("PlayerGui")
local UIScale = New("UIScale",{Scale=ENV.USH_CFG.uiScale or 1.0}); UIScale.Parent=Screen

local Root = New("Frame",{
  BackgroundColor3=Color3.fromRGB(20,20,24),
  BackgroundTransparency = 1 - (ENV.USH_CFG.opacity or 0.92),
  Size=UDim2.new(0,460,0,560),
  Position=UDim2.fromScale(ENV.USH_CFG.guiPos[1] or 0.06, ENV.USH_CFG.guiPos[2] or 0.16)
})
Root.Parent=Screen
New("UICorner",{CornerRadius=UDim.new(0,12)}).Parent=Root
New("UIStroke",{Thickness=1,Transparency=0.5,Color=Color3.fromRGB(60,60,70)}).Parent=Root

local Top = New("Frame",{BackgroundColor3=Color3.fromRGB(34,34,42),Size=UDim2.new(1,0,0,50)}); Top.Parent=Root
local Title = New("TextLabel",{BackgroundTransparency=1,Text="Ultra Stealth • Touch",Font=Enum.Font.GothamSemibold,TextSize=18,TextColor3=Color3.fromRGB(240,240,245),TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2.new(0,14,0,0),Size=UDim2.new(0.7,0,1,0)}); Title.Parent=Top
local Close = New("TextButton",{Text="✕",Font=Enum.Font.GothamBold,TextSize=18,BackgroundTransparency=1,TextColor3=Color3.fromRGB(240,240,245),Size=UDim2.new(0,48,1,0),Position=UDim2.new(1,-48,0,0)}); Close.Parent=Top
Close.MouseButton1Click:Connect(function() Screen.Enabled=false end)

-- Drag
local dragging=false; local startPos; local startInput
Top.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true; startPos=i.Position; startInput=i end end)
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

-- Contenido con tabs simples
local Tabs = New("Frame",{BackgroundColor3=Color3.fromRGB(34,34,42),Size=UDim2.new(1,0,0,40),Position=UDim2.new(0,0,0,50)}); Tabs.Parent=Root
local Body = New("ScrollingFrame",{BackgroundTransparency=1,Size=UDim2.new(1,0,1,-100),Position=UDim2.new(0,0,0,90),ScrollBarThickness=6}); Body.Parent=Root
local Layout = New("UIListLayout",{Padding=UDim.new(0,10),SortOrder=Enum.SortOrder.LayoutOrder}); Layout.Parent=Body
local Pad = New("UIPadding",{PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12),PaddingTop=UDim.new(0,12),PaddingBottom=UDim.new(0,12)}); Pad.Parent=Body
local function updateCanvas() Body.CanvasSize = UDim2.new(0,0,0,Layout.AbsoluteContentSize.Y+24) end
Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)

local function pill(h) local f=New("Frame",{BackgroundColor3=Color3.fromRGB(28,28,34),Size=UDim2.new(1,0,0,h or 52)}); f.Parent=Body; New("UICorner",{CornerRadius=UDim.new(0,10)}).Parent=f; New("UIStroke",{Thickness=1,Transparency=0.4,Color=Color3.fromRGB(55,55,65)}).Parent=f; return f end
local function text(parent, t, sub)
  local l=New("TextLabel",{BackgroundTransparency=1,Text=t,Font=Enum.Font.GothamSemibold,TextSize=16,TextColor3=Color3.fromRGB(235,235,240),TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2.new(0,12,0,6),Size=UDim2.new(1,-140,0,20)}); l.Parent=parent
  if sub then local s=New("TextLabel",{BackgroundTransparency=1,Text=sub,Font=Enum.Font.Gotham,TextSize=12,TextColor3=Color3.fromRGB(170,170,180),TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2.new(0,12,0,26),Size=UDim2.new(1,-140,0,18)}); s.Parent=parent end
end

local function makeToggle(name, desc, getFn, onFn, offFn)
  local fr = pill(52); text(fr, name, desc)
  local btn = New("TextButton",{Text="",Font=Enum.Font.GothamBold,TextSize=14,TextColor3=Color3.new(1,1,1),Size=UDim2.new(0,108,0,34),Position=UDim2.new(1,-120,0,9)})
  btn.Parent=fr; New("UICorner",{CornerRadius=UDim.new(0,8)}).Parent=btn
  local function refresh()
    local v = false; pcall(function() v=getFn() end)
    btn.Text = v and "ON" or "OFF"
    btn.BackgroundColor3 = v and Color3.fromRGB(30,140,90) or Color3.fromRGB(140,40,50)
  end
  btn.MouseButton1Click:Connect(function()
    local v=false; pcall(function() v=getFn() end)
    if v then offFn() else onFn() end
    refresh()
  end)
  refresh()
end

local function makeStepper(name, desc, getFn, setFn, min, max, step)
  local fr = pill(64); text(fr, name, desc)
  local minus = New("TextButton",{Text="−",Font=Enum.Font.GothamBold,TextSize=20,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(40,40,48),Size=UDim2.new(0,44,0,34),Position=UDim2.new(1,-210,0,22)}); minus.Parent=fr; New("UICorner",{CornerRadius=UDim.new(0,8)}).Parent=minus
  local box = New("TextBox",{Text="",PlaceholderText="--",Font=Enum.Font.GothamSemibold,TextSize=16,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(40,40,48),ClearTextOnFocus=false,Size=UDim2.new(0,110,0,34),Position=UDim2.new(1,-160,0,22)}); box.Parent=fr; New("UICorner",{CornerRadius=UDim.new(0,8)}).Parent=box
  local plus = New("TextButton",{Text="+",Font=Enum.Font.GothamBold,TextSize=20,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(40,40,48),Size=UDim2.new(0,44,0,34),Position=UDim2.new(1,-44,0,22)}); plus.Parent=fr; New("UICorner",{CornerRadius=UDim.new(0,8)}).Parent=plus

  local function current() local v=0 pcall(function() v=getFn() end); return v end
  local function set(v) pcall(function() setFn(v) end) end
  local function clampStep(v)
    v = math.clamp(v, min, max); local s=step or 1
    v = math.floor((v + s/2)/s)*s; return v
  end
  local function refresh() box.Text = tostring(current()) end
  minus.MouseButton1Click:Connect(function() set(clampStep(current() - (step or 1))); refresh() end)
  plus.MouseButton1Click:Connect(function() set(clampStep(current() + (step or 1))); refresh() end)
  box.FocusLost:Connect(function(enter)
    local n = tonumber(box.Text)
    if n then set(clampStep(n)) else box.Text = tostring(current()) end
  end)
  refresh()
end

-- Tabs (Movimiento / Stealth / Ajustes)
local function clearBody() for _,g in ipairs(Body:GetChildren()) do if g:IsA("GuiObject") then g:Destroy() end end end
local function buildMovimiento()
  makeToggle("Noclip", "Atravesar objetos", API.Noclip.get, API.Noclip.on, API.Noclip.off)
  makeToggle("Sprint", "Correr más rápido", API.Sprint.get, API.Sprint.on, API.Sprint.off)
  makeToggle("Fly", "Vuelo (si tu hub lo expone)", API.Fly.get, API.Fly.on, API.Fly.off)

  makeStepper("WalkSpeed", "Velocidad al caminar", API.WalkSpeed.get, API.WalkSpeed.set, API.WalkSpeed.min, API.WalkSpeed.max, API.WalkSpeed.step)
  makeStepper("SprintSpeed", "Velocidad en sprint", API.SprintSpeed.get, API.SprintSpeed.set, API.SprintSpeed.min, API.SprintSpeed.max, API.SprintSpeed.step)
  makeStepper("FlySpeed", "Velocidad de vuelo (referencia)", API.FlySpeed.get, API.FlySpeed.set, API.FlySpeed.min, API.FlySpeed.max, API.FlySpeed.step)

  -- NUEVO: AURA HIT
  makeToggle("AURA HIT", "Amplía el área del golpe (Tool Handle)", API.Aura.get, API.Aura.on, API.Aura.off)
  makeStepper("Aura Size", "Tamaño del área (4..1000 studs)", API.AuraSize.get, API.AuraSize.set, API.AuraSize.min, API.AuraSize.max, API.AuraSize.step)
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

local tabIndex = 1
local function buildTab(i)
  clearBody()
  if i==1 then buildMovimiento()
  elseif i==2 then buildStealth()
  else buildAjustes() end
  updateCanvas()
end

local function tabBtn(label, x, idx)
  local b = New("TextButton",{Text=label,Font=Enum.Font.GothamSemibold,TextSize=14,TextColor3=Color3.fromRGB(235,235,240),BackgroundColor3=Color3.fromRGB(34,34,42),Size=UDim2.new(0,120,1,0),Position=UDim2.new(0,x,0,0)})
  b.Parent=Tabs
  b.MouseButton1Click:Connect(function() tabIndex=idx; buildTab(idx) end)
  return b
end

tabBtn("Movimiento", 8, 1)
tabBtn("Stealth",   136, 2)
tabBtn("Ajustes",   264, 3)
buildTab(1)

notify("GUI táctil lista. Noclip, velocidad y
