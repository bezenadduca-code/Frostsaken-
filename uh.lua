-- V1PRWARE | maintained by mitsuki | original by v1pr/glov
print("V1PRWARE loaded")

------------------------------------------------------------------------
-- services
------------------------------------------------------------------------
local svc = {
    Players      = game:GetService("Players"),
    Run          = game:GetService("RunService"),
    Input        = game:GetService("UserInputService"),
    RS           = game:GetService("ReplicatedStorage"),
    WS           = game:GetService("Workspace"),
    TweenService = game:GetService("TweenService"),
    TextChat     = game:GetService("TextChatService"),
    Http         = game:GetService("HttpService"),
    Stats        = game:GetService("Stats"),
}

local lp  = svc.Players.LocalPlayer
local gui = lp:WaitForChild("PlayerGui", 10)

------------------------------------------------------------------------
-- filesystem shims
------------------------------------------------------------------------
local fs = {
    hasFolder = isfolder      or function() return false end,
    makeFolder= makefolder    or function() end,
    write     = writefile     or function() end,
    hasFile   = isfile        or function() return false end,
    read      = readfile      or function() return "" end,
    asset     = getcustomasset or function(p) return p end,
}

------------------------------------------------------------------------
-- config
------------------------------------------------------------------------
local cfg = {}
do
    local DIR  = "V1PRWARE"
    local FILE = DIR .. "/config.json"
    local saveThread = nil

    local function prep()
        if not fs.hasFolder(DIR) then fs.makeFolder(DIR) end
    end

    function cfg.load()
        prep()
        if not fs.hasFile(FILE) then return end
        local ok, t = pcall(svc.Http.JSONDecode, svc.Http, fs.read(FILE))
        if ok and type(t) == "table" then cfg._data = t end
    end

    function cfg.save()
        if saveThread then task.cancel(saveThread) end
        saveThread = task.delay(0.5, function()
            saveThread = nil
            prep()
            local ok, s = pcall(svc.Http.JSONEncode, svc.Http, cfg._data)
            if ok then fs.write(FILE, s) end
        end)
    end

    function cfg.get(k, default)
        local v = cfg._data[k]
        return v ~= nil and v or default
    end

    function cfg.set(k, v)
        cfg._data[k] = v
        cfg.save()
    end

    cfg._data = {}
    cfg.load()
end

------------------------------------------------------------------------
-- Rayfield GUI
------------------------------------------------------------------------
local Rayfield = loadstring(game:HttpGet(
    "https://sirius.menu/rayfield"
))()

------------------------------------------------------------------------
-- Window
------------------------------------------------------------------------
local win = Rayfield:CreateWindow({
    Name             = "V1PRWARE",
    LoadingTitle     = "V1PRWARE",
    LoadingSubtitle  = "maintained by mitsuki | original by v1pr/glov",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "V1PRWARE",
        FileName = "config",
    },
    Discord = {
        Enabled = false,
    },
    KeySystem = false,
})

------------------------------------------------------------------------
-- helpers
------------------------------------------------------------------------
local function getTeamFolder(name)
    local root = svc.WS:FindFirstChild("Players")
    return root and root:FindFirstChild(name)
end
local function getIngame()
    local m = svc.WS:FindFirstChild("Map")
    return m and m:FindFirstChild("Ingame")
end
local function getMapContent()
    local ig = getIngame()
    return ig and ig:FindFirstChild("Map")
end

local _networkModule = nil
local function getNetwork()
    if _networkModule then return _networkModule end
    local ok, m = pcall(function()
        return require(svc.RS.Modules.Network.Network)
    end)
    if ok and m then _networkModule = m end
    return _networkModule
end

------------------------------------------------------------------------
------------------------------------------------------------------------
-- TAB: SETTINGS
------------------------------------------------------------------------
------------------------------------------------------------------------
local tabSettings = win:CreateTab("Settings", "settings-2")

local secInterface = tabSettings:CreateSection("Interface")

local chatForceEnabled = cfg.get("chatForceEnabled", false)
local chatForceConns   = {}
local function enforceChatOn()
    if not chatForceEnabled then return end
    local cw = svc.TextChat:FindFirstChild("ChatWindowConfiguration")
    local ci = svc.TextChat:FindFirstChild("ChatInputBarConfiguration")
    if cw and not cw.Enabled then cw.Enabled = true end
    if ci and not ci.Enabled then ci.Enabled = true end
end
tabSettings:CreateToggle({
    Name = "Show Chat Logs", CurrentValue = chatForceEnabled, Flag = "showChatLogs",
    Callback = function(on)
        chatForceEnabled = on; cfg.set("chatForceEnabled", on)
        for _, c in ipairs(chatForceConns) do if c.Connected then c:Disconnect() end end
        chatForceConns = {}
        if on then
            enforceChatOn()
            for _, key in ipairs({ "ChatWindowConfiguration", "ChatInputBarConfiguration" }) do
                local obj = svc.TextChat:FindFirstChild(key)
                if obj then
                    table.insert(chatForceConns, obj:GetPropertyChangedSignal("Enabled"):Connect(enforceChatOn))
                end
            end
        end
    end
})

local timerSide = cfg.get("timerSide", "Middle")
local function applyTimerPos()
    local rt = lp.PlayerGui:FindFirstChild("RoundTimer")
    local m  = rt and rt:FindFirstChild("Main")
    if m then m.Position = UDim2.new(timerSide == "Middle" and 0.5 or 0.9, 0, m.Position.Y.Scale, m.Position.Y.Offset) end
end
applyTimerPos()
tabSettings:CreateDropdown({
    Name = "Timer Position", Options = { "Middle", "Right" }, CurrentOption = timerSide,
    Flag = "timerSide",
    Callback = function(v) timerSide = v; cfg.set("timerSide", v); applyTimerPos() end
})
lp.CharacterAdded:Connect(function()
    task.delay(1, function() applyTimerPos() end)
end)



------------------------------------------------------------------------
------------------------------------------------------------------------
-- TAB: GLOBAL
------------------------------------------------------------------------
------------------------------------------------------------------------
local tabGlobal  = win:CreateTab("Global", "globe-2")

tabGlobal:CreateSection("Stamina")

tabGlobal:CreateParagraph({ Title = "How it works", Content = "Directly modifies the client-side Sprinting module values." })

local stam = {
    on      = cfg.get("stamOn",      false),
    loss    = cfg.get("stamLoss",    10),
    gain    = cfg.get("stamGain",    20),
    max     = cfg.get("stamMax",     100),
    current = cfg.get("stamCurrent", 100),
    noLoss  = cfg.get("stamNoLoss",  false),
    thread  = nil,
}

local function stamModule()
    local ok, m = pcall(function() return require(svc.RS.Systems.Character.Game.Sprinting) end)
    return ok and m or nil
end
local function stamIsKiller()
    local ch = lp.Character; if not ch then return false end
    local kf = getTeamFolder("Killers")
    return kf and ch:IsDescendantOf(kf)
end
local function stamApply()
    local m = stamModule(); if not m then return end
    if not m.DefaultsSet then pcall(function() m.Init() end) end
    local forceNoLoss = stam.noLoss or stamIsKiller()
    m.StaminaLoss = stam.loss; m.StaminaGain = stam.gain
    local abilityCapActive = type(m.StaminaCap) == "number" and m.StaminaCap < (m.MaxStamina or math.huge)
    if not abilityCapActive then
        m.MaxStamina = stam.max
        if type(m.StaminaCap) == "number" then m.StaminaCap = stam.max end
    end
    m.StaminaLossDisabled = forceNoLoss
    if m.Stamina and m.Stamina > stam.max then m.Stamina = stam.current end
    pcall(function() if m.__staminaChangedEvent then m.__staminaChangedEvent:Fire() end end)
end
local function stamStart()
    if stam.thread then return end
    stam.thread = task.spawn(function()
        while stam.on do
            if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then stamApply() end
            task.wait(0.5)
        end; stam.thread = nil
    end)
end
local function stamStop()
    stam.on = false
    if stam.thread then task.cancel(stam.thread); stam.thread = nil end
end
tabGlobal:CreateToggle({ Name = "Custom Stamina", CurrentValue = stam.on, Flag = "stamOn",
    Callback = function(on) stam.on = on; cfg.set("stamOn", on); if on then stamStart() else stamStop() end end })
tabGlobal:CreateSlider({ Name = "Loss Rate",     Range = { 0,  50  }, Increment = 1, CurrentValue = stam.loss,    Flag = "stamLoss",    Callback = function(v) stam.loss    = v; cfg.set("stamLoss",    v) end })
tabGlobal:CreateSlider({ Name = "Gain Rate",     Range = { 0,  50  }, Increment = 1, CurrentValue = stam.gain,    Flag = "stamGain",    Callback = function(v) stam.gain    = v; cfg.set("stamGain",    v) end })
tabGlobal:CreateSlider({ Name = "Max Pool",      Range = { 50, 500 }, Increment = 1, CurrentValue = stam.max,     Flag = "stamMax",     Callback = function(v) stam.max     = v; cfg.set("stamMax",     v) end })
tabGlobal:CreateSlider({ Name = "Current Value", Range = { 0,  500 }, Increment = 1, CurrentValue = stam.current, Flag = "stamCurrent", Callback = function(v) stam.current = v; cfg.set("stamCurrent", v) end })
tabGlobal:CreateToggle({ Name = "Infinite Stamina", CurrentValue = stam.noLoss, Flag = "stamNoLoss",
    Callback = function(on)
        stam.noLoss = on; cfg.set("stamNoLoss", on); stamApply()
        if on and not stam.on then stam.on = true; stamStart() end
    end
})
if stam.on then stamStart() end
lp.CharacterAdded:Connect(function()
    task.delay(1.5, function()
        if stam.on then stamApply(); if not stam.thread then stamStart() end end
    end)
end)

------------------------------------------------------------------------
-- Speed Hack (Sprint Module)
------------------------------------------------------------------------
tabGlobal:CreateSection("Speed Hack")

tabGlobal:CreateParagraph({ 
    Title = "How it works", 
    Content = "Modifies the Sprinting module's SprintSpeed value directly. Enter a custom sprint speed. IMPORTANT: Stop sprinting, set new speed, sprint again." 
})

local speedHack = {
    on       = cfg.get("speedOn",       false),
    speed    = cfg.get("speedValue",    30),
    thread   = nil,
    originalSpeed = nil,
    lastTeam = nil,
    lastAppliedSpeed = 0,
}

local function speedModule()
    local ok, m = pcall(function() return require(svc.RS.Systems.Character.Game.Sprinting) end)
    return ok and m or nil
end

local function speedGetTeam()
    local char = lp.Character
    if not char then return nil end
    local kf = getTeamFolder("Killers")
    local sf = getTeamFolder("Survivors")
    if kf and char:IsDescendantOf(kf) then return "Killer" end
    if sf and char:IsDescendantOf(sf) then return "Survivor" end
    return nil
end

local function speedGetDefault()
    local team = speedGetTeam()
    if team == "Killer" then
        local char = lp.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and hum.WalkSpeed > 0 then return hum.WalkSpeed end
        end
        return 27
    end
    return 26
end

local function speedApply()
    if not speedHack.on then return end
    local m = speedModule()
    if not m then return end
    if not m.DefaultsSet then pcall(function() m.Init() end) end
    
    if speedHack.speed > 0 and speedHack.speed ~= speedHack.lastAppliedSpeed then
        m.SprintSpeed = speedHack.speed
        pcall(function() m.MaxSprintSpeed = speedHack.speed end)
        speedHack.lastAppliedSpeed = speedHack.speed
        
        local char = lp.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                local isSprinting = false
                pcall(function() if m.IsSprinting then isSprinting = m:IsSprinting() end end)
                if isSprinting then hum.WalkSpeed = speedHack.speed end
            end
        end
    end
    
    local char = lp.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            local isSprinting = false
            pcall(function() if m.IsSprinting then isSprinting = m:IsSprinting() end end)
            if not isSprinting then speedHack.lastAppliedSpeed = 0 end
        end
        local team = speedGetTeam()
        if team and team ~= speedHack.lastTeam then
            speedHack.lastTeam = team
            speedHack.originalSpeed = nil
            speedHack.lastAppliedSpeed = 0
        end
    end
end

local function speedRestore()
    local m = speedModule()
    if m then
        local default = speedGetDefault()
        m.SprintSpeed = default
        pcall(function() m.MaxSprintSpeed = default end)
    end
    local char = lp.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = speedGetDefault() end
    end
    speedHack.originalSpeed = nil
    speedHack.lastAppliedSpeed = 0
end

local function speedStart()
    if speedHack.thread then return end
    speedHack.lastAppliedSpeed = 0
    speedHack.thread = task.spawn(function()
        while speedHack.on do
            if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then speedApply() end
            task.wait(0.2)
        end
        speedHack.thread = nil
    end)
end

local function speedStop()
    speedHack.on = false
    if speedHack.thread then task.cancel(speedHack.thread); speedHack.thread = nil end
    speedRestore()
end

lp.CharacterAdded:Connect(function()
    task.delay(1, function()
        speedHack.originalSpeed = nil
        speedHack.lastTeam = nil
        speedHack.lastAppliedSpeed = 0
        if speedHack.on then speedApply(); if not speedHack.thread then speedStart() end end
    end)
end)

if speedHack.on then speedStart() end

tabGlobal:CreateToggle({ Name = "Custom Sprint Speed", CurrentValue = speedHack.on, Flag = "speedOn",
    Callback = function(on) speedHack.on = on; cfg.set("speedOn", on); if on then speedHack.lastAppliedSpeed = 0; speedStart() else speedStop() end end })
