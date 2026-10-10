local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local SoundService     = game:GetService("SoundService")
local TweenService     = game:GetService("TweenService")
local HttpService      = game:GetService("HttpService")
local TeleportService  = game:GetService("TeleportService")
local Camera           = workspace.CurrentCamera
local LocalPlayer      = Players.LocalPlayer

local ESP_RANGE           = 600
local ESP_REFRESH         = 0.1
local ESP_RED             = Color3.fromRGB(255, 0, 0)
local ESP_FILL            = 0.6
local ESP_OUTLINE         = 0

local TAG_NAME_OFFSET     = Vector3.new(0, 2.6, 0)
local TAG_DIST_OFFSET     = Vector3.new(0, -2.8, 0)

local AIM_FOV             = 600
local AIM_MAX_DIST        = 800
local AIM_FRONT_BIAS      = 0.4
local AIM_TEAM_CHECK      = false
local AIM_WALL_CHECK      = true
local AIM_SWITCH_DELAY    = 0.15

local SMOOTH_ON           = false
local SMOOTH_FACTOR       = 0.25
local SMOOTH_MIN          = 0.05
local SMOOTH_MAX          = 1.0
local SMOOTH_STEP         = 0.05

local TEAM_CHECK          = false

local KILL_SOUND_ID       = "rbxassetid://125662494668382"
local KILL_SOUND_VOL      = 2
local KILL_SOUND_MODE     = "target"
local KILL_SOUND_RADIUS   = 100
local KILL_CONFIRM_WINDOW = 1.0

local CLR_ON              = Color3.fromRGB(120, 220, 150)
local CLR_OFF             = Color3.fromRGB(220, 110, 110)
local CLR_ACCENT          = Color3.fromRGB(120, 180, 255)
local CLR_BG              = Color3.fromRGB(22, 22, 28)
local CLR_TEXT            = Color3.fromRGB(235, 235, 240)
local CLR_MUTED           = Color3.fromRGB(150, 150, 160)
local CLR_DIVIDER         = Color3.fromRGB(55, 55, 65)

local BRAND_TAG           = "By: DoodScriptBoy"
local BRAND_DISCORD       = "https://discord.gg/5xUYcteRC"

local espOn        = false
local aimOn        = false
local target       = nil
local lastSwitch   = 0
local lastEspTick  = 0
local lastShot     = 0
local highlights   = {}
local nameTags     = {}
local wmGui, wmFrame, wmStatus
local hopGui, hopOpen
local killSoundInst
local conns = {}

local function keep(c)
    conns[#conns + 1] = c
    return c
end

local function alive(plr)
    local c = plr.Character
    return c and c:FindFirstChild("Humanoid") and c.Humanoid.Health > 0
end

local function parentGui()
    return (gethui and gethui()) or game:GetService("CoreGui")
end

local function panel(props)
    local f = Instance.new("Frame")
    f.BackgroundColor3        = props.bg or CLR_BG
    f.BackgroundTransparency  = props.bgT or 0.15
    f.BorderSizePixel         = 0
    f.Size                    = props.size
    f.Position                = props.pos
    f.AnchorPoint             = props.anchor or Vector2.new(0, 0)
    f.Parent                  = props.parent
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, props.radius or 10)
    c.Parent = f
    if props.stroke ~= false then
        local s = Instance.new("UIStroke")
        s.Color = props.strokeClr or CLR_ACCENT
        s.Thickness = props.strokeW or 1.3
        s.Transparency = props.strokeT or 0.35
        s.Parent = f
    end
    return f
end

local function label(props)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Font = props.font or Enum.Font.Gotham
    l.TextSize = props.size or 13
    l.TextColor3 = props.color or CLR_TEXT
    l.TextXAlignment = props.x or Enum.TextXAlignment.Left
    l.TextYAlignment = Enum.TextYAlignment.Center
    l.Text = props.text or ""
    l.Position = props.pos or UDim2.new(0, 0, 0, 0)
    l.Size = props.dim or UDim2.new(1, 0, 1, 0)
    l.TextStrokeTransparency = props.stroke == false and 1 or 0.6
    l.Parent = props.parent
    return l
end

