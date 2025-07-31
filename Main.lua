for _,v in pairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
    if v:IsA("RemoteEvent") then
        v.OnClientEvent:Connect(function(...)
            print("📡 RemoteEvent:", v.Name, ...)
        end)
    elseif v:IsA("RemoteFunction") then
        v.OnClientInvoke = function(...)
            print("📡 RemoteFunction:", v.Name, ...)
        end
    end
end
