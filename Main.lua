local mt = getrawmetatable(game)
setreadonly(mt, false)
local old_index = mt.__index
local old_namecall = mt.__namecall

mt.__index = newcclosure(function(self, key)
    print("[Index acceso]", self:GetFullName(), "→", key)
    return old_index(self, key)
end)

mt.__namecall = newcclosure(function(self, ...)
    local args = {...}
    local method = getnamecallmethod()
    print("[Namecall → " .. method .. "]", self:GetFullName(), unpack(args))
    return old_namecall(self, unpack(args))
end)