tabGlobal:CreateInput({ Name = "Sprint Speed Value", CurrentValue = tostring(speedHack.speed), PlaceholderText = "Enter speed", RemoveTextAfterFocusLost = false, Flag = "speedValueInput",
    Callback = function(text) local num = tonumber(text); if num and num > 0 and num <= 200 then speedHack.speed = num; cfg.set("speedValue", num); speedHack.lastAppliedSpeed = 0 end end })
tabGlobal:CreateButton({ Name = "Reset Sprint Speed", Callback = function() speedRestore() end })
tabGlobal:CreateButton({ Name = "Set Speed: 28 (Fast)", Callback = function() speedHack.speed = 28; cfg.set("speedValue", 28); speedHack.lastAppliedSpeed = 0 end })
tabGlobal:CreateButton({ Name = "Set Speed: 35 (Faster)", Callback = function() speedHack.speed = 35; cfg.set("speedValue", 35); speedHack.lastAppliedSpeed = 0 end })
tabGlobal:CreateButton({ Name = "Set Speed: 50 (Zoom)", Callback = function() speedHack.speed = 50; cfg.set("speedValue", 50); speedHack.lastAppliedSpeed = 0 end })

tabGlobal:CreateSection("Status")

local statusGroups = {
    Slowness      = { on = false, paths = { "Modules.Schematics.StatusEffects.Slowness" } },
    Hallucination = { on = false, paths = { "Modules.Schematics.StatusEffects.KillerExclusive.Hallucination" } },
    Visual        = { on = false, paths = { "Modules.Schematics.StatusEffects.Blindness", "Modules.Schematics.StatusEffects.SurvivorExclusive.Subspaced", "Modules.Schematics.StatusEffects.KillerExclusive.Glitched" }},
}
local statusBackup = {}
local function statusResolve(path)
    local node = svc.RS
    for seg in path:gmatch("[^%.]+") do node = node:FindFirstChild(seg); if not node then return nil end end
    return node
end
local function statusBlock(path)
    if statusBackup[path] then return end
    local mod = statusResolve(path)
    if not mod then return end
    if mod:IsA("Folder") then
        statusBackup[path] = { clone = mod:Clone(), isFolder = true, parentPath = path:match("^(.-)%.?[^%.]+$") }
        mod:Destroy()
    elseif mod:IsA("ModuleScript") or mod:IsA("LocalScript") then
        statusBackup[path] = { clone = mod:Clone(), src = mod.Source, isFolder = false }
        mod:Destroy()
    end
end
local function statusRestore(path)
    local saved = statusBackup[path]; if not saved then return end
    local existing = statusResolve(path); if existing then existing:Destroy() end
    local parentPath = saved.parentPath or path:match("^(.-)%.?[^%.]+$")
    local parent = statusResolve(parentPath)
    if parent then
        if not saved.isFolder then saved.clone.Source = saved.src end
        saved.clone.Parent = parent
    end
    statusBackup[path] = nil
end
local statusLoopThread = nil
local function statusTick()
    if statusLoopThread then return end
    statusLoopThread = task.spawn(function()
        while true do
            local any = false
            for _, g in pairs(statusGroups) do if g.on then any = true; for _, p in ipairs(g.paths) do local m = statusResolve(p); if m then m:Destroy() end end end end
            if not any then break end; task.wait(0.8)
        end; statusLoopThread = nil
    end)
end
local function statusToggle(name)
    local g = statusGroups[name]; if not g then return end; g.on = not g.on
    for _, p in ipairs(g.paths) do if g.on then statusBlock(p) else statusRestore(p) end end
    local any = false; for _, sg in pairs(statusGroups) do if sg.on then any = true; break end end
    if any then statusTick() elseif statusLoopThread then task.cancel(statusLoopThread); statusLoopThread = nil end
end
tabGlobal:CreateButton({ Name = "Toggle: Slowness", Callback = function() statusToggle("Slowness") end })
tabGlobal:CreateButton({ Name = "Toggle: Hallucination", Callback = function() statusToggle("Hallucination") end })
tabGlobal:CreateButton({ Name = "Toggle: Visual Effects", Callback = function() statusToggle("Visual") end })
lp.CharacterAdded:Connect(function()
    statusBackup = {}; for _, g in pairs(statusGroups) do g.on = false end
    if statusLoopThread then task.cancel(statusLoopThread); statusLoopThread = nil end
end)

------------------------------------------------------------------------
-- remote helper
------------------------------------------------------------------------
local _hbRemote = nil
local function hbGetRemote()
    if _hbRemote and _hbRemote.Parent then return _hbRemote end
    local ok, re = pcall(function() return svc.RS.Modules.Network.Network:FindFirstChild("RemoteEvent") end)
    if ok and re then _hbRemote = re; return re end
    return nil
end

------------------------------------------------------------------------
------------------------------------------------------------------------
-- TAB: GENERATOR
------------------------------------------------------------------------
------------------------------------------------------------------------
local tabGen = win:CreateTab("Generator", "cpu")
tabGen:CreateSection("Auto Solve")

local flow = { on = cfg.get("flowOn", false), nodeDelay = cfg.get("flowNodeDelay", 0.04), lineDelay = cfg.get("flowLineDelay", 0.60) }
local function flowKey(n) return n.row.."-"..n.col end
local function flowNeighbour(r1,c1,r2,c2)
    if r2==r1-1 and c2==c1 then return"up" end; if r2==r1+1 and c2==c1 then return"down" end
    if r2==r1 and c2==c1-1 then return"left" end; if r2==r1 and c2==c1+1 then return"right" end; return false
end
local function flowOrder(path, endpoints)
    if not path or #path == 0 then return path end
    local lookup = {}; for _, n in ipairs(path) do lookup[flowKey(n)] = n end
    local start
    for _, ep in ipairs(endpoints or {}) do for _, n in ipairs(path) do if n.row == ep.row and n.col == ep.col then start = { row = ep.row, col = ep.col }; break end end; if start then break end end
    if not start then for _, n in ipairs(path) do local nb = 0; for _, d in ipairs({{-1,0},{1,0},{0,-1},{0,1}}) do if lookup[(n.row+d[1]).."-"..(n.col+d[2])] then nb += 1 end end; if nb == 1 then start = { row = n.row, col = n.col }; break end end end
    if not start then start = { row = path[1].row, col = path[1].col } end
    local pool, ordered = {}, {}; for _, n in ipairs(path) do pool[flowKey(n)] = { row = n.row, col = n.col } end
    local cur = start; table.insert(ordered, { row = cur.row, col = cur.col }); pool[flowKey(cur)] = nil
    while next(pool) do local moved = false; for k, node in pairs(pool) do if flowNeighbour(cur.row, cur.col, node.row, node.col) then table.insert(ordered, { row = node.row, col = node.col }); pool[k] = nil; cur = node; moved = true; break end end; if not moved then break end end
    return ordered
end
local function flowSolve(puzzle)
    if not puzzle or not puzzle.Solution then return end
    local indices = {}; for i = 1, #puzzle.Solution do indices[i] = i end
    for i = #indices, 2, -1 do local j = math.random(1, i); indices[i], indices[j] = indices[j], indices[i] end
    for _, ci in ipairs(indices) do
        local solution = puzzle.Solution[ci]; if not solution then continue end
        local ordered = flowOrder(solution, puzzle.targetPairs[ci])
        if not ordered or #ordered == 0 then continue end
        puzzle.paths[ci] = {}
        for _, node in ipairs(ordered) do table.insert(puzzle.paths[ci], { row = node.row, col = node.col }); puzzle:updateGui(); task.wait(flow.nodeDelay) end
        task.wait(flow.lineDelay); puzzle:checkForWin()
    end
end
do
    local fgModule = svc.RS:FindFirstChild("Modules") and svc.RS.Modules:FindFirstChild("Minigames") and svc.RS.Modules.Minigames:FindFirstChild("FlowGameManager") and svc.RS.Modules.Minigames.FlowGameManager:FindFirstChild("FlowGame")
    if fgModule then local ok, FG = pcall(require, fgModule)
        if ok and FG and FG.new then local orig = FG.new; FG.new = function(...) local p = orig(...); if flow.on then task.spawn(function() task.wait(0.3); flowSolve(p) end) end; return p end end
    end
end
tabGen:CreateToggle({ Name = "Auto Solve", CurrentValue = flow.on, Flag = "flowOn", Callback = function(on) flow.on = on; cfg.set("flowOn", on) end })
tabGen:CreateSlider({ Name = "Node Speed", Range = { 0.01, 0.50 }, Increment = 0.02, CurrentValue = flow.nodeDelay, Flag = "flowNodeDelay", Callback = function(v) flow.nodeDelay = v; cfg.set("flowNodeDelay", v) end })
tabGen:CreateSlider({ Name = "Line Pause", Range = { 0.00, 1.00 }, Increment = 0.10, CurrentValue = flow.lineDelay, Flag = "flowLineDelay", Callback = function(v) flow.lineDelay = v; cfg.set("flowLineDelay", v) end })

------------------------------------------------------------------------
------------------------------------------------------------------------
-- TAB: KILLER
------------------------------------------------------------------------
------------------------------------------------------------------------
local tabKiller = win:CreateTab("Killer", "sword")
tabKiller:CreateSection("Aimbot")

local aim = { on=cfg.get("aimOn",false), cooldown=cfg.get("aimCooldown",0.3), lockTime=cfg.get("aimLockTime",0.4), maxDist=cfg.get("aimMaxDist",30), smooth=cfg.get("aimSmooth",0.35), targeting=false, target=nil, deathConn=nil, autoRotate=nil, lastFired=0, hum=nil, hrp=nil, cache={}, cacheTime=0, cacheLife=0.5 }
local function aimAmIKiller() local ch=lp.Character; if not ch then return false end; local kf=getTeamFolder("Killers"); return kf and ch:IsDescendantOf(kf) end
local function aimRefreshChar(ch) aim.hum=ch:FindFirstChildOfClass("Humanoid"); aim.hrp=ch:FindFirstChild("HumanoidRootPart") end
local function aimRefreshTargets() local now=tick(); if now-aim.cacheTime<aim.cacheLife then return end; aim.cacheTime=now; aim.cache={}; local sf=getTeamFolder("Survivors"); if not sf then return end; for _,model in ipairs(sf:GetChildren()) do if model~=lp.Character and model:IsA("Model") then local h=model:FindFirstChildOfClass("Humanoid"); local r=model:FindFirstChild("HumanoidRootPart"); if h and r and h.Health>0 then table.insert(aim.cache,r) end end end end
local function aimNearest() aimRefreshTargets(); if not aim.hrp or #aim.cache==0 then return nil end; local best,bd=nil,math.huge; for _,r in ipairs(aim.cache) do local d=(r.Position-aim.hrp.Position).Magnitude; if d<bd and d<=aim.maxDist then bd=d; best=r end end; return best end
local function aimUnlock() if not aim.targeting then return end; if aim.deathConn then aim.deathConn:Disconnect(); aim.deathConn=nil end; if aim.autoRotate~=nil and aim.hum then aim.hum.AutoRotate=aim.autoRotate end; aim.targeting=false; aim.target=nil end
local function aimLock(r) if not r or not r.Parent or not aim.hum or not aim.hrp then return end; if aim.targeting and aim.target==r then return end; aimUnlock(); aim.target=r; aim.targeting=true; aim.autoRotate=aim.hum.AutoRotate; aim.hum.AutoRotate=false; local th=r.Parent:FindFirstChildOfClass("Humanoid"); if th then aim.deathConn=th.Died:Connect(aimUnlock) end; task.delay(aim.lockTime, function() if aim.target==r then aimUnlock() end end) end
svc.Run.RenderStepped:Connect(function() if not aim.on or not aim.targeting or not aim.hrp or not aim.target then return end; if not aim.target.Parent then aimUnlock(); return end; local th=aim.target.Parent:FindFirstChildOfClass("Humanoid"); if not th or th.Health<=0 then aimUnlock(); return end; local dx=aim.target.Position.X-aim.hrp.Position.X; local dz=aim.target.Position.Z-aim.hrp.Position.Z; local mag=math.sqrt(dx*dx+dz*dz); if mag>0 then local flat=Vector3.new(dx/mag,0,dz/mag); aim.hrp.CFrame=aim.hrp.CFrame:Lerp(CFrame.new(aim.hrp.Position,aim.hrp.Position+flat),aim.smooth) end end)
task.spawn(function() local remote = hbGetRemote(); if not remote then return end; remote.OnClientEvent:Connect(function(...) if not aim.on then return end; local a={...}; if typeof(a[1])~="string" then return end; local n=a[1]; if not (n:match("Ability") or n:match("[QER]") or n=="Slash" or n=="Dagger" or n=="Charge") then return end; if tick()-aim.lastFired<aim.cooldown then return end; aim.lastFired=tick(); if aimAmIKiller() then local t=aimNearest(); if t then aimLock(t) end end end) end)
lp.CharacterAdded:Connect(function(ch) task.wait(0.5); aimRefreshChar(ch) end)
if lp.Character then aimRefreshChar(lp.Character) end
tabKiller:CreateToggle({ Name="Enable Aimbot", CurrentValue=aim.on, Flag="aimOn", Callback=function(on) aim.on=on; cfg.set("aimOn",on); if not on then aimUnlock() end end })
tabKiller:CreateSlider({ Name="Cooldown (s)", Range={0.1, 2.0}, Increment=0.05, CurrentValue=aim.cooldown, Flag="aimCooldown", Callback=function(v) aim.cooldown=v; cfg.set("aimCooldown",v) end })
tabKiller:CreateSlider({ Name="Lock Time (s)", Range={0.1, 3.0}, Increment=0.1, CurrentValue=aim.lockTime, Flag="aimLockTime", Callback=function(v) aim.lockTime=v; cfg.set("aimLockTime",v) end })
tabKiller:CreateSlider({ Name="Max Distance", Range={5, 100}, Increment=5, CurrentValue=aim.maxDist, Flag="aimMaxDist", Callback=function(v) aim.maxDist=v; cfg.set("aimMaxDist",v) end })
tabKiller:CreateSlider({ Name="Rotation Smoothing", Range={0.05, 1.0}, Increment=0.05, CurrentValue=aim.smooth, Flag="aimSmooth", Callback=function(v) aim.smooth=v; cfg.set("aimSmooth",v) end })