local function buildWatermark()
    wmGui = Instance.new("ScreenGui")
    wmGui.Name = "nt_watermark"
    wmGui.ResetOnSpawn = false
    wmGui.IgnoreGuiInset = true
    wmGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    wmGui.DisplayOrder = 999
    wmGui.Parent = parentGui()

    wmFrame = panel({
        parent = wmGui,
        size = UDim2.new(0, 210, 0, 0),
        pos = UDim2.new(1, -14, 1, -14),
        anchor = Vector2.new(1, 1),
        radius = 10,
        bgT = 0.2,
        strokeClr = CLR_ACCENT,
        strokeT = 0.5,
    })
    wmFrame.AutomaticSize = Enum.AutomaticSize.Y

    local pad = Instance.new("UIPadding")
    pad.PaddingTop    = UDim.new(0, 10)
    pad.PaddingBottom = UDim.new(0, 10)
    pad.PaddingLeft   = UDim.new(0, 12)
    pad.PaddingRight  = UDim.new(0, 12)
    pad.Parent = wmFrame

    local list = Instance.new("UIListLayout")
    list.FillDirection = Enum.FillDirection.Vertical
    list.HorizontalAlignment = Enum.HorizontalAlignment.Right
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Padding = UDim.new(0, 4)
    list.Parent = wmFrame

    local brand = label({
        parent = wmFrame, font = Enum.Font.GothamBold, size = 13,
        color = CLR_ACCENT, text = "NEON TEAM", x = Enum.TextXAlignment.Right,
        dim = UDim2.new(1, 0, 0, 16),
    })
    brand.LayoutOrder = 1

    wmStatus = {}
    local function row(order, key)
        local r = label({
            parent = wmFrame, font = Enum.Font.Gotham, size = 12,
            color = CLR_MUTED, text = key .. "   off", x = Enum.TextXAlignment.Right,
            dim = UDim2.new(1, 0, 0, 15),
        })
        r.LayoutOrder = order
        wmStatus[key] = r
    end

    row(2, "esp")
    row(3, "aim")
    row(4, "smooth")

    local div = Instance.new("Frame")
    div.BackgroundColor3 = CLR_DIVIDER
    div.BorderSizePixel = 0
    div.Size = UDim2.new(1, 0, 0, 1)
    div.LayoutOrder = 5
    div.Parent = wmFrame

    local sig = label({
        parent = wmFrame, font = Enum.Font.Gotham, size = 11,
        color = CLR_MUTED, text = BRAND_TAG, x = Enum.TextXAlignment.Right,
        dim = UDim2.new(1, 0, 0, 14),
    })
    sig.LayoutOrder = 6

    local dis = label({
        parent = wmFrame, font = Enum.Font.Gotham, size = 11,
        color = CLR_MUTED, text = BRAND_DISCORD, x = Enum.TextXAlignment.Right,
        dim = UDim2.new(1, 0, 0, 14),
    })
    dis.LayoutOrder = 7
end

local function refreshStatus()
    if not wmStatus then return end
    local function paint(row, key, state)
        if not state then
            row.Text = key .. "   off"
            row.TextColor3 = CLR_MUTED
        else
            row.Text = key .. "   on"
            row.TextColor3 = CLR_ON
        end
    end
    paint(wmStatus.esp,    "esp",    espOn)
    paint(wmStatus.aim,    "aim",    aimOn)
    paint(wmStatus.smooth, "smooth", SMOOTH_ON)
end

local function buildHopPrompt()
    hopGui = Instance.new("ScreenGui")
    hopGui.Name = "nt_serverhop"
    hopGui.ResetOnSpawn = false
    hopGui.IgnoreGuiInset = true
    hopGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    hopGui.DisplayOrder = 1001
    hopGui.Enabled = false
    hopGui.Parent = parentGui()

    local card = panel({
        parent = hopGui,
        size = UDim2.new(0, 420, 0, 110),
        pos = UDim2.new(0.5, 0, 0, 44),
        anchor = Vector2.new(0.5, 0),
        radius = 14,
        bgT = 0.1,
        strokeClr = CLR_ACCENT,
        strokeT = 0.3,
        strokeW = 1.5,
    })

    local title = label({
        parent = card, font = Enum.Font.GothamBold, size = 16,
        color = CLR_TEXT, text = "Change server?",
        pos = UDim2.new(0, 20, 0, 16),
        dim = UDim2.new(1, -40, 0, 22),
    })

    local sub = label({
        parent = card, font = Enum.Font.Gotham, size = 12,
        color = CLR_MUTED, text = "You'll be moved to another server with free slots.",
        pos = UDim2.new(0, 20, 0, 40),
        dim = UDim2.new(1, -40, 0, 16),
    })

    local function makeBtn(text, color, pos)
        local b = panel({
            parent = card,
            size = UDim2.new(0, 90, 0, 34),
            pos = pos,
            anchor = Vector2.new(1, 0),
            radius = 8,
            bg = color,
            bgT = 0.15,
            strokeClr = color,
            strokeT = 0.1,
            strokeW = 1.2,
        })
        label({
            parent = b, font = Enum.Font.GothamBold, size = 14,
            color = Color3.fromRGB(255, 255, 255),
            text = text, x = Enum.TextXAlignment.Center,
        })
        return b
    end

    local no = makeBtn("N   Cancel", CLR_OFF,  UDim2.new(1, -20, 0, 62))
    local yes = makeBtn("Y   Go",    CLR_ON,   UDim2.new(1, -120, 0, 62))

    TweenService:Create(yes, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
        BackgroundTransparency = 0.35
    }):Play()
