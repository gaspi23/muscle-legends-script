-- SuperPlayer Hub - Noclip + Fly + Sprint + Invis Server + Ghost Mode (GUI + Keybinds)
-- Autor: Luis & Copilot

-- ====== Servicios ======
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local player = Players.LocalPlayer

-- ====== Util ======
local function getChar()
    local char = player.Character or player.CharacterAdded:Wait()
    local hum = char:WaitForChild("Humanoid")
    local hrp = char:WaitForChild("HumanoidRootPart")
    return char, hum, hrp
end

local function safeConnect(box, signal, fn)
    local c = signal:Connect(fn)
    table.insert(box, c)
    return c
end

local function disconnectAll(t)
    for _, c in ipairs(t) do pcall(function() c:Disconnect() end) end
    table.clear(t)
end

-- ====== Estado ======
local State = {
    noclip = false,
    fly = false,
    sprint = false,
    speedWalk = 16,
    speedSprint = 80,
    speedFly = 60,
    invisRep = false,   -- Invisibilidad replicada (otros no te ven)
    ghost = false,      -- Ghost Mode (tu char real lejos; controlas clon local)
}

local Conns = {
    noclip = {},
    fly = {},
    input = {},
    char = {},
    invis = {},
    ghost = {},
}

-- Personajes
local realChar, realHum, realHrp = getChar()
-- Control actual (real o ghost)
local ctrlChar, ctrlHum, ctrlHrp = realChar, realHum, realHrp

-- ====== Invisibilidad (Replicada, server-visible) ======
local Appearance = {
    partT = {}, decalT = {}, accT = {}, clothing = {}, humName = nil
}

local function hideServer(c)
    local h = c:FindFirstChildOfClass("Humanoid")

    for _, d in ipairs(c:GetDescendants()) do
        if d:IsA("BasePart") then
            if Appearance.partT[d] == nil then Appearance.partT[d] = d.Transparency end
            d.Transparency = 1
            d.Reflectance = 0
            if d.Name == "HumanoidRootPart" then d.CanCollide = false end
        elseif d:IsA("Decal") then
            if Appearance.decalT[d] == nil then Appearance.decalT[d] = d.Transparency end
            d.Transparency = 1
        elseif d:IsA("Accessory") then
            local handle = d:FindFirstChild("Handle")
            if handle then
                if Appearance.accT[handle] == nil then Appearance.accT[handle] = handle.Transparency end
                handle.Transparency = 1
                for _, dd in ipairs(handle:GetDescendants()) do
                    if dd:IsA("Decal") then
                        if Appearance.decalT[dd] == nil then Appearance.decalT[dd] = dd.Transparency end
                        dd.Transparency = 1
                    end
                end
            end
        elseif d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") then
            if Appearance.clothing[d] == nil then
                if d:IsA("Shirt") then Appearance.clothing[d] = d.ShirtTemplate; d.ShirtTemplate = "" end
                if d:IsA("Pants") then Appearance.clothing[d] = d.PantsTemplate; d.PantsTemplate = "" end
                if d:IsA("ShirtGraphic") then Appearance.clothing[d] = d.Graphic; d.Graphic = "" end
            else
                if d:IsA("Shirt") then d.ShirtTemplate = "" end
                if d:IsA("Pants") then d.PantsTemplate = "" end
                if d:IsA("ShirtGraphic") then d.Graphic = "" end
            end
        end
    end

    if h then
        if not Appearance.humName then
            Appearance.humName = {
                DisplayDistanceType = h.DisplayDistanceType,
                NameDisplayDistance = h.NameDisplayDistance
            }
        end
        pcall(function() h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end)
        pcall(function() h.NameDisplayDistance = 0 end)
    end
end

