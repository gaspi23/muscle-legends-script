local remote = game:GetService("ReplicatedStorage"):WaitForChild("guiDamageEvent")

while true do
    remote:FireServer("punchTrails", "handTrail", "leftHand")
    wait() -- 1 milisegundo (o lo más rápido que permita tu FPS)
end
