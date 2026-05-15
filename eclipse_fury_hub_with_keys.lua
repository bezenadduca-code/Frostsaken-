local Luna = loadstring(game:HttpGet("https://raw.githubusercontent.com/Nebula-Softworks/Luna-Interface-Suite/refs/heads/master/source.lua", true))()
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- ──────────────────────────────────────────────
--  KEY SYSTEM
-- ──────────────────────────────────────────────
local VALID_KEYS = {
    "eclipse1", "eclipse69", "eclipse420", "strike1", "strike69", "strike420",
    "arcgod", "arcpro", "arc123", "arc777", "voidgod", "voidpro", "void123",
    "fistgod", "fistpro", "dashgod", "dash420", "keyme", "key123", "easykey",
    "hub123", "hub420", "hubgod", "moonlight", "darkfist", "cursedkey", "nebulax",
    "eclipsegod", "strikemaster", "arcmaster", "voidmaster", "fistmaster",
    "proplayer", "godmode1", "legend69", "secretkey", "freekey", "keyfree",
    "eclipsepro", "strikepro", "arcpro123", "voidpro", "fist123", "dashpro",
    "nightfist", "shadowarc", "blazekey", "stormfist", "ninjakey", "ghostarc",
    "lunarhub", "neonstrike", "apexkey", "zenith1", "helixkey", "pulsearch",
    "riftkey", "novafist", "cursedx", "oblivion1", "eternalkey", "infinity69",
    "key1", "key2", "key3", "key4", "key5", "key420", "key777", "key999",
    "es1", "es2", "es3", "es69", "es420", "eshub", "eshub69", "eshub420",
    "strike101", "arc101", "void101", "fist101", "dash101",
    "bestkey", "opkey", "tryhard1", "sweatkey", "pvpgod", "ranked1",
    "moon69", "star123", "sunfist", "icekey", "firearc", "thunderkey",
    "dragon1", "titankey", "demonfist", "angelarc", "darkvoid", "lightstrike",
    "hubpro", "hubgod69", "masterkey", "ownerkey", "devkey", "testerkey",
    "beta1", "alpha69", "omega1", "sigma420", "sigma69", "rizzkey",
    "skibidi1", "fanumkey", "ohioarc", "eclipseohio", "strikesigma",
    "arcsigma", "voidrizz", "fistfanum", "eclipse1234", "strike5678",
    "arc9999", "void7777", "fist8888", "dash999", "key5555",
    "prostrike", "godarc", "mastervoid", "legendfist", "ultrakey",
    "maxkey", "overkey", "brokenkey", "insanekey", "crazykey",
    "chillkey", "trykey", "winkey", "losekey", "ezkey", "hardkey",
    "eclipsevip", "strikevip", "arcvip", "voidvip", "fistvip",
    "hubvip", "secret1", "hiddenkey", "rarekey", "epickey",
    "mythic1", "legendarykey", "divinekey", "immortal69", "eternal420",
    "eclipse7", "strike8", "arc9", "void10", "fist11", "dash12",
    "key13", "hub14", "pro15", "god16", "arc17", "void18",
    "fist19", "strike20", "eclipse21", "key22", "hub23", "arc24",
    "void25", "fist26", "dash27", "strike28", "eclipse29", "key30",
    "eclipsex", "strikex", "arcx", "voidx", "fistx", "dashx",
    "keyx", "hubx", "prox", "godx", "legendx", "masterx",
    "eclipsey", "strikey", "arcy", "voidy", "fisty", "dashy",
    "keyy", "huby", "proy", "gody", "moonx", "starx",
    "eclipsez", "strikez", "arcz", "voidz", "fistz", "keyz",
    "hubz", "proz", "godz", "winz", "losez", "top1",
    "champ1", "kingkey", "queenkey", "bosskey", "elite1",
    "premium1", "exclusive", "limitedkey", "rarehub", "special1"
}

local KEY_FILE = "EclipseFuryHub_SavedKey.txt"

local function isValidKey(key)
    for _, validKey in ipairs(VALID_KEYS) do
        if key == validKey then
            return true
        end
    end
    return false
