local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

for _, player in pairs(Players:GetPlayers()) do
    if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        local distance = (LocalPlayer.Character.HumanoidRootPart.Position - player.Character.HumanoidRootPart.Position).Magnitude
        if distance <= 10 then
            local pushF = Instance.new("BodyVelocity")
            pushF.Name = "PushF"
            pushF.MaxForce = Vector3.new(1000000, 1000000, 1000000)
            pushF.Velocity = (LocalPlayer.Character.HumanoidRootPart.CFrame.lookVector) * 110
            pushF.Parent = player.Character.HumanoidRootPart
            wait(0.3)
            pushF:Destroy()
        end
    end
end
