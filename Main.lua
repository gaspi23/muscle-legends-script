
-- Ultra Stealth Hub - Invis replicada (si hay Remote), Anti-restore nivel dios, Ghost, Noclip, Fly, Sprint, Auto-Stealth
-- Autor: Luis & Copilot

-- ===== Servicios =====
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local player = Players.LocalPlayer

-- ===== Util =====
local function getChar()
    local c = player.Character or player.CharacterAdded:Wait()
    return c, c:WaitForChild("Humanoid"), c:WaitForChild("HumanoidRootPart")
end

local function safeConnect(box, signal, fn)
    local c = signal:Connect(fn); table.insert(box, c); return c
end
local function disconnectAll(t) for _, c in ipairs(t) do pcall(function() c:Disconnect() end) end; table.clear(t) end

-- ===== Estado =====
local State = {
    noclip=false, fly=false, sprint=false,
    speedWalk=16, speedSprint=80, speedFly=60,
    invisRep=false, ghost=false, autoStealth=false,
    restoreHits=0, lastRestoreWindowStart=0
}
local Conns = {noclip={}, fly={}, input={}, char={}, invis={}, ghost={}, monitor={}}
local realChar, realHum, realHrp = getChar()
local ctrlChar, ctrlHum, ctrlHrp = realChar, realHum, realHrp

-- ===== Soporte de Remote (si el juego lo tiene) =====
local ServerInvis = {
    remote = nil, -- establece manualmente si sabes el remote exacto
    onArgs = {true}, offArgs = {false},
    found = {}
}

local function scanInvisRemotes()
    local hits = {}
    for _, inst in ipairs(game:GetDescendants()) do
        if inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") then
            local n = inst.Name:lower()
            if n:find("invis") or n:find("cloak") or n:find("stealth") or n:find("hide") or n:find("vanish") or n:find("ghost") or n:find("morph") then
                table.insert(hits, inst)
            end
        end
    end
    ServerInvis.found = hits
end

local function serverInvis(on)
    local ok = false
    if ServerInvis.remote then
        ok = pcall(function()
            if ServerInvis.remote:IsA("RemoteEvent") then
                ServerInvis.remote:FireServer(unpack(on and ServerInvis.onArgs or ServerInvis.offArgs))
            else
                ServerInvis.remote:InvokeServer(unpack(on and ServerInvis.onArgs or ServerInvis.offArgs))
            end
        end)
    else
        for _, r in ipairs(ServerInvis.found) do
            ok = pcall(function()
                if r:IsA("RemoteEvent") then r:FireServer(on) else r:InvokeServer(on) end
            end)
            if ok then ServerInvis.remote = r; break end
        end
    end
    return ok
end

-- ===== Apariencia y anti-restore =====
local Appearance = {
    partT = {}, decalT = {}, accT = {}, clothing = {}, highlightE = {}, beamE = {}, trailE = {}, particleE = {},
    castShadow = {}, billboardE = {}, faceDecalT = {}, humName = nil
}

