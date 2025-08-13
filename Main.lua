-- SuperPlayer Hub - Noclip + Fly + Sprint (GUI + Keybinds)
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

local moveKeys = {
    W=false, A=false, S=false, D=false, Up=false, Down=false
}

local function computeFlyVelocity()
    local cam = workspace.CurrentCamera
    local dir = Vector3.new()
    -- Usa MoveDirection para móvil/joystick; teclado con WASD
    local moveDir = hum and hum.MoveDirection or Vector3.new()
    if moveDir.Magnitude > 0 then
        -- Proyecta a la orientación de la cámara
        local cf = cam.CFrame
        local forward = cf.LookVector
        local right = cf.RightVector
        -- Descompone moveDir en plano XZ de la cámara
        local planar = (forward * moveDir.Z + right * moveDir.X)
        dir = dir + Vector3.new(planar.X, 0, planar.Z)
    else
        -- Teclado puro
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
    frame.Size = UDim2.new(0, 220, 0, 180)
    frame.Position = UDim2.new(0.5, -110, 0.5, -90)
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

    local function updateBtn(btn, on)
        btn.Text = (on and "ON  - " or "OFF - ") .. btn.Name
        btn.BackgroundColor3 = on and Color3.fromRGB(30, 120, 60) or Color3.fromRGB(60, 30, 30)
    end

    local btnNoclip = makeButton("OFF - Noclip (T)", function(btn)
        if State.noclip then noclipOff() else noclipOn() end
        updateBtn(btn, State.noclip)
    end)
    btnNoclip.Name = "Noclip (T)"
    updateBtn(btnNoclip, State.noclip)

    local btnFly = makeButton("OFF - Fly (F)", function(btn)
        if State.fly then flyOff() else flyOn() end
        updateBtn(btn, State.fly)
    end)
    btnFly.Name = "Fly (F)"
    updateBtn(btnFly, State.fly)

    local btnSprint = makeButton("OFF - Sprint (Shift)", function(btn)
        sprintToggle()
        updateBtn(btn, State.sprint)
    end)
    btnSprint.Name = "Sprint (Shift)"
    updateBtn(btnSprint, State.sprint)

    -- Simple drag
    local dragging = false
    local dragStart, startPos
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- ====== Respawn handling ======
local function bindCharacter()
    for _, c in ipairs(Conns.char) do c:Disconnect() end
    Conns.char = {}

    safeConnect(Conns.char, player.CharacterAdded, function(newChar)
        char = newChar
        hum = newChar:WaitForChild("Humanoid")
        hrp = newChar:WaitForChild("HumanoidRootPart")
        -- Reaplica estados
        if State.noclip then
            noclipOff(); noclipOn()
        end
        if State.fly then
            flyOff(); flyOn()
        end
        applyWalkSpeed()
    end)
end

-- ====== Init ======
bindInputs()
buildGUI()
bindCharacter()
applyWalkSpeed()

-- Opcional: activar por defecto (false = desactivado al iniciar)
-- noclipOn()
-- flyOn()
-- sprintToggle()
