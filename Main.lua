-- SuperPlayer Hub - Noclip + Fly + Sprint + Invis (GUI + Keybinds)
-- Autor: Luis & Copilot

-- ====== Servicios y utilidades ======
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

local player = Players.LocalPlayer

local function getChar()
    local char = player.Character or player.CharacterAdded:Wait()
    local hum = char:WaitForChild("Humanoid")
    local hrp = char:WaitForChild("HumanoidRootPart")
    return char, hum, hrp
end

local function safeConnect(connTable, signal, fn)
    local c = signal:Connect(fn)
    table.insert(connTable, c)
    return c
end

-- ====== Estado ======
local State = {
    noclip = false,
    fly = false,
    sprint = false,
    invis = false,
    speedWalk = 16,
    speedSprint = 80,
    speedFly = 60,
}

local Conns = {
    noclip = {},
    fly = {},
    char = {},
    input = {},
}

local char, hum, hrp = getChar()

-- ====== Invisibilidad ======
local Appearance = {
    parts = {},
    decals = {},
    accHandles = {},
    clothing = {},
    humanoidName = {},
}

local function hideCharacter(c)
    local h = c:FindFirstChildOfClass("Humanoid")

    -- Guardar y ocultar partes (R6/R15/MeshPart)
    for _, d in ipairs(c:GetDescendants()) do
        if d:IsA("BasePart") then
            if not Appearance.parts[d] then
                Appearance.parts[d] = d.Transparency
            end
            d.Transparency = 1
            pcall(function() d.LocalTransparencyModifier = 1 end)
        elseif d:IsA("Decal") then
            if not Appearance.decals[d] then
                Appearance.decals[d] = d.Transparency
            end
            d.Transparency = 1
        elseif d:IsA("Accessory") then
            local handle = d:FindFirstChild("Handle")
            if handle then
                if not Appearance.accHandles[handle] then
                    Appearance.accHandles[handle] = handle.Transparency
                end
                handle.Transparency = 1
                pcall(function() handle.LocalTransparencyModifier = 1 end)
                for _, dd in ipairs(handle:GetDescendants()) do
                    if dd:IsA("Decal") then
                        if not Appearance.decals[dd] then
                            Appearance.decals[dd] = dd.Transparency
                        end
                        dd.Transparency = 1
                    end
                end
            end
        elseif d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") then
            if not Appearance.clothing[d] then
                -- Guardar plantillas para restaurar
                if d:IsA("Shirt") then
                    Appearance.clothing[d] = d.ShirtTemplate
                    d.ShirtTemplate = ""
                elseif d:IsA("Pants") then
                    Appearance.clothing[d] = d.PantsTemplate
                    d.PantsTemplate = ""
                elseif d:IsA("ShirtGraphic") then
                    Appearance.clothing[d] = d.Graphic
                    d.Graphic = ""
                end
            else
                -- Ya guardado; forzar oculto
                if d:IsA("Shirt") then d.ShirtTemplate = "" end
                if d:IsA("Pants") then d.PantsTemplate = "" end
                if d:IsA("ShirtGraphic") then d.Graphic = "" end
            end
        end
    end

    -- Ocultar nombre
    if h then
        if Appearance.humanoidName.saved == nil then
            Appearance.humanoidName.saved = {
                DisplayDistanceType = (h.DisplayDistanceType or nil),
                NameDisplayDistance = (h.NameDisplayDistance or nil),
            }
        end
        pcall(function() h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end)
        pcall(function() h.NameDisplayDistance = 0 end)
    end
end