local function hideServer(c)
    local h = c:FindFirstChildOfClass("Humanoid")
    for _, d in ipairs(c:GetDescendants()) do
        if d:IsA("BasePart") then
            if Appearance.partT[d] == nil then Appearance.partT[d] = d.Transparency end
            if Appearance.castShadow[d] == nil then Appearance.castShadow[d] = d.CastShadow end
            d.Transparency = 1
            d.Reflectance = 0
            d.CanCollide = (d.Name ~= "HumanoidRootPart") and d.CanCollide
            d.CastShadow = false
        elseif d:IsA("Decal") then
            if Appearance.decalT[d] == nil then Appearance.decalT[d] = d.Transparency end
            d.Transparency = 1
        elseif d:IsA("Accessory") then
            local handle = d:FindFirstChild("Handle")
            if handle then
                if Appearance.accT[handle] == nil then Appearance.accT[handle] = handle.Transparency end
                handle.Transparency = 1
                for _, dd in ipairs(handle:GetDescendants()) do
                    if dd:IsA("Decal") then
                        if Appearance.decalT[dd] == nil then Appearance.decalT[dd] = dd.Transparency end
                        dd.Transparency = 1
                    end
                end
            end
        elseif d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") then
            if Appearance.clothing[d] == nil then
                Appearance.clothing[d] = d:IsA("Shirt") and d.ShirtTemplate or d:IsA("Pants") and d.PantsTemplate or d.Graphic
            end
            if d:IsA("Shirt") then d.ShirtTemplate = "" end
            if d:IsA("Pants") then d.PantsTemplate = "" end
            if d:IsA("ShirtGraphic") then d.Graphic = "" end
        elseif d:IsA("Highlight") then
            if Appearance.highlightE[d] == nil then Appearance.highlightE[d] = d.Enabled end
            d.Enabled = false
        elseif d:IsA("Beam") then
            if Appearance.beamE[d] == nil then Appearance.beamE[d] = d.Enabled end
            d.Enabled = false
        elseif d:IsA("Trail") then
            if Appearance.trailE[d] == nil then Appearance.trailE[d] = d.Enabled end
            d.Enabled = false
        elseif d:IsA("ParticleEmitter") then
            if Appearance.particleE[d] == nil then Appearance.particleE[d] = d.Enabled end
            d.Enabled = false
        elseif d:IsA("BillboardGui") or d:IsA("SurfaceGui") then
            if Appearance.billboardE[d] == nil then Appearance.billboardE[d] = d.Enabled end
            d.Enabled = false
        end
    end
    -- Face decal directo
    local head = c:FindFirstChild("Head")
    if head then
        local face = head:FindFirstChildOfClass("Decal")
        if face then
            if Appearance.faceDecalT[face] == nil then Appearance.faceDecalT[face] = face.Transparency end
            face.Transparency = 1
        end
    end
    if h then
        if not Appearance.humName then
            Appearance.humName = { DisplayDistanceType = h.DisplayDistanceType, NameDisplayDistance = h.NameDisplayDistance }
        end
        pcall(function() h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end)
        pcall(function() h.NameDisplayDistance = 0 end)
    end
end

local function showServer(c)
    local h = c:FindFirstChildOfClass("Humanoid")
    for inst, t in pairs(Appearance.partT) do if inst and inst.Parent then inst.Transparency = t end end
    for inst, t in pairs(Appearance.decalT) do if inst and inst.Parent then inst.Transparency = t end end
    for inst, t in pairs(Appearance.accT) do if inst and inst.Parent then inst.Transparency = t end end
    for inst, v in pairs(Appearance.castShadow) do if inst and inst.Parent then inst.CastShadow = v end end
    for cloth, val in pairs(Appearance.clothing) do
        if cloth and cloth.Parent then
            if cloth:IsA("Shirt") then cloth.ShirtTemplate = val end
            if cloth:IsA("Pants") then cloth.PantsTemplate = val end
            if cloth:IsA("ShirtGraphic") then cloth.Graphic = val end
        end
    end
    for inst, e in pairs(Appearance.highlightE) do if inst and inst.Parent then inst.Enabled = e end end
    for inst, e in pairs(Appearance.beamE) do if inst and inst.Parent then inst.Enabled = e end end
    for inst, e in pairs(Appearance.trailE) do if inst and inst.Parent then inst.Enabled = e end end
    for inst, e in pairs(Appearance.particleE) do if inst and inst.Parent then inst.Enabled = e end end
    for inst, e in pairs(Appearance.billboardE) do if inst and inst.Parent then inst.Enabled = e end end
    for inst, t in pairs(Appearance.faceDecalT) do if inst and inst.Parent then inst.Transparency = t end end
    if h and Appearance.humName then
        pcall(function() h.DisplayDistanceType = Appearance.humName.DisplayDistanceType end)
        pcall(function() h.NameDisplayDistance  = Appearance.humName.NameDisplayDistance  end)
    end
end

local function monitorRestore(c)
    disconnectAll(Conns.monitor)
    local function flagRestore()
        local now = os.clock()
        if now - State.lastRestoreWindowStart > 2 then
            State.lastRestoreWindowStart = now
            State.restoreHits = 0
        end
        State.restoreHits += 1
        if State.autoStealth and State.restoreHits >= 3 and not State.ghost then
            -- escalada a ghost
            if State.invisRep then State.invisRep = false end
            pcall(function() hideServer(realChar) end)
            task.defer(function() game:GetService("StarterGui"):SetCore("SendNotification",{Title="Auto-Stealth",Text="Servidor revirtiendo. Cambiando a Ghost.",Duration=2}) end)
            -- activar ghost
            _G.__triggerGhostOn()
        end
    end

    safeConnect(Conns.monitor, c.DescendantAdded, function(d)
        task.defer(function()
            if State.invisRep then
                hideServer(c)
                flagRestore()
            end
        end)
    end)
    -- vigilar cambios críticos
    for _, d in ipairs(c:GetDescendants()) do
        if d:IsA("BasePart") or d:IsA("Decal") or d:IsA("Accessory") or d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") then
            safeConnect(Conns.monitor, d.Changed, function(prop)
                if not State.invisRep then return end
                if prop == "Transparency" or prop == "ShirtTemplate" or prop == "PantsTemplate" or prop == "Graphic" then
                    hideServer(c)
                    flagRestore()
                end
            end)
        end
    end
