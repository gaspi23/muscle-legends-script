local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")

local force = Instance.new("BodyVelocity")
force.Velocity = Vector3.new(150, 0, 0) -- Empuje suave hacia la derecha
force.MaxForce = Vector3.new(50000, 0, 50000) -- Solo en X y Z
force.P = 1250
force.Parent = rootPart

wait(0.5)
force:Destroy()