local function showCharacter(c)
    local h = c:FindFirstChildOfClass("Humanoid")
    for inst, t in pairs(Appearance.parts) do
        if inst and inst.Parent then
            pcall(function()
                inst.Transparency = t
                inst.LocalTransparencyModifier = 0
            end)
        end
    end
    for inst, t in pairs(Appearance.decals) do
        if inst and inst.Parent then
            pcall(function() inst.Transparency = t end)
        end
    end
    for handle, t in pairs(Appearance.accHandles) do
        if handle and handle.Parent then
            pcall(function()
                handle.Transparency = t
                handle.LocalTransparencyModifier = 0
            end)
        end
    end
    for cloth, val in pairs(Appearance.clothing) do
        if cloth and cloth.Parent then
            pcall(function()
                if cloth:IsA("Shirt") then cloth.ShirtTemplate = val end
                if cloth:IsA("Pants") then cloth.PantsTemplate = val end
                if cloth:IsA("ShirtGraphic") then cloth.Graphic = val end
            end)
        end
    end
    if h and Appearance.humanoidName.saved then
        pcall(function()
            if Appearance.humanoidName.saved.DisplayDistanceType then
                h.DisplayDistanceType = Appearance.humanoidName.saved.DisplayDistanceType
            end
        end)
        pcall(function()
            if Appearance.humanoidName.saved.NameDisplayDistance then
                h.NameDisplayDistance = Appearance.humanoidName.saved.NameDisplayDistance
            end
        end)
    end
end

local function invisOn()
    if State.invis then return end
    State.invis = true
    hideCharacter(char)
    -- Reaplicar periódicamente por si el juego re-veste o añade accesorios
    safeConnect(Conns.char, RunService.Heartbeat, function()
        if State.invis and char and char.Parent then
            hideCharacter(char)
        end
    end)
end

local function invisOff()
    if not State.invis then return end
    State.invis = false
    for _, c in ipairs(Conns.char) do c:Disconnect() end
    Conns.char = {}
    showCharacter(char)
end

-- ====== Noclip ======
local function setCharNoCollide(on)
    if not char then return end
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("BasePart") then
            v.CanCollide = not on
        end
    end
end

local function noclipOn()
    if State.noclip then return end
    State.noclip = true
    setCharNoCollide(true)
    safeConnect(Conns.noclip, RunService.Stepped, function()
        if not State.noclip then return end
        setCharNoCollide(true)
    end)
end

local function noclipOff()
    if not State.noclip then return end
    State.noclip = false
    for _, c in ipairs(Conns.noclip) do c:Disconnect() end
    Conns.noclip = {}
    setCharNoCollide(false)
end

-- ====== Fly ======
local flyBV, flyBG
local moveKeys = {W=false, A=false, S=false, D=false, Up=false, Down=false}

local function computeFlyVelocity()
    local cam = workspace.CurrentCamera
    local dir = Vector3.new()
    local moveDir = hum and hum.MoveDirection or Vector3.new()
    if moveDir.Magnitude > 0 then
        local cf = cam.CFrame
        local forward = cf.LookVector
        local right = cf.RightVector
        local planar = (forward * moveDir.Z + right * moveDir.X)
        dir = dir + Vector3.new(planar.X, 0, planar.Z)
    else
        local cf = cam.CFrame
        if moveKeys.W then dir = dir + cf.LookVector end
        if moveKeys.S then dir = dir - cf.LookVector end
        if moveKeys.A then dir = dir - cf.RightVector end
        if moveKeys.D then dir = dir + cf.RightVector end
    end
    if moveKeys.Up then dir = dir + Vector3.new(0, 1, 0) end
    if moveKeys.Down then dir = dir + Vector3.new(0, -1, 0) end
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
    flyBV.Parent = hrp

    flyBG = Instance.new("BodyGyro")
    flyBG.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
    flyBG.P = 3e4
    flyBG.CFrame = hrp.CFrame
    flyBG.Parent = hrp

    hum:ChangeState(Enum.HumanoidStateType.Physics)
    hum.PlatformStand = true

    safeConnect(Conns.fly, RunService.Heartbeat, function()
        if not State.fly or not hrp or not hum then return end
        flyBV.Velocity = computeFlyVelocity()
        flyBG.CFrame = CFrame.new(hrp.Position, hrp.Position + workspace.CurrentCamera.CFrame.LookVector)
    end)
end

local function flyOff()
    if not State.fly then return end
    State.fly = false
    for _, c in ipairs(Conns.fly) do c:Disconnect() end
    Conns.fly = {}
    if flyBV then flyBV:Destroy(); flyBV = nil end
    if flyBG then flyBG:Destroy(); flyBG = nil end
    if hum then
        hum.PlatformStand = false
        hum:ChangeState(Enum.HumanoidStateType.RunningNoPhysics)
        hum:Move(Vector3.new())
    end