tabKiller:CreateSection("Anti-Backstab")
local abs = { on=cfg.get("absOn",false), range=cfg.get("absRange",40), duration=cfg.get("absDur",1.5), locked=false, soundConn=nil, scanThread=nil, rings={} }
local absTriggerSounds = { ["86710781315432"]=true, ["99820161736138"]=true }
-- (abs functions kept compact for length)
local function absTrigger()
    if abs.locked then return end; local ch=lp.Character; local myRoot=ch and ch:FindFirstChild("HumanoidRootPart"); if not myRoot then return end
    local ttModel = nil; local players=svc.WS:FindFirstChild("Players"); if players then for _,folder in ipairs(players:GetChildren()) do local tt=folder:FindFirstChild("TwoTime"); if tt then ttModel=tt; break end end end
    if not ttModel then return end; local ttRoot=ttModel:FindFirstChild("HumanoidRootPart"); if not ttRoot then return end
    if (myRoot.Position-ttRoot.Position).Magnitude>abs.range then return end
    abs.locked=true
    task.spawn(function() local deadline=tick()+abs.duration; while tick()<deadline do if not abs.on then break end; local ch2=lp.Character; local r2=ch2 and ch2:FindFirstChild("HumanoidRootPart"); if not r2 or not ttRoot.Parent then break end; r2.CFrame=CFrame.lookAt(r2.Position,Vector3.new(ttRoot.Position.X,r2.Position.Y,ttRoot.Position.Z)); svc.Run.RenderStepped:Wait() end; abs.locked=false end)
end
local function absHookSounds() if abs.soundConn then abs.soundConn:Disconnect(); abs.soundConn=nil end; abs.soundConn=svc.WS.DescendantAdded:Connect(function(obj) if not abs.on or not obj:IsA("Sound") then return end; local id=obj.SoundId:match("%d+"); if id and absTriggerSounds[id] then absTrigger() end end) end
local function absStart() absHookSounds() end
local function absStop() abs.on=false; if abs.soundConn then abs.soundConn:Disconnect(); abs.soundConn=nil end; abs.locked=false end
lp.CharacterAdded:Connect(function() abs.locked=false; if abs.on then absStart() end end)
tabKiller:CreateToggle({ Name="Enable Anti-Backstab", CurrentValue=abs.on, Flag="absOn", Callback=function(on) abs.on=on; cfg.set("absOn",on); if on then absStart() else absStop() end end })
tabKiller:CreateSlider({ Name="Detection Range", Range={10,120}, Increment=5, CurrentValue=abs.range, Flag="absRange", Callback=function(v) abs.range=v; cfg.set("absRange",v) end })
tabKiller:CreateSlider({ Name="Look Duration (s)", Range={0.3,5.0}, Increment=0.1, CurrentValue=abs.duration, Flag="absDur", Callback=function(v) abs.duration=v; cfg.set("absDur",v) end })

-- Sixer Air Strafe
local sixerStrafeOn = cfg.get("sixerStrafeOn", false)
svc.Run:BindToRenderStep("V1PRWARESixerStrafe", Enum.RenderPriority.Character.Value + 2, function()
    if not sixerStrafeOn then return end; local char = lp.Character; if not char then return end
    if char:GetAttribute("PursuitState") ~= "Dashing" then return end
    local hrp = char:FindFirstChild("HumanoidRootPart"); local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end; if hum.FloorMaterial ~= Enum.Material.Air then return end
    local cam = svc.WS.CurrentCamera; local flat = cam.CFrame.LookVector * Vector3.new(1, 0, 1)
    if flat.Magnitude < 0.01 then return end; flat = flat.Unit
    local vel = hrp.AssemblyLinearVelocity; local hVel = Vector3.new(vel.X, 0, vel.Z); local hSpeed = hVel.Magnitude
    if hSpeed < 0.1 then return end; local newH = hVel:Lerp(flat * hSpeed, 1)
    hrp.AssemblyLinearVelocity = Vector3.new(newH.X, vel.Y, newH.Z)
end)

-- c00lkidd Dash Turn
local coolkidWSOOn = cfg.get("coolkidWSOOn", false)
local function coolkidGetInputDir()
    local cf = svc.WS.CurrentCamera.CFrame; local fwd = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z).Unit; local right = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z).Unit; local dir = Vector3.zero
    if svc.Input:IsKeyDown(Enum.KeyCode.W) then dir += fwd end; if svc.Input:IsKeyDown(Enum.KeyCode.S) then dir -= fwd end
    if svc.Input:IsKeyDown(Enum.KeyCode.A) then dir -= right end; if svc.Input:IsKeyDown(Enum.KeyCode.D) then dir += right end
    return dir.Magnitude > 0 and dir.Unit or nil
end
svc.Run:BindToRenderStep("CoolkidWSO", Enum.RenderPriority.Character.Value + 1, function()
    if not coolkidWSOOn then return end; local char = lp.Character; if not char then return end
    if char:GetAttribute("PursuitState") ~= "Dashing" then return end
    local hrp = char:FindFirstChild("HumanoidRootPart"); local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end; local inputDir = coolkidGetInputDir(); if not inputDir then return end
    local vel = hrp.AssemblyLinearVelocity; local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
    if speed < 0.1 then return end; hrp.AssemblyLinearVelocity = Vector3.new(inputDir.X * speed, vel.Y, inputDir.Z * speed)
    hum.WalkSpeed = 60; hum.AutoRotate = false
    local horiz = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z); if horiz.Magnitude > 0 then hum:Move(horiz.Unit) end
end)

-- Noli Void Rush Control
local noliVoidRushOn = cfg.get("noliVoidRushOn", false); local noliOverrideActive = false; local noliOrigWalkSpeed = nil; local noliOrigAutoRotate = nil
local function noliStart()
    if noliOverrideActive then return end; noliOverrideActive = true; local char = lp.Character; if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart"); local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then noliOverrideActive = false; return end; noliOrigWalkSpeed = hum.WalkSpeed; noliOrigAutoRotate = hum.AutoRotate
    svc.Run:BindToRenderStep("NoliVoidRush", Enum.RenderPriority.Character.Value + 3, function()
        if not noliOverrideActive then svc.Run:UnbindFromRenderStep("NoliVoidRush"); return end
        local ch2 = lp.Character; if not ch2 then return end; local hrp2 = ch2:FindFirstChild("HumanoidRootPart"); local hum2 = ch2:FindFirstChildOfClass("Humanoid")
        if not hrp2 or not hum2 then return end; hum2.WalkSpeed = 60; hum2.AutoRotate = false
        local horiz = Vector3.new(hrp2.CFrame.LookVector.X, 0, hrp2.CFrame.LookVector.Z); if horiz.Magnitude > 0 then hum2:Move(horiz.Unit) end
    end)
end
local function noliStop()
    if not noliOverrideActive then return end; noliOverrideActive = false; svc.Run:UnbindFromRenderStep("NoliVoidRush")
    local char = lp.Character; if not char then return end; local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
    if noliOrigWalkSpeed ~= nil then hum.WalkSpeed = noliOrigWalkSpeed end; if noliOrigAutoRotate ~= nil then hum.AutoRotate = noliOrigAutoRotate end
    noliOrigWalkSpeed = nil; noliOrigAutoRotate = nil
end
svc.Run.RenderStepped:Connect(function() if not noliVoidRushOn then if noliOverrideActive then noliStop() end; return end; local char = lp.Character; if not char then return end; if char:GetAttribute("VoidRushState") == "Dashing" then noliStart() else noliStop() end end)
lp.CharacterAdded:Connect(function() noliStop(); noliOrigWalkSpeed = nil end)

tabKiller:CreateSection("Killer Abilities")
tabKiller:CreateToggle({ Name="Sixer — Air Strafe", CurrentValue=sixerStrafeOn, Flag="sixerStrafeOn", Callback=function(on) sixerStrafeOn=on; cfg.set("sixerStrafeOn",on) end })
tabKiller:CreateToggle({ Name="c00lkidd — Dash Turn", CurrentValue=coolkidWSOOn, Flag="coolkidWSOOn", Callback=function(on) coolkidWSOOn=on; cfg.set("coolkidWSOOn",on) end })
tabKiller:CreateToggle({ Name="Noli — Void Rush Control", CurrentValue=noliVoidRushOn, Flag="noliVoidRushOn", Callback=function(on) noliVoidRushOn=on; cfg.set("noliVoidRushOn",on); if not on then noliStop() end end })

------------------------------------------------------------------------
------------------------------------------------------------------------
-- TAB: VISUAL (ESP) - compact but complete
------------------------------------------------------------------------
------------------------------------------------------------------------
local tabVisual = win:CreateTab("Visual", "eye")
tabVisual:CreateSection("ESP")
local function loadColor(key, dr, dg, db) return Color3.fromRGB(cfg.get(key.."R", dr), cfg.get(key.."G", dg), cfg.get(key.."B", db)) end
local espColors = { killer = loadColor("espColKiller", 139, 0, 0), survivor = loadColor("espColSurvivor", 34, 139, 34), generator = loadColor("espColGen", 255, 105, 180), medkit = loadColor("espColMedkit", 0, 255, 255), bloxycola = loadColor("espColBloxy", 255, 165, 0), building = loadColor("espColBuilding", 255, 80, 0) }
local function saveColor(key, col) cfg.set(key.."R", math.floor(col.R * 255)); cfg.set(key.."G", math.floor(col.G * 255)); cfg.set(key.."B", math.floor(col.B * 255)) end
local function espItemColor(name) local n = name:lower(); if n:find("medkit") then return espColors.medkit end; if n:find("bloxycola") then return espColors.bloxycola end; return Color3.fromRGB(0, 230, 230) end
local function espItemHeld(obj) for _, plr in ipairs(svc.Players:GetPlayers()) do local ch = plr.Character; if ch and obj:IsDescendantOf(ch) then return true end; local bp = plr:FindFirstChildOfClass("Backpack"); if bp and obj:IsDescendantOf(bp) then return true end end; return false end
local esp = { killers = cfg.get("espKillers", false), survivors = cfg.get("espSurvivors", false), generators = cfg.get("espGenerators", false), items = cfg.get("espItems", false), buildings = cfg.get("espBuildings", false), killerFolder = nil, survivorFolder = nil, mapFolder = nil, playerConns = {}, mapConns = {}, healthConns = setmetatable({}, {__mode = "k"}), progConns = setmetatable({}, {__mode = "k"}), guardConns = setmetatable({}, {__mode = "k"}), ready = false }
local espAttach, espDetach
espAttach = function(obj, tag, color, isChar)
    if not obj or not obj.Parent then return end
    pcall(function() local oldHl = obj:FindFirstChild(tag); local oldBb = obj:FindFirstChild(tag .. "_bb"); if oldHl then oldHl:Destroy() end; if oldBb then oldBb:Destroy() end end)
    if esp.guardConns[obj] then pcall(function() esp.guardConns[obj]:Disconnect() end); esp.guardConns[obj] = nil end
    if esp.healthConns[obj] then pcall(function() esp.healthConns[obj]:Disconnect() end); esp.healthConns[obj] = nil end
    if esp.progConns[obj] then pcall(function() esp.progConns[obj]:Disconnect() end); esp.progConns[obj] = nil end
    local root; if isChar then root = obj:FindFirstChild("HumanoidRootPart") else root = obj.PrimaryPart or obj:FindFirstChild("Base") or obj:FindFirstChild("Main"); if not root then for _, child in ipairs(obj:GetChildren()) do if child:IsA("BasePart") then root = child; break end end end; if not root and obj:IsA("BasePart") then root = obj end end
    if not root then return end
    pcall(function()
        local hl = Instance.new("Highlight"); hl.Name = tag; hl.FillColor = color; hl.FillTransparency = 0.8; hl.OutlineColor = color; hl.OutlineTransparency = 0; hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; hl.Adornee = obj; hl.Parent = obj
        local bb = Instance.new("BillboardGui"); bb.Name = tag .. "_bb"; bb.Adornee = root; bb.Size = UDim2.new(0, 100, 0, 20); bb.StudsOffset = Vector3.new(0, isChar and 3.5 or 3.8, 0); bb.AlwaysOnTop = true; bb.MaxDistance = 1000; bb.Parent = obj
        local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.new(1, 0, 1, 0); lbl.BackgroundTransparency = 1; lbl.TextColor3 = color; lbl.TextStrokeTransparency = 0.5; lbl.TextStrokeColor3 = Color3.new(0, 0, 0); lbl.TextSize = 15; lbl.FontFace = Font.new("rbxasset://fonts/families/AccanthisADFStd.json"); lbl.Parent = bb
        if isChar then local hum = obj:FindFirstChildOfClass("Humanoid"); if hum then lbl.Text = obj.Name .. " (100%)"; local c = hum.HealthChanged:Connect(function() if lbl.Parent and hum.MaxHealth > 0 then lbl.Text = obj.Name .. " (" .. math.floor(hum.Health / hum.MaxHealth * 100) .. "%)" end end); esp.healthConns[obj] = c else lbl.Text = obj.Name end
        else local prog = obj:FindFirstChild("Progress"); if prog and prog:IsA("NumberValue") then lbl.Text = math.floor(prog.Value) .. "%"; local c = prog.Changed:Connect(function() if lbl.Parent then lbl.Text = math.floor(prog.Value) .. "%" end end); esp.progConns[obj] = c else lbl.Text = obj.Name end end
    end)
    esp.guardConns[obj] = obj.ChildRemoved:Connect(function(removed) if removed.Name ~= tag and removed.Name ~= (tag .. "_bb") then return end; task.defer(function() if not obj or not obj.Parent then return end; if not isChar and espItemHeld(obj) then return end; espAttach(obj, tag, color, isChar) end) end)
