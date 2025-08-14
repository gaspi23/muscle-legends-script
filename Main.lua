-- Ultra Minimal Hub (Tablet) — Infinito Daño + Aura Hit 360°
-- Luis x Copilot

-- Servicios
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local LP = Players.LocalPlayer
local function notify(t,d) pcall(function() StarterGui:SetCore("SendNotification",{Title="Ultra Hub",Text=t,Duration=d or 1.8}) end) end
local function clamp(v,a,b) return (v<a) and a or ((v>b) and b or v) end

-- Reusar GUI si existe
do
    local pg = LP:WaitForChild("PlayerGui")
    local existing = pg:FindFirstChild("UltraMinimalGUI")
    if existing then
        existing.Enabled = true
        local root = existing:FindFirstChild("Root")
        local reopen = existing:FindFirstChild("ReopenButton")
        if root then root.Visible = true end
        if reopen then reopen.Visible = false end
        return
    end
end

-- Estado con Aura Hit 360°
local ENV = getgenv and getgenv() or _G
ENV.UMH_STATE = ENV.UMH_STATE or {
    auraOn = false,
    auraRange = 300,
    auraWidth = 12,
    auraFOV = 180,
    auraFrontOnly = false, -- 360°
    auraDelay = 0.06,
    auraLOS = false,
    clickBurst = true,
    clickRange = 900,
    proxySize = 3,
    infDamage = false,
}
local S = ENV.UMH_STATE

-- Conexiones
local Conns = {char={}, aura={}, click={}}
local function disconnectAll(t) for _,c in ipairs(t) do pcall(function() c:Disconnect() end) end table.clear(t) end

-- Character helpers
local char, hum, hrp
local function getChar()
    local c = LP.Character or LP.CharacterAdded:Wait()
    return c, c:WaitForChild("Humanoid"), c:WaitForChild("HumanoidRootPart")
end
local function isAlive(h) return h and h.Health and h.Health > 0 end
local function dot(a,b) return a.X*b.X + a.Y*b.Y + a.Z*b.Z end
local function angle(a,b) local m=(a.Magnitude*b.Magnitude) if m==0 then return 180 end return math.deg(math.acos(math.clamp(dot(a,b)/m,-1,1))) end

-- Tool helpers
local function toolEquipped()
    if not char then return end
    for _,t in ipairs(char:GetChildren()) do
        if t:IsA("Tool") and t:FindFirstChild("Handle") then return t end
    end
end
local function equipAnyTool()
    if toolEquipped() then return true end
    local bp = LP:FindFirstChildOfClass("Backpack")
    if not bp then return false end
    for _,t in ipairs(bp:GetChildren()) do
        if t:IsA("Tool") and t:FindFirstChild("Handle") then t.Parent = char; return true end
    end
    return false
end
local function activateAnyTool(times)
    times = times or 1
    for _=1,times do
        for _,t in ipairs(char:GetChildren()) do
            if t:IsA("Tool") and t:FindFirstChild("Handle") then t:Activate() end
        end
    end
end

-- Proxy invisible
local proxy
local function ensureProxy()
    if proxy and proxy.Parent and proxy:IsA("BasePart") then return proxy end
    proxy = Instance.new("Part")
    proxy.Size = Vector3.new(S.proxySize, S.proxySize, S.proxySize)
    proxy.Transparency = 1
    proxy.CanCollide, proxy.CanQuery, proxy.CanTouch = false,false,true
    proxy.Massless = true
    proxy.Anchored = false
    proxy.Parent = char or LP.Character or LP.CharacterAdded:Wait()
    return proxy
end
local function fireTouch(a,b)
    if typeof(firetouchinterest) == "function" then
        pcall(firetouchinterest, a, b, 0)
        task.wait()
        pcall(firetouchinterest, a, b, 1)
    end
end
local function hitChar(targetChar, repeats)
    local h = targetChar and (targetChar:FindFirstChild("HumanoidRootPart") or targetChar:FindFirstChild("UpperTorso") or targetChar:FindFirstChild("Torso"))
    if not h then return end
    local p = ensureProxy()
    p.Size = Vector3.new(S.proxySize, S.proxySize, S.proxySize)
    p.CFrame = h.CFrame
    fireTouch(p, h)
    if S.infDamage then
        for i=1,(repeats or 6) do fireTouch(p, h) end
        activateAnyTool(3)
    end
end

-- Validar objetivo
local function canHit(hrp, look, other, range)
    local och = other.Character
    if not och then return false end
    local oh = och:FindFirstChildOfClass("Humanoid")
    local ohrp = och:FindFirstChild("HumanoidRootPart")
    if not oh or not ohrp or not isAlive(oh) then return false end
    local d = ohrp.Position - hrp.Position
    range = range or S.auraRange
    if not S.auraFrontOnly then
        if d.Magnitude > range then return false end
    else
        if angle(d, look) > (S.auraFOV/2) then return false end
        local f = dot(d, look.Unit)
        if f <= 0 or f > range then return false end
        local perp = d - look.Unit * f
        if perp.Magnitude > S.auraWidth then return false end
    end
    if S.auraLOS then
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Blacklist
        params.FilterDescendantsInstances = {char, och}
        local res = Workspace:Raycast(hrp.Position, ohrp.Position - hrp.Position, params)
        if res and not res.Instance:IsDescendantOf(och) then return false end
    end
    return true
end

-- Aura 360°
local lastHit = {}
local function startAura()
    disconnectAll(Conns.aura)
    if not S.auraOn then return end
    local acc = 0
    table.insert(Conns.aura, RunService.Heartbeat:Connect(function(dt)
        acc += dt
        if acc < S.auraDelay then return end
        acc = 0
        char, hum, hrp = getChar()
        if not isAlive(hum) then return end
        equipAnyTool()
        local cam = Workspace.CurrentCamera
        local look = (cam and cam.CFrame.LookVector) or hrp.CFrame.LookVector
        local now = os.clock()
        for _,pl in ipairs(Players:GetPlayers()) do
            if pl ~= LP and pl.Character then
                if canHit(hrp, look, pl, S.auraRange) then
                    local last = lastHit[pl] or 0
                    if now - last >= S.auraDelay*0.5 then
                        hitChar(pl.Character, S.infDamage and 10 or 1)
                        lastHit[pl] = now
                    end
                end
            end
        end
    end))
end

-- Click Burst
disconnectAll(Conns.click)
table.insert(Conns.click, UIS.InputBegan:Connect(function(i,gp)
    if gp then return end
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        char, hum, hrp = getChar()
        if not isAlive(hum) then return end
        equipAnyTool()
        local cam = Workspace.CurrentCamera
        local look = (cam and cam.CFrame.LookVector) or hrp.CFrame.LookVector
        for _,pl in ipairs(Players:GetPlayers()) do
            if pl ~= LP and pl.Character then
                if canHit(hrp, look, pl, S.clickRange) then
                    hitChar(pl.Character, S.infDamage and 16 or 2)
                end
            end
        end
    end
end))

-- GUI minimal
local function New(c,p,children) local o=Instance.new(c) for k,v in pairs(p or {}) do o[k]=v end if children then for _,ch in ipairs(children) do ch.Parent=o end end return o end
local Screen = New("ScreenGui",{Name="UltraMinimalGUI",ResetOnSpawn=false,IgnoreGuiInset=true,ZIndexBehavior=Enum.ZIndexBehavior.Global,DisplayOrder=999999})
Screen.Parent = LP:WaitForChild("PlayerGui")

local Root = New("Frame",{Name="Root",BackgroundColor3=Color3.fromRGB(