end

local function invisRepOn()
    if State.invisRep then return end
    State.invisRep = true
    -- Si hay Remote de servidor, primero intentar desde servidor
    local ok = serverInvis(true)
    hideServer(realChar)
    monitorRestore(realChar)
    safeConnect(Conns.invis, RunService.Heartbeat, function()
        if State.invisRep and realChar and realChar.Parent then hideServer(realChar) end
    end)
end

local function invisRepOff()
    if not State.invisRep then return end
    State.invisRep = false
    disconnectAll(Conns.invis); disconnectAll(Conns.monitor)
    pcall(showServer, realChar)
    pcall(serverInvis, false)
end

-- ===== Ghost =====
local ghostModel, camPrevSubj
local function makeGhost()
    local ok, model = pcall(function() return Players:CreateHumanoidModelFromUserId(player.UserId) end)
    if ok and model then return model end
    local clone = realChar:Clone()
    for _, d in ipairs(clone:GetDescendants()) do if d:IsA("Script") or d:IsA("LocalScript") then d:Destroy() end end
    return clone
end

local function ghostOn()
    if State.ghost then return end
    State.ghost = true
    ghostModel = makeGhost(); ghostModel.Name = "Ghost_"..player.Name; ghostModel.Parent = workspace
    local gHum = ghostModel:FindFirstChildOfClass("Humanoid") or Instance.new("Humanoid", ghostModel)
    local gRoot = ghostModel:WaitForChild("HumanoidRootPart")
    ghostModel:MoveTo(realHrp.Position + Vector3.new(0, 2, 0))
    camPrevSubj = workspace.CurrentCamera.CameraSubject; workspace.CurrentCamera.CameraSubject = gHum
    pcall(function()
        realHrp.Anchored = true; realHum.PlatformStand = true
        realHrp.CFrame = CFrame.new(0, -10000, 0)
        hideServer(realChar)
    end)
    ctrlChar, ctrlHum, ctrlHrp = ghostModel, gHum, gRoot
    safeConnect(Conns.ghost, RunService.Heartbeat, function()
        if not State.ghost then return end
        if realHrp and realHrp.Parent and realHrp.Position.Y > -9000 then
            realHrp.CFrame = CFrame.new(0, -10000, 0)
        end
    end)
end
_G.__triggerGhostOn = ghostOn

local function ghostOff()
    if not State.ghost then return end
    State.ghost = false
    disconnectAll(Conns.ghost)
    local backPos = (ctrlHrp and ctrlHrp.Position) or (realHrp.Position + Vector3.new(0,3,0))
    if ghostModel and ghostModel.Parent then ghostModel:Destroy() end
    pcall(function()
        realHrp.Anchored = false; realHum.PlatformStand = false
        realHrp.CFrame = CFrame.new(backPos + Vector3.new(0,2,0))
    end)
    if camPrevSubj then workspace.CurrentCamera.CameraSubject = camPrevSubj end
    ctrlChar, ctrlHum, ctrlHrp = realChar, realHum, realHrp
end