end
espDetach = function(obj, tag) if not obj then return end; if esp.guardConns[obj] then pcall(function() esp.guardConns[obj]:Disconnect() end); esp.guardConns[obj] = nil end; if esp.healthConns[obj] then pcall(function() esp.healthConns[obj]:Disconnect() end); esp.healthConns[obj] = nil end; if esp.progConns[obj] then pcall(function() esp.progConns[obj]:Disconnect() end); esp.progConns[obj] = nil end; pcall(function() local h = obj:FindFirstChild(tag); if h then h:Destroy() end; local b = obj:FindFirstChild(tag .. "_bb"); if b then b:Destroy() end end) end
local function espDoKillers(on) if not esp.killerFolder then return end; for _, k in ipairs(esp.killerFolder:GetChildren()) do if k:IsA("Model") then if on then espAttach(k, "esp_k", espColors.killer, true) else espDetach(k, "esp_k") end end end end
local function espDoSurvivors(on) if not esp.survivorFolder then return end; for _, s in ipairs(esp.survivorFolder:GetChildren()) do if s:IsA("Model") then if on then espAttach(s, "esp_s", espColors.survivor, true) else espDetach(s, "esp_s") end end end end
local function espDoGenerators(on) local map = getMapContent(); if not map then return end; for _, obj in ipairs(map:GetChildren()) do if obj.Name == "Generator" then if on then espAttach(obj, "esp_g", espColors.generator, false) else espDetach(obj, "esp_g") end end end end
local function espDoItems(on) for _, obj in ipairs(svc.WS:GetDescendants()) do if obj.Name == "BloxyCola" or obj.Name == "Medkit" then if not espItemHeld(obj) then if on then espAttach(obj, "esp_i", espItemColor(obj.Name), false) else espDetach(obj, "esp_i") end end end end end
local function espDoBuildings(on) local ig = getIngame(); if not ig then return end; for _, obj in ipairs(ig:GetChildren()) do if obj.Name == "BuildermanSentry" or obj.Name == "SubspaceTripmine" or obj.Name == "BuildermanDispenser" then if on then if not obj:FindFirstChild("esp_b") then espAttach(obj, "esp_b", espColors.building, false) end else espDetach(obj, "esp_b") end end end end
local function espBindPlayers()
    for _, c in pairs(esp.playerConns) do if c.Connected then c:Disconnect() end end; esp.playerConns = {}
    if esp.killerFolder then table.insert(esp.playerConns, esp.killerFolder.ChildAdded:Connect(function(ch) task.defer(function() if esp.killers and ch and ch.Parent and ch:IsA("Model") then espAttach(ch, "esp_k", espColors.killer, true) end end) end)); table.insert(esp.playerConns, esp.killerFolder.ChildRemoved:Connect(function(ch) espDetach(ch, "esp_k") end)) end
    if esp.survivorFolder then table.insert(esp.playerConns, esp.survivorFolder.ChildAdded:Connect(function(ch) task.defer(function() if esp.survivors and ch and ch.Parent and ch:IsA("Model") then espAttach(ch, "esp_s", espColors.survivor, true) end end) end)); table.insert(esp.playerConns, esp.survivorFolder.ChildRemoved:Connect(function(ch) espDetach(ch, "esp_s") end)) end
end
local espMapChildConns = {}
local function espUnbindMapChildren() for _, c in ipairs(espMapChildConns) do if c.Connected then c:Disconnect() end end; espMapChildConns = {} end
local function espBindMapContent(mapObj) espUnbindMapChildren(); esp.mapFolder = mapObj; if esp.generators then espDoGenerators(true) end; if esp.items then espDoItems(true) end; table.insert(espMapChildConns, mapObj.ChildAdded:Connect(function(child) task.defer(function() if esp.generators and child.Name == "Generator" and child.Parent then espAttach(child, "esp_g", espColors.generator, false) end end) end)); table.insert(espMapChildConns, mapObj.ChildRemoved:Connect(function(child) if child.Name == "Generator" then espDetach(child, "esp_g") end end)) end
local function espBindWorld()
    for _, c in pairs(esp.mapConns) do if c.Connected then c:Disconnect() end end; esp.mapConns = {}; local ig = getIngame(); if not ig then return end
    table.insert(esp.mapConns, ig.ChildAdded:Connect(function(obj) task.defer(function() if not obj or not obj.Parent then return end; if esp.buildings and (obj.Name == "BuildermanSentry" or obj.Name == "SubspaceTripmine" or obj.Name == "BuildermanDispenser") then if not obj:FindFirstChild("esp_b") then espAttach(obj, "esp_b", espColors.building, false) end end; if obj.Name == "Map" then task.wait(0.5); espBindMapContent(obj) end end) end))
    table.insert(esp.mapConns, ig.ChildRemoved:Connect(function(obj) if obj.Name == "BuildermanSentry" or obj.Name == "SubspaceTripmine" or obj.Name == "BuildermanDispenser" then espDetach(obj, "esp_b") end; if obj.Name == "Map" then espUnbindMapChildren(); esp.mapFolder = nil end end))
    table.insert(esp.mapConns, svc.WS.DescendantAdded:Connect(function(obj) if not esp.items then return end; if obj.Name ~= "BloxyCola" and obj.Name ~= "Medkit" then return end; task.defer(function() if obj and obj.Parent and not espItemHeld(obj) then espAttach(obj, "esp_i", espItemColor(obj.Name), false) end end) end))
    local existing = getMapContent(); if existing then task.defer(function() task.wait(1); espBindMapContent(existing) end) end
    if esp.buildings then task.defer(function() espDoBuildings(true) end) end
end
tabVisual:CreateToggle({ Name="Killers", CurrentValue=esp.killers, Flag="espKillers", Callback=function(on) esp.killers=on; cfg.set("espKillers",on); espDoKillers(on) end })
tabVisual:CreateToggle({ Name="Survivors", CurrentValue=esp.survivors, Flag="espSurvivors", Callback=function(on) esp.survivors=on; cfg.set("espSurvivors",on); espDoSurvivors(on) end })
tabVisual:CreateToggle({ Name="Generators", CurrentValue=esp.generators, Flag="espGenerators", Callback=function(on) esp.generators=on; cfg.set("espGenerators",on); espDoGenerators(on) end })
tabVisual:CreateToggle({ Name="Items", CurrentValue=esp.items, Flag="espItems", Callback=function(on) esp.items=on; cfg.set("espItems",on); pcall(function() espDoItems(on) end) end })
tabVisual:CreateToggle({ Name="Buildings", CurrentValue=esp.buildings, Flag="espBuildings", Callback=function(on) esp.buildings=on; cfg.set("espBuildings",on); pcall(function() espDoBuildings(on) end) end })

tabVisual:CreateSection("ESP Colors")
tabVisual:CreateColorPicker({ Name = "Killer Color", Color = espColors.killer, Flag = "espColKiller", Callback = function(col) espColors.killer = col; saveColor("espColKiller", col); if esp.killers then espDoKillers(false); espDoKillers(true) end end })
tabVisual:CreateColorPicker({ Name = "Survivor Color", Color = espColors.survivor, Flag = "espColSurvivor", Callback = function(col) espColors.survivor = col; saveColor("espColSurvivor", col); if esp.survivors then espDoSurvivors(false); espDoSurvivors(true) end end })
tabVisual:CreateColorPicker({ Name = "Generator Color", Color = espColors.generator, Flag = "espColGen", Callback = function(col) espColors.generator = col; saveColor("espColGen", col); if esp.generators then espDoGenerators(false); espDoGenerators(true) end end })
tabVisual:CreateColorPicker({ Name = "Item Color", Color = espColors.medkit, Flag = "espColItem", Callback = function(col) espColors.medkit = col; espColors.bloxycola = col; saveColor("espColMedkit", col); saveColor("espColBloxy", col); if esp.items then espDoItems(false); espDoItems(true) end end })
tabVisual:CreateColorPicker({ Name = "Building Color", Color = espColors.building, Flag = "espColBuilding", Callback = function(col) espColors.building = col; saveColor("espColBuilding", col); if esp.buildings then espDoBuildings(false); espDoBuildings(true) end end })

-- Minion ESP (compact)
tabVisual:CreateSection("Minion & Ability ESP")
local mset = { pizza=cfg.get("espPizza",false), zombie=cfg.get("espZombie",false), puddle=cfg.get("espPuddle",false), transparency=cfg.get("espMinionTrans",0.25) }
local tracked = { pizza={}, zombie={}, puddle={} }
local function isRealPlayer(obj) for _, plr in ipairs(svc.Players:GetPlayers()) do if plr.Character == obj then return true end; if plr.Character and obj:IsDescendantOf(plr.Character) then return true end end; return false end
local function addHighlight(obj, color, tag, label, offset) if not obj or tracked[tag][obj] then return end; if isRealPlayer(obj) then return end; tracked[tag][obj] = true; local root = obj; if obj:IsA("Model") then root = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso") or obj.PrimaryPart; if not root then for _, child in ipairs(obj:GetChildren()) do if child:IsA("BasePart") then root=child; break end end end end; local hl = Instance.new("Highlight"); hl.Name=tag.."_HL"; hl.FillColor=color; hl.FillTransparency=mset.transparency; hl.OutlineColor=color; hl.OutlineTransparency=0.1; hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; hl.Adornee=obj; hl.Parent=obj; if root then local bb = Instance.new("BillboardGui"); bb.Name=tag.."_BB"; bb.Adornee=root; bb.Size=UDim2.new(0,130,0,24); bb.StudsOffset=Vector3.new(0,offset or 3,0); bb.AlwaysOnTop=true; bb.Parent=obj; local lbl = Instance.new("TextLabel"); lbl.Size=UDim2.new(1,0,1,0); lbl.BackgroundTransparency=1; lbl.Text=label; lbl.TextColor3=color; lbl.TextStrokeColor3=Color3.new(0,0,0); lbl.TextStrokeTransparency=0.2; lbl.TextSize=12; lbl.Font=Enum.Font.GothamBold; lbl.Parent=bb end; local conn; conn = obj.AncestryChanged:Connect(function() if obj.Parent then return end; conn:Disconnect(); hl:Destroy(); local bb=obj:FindFirstChild(tag.."_BB"); if bb then bb:Destroy() end; tracked[tag][obj] = nil end) end
local function clearTag(tag) for obj in pairs(tracked[tag]) do local hl=obj:FindFirstChild(tag.."_HL"); if hl then hl:Destroy() end; local bb=obj:FindFirstChild(tag.."_BB"); if bb then bb:Destroy() end end; tracked[tag]={} end
local function scanPizza() if not mset.pizza then return end; for _,obj in ipairs(svc.WS:GetDescendants()) do if obj.Name=="PizzaDeliveryRig" and obj:IsA("Model") and not isRealPlayer(obj) and not tracked.pizza[obj] then addHighlight(obj,Color3.fromRGB(255,100,0),"pizza","C00LKIDD PIZZA DELIVERY",3) end end end
local function scanZombie() if not mset.zombie then return end; for _,obj in ipairs(svc.WS:GetDescendants()) do if obj.Name=="1x1x1x1Zombie" and obj:IsA("Model") and not isRealPlayer(obj) and not tracked.zombie[obj] then addHighlight(obj,Color3.fromRGB(80,255,120),"zombie","1X1X1X1 ZOMBIE",3) end end end
local function setupMinionWatcher() svc.WS.DescendantAdded:Connect(function(obj) task.defer(function() if not obj or not obj.Parent then return end; if mset.pizza and obj.Name=="PizzaDeliveryRig" and obj:IsA("Model") and not isRealPlayer(obj) and not tracked.pizza[obj] then addHighlight(obj,Color3.fromRGB(255,100,0),"pizza","C00LKIDD PIZZA DELIVERY",3) end; if mset.zombie and obj.Name=="1x1x1x1Zombie" and obj:IsA("Model") and not isRealPlayer(obj) and not tracked.zombie[obj] then addHighlight(obj,Color3.fromRGB(80,255,120),"zombie","1X1X1X1 ZOMBIE",3) end end) end) end
task.spawn(function() task.wait(3); local pf = svc.WS:FindFirstChild("Players"); if pf then esp.killerFolder = pf:FindFirstChild("Killers"); esp.survivorFolder = pf:FindFirstChild("Survivors"); espBindPlayers(); if esp.killers then espDoKillers(true) end; if esp.survivors then espDoSurvivors(true) end end; espBindWorld(); setupMinionWatcher(); if mset.pizza then scanPizza() end; if mset.zombie then scanZombie() end; esp.ready = true end)
lp.CharacterAdded:Connect(function() task.wait(4); local pf = svc.WS:FindFirstChild("Players"); if pf then esp.killerFolder = pf:FindFirstChild("Killers"); esp.survivorFolder = pf:FindFirstChild("Survivors") end; espBindPlayers(); espBindWorld(); if esp.killers then espDoKillers(true) end; if esp.survivors then espDoSurvivors(true) end; if esp.generators then espDoGenerators(true) end; if esp.items then espDoItems(true) end; if esp.buildings then espDoBuildings(true) end; if mset.pizza then scanPizza() end; if mset.zombie then scanZombie() end end)
tabVisual:CreateToggle({ Name="c00lkidd Pizza Bots", CurrentValue=mset.pizza, Flag="espPizza", Callback=function(on) mset.pizza=on; cfg.set("espPizza",on); if on then scanPizza() else clearTag("pizza") end end })
tabVisual:CreateToggle({ Name="1x1x1x1 Zombies", CurrentValue=mset.zombie, Flag="espZombie", Callback=function(on) mset.zombie=on; cfg.set("espZombie",on); if on then scanZombie() else clearTag("zombie") end end })