end

local function saveKey(key)
    writefile(KEY_FILE, key)
end

local function loadSavedKey()
    if isfile(KEY_FILE) then
        return readfile(KEY_FILE)
    end
    return nil
end

local function checkAndLoadScript()
    local savedKey = loadSavedKey()
    
    if savedKey and isValidKey(savedKey) then
        print("[KeySystem] Auto-loading with saved key...")
        return true
    end
    
    return false
end

-- Check for saved key first
if checkAndLoadScript() then
    print("[KeySystem] Key validated! Loading script...")
else
    -- Show key prompt
    local keyEntered = false
    
    local KeyWindow = Luna:CreateWindow({
        Name             = "Eclipse Fury Hub - Key System",
        Subtitle         = "Enter your key to continue",
        LogoID           = nil,
        LoadingEnabled   = false,
        ConfigSettings   = {
            RootFolder   = nil,
            ConfigFolder = "EclipseFuryHub",
        },
        KeySystem = false,
    })
    
    local KeyTab = KeyWindow:CreateTab({
        Name        = "Key",
        Icon        = "lock",
        ImageSource = "Material",
        ShowTitle   = true,
    })
    
    KeyTab:CreateSection("Enter Key")
    
    local keyInput = ""
    
    KeyTab:CreateInput({
        Name         = "Key",
        Description  = "Enter your access key",
        PlaceholderText = "Enter key here...",
        RemoveTextAfterFocusLost = false,
        Callback     = function(text)
            keyInput = text
        end,
    })
    
    KeyTab:CreateButton({
        Name        = "Submit Key",
        Description = "Click to validate your key",
        Callback    = function()
            if isValidKey(keyInput) then
                saveKey(keyInput)
                Luna:Notification({
                    Title       = "Key System",
                    Icon        = "check_circle",
                    ImageSource = "Material",
                    Content     = "Key accepted! Loading script...",
                })
                keyEntered = true
                task.wait(1)
                KeyWindow:Destroy()
            else
                Luna:Notification({
                    Title       = "Key System",
                    Icon        = "error",
                    ImageSource = "Material",
                    Content     = "Invalid key! Please try again.",
                })
            end
        end,
    })
    
    KeyTab:CreateButton({
        Name        = "Get Key",
        Description = "Click for key information",
        Callback    = function()
            Luna:Notification({
                Title       = "Key System",
                Icon        = "info",
                ImageSource = "Material",
                Content     = "Contact the developer for a key!",
            })
        end,
    })
    
    -- Wait for key validation
    repeat task.wait(0.1) until keyEntered
end

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
    task.delay(1.113, function()
        if track.IsPlaying then track:Stop() end
    end)
end

-- ──────────────────────────────────────────────
--  CURVED DASH
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
        if targetRoot and targetRoot.Parent then
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

                if not shouldRetryFire then
                    print("[DivergentFist][Retry] RetryFire OFF, skip fire")
                else
                    print("[DivergentFist][Retry] Fire DivergentFist")
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
--  LUNA GUI
-- ──────────────────────────────────────────────
local Window = Luna:CreateWindow({
    Name             = "Eclipse Fury Hub",
    Subtitle         = "by Mitsuki/Kitty/storm",
    LogoID           = nil,
    LoadingEnabled   = true,
    LoadingTitle     = "Eclipse Fury Hub",
    LoadingSubtitle  = "by Mitsuki/Kitty/storm",
    ConfigSettings   = {
        RootFolder   = nil,
        ConfigFolder = "EclipseFuryHub",
    },
    KeySystem = false,
})

Window:CreateHomeTab({
    SupportedExecutors = {
        "Synapse X", "Krnl", "ProtoSmasher", "Fluxus",
        "Script-Ware", "Delta", "Wave", "Electron",
    },
    DiscordInvite = "",
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

print("[DivergentFist] Loaded!")
print(string.format("[DivergentFist] Speed:%d | FireDelay:%.2fs | Offset:%.1f",
    CONFIG.DashSpeed, CONFIG.FireDelay, CONFIG.BehindOffset))
