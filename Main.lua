-- Ultra Stealth Hub (Vanguard) - by Luis & Copilot
-- Todo lo de Ultimate + CollisionGroup No-Hit, Anti-Teleport-Back, Teleport seguro (Path/Raycast), Perfiles por juego, Command Palette

-- ===== Services =====
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local PathfindingService = game:GetService("PathfindingService")
local PhysicsService = game:GetService("PhysicsService")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer

-- ===== Helpers =====
local function safe(f, ...) local ok, r = pcall(f, ...); return ok, r end
local function notify(t, d) safe(function() StarterGui:SetCore("SendNotification",{Title="Ultra Stealth",Text=t,Duration=d or 2}) end) end
local function clamp(v, lo, hi) if v<lo then return lo elseif v>hi then return hi else return v end end
local function now() return os.clock() end

local function getChar()
    local c = player.Character or player.CharacterAdded:Wait()
    return c, c:WaitForChild("Humanoid"), c:WaitForChild("HumanoidRootPart")
end
local function safeConnect(box, signal, fn)
    local c = signal:Connect(fn); table.insert(box, c); return c
end
local function disconnectAll(t) for _, c in ipairs(t) do safe(function() c:Disconnect() end) end; table.clear(t) end

-- ===== Persistencia (global y por juego) =====
local function hasFS()
    return (typeof(isfile)=="function" and typeof(writefile)=="function" and typeof(readfile)=="function" and typeof(makefolder)=="function")
end
local gameId = tostring(game.PlaceId or game.GameId or "global")
local baseCfg = {
    speedWalk=16, stepWalk=2, minWalk=8,  maxWalk=300,
    speedSprint=80, stepSprint=5, minSprint=16, maxSprint=800,
    speedFly=60, stepFly=10, minFly=10, maxFly=1200,
    flyEngine="Body", -- "Body" / "Align"
    dmgGuard = { antiStun=true, antiHazard=true, dodge=true, noHitBubble=true, autoGhostOnHit=true, antiVoid=true, dodgeRadius=14, dodgeSide=10, hitDrop=20, ghostSeconds=3 },
    hazardNames={"kill","lava","void","dead","toxic","acid","die","damage"},
    tpMode="Blink", tpTweenSpeed=80, tpBlinkStep=18, tpBlinkDelay=0.02, tpSafe=true,
    uiVisible=true,
    antiTeleportBack = { enabled=true, threshold=35, action="ghost" }, -- "revert"|"ghost"|"mark"
    perGame=true
}
getgenv().UltraStealthCfg = getgenv().UltraStealthCfg or {}
local CFG = getgenv().UltraStealthCfg

local function deepCopy(t) local n={} for k,v in pairs(t) do n[k]=type(v)=="table" and deepCopy(v) or v end return n end
local function merge(dst, src) for k,v in pairs(src) do if type(v)=="table" then dst[k]=dst[k] or {}; merge(dst[k],v) else if dst[k]==nil then dst[k]=v end end end return dst end

-- load per-game
local function cfgPath() return "UltraStealth/"..gameId..".json" end
if not CFG.__inited then
    merge(CFG, deepCopy(baseCfg))
    if hasFS() then
        if not isfolder("UltraStealth") then safe(makefolder, "UltraStealth") end
        if isfile(cfgPath()) then
            local ok, js = safe(readfile, cfgPath())
            if ok then local ok2, tbl = pcall(function() return HttpService:JSONDecode(js) end)
                if ok2 and type(tbl)=="table" then merge(CFG, tbl) end
            end
        end
    end
    CFG.__inited=true
end
local function saveCfg()
    if not hasFS() or CFG.perGame==false then return end
    local ok, js = pcall(function() return HttpService:JSONEncode(CFG) end)
    if ok then safe(writefile, cfgPath(), js) end
end

-- ===== Estado =====
local State = {
    noclip=false, fly=false, sprint=false, invisRep=false, ghost=false, autoStealth=false,
    restoreHits=0, lastRestoreWindowStart=0, lastHealth=nil, safePos=nil,
    userMoveTick=0, lastCFrame= nil
}
local Conns = {noclip={}, fly={}, input={}, char={}, invis={}, ghost={}, monitor={}, meta={}, ui={}, guard={}, tp={}, antiTP={}}
local realChar, realHum, realHrp = getChar()
local ctrlChar, ctrlHum, ctrlHrp = realChar, realHum, realHrp

-- ===== Collision Group (No-Hit Bubble) =====
local CG = { group="USH_Ghost", ready=false }
local function ensureGroup()
    if CG.ready then return true end
    local ok = true
    safe(function()
        local groups = PhysicsService:GetCollisionGroups()
        local exists=false
        for _,g in ipairs(groups) do if g.name == CG.group then exists=true end end
        if not exists then PhysicsService:CreateCollisionGroup(CG.group) end
        PhysicsService:CollisionGroupSetCollidable(CG.group, "Default", false)
        PhysicsService:CollisionGroupSetCollidable(CG.group, CG.group, false)
    end)
    CG.ready = ok
    return ok