------------------------------------------------------------------------
------------------------------------------------------------------------
-- TAB: MUSIC
------------------------------------------------------------------------
------------------------------------------------------------------------
local tabMusic = win:CreateTab("Music", "music")
tabMusic:CreateSection("LMS Music")
local music = { on=cfg.get("musicOn",false), selected=cfg.get("musicSel","CondemnedLMS"), cached={}, origId=nil, thread=nil }
local musicDir = "V1PRWARE/LMS_Songs"; if not fs.hasFolder("V1PRWARE") then fs.makeFolder("V1PRWARE") end; if not fs.hasFolder(musicDir) then fs.makeFolder(musicDir) end
local musicTracks = { ["AbberantLMS"] = "https://files.catbox.moe/4bb0g9.mp3", ["OvertimeLMS"] = "https://files.catbox.moe/puf7xu.mp3", ["CondemnedLMS"] = "https://files.catbox.moe/l470am.mp3" }
local musicList = {}; for k in pairs(musicTracks) do table.insert(musicList, k) end; table.sort(musicList)
local function musicFetch(name) if music.cached[name] then return music.cached[name] end; local url=musicTracks[name]; if not url then return nil end; local path=musicDir.."/"..name:gsub("[^%w]","_")..".mp3"; if not fs.hasFile(path) then local ok,data=pcall(function() return game:HttpGet(url) end); if not ok or not data or #data==0 then return nil end; fs.write(path,data) end; music.cached[name]=fs.asset(path); return music.cached[name] end
local function musicGetSound() local t = svc.WS:FindFirstChild("Themes"); if not t then return nil end; return t:FindFirstChild("LastSurvivor") or t:FindFirstChild("LastSurvivor", true) end
local function musicPlay(name) local snd=musicGetSound(); if not snd then return false end; if not music.origId then music.origId=snd.SoundId end; local asset=musicFetch(name); if not asset then return false end; snd.SoundId=asset; snd:Stop(); task.wait(); snd:Play(); return true end
local function musicReset() local snd=musicGetSound(); if snd and music.origId then snd.SoundId=music.origId; snd:Stop(); task.wait(); snd:Play() end end
local function musicIsLMS() local sf=getTeamFolder("Survivors"); if sf then local alive=0; for _,s in ipairs(sf:GetChildren()) do local h=s:FindFirstChildOfClass("Humanoid"); if h and h.Health>0 then alive+=1 end end; if alive==1 then return true end end; local snd=musicGetSound(); return snd and snd.IsPlaying and (not music.origId or snd.SoundId~=music.origId) end
local function musicMonitor() local i=0; while music.on and i<2000 do i+=1; if musicIsLMS() then local snd=musicGetSound(); if not snd or not snd.IsPlaying or snd.SoundId~=(music.cached[music.selected] or "") then musicPlay(music.selected) end; task.wait(3) else task.wait(1) end end end
tabMusic:CreateToggle({ Name="Auto-Play on LMS", CurrentValue=music.on, Flag="musicOn", Callback=function(on) music.on=on; cfg.set("musicOn",on); if on then music.thread=task.spawn(musicMonitor) else if music.thread then task.cancel(music.thread); music.thread=nil end; musicReset() end end })
tabMusic:CreateDropdown({ Name="Track", Options=musicList, CurrentOption=music.selected, Flag="musicSel", Callback=function(sel) music.selected=type(sel)=="table" and sel[1] or sel; cfg.set("musicSel",music.selected); task.spawn(function()musicFetch(music.selected)end) end })
tabMusic:CreateButton({ Name="Play", Callback=function() musicPlay(music.selected) end })
tabMusic:CreateButton({ Name="Stop", Callback=function() musicReset() end })

------------------------------------------------------------------------
------------------------------------------------------------------------
-- TAB: SENTINELS (with Guest1337 + 

 + HDT from V1rpblock 2.0)
------------------------------------------------------------------------
------------------------------------------------------------------------
local tabSurSen = win:CreateTab("Sentinels", "shield")

tabSurSen:CreateSection("Survivors")

-- Elliot Aimbot (compact)
do
    tabSurSen:CreateSection("Elliot Aimbot")
    local elliotEnabled = false; local elliotConnection = nil; local elliotAutoRotBak = nil; local elliotPredDist = 5; local elliotVelThresh = 16; local elliotAimType = "Camera + Character"; local elliotThrowDur = 0.5; local elliotIsThrowing = false; local elliotThrowTS = 0; local elliotRequireAnim = true; local elliotHum, elliotHRP = nil, nil; local elliotCamera = svc.WS.CurrentCamera
    local function elliotSetupChar(char) elliotHum = char:FindFirstChild("Humanoid"); elliotHRP = char:FindFirstChild("HumanoidRootPart") end
    if lp.Character then elliotSetupChar(lp.Character) end; lp.CharacterAdded:Connect(function(c) elliotSetupChar(c) end)
    task.spawn(function() local ok, re = pcall(function() return svc.RS:WaitForChild("Modules",5):WaitForChild("Network",5):WaitForChild("RemoteEvent",5) end); if ok and re then local oldNC; oldNC = hookmetamethod(game,"__namecall",function(self,...) local method = getnamecallmethod(); local args = {...}; if method=="FireServer" and self==re then if args[1]=="UseActorAbility" and args[2] and args[2][1] then local ok2, bs = pcall(function() return buffer.tostring(args[2][1]) end); if ok2 and bs and string.find(bs,"ThrowPizza") then elliotIsThrowing = true; elliotThrowTS = tick() end end end; return oldNC(self,...) end) end end)
    local function elliotFindTarget() local sf = svc.WS:FindFirstChild("Players") and svc.WS.Players:FindFirstChild("Survivors"); if not sf then sf = svc.WS:FindFirstChild("Survivors") end; if not sf or not elliotHRP then return nil end; local best, bestHP = nil, math.huge; for _, s in ipairs(sf:GetChildren()) do if s ~= lp.Character then local h = s:FindFirstChildOfClass("Humanoid"); local r = s:FindFirstChild("HumanoidRootPart"); if h and r and h.Health > 0 and h.Health < bestHP then best = r; bestHP = h.Health end end end; return best end
    local function elliotAimAt(tgt) if not tgt or not tgt.Parent then return end; local vel = tgt.AssemblyLinearVelocity; local pos = tgt.Position; local predPos = pos + (tgt.CFrame.LookVector * 2); if vel.Magnitude > elliotVelThresh then predPos = predPos + (vel.Unit * elliotPredDist) end; if elliotAimType == "HRP Aimbot" or elliotAimType == "Camera + Character" then if elliotHRP then if not elliotAutoRotBak then elliotAutoRotBak = elliotHum.AutoRotate end; elliotHum.AutoRotate = false; elliotHRP.AssemblyAngularVelocity = Vector3.new(0,0,0); local dir = (predPos - elliotHRP.Position); local flat = Vector3.new(dir.X,0,dir.Z).Unit; local tCF = CFrame.new(elliotHRP.Position, elliotHRP.Position + flat); local cur = elliotHRP.CFrame; local nCF = cur:Lerp(tCF, 0.35); elliotHRP.CFrame = CFrame.new(cur.Position) * (nCF - nCF.Position) end end; if elliotAimType == "Camera Aimbot" or elliotAimType == "Camera + Character" then elliotCamera.CFrame = CFrame.lookAt(elliotCamera.CFrame.Position, predPos) end end
    tabSurSen:CreateToggle({ Name="Enable Elliot Aimbot", CurrentValue=false, Callback=function(v) elliotEnabled = v; if v then elliotConnection = svc.Run.RenderStepped:Connect(function() if not elliotEnabled or not elliotHum or not elliotHRP then return end; if elliotIsThrowing and (tick()-elliotThrowTS)>elliotThrowDur then elliotIsThrowing=false end; local shouldAim = elliotRequireAnim and elliotIsThrowing or (not elliotRequireAnim); if not shouldAim then if elliotAutoRotBak ~= nil then elliotHum.AutoRotate=elliotAutoRotBak; elliotAutoRotBak=nil end; return end; local tgt = elliotFindTarget(); if not tgt then if elliotAutoRotBak ~= nil then elliotHum.AutoRotate=elliotAutoRotBak; elliotAutoRotBak=nil end; return end; elliotAimAt(tgt) end) else if elliotConnection then elliotConnection:Disconnect(); elliotConnection=nil end; if elliotAutoRotBak ~= nil then elliotHum.AutoRotate=elliotAutoRotBak; elliotAutoRotBak=nil end end end })
    tabSurSen:CreateSlider({ Name="Prediction Studs", Range={0,50}, Increment=1, CurrentValue=5, Callback=function(v) elliotPredDist=v end })
    tabSurSen:CreateSlider({ Name="Aim Duration (s)", Range={0.1,2}, Increment=0.1, CurrentValue=0.5, Callback=function(v) elliotThrowDur=v end })
    tabSurSen:CreateToggle({ Name="Require Throw Animation", CurrentValue=true, Callback=function(v) elliotRequireAnim=v end })
end

------------------------------------------------------------------------
-- SENTINELS (Guest1337 + Combat Features) - HDT activates on SOUNDS (same as AB)
------------------------------------------------------------------------
tabSurSen:CreateSection("Sentinels")

-- Combat Settings
local combatS = {
    autoBlockOn = cfg.get("combatABOn", false), blockType = cfg.get("combatBlockType", "Block"),
    detectionRange = cfg.get("combatDetectRange", 18), blockDelay = cfg.get("combatBlockDelay", 0),
    facingCheck = cfg.get("combatFacingCheck", true), doubleBlock = cfg.get("combatDoubleBlock", true),
    antiBait = cfg.get("combatAntiBait", false), abMissChance = cfg.get("combatABMiss", 0),
    autoPunchOn = cfg.get("combatAutoPunch", false),
    hdtEnabled = cfg.get("combatHDT", false), hdtSpeed = cfg.get("combatHDTSpeed", 12),
    hdtDelay = cfg.get("combatHDTDelay", 0), hdtMissChance = cfg.get("combatHDTMiss", 0),
    killerCircles = cfg.get("combatCircles", false), facingVisual = cfg.get("combatFacingVis", false),
}

-- Sound IDs for Auto Block
local TRIGGER_SOUNDS = {
    ["102228729296384"]=true,["140242176732868"]=true,["112809109188560"]=true,["136323728355613"]=true,
    ["115026634746636"]=true,["84116622032112"]=true,["108907358619313"]=true,["127793641088496"]=true,
    ["86174610237192"]=true,["95079963655241"]=true,["101199185291628"]=true,["119942598489800"]=true,
    ["84307400688050"]=true,["113037804008732"]=true,["105200830849301"]=true,["75330693422988"]=true,
    ["82221759983649"]=true,["109348678063422"]=true,["81702359653578"]=true,["85853080745515"]=true,
    ["108610718831698"]=true,["112395455254818"]=true,["109431876587852"]=true,["12222216"]=true,
    ["79980897195554"]=true,["119583605486352"]=true,["71834552297085"]=true,["116581754553533"]=true,
    ["86833981571073"]=true,["110372418055226"]=true,["105840448036441"]=true,["86494585504534"]=true,
    ["80516583309685"]=true,["131406927389838"]=true,["89004992452376"]=true,["117231507259853"]=true,
    ["101698569375359"]=true,["101553872555606"]=true,["140412278320643"]=true,["106300477136129"]=true,
    ["117173212095661"]=true,["104910828105172"]=true,["140194172008986"]=true,["85544168523099"]=true,
    ["114506382930939"]=true,["99829427721752"]=true,["120059928759346"]=true,["104625283622511"]=true,
    ["105316545074913"]=true,["126131675979001"]=true,["82336352305186"]=true,["93366464803829"]=true,
    ["84069821282466"]=true,["128856426573270"]=true,["121954639447247"]=true,["128195973631079"]=true,
    ["124903763333174"]=true,["94317217837143"]=true,["98111231282218"]=true,["119089145505438"]=true,
    ["136728245733659"]=true,["71310583817000"]=true,["107444859834748"]=true,["76959687420003"]=true,
    ["72425554233832"]=true,["96594507550917"]=true,["139996647355899"]=true,["107345261604889"]=true,
    ["127557531826290"]=true,["108651070773439"]=true,["74842815979546"]=true,["124397369810639"]=true,
    ["76467993976301"]=true,["118493324723683"]=true,["78298577002481"]=true,["116527305931161"]=true,
    ["5148302439"]=true,["98675142200448"]=true,["128367348686124"]=true,["71805956520207"]=true,
    ["125213046326879"]=true,["84353899757208"]=true,["103684883268194"]=true,["109246041199659"]=true,
    ["80540530406270"]=true,["139523195429581"]=true,["105204810054381"]=true,
}

