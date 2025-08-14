-- LocalScript (StarterPlayerScripts)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LOCAL = Players.LocalPlayer
local RANGE = 50
local COOLDOWN = 0.3 -- por objetivo
local REMOTE_NAME = "AuraHitRemote"

-- Espera el RemoteEvent
local Remote = ReplicatedStorage:WaitForChild(REMOTE_NAME, 5)
if not Remote then
    warn(("No se encontró RemoteEvent '%s' en ReplicatedStorage"):format(REMOTE_NAME))
end

-- Estado
local enabled = false
local lastHit = {} -- [userId] = tick()
local character, hrp

local function bindCharacter(char)
    character = char
    hrp = nil
    task.spawn(function()
        hrp = character:WaitForChild("HumanoidRootPart", 5)
    end)
end

if LOCAL.Character then bindCharacter(LOCAL.Character) end
LOCAL.CharacterAdded:Connect(bindCharacter)

-- Crear GUI táctil
local function makeGui()
    local pg = LOCAL:WaitForChild("PlayerGui")

    local gui = Instance.new("ScreenGui")
    gui.Name = "AuraUI"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.IgnoreGuiInset = true
    gui.Parent = pg

    local btn = Instance.new("TextButton")
    btn.Name = "ToggleAura"
    btn.AnchorPoint = Vector2.new(1,1)
    btn.Position = UDim2.fromScale(0.98, 0.95)
    btn.Size = UDim2.fromOffset(140, 140)
    btn.AutoButtonColor = true
    btn.TextScaled = true
    btn.Font = Enum.Font.GothamBold
    btn.Text = "Aura: OFF"
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Parent = gui

    -- Mejor tacto: radio/estética
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0,18); corner.Parent = btn
    local stroke = Instance.new("UIStroke"); stroke.Thickness = 2; stroke.Color = Color3.fromRGB(255,255,255); stroke.Transparency = 0.3; stroke.Parent = btn
    local aspect = Instance.new("UIAspectRatioConstraint"); aspect.AspectRatio = 1; aspect.Parent = btn

    -- Mostrar solo si hay touch (tablets/phones); si quieres siempre visible, comenta este bloque
    if UserInputService.TouchEnabled then
        gui.Enabled = true
    else
        gui.Enabled = true -- también útil en PC; cámbialo a false si quieres exclusivo touch
    end

    local function refreshVisual()
        if enabled then
            btn.Text = "Aura: ON"
            btn.BackgroundColor3 = Color3.fromRGB(30, 150, 80)
        else
            btn.Text = "Aura: OFF"
            btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        end
    end
    refreshVisual()

    btn.Activated:Connect(function()
        enabled = not enabled
        refreshVisual()
    end)
end

makeGui()

-- Bucle del Aura: reúne objetivos y pide al servidor que aplique daño
RunService.Heartbeat:Connect(function()
    if not enabled or not Remote then return end
    if not character or not hrp then return end

    local now = tick()
    local targetsToHit = {}

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LOCAL then
            local c = plr.Character
            if c then
                local th = c:FindFirstChild("Humanoid")
                local thrp = c:FindFirstChild("HumanoidRootPart")
                if th and th.Health > 0 and thrp then
                    local dist = (thrp.Position - hrp.Position).Magnitude
                    if dist <= RANGE then
                        local uid = plr.UserId
                        local last = lastHit[uid]
                        if (not last) or (now - last >= COOLDOWN) then
                            table.insert(targetsToHit, uid)
                            lastHit[uid] = now
                        end
                    end
                end
            end
        end
    end

    if #targetsToHit > 0 then
        -- Enviar lote al servidor para validación y daño
        Remote:FireServer(targetsToHit, RANGE)
    end
end)
