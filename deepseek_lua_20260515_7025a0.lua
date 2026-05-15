local Luna = loadstring(game:HttpGet("https://raw.githubusercontent.com/Nebula-Softworks/Luna-Interface-Suite/refs/heads/master/source.lua", true))()
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Stats = game:GetService("Stats")

-- ──────────────────────────────────────────────
--  CONFIG
-- ──────────────────────────────────────────────
local CONFIG = {
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
    RetryDelay             = 0.04,
    RetryFire              = true,
    ESPEnabled             = true,
    ESPColor               = Color3.fromRGB(255, 50, 50),
    ESPFillTransparency    = 0.7,
    ESPOutlineTransparency = 0.3,
    MinPingAdjustment      = 0.05,  -- Minimum extra delay based on ping
    MaxRetryAttempts       = 3,     -- Maximum retry attempts
    BlackFlashEffect       = true,  -- Enable screen black flash effect
}

-- ──────────────────────────────────────────────
--  REMOTES
-- ──────────────────────────────────────────────
local function getRemote(...)
    local path = { ... }
    local ok, remote = pcall(function()
        local node = ReplicatedStorage
        for _, child in ipairs(path) do
            node = node:WaitForChild(child, 5)
        end
        return node
    end)
    return ok and remote or nil
end

local targetRemote = getRemote("Knit","Knit","Services","DivergentFistService","RE","Activated")
if not targetRemote then
    warn("[DivergentFist] Remote not found!")
    return
end

local returnSkillRemote = getRemote("Knit","Knit","Services","ItadoriService","RE","RightActivated")

-- ──────────────────────────────────────────────
--  PING-BASED ADAPTIVE TIMING
-- ──────────────────────────────────────────────
local function getPingAdjustment()
    local ping = Stats and Stats.Network and Stats.Network.ServerStatsItem and Stats.Network.ServerStatsItem["Data Ping"]
    if ping then
        return (ping:GetValue() / 1000) + CONFIG.MinPingAdjustment
    end
    return CONFIG.MinPingAdjustment
end

-- ──────────────────────────────────────────────
--  BLACK FLASH EFFECT SYSTEM
-- ──────────────────────────────────────────────
local function triggerBlackFlash()
    if not CONFIG.BlackFlashEffect then return end
    
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "BlackFlashEffect"
    screenGui.Parent = playerGui
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.DisplayOrder = 999
    
    local frame = Instance.new("Frame")
    frame.Name = "Flash"
    frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    frame.BackgroundTransparency = 0
    frame.BorderSizePixel = 0
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.Parent = screenGui
    
    -- Red overlay for black flash effect
    local redOverlay = Instance.new("Frame")
    redOverlay.Name = "RedOverlay"
    redOverlay.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    redOverlay.BackgroundTransparency = 1
    redOverlay.BorderSizePixel = 0
    redOverlay.Size = UDim2.new(1, 0, 1, 0)
    redOverlay.Parent = screenGui
    
    -- Flash sequence
    task.spawn(function()
        -- Black flash
        frame.BackgroundTransparency = 0
        redOverlay.BackgroundTransparency = 0.5
        task.wait(0.05)
        
        -- Fade out
        local fadeTime = 0.3
        local startTime = tick()
        while tick() - startTime < fadeTime do
            local alpha = (tick() - startTime) / fadeTime
            frame.BackgroundTransparency = alpha
            redOverlay.BackgroundTransparency = 0.5 + (alpha * 0.5)
            task.wait()
        end
        
        -- Cleanup
        screenGui:Destroy()
    end)
end

-- ──────────────────────────────────────────────
--  ESP SYSTEM
-- ──────────────────────────────────────────────
local espObjects = {}

local function createHighlight(model, color)
    local highlight = Instance.new("Highlight")
    highlight.Name = "DivergentFistESP"
    highlight.FillTransparency = CONFIG.ESPFillTransparency
    highlight.OutlineTransparency = CONFIG.ESPOutlineTransparency
    highlight.FillColor = color
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.Adornee = model
    highlight.Parent = model
    return highlight
end

local function destroyESP()
    for _, obj in pairs(espObjects) do
        pcall(function() obj:Destroy() end)
    end
    espObjects = {}
end