local BAIT_KILLERS = {"John Doe","Slasher","c00lkidd","Jason","1x1x1x1","Noli","Sixer","Nosferatu"}
local STRICT_FACING_DOT = 0.70

-- Helper functions
local function combatGetKillersFolder() local p = svc.WS:FindFirstChild("Players"); return p and p:FindFirstChild("Killers") end
local function combatGetNearestKiller() local char = lp.Character; if not char then return nil end; local myRoot = char:FindFirstChild("HumanoidRootPart"); if not myRoot then return nil end; local kf = combatGetKillersFolder(); if not kf then return nil end; local best, bestD = nil, math.huge; for _, k in pairs(kf:GetChildren()) do local hrp = k:FindFirstChild("HumanoidRootPart"); if hrp then local d = (hrp.Position - myRoot.Position).Magnitude; if d < bestD then best, bestD = k, d end end end; return best end
local function combatIsFacing(myRoot, targetRoot, killerName) if not combatS.facingCheck then return true end; if not myRoot or not targetRoot then return false end; local diff = myRoot.Position - targetRoot.Position; if diff.Magnitude < 0.01 then return true end; local dir = diff.Unit; local dot = targetRoot.CFrame.LookVector:Dot(dir); local bait = false; if killerName then for _, n in ipairs(BAIT_KILLERS) do if killerName:find(n) then bait = true; break end end end; if bait then local vel = Vector3.zero; pcall(function() vel = targetRoot.AssemblyLinearVelocity end); if vel.Magnitude < 0.01 then pcall(function() vel = targetRoot.Velocity end) end; local side = math.abs(vel:Dot(targetRoot.CFrame.RightVector)); if side > 3 then return false end; return dot > STRICT_FACING_DOT + 0.05 end; return dot > STRICT_FACING_DOT end
local function combatRollMiss(chance) if chance <= 0 then return false end; if chance >= 100 then return true end; return math.random(1, 100) <= chance end
local function combatFireAbility(abilityType) local rem = hbGetRemote(); if not rem then return end; local buf; if abilityType == "Block" then buf = buffer.fromstring("\3\5\0\0\0Block") elseif abilityType == "Punch" then buf = buffer.fromstring("\3\5\0\0\0Punch") elseif abilityType == "Charge" then buf = buffer.fromstring("\3\5\0\0\0Charge") elseif abilityType == "Clone" then buf = buffer.fromstring("\3\5\0\0\0Clone") else buf = buffer.fromstring("\3\5\0\0\0Block") end; pcall(function() rem:FireServer("UseActorAbility", {[1] = buf}) end); pcall(function() rem:FireServer(abilityType) end) end

-- Block cooldown check
local function isBlockReady()
    local mainUI = lp.PlayerGui:FindFirstChild("MainUI")
    if mainUI then local abilityContainer = mainUI:FindFirstChild("AbilityContainer")
        if abilityContainer then local block = abilityContainer:FindFirstChild("Block")
            if block then local cooldownTime = block:FindFirstChild("CooldownTime")
                if cooldownTime and cooldownTime:IsA("TextLabel") then local text = cooldownTime.Text; local num = text:match("[%d%.]+")
                    if num then local val = tonumber(num); if val and val <= 0 then return true else return false end
                    else return true end
                end
            end
        end
    end
    return true
end

-- Auto Block (Audio-based)
local combatTrackedSounds = {}; local combatBlockedUntil = {}; local combatLastBlockTime = 0; local BLOCK_CD = 0.1
local function combatExtractSoundId(sound) return tostring(sound.SoundId):match("%d+") end

-- HDT (activates on SOUNDS, same trigger as AB)
local combatHDTActive = false; local combatHDTLastTime = 0; local HDT_CD = 0.5

local function combatHDTBeginDrag(killerModel)
    if combatHDTActive then return end
    if not killerModel or not killerModel.Parent then return end
    local char = lp.Character; if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart"); local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end
    local tHRP = killerModel:FindFirstChild("HumanoidRootPart"); if not tHRP then return end
    if combatRollMiss(combatS.hdtMissChance) then return end
    combatHDTActive = true; local oldW = hum.WalkSpeed; hum.WalkSpeed = 0
    hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position - hrp.CFrame.LookVector)
    local bv = Instance.new("BodyVelocity"); bv.MaxForce = Vector3.new(1e5, 0, 1e5); bv.Velocity = Vector3.zero; bv.Parent = hrp
    local conn; conn = svc.Run.Heartbeat:Connect(function()
        if not combatHDTActive then conn:Disconnect(); if bv and bv.Parent then bv:Destroy() end; hum.WalkSpeed = oldW; return end
        if not (char and char.Parent) or not (killerModel and killerModel.Parent) then combatHDTActive = false; return end
        local curTHRP = killerModel:FindFirstChild("HumanoidRootPart"); if not curTHRP then combatHDTActive = false; return end
        local to = curTHRP.Position - hrp.Position; local h2 = Vector3.new(to.X, 0, to.Z)
        bv.Velocity = h2.Magnitude > 0.01 and h2.Unit * combatS.hdtSpeed or Vector3.zero
        if to.Magnitude <= 2.0 then combatHDTActive = false end
    end)
    local sw = tick(); if hum then hum.AutoRotate = false end
    while tick() - sw < 0.4 do pcall(function() local nk = combatGetNearestKiller(); if nk and hrp then local tHRP2 = nk:FindFirstChild("HumanoidRootPart"); if tHRP2 then hrp.CFrame = CFrame.lookAt(hrp.Position, tHRP2.Position) end end end); task.wait() end
    if hum then hum.AutoRotate = true end
    task.delay(0.4, function() combatHDTActive = false end)
end

local function combatTriggerHDT(killerModel)
    if not combatS.hdtEnabled or combatHDTActive then return end
    local now = tick(); if now - combatHDTLastTime < HDT_CD then return end
    combatHDTLastTime = now
    task.spawn(function() if combatS.hdtDelay > 0 then task.wait(combatS.hdtDelay) end; combatHDTBeginDrag(killerModel) end)
end

local function combatTryBlock(sound, killerModel)
    local now = tick()
    if combatBlockedUntil[sound] and now < combatBlockedUntil[sound] then return end
    if now - combatLastBlockTime < BLOCK_CD then return end
    local id = combatExtractSoundId(sound); if not id or not TRIGGER_SOUNDS[id] then return end
    if not isBlockReady() then return end  -- CHECK COOLDOWN
    
    local char = lp.Character; if not char then return end
    local myRoot = char:FindFirstChild("HumanoidRootPart"); if not myRoot then return end
    if not killerModel then return end
    local hrp = killerModel:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    if (hrp.Position - myRoot.Position).Magnitude > combatS.detectionRange then return end
    if not combatIsFacing(myRoot, hrp, killerModel.Name) then return end

    if combatS.antiBait then
        local vel = Vector3.zero; pcall(function() vel = hrp.AssemblyLinearVelocity end)
        if vel.Magnitude < 0.1 then pcall(function() vel = hrp.Velocity end) end
        local dist = (hrp.Position - myRoot.Position).Magnitude; local toUs = (myRoot.Position - hrp.Position)
        if toUs.Magnitude > 0.1 then if vel:Dot(toUs.Unit) < -3 then return end end
        if dist > 13 then return end
        if dist > 6 then local sideSpeed = math.abs(vel:Dot(hrp.CFrame.RightVector)); local towardUs = vel:Dot(toUs.Unit); if sideSpeed > 6 and towardUs < 0 then return end end
    end

    if combatRollMiss(combatS.abMissChance) then return end
    combatLastBlockTime = now; combatBlockedUntil[sound] = now + 0.3
    
    local function doFire()
        if combatS.blockType == "Block" then combatFireAbility("Block"); if combatS.doubleBlock then combatFireAbility("Punch") end
        elseif combatS.blockType == "Charge" then combatFireAbility("Charge")
        elseif combatS.blockType == "7n7 Clone" then combatFireAbility("Clone") end
        -- HDT triggers when block fires (only if off cooldown, checked above)
        if combatS.hdtEnabled and killerModel then combatTriggerHDT(killerModel) end
    end
    
    if combatS.blockDelay > 0 then task.delay(combatS.blockDelay, doFire) else doFire() end
end

local function combatRegisterSound(sound)
    if not sound or not sound:IsA("Sound") then return end
    if combatTrackedSounds[sound] then return end
    local id = combatExtractSoundId(sound); if not id or not TRIGGER_SOUNDS[id] then return end
    combatTrackedSounds[sound] = true
    sound.Destroying:Connect(function() combatTrackedSounds[sound] = nil; combatBlockedUntil[sound] = nil end)
end

local function combatSetupSoundWatcher()
    local kf = combatGetKillersFolder(); if not kf then return end
    for _, d in pairs(kf:GetDescendants()) do if d:IsA("Sound") then combatRegisterSound(d) end end
    kf.DescendantAdded:Connect(function(d) if d:IsA("Sound") then combatRegisterSound(d) end end)
end

-- Sound-based detection loop
local function combatSoundTick()
    if not combatS.autoBlockOn then return end
    for sound in pairs(combatTrackedSounds) do
        if not sound or not sound.Parent then combatTrackedSounds[sound] = nil; combatBlockedUntil[sound] = nil
        elseif sound.IsPlaying then
            -- Find killer model from sound
            local killerModel = nil
            local kf = combatGetKillersFolder()
            if kf then
                local soundPart = sound.Parent
                if soundPart and soundPart:IsA("BasePart") then
                    local model = soundPart:FindFirstAncestorOfClass("Model")
                    if model and model:FindFirstChildOfClass("Humanoid") and model:IsDescendantOf(kf) then killerModel = model end
                end
            end
            -- Fallback: use nearest killer
            if not killerModel then killerModel = combatGetNearestKiller() end
            if killerModel then combatTryBlock(sound, killerModel) end
        end
    end
end

-- Detection Circles (flat on floor)
local combatCircles = {}
local function combatUpdateCircles()
    local kf = combatGetKillersFolder(); if not kf then return end
    for _, k in pairs(kf:GetChildren()) do
        local hrp = k:FindFirstChild("HumanoidRootPart")
        if hrp then
            if combatS.killerCircles then
                if not combatCircles[k] then
                    pcall(function()
                        local c = Instance.new("CylinderHandleAdornment")
                        c.Name="CombatCircle"; c.Adornee=hrp
                        c.Color3=Color3.fromRGB(255,140,170); c.AlwaysOnTop=true; c.ZIndex=1; c.Transparency=0.6
                        c.Radius=combatS.detectionRange; c.Height=0.05
                        c.CFrame=CFrame.new(0,-hrp.Size.Y/2,0)  -- Flat on the floor, no rotation
                        c.Parent=hrp; combatCircles[k]=c
                    end)
                else
                    combatCircles[k].Radius = combatS.detectionRange
                end
            else
                if combatCircles[k] then combatCircles[k]:Destroy(); combatCircles[k]=nil end
            end
        end
    end
    for k, c in pairs(combatCircles) do
        if not k.Parent or not k:FindFirstChild("HumanoidRootPart") then
            pcall(function() c:Destroy() end); combatCircles[k]=nil
        end
    end
end

-- Facing Visual
local combatFacingVisuals = {}
local function combatUpdateFacing()
    local kf = combatGetKillersFolder(); if not kf then return end
    local myRoot = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    for _, k in pairs(kf:GetChildren()) do local hrp = k:FindFirstChild("HumanoidRootPart")
        if hrp then
            if combatS.facingVisual then
                if not combatFacingVisuals[k] then pcall(function() local v = Instance.new("CylinderHandleAdornment"); v.Name="FacingVis"; v.Adornee=hrp; v.AlwaysOnTop=true; v.ZIndex=2; v.Transparency=0.55; v.Color3=Color3.fromRGB(120,255,120); v.Parent=hrp; combatFacingVisuals[k]=v end) end
                local vis = combatFacingVisuals[k]
                if vis and vis.Parent then local inRange, facing = false, false
                    if myRoot then inRange = (hrp.Position - myRoot.Position).Magnitude <= combatS.detectionRange; if inRange then facing = combatIsFacing(myRoot, hrp, k.Name) end end
                    if inRange and facing then vis.Color3=Color3.fromRGB(120,255,120); vis.Transparency=0.3
                    elseif inRange then vis.Color3=Color3.fromRGB(255,120,120); vis.Transparency=0.6
                    else vis.Color3=Color3.fromRGB(255,255,120); vis.Transparency=0.85 end
                end
            else if combatFacingVisuals[k] then combatFacingVisuals[k]:Destroy(); combatFacingVisuals[k]=nil end
            end
        end
    end
end

-- Main loops
local combatSoundTickConn = nil; local combatVisualTickConn = nil
local function combatStartLoops()
    if combatSoundTickConn then combatSoundTickConn:Disconnect() end
    combatSoundTickConn = svc.Run.Heartbeat:Connect(combatSoundTick)
    if combatVisualTickConn then combatVisualTickConn:Disconnect() end
    combatVisualTickConn = svc.Run.Heartbeat:Connect(function() combatUpdateCircles(); combatUpdateFacing() end)
end
local function combatStopLoops()
    if combatSoundTickConn then combatSoundTickConn:Disconnect(); combatSoundTickConn = nil end
    if combatVisualTickConn then combatVisualTickConn:Disconnect(); combatVisualTickConn = nil end
    for k, c in pairs(combatCircles) do pcall(function() c:Destroy() end) end; combatCircles = {}
    for k, v in pairs(combatFacingVisuals) do pcall(function() v:Destroy() end) end; combatFacingVisuals = {}