end

local function showHop()
    if not hopGui then buildHopPrompt() end
    hopGui.Enabled = true
    hopOpen = true
end

local function hideHop()
    if hopGui then hopGui.Enabled = false end
    hopOpen = false
end

local function doHop()
    print("[neon team] looking for a server...")
    local placeId = game.PlaceId
    local currentJob = game.JobId

    local url = string.format(
        "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100",
        placeId
    )

    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(url))
    end)

    if ok and decoded and decoded.data then
        local pool = {}
        for _, s in ipairs(decoded.data) do
            if s.id and s.id ~= currentJob and s.playing < s.maxPlayers then
                pool[#pool + 1] = s.id
            end
        end

        if #pool > 0 then
            local pick = pool[math.random(1, #pool)]
            print("[neon team] hopping to " .. pick)
            local ok2 = pcall(function()
                TeleportService:TeleportToPlaceInstance(placeId, pick, LocalPlayer)
            end)
            if ok2 then return end
        else
            print("[neon team] no free servers, trying same place")
        end
    else
        print("[neon team] http failed, trying same place")
    end

    pcall(function()
        TeleportService:Teleport(placeId, LocalPlayer)
    end)
end

local function initKillSound()
    if killSoundInst then return end
    local s = Instance.new("Sound")
    s.Name = "nt_killsound"
    s.SoundId = KILL_SOUND_ID
    s.Volume = KILL_SOUND_VOL
    s.PlayOnRemove = false
    s.RollOffMode = Enum.RollOffMode.InverseTapered
    s.RollOffMaxDistance = 10000
    s.RollOffMinDistance = 10
    s.Parent = workspace.CurrentCamera
    killSoundInst = s
end

local function playKillSound()
    if not killSoundInst then return end
    local ok = pcall(function()
        SoundService:PlayLocalSound(killSoundInst)
    end)
    if not ok or not killSoundInst.IsPlaying then
        pcall(function()
            killSoundInst:Stop()
            killSoundInst:Play()
        end)
    end
end

local function addHighlight(plr)
    if highlights[plr] and highlights[plr].Parent then return highlights[plr] end
    local char = plr.Character
    if not char then return nil end

    local hl = Instance.new("Highlight")
    hl.Name = "nt_esp"
    hl.FillColor = ESP_RED
    hl.OutlineColor = ESP_RED
    hl.FillTransparency = ESP_FILL
    hl.OutlineTransparency = ESP_OUTLINE
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = char
    hl.Parent = char

    highlights[plr] = hl
    return hl
end

local function killHighlight(plr)
    local h = highlights[plr]
    if h then h:Destroy() end
    highlights[plr] = nil
end

local function clearHighlights()
    for _, h in pairs(highlights) do
        if h then h:Destroy() end
    end
    highlights = {}
end

local function addTag(plr)
    local char = plr.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    if not head or not hrp then return end

    local bbName = Instance.new("BillboardGui")
    bbName.Name = "nt_name"
    bbName.Size = UDim2.new(0, 200, 0, 18)
    bbName.StudsOffset = TAG_NAME_OFFSET
    bbName.AlwaysOnTop = true
    bbName.Adornee = head
    bbName.Parent = head

    local nameLbl = label({
        parent = bbName, font = Enum.Font.GothamBold, size = 13,
        color = Color3.fromRGB(255, 255, 255), text = plr.Name,
        x = Enum.TextXAlignment.Center,
    })

    local bbDist = Instance.new("BillboardGui")
    bbDist.Name = "nt_dist"
    bbDist.Size = UDim2.new(0, 200, 0, 16)
    bbDist.StudsOffset = TAG_DIST_OFFSET
    bbDist.AlwaysOnTop = true
    bbDist.Adornee = hrp
    bbDist.Parent = hrp

    local distLbl = label({
        parent = bbDist, font = Enum.Font.Code, size = 12,
        color = Color3.fromRGB(210, 210, 220), text = "",
        x = Enum.TextXAlignment.Center,
    })

    nameTags[plr] = {name = bbName, dist = bbDist, nameLbl = nameLbl, distLbl = distLbl}
end

local function killTag(plr)
    local t = nameTags[plr]
    if t then
        if t.name then t.name:Destroy() end
        if t.dist then t.dist:Destroy() end
    end
    nameTags[plr] = nil
end

local function clearTags()
    for _, t in pairs(nameTags) do
        if t.name then t.name:Destroy() end
        if t.dist then t.dist:Destroy() end
    end
    nameTags = {}
end

local function tickTags()
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        if TEAM_CHECK and plr.Team == LocalPlayer.Team then
            killTag(plr)
            continue
        end

        local char = plr.Character
        local head = char and char:FindFirstChild("Head")
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        local hum  = char and char:FindFirstChild("Humanoid")

        if char and head and hrp and hum and hum.Health > 0 and myRoot then
            local dist = (hrp.Position - myRoot.Position).Magnitude
            if dist <= ESP_RANGE then
                if not nameTags[plr] or not nameTags[plr].name.Parent then
                    killTag(plr)
                    addTag(plr)
                end
                local t = nameTags[plr]
                if t then
                    if t.name.Adornee ~= head then t.name.Adornee = head end
                    if t.dist.Adornee ~= hrp then t.dist.Adornee = hrp end
                    t.distLbl.Text = string.format("%d m", math.floor(dist))
                    local fade = math.clamp(dist / ESP_RANGE, 0, 1) * 0.4
                    t.nameLbl.TextTransparency = fade
                    t.distLbl.TextTransparency = fade
                end
            else
                killTag(plr)
            end
        else
            killTag(plr)
        end
    end
end

local function tickEsp()
    if not espOn then return end

    local myChar = LocalPlayer.Character
    if not myChar then return end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    local myPos = myRoot.Position

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end

        if TEAM_CHECK and plr.Team == LocalPlayer.Team then
            killHighlight(plr)
            continue
        end

        local char = plr.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChild("Humanoid")

        if char and hrp and hum and hum.Health > 0 then
            local dist = (hrp.Position - myPos).Magnitude
            if dist <= ESP_RANGE then
                local hl = addHighlight(plr)
                if hl and hl.Adornee ~= char then hl.Adornee = char end
                if hl then
                    local t = dist / ESP_RANGE
                    hl.FillTransparency = 0.4 + t * 0.4
                end
            else
                killHighlight(plr)
            end
        else
            killHighlight(plr)
        end
    end

    tickTags()
end

local function score(plr)
    local char = plr.Character
    local head = char and char:FindFirstChild("Head")
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not head or not hrp then return nil end

    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end

    local worldDist = (hrp.Position - myRoot.Position).Magnitude
    if worldDist > AIM_MAX_DIST then return nil end

    local sp, onScreen = Camera:WorldToViewportPoint(head.Position)
    if not onScreen then return nil end

    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local screenDist = (Vector2.new(sp.X, sp.Y) - center).Magnitude
    if screenDist > AIM_FOV then return nil end

    local look = Camera.CFrame.LookVector
    local dir  = (head.Position - Camera.CFrame.Position).Unit
    local dot  = look:Dot(dir)
    if dot < AIM_FRONT_BIAS then return nil end

    if AIM_WALL_CHECK then
        local origin = Camera.CFrame.Position
        local ray = Ray.new(origin, head.Position - origin)
        local ignore = { LocalPlayer.Character, char }
        local hit = workspace:FindPartOnRayWithIgnoreList(ray, ignore, false, true)
        if hit then return nil end
    end

    return screenDist - dot * 200
end

local function bestTarget()
    local best, bestScore = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer or not alive(plr) then continue end
        if AIM_TEAM_CHECK and plr.Team == LocalPlayer.Team then continue end
        local s = score(plr)
        if s and s < bestScore then
            bestScore = s
            best = plr
        end
    end
    return best
end

local function targetHead()
    if not target or not alive(target) then return nil end
    local char = target.Character
    local head = char and char:FindFirstChild("Head")
    return head and head.Position or nil
end

local function watchKills(plr)
    if plr == LocalPlayer then return end

    local function attach(char)
        local hum = char:WaitForChild("Humanoid", 5)
        if not hum then return end

        keep(hum.Died:Connect(function()
            local play = false

            if KILL_SOUND_MODE == "target" then
                if target == plr then play = true end
            elseif KILL_SOUND_MODE == "nearby" then
                local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if myRoot and hrp then
                    if (hrp.Position - myRoot.Position).Magnitude <= KILL_SOUND_RADIUS then
                        play = true
                    end
                end
            elseif KILL_SOUND_MODE == "confirm" then
                if target == plr and (tick() - lastShot) <= KILL_CONFIRM_WINDOW then
                    play = true
                end
            end

            if play then
                playKillSound()
                print("[neon team] kill: " .. plr.Name)
            end
        end))
    end

    if plr.Character then attach(plr.Character) end
    keep(plr.CharacterAdded:Connect(attach))
end

local function onJoin(plr)
    watchKills(plr)
    keep(plr.CharacterRemoving:Connect(function()
        killHighlight(plr)
        killTag(plr)
        if target == plr then target = nil end
    end))
end

local function onLeave(plr)
    killHighlight(plr)
    killTag(plr)
    if target == plr then target = nil end
end

keep(Players.PlayerAdded:Connect(onJoin))
keep(Players.PlayerRemoving:Connect(onLeave))
for _, plr in ipairs(Players:GetPlayers()) do onJoin(plr) end

local function shutdown()
    for _, c in ipairs(conns) do
        pcall(function() c:Disconnect() end)
    end
    conns = {}

    clearHighlights()
    clearTags()

    if wmGui then wmGui:Destroy() wmGui = nil end
    if hopGui then hopGui:Destroy() hopGui = nil end
    if killSoundInst then killSoundInst:Destroy() killSoundInst = nil end

    espOn = false
    aimOn = false
    target = nil
    wmStatus = nil
    hopOpen = false

    print("[neon team] unloaded. cya.")
end

keep(UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end

    if hopOpen then
        if input.KeyCode == Enum.KeyCode.N then
            hideHop()
            print("[neon team] hop cancelled")
        elseif input.KeyCode == Enum.KeyCode.Y then
            hideHop()
            doHop()
        elseif input.KeyCode == Enum.KeyCode.Z then
            shutdown()
        end
        return
    end

    if input.KeyCode == Enum.KeyCode.Z then
        shutdown()

    elseif input.KeyCode == Enum.KeyCode.L then
        showHop()
        print("[neon team] hop prompt shown")

    elseif input.KeyCode == Enum.KeyCode.P then
        espOn = not espOn
        if not espOn then
            clearHighlights()
            clearTags()
        end
        print("[neon team] esp " .. (espOn and "on" or "off"))
        refreshStatus()

    elseif input.KeyCode == Enum.KeyCode.T then
        aimOn = not aimOn
        if aimOn then
            target = bestTarget()
            lastSwitch = tick()
            if target then
                print("[neon team] locked " .. target.Name)
            else
                print("[neon team] nothing visible in front")
                aimOn = false
            end
        else
            target = nil
            print("[neon team] unlocked")
        end
        refreshStatus()

    elseif input.KeyCode == Enum.KeyCode.K then
        SMOOTH_ON = not SMOOTH_ON
        print(string.format("[neon team] smooth %s (%.2f)", SMOOTH_ON and "on" or "off", SMOOTH_FACTOR))
        refreshStatus()

    elseif input.KeyCode == Enum.KeyCode.LeftBracket then
        SMOOTH_FACTOR = math.max(SMOOTH_MIN, SMOOTH_FACTOR - SMOOTH_STEP)
        print(string.format("[neon team] smooth factor %.2f", SMOOTH_FACTOR))

    elseif input.KeyCode == Enum.KeyCode.RightBracket then
        SMOOTH_FACTOR = math.min(SMOOTH_MAX, SMOOTH_FACTOR + SMOOTH_STEP)
        print(string.format("[neon team] smooth factor %.2f", SMOOTH_FACTOR))
    end
end))

keep(UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        lastShot = tick()
    end
end))

keep(RunService.Heartbeat:Connect(function()
    if not espOn then return end
    local now = tick()
    if now - lastEspTick < ESP_REFRESH then return end
    lastEspTick = now
    pcall(tickEsp)
end))

keep(RunService.RenderStepped:Connect(function()
    if not aimOn then return end
    local now = tick()

    if not target or not alive(target) or (now - lastSwitch >= AIM_SWITCH_DELAY) then
        local best = bestTarget()
        if best and best ~= target then
            target = best
            lastSwitch = now
        elseif not best then
            target = nil
            return
        end
    end

    local head = targetHead()
    if head then
        local desired = CFrame.new(Camera.CFrame.Position, head)
        if SMOOTH_ON then
            Camera.CFrame = Camera.CFrame:Lerp(desired, SMOOTH_FACTOR)
        else
            Camera.CFrame = desired
        end
    end
end))

initKillSound()
buildWatermark()
refreshStatus()