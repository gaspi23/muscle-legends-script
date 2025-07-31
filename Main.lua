local mt = getrawmetatable(game)
local namecall = mt.__namecall
local index = mt.__index
setreadonly(mt, false)

mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    if method == "FireServer" then
        print("[FireServer detectado] →", self:GetFullName(), ...)
    end
    return namecall(self, ...)
end)

mt.__index = newcclosure(function(self, key)
    return index(self, key) -- no imprime para no saturar
end)
