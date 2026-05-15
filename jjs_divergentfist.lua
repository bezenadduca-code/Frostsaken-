-- JJS Hub | Rayfield UI
-- Divergent Fist + ESP + Block + Hitbox Expander + Teleport

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local Players           = game:GetService("Players")
local LocalPlayer       = Players.LocalPlayer

------------------------------------------------------------------------
-- Rayfield
------------------------------------------------------------------------
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

------------------------------------------------------------------------
-- CONFIG
------------------------------------------------------------------------
local CONFIG = {
    -- Divergent Fist
    BehindOffset           = 5.5,
    AlreadyBehindTolerance = 3.5,
    FireDelay              = 0.37,
    DashSpeed              = 79,
    ArcSegments            = 5,
    SideWidth              = 0.65,
    TrailLifetime          = 0.35,
    DashAnimLeft           = "rbxassetid://117223862448096",
    DashAnimRight          = "rbxassetid://75203303352791",
    AttackAnimId           = "rbxassetid://100962226150441",
    FacingDotThreshold     = -0.6,
    RetryDelay             = 0.04,
    RetryFire              = true,
    Enabled                = true,
    ShowTrail              = true,
    PlayAnims              = true,
    -- ESP
    EspEnabled             = false,
    EspFillColor           = Color3.fromRGB(255, 50, 50),
    EspOutlineColor        = Color3.fromRGB(255, 255, 255),
    EspFillTrans           = 0.6,
    EspOutlineTrans        = 0.0,
    -- Block
    BlockEnabled           = false,
    BlockInterval          = 0.1,
    -- Hitbox
    HitboxEnabled          = false,
    HitboxMultiplier       = 75,
}

if _G.retryfire ~= nil then CONFIG.RetryFire = _G.retryfire end

------------------------------------------------------------------------
-- Remotes
------------------------------------------------------------------------
local function getRemote(...)
    local path = {...}
    local ok, remote = pcall(function()
        local node = ReplicatedStorage
        for _, child in ipairs(path) do
            node = node:WaitForChild(child, 5)
        end
        return node
    end)
    return ok and remote or nil
end

local targetRemote      = getRemote("Knit","Knit","Services","DivergentFistService","RE","Activated")
local returnSkillRemote = getRemote("Knit","Knit","Services","ItadoriService","RE","RightActivated")
local blockRemote       = getRemote("Knit","Knit","Services","BlockService","RE","Activated")

------------------------------------------------------------------------
-- Utils
------------------------------------------------------------------------
local function getHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getAnimator()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum and hum:FindFirstChildOfClass("Animator")
end

local function isAliveModel(model)
    local myChar = LocalPlayer.Character
    if model == myChar then return false end
    local root = model:FindFirstChild("HumanoidRootPart")
    local hum  = model:FindFirstChild("Humanoid")
    return root and hum and hum.Health > 0
end

local function isTargetFacingAway(targetRoot)
    local hrp = getHRP()
    if not hrp or not targetRoot or not targetRoot.Parent then return false end
    local toPlayer = (hrp.Position - targetRoot.Position)
    if toPlayer.Magnitude < 0.01 then return false end
    local dot = targetRoot.CFrame.LookVector:Dot(toPlayer.Unit)
    return dot < CONFIG.FacingDotThreshold
end

local function findNearestTarget()
    local hrp = getHRP()
    if not hrp then return nil end
    local nearest, bestDist = nil, math.huge
    local function checkModel(model)
        if not isAliveModel(model) then return end
        local root = model:FindFirstChild("HumanoidRootPart")
        local dist = (hrp.Position - root.Position).Magnitude
        if dist < bestDist then bestDist = dist; nearest = model end
    end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then checkModel(player.Character) end
    end
    return nearest
end

------------------------------------------------------------------------
-- Trail
------------------------------------------------------------------------
local function createTrail(rootPart)
    if not CONFIG.ShowTrail then return end
    local a0 = Instance.new("Attachment", rootPart)
    local a1 = Instance.new("Attachment", rootPart)
    a1.Position = Vector3.new(0, 2, 0)
    local trail        = Instance.new("Trail", rootPart)
    trail.Attachment0  = a0
    trail.Attachment1  = a1
    trail.Color        = ColorSequence.new(Color3.fromRGB(255, 255, 255))
    trail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.4),
        NumberSequenceKeypoint.new(1, 1),
    })
    trail.Lifetime   = CONFIG.TrailLifetime
    trail.MinLength  = 0
    trail.FaceCamera = true
    task.delay(CONFIG.TrailLifetime + 0.1, function()
        trail:Destroy(); a0:Destroy(); a1:Destroy()
    end)
