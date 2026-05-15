local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

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
    FacingDotThreshold     = -0.6,
    RetryDelay             = 0.04,
    RetryFire              = true,
    ESPEnabled             = true,
    ESPColor               = Color3.fromRGB(255, 50, 50),
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
--  LOCK TARGET SYSTEM
--  Stores the PLAYER object (or model ref) so it
--  survives respawns; character is resolved fresh.
-- ──────────────────────────────────────────────
local lockedPlayer  = nil   -- Player instance (for player targets)
local lockedModel   = nil   -- Direct model ref (for NPC targets)
local lockHighlight = nil   -- Separate from ESP highlights

local function setLockHighlight(model)
    -- Remove old lock highlight
    if lockHighlight then
        pcall(function() lockHighlight:Destroy() end)
        lockHighlight = nil
    end
    if not model then return end
    local hl = Instance.new("Highlight")
    hl.Name = "DivFistLock"
    hl.FillColor = Color3.fromRGB(0, 255, 80)
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = 0.5
    hl.OutlineTransparency = 0
    hl.Adornee = model
    hl.Parent = model
    lockHighlight = hl
end

-- Returns the currently locked character model (resolves respawns)
local function getLockedCharacter()
    if lockedPlayer then
        -- Always grab fresh character from Player object
        local char = lockedPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                -- Keep highlight on current character
                if lockHighlight and lockHighlight.Adornee ~= char then
                    setLockHighlight(char)
                end
                return char
            end
        end
        return nil
    elseif lockedModel then
        if isAliveModel and isAliveModel(lockedModel) then
            return lockedModel
        end
        return nil
    end
    return nil
end

local function clearLock()
    lockedPlayer = nil
    lockedModel  = nil
    if lockHighlight then
        pcall(function() lockHighlight:Destroy() end)
        lockHighlight = nil
    end
end

-- ──────────────────────────────────────────────
--  ESP SYSTEM (NON-LAGGY)
-- ──────────────────────────────────────────────
local espObjects = {}

local function createHighlight(model, color)
    -- Don't double-highlight the locked target
    if lockHighlight and lockHighlight.Adornee == model then return nil end

    local highlight = Instance.new("Highlight")
    highlight.Name = "DivergentFistESP"
    highlight.FillTransparency = 0.7
    highlight.OutlineTransparency = 0.3
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

function isAliveModel(model)
    local myChar = LocalPlayer.Character
    if model == myChar then return false end
    local root = model:FindFirstChild("HumanoidRootPart")
    local humanoid = model:FindFirstChild("Humanoid")
    return root and humanoid and humanoid.Health > 0
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
    -- Always try locked target first
    local locked = getLockedCharacter()
    if locked then return locked end

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
    task.delay(1.113, function()
        if track.IsPlaying then track:Stop() end
    end)
end

-- ──────────────────────────────────────────────
--  CURVED DASH WITH LOCK
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

local function performCurvedDash(targetRoot)
    local hrp = getHRP()
    if not hrp or isDashing then return end

    isDashing = true
    local myPos = hrp.Position
    local destPos = (targetRoot.CFrame * CFrame.new(0, 0, CONFIG.BehindOffset)).Position

    if (myPos - destPos).Magnitude < CONFIG.AlreadyBehindTolerance then
        print("[DivergentFist] Already behind — skip dash")
        playAttackAnimation()
        isDashing = false
        return
    end

    local lockConnection = lockRotationToTarget(targetRoot)

    local dist = (destPos - myPos).Magnitude
    if dist < 0.5 then
        isDashing = false
        if lockConnection then lockConnection:Disconnect() end
        return
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
    print(string.format("[DivergentFist] Dash %s", dashDirection))

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

    playAttackAnimation()
    print("[DivergentFist] Dash complete → Attack animation playing")
end

