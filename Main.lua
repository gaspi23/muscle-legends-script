local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local muscleEvent = LocalPlayer.muscleEvent

-- Golpes automáticos cada 0.001 segundos
task.spawn(function()
    while true do
        muscleEvent:FireServer("punch", "rightHand", "leftHand")
        task.wait(0.001)
    end
end)

-- Función para eliminar a todos los jugadores (excepto tú)
local function eliminarTodos()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Humanoid") then
            player.Character:BreakJoints()
        end
    end
end

-- Botón para activar la función
local btn = Instance.new("TextButton")
btn.Size = UDim2.new(0, 200, 0, 50)
btn.Position = UDim2.new(0.5, -100, 0.9, -25)
btn.Text = "Matar a Todos"
btn.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
btn.TextColor3 = Color3.fromRGB(255, 255, 255)
btn.Parent = game.CoreGui

btn.MouseButton1Click:Connect(function()
    eliminarTodos()
end)