local function showServer(c)
    local h = c:FindFirstChildOfClass("Humanoid")
    for inst, t in pairs(Appearance.partT) do if inst and inst.Parent then inst.Transparency = t end end
    for inst, t in pairs(Appearance.decalT) do if inst and inst.Parent then inst.Transparency = t end end
    for inst, t in pairs(Appearance.accT)   do if inst and inst.Parent then inst.Transparency = t end end
    for cloth, val in pairs(Appearance.clothing) do
        if cloth and cloth.Parent then
            if cloth:IsA("Shirt") then cloth.ShirtTemplate = val end
            if cloth:IsA("Pants") then cloth.PantsTemplate = val end
            if cloth:IsA("ShirtGraphic") then cloth.Graphic = val end
        end
    end
    if h and Appearance.humName then
        pcall(function() h.DisplayDistanceType = Appearance.humName.DisplayDistanceType end)
        pcall(function() h.NameDisplayDistance  = Appearance.humName.NameDisplayDistance  end)
    end
end

local function invisRepOn()
    if State.invisRep then return end
    State.invisRep = true
    hideServer(realChar)
    -- Anti-restore: reocultar si el juego te reviste
    safeConnect(Conns.invis, RunService.Heartbeat, function()
        if State.invisRep and realChar and realChar.Parent then hideServer(realChar) end
    end)
    safeConnect(Conns.invis, realChar.DescendantAdded, function(d) if State.invisRep then task.defer(hideServer, realChar) end end)
end

local function invisRepOff()
    if not State.invisRep then return end
    State.invisRep = false
    disconnectAll(Conns.invis)
    showServer(realChar)
end

-- ====== Ghost Mode ======
local ghostModel, camPrevSubj
local function makeGhostFromUser()
    local ok, model = pcall(function()
        return Players:CreateHumanoidModelFromUserId(player.UserId)
    end)
    if ok and model then return model end
    -- Fallback: clonar estructura básica del realChar
    local clone = realChar:Clone()
    for _, d in ipairs(clone:GetDescendants()) do
        if d:IsA("Script") or d:IsA("LocalScript") then d:Destroy() end
    end
    return clone
end

local function ghostOn()
    if State.ghost then return end
    State.ghost = true

    -- Crear ghost local
    ghostModel = makeGhostFromUser()
    ghostModel.Name = "Ghost_"..player.Name
    ghostModel.Parent = workspace
    local gHum = ghostModel:FindFirstChildOfClass("Humanoid") or Instance.new("Humanoid", ghostModel)
    local gRoot = ghostModel:FindFirstChild("HumanoidRootPart") or ghostModel:WaitForChild("HumanoidRootPart")
    gHum.PlatformStand = false
    gHum:ChangeState(Enum.HumanoidStateType.Running)
    ghostModel:MoveTo(realHrp.Position + Vector3.new(0, 2, 0))

    -- Cam -> ghost
    camPrevSubj = workspace.CurrentCamera.CameraSubject
    workspace.CurrentCamera.CameraSubject = gHum

    -- Alejar y anclar personaje real (invisible absoluta para todos)
    pcall(function()
        realHrp.Anchored = true
        realHum.PlatformStand = true
        realHrp.CFrame = CFrame.new(0, -10000, 0)
        hideServer(realChar)
    end)

    -- Redirigir control al ghost
    ctrlChar, ctrlHum, ctrlHrp = ghostModel, gHum, gRoot

    -- Asegurar que el real no regrese por correcciones del server
    safeConnect(Conns.ghost, RunService.Heartbeat, function()
        if not State.ghost then return end
        if realHrp and realHrp.Parent then
            if realHrp.Position.Y > -9000 then
                realHrp.CFrame = CFrame.new(0, -10000, 0)
            end
        end
    end)
end

local function ghostOff()
    if not State.ghost then return end
    State.ghost = false
    disconnectAll(Conns.ghost)

    -- Regresar control al real y teletransportarlo a donde está el ghost
    local backPos = ctrlHrp and ctrlHrp.Position or realHrp.Position + Vector3.new(0,3,0)
    if ghostModel and ghostModel.Parent then ghostModel:Destroy() end
    ghostModel = nil

    pcall(function()
        realHrp.Anchored = false
        realHum.PlatformStand = false
        realHrp.CFrame = CFrame.new(backPos + Vector3.new(0,2,0))
    end)

    -- Restaurar cámara y control
    if camPrevSubj then workspace.CurrentCamera.CameraSubject = camPrevSubj end
    ctrlChar, ctrlHum, ctrlHrp = realChar, realHum, realHrp