-- ===== Noclip =====
local function setNoCollide(model, on) for _, v in ipairs(model:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide = not on end end end
local function noclipOn() if State.noclip then return end State.noclip=true; setNoCollide(ctrlChar,true); safeConnect(Conns.noclip, RunService.Stepped, function() if State.noclip and ctrlChar and ctrlChar.Parent then setNoCollide(ctrlChar,true) end end) end
local function noclipOff() if not State.noclip then return end State.noclip=false; disconnectAll(Conns.noclip); setNoCollide(ctrlChar,false) end

-- ===== Fly =====
local flyBV, flyBG; local moveKeys={W=false,A=false,S=false,D=false,Up=false,Down=false}
local function computeFlyVelocity()
    local cam = workspace.CurrentCamera
    local dir = Vector3.new()
    local cf = cam.CFrame
    if moveKeys.W then dir += cf.LookVector end
    if moveKeys.S then dir -= cf.LookVector end
    if moveKeys.A then dir -= cf.RightVector end
    if moveKeys.D then dir += cf.RightVector end
    if moveKeys.Up then dir += Vector3.new(0,1,0) end
    if moveKeys.Down then dir += Vector3.new(0,-1,0) end
    return (dir.Magnitude>0) and dir.Unit*State.speedFly or Vector3.new()
end
local function flyOn()
    if State.fly then return end
    State.fly=true
    flyBV=Instance.new("BodyVelocity"); flyBV.MaxForce=Vector3.new(1e6,1e6,1e6); flyBV.P=1e4; flyBV.Parent=ctrlHrp
    flyBG=Instance.new("BodyGyro"); flyBG.MaxTorque=Vector3.new(1e6,1e6,1e6); flyBG.P=3e4; flyBG.CFrame=ctrlHrp.CFrame; flyBG.Parent=ctrlHrp
    ctrlHum.PlatformStand=true
    safeConnect(Conns.fly, RunService.Heartbeat, function()
        if not State.fly or not ctrlHrp or not ctrlHum then return end
        if flyBV.Parent~=ctrlHrp then flyBV.Parent=ctrlHrp end
        if flyBG.Parent~=ctrlHrp then flyBG.Parent=ctrlHrp end
        flyBV.Velocity=computeFlyVelocity()
        flyBG.CFrame=CFrame.new(ctrlHrp.Position, ctrlHrp.Position + workspace.CurrentCamera.CFrame.LookVector)
    end)
end
local function flyOff()
    if not State.fly then return end
    State.fly=false; disconnectAll(Conns.fly)
    if flyBV then flyBV:Destroy() flyBV=nil end
    if flyBG then flyBG:Destroy() flyBG=nil end
    if ctrlHum then ctrlHum.PlatformStand=false; ctrlHum:Move(Vector3.new()) end
end

-- ===== Sprint =====
local shiftHeld=false
local function applyWalkSpeed() if ctrlHum then ctrlHum.WalkSpeed = (State.sprint or shiftHeld) and State.speedSprint or State.speedWalk end end
local function sprintToggle() State.sprint=not State.sprint; applyWalkSpeed() end

-- ===== Input =====
local function bindInputs()
    disconnectAll(Conns.input)
    safeConnect(Conns.input, UIS.InputBegan, function(i,gp)
        if gp then return end
        local k=i.KeyCode
        if k==Enum.KeyCode.T then if State.noclip then noclipOff() else noclipOn() end
        elseif k==Enum.KeyCode.F then if State.fly then flyOff() else flyOn() end
        elseif k==Enum.KeyCode.G then if State.invisRep then invisRepOff() else invisRepOn() end
        elseif k==Enum.KeyCode.H then if State.ghost then ghostOff() else ghostOn() end
        elseif k==Enum.KeyCode.LeftShift then shiftHeld=true; applyWalkSpeed()
        elseif k==Enum.KeyCode.Space then moveKeys.Up=true
        elseif k==Enum.KeyCode.LeftControl or k==Enum.KeyCode.C then moveKeys.Down=true
        elseif k==Enum.KeyCode.W then moveKeys.W=true
        elseif k==Enum.KeyCode.A then moveKeys.A=true
        elseif k==Enum.KeyCode.S then moveKeys.S=true
        elseif k==Enum.KeyCode.D then moveKeys.D=true end
    end)
    safeConnect(Conns.input, UIS.InputEnded, function(i,gp)
        if gp then return end
        local k=i.KeyCode
        if k==Enum.KeyCode.LeftShift then shiftHeld=false; applyWalkSpeed()
        elseif k==Enum.KeyCode.Space then moveKeys.Up=false
        elseif k==Enum.KeyCode.LeftControl or k==Enum.KeyCode.C then moveKeys.Down=false
        elseif k==Enum.KeyCode.W then moveKeys.W=false
        elseif k==Enum.KeyCode.A then moveKeys.A=false
        elseif k==Enum.KeyCode.S then moveKeys.S=false
        elseif k==Enum.KeyCode.D then moveKeys.D=false end
    end)
end

-- ===== GUI =====
local function buildGUI()
    local gui=Instance.new("ScreenGui"); gui.Name="UltraStealthHub"; gui.ResetOnSpawn=false; gui.Parent=player:WaitForChild("PlayerGui")
    local frame=Instance.new("Frame"); frame.Size=UDim2.new(0,280,0,300); frame.Position=UDim2.new(0.5,-140,0.5,-150)
    frame.BackgroundColor3=Color3.fromRGB(20,20,20); frame.BorderSizePixel=0; frame.Parent=gui
    local pad=Instance.new("UIPadding",frame); pad.PaddingTop=UDim.new(0,10); pad.PaddingLeft=UDim.new(0,10); pad.PaddingRight=UDim.new(0,10); pad.PaddingBottom=UDim.new(0,10)
    local title=Instance.new("TextLabel"); title.Size=UDim2.new(1,0,0,24); title.BackgroundTransparency=1; title.Text="Ultra Stealth Hub"
    title.TextColor3=Color3.new(1,1,1); title.Font=Enum.Font.GothamBold; title.TextSize=18; title.Parent=frame
    local list=Instance.new("UIListLayout"); list.Padding=UDim.new(0,8); list.HorizontalAlignment=Enum.HorizontalAlignment.Center; list.Parent=frame
    local info=Instance.new("TextLabel"); info.Size=UDim2.new(1,-20,0,22); info.BackgroundTransparency=1
    info.Text="T Noclip | F Fly | G Invis | H Ghost | Shift Sprint"; info.TextColor3=Color3.fromRGB(180,180,180); info.Font=Enum.Font.Gotham; info.TextSize=12; info.Parent=frame
    local function btn(text, cb)
        local b=Instance.new("TextButton"); b.Size=UDim2.new(1,-20,0,32); b.BackgroundColor3=Color3.fromRGB(40,40,40)
        b.TextColor3=Color3.new(1,1,1); b.Font=Enum.Font.GothamSemibold; b.TextSize=14; b.Text=text; b.Parent=frame
        b.MouseButton1Click:Connect(function() cb(b) end); return b
    end
    local bNoclip=btn("Noclip: OFF", function(b) if State.noclip then noclipOff(); b.Text="Noclip: OFF" else noclipOn(); b.Text="Noclip: ON" end end)
    local bFly=btn("Fly: OFF", function(b) if State.fly then flyOff(); b.Text="Fly: OFF" else flyOn(); b.Text="Fly: ON" end end)
    local bSprint=btn("Sprint: OFF", function(b) sprintToggle(); b.Text=State.sprint and "Sprint: ON" or "Sprint: OFF" end)
    local bInvis=btn("Invis Rep: OFF", function(b) if State.invisRep then invisRepOff(); b.Text="Invis Rep: OFF" else invisRepOn(); b.Text="Invis Rep: ON" end end)
    local bGhost=btn("Ghost: OFF", function(b)
        if State.ghost then ghostOff(); b.Text="Ghost: OFF"
        else if State.invisRep then invisRepOff() end; ghostOn(); b.Text="Ghost: ON" end
    end)
    local bAuto=btn("Auto-Stealth: OFF", function(b)
        State.autoStealth = not State.autoStealth
        b.Text = State.autoStealth and "Auto-Stealth: ON" or "Auto-Stealth: OFF"
    end)
    local bScan=btn("Scan Remotes", function(b)
        scanInvisRemotes()
        b.Text = (#ServerInvis.found>0) and ("Found: "..#ServerInvis.found) or "None found"
    end)
    -- Drag
    local dragging, dragStart, startPos=false,nil,nil
    frame.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=true; dragStart=i.Position; startPos=frame.Position
        i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then dragging=false end end) end end)
    frame.InputChanged:Connect(function(i) if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
        local d=i.Position-dragStart; frame.Position=UDim2.new(startPos.X.Scale, startPos.X.Offset+d.X, startPos.Y.Scale, startPos.Y.Offset+d.Y) end end)
end

-- ===== Ciclo de vida =====
local function rebindControlToReal()
    ctrlChar, ctrlHum, ctrlHrp = realChar, realHum, realHrp
    applyWalkSpeed()
    if State.noclip then noclipOn() end
    if State.fly then flyOn() end
end
local function onCharacterAdded()
    disconnectAll(Conns.char)
    realChar, realHum, realHrp = getChar()
    if State.invisRep then task.defer(invisRepOn) end
    if State.ghost then task.delay(0.25, function() if State.ghost then ghostOn() end end) end
    if not State.ghost then rebindControlToReal() end
end
table.insert(Conns.char, player.CharacterAdded:Connect(onCharacterAdded))

-- ===== Init =====
bindInputs()
buildGUI()
applyWalkSpeed()
scanInvisRemotes()

    
