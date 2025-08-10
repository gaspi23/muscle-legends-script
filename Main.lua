local button = script.Parent
local player = game.Players.LocalPlayer

local function applyPush()
    local character = player.Character or player.CharacterAdded:Wait()
    local rootPart = character:WaitForChild("HumanoidRootPart")

    local force = Instance.new("BodyVelocity")
    force.Velocity = rootPart.CFrame.LookVector * 150
    force.MaxForce = Vector3.new(50000, 0, 50000)
    force.P = 1250
    force.Parent = rootPart

    wait(0.5)
    force:Destroy()
end

button.MouseButton1Click:Connect(function()
    applyPush()
end)