end

-- ====== Noclip ======
local function setNoCollide(model, on)
    for _, v in ipairs(model:GetDescendants()) do
        if v:IsA("BasePart") then v.CanCollide = not on end
    end
end

local function noclipOn()
    if State.noclip then return end
    State.noclip = true
    setNoCollide(ctrlChar, true)
    safeConnect(Conns.noclip, RunService.Stepped, function()
        if State.noclip and ctrlChar and ctrlChar.Parent then setNoCollide(ctrlChar, true) end
    end)
end

local function noclipOff()
    if not State.noclip then return end
    State.noclip = false
    disconnectAll(Conns.noclip)
    setNoCollide(ctrlChar, false)
end

-- ====== Fly ======
local flyBV, flyBG
local moveKeys = {W=false, A=false, S=false, D=false, Up=false, Down=false}

local function computeFlyVelocity()
    local cam = workspace.CurrentCamera
    local dir = Vector3.new()
    local moveDir = ctrlHum and ctrlHum.MoveDirection or Vector3.new()
    if moveDir.Magnitude > 0 then
        local cf = cam.CFrame
        local forward, right = cf.LookVector, cf.RightVector
        local planar = (forward * moveDir.Z + right * moveDir.X)
        dir = dir + Vector3.new(planar.X, 0, planar.Z)
    else
        local cf = cam.CFrame
        if moveKeys.W then dir = dir + cf.LookVector end
        if moveKeys.S then dir = dir - cf.LookVector end
        if moveKeys.A then dir = dir - cf.RightVector end
        if moveKeys.D then dir = dir + cf.RightVector end
    end
    if moveKeys.Up then dir += Vector3.new(0, 1, 0) end
    if moveKeys.Down then dir += Vector3.new(0, -1, 0) end
    if dir.Magnitude > 0 then dir = dir.Unit * State.speedFly end
    return dir
end

local function flyOn()
    if State.fly then return end
    State.fly = true
    flyBV = Instance.new("BodyVelocity")
    flyBV.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    flyBV.Velocity = Vector3.new()
    flyBV.P = 1e4
    flyBV.Parent = ctrlHrp

    flyBG = Instance.new("BodyGyro")
    flyBG.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
    flyBG.P = 3e4
    flyBG.CFrame = ctrlHrp.CFrame
    flyBG.Parent = ctrlHrp

    ctrlHum:ChangeState(Enum.HumanoidStateType.Physics)
    ctrlHum.PlatformStand = true

    safeConnect(Conns.fly, RunService.Heartbeat, function()
        if not State.fly or not ctrlHrp or not ctrlHum then return end
        if flyBV.Parent ~= ctrlHrp then flyBV.Parent = ctrlHrp end
        if flyBG.Parent ~= ctrlHrp then flyBG.Parent = ctrlHrp end
        flyBV.Velocity = computeFlyVelocity()
        flyBG.CFrame = CFrame.new(ctrlHrp.Position, ctrlHrp.Position + workspace.CurrentCamera.CFrame.LookVector)
    end)
end

local function flyOff()
    if not State.fly then return end
    State.fly = false
    disconnectAll(Conns.fly)
    if flyBV then flyBV:Destroy() flyBV = nil end
    if flyBG then flyBG:Destroy() flyBG = nil end
    if ctrlHum then
        ctrlHum.PlatformStand = false
        ctrlHum:ChangeState(Enum.HumanoidStateType.RunningNoPhysics)
        ctrlHum:Move(Vector3.new())
    end
end

-- ====== Sprint ======
local shiftHeld = false
local function applyWalkSpeed()
    if not ctrlHum then return end
    ctrlHum.WalkSpeed = (State.sprint or shiftHeld) and State.speedSprint or State.speedWalk
end

local function sprintToggle()
    State.sprint = not State.sprint
    applyWalkSpeed()
end

