local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

local DAMAGE = math.huge -- Daño infinito
local RANGE = 50 -- Rango extendido
local COOLDOWN = 0.3 -- por objetivo

local lastHit = {}

local function isEnemy(target)
    return target:IsA("Model") and target ~= Character and target:FindFirstChild("Humanoid")
end

local function applyDamage(target)
    local humanoid = target:FindFirstChild("Humanoid")
    if humanoid and humanoid.Health > 0 then
        local now = tick()
        if not lastHit[target] or now - lastHit[target] >= COOLDOWN then
            humanoid:TakeDamage(DAMAGE)
            lastHit[target] = now
        end
    end
end

RunService.RenderStepped:Connect(function()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and isEnemy(player.Character) then
            local targetHRP = player.Character:FindFirstChild("HumanoidRootPart")
            if targetHRP and (targetHRP.Position - HumanoidRootPart.Position).Magnitude <= RANGE then
                applyDamage(player.Character)
            end
        end
    end
end)