end

------------------------------------------------------------------------
-- Animations
------------------------------------------------------------------------
local cachedAnims = {}

local function playDashAnimation(direction, duration)
    if not CONFIG.PlayAnims then return nil end
    local animator = getAnimator()
    if not animator then return nil end
    local animId = (direction == "Left") and CONFIG.DashAnimLeft or CONFIG.DashAnimRight
    if not cachedAnims[direction] then
        local anim = Instance.new("Animation")
        anim.AnimationId = animId
        anim.Name = "DivergentFistDashAnim_" .. direction
        cachedAnims[direction] = anim
    end
    local track = animator:LoadAnimation(cachedAnims[direction])
    track.Priority = Enum.AnimationPriority.Action
    track:Play()
    task.delay(duration + 0.05, function()
        if track and track.IsPlaying then track:Stop(0.15) end
    end)
    return track
end

local function playAttackAnimation()
    if not CONFIG.PlayAnims then return end
    local animator = getAnimator()
    if not animator then return end
    if not cachedAnims["Attack"] then
        local anim = Instance.new("Animation")
        anim.AnimationId = CONFIG.AttackAnimId
        anim.Name = "DivergentFistAttackAnim"
        cachedAnims["Attack"] = anim
    end
    local track = animator:LoadAnimation(cachedAnims["Attack"])
    track.Priority = Enum.AnimationPriority.Action
    track:Play()
    task.delay(1.113, function()
        if track.IsPlaying then track:Stop() end
    end)
end