end

-- Character handlers
lp.CharacterAdded:Connect(function() task.wait(0.6); if combatS.autoBlockOn then combatSetupSoundWatcher() end; if combatS.autoBlockOn or combatS.killerCircles or combatS.facingVisual then combatStartLoops() end end)
if lp.Character then task.spawn(function() task.wait(1); if combatS.autoBlockOn then combatSetupSoundWatcher() end; if combatS.autoBlockOn or combatS.killerCircles or combatS.facingVisual then combatStartLoops() end end) end

-- Auto Punch loop
task.spawn(function() while true do task.wait(0.25); if not combatS.autoPunchOn then continue end; local char = lp.Character; if not char then continue end; local myRoot = char:FindFirstChild("HumanoidRootPart"); if not myRoot then continue end; local kf = combatGetKillersFolder(); if not kf then continue end; for _, k in pairs(kf:GetChildren()) do local hrp = k:FindFirstChild("HumanoidRootPart"); if hrp and (hrp.Position - myRoot.Position).Magnitude <= 10 then combatFireAbility("Punch"); break end end end end)

-- UI Elements
tabSurSen:CreateSection("Auto Block & Combat")
tabSurSen:CreateToggle({ Name="Auto Block (Audio)", CurrentValue=combatS.autoBlockOn, Flag="combatABOn", Callback=function(on) combatS.autoBlockOn=on; cfg.set("combatABOn",on); if on then combatSetupSoundWatcher(); combatStartLoops() else combatStopLoops() end end })
tabSurSen:CreateDropdown({ Name="Block Type", Options={"Block","Charge","7n7 Clone"}, CurrentOption=combatS.blockType, Flag="combatBlockType", Callback=function(v) combatS.blockType=v; cfg.set("combatBlockType",v) end })
tabSurSen:CreateSlider({ Name="Detection Range", Range={5,50}, Increment=1, CurrentValue=combatS.detectionRange, Flag="combatDetectRange", Callback=function(v) combatS.detectionRange=v; cfg.set("combatDetectRange",v) end })
tabSurSen:CreateSlider({ Name="Block Delay (s)", Range={0,0.5}, Increment=0.01, CurrentValue=combatS.blockDelay, Flag="combatBlockDelay", Callback=function(v) combatS.blockDelay=v; cfg.set("combatBlockDelay",v) end })
tabSurSen:CreateToggle({ Name="Facing Check", CurrentValue=combatS.facingCheck, Flag="combatFacingCheck", Callback=function(on) combatS.facingCheck=on; cfg.set("combatFacingCheck",on) end })
tabSurSen:CreateToggle({ Name="Double Block Tech", CurrentValue=combatS.doubleBlock, Flag="combatDoubleBlock", Callback=function(on) combatS.doubleBlock=on; cfg.set("combatDoubleBlock",on) end })
tabSurSen:CreateToggle({ Name="Anti-Bait", CurrentValue=combatS.antiBait, Flag="combatAntiBait", Callback=function(on) combatS.antiBait=on; cfg.set("combatAntiBait",on) end })
tabSurSen:CreateSlider({ Name="Block Miss Chance %", Range={0,100}, Increment=1, CurrentValue=combatS.abMissChance, Flag="combatABMiss", Callback=function(v) combatS.abMissChance=v; cfg.set("combatABMiss",v) end })

tabSurSen:CreateSection("Auto Punch")
tabSurSen:CreateToggle({ Name="Auto Punch", CurrentValue=combatS.autoPunchOn, Flag="combatAutoPunch", Callback=function(on) combatS.autoPunchOn=on; cfg.set("combatAutoPunch",on) end })

tabSurSen:CreateSection("HDT (Hitbox Dragging)")
tabSurSen:CreateParagraph({ Title = "How HDT works", Content = "Activates on sound triggers (same as Auto Block). When block fires successfully, HDT drags you toward the nearest killer. Only activates when block is OFF cooldown." })
tabSurSen:CreateToggle({ Name="Enable HDT", CurrentValue=combatS.hdtEnabled, Flag="combatHDT", Callback=function(on) combatS.hdtEnabled=on; cfg.set("combatHDT",on) end })
tabSurSen:CreateSlider({ Name="HDT Speed", Range={1,30}, Increment=0.5, CurrentValue=combatS.hdtSpeed, Flag="combatHDTSpeed", Callback=function(v) combatS.hdtSpeed=v; cfg.set("combatHDTSpeed",v) end })
tabSurSen:CreateSlider({ Name="HDT Delay (s)", Range={0,0.5}, Increment=0.01, CurrentValue=combatS.hdtDelay, Flag="combatHDTDelay", Callback=function(v) combatS.hdtDelay=v; cfg.set("combatHDTDelay",v) end })
tabSurSen:CreateSlider({ Name="HDT Miss Chance %", Range={0,100}, Increment=1, CurrentValue=combatS.hdtMissChance, Flag="combatHDTMiss", Callback=function(v) combatS.hdtMissChance=v; cfg.set("combatHDTMiss",v) end })

tabSurSen:CreateSection("Vision")
tabSurSen:CreateToggle({ Name="Detection Circles", CurrentValue=combatS.killerCircles, Flag="combatCircles", Callback=function(on) combatS.killerCircles=on; cfg.set("combatCircles",on); if on then combatStartLoops() else combatUpdateCircles() end end })
tabSurSen:CreateToggle({ Name="Facing Visual", CurrentValue=combatS.facingVisual, Flag="combatFacingVis", Callback=function(on) combatS.facingVisual=on; cfg.set("combatFacingVis",on); if on then combatStartLoops() end end })

-- Chance Aimbot (compact)
do
    tabSurSen:CreateSection("Chance Aimbot")
    local chanceAimEnabled = false; local chancePredMode = "Velocity"; local chancePredValue = 0.5; local chanceHeightAim = true; local chanceHoldToAim = true; local chanceAimKey = Enum.KeyCode.Q; local chanceHoldingKey = false; local chanceAiming = false; local chanceStartTime = 0; local chanceAimDuration = 1.7
    local chanceHum, chanceHRP, chanceBodyGyro
    local function chanceSetChar(c) chanceHum=c:WaitForChild("Humanoid"); chanceHRP=c:WaitForChild("HumanoidRootPart") end
    if lp.Character then chanceSetChar(lp.Character) end; lp.CharacterAdded:Connect(chanceSetChar)
    local chanceMotion = {}
    local function chanceGetMotion(hrp) local now=tick(); local pos=hrp.Position; local data=chanceMotion[hrp]; if not data then chanceMotion[hrp]={lastPos=pos,lastTime=now,velocity=Vector3.zero,accel=Vector3.zero}; return Vector3.zero,Vector3.zero end; local dt=now-data.lastTime; if dt<=0 then return data.velocity,data.accel end; local vel=(pos-data.lastPos)/dt; local acc=(vel-data.velocity)/dt; data.lastPos=pos; data.lastTime=now; data.accel=acc; data.velocity=vel; return vel,acc end
    local function chanceGetNearest() if not chanceHRP then return end; local folder=getTeamFolder("Killers"); if not folder then return end; local closest,dist=nil,math.huge; for _,m in ipairs(folder:GetChildren()) do local r=m:FindFirstChild("HumanoidRootPart"); local h=m:FindFirstChildOfClass("Humanoid"); if r and h and h.Health>0 then local d=(r.Position-chanceHRP.Position).Magnitude; if d<dist then dist=d; closest=r end end end; return closest end
    local function chancePredict(hrp) local vel,accel=chanceGetMotion(hrp); local pos=hrp.Position; local speed=vel.Magnitude; if speed<0.5 then return pos end; return pos+vel*chancePredValue end
    svc.Run.RenderStepped:Connect(function() if not chanceAimEnabled or not chanceHRP then return end; if chanceHoldToAim then if not chanceHoldingKey then return end else if not chanceAiming then return end; if tick()-chanceStartTime>chanceAimDuration then chanceAiming=false; return end end; local target=chanceGetNearest(); if not target then return end; local pos=chancePredict(target); if not pos then return end; local aimPos=chanceHeightAim and pos or Vector3.new(pos.X,chanceHRP.Position.Y,pos.Z); if not chanceBodyGyro or not chanceBodyGyro.Parent then chanceBodyGyro = Instance.new("BodyGyro"); chanceBodyGyro.MaxTorque = Vector3.new(0, math.huge, 0); chanceBodyGyro.P = 10000; chanceBodyGyro.D = 500; chanceBodyGyro.Parent = chanceHRP end; chanceBodyGyro.CFrame = CFrame.lookAt(chanceHRP.Position, aimPos) end)
    svc.Input.InputBegan:Connect(function(input,gpe) if gpe then return end; if chanceHoldToAim and input.KeyCode==chanceAimKey then chanceHoldingKey=true; chanceAiming=true; chanceStartTime=tick() end end)
    svc.Input.InputEnded:Connect(function(input) if chanceHoldToAim and input.KeyCode==chanceAimKey then chanceHoldingKey=false; chanceAiming=false end end)
    tabSurSen:CreateToggle({ Name="Enable Aimbot", CurrentValue=false, Callback=function(v) chanceAimEnabled=v end })
    tabSurSen:CreateDropdown({ Name="Prediction Mode", Options={"Velocity","Ping","Look"}, CurrentOption="Velocity", Callback=function(v) chancePredMode=v end })
    tabSurSen:CreateSlider({ Name="Prediction Value", Range={0,2}, Increment=0.1, CurrentValue=0.5, Callback=function(v) chancePredValue=v end })
    tabSurSen:CreateToggle({ Name="Hold-to-Aim", CurrentValue=true, Callback=function(v) chanceHoldToAim=v end })
    tabSurSen:CreateDropdown({ Name="Aim Key", Options={"Q","E","R","T","F","G"}, CurrentOption="Q", Callback=function(v) chanceAimKey=Enum.KeyCode[v] end })
end

-- TwoTime Backstab (compact)
do
    tabSurSen:CreateSection("TwoTime Backstab")
    local BS_BACKSTAB_THRESHOLD_COS = math.cos(math.rad(70)); local BS_DEFAULT_PROXIMITY = 8; local BS_COOLDOWN = 5.0
    local bsEnabled = false; local bsDaggerEnabled = false; local bsBaseProximity = BS_DEFAULT_PROXIMITY; local bsLastTrigger = 0
    local function bsGetChar() return lp.Character or lp.CharacterAdded:Wait() end
    local function bsGetDaggerButton() local pg=lp:FindFirstChild("PlayerGui"); if not pg then return nil end; local mainUI=pg:FindFirstChild("MainUI"); if not mainUI then return nil end; local container=mainUI:FindFirstChild("AbilityContainer"); if not container then return nil end; return container:FindFirstChild("Dagger") end
    local function bsGetKillersFolder() local pf=svc.WS:FindFirstChild("Players"); if not pf then return nil end; return pf:FindFirstChild("Killers") end
    local function bsIsValidKiller(model) if not model then return false end; local hrp=model:FindFirstChild("HumanoidRootPart"); local hum=model:FindFirstChildWhichIsA("Humanoid"); return hrp and hum and hum.Health and hum.Health>0 end
    local function bsTryActivateButton(btn) if not btn then return false end; pcall(function() if btn.Activate then btn:Activate() end end); return true end
    task.spawn(function() while true do task.wait(0.05); if not bsEnabled then continue end; local kf=bsGetKillersFolder(); if not kf then continue end; local char=bsGetChar(); local hrp=char and char:FindFirstChild("HumanoidRootPart"); if not hrp then continue end; for _,killer in pairs(kf:GetChildren()) do if not bsIsValidKiller(killer) then continue end; local khrp=killer:FindFirstChild("HumanoidRootPart"); local dist=(khrp.Position-hrp.Position).Magnitude; if dist > bsBaseProximity then continue end; local toKiller=(khrp.Position-hrp.Position).Unit; local dot=toKiller:Dot(khrp.CFrame.LookVector); if dot>BS_BACKSTAB_THRESHOLD_COS and os.clock()-bsLastTrigger>=BS_COOLDOWN then bsLastTrigger=os.clock(); hrp.CFrame=CFrame.lookAt(hrp.Position,Vector3.new(khrp.Position.X,hrp.Position.Y,khrp.Position.Z)); if bsDaggerEnabled then bsTryActivateButton(bsGetDaggerButton()) end; break end end end end)
    tabSurSen:CreateToggle({ Name="Enabled", CurrentValue=false, Callback=function(v) bsEnabled=v end })
    tabSurSen:CreateToggle({ Name="Auto Use Dagger", CurrentValue=false, Callback=function(v) bsDaggerEnabled=v end })
    tabSurSen:CreateSlider({ Name="Detection Range", Range={1,32}, Increment=1, CurrentValue=BS_DEFAULT_PROXIMITY, Callback=function(v) bsBaseProximity=v end })
end