end

-- ====== Sprint ======
local shiftHeld = false

local function applyWalkSpeed()
    if not hum then return end
    if State.sprint or shiftHeld then
        hum.WalkSpeed = State.speedSprint
    else
        hum.WalkSpeed = State.speedWalk
    end
end

local function sprintToggle()
    State.sprint = not State.sprint
    applyWalkSpeed()
end

-- ====== Input (teclado) ======
local function bindInputs()
    for _, c in ipairs(Conns.input) do c:Disconnect() end
    Conns.input = {}

    safeConnect(Conns.input, UIS.InputBegan, function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.T then
            if State.noclip then noclipOff() else noclipOn() end
        elseif input.KeyCode == Enum.KeyCode.F then
            if State.fly then flyOff() else flyOn() end
        elseif input.KeyCode == Enum.KeyCode.G then
            if State.invis then invisOff() else invisOn() end
        elseif input.KeyCode == Enum.KeyCode.LeftShift then
            shiftHeld = true
            applyWalkSpeed()
        elseif input.KeyCode == Enum.KeyCode.Space then
            moveKeys.Up = true
        elseif input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.C then
            moveKeys.Down = true
        elseif input.KeyCode == Enum.KeyCode.W then moveKeys.W = true
        elseif input.KeyCode == Enum.KeyCode.A then moveKeys.A = true
        elseif input.KeyCode == Enum.KeyCode.S then moveKeys.S = true
        elseif input.KeyCode == Enum.KeyCode.D then moveKeys.D = true
        end
    end)

    safeConnect(Conns.input, UIS.InputEnded, function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.LeftShift then
            shiftHeld = false
            applyWalkSpeed()
        elseif input.KeyCode == Enum.KeyCode.Space then
            moveKeys.Up = false
        elseif input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.C then
            moveKeys.Down = false
        elseif input.KeyCode == Enum.KeyCode.W then moveKeys.W = false
        elseif input.KeyCode == Enum.KeyCode.A then moveKeys.A = false
        elseif input.KeyCode == Enum.KeyCode.S then moveKeys.S = false
        elseif input.KeyCode == Enum.KeyCode.D then moveKeys.D = false
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
    frame.Size = UDim2.new(0, 240, 0, 210)
    frame.Position = UDim2.new(0.5, -120, 0.5, -105)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    frame.BorderSizePixel = 0
    frame.Parent = gui

    local uiPadding = Instance.new("UIPadding", frame)
    uiPadding.PaddingTop = UDim.new(0, 10)
    uiPadding.PaddingLeft = UDim.new(0, 10)
    uiPadding.PaddingRight = UDim.new(0, 10)
    uiPadding.PaddingBottom = UDim.new(0, 10)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 24)
    title.BackgroundTransparency = 1
    title.Text = "SuperPlayer Hub"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.Parent = frame

    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, 8)
    list.HorizontalAlignment = Enum.HorizontalAlignment.Center
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Parent = frame

    local function makeButton(text, callback)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -20, 0, 32)
        b.AutoButtonColor = true
        b.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.Font = Enum.Font.GothamSemibold
        b.TextSize = 14
        b.Text = text
        b.Parent = frame
        b.MouseButton1Click:Connect(function() callback(b) end)
        return b
    end

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -20, 0, 22)
    status.BackgroundTransparency = 1
    status.Text = "T/F: Fly | T: Noclip | G: Invis | Shift: Sprint"
    status.TextColor3 = Color3.fromRGB(180, 180, 180)
    status.Font = Enum.Font.Gotham
    status.TextSize = 12
    status.Parent = frame

    local btnNoclip = makeButton("Noclip: OFF", function(btn)
        if State.noclip then noclipOff() btn.Text = "Noclip: OFF"
        else noclipOn() btn.Text = "Noclip: ON" end
    end)

    local btnFly = makeButton("Fly: OFF", function(btn)
        if State.fly then flyOff() btn.Text = "Fly: OFF"
        else flyOn() btn.Text = "Fly: ON" end
    end)

    local btnSprint = makeButton("Sprint: OFF", function(btn)
        sprintToggle()
        btn.Text = State.sprint and "Sprint: ON" or "Sprint: OFF"
    end)

    local btnInvis = makeButton("Invisibilidad: OFF", function(btn)
        if State.invis then
            invisOff()
            btn.Text = "Invisibilidad: OFF"
        else
            invisOn()
            btn.Text = "Invisibilidad: ON"
        end
    end)

    local sliders = Instance.new("Frame")
    sliders.Size = UDim2.new(1, -20, 0, 70)
    sliders.BackgroundTransparency = 1
    sliders.Parent = frame

    local speedWalkLbl = Instance.new("TextLabel")
    speedWalkLbl.Size = UDim2.new(1, 0, 0, 18)
    speedWalkLbl.BackgroundTransparency = 1
    speedWalkLbl.Text = "WalkSpeed: "..State.speedWalk
    speedWalkLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    speedWalkLbl.Font = Enum.Font.Gotham
    speedWalkLbl.TextSize = 12
    speedWalkLbl.Parent = sliders

    local plusW = Instance.new("TextButton")
    plusW.Size = UDim2.new(0, 32, 0, 24)
    plusW.Position = UDim2.new(0, 0, 0, 20)
    plusW.Text = "+WS"
    plusW.BackgroundColor3 = Color3.fromRGB(45,45,45)
    plusW.TextColor3 = Color3.fromRGB(255,255,255)
    plusW.Parent = sliders
    plusW.MouseButton1Click:Connect(function()
        State.speedWalk = math.clamp(State.speedWalk + 2, 8, 200)
        speedWalkLbl.Text = "WalkSpeed: "..State.speedWalk
        applyWalkSpeed()
    end)

    local minusW = plusW:Clone()
    minusW.Text = "-WS"
    minusW.Position = UDim2.new(0, 36, 0, 20)
    minusW.Parent = sliders
    minusW.MouseButton1Click:Connect(function()
        State.speedWalk = math.clamp(State.speedWalk - 2, 8, 200)
        speedWalkLbl.Text = "WalkSpeed: "..State.speedWalk
        applyWalkSpeed()
    end)

    local speedSprintLbl = speedWalkLbl:Clone()
    speedSprintLbl.Position = UDim2.new(0, 0, 0, 48)
    speedSprintLbl.Text = "SprintSpeed: "..State.speedSprint
    speedSprintLbl.Parent = sliders

    local plusS = plusW:Clone()
    plusS.Text = "+SP"
    plusS.Position = UDim2.new(0, 80, 0, 20)
    plusS.Parent = sliders
    plusS.MouseButton1Click:Connect(function()
        State.speedSprint = math.clamp(State.speedSprint + 5, 16, 400)
        speedSprintLbl.Text = "SprintSpeed: "..State.speedSprint
        applyWalkSpeed()
    end)

    local minusS = minusW:Clone()
    minusS.Text = "-SP"
    minusS.Position = UDim2.new(0, 116, 0, 20)
    minusS.Parent = sliders
    minusS.MouseButton1Click:Connect(function()
        State.speedSprint = math.clamp(State.speedSprint - 5, 16, 400)
        speedSprintLbl.Text = "SprintSpeed: "..State.speedSprint
        applyWalkSpeed()
    end)

    -- Drag simple
    local dragging, dragStart, startPos = false, nil, nil
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
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

-- ====== Ciclo de vida del personaje ======
local function onCharacter(charNew)
    for _, c in ipairs(Conns.char) do c:Disconnect() end
    Conns.char = {}

    char, hum, hrp = getChar()
    applyWalkSpeed()

    -- Reaplicar estados al respawn
    if State.noclip then noclipOn() end
    if State.fly then flyOn() end
    if State.invis then
        -- Pequeño delay para que carguen todas las piezas/accesorios
        task.delay(0.25, function()
            if State.invis then invisOn() end
        end)
    end
end

-- Hooks de respawn
table.insert(Conns.char, player.CharacterAdded:Connect(onCharacter))

-- Init
bindInputs()
buildGUI()
applyWalkSpeed()