-- ====== Input ======
local function bindInputs()
    disconnectAll(Conns.input)
    safeConnect(Conns.input, UIS.InputBegan, function(input, gp)
        if gp then return end
        local kc = input.KeyCode
        if kc == Enum.KeyCode.T then
            if State.noclip then noclipOff() else noclipOn() end
        elseif kc == Enum.KeyCode.F then
            if State.fly then flyOff() else flyOn() end
        elseif kc == Enum.KeyCode.G then
            if State.invisRep then invisRepOff() else invisRepOn() end
        elseif kc == Enum.KeyCode.H then
            if State.ghost then ghostOff() else ghostOn() end
        elseif kc == Enum.KeyCode.LeftShift then
            shiftHeld = true; applyWalkSpeed()
        elseif kc == Enum.KeyCode.Space then
            moveKeys.Up = true
        elseif kc == Enum.KeyCode.LeftControl or kc == Enum.KeyCode.C then
            moveKeys.Down = true
        elseif kc == Enum.KeyCode.W then moveKeys.W = true
        elseif kc == Enum.KeyCode.A then moveKeys.A = true
        elseif kc == Enum.KeyCode.S then moveKeys.S = true
        elseif kc == Enum.KeyCode.D then moveKeys.D = true
        end
    end)
    safeConnect(Conns.input, UIS.InputEnded, function(input, gp)
        if gp then return end
        local kc = input.KeyCode
        if kc == Enum.KeyCode.LeftShift then
            shiftHeld = false; applyWalkSpeed()
        elseif kc == Enum.KeyCode.Space then
            moveKeys.Up = false
        elseif kc == Enum.KeyCode.LeftControl or kc == Enum.KeyCode.C then
            moveKeys.Down = false
        elseif kc == Enum.KeyCode.W then moveKeys.W = false
        elseif kc == Enum.KeyCode.A then moveKeys.A = false
        elseif kc == Enum.KeyCode.S then moveKeys.S = false
        elseif kc == Enum.KeyCode.D then moveKeys.D = false
        end
    end)
end