------------------------------------------------------------------------
------------------------------------------------------------------------
-- TAB: VEERONICA
------------------------------------------------------------------------
------------------------------------------------------------------------
local tabVeeronica = win:CreateTab("Veeronica", "zap")
tabVeeronica:CreateSection("Auto Trick")
do
    local atEnabled = false; local atActiveMonitors = {}; local atDescendantAddedConn = nil
    local function atGetBehaviorFolder() return svc.RS:WaitForChild("Assets"):WaitForChild("Survivors"):WaitForChild("Veeronica"):WaitForChild("Behavior") end
    local function atGetSprintingButton() return lp.PlayerGui:WaitForChild("MainUI"):WaitForChild("SprintingButton") end
    local atBehaviorFolder = nil; task.spawn(function() local ok, f = pcall(atGetBehaviorFolder); if ok and f then atBehaviorFolder = f end end)
    local function atMonitorHighlight(h) if not h or atActiveMonitors[h] then return end; local connections = {}; local prevState = false; local function cleanup() for _, conn in ipairs(connections) do if conn and conn.Connected then conn:Disconnect() end end; atActiveMonitors[h] = nil end
        local function adorneeIsPlayer(hh) if not hh then return false end; local adornee = hh.Adornee; local char = lp.Character; if not adornee or not char then return false end; return adornee == char or adornee:IsDescendantOf(char) end
        local function onChanged() if not atEnabled then return end; if not h or not h.Parent then cleanup(); return end; local currState = adorneeIsPlayer(h); if prevState ~= currState then if currState then local ok2, btn = pcall(atGetSprintingButton); if ok2 and btn then for _, v in pairs(getconnections(btn.MouseButton1Down)) do pcall(function() v:Fire() end) end end end end; prevState = currState end
        local c = h:GetPropertyChangedSignal("Adornee"):Connect(onChanged); if c then table.insert(connections, c) end; table.insert(connections, h.AncestryChanged:Connect(function(_, parent) if not parent then cleanup() else onChanged() end end)); atActiveMonitors[h] = cleanup; task.spawn(onChanged) end
    local function atStartManager() if atDescendantAddedConn or not atBehaviorFolder then return end; for _, desc in ipairs(atBehaviorFolder:GetDescendants()) do if desc:IsA("Highlight") then atMonitorHighlight(desc) end end; atDescendantAddedConn = atBehaviorFolder.DescendantAdded:Connect(function(child) if child:IsA("Highlight") then atMonitorHighlight(child) end end) end
    local function atStopManager() if atDescendantAddedConn and atDescendantAddedConn.Connected then atDescendantAddedConn:Disconnect() end; atDescendantAddedConn = nil; for _, cleanup in pairs(atActiveMonitors) do if type(cleanup) == "function" then pcall(cleanup) end end; atActiveMonitors = {} end
    tabVeeronica:CreateToggle({ Name = "Auto Trick", CurrentValue = false, Flag = "autoTrickOn", Callback = function(on) atEnabled = on; if on then if not atBehaviorFolder then local ok, f = pcall(atGetBehaviorFolder); if ok and f then atBehaviorFolder = f end end; atStartManager() else atStopManager() end end })
end

tabVeeronica:CreateSection("SK8 Control")
do
    local sk8_camera = workspace.CurrentCamera; local sk8_shiftlockEnabled = false; local sk8_shiftConn = nil
    local function sk8_setShiftlock(state) sk8_shiftlockEnabled = state; if sk8_shiftConn then sk8_shiftConn:Disconnect(); sk8_shiftConn = nil end; if sk8_shiftlockEnabled then svc.Input.MouseBehavior = Enum.MouseBehavior.LockCenter; sk8_shiftConn = svc.Run.RenderStepped:Connect(function() local character = lp.Character; local root = character and character:FindFirstChild("HumanoidRootPart"); if root then local camCF = sk8_camera.CFrame; root.CFrame = CFrame.new(root.Position, Vector3.new(camCF.LookVector.X+root.Position.X, root.Position.Y, camCF.LookVector.Z+root.Position.Z)) end end) else svc.Input.MouseBehavior = Enum.MouseBehavior.Default end end
    local sk8_chargeAnimIds = { "117058860640843" }; local sk8_DASH_SPEED = 60; local sk8_controlEnabled = cfg.get("sk8ControlEnabled", true); local sk8_controlActive = false; local sk8_overrideConn = nil
    local function sk8_getHumanoid() if not lp or not lp.Character then return nil end; return lp.Character:FindFirstChildOfClass("Humanoid") end
    local function sk8_startOverride() if sk8_controlActive then return end; local hum = sk8_getHumanoid(); if not hum then return end; sk8_controlActive = true; pcall(function() hum.WalkSpeed = sk8_DASH_SPEED; hum.AutoRotate = false end); sk8_setShiftlock(true); sk8_overrideConn = svc.Run.RenderStepped:Connect(function() local humanoid = sk8_getHumanoid(); local rootPart = humanoid and humanoid.Parent and humanoid.Parent:FindFirstChild("HumanoidRootPart"); if not humanoid or not rootPart then return end; pcall(function() humanoid.WalkSpeed = sk8_DASH_SPEED; humanoid.AutoRotate = false end); local direction = rootPart.CFrame.LookVector; local horizontal = Vector3.new(direction.X, 0, direction.Z); if horizontal.Magnitude > 0 then humanoid:Move(horizontal.Unit) end end) end
    local function sk8_stopOverride() if not sk8_controlActive then return end; sk8_controlActive = false; if sk8_overrideConn then pcall(function() sk8_overrideConn:Disconnect() end); sk8_overrideConn = nil end; sk8_setShiftlock(false) end
    local function sk8_detectChargeAnim() local hum = sk8_getHumanoid(); if not hum then return false end; for _, track in ipairs(hum:GetPlayingAnimationTracks()) do local ok, animId = pcall(function() return tostring(track.Animation and track.Animation.AnimationId or ""):match("%d+") end); if ok and animId and animId ~= "" then if table.find(sk8_chargeAnimIds, animId) then return true end end end; return false end
    svc.Run.RenderStepped:Connect(function() if not sk8_controlEnabled then if sk8_controlActive then sk8_stopOverride() end; return end; local hum = sk8_getHumanoid(); if not hum then if sk8_controlActive then sk8_stopOverride() end; return end; if sk8_detectChargeAnim() then if not sk8_controlActive then sk8_startOverride() end else if sk8_controlActive then sk8_stopOverride() end end end)
    tabVeeronica:CreateToggle({ Name = "Enable SK8 Control", CurrentValue = sk8_controlEnabled, Flag = "sk8ControlEnabled", Callback = function(on) sk8_controlEnabled = on; cfg.set("sk8ControlEnabled", on); if not on and sk8_controlActive then sk8_stopOverride() end end })
end

------------------------------------------------------------------------
------------------------------------------------------------------------
-- TAB: JANE DOE
------------------------------------------------------------------------
------------------------------------------------------------------------
local tabJaneDoe = win:CreateTab("Jane Doe", "gem")
do
    local jd_Camera = svc.WS.CurrentCamera; local jd_RemoteEvent = nil; local jd_NetworkRF = nil
    pcall(function() jd_RemoteEvent = svc.RS:WaitForChild("Modules",10):WaitForChild("Network",10):WaitForChild("Network",10):WaitForChild("RemoteEvent",10) end)
    pcall(function() jd_NetworkRF = svc.RS:WaitForChild("Modules",10):WaitForChild("Network",10):WaitForChild("Network",10):WaitForChild("RemoteFunction",10) end)
    local jd_enabled = false; local jd_aimbotOn = false; local jd_patched = false; local jd_crystalCB = nil; local jd_unloaded = false
    local jd_AIM_OFFSET = -0.3; local jd_PREDICTION = 0.6; local jd_HOLD_DURATION = 0.9; local jd_killerMotionData = {}
    local function jd_getKillerVelocity(hrp) local now=tick(); local pos=hrp.Position; local data=jd_killerMotionData[hrp]; if not data then jd_killerMotionData[hrp]={lastPos=pos,lastTime=now,velocity=Vector3.zero}; return Vector3.zero end; local dt=now-data.lastTime; if dt<=0 then return data.velocity end; local vel=(pos-data.lastPos)/dt; data.lastPos=pos; data.lastTime=now; data.velocity=vel; return vel end
    local function jd_getNearestKiller(fromPos) local folder=getTeamFolder("Killers"); if not folder then return nil end; local nearest,best=nil,math.huge; for _,model in ipairs(folder:GetChildren()) do local hrp=model:FindFirstChild("HumanoidRootPart"); local hum=model:FindFirstChildOfClass("Humanoid"); if hrp and hum and hum.Health>0 then local d=(hrp.Position-fromPos).Magnitude; if d<best then best=d; nearest=model end end end; return nearest end
    local function jd_fireCrystal() if not jd_RemoteEvent then return end; local buf=buffer.create(8); buffer.writeu32(buf,0,0xe8812534); buffer.writeu32(buf,4,0x1055d474); jd_RemoteEvent:FireServer("UseActorAbility",{buf}) end
    local function jd_buildCamCF(myHRP, killerHRP, v0, g) local hum=myHRP.Parent and myHRP.Parent:FindFirstChildOfClass("Humanoid"); local hipH=hum and hum.HipHeight or 1.35; local v238=(hipH+myHRP.Size.Y/2)/2; local spawnPos=myHRP.CFrame.Position+Vector3.new(0,v238,0); local vel=jd_getKillerVelocity(killerHRP); local predicted=killerHRP.Position+vel*jd_PREDICTION; local target=predicted+Vector3.new(0,jd_AIM_OFFSET,0); local delta=target-spawnPos; local flatV=Vector3.new(delta.X,0,delta.Z); local dx=flatV.Magnitude; local dy=delta.Y; if dx<0.01 then local d=dy>=0 and Vector3.new(0,1,0) or Vector3.new(0,-1,0); return CFrame.new(jd_Camera.CFrame.Position,jd_Camera.CFrame.Position+d) end; local flatDir=flatV.Unit; local v2=v0*v0; local disc=v2*v2-g*(g*dx*dx+2*dy*v2); local theta=disc<0 and math.atan2(dy,dx) or math.atan2(v2-math.sqrt(disc),g*dx); local T=math.tan(theta); local denom=3+T; local alpha=math.abs(denom)<0.0001 and -math.pi/2 or math.atan2(3*T-1,denom); local yawCF=CFrame.new(jd_Camera.CFrame.Position,jd_Camera.CFrame.Position+flatDir); return yawCF*CFrame.Angles(alpha,0,0) end
    local function jd_getLocalActor() return lp.Character end
    local function jd_applyPatch(actor) if jd_patched or not actor or not jd_NetworkRF then return end; if type(getcallbackvalue)=="function" then pcall(function() jd_crystalCB=getcallbackvalue(jd_NetworkRF,"OnClientInvoke") end) end; jd_NetworkRF.OnClientInvoke=function(reqName,...) if reqName=="GetCameraCF" and jd_enabled and jd_aimbotOn then local char=lp.Character; local myHRP=char and char:FindFirstChild("HumanoidRootPart"); if myHRP then local killer=jd_getNearestKiller(myHRP.Position); local killerHRP=killer and killer:FindFirstChild("HumanoidRootPart"); if killerHRP then local ok,cf=pcall(jd_buildCamCF,myHRP,killerHRP,250,40); if ok and cf then return cf end end end end; if jd_crystalCB then return jd_crystalCB(reqName,...) end end; jd_patched=true end
    local function jd_removePatch() if not jd_patched then return end; pcall(function() if jd_NetworkRF then jd_NetworkRF.OnClientInvoke=jd_crystalCB end end); jd_crystalCB=nil; jd_patched=false end
    task.spawn(function() while not jd_unloaded do task.wait(0.1); if not jd_enabled or not jd_patched then continue end; jd_fireCrystal(); task.wait(jd_HOLD_DURATION + 0.2) end end)
    task.spawn(function() local lastActor=nil; while not jd_unloaded do task.wait(0.5); local cur=jd_getLocalActor(); if cur~=lastActor then if lastActor~=nil then jd_patched=false; jd_crystalCB=nil; jd_killerMotionData={} end; lastActor=cur; if cur and jd_enabled then jd_applyPatch(cur) end end end end)
    tabJaneDoe:CreateSection("Crystal Auto-Fire")
    tabJaneDoe:CreateToggle({ Name="Enable Jane Doe Aimbot", CurrentValue=false, Callback=function(on) jd_enabled=on; local actor=jd_getLocalActor(); if on and not jd_patched and actor then jd_applyPatch(actor) end end})
    tabJaneDoe:CreateToggle({ Name="Aimbot (Silent Aim)", CurrentValue=false, Callback=function(on) jd_aimbotOn=on; local actor=jd_getLocalActor(); if on and not jd_patched and actor then jd_applyPatch(actor) end end})
    tabJaneDoe:CreateSlider({ Name="Aim Offset (Y)", Range={-5.0,5.0}, Increment=0.1, CurrentValue=jd_AIM_OFFSET, Callback=function(v) jd_AIM_OFFSET=v end })
    tabJaneDoe:CreateSlider({ Name="Prediction", Range={0.0,1.0}, Increment=0.01, CurrentValue=jd_PREDICTION, Callback=function(v) jd_PREDICTION=v end })
    tabJaneDoe:CreateSlider({ Name="Hold Duration (s)", Range={0.3,2.0}, Increment=0.1, CurrentValue=jd_HOLD_DURATION, Callback=function(v) jd_HOLD_DURATION=v end })
    tabJaneDoe:CreateButton({ Name="Unload Jane Doe", Callback=function() if jd_unloaded then return end; jd_unloaded=true; jd_enabled=false; jd_aimbotOn=false; pcall(jd_removePatch) end})
end

------------------------------------------------------------------------
-- Interface Tab
------------------------------------------------------------------------
local tabInterface = win:CreateTab("Interface", "layout-dashboard")
tabInterface:CreateSection("UI Functions")
tabInterface:CreateButton({ Name = "Close UI", Callback = function() local ok = pcall(function() win:Destroy() end); if not ok then pcall(function() win:Close() end) end end })

print("V1PRWARE ready")