-- SuperPlayer Hub by Luis & Copilot 💥
local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hum = char:WaitForChild("Humanoid")
local hrp = char:WaitForChild("HumanoidRootPart")

-- UI Setup
local ScreenGui = Instance.new("ScreenGui", player:WaitForChild("PlayerGui"))
local Frame = Instance.new("Frame", ScreenGui)
Frame.Size = UDim2.new(0, 200, 0, 150)
Frame.Position = UDim2.new(0.5, -100, 0.5, -75)
Frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)

local function createButton(name, yPos, callback)
    local btn = Instance.new("TextButton", Frame)
    btn.Size = UDim2.new(0, 180, 0, 30)
    btn.Position = UDim2.new(0, 10, 0, yPos)
    btn.Text = name
    btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.MouseButton1Click:Connect(callback)
end

-- 🧱 Traspasar paredes
createButton("Traspasar Paredes", 10, function()
    for _, v in pairs(workspace:GetDescendants()) do
        if v:IsA("Part") and v.CanCollide == true then
            v.CanCollide = false
        end
    end
end)

-- 🦅 Volar
local flying = false
local bv, bg
createButton("Activar Vuelo", 50, function()
    flying = not flying
    if flying then
        bv = Instance.new("BodyVelocity", hrp)
        bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        bv.Velocity = Vector3.new(0, 0, 0)

        bg = Instance.new("BodyGyro", hrp)
        bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
        bg.CFrame = hrp.CFrame

        game:GetService("RunService").Heartbeat:Connect(function()
            if flying then
                bv.Velocity = player:GetMouse().Hit.lookVector * 50
                bg.CFrame = CFrame.new(hrp.Position, player:GetMouse().Hit.p)
            end
        end)
    else
        if bv then bv:Destroy() end
        if bg then bg:Destroy() end
    end
end)

-- 🏃‍♂️ Correr rápido
local sprinting = false
createButton("Sprint x5", 90, function()
    sprinting = not sprinting
    hum.WalkSpeed = sprinting and 80 or 16
end)