-- ====== GUI ======
local function buildGUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "SuperPlayerHub"
    gui.ResetOnSpawn = false
    gui.Parent = player:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 260, 0, 250)
    frame.Position = UDim2.new(0.5, -130, 0.5, -125)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    frame.BorderSizePixel = 0
    frame.Parent = gui

    local pad = Instance.new("UIPadding", frame)
    pad.PaddingTop = UDim.new(0, 10)
    pad.PaddingLeft = UDim.new(0, 10)
    pad.PaddingRight = UDim.new(0, 10)
    pad.PaddingBottom = UDim.new(0, 10)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 24)
    title.BackgroundTransparency = 1
    title.Text = "SuperPlayer Hub"
    title.TextColor3 = Color3.new(1,1,1)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.Parent = frame

    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, 8)
    list.HorizontalAlignment = Enum.HorizontalAlignment.Center
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Parent = frame

    local function btn(text, cb)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -20, 0, 32)
        b.BackgroundColor3 = Color3.fromRGB(45,45,45)
        b.TextColor3 = Color3.new(1,1,1)
        b.Font = Enum.Font.GothamSemibold
        b.TextSize = 14
        b.Text = text
        b.Parent = frame
        b.MouseButton1Click:Connect(function() cb(b) end)
        return b
    end

    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(1, -20, 0, 22)
    info.BackgroundTransparency = 1
    info.Text = "T: Noclip | F: Fly | G: Invis | H: Ghost | Shift: Sprint"
    info.TextColor3 = Color3.fromRGB(180,180,180)
    info.Font = Enum.Font.Gotham
    info.TextSize = 12
    info.Parent = frame

    local bNoclip = btn("Noclip: OFF", function(b)
        if State.noclip then noclipOff(); b.Text = "Noclip: OFF" else noclipOn(); b.Text = "Noclip: ON" end
    end)

    local bFly = btn("Fly: OFF", function(b)
        if State.fly then flyOff(); b.Text = "Fly: OFF" else flyOn(); b.Text = "Fly: ON" end
    end)

    local bSprint = btn("Sprint: OFF", function(b)
        sprintToggle(); b.Text = State.sprint and "Sprint: ON" or "Sprint: OFF"
    end)

    local bInvis = btn("Invis Server: OFF", function(b)
        if State.invisRep then invisRepOff(); b.Text = "Invis Server: OFF" else invisRepOn(); b.Text = "Invis Server: ON" end
    end)

    local bGhost = btn("Ghost Mode: OFF", function(b)
        if State.ghost then ghostOff(); b.Text = "Ghost Mode: OFF"
        else
            -- si activas ghost, desactiva invisRep para evitar peleas de estados
            if State.invisRep then invisRepOff() end
            ghostOn(); b.Text = "Ghost Mode: ON"
        end
    end)

    -- Controles de velocidad
    local speeds = Instance.new("Frame")
    speeds.Size = UDim2.new(1, -20, 0, 80)
    speeds.BackgroundTransparency = 1
    speeds.Parent = frame

    local wsLbl = Instance.new("TextLabel")
    wsLbl.Size = UDim2.new(1, 0, 0, 18)
    wsLbl.BackgroundTransparency = 1
    wsLbl.Text = "WalkSpeed: "..State.speedWalk
    wsLbl.TextColor3 = Color3.fromRGB(200,200,200)
    wsLbl.Font = Enum.Font.Gotham
    wsLbl.TextSize = 12
    wsLbl.Parent = speeds

    local function mkAdj(text, x, cb)
        local t = Instance.new("TextButton")
        t.Size = UDim2.new(0, 36, 0, 24)
        t.Position = UDim2.new(0, x, 0, 22)
        t.BackgroundColor3 = Color3.fromRGB(45,45,45)
        t.TextColor3 = Color3.new(1,1,1)
        t.Font = Enum.Font.GothamSemibold
        t.TextSize = 12
        t.Text = text
        t.Parent = speeds
        t.MouseButton1Click:Connect(cb)
        return t
    end

    mkAdj("+WS", 0, function()
        State.speedWalk = math.clamp(State.speedWalk + 2, 8, 200)
        wsLbl.Text = "WalkSpeed: "..State.speedWalk
        applyWalkSpeed()
    end)
    mkAdj("-WS", 40, function()
        State.speedWalk = math.clamp(State.speedWalk - 2, 8, 200)
        wsLbl.Text = "WalkSpeed: "..State.speedWalk
        applyWalkSpeed()
    end)

    local spLbl = wsLbl:Clone()
    spLbl.Position = UDim2.new(0,0,0,48)
    spLbl.Text = "SprintSpeed: "..State.speedSprint
    spLbl.Parent = speeds

    mkAdj("+SP", 80, function()
        State.speedSprint = math.clamp(State.speedSprint + 5, 16, 400)
        spLbl.Text = "SprintSpeed: "..State.speedSprint
        applyWalkSpeed()
    end)
    mkAdj("-SP", 120, function()
        State.speedSprint = math.clamp(State.speedSprint - 5, 16, 400)
        spLbl.Text = "SprintSpeed: "..State.speedSprint
        applyWalkSpeed()
    end)

    -- Drag
    local dragging, dragStart, startPos = false, nil, nil
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    frame.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- ====== Ciclo de vida ======
local function rebindControlToReal()
    ctrlChar, ctrlHum, ctrlHrp = realChar, realHum, realHrp
    applyWalkSpeed()
    if State.noclip then noclipOn() end
    if State.fly then flyOn() end
end

local function onCharacterAdded()
    disconnectAll(Conns.char)
    realChar, realHum, realHrp = getChar()
    -- Reaplicar invis server si estaba ON
    if State.invisRep then task.defer(invisRepOn) end
    -- Reaplicar ghost si estaba ON
    if State.ghost then task.delay(0.25, function() if State.ghost then ghostOn() end end) end
    -- Si controlabas real, reengancha velocidades/estados
    if not State.ghost then rebindControlToReal() end
end

table.insert(Conns.char, player.CharacterAdded:Connect(onCharacterAdded))

-- ====== Init ======
bindInputs()
buildGUI()
applyWalkSpeed()

    
