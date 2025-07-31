for _, v in pairs(game:GetDescendants()) do
    if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
        print("Encontrado:", v:GetFullName(), "→", v.ClassName)
    end
end

print("✅ Escaneo completo. Revisa la consola de Delta para ver los eventos disponibles.")