-- ──────────────────────────────────────────────
--  HOOK
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

    local result = oldNamecall(self, ...)
    local args = { ... }
    local target = findNearestTarget()
    local targetRoot = target and target:FindFirstChild("HumanoidRootPart")

    task.delay(CONFIG.FireDelay, function()
        if targetRoot and targetRoot.Parent and not isTargetFacingAway(targetRoot) then
            print("[DivergentFist] Enemy turned → ReturnSkill")
            if returnSkillRemote then
                pcall(function() returnSkillRemote:FireServer() end)
            end

            task.spawn(function()
                task.wait(CONFIG.RetryDelay)

                if not targetRoot.Parent or not isAliveModel(targetRoot.Parent) then
                    print("[DivergentFist][Retry] Target gone — abort")
                    task.defer(function() isCooling = false end)
                    return
                end

                print("[DivergentFist][Retry] Re-dashing...")
                performCurvedDash(targetRoot)

                local shouldRetryFire = (_G.retryfire ~= nil) and _G.retryfire or CONFIG.RetryFire

                if not isTargetFacingAway(targetRoot) then
                    print("[DivergentFist][Retry] Failed again — giving up")
                elseif not shouldRetryFire then
                    print("[DivergentFist][Retry] Success → RetryFire OFF, skip fire")
                else
                    print("[DivergentFist][Retry] Success → Fire DivergentFist")
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
end)

-- ──────────────────────────────────────────────
--  RAYFIELD GUI  (fixed)
-- ──────────────────────────────────────────────
local Window = Rayfield:CreateWindow({
    Name          = "Divergent Fist",
    Icon          = 0,          -- use 0 or a valid image id; rbxassetid string breaks newer Rayfield
    LoadingTitle  = "Divergent Fist",
    LoadingSubtitle = "by ScriptHub",
    ConfigurationSaving = {
        Enabled    = true,
        FolderName = "DivergentFist",
        FileName   = "Settings",
    },
    Discord = {
        Enabled      = false,
        Invite       = "noinvitelink",
        RememberJoins = true,
    },
    KeySystem = false,
})

local MainTab     = Window:CreateTab("Main",     4483362458)
local SettingsTab = Window:CreateTab("Settings", 4483362458)
local ESPTab      = Window:CreateTab("ESP",      4483362458)

-- ── MAIN TAB ────────────────────────────────
local lockedLabel  -- we'll update this when lock changes

local function refreshLockLabel()
    if not lockedLabel then return end
    local locked = getLockedCharacter()
    if locked then
        lockedLabel.Title = "Locked: " .. locked.Name
    else
        lockedLabel.Title = "Locked: None"
    end
end

-- Status label (Section acts as a read-only label in Rayfield)
MainTab:CreateSection("Lock Status")

-- CreateButton returns the button; we piggy-back a section for status text
lockedLabel = MainTab:CreateSection("Locked: None")

MainTab:CreateButton({
    Name = "Lock Nearest Target",
    Callback = function()
        local hrp = getHRP()
        if not hrp then
            Rayfield:Notify({ Title = "Error", Content = "Character not found", Duration = 2 })
            return
        end

        local nearest = nil
        local bestDist = math.huge

        -- Check players first
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local char = player.Character
                if isAliveModel(char) then
                    local root = char:FindFirstChild("HumanoidRootPart")
                    local dist = (hrp.Position - root.Position).Magnitude
                    if dist < bestDist then
                        bestDist = dist
                        nearest = player   -- store the Player object
                    end
                end
            end
        end

        -- Check NPCs
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Model") and obj ~= LocalPlayer.Character and obj:FindFirstChild("HumanoidRootPart") then
                if isAliveModel(obj) and not obj:IsDescendantOf(Players) then
                    local root = obj:FindFirstChild("HumanoidRootPart")
                    local dist = (hrp.Position - root.Position).Magnitude
                    if dist < bestDist then
                        bestDist = dist
                        nearest = obj   -- store the model directly
                    end
                end
            end
        end

        if nearest then
            clearLock()
            if nearest:IsA("Player") then
                lockedPlayer = nearest
                setLockHighlight(nearest.Character)
                Rayfield:Notify({
                    Title   = "Target Locked",
                    Content = "Locked: " .. nearest.Name,
                    Duration = 3,
                })
            else
                lockedModel = nearest
                setLockHighlight(nearest)
                Rayfield:Notify({
                    Title   = "Target Locked",
                    Content = "Locked: " .. nearest.Name,
                    Duration = 3,
                })
            end
            refreshLockLabel()
        else
            Rayfield:Notify({ Title = "No Target", Content = "No valid target nearby", Duration = 2 })
        end
    end,
})

MainTab:CreateButton({
    Name = "Clear Lock",
    Callback = function()
        clearLock()
        refreshLockLabel()
        Rayfield:Notify({ Title = "Lock Cleared", Content = "Target lock removed", Duration = 2 })
    end,
})

-- ── SETTINGS TAB ────────────────────────────
SettingsTab:CreateSection("Dash Settings")

SettingsTab:CreateSlider({
    Name         = "Dash Speed",
    Range        = {30, 150},
    Increment    = 1,
    Suffix       = "Speed",
    CurrentValue = CONFIG.DashSpeed,
    Flag         = "DashSpeed",
    Callback     = function(value)
        CONFIG.DashSpeed = value
    end,
})

SettingsTab:CreateSlider({
    Name         = "Behind Offset",
    Range        = {3, 10},
    Increment    = 0.5,
    Suffix       = "Studs",
    CurrentValue = CONFIG.BehindOffset,
    Flag         = "BehindOffset",
    Callback     = function(value)
        CONFIG.BehindOffset = value
    end,
})

SettingsTab:CreateSlider({
    Name         = "Fire Delay",
    Range        = {10, 100},   -- Rayfield sliders need integers; store as /100
    Increment    = 1,
    Suffix       = "×0.01s",
    CurrentValue = math.floor(CONFIG.FireDelay * 100),
    Flag         = "FireDelay",
    Callback     = function(value)
        CONFIG.FireDelay = value / 100
    end,
})

SettingsTab:CreateSection("Combat Settings")

SettingsTab:CreateToggle({
    Name         = "Retry Fire",
    CurrentValue = CONFIG.RetryFire,
    Flag         = "RetryFire",
    Callback     = function(value)
        CONFIG.RetryFire = value
        _G.retryfire = value
    end,
})

-- ── ESP TAB ─────────────────────────────────
ESPTab:CreateSection("ESP Settings")

ESPTab:CreateToggle({
    Name         = "Enable ESP",
    CurrentValue = CONFIG.ESPEnabled,
    Flag         = "ESPEnabled",
    Callback     = function(value)
        CONFIG.ESPEnabled = value
        if not value then
            destroyESP()
        else
            updateESP()
        end
    end,
})

-- ColorPicker: Rayfield's correct API (no nested table)
ESPTab:CreateColorPicker({
    Name     = "ESP Color",
    Color    = CONFIG.ESPColor,
    Flag     = "ESPColor",
    Callback = function(color)
        CONFIG.ESPColor = color
        if CONFIG.ESPEnabled then updateESP() end
    end,
})

ESPTab:CreateButton({
    Name = "Refresh ESP",
    Callback = function()
        updateESP()
        Rayfield:Notify({ Title = "ESP Refreshed", Content = "ESP updated", Duration = 2 })
    end,
})

print("[DivergentFist] Loaded!")
print(string.format("[DivergentFist] Speed:%d | FireDelay:%.2fs | Offset:%.1f",
    CONFIG.DashSpeed, CONFIG.FireDelay, CONFIG.BehindOffset))