local function updateESP()
    if not CONFIG.ESPEnabled then
        destroyESP()
        return
    end

    destroyESP()

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 then
                local hl = createHighlight(player.Character, CONFIG.ESPColor)
                if hl then table.insert(espObjects, hl) end
            end
        end
    end

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj ~= LocalPlayer.Character and obj:FindFirstChild("HumanoidRootPart") then
            local humanoid = obj:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 and not obj:IsDescendantOf(Players) then
                local hl = createHighlight(obj, CONFIG.ESPColor)
                if hl then table.insert(espObjects, hl) end
            end
        end
    end
end

local function applyTransparencyLive()
    for _, obj in pairs(espObjects) do
        pcall(function()
            obj.FillTransparency = CONFIG.ESPFillTransparency
            obj.OutlineTransparency = CONFIG.ESPOutlineTransparency
        end)
    end
end

task.spawn(function()
    while true do
        if CONFIG.ESPEnabled then
            updateESP()
        end
        task.wait(0.5)
    end
end)

-- ──────────────────────────────────────────────
--  UTILS
-- ──────────────────────────────────────────────
local isDashing = false
local isAttacking = false
local dashSuccessCount = 0
local dashFailCount = 0

local function getHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getAnimator()
    local char = LocalPlayer.Character
    if not char then return nil end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return nil end
    return humanoid:FindFirstChildOfClass("Animator")
end

local function isAliveModel(model)
    local myChar = LocalPlayer.Character
    if model == myChar then return false end
    local root = model:FindFirstChild("HumanoidRootPart")
    local humanoid = model:FindFirstChild("Humanoid")
    return root and humanoid and humanoid.Health > 0
end

local function findNearestTarget()
    local hrp = getHRP()
    if not hrp then return nil end

    local nearest = nil
    local bestDist = math.huge

    local function checkModel(model)
        if not isAliveModel(model) then return end
        local root = model:FindFirstChild("HumanoidRootPart")
        local dist = (hrp.Position - root.Position).Magnitude
        if dist < bestDist then
            bestDist = dist
            nearest = model
        end
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            checkModel(player.Character)
        end
    end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") then checkModel(obj) end
    end

    return nearest
end

-- ──────────────────────────────────────────────
--  TRAIL
-- ──────────────────────────────────────────────
local function createTrail(rootPart)
    local a0 = Instance.new("Attachment", rootPart)
    local a1 = Instance.new("Attachment", rootPart)
    a1.Position = Vector3.new(0, 2, 0)
    local trail = Instance.new("Trail", rootPart)
    trail.Attachment0 = a0
    trail.Attachment1 = a1
    trail.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
    trail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.4),
        NumberSequenceKeypoint.new(1, 1),
    })
    trail.Lifetime = CONFIG.TrailLifetime
    trail.MinLength = 0
    trail.FaceCamera = true
    task.delay(CONFIG.TrailLifetime + 0.1, function()
        trail:Destroy(); a0:Destroy(); a1:Destroy()
    end)
end

-- ──────────────────────────────────────────────
--  ANIMATION PLAYER
-- ──────────────────────────────────────────────
local cachedAnims = {}

local function playDashAnimation(direction, duration)
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
    isAttacking = true
    task.delay(1.113, function()
        if track.IsPlaying then track:Stop() end
        isAttacking = false
    end)
end

-- ──────────────────────────────────────────────
--  CURVED DASH (IMPROVED)
-- ──────────────────────────────────────────────
local function lockRotationToTarget(targetRoot)
    local connection
    connection = RunService.RenderStepped:Connect(function()
        if not isDashing or not targetRoot.Parent then
            connection:Disconnect()
            return
        end
        local currentHRP = getHRP()
        if currentHRP and targetRoot and targetRoot.Parent then
            local lookDir = (targetRoot.Position - currentHRP.Position).Unit
            currentHRP.CFrame = CFrame.new(currentHRP.Position, currentHRP.Position + lookDir)
        end
    end)
    return connection
end