------------------------------------------------------------------------
-- Curved Dash (original logic untouched)
------------------------------------------------------------------------
local function performCurvedDash(targetRoot)
    local hrp = getHRP()
    if not hrp then return end

    local myPos   = hrp.Position
    local destPos = (targetRoot.CFrame * CFrame.new(0, 0, CONFIG.BehindOffset)).Position

    if (myPos - destPos).Magnitude < CONFIG.AlreadyBehindTolerance then
        playAttackAnimation()
        return
    end

    local dist = (destPos - myPos).Magnitude
    if dist < 0.5 then return end

    local dir    = (destPos - myPos).Unit
    local side   = dir:Cross(Vector3.new(0, 1, 0)).Unit
    local isLeft = math.random(1, 2) == 2
    if isLeft then side = -side end
    local dashDirection = isLeft and "Left" or "Right"

    local arcDef = {
        { 0.10, CONFIG.SideWidth * 0.50 },
        { 0.30, CONFIG.SideWidth * 0.80 },
        { 0.55, CONFIG.SideWidth * 0.70 },
        { 0.75, CONFIG.SideWidth * 0.40 },
        { 1.00, 0                        },
    }

    local waypoints = {}
    for i = 1, math.min(CONFIG.ArcSegments, #arcDef) do
        table.insert(waypoints, myPos + (dir * dist * arcDef[i][1]) + (side * dist * arcDef[i][2]))
    end

    local totalTime = math.max(dist / CONFIG.DashSpeed, 0.08)
    local segTime   = totalTime / #waypoints

    createTrail(hrp)
    local dashTrack = playDashAnimation(dashDirection, totalTime)

    for i, wp in ipairs(waypoints) do
        local lookDir = (i < #waypoints)
            and (waypoints[i + 1] - wp).Unit
            or  (targetRoot.Position - wp).Unit
        TweenService:Create(hrp,
            TweenInfo.new(segTime, Enum.EasingStyle.Linear),
            { CFrame = CFrame.new(wp, wp + lookDir) }
        ):Play()
        task.wait(segTime)
    end

    hrp.CFrame = CFrame.lookAt(destPos, targetRoot.Position)
    if dashTrack and dashTrack.IsPlaying then dashTrack:Stop(0.1) end
    playAttackAnimation()
end

------------------------------------------------------------------------
-- ESP (Highlight-based, single loop, non-laggy)
------------------------------------------------------------------------
local espHighlights = {} -- [character] = Highlight

local function removeHighlight(char)
    if espHighlights[char] then
        pcall(function() espHighlights[char]:Destroy() end)
        espHighlights[char] = nil
    end
end

local function applyHighlight(char)
    if espHighlights[char] and espHighlights[char].Parent then return end
    local hl = Instance.new("Highlight")
    hl.FillColor         = CONFIG.EspFillColor
    hl.OutlineColor      = CONFIG.EspOutlineColor
    hl.FillTransparency  = CONFIG.EspFillTrans
    hl.OutlineTransparency = CONFIG.EspOutlineTrans
    hl.Adornee           = char
    hl.Parent            = char
    espHighlights[char]  = hl
end

local function clearAllESP()
    for char, hl in pairs(espHighlights) do
        pcall(function() hl:Destroy() end)
    end
    espHighlights = {}
end

-- single heartbeat loop — checks all players once per frame
RunService.Heartbeat:Connect(function()
    if not CONFIG.EspEnabled then return end
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local char = player.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                applyHighlight(char)
            else
                removeHighlight(char)
            end
        else
            if espHighlights[char] then removeHighlight(char) end
        end
    end
end)

-- clean up on character removal
Players.PlayerRemoving:Connect(function(player)
    if player.Character then removeHighlight(player.Character) end
end)

------------------------------------------------------------------------
-- Block spam
------------------------------------------------------------------------
local blockThread = nil

local function startBlock()
    if blockThread or not blockRemote then return end
    blockThread = task.spawn(function()
        while CONFIG.BlockEnabled do
            pcall(function() blockRemote:FireServer(nil) end)
            task.wait(CONFIG.BlockInterval)
        end
        blockThread = nil
    end)
end

local function stopBlock()
    CONFIG.BlockEnabled = false
    if blockThread then task.cancel(blockThread); blockThread = nil end
end

------------------------------------------------------------------------
-- Hitbox Expander (namecall hook — runs alongside DivergentFist hook)
------------------------------------------------------------------------
local isCooling  = false
local isRetrying = false

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()

    -- Hitbox expander
    if CONFIG.HitboxEnabled and method == "FireServer"
        and self.Parent == LocalPlayer.Character
        and type((...)) == "table" then
        local n, c = {}, 0
        for _, v in next, (...) do
            for i = 1, CONFIG.HitboxMultiplier do
                c += 1; n[c] = v
            end
        end
        return oldNamecall(self, n, select(2, ...))
    end

    -- DivergentFist hook
    if method == "FireServer" and self == targetRemote then
        if not CONFIG.Enabled then return oldNamecall(self, ...) end
        if isRetrying then return oldNamecall(self, ...) end
        if isCooling  then return oldNamecall(self, ...) end
        isCooling = true

        local result     = oldNamecall(self, ...)
        local args       = {...}
        local target     = findNearestTarget()
        local targetRoot = target and target:FindFirstChild("HumanoidRootPart")

        task.delay(CONFIG.FireDelay, function()
            if targetRoot and targetRoot.Parent and not isTargetFacingAway(targetRoot) then
                if returnSkillRemote then
                    pcall(function() returnSkillRemote:FireServer() end)
                end
                task.spawn(function()
                    task.wait(CONFIG.RetryDelay)
                    if not targetRoot.Parent or not isAliveModel(targetRoot.Parent) then
                        task.defer(function() isCooling = false end)
                        return
                    end
                    performCurvedDash(targetRoot)
                    local shouldRetryFire = (_G.retryfire ~= nil) and _G.retryfire or CONFIG.RetryFire
                    if not isTargetFacingAway(targetRoot) then
                        -- failed
                    elseif not shouldRetryFire then
                        -- skip
                    else
                        isRetrying = true
                        pcall(function() targetRemote:FireServer(table.unpack(args)) end)
                        task.wait(CONFIG.FireDelay)
                        pcall(function() targetRemote:FireServer(table.unpack(args)) end)
                        isRetrying = false
                    end
                    task.defer(function() isCooling = false end)
                end)
            else
                pcall(function() targetRemote:FireServer(table.unpack(args)) end)
                task.defer(function() isCooling = false end)
            end
        end)

        task.spawn(function()
            if not targetRoot or not targetRoot.Parent then return end
            performCurvedDash(targetRoot)
        end)

        return result
    end

    return oldNamecall(self, ...)
end)

------------------------------------------------------------------------
-- Teleport to nearest
------------------------------------------------------------------------
local function teleportToNearest()
    local hrp = getHRP()
    if not hrp then return end
    local target = findNearestTarget()
    if not target then
        Rayfield:Notify({ Title = "Teleport", Content = "No target found.", Duration = 3 })
        return
    end
    local targetHRP = target:FindFirstChild("HumanoidRootPart")
    if targetHRP then
        hrp.CFrame = targetHRP.CFrame * CFrame.new(0, 0, 3)
        Rayfield:Notify({ Title = "Teleport", Content = "Teleported to " .. (target.Name or "target"), Duration = 2 })
    end
end

------------------------------------------------------------------------
-- RAYFIELD UI
------------------------------------------------------------------------
local win = Rayfield:CreateWindow({
    Name            = "JJS Hub",
    LoadingTitle    = "JJS Hub",
    LoadingSubtitle = "Divergent Fist + ESP + Block + More",
    ConfigurationSaving = { Enabled = true, FolderName = "JJS", FileName = "hub" },
    KeySystem = false,
})

------------------------------------------------------------------------
-- TAB: Main (Divergent Fist)
------------------------------------------------------------------------
local tabMain = win:CreateTab("Divergent Fist", "zap")
tabMain:CreateSection("Control")

tabMain:CreateToggle({
    Name = "Enabled", CurrentValue = CONFIG.Enabled, Flag = "dfEnabled",
    Callback = function(v) CONFIG.Enabled = v end,
})
tabMain:CreateToggle({
    Name = "Retry Fire", CurrentValue = CONFIG.RetryFire, Flag = "retryFire",
    Callback = function(v) CONFIG.RetryFire = v; _G.retryfire = v end,
})
tabMain:CreateToggle({
    Name = "Show Trail", CurrentValue = CONFIG.ShowTrail, Flag = "showTrail",
    Callback = function(v) CONFIG.ShowTrail = v end,
})
tabMain:CreateToggle({
    Name = "Play Animations", CurrentValue = CONFIG.PlayAnims, Flag = "playAnims",
    Callback = function(v) CONFIG.PlayAnims = v end,
})

tabMain:CreateSection("Timing")
tabMain:CreateSlider({
    Name = "Fire Delay (s)", Range = {0.1, 1.0}, Increment = 0.01, Suffix = "s",
    CurrentValue = CONFIG.FireDelay, Flag = "fireDelay",
    Callback = function(v) CONFIG.FireDelay = v end,
})
tabMain:CreateSlider({
    Name = "Retry Delay (s)", Range = {0.01, 0.5}, Increment = 0.01, Suffix = "s",
    CurrentValue = CONFIG.RetryDelay, Flag = "retryDelay",
    Callback = function(v) CONFIG.RetryDelay = v end,
})
tabMain:CreateSlider({
    Name = "Trail Lifetime (s)", Range = {0.1, 1.0}, Increment = 0.05, Suffix = "s",
    CurrentValue = CONFIG.TrailLifetime, Flag = "trailLifetime",
    Callback = function(v) CONFIG.TrailLifetime = v end,
})

tabMain:CreateSection("Dash")
tabMain:CreateSlider({
    Name = "Dash Speed", Range = {20, 200}, Increment = 1,
    CurrentValue = CONFIG.DashSpeed, Flag = "dashSpeed",
    Callback = function(v) CONFIG.DashSpeed = v end,
})
tabMain:CreateSlider({
    Name = "Behind Offset", Range = {1.0, 15.0}, Increment = 0.5,
    CurrentValue = CONFIG.BehindOffset, Flag = "behindOffset",
    Callback = function(v) CONFIG.BehindOffset = v end,
})
tabMain:CreateSlider({
    Name = "Already Behind Tolerance", Range = {1.0, 10.0}, Increment = 0.5,
    CurrentValue = CONFIG.AlreadyBehindTolerance, Flag = "behindTolerance",
    Callback = function(v) CONFIG.AlreadyBehindTolerance = v end,
})
tabMain:CreateSlider({
    Name = "Arc Side Width", Range = {0.0, 2.0}, Increment = 0.05,
    CurrentValue = CONFIG.SideWidth, Flag = "sideWidth",
    Callback = function(v) CONFIG.SideWidth = v end,
})
tabMain:CreateSlider({
    Name = "Arc Segments", Range = {1, 10}, Increment = 1,
    CurrentValue = CONFIG.ArcSegments, Flag = "arcSegments",
    Callback = function(v) CONFIG.ArcSegments = math.floor(v) end,
})
tabMain:CreateSlider({
    Name = "Facing Dot Threshold", Range = {-1.0, 0.0}, Increment = 0.05,
    CurrentValue = CONFIG.FacingDotThreshold, Flag = "facingDot",
    Callback = function(v) CONFIG.FacingDotThreshold = v end,
})

tabMain:CreateSection("Remotes")
tabMain:CreateLabel("BF Remote: "     .. (targetRemote      and "✓ Found" or "✗ Not Found"))
tabMain:CreateLabel("Return Remote: " .. (returnSkillRemote and "✓ Found" or "✗ Not Found"))
tabMain:CreateLabel("Block Remote: "  .. (blockRemote       and "✓ Found" or "✗ Not Found"))

------------------------------------------------------------------------
-- TAB: ESP
------------------------------------------------------------------------
local tabESP = win:CreateTab("ESP", "eye")
tabESP:CreateSection("Highlight ESP")

tabESP:CreateToggle({
    Name = "Enable ESP", CurrentValue = CONFIG.EspEnabled, Flag = "espEnabled",
    Callback = function(v)
        CONFIG.EspEnabled = v
        if not v then clearAllESP() end
    end,
})
tabESP:CreateColorPicker({
    Name = "Fill Color",
    Color = CONFIG.EspFillColor,
    Flag = "espFillColor",
    Callback = function(v)
        CONFIG.EspFillColor = v
        for _, hl in pairs(espHighlights) do hl.FillColor = v end
    end,
})
tabESP:CreateColorPicker({
    Name = "Outline Color",
    Color = CONFIG.EspOutlineColor,
    Flag = "espOutlineColor",
    Callback = function(v)
        CONFIG.EspOutlineColor = v
        for _, hl in pairs(espHighlights) do hl.OutlineColor = v end
    end,
})
tabESP:CreateSlider({
    Name = "Fill Transparency", Range = {0.0, 1.0}, Increment = 0.05,
    CurrentValue = CONFIG.EspFillTrans, Flag = "espFillTrans",
    Callback = function(v)
        CONFIG.EspFillTrans = v
        for _, hl in pairs(espHighlights) do hl.FillTransparency = v end
    end,
})
tabESP:CreateSlider({
    Name = "Outline Transparency", Range = {0.0, 1.0}, Increment = 0.05,
    CurrentValue = CONFIG.EspOutlineTrans, Flag = "espOutlineTrans",
    Callback = function(v)
        CONFIG.EspOutlineTrans = v
        for _, hl in pairs(espHighlights) do hl.OutlineTransparency = v end
    end,
})

------------------------------------------------------------------------
-- TAB: Combat
------------------------------------------------------------------------
local tabCombat = win:CreateTab("Combat", "sword")

tabCombat:CreateSection("Block Spam")
tabCombat:CreateToggle({
    Name = "Auto Block", CurrentValue = false, Flag = "blockEnabled",
    Callback = function(v)
        CONFIG.BlockEnabled = v
        if v then startBlock() else stopBlock() end
    end,
})
tabCombat:CreateSlider({
    Name = "Block Interval (s)", Range = {0.05, 1.0}, Increment = 0.05, Suffix = "s",
    CurrentValue = CONFIG.BlockInterval, Flag = "blockInterval",
    Callback = function(v) CONFIG.BlockInterval = v end,
})

tabCombat:CreateSection("Hitbox Expander")
tabCombat:CreateToggle({
    Name = "Hitbox Expander", CurrentValue = false, Flag = "hitboxEnabled",
    Callback = function(v) CONFIG.HitboxEnabled = v end,
})
tabCombat:CreateSlider({
    Name = "Hit Multiplier", Range = {1, 150}, Increment = 1,
    CurrentValue = CONFIG.HitboxMultiplier, Flag = "hitboxMult",
    Callback = function(v) CONFIG.HitboxMultiplier = math.floor(v) end,
})

tabCombat:CreateSection("Teleport")
tabCombat:CreateButton({
    Name = "Teleport to Nearest Player",
    Callback = teleportToNearest,
})

------------------------------------------------------------------------
Rayfield:Notify({
    Title   = "JJS Hub Loaded",
    Content = "Divergent Fist + ESP + Block + Hitbox ready.",
    Duration = 4,
})