end
local function setGroup(model, group)
    for _, v in ipairs(model:GetDescendants()) do
        if v:IsA("BasePart") then safe(function() PhysicsService:SetPartCollisionGroup(v, group) end) end
    end
end

-- ===== Server invis (heurística) =====
local ServerInvis = { remote=nil, onArgs={true}, offArgs={false}, found={} }
local function scanInvisRemotes()
    local hits={}
    for _, inst in ipairs(game:GetDescendants()) do
        if inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") then
            local n=inst.Name:lower()
            if n:find("invis") or n:find("cloak") or n:find("stealth") or n:find("hide") or n:find("vanish") or n:find("ghost") or n:find("morph") then
                table.insert(hits, inst)
            end
        end
    end
    ServerInvis.found = hits
end
local function serverInvis(on)
    local ok=false
    if ServerInvis.remote then
        ok = safe(function()
            if ServerInvis.remote:IsA("RemoteEvent") then
                ServerInvis.remote:FireServer(unpack(on and ServerInvis.onArgs or ServerInvis.offArgs))
            else
                ServerInvis.remote:InvokeServer(unpack(on and ServerInvis.onArgs or ServerInvis.offArgs))
            end
        end)
    else
        for _, r in ipairs(ServerInvis.found) do
            ok = safe(function()
                if r:IsA("RemoteEvent") then r:FireServer(on) else r:InvokeServer(on) end
            end)
            if ok then ServerInvis.remote=r; break end
        end
    end
    return ok
end

-- ===== Apariencia & Anti-restore (igual que Ultimate, robustecido) =====
local Appearance = {
    partT={}, decalT={}, accT={}, clothing={}, castShadow={}, faceDecalT={},
    highlightE={}, beamE={}, trailE={}, particleE={}, billboardE={}, humName=nil
}
local function hideServer(c)
    local h = c:FindFirstChildOfClass("Humanoid")
    for _, d in ipairs(c:GetDescendants()) do
        if d:IsA("BasePart") then
            if Appearance.partT[d]==nil then Appearance.partT[d]=d.Transparency end
            if Appearance.castShadow[d]==nil then Appearance.castShadow[d]=d.CastShadow end
            d.Transparency=1; d.Reflectance=0; d.CastShadow=false
        elseif d:IsA("Decal") then if Appearance.decalT[d]==nil then Appearance.decalT[d]=d.Transparency end; d.Transparency=1
        elseif d:IsA("Accessory") then
            local handle=d:FindFirstChild("Handle")
            if handle then
                if Appearance.accT[handle]==nil then Appearance.accT[handle]=handle.Transparency end
                handle.Transparency=1
                for _, dd in ipairs(handle:GetDescendants()) do
                    if dd:IsA("Decal") then if Appearance.decalT[dd]==nil then Appearance.decalT[dd]=dd.Transparency end; dd.Transparency=1 end
                end
            end
        elseif d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") then
            if Appearance.clothing[d]==nil then Appearance.clothing[d] = d:IsA("Shirt") and d.ShirtTemplate or d:IsA("Pants") and d.PantsTemplate or d.Graphic end
            if d:IsA("Shirt") then d.ShirtTemplate="" end
            if d:IsA("Pants") then d.PantsTemplate="" end
            if d:IsA("ShirtGraphic") then d.Graphic="" end
        elseif d:IsA("Highlight") then if Appearance.highlightE[d]==nil then Appearance.highlightE[d]=d.Enabled end; d.Enabled=false
        elseif d:IsA("Beam") then if Appearance.beamE[d]==nil then Appearance.beamE[d]=d.Enabled end; d.Enabled=false
        elseif d:IsA("Trail") then if Appearance.trailE[d]==nil then Appearance.trailE[d]=d.Enabled end; d.Enabled=false
        elseif d:IsA("ParticleEmitter") then if Appearance.particleE[d]==nil then Appearance.particleE[d]=d.Enabled end; d.Enabled=false
        elseif d:IsA("BillboardGui") or d:IsA("SurfaceGui") then if Appearance.billboardE[d]==nil then Appearance.billboardE[d]=d.Enabled end; d.Enabled=false
        end
    end
    local head=c:FindFirstChild("Head")
    if head then local face=head:FindFirstChildOfClass("Decal"); if face then if Appearance.faceDecalT[face]==nil then Appearance.faceDecalT[face]=face.Transparency end; face.Transparency=1 end end
    if h then
        if not Appearance.humName then Appearance.humName = { DisplayDistanceType=h.DisplayDistanceType, NameDisplayDistance=h.NameDisplayDistance } end
        safe(function() h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end)
        safe(function() h.NameDisplayDistance = 0 end)
    end
end
local function showServer(c)
    local h=c:FindFirstChildOfClass("Humanoid")
    for inst,t in pairs(Appearance.partT) do if inst and inst.Parent then inst.Transparency=t end end
    for inst,t in pairs(Appearance.decalT) do if inst and inst.Parent then inst.Transparency=t end end
    for inst,t in pairs(Appearance.accT) do if inst and inst.Parent then inst.Transparency=t end end
    for inst,v in pairs(Appearance.castShadow) do if inst and inst.Parent then inst.CastShadow=v end end
    for cloth,val in pairs(Appearance.clothing) do
        if cloth and cloth.Parent then
            if cloth:IsA("Shirt") then cloth.ShirtTemplate=val end
            if cloth:IsA("Pants") then cloth.PantsTemplate=val end
            if cloth:IsA("ShirtGraphic") then cloth.Graphic=val end
        end
    end
    for inst,e in pairs(Appearance.highlightE) do if inst and inst.Parent then inst.Enabled=e end end
    for inst,e in pairs(Appearance.beamE) do if inst and inst.Parent then inst.Enabled=e end end
    for inst,e in pairs(Appearance.trailE) do if inst and inst.Parent then inst.Enabled=e end end
    for inst,e in pairs(Appearance.particleE) do if inst and inst.Parent then inst.Enabled=e end end
    for inst,e in pairs(Appearance.billboardE) do if inst and inst.Parent then inst.Enabled=e end end
    for inst,t in pairs(Appearance.faceDecalT) do if inst and inst.Parent then inst.Transparency=t end end
    if h and Appearance.humName then
        safe(function() h.DisplayDistanceType = Appearance.humName.DisplayDistanceType end)
        safe(function() h.NameDisplayDistance = Appearance.humName.NameDisplayDistance end)
    end
end

local function monitorRestore(c)
    disconnectAll(Conns.monitor)
    local function flagRestore()
        local t=now()
        if t - State.lastRestoreWindowStart > 2 then State.lastRestoreWindowStart=t; State.restoreHits=0 end
        State.restoreHits += 1
        if State.autoStealth and State.restoreHits >= 3 and not State.ghost then
            if State.invisRep then State.invisRep=false end
            safe(hideServer, realChar)
            task.defer(function() notify("Servidor revirtiendo. Cambiando a Ghost.", 2) end)
            _G.__triggerGhostOn()
        end
    end
    safeConnect(Conns.monitor, c.DescendantAdded, function()
        if State.invisRep then task.defer(function() hideServer(c); flagRestore() end) end
    end)
    for _, d in ipairs(c:GetDescendants()) do
        if d:IsA("BasePart") or d:IsA("Decal") or d:IsA("Accessory") or d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") then
            safeConnect(Conns.monitor, d.Changed, function(prop)
                if not State.invisRep then return end
                if prop=="Transparency" or prop=="ShirtTemplate" or prop=="PantsTemplate" or prop=="Graphic" then
                    hideServer(c); flagRestore()
                end
            end)
        end
    end
end

local function invisRepOn()
    if State.invisRep then return end
    State.invisRep=true
    serverInvis(true)
    hideServer(realChar)
    monitorRestore(realChar)
    safeConnect(Conns.invis, RunService.Heartbeat, function()
        if State.invisRep and realChar and realChar.Parent then hideServer(realChar) end
    end)
end
local function invisRepOff()
    if not State.invisRep then return end
    State.invisRep=false
    disconnectAll(Conns.invis); disconnectAll(Conns.monitor)
    safe(showServer, realChar)
    serverInvis(false)
end

-- ===== Ghost =====
local ghostModel, camPrevSubj
local function makeGhost()
    local ok, model = safe(function() return Players:CreateHumanoidModelFromUserId(player.UserId) end)
    if ok and model then return model end
    local clone = realChar:Clone()
    for _, d in ipairs(clone:GetDescendants()) do if d:IsA("Script") or d:IsA("LocalScript") then d:Destroy() end end
    return clone
end
local function ghostOn()
    if State.ghost then return end
    State.ghost=true
    ghostModel = makeGhost(); ghostModel.Name="Ghost_"..player.Name; ghostModel.Parent = workspace
    local gHum = ghostModel:FindFirstChildOfClass("Humanoid") or Instance.new("Humanoid", ghostModel)
    local gRoot = ghostModel:WaitForChild("HumanoidRootPart")
    ghostModel:MoveTo(realHrp.Position + Vector3.new(0,2,0))
    camPrevSubj = workspace.CurrentCamera.CameraSubject; workspace.CurrentCamera.CameraSubject = gHum
    safe(function()
        realHrp.Anchored=true; realHum.PlatformStand=true
        realHrp.CFrame = CFrame.new(0,-10000,0)
        hideServer(realChar)
    end)
    ctrlChar, ctrlHum, ctrlHrp = ghostModel, gHum, gRoot
    safeConnect(Conns.ghost, RunService.Heartbeat, function()
        if not State.ghost then return end
        if realHrp and realHrp.Parent and realHrp.Position.Y > -9000 then
            realHrp.CFrame = CFrame.new(0,-10000,0)
        end
    end)
end
_G.__triggerGhostOn = ghostOn
local function ghostOff()
    if not State.ghost then return end
    State.ghost=false
    disconnectAll(Conns.ghost)
    local backPos = (ctrlHrp and ctrlHrp.Position) or (realHrp.Position + Vector3.new(0,3,0))
    if ghostModel and ghostModel.Parent then ghostModel:Destroy() end
    safe(function()
        realHrp.Anchored=false; realHum.PlatformStand=false
        realHrp.CFrame = CFrame.new(backPos + Vector3.new(0,2,0))
    end)
    if camPrevSubj then workspace.CurrentCamera.CameraSubject = camPrevSubj end
    ctrlChar, ctrlHum, ctrlHrp = realChar, realHum, realHrp
end

-- ===== Noclip & No-Hit =====
local function setNoCollide(model,on) for _, v in ipairs(model:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide = not on; if on then v.CanTouch=false end end end end
local function noclipOn()
    if State.noclip then return end
    State.noclip=true
    setNoCollide(ctrlChar,true)
    if CFG.dmgGuard.noHitBubble and ensureGroup() then setGroup(ctrlChar, CG.group) end
    safeConnect(Conns.noclip, RunService.Stepped, function()
        if State.noclip and ctrlChar and ctrlChar.Parent then
            setNoCollide(ctrlChar,true)
            if CFG.dmgGuard.noHitBubble and CG.ready then setGroup(ctrlChar, CG.group) end
        end
    end)
end
local function noclipOff()
    if not State.noclip then return end
    State.noclip=false; disconnectAll(Conns.noclip)
    setNoCollide(ctrlChar,false)
end

-- ===== Fly (Dual Engine) =====
local flyBV, flyBG, alignP, alignO, att
local moveKeys={W=false,A=false,S=false,D=false,Up=false,Down=false}
local function computeFlyDir()
    local cam = workspace.CurrentCamera
    local dir = Vector3.new()
    local cf = cam.CFrame
    if moveKeys.W then dir += cf.LookVector end
    if moveKeys.S then dir -= cf.LookVector end
    if moveKeys.A then dir -= cf.RightVector end
    if moveKeys.D then dir += cf.RightVector end
    if moveKeys.Up then dir += Vector3.new(0,1,0) end
    if moveKeys.Down then dir += Vector3.new(0,-1,0) end
    return dir.Magnitude>0 and dir.Unit or Vector3.new()
end
local function ensureAlign(ctrlRoot)
    if att and att.Parent ~= ctrlRoot then att:Destroy(); att=nil end
    if not att then att = Instance.new("Attachment", ctrlRoot) end
    if not alignP then
        alignP = Instance.new("AlignPosition"); alignP.Attachment0=att; alignP.RigidityEnabled=false
        alignP.MaxForce = 1e9; alignP.Responsiveness=200; alignP.ApplyAtCenterOfMass=true; alignP.Parent=ctrlRoot
    end
    if not alignO then
        alignO = Instance.new("AlignOrientation"); alignO.Attachment0=att; alignO.RigidityEnabled=false
        alignO.MaxTorque = 1e9; alignO.Responsiveness=200; alignO.Mode=Enum.OrientationAlignmentMode.OneAttachment; alignO.Parent=ctrlRoot
    end
end
local function cleanupFlyObjects() if flyBV then flyBV:Destroy() flyBV=nil end if flyBG then flyBG:Destroy() flyBG=nil end if alignP then alignP:Destroy() alignP=nil end if alignO then alignO:Destroy() alignO=nil end if att then att:Destroy() att=nil end end
local function flyOn()
    if State.fly then return end
    State.fly=true
    if CFG.flyEngine=="Body" then
        flyBV=Instance.new("BodyVelocity"); flyBV.MaxForce=Vector3.new(1e6,1e6,1e6); flyBV.P=1e4; flyBV.Velocity=Vector3.new(); flyBV.Parent=ctrlHrp
        flyBG=Instance.new("BodyGyro"); flyBG.MaxTorque=Vector3.new(1e6,1e6,1e6); flyBG.P=3e4; flyBG.CFrame=ctrlHrp.CFrame; flyBG.Parent=ctrlHrp
    else
        ensureAlign(ctrlHrp)
    end
    ctrlHum.PlatformStand=true
    local accum=0
    safeConnect(Conns.fly, RunService.Heartbeat, function(dt)
        if not State.fly or not ctrlHrp or not ctrlHum then return end
        accum += dt
        local stepRate = 1/90 -- micro pasos
        if accum < stepRate then return end
        accum = 0
        local dir = computeFlyDir()
        local v = dir * CFG.speedFly
        if CFG.flyEngine=="Body" then
            if flyBV.Parent~=ctrlHrp then flyBV.Parent=ctrlHrp end
            if flyBG.Parent~=ctrlHrp then flyBG.Parent=ctrlHrp end
            flyBV.Velocity = v
            flyBG.CFrame = CFrame.new(ctrlHrp.Position, ctrlHrp.Position + workspace.CurrentCamera.CFrame.LookVector)
        else
            if not alignP or not alignO then ensureAlign(ctrlHrp) end
            local target = ctrlHrp.Position + (v * (1/60))
            alignP.Position = target
            alignO.CFrame = CFrame.new(ctrlHrp.Position, ctrlHrp.Position + workspace.CurrentCamera.CFrame.LookVector)
        end
    end)
end
local function flyOff()
    if not State.fly then return end
    State.fly=false; disconnectAll(Conns.fly); cleanupFlyObjects()
    if ctrlHum then ctrlHum.PlatformStand=false; ctrlHum:Move(Vector3.new()) end
end

-- ===== Velocidades =====
local shiftHeld=false
local function applyWalkSpeed() if ctrlHum then ctrlHum.WalkSpeed = (State.sprint or shiftHeld) and CFG.speedSprint or CFG.speedWalk end end
local function sprintToggle() State.sprint = not State.sprint; applyWalkSpeed(); saveCfg() end
local function bumpWalk(delta) CFG.speedWalk = clamp(CFG.speedWalk + delta, CFG.minWalk, CFG.maxWalk); applyWalkSpeed(); notify("Walk = "..math.floor(CFG.speedWalk)); saveCfg() end
local function bumpSprint(delta) CFG.speedSprint = clamp(CFG.speedSprint + delta, CFG.minSprint, CFG.maxSprint); applyWalkSpeed(); notify("Sprint = "..math.floor(CFG.speedSprint)); saveCfg() end
local function bumpFly(delta) CFG.speedFly = clamp(CFG.speedFly + delta, CFG.minFly, CFG.maxFly); notify("Fly = "..math.floor(CFG.speedFly)); saveCfg() end
local function toggleEngine() CFG.flyEngine = (CFG.flyEngine=="Body") and "Align" or "Body"; if State.fly then flyOff(); task.wait(); flyOn() end; notify("Fly Engine: "..CFG.flyEngine, 1.5); saveCfg() end

-- ===== Damage Guard (con No-Hit y Anti-Void, Anti-Stun, Auto-Ghost) =====
local HazardCache=setmetatable({}, {__mode='k'})
local function looksHazard(part)
    if not part or not part.Parent then return false end
    if HazardCache[part] ~= nil then return HazardCache[part] end
    local n = (part.Name or ""):lower()
    local hit=false
    for _, k in ipairs(CFG.hazardNames) do if n:find(k) then hit=true break end end
    HazardCache[part]=hit
    return hit
end
local function updateSafePos()
    if not realHrp or not realHrp.Parent then return end
    local pos = realHrp.Position
    if pos.Y > -1000 and pos.Y < 10000 and pos.FMagnitude ~= math.huge then State.safePos = CFrame.new(pos) end
end
local function dashSide(fromPos, sideDist)
    local right = Workspace.CurrentCamera.CFrame.RightVector
    local dir = (math.random(0,1)==0) and right or -right
    return fromPos + dir * sideDist
end
local function guardStart()
    disconnectAll(Conns.guard)
    if CFG.dmgGuard.antiStun then
        local ds = {Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.PlatformStanding, Enum.HumanoidStateType.Physics, Enum.HumanoidStateType.GettingUp}
        for _, st in ipairs(ds) do safe(function() realHum:SetStateEnabled(st, false) end) end
    end
    State.lastHealth = realHum and realHum.Health or nil
    if CFG.dmgGuard.autoGhostOnHit then
        safeConnect(Conns.guard, realHum.HealthChanged, function(hp)
            if not State.lastHealth then State.lastHealth = hp return end
            local drop = State.lastHealth - hp; State.lastHealth = hp
            if drop >= CFG.dmgGuard.hitDrop and not State.ghost then
                notify("Golpe detectado. Auto-Ghost...", 1.2)
                ghostOn(); task.delay(CFG.dmgGuard.ghostSeconds, function() if State.ghost then ghostOff() end end)
            end
        end)
    end
    if CFG.dmgGuard.noHitBubble and ensureGroup() then
        setGroup(realChar, CG.group)
        safeConnect(Conns.guard, RunService.Stepped, function() if CG.ready then setGroup(realChar, CG.group) end end)
    end
    if CFG.dmgGuard.antiVoid then
        safeConnect(Conns.guard, RunService.Heartbeat, function()
            if not realHrp then return end
            updateSafePos()
            if realHrp.Position.Y < -200 or tostring(realHrp.CFrame):find("nan") then
                if State.safePos then realHrp.CFrame = State.safePos + Vector3.new(0,6,0) else realHrp.CFrame=CFrame.new(0,50,0) end
                notify("Anti-Void", 1)
            end
        end)
    end
    if CFG.dmgGuard.antiHazard then
        safeConnect(Conns.guard, realHrp.Touched, function(hit)
            if hit and looksHazard(hit) and State.safePos then realHrp.CFrame = State.safePos + Vector3.new(0,6,0); notify("Hazard evitado", 1) end
        end)
    end
    if CFG.dmgGuard.dodge then
        safeConnect(Conns.guard, RunService.Stepped, function()
            if not realHrp then return end
            local myPos=realHrp.Position
            local nearest, nd= nil, CFG.dmgGuard.dodgeRadius
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl~=player and pl.Character then
                    local hrp = pl.Character:FindFirstChild("HumanoidRootPart"); local hum=pl.Character:FindFirstChildOfClass("Humanoid")
                    if hrp and hum and hum.Health>0 then
                        local d=(hrp.Position - myPos).Magnitude
                        if d<nd then nearest, nd = hrp, d end
                    end
                end
            end
            if nearest then local newPos=dashSide(myPos, CFG.dmgGuard.dodgeSide); safe(function() realHrp.CFrame = CFrame.new(newPos + Vector3.new(0,2,0)) end) end
        end)
    end
end

-- ===== Anti-Teleport-Back =====
local userCFrameWrite=false
local function markUserMove() State.userMoveTick = now() end
local function antiTeleportBack()
    disconnectAll(Conns.antiTP)
    if not CFG.antiTeleportBack.enabled then return end
    State.lastCFrame = realHrp.CFrame
    safeConnect(Conns.antiTP, realHrp:GetPropertyChangedSignal("CFrame"), function()
        if userCFrameWrite then return end
        local oldPos = State.lastCFrame.Position
        local newPos = realHrp.CFrame.Position
        local jump = (newPos - oldPos).Magnitude
        State.lastCFrame = realHrp.CFrame
        if jump >= CFG.antiTeleportBack.threshold and (now() - State.userMoveTick) > 0.2 then
            if CFG.antiTeleportBack.action=="revert" and State.safePos then
                userCFrameWrite=true; realHrp.CFrame = State.safePos + Vector3.new(0,6,0); userCFrameWrite=false
                notify("Anti-TPBack: revert", 1)
            elseif CFG.antiTeleportBack.action=="ghost" then
                notify("Anti-TPBack: ghost", 1); if not State.ghost then ghostOn() end
            else
                notify("Zona hostil marcada", 1)
            end
        end
    end)
end

-- ===== Teleport Suite (con path y raycast) =====
local Waypoints={}
local function addWaypoint(name, cf) table.insert(Waypoints, {name=name or ("WP"..tostring(#Waypoints+1)), cf=cf}) end
local function groundAt(pos)
    local ray = RaycastParams.new(); ray.FilterType=Enum.RaycastFilterType.Blacklist; ray.FilterDescendantsInstances={realChar}
    local hit = Workspace:Raycast(pos+Vector3.new(0,50,0), Vector3.new(0,-500,0), ray)
    if hit then return CFrame.new(hit.Position + Vector3.new(0,3,0)) else return CFrame.new(pos) end
end
local function tpSnap(cf) userCFrameWrite=true; realHrp.CFrame=cf; userCFrameWrite=false; markUserMove() end
local function tpTween(cf, speed)
    local dist = (realHrp.Position - cf.Position).Magnitude
    local t = math.max(0.05, dist / (speed or CFG.tpTweenSpeed))
    local tw = TweenService:Create(realHrp, TweenInfo.new(t, Enum.EasingStyle.Linear), {CFrame = cf})
    userCFrameWrite=true; tw:Play(); tw.Completed:Wait(); userCFrameWrite=false; markUserMove()
end
local function tpBlink(cf, step, delayStep)
    local from=realHrp.Position; local to=cf.Position; local dir=(to-from); local dist=dir.Magnitude; if dist==0 then return end
    local unit=dir.Unit; local s=step or CFG.tpBlinkStep; local n=math.max(1, math.floor(dist/s))
    for i=1,n do
        local target = from + unit * (s*i)
        if CFG.tpSafe then target = groundAt(target).Position end
        userCFrameWrite=true; realHrp.CFrame = CFrame.new(target); userCFrameWrite=false
        task.wait(delayStep or CFG.tpBlinkDelay)
    end
    userCFrameWrite=true; realHrp.CFrame = cf; userCFrameWrite=false; markUserMove()
end
local function tpPathTo(targetPos)
    local params = PathfindingService:CreatePath({AgentRadius=2, AgentCanJump=true})
    params:ComputeAsync(realHrp.Position, targetPos)
    if params.Status ~= Enum.PathStatus.Success then return false end
    local way = params:GetWaypoints()
    for _, w in ipairs(way) do
        local cf = CFrame.new(w.Position) * CFrame.Angles(0,0,0)
        if CFG.tpMode=="Tween" then tpTween(groundAt(w.Position), CFG.tpTweenSpeed)
        elseif CFG.tpMode=="Blink" then tpBlink(groundAt(w.Position), CFG.tpBlinkStep, CFG.tpBlinkDelay)
        else tpSnap(groundAt(w.Position)) end
    end
    return true
end
local function tpToCFrame(cf, mode)
    mode = mode or CFG.tpMode
    if mode=="Snap" then tpSnap(cf)
    elseif mode=="Tween" then tpTween(cf, CFG.tpTweenSpeed)
    else tpBlink(cf, CFG.tpBlinkStep, CFG.tpBlinkDelay) end
end
local function tpToMouse(mode)
    local mouse = player:GetMouse(); if not mouse.Hit then return end
    local pos = mouse.Hit.Position
    if CFG.tpSafe then pos = groundAt(pos).Position end
    if not tpPathTo(pos) then tpToCFrame(CFrame.new(pos), mode) end
end
local function findPlayer(q)
    if not q or q=="" then return nil end; q=q:lower()
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl~=player and ((pl.Name:lower():find(q)) or (pl.DisplayName and pl.DisplayName:lower():find(q))) then return pl end
    end
    return nil
end
local function tpToPlayer(q, mode)
    local pl = findPlayer(q); if not pl or not pl.Character then notify("Jugador no encontrado",1.2) return end
    local hrp = pl.Character:FindFirstChild("HumanoidRootPart"); if not hrp then notify("Sin HRP",1.2) return end
    local pos = hrp.Position + Vector3.new(0,3,0); if CFG.tpSafe then pos = groundAt(pos).Position end
    if not tpPathTo(pos) then tpToCFrame(CFrame.new(pos), mode) end
end

-- ===== Inputs =====
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
        elseif k==Enum.KeyCode.Equals or k==Enum.KeyCode.KeypadPlus then bumpFly( CFG.stepFly)
        elseif k==Enum.KeyCode.Minus  or k==Enum.KeyCode.KeypadMinus then bumpFly(-CFG.stepFly)
        elseif k==Enum.KeyCode.RightBracket then bumpSprint( CFG.stepSprint)
        elseif k==Enum.KeyCode.LeftBracket  then bumpSprint(-CFG.stepSprint)
        elseif k==Enum.KeyCode.Period then bumpWalk( CFG.stepWalk)
        elseif k==Enum.KeyCode.Comma  then bumpWalk(-CFG.stepWalk)
        elseif k==Enum.KeyCode.BackSlash then toggleEngine()
        elseif k==Enum.KeyCode.P then if _G.__USH_CMD then _G.__USH_CMD() end
        elseif k==Enum.KeyCode.MouseButton3 then tpToMouse()
        end
        if k==Enum.KeyCode.Space then moveKeys.Up=true end
        if k==Enum.KeyCode.LeftControl or k==Enum.KeyCode.C then moveKeys.Down=true end
        if k==Enum.KeyCode.W then moveKeys.W=true end
        if k==Enum.KeyCode.A then moveKeys.A=true end
        if k==Enum.KeyCode.S then moveKeys.S=true end
        if k==Enum.KeyCode.D then moveKeys.D=true end
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
        elseif k==Enum.KeyCode.D then moveKeys.D=false
        end
    end)
end

-- ===== Anti-idle =====
do local ok, vu = pcall(function() return game:GetService("VirtualUser") end)
    if ok and vu then safeConnect(Conns.meta, player.Idled, function() vu:Button2Down(Vector2.new(), Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame or CFrame.new()); task.wait(1); vu:Button2Up(Vector2.new(), Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame or CFrame.new()) end) end
end

-- ===== GUI (compact, con Command Palette) =====
local UI = {}
local function buildGUI()
    disconnectAll(Conns.ui)
    if UI.Screen and UI.Screen.Parent then UI.Screen:Destroy() end
    local gui=Instance.new("ScreenGui"); gui.Name="UltraStealthHub"; gui.ResetOnSpawn=false; gui.Parent=player:WaitForChild("PlayerGui"); UI.Screen=gui
    local frame=Instance.new("Frame"); frame.Size=UDim2.new(0,390,0,560); frame.Position=UDim2.new(0.5,-195,0.5,-280)
    frame.BackgroundColor3=Color3.fromRGB(18,18,18); frame.BorderSizePixel=0; frame.Parent=gui; UI.Frame=frame
    local title=Instance.new("TextLabel"); title.Size=UDim2.new(1,-80,0,26); title.Position=UDim2.new(0,10,0,8)
    title.BackgroundTransparency=1; title.Text="Ultra Stealth Hub (Vanguard)"; title.TextColor3=Color3.new(1,1,1); title.Font=Enum.Font.GothamBold; title.TextSize=16; title.TextXAlignment=Enum.TextXAlignment.Left; title.Parent=frame
    local close=Instance.new("TextButton"); close.Size=UDim2.new(0,60,0,24); close.Position=UDim2.new(1,-70,0,8)
    close.Text = CFG.uiVisible and "Hide UI" or "Show UI"; close.BackgroundColor3=Color3.fromRGB(40,40,40); close.TextColor3=Color3.new(1,1,1); close.Font=Enum.Font.GothamSemibold; close.TextSize=12; close.Parent=frame
    local pad=Instance.new("UIPadding", frame); pad.PaddingTop=UDim.new(0,40); pad.PaddingLeft=UDim.new(0,10); pad.PaddingRight=UDim.new(0,10); pad.PaddingBottom=UDim.new(0,10)
    local list=Instance.new("UIListLayout", frame); list.Padding=UDim.new(0,8)

    local function button(text, cb) local b=Instance.new("TextButton"); b.Size=UDim2.new(1,-20,0,32); b.BackgroundColor3=Color3.fromRGB(40,40,40); b.TextColor3=Color3.new(1,1,1); b.Font=Enum.Font.GothamSemibold; b.TextSize=14; b.Text=text; b.Parent=frame; b.MouseButton1Click:Connect(function() cb(b) end); return b end
    local function counter(label, getter, inc, dec)
        local row=Instance.new("Frame"); row.Size=UDim2.new(1,-20,0,32); row.BackgroundColor3=Color3.fromRGB(30,30,30); row.Parent=frame
        local l=Instance.new("TextLabel"); l.Size=UDim2.new(0.5,0,1,0); l.BackgroundTransparency=1; l.Text=label; l.TextColor3=Color3.fromRGB(220,220,220); l.Font=Enum.Font.Gotham; l.TextSize=13; l.TextXAlignment=Enum.TextXAlignment.Left; l.Parent=row
        local minus=Instance.new("TextButton"); minus.Size=UDim2.new(0,32,0,24); minus.Position=UDim2.new(0.55,0,0.5,-12); minus.Text="-"; minus.BackgroundColor3=Color3.fromRGB(60,40,40); minus.TextColor3=Color3.new(1,1,1); minus.Parent=row
        local val=Instance.new("TextLabel"); val.Size=UDim2.new(0,80,1,0); val.Position=UDim2.new(0.68,0,0,0); val.BackgroundTransparency=1; val.Text=tostring(getter()); val.TextColor3=Color3.fromRGB(255,255,255); val.Font=Enum.Font.Gotham; val.TextSize=13; val.TextXAlignment=Enum.TextXAlignment.Center; val.Parent=row
        local plus=Instance.new("TextButton"); plus.Size=UDim2.new(0,32,0,24); plus.Position=UDim2.new(0.88,0,0.5,-12); plus.Text="+"; plus.BackgroundColor3=Color3.fromRGB(40,60,40); plus.TextColor3=Color3.new(1,1,1); plus.Parent=row
        minus.MouseButton1Click:Connect(function() dec(); val.Text=tostring(getter()); saveCfg() end)
        plus.MouseButton1Click:Connect(function() inc(); val.Text=tostring(getter()); saveCfg() end)
        return row
    end
    local function toggle(label, get, set)
        local row=Instance.new("TextButton"); row.Size=UDim2.new(1,-20,0,28); row.BackgroundColor3=Color3.fromRGB(35,35,35); row.TextColor3=Color3.new(1,1,1); row.Font=Enum.Font.Gotham; row.TextSize=13; row.Parent=frame
        local function update() row.Text = label..": "..(get() and "ON" or "OFF") end; update()
        row.MouseButton1Click:Connect(function() set(not get()); update(); saveCfg() end)
        return row
    end

    button("Noclip: OFF (T)", function(b) if State.noclip then noclipOff(); b.Text="Noclip: OFF (T)" else noclipOn(); b.Text="Noclip: ON  (T)" end end)
    button("Fly: OFF (F)", function(b) if State.fly then flyOff(); b.Text="Fly: OFF (F)" else flyOn(); b.Text="Fly: ON  (F)" end end)
    button("Sprint: OFF (Shift)", function(b) sprintToggle(); b.Text = State.sprint and "Sprint: ON  (Shift)" or "Sprint: OFF (Shift)" end)
    button("Invis Rep: OFF (G)", function(b) if State.invisRep then invisRepOff(); b.Text="Invis Rep: OFF (G)" else invisRepOn(); b.Text="Invis Rep: ON  (G)" end end)
    button("Ghost: OFF (H)", function(b) if State.ghost then ghostOff(); b.Text="Ghost: OFF (H)" else if State.invisRep then invisRepOff() end; ghostOn(); b.Text="Ghost: ON  (H)" end end)
    button("Fly Engine: "..CFG.flyEngine.." (\\)", function(b) toggleEngine(); b.Text="Fly Engine: "..CFG.flyEngine.." (\\)" end)
    toggle("Auto-Stealth", function() return State.autoStealth end, function(v) State.autoStealth=v end)
    toggle("No-Hit Bubble (CG)", function() return CFG.dmgGuard.noHitBubble end, function(v) CFG.dmgGuard.noHitBubble=v; guardStart() end)
    toggle("Anti-TPBack", function() return CFG.antiTeleportBack.enabled end, function(v) CFG.antiTeleportBack.enabled=v; antiTeleportBack() end)

    counter("Walk speed  (,/.)", function() return math.floor(CFG.speedWalk) end, function() bumpWalk( CFG.stepWalk) end, function() bumpWalk(-CFG.stepWalk) end)
    counter("Sprint speed  ([/])", function() return math.floor(CFG.speedSprint) end, function() bumpSprint( CFG.stepSprint) end, function() bumpSprint(-CFG.stepSprint) end)
    counter("Fly speed  (-/=)", function() return math.floor(CFG.speedFly) end, function() bumpFly( CFG.stepFly) end, function() bumpFly(-CFG.stepFly) end)

    button("TP to Mouse ("..CFG.tpMode..") [MMB]", function() tpToMouse() end)
    button("TP Mode: "..CFG.tpMode, function(b) local order={"Snap","Tween","Blink"}; local idx=1 for i,n in ipairs(order) do if CFG.tpMode==n then idx=i end end idx=idx%#order+1; CFG.tpMode=order[idx]; b.Text="TP Mode: "..CFG.tpMode; save