local function performCurvedDash(targetRoot, isRetry)
    local hrp = getHRP()
    if not hrp or isDashing then 
        return false 
    end

    isDashing = true
    local myPos = hrp.Position
    local destPos = (targetRoot.CFrame * CFrame.new(0, 0, CONFIG.BehindOffset)).Position

    if (myPos - destPos).Magnitude < CONFIG.AlreadyBehindTolerance then
        print("[DivergentFist] Already behind — skip dash")
        playAttackAnimation()
        isDashing = false
        triggerBlackFlash()
        return true
    end

    local lockConnection = lockRotationToTarget(targetRoot)

    local dist = (destPos - myPos).Magnitude
    if dist < 0.5 then
        isDashing = false
        if lockConnection then lockConnection:Disconnect() end
        return false
    end

    local dir = (destPos - myPos).Unit
    local side = dir:Cross(Vector3.new(0, 1, 0)).Unit
    local isLeft = math.random(1, 2) == 2
    if isLeft then side = -side end
    local dashDirection = isLeft and "Left" or "Right"

    local arcDef = {
        { 0.10, CONFIG.SideWidth * 0.50 },
        { 0.30, CONFIG.SideWidth * 0.80 },
        { 0.55, CONFIG.SideWidth * 0.70 },
        { 0.75, CONFIG.SideWidth * 0.40 },
        { 1.00, 0 },
    }

    local waypoints = {}
    for i = 1, math.min(CONFIG.ArcSegments, #arcDef) do
        table.insert(waypoints,
            myPos + (dir * dist * arcDef[i][1]) + (side * dist * arcDef[i][2]))
    end

    local totalTime = math.max(dist / CONFIG.DashSpeed, 0.08)
    local segTime = totalTime / #waypoints

    createTrail(hrp)
    local dashTrack = playDashAnimation(dashDirection, totalTime)
    print(string.format("[DivergentFist] Dash %s %s", dashDirection, isRetry and "(Retry)" or ""))

    for i, wp in ipairs(waypoints) do
        local lookDir = (i < #waypoints)
            and (waypoints[i + 1] - wp).Unit
            or (targetRoot.Position - wp).Unit
        TweenService:Create(hrp,
            TweenInfo.new(segTime, Enum.EasingStyle.Linear),
            { CFrame = CFrame.new(wp, wp + lookDir) }
        ):Play()
        task.wait(segTime)
    end

    hrp.CFrame = CFrame.lookAt(destPos, targetRoot.Position)
    if dashTrack and dashTrack.IsPlaying then dashTrack:Stop(0.1) end
    if lockConnection then lockConnection:Disconnect() end
    isDashing = false

    -- Wait for dash to complete before playing attack
    task.wait(0.1)
    playAttackAnimation()
    
    dashSuccessCount = dashSuccessCount + 1
    print(string.format("[DivergentFist] Dash complete (Success: %d, Failed: %d)", dashSuccessCount, dashFailCount))
    return true
end

-- ──────────────────────────────────────────────
--  IMPROVED RETRY SYSTEM WITH VALIDATION
-- ──────────────────────────────────────────────
local function safeFireRemote(remote, args, maxAttempts)
    local attempts = 0
    local pingAdjust = getPingAdjustment()
    
    while attempts < (maxAttempts or 2) do
        local success = pcall(function()
            remote:FireServer(table.unpack(args))
        end)
        
        if success then
            return true
        end
        
        attempts = attempts + 1
        print(string.format("[DivergentFist] Remote fire attempt %d failed, retrying...", attempts))
        task.wait(pingAdjust)
    end
    
    return false
end

local function performRetryDash(targetRoot, args)
    local retryAttempts = 0
    
    while retryAttempts < CONFIG.MaxRetryAttempts do
        if not targetRoot.Parent or not isAliveModel(targetRoot.Parent) then
            print("[DivergentFist][Retry] Target gone — abort")
            return false
        end
        
        print(string.format("[DivergentFist][Retry] Attempt %d/%d", retryAttempts + 1, CONFIG.MaxRetryAttempts))
        
        -- Perform the dash
        local dashSuccess = performCurvedDash(targetRoot, true)
        
        if dashSuccess then
            -- Wait for attack animation to start
            task.wait(0.2)
            
            -- Fire the remote with black flash effect
            if CONFIG.RetryFire then
                print("[DivergentFist][Retry] Firing DivergentFist remote...")
                triggerBlackFlash()
                
                local fireSuccess = safeFireRemote(targetRemote, args, 3)
                if fireSuccess then
                    print("[DivergentFist][Retry] Success!")
                    return true
                end
            end
        else
            dashFailCount = dashFailCount + 1
        end
        
        retryAttempts = retryAttempts + 1
        if retryAttempts < CONFIG.MaxRetryAttempts then
            local waitTime = CONFIG.RetryDelay + getPingAdjustment()
            task.wait(waitTime)
        end
    end
    
    print("[DivergentFist][Retry] Max retries reached")
    return false
end

-- ──────────────────────────────────────────────
--  HOOK (IMPROVED)
-- ──────────────────────────────────────────────
local isCooling = false
local isRetrying = false

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    if getnamecallmethod() ~= "FireServer" or self ~= targetRemote then
        return oldNamecall(self, ...)
    end

    if isRetrying then return oldNamecall(self, ...) end
    if isCooling then return oldNamecall(self, ...) end
    isCooling = true

    local args = { ... }
    local target = findNearestTarget()
    local targetRoot = target and target:FindFirstChild("HumanoidRootPart")

    -- Fire the original remote first
    local result = oldNamecall(self, ...)

    -- Wait for initial delay
    local initialDelay = CONFIG.FireDelay + getPingAdjustment()
    task.delay(initialDelay, function()
        if targetRoot and targetRoot.Parent then
            -- Return skill if possible
            if returnSkillRemote then
                pcall(function() returnSkillRemote:FireServer() end)
            end

            -- Wait for retry delay
            task.spawn(function()
                task.wait(CONFIG.RetryDelay + getPingAdjustment())

                if not targetRoot.Parent or not isAliveModel(targetRoot.Parent) then
                    print("[DivergentFist][Retry] Target gone — abort")
                    task.defer(function() isCooling = false end)
                    return
                end

                isRetrying = true
                local retrySuccess = performRetryDash(targetRoot, args)
                isRetrying = false
                
                task.defer(function() isCooling = false end)
            end)
        else
            -- Target invalid, fire original again as fallback
            pcall(function() targetRemote:FireServer(table.unpack(args)) end)
            task.defer(function() isCooling = false end)
        end
    end)

    -- Spawn initial dash
    task.spawn(function()
        if targetRoot and targetRoot.Parent then
            performCurvedDash(targetRoot, false)
        end
    end)

    return result
end)

-- ──────────────────────────────────────────────
--  LUNA GUI
-- ──────────────────────────────────────────────
local Window = Luna:CreateWindow({
    Name             = "Divergent Fist v2",
    Subtitle         = "by ScriptHub | FIXED",
    LogoID           = nil,
    LoadingEnabled   = true,
    LoadingTitle     = "Divergent Fist v2",
    LoadingSubtitle  = "Faint System Fixed",
    ConfigSettings   = {
        RootFolder   = nil,
        ConfigFolder = "DivergentFist",
    },
    KeySystem = false,
})

Window:CreateHomeTab({
    SupportedExecutors = {
        "Synapse X", "Krnl", "ProtoSmasher", "Fluxus",
        "Script-Ware", "Delta", "Wave", "Electron",
    },
    DiscordInvite = "discord.gg/scriptHub", -- Placeholder, update with real invite
    Icon = 1,
})

-- ── SETTINGS TAB ────────────────────────────────
local SettingsTab = Window:CreateTab({
    Name        = "Settings",
    Icon        = "settings",
    ImageSource = "Material",
    ShowTitle   = true,
})

SettingsTab:CreateSection("Dash Settings")

SettingsTab:CreateSlider({
    Name         = "Dash Speed",
    Range        = {30, 150},
    Increment    = 1,
    CurrentValue = CONFIG.DashSpeed,
    Callback     = function(value)
        CONFIG.DashSpeed = value
    end,
}, "DashSpeed")

SettingsTab:CreateSlider({
    Name         = "Behind Offset",
    Range        = {3, 10},
    Increment    = 0.5,
    CurrentValue = CONFIG.BehindOffset,
    Callback     = function(value)
        CONFIG.BehindOffset = value
    end,
}, "BehindOffset")

SettingsTab:CreateSlider({
    Name         = "Fire Delay (×0.01s)",
    Range        = {10, 100},
    Increment    = 1,
    CurrentValue = math.floor(CONFIG.FireDelay * 100),
    Callback     = function(value)
        CONFIG.FireDelay = value / 100
    end,
}, "FireDelay")

SettingsTab:CreateSection("Combat Settings")

SettingsTab:CreateToggle({
    Name         = "Retry Fire",
    Description  = nil,
    CurrentValue = CONFIG.RetryFire,
    Callback     = function(value)
        CONFIG.RetryFire = value
        _G.retryfire = value
    end,
}, "RetryFire")

SettingsTab:CreateToggle({
    Name         = "Black Flash Effect",
    Description  = "Screen flash when faint succeeds",
    CurrentValue = CONFIG.BlackFlashEffect,
    Callback     = function(value)
        CONFIG.BlackFlashEffect = value
    end,
}, "BlackFlashEffect")

SettingsTab:CreateSlider({
    Name         = "Max Retry Attempts",
    Range        = {1, 5},
    Increment    = 1,
    CurrentValue = CONFIG.MaxRetryAttempts,
    Callback     = function(value)
        CONFIG.MaxRetryAttempts = value
    end,
}, "MaxRetryAttempts")

-- ── STATS SECTION ────────────────────────────────
SettingsTab:CreateSection("Statistics")

SettingsTab:CreateButton({
    Name        = "Show Stats",
    Description = "View dash success/fail rates",
    Callback    = function()
        Luna:Notification({
            Title       = "Dash Statistics",
            Icon        = "bar-chart",
            ImageSource = "Material",
            Content     = string.format("Success: %d | Failed: %d | Rate: %.1f%%", 
                dashSuccessCount, dashFailCount, 
                dashSuccessCount > 0 and (dashSuccessCount / (dashSuccessCount + dashFailCount) * 100) or 0),
        })
    end,
})

-- ── ESP TAB ──────────────────────────────────────
local ESPTab = Window:CreateTab({
    Name        = "ESP",
    Icon        = "visibility",
    ImageSource = "Material",
    ShowTitle   = true,
})

ESPTab:CreateSection("ESP Settings")

ESPTab:CreateToggle({
    Name         = "Enable ESP",
    Description  = nil,
    CurrentValue = CONFIG.ESPEnabled,
    Callback     = function(value)
        CONFIG.ESPEnabled = value
        if not value then
            destroyESP()
        else
            updateESP()
        end
    end,
}, "ESPEnabled")

ESPTab:CreateColorPicker({
    Name     = "ESP Color",
    Color    = CONFIG.ESPColor,
    Flag     = "ESPColor",
    Callback = function(color)
        CONFIG.ESPColor = color
        if CONFIG.ESPEnabled then updateESP() end
    end,
}, "ESPColor")

ESPTab:CreateSection("Transparency")

ESPTab:CreateSlider({
    Name         = "Fill Transparency",
    Range        = {0, 100},
    Increment    = 1,
    CurrentValue = math.floor(CONFIG.ESPFillTransparency * 100),
    Callback     = function(value)
        CONFIG.ESPFillTransparency = value / 100
        applyTransparencyLive()
    end,
}, "ESPFillTransparency")

ESPTab:CreateSlider({
    Name         = "Outline Transparency",
    Range        = {0, 100},
    Increment    = 1,
    CurrentValue = math.floor(CONFIG.ESPOutlineTransparency * 100),
    Callback     = function(value)
        CONFIG.ESPOutlineTransparency = value / 100
        applyTransparencyLive()
    end,
}, "ESPOutlineTransparency")

ESPTab:CreateButton({
    Name        = "Refresh ESP",
    Description = nil,
    Callback    = function()
        updateESP()
        Luna:Notification({
            Title       = "ESP",
            Icon        = "visibility",
            ImageSource = "Material",
            Content     = "ESP highlights refreshed.",
        })
    end,
})

-- ── THEME TAB ────────────────────────────────────
local ThemeTab = Window:CreateTab({
    Name        = "Theme",
    Icon        = "palette",
    ImageSource = "Material",
    ShowTitle   = true,
})
ThemeTab:BuildThemeSection()

print("[DivergentFist v2] Loaded with fixes!")
print(string.format("[DivergentFist] Speed:%d | FireDelay:%.2fs | Offset:%.1f | MaxRetries:%d",
    CONFIG.DashSpeed, CONFIG.FireDelay, CONFIG.BehindOffset, CONFIG.MaxRetryAttempts))
print("[DivergentFist] Fixes applied: Ping-adaptive timing, Black flash sync, Retry validation")