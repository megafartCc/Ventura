-- ESP V2 — Clean module
-- gethui()-only, Heartbeat, full pcall, randomized names
-- Features: Skeleton, Box, Name, Health, Tracers

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera     = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

------------------------------------------------------------
-- Random name generator (looks like native Roblox UI IDs)
------------------------------------------------------------
local _seed = tick()
local function rname()
    local c = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local s, n = "", math.random(8, 14)
    for _ = 1, n do
        _seed = (_seed * 1664525 + 1013904223) % (2^32)
        s = s .. c:sub((_seed % #c) + 1, (_seed % #c) + 1)
    end
    return s
end

------------------------------------------------------------
-- gethui()-only (cached, never CoreGui)
------------------------------------------------------------
local _hui = nil
local function getHUI()
    if _hui then return _hui end
    local ok, r = pcall(function() return gethui and gethui() end)
    if ok and r then _hui = r end
    return _hui
end

------------------------------------------------------------
-- ScreenGui (single, random name, inside gethui)
------------------------------------------------------------
local _gui = nil
local function getGui()
    local hui = getHUI()
    if not hui then return nil end
    if _gui and _gui.Parent then return _gui end
    local g = Instance.new("ScreenGui")
    g.Name = rname()
    g.ResetOnSpawn = false
    g.IgnoreGuiInset = true
    g.Parent = hui
    _gui = g
    return g
end

------------------------------------------------------------
-- Drawing helpers (gethui Frame/TextLabel fallback)
------------------------------------------------------------
local function NewLine(thickness, color)
    local gui = getGui()
    if not gui then return nil end
    local f = Instance.new("Frame")
    f.Name = rname()
    f.BackgroundColor3 = color or Color3.fromRGB(255, 255, 255)
    f.BorderSizePixel = 0
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.ZIndex = 10
    f.Visible = false
    f.Parent = gui

    local line = {
        _frame = f,
        Visible = false,
        From = Vector2.new(0, 0),
        To = Vector2.new(0, 0),
        Color = color,
        Thickness = thickness or 1,
        Transparency = 1,
    }

    function line:Remove() pcall(function() self._frame:Destroy() end) end

    setmetatable(line, {
        __newindex = function(t, k, v)
            rawset(t, k, v)
            if k == "Visible" then
                t._frame.Visible = v
            elseif k == "Color" then
                t._frame.BackgroundColor3 = v
            elseif k == "Transparency" then
                t._frame.BackgroundTransparency = 1 - v
            elseif k == "From" or k == "To" then
                local from = t.From
                local to = t.To
                if from and to then
                    local delta = to - from
                    local len = delta.Magnitude
                    if len < 0.5 then t._frame.Visible = false return end
                    local angle = math.atan2(delta.Y, delta.X)
                    local mid = from + delta * 0.5
                    t._frame.Size = UDim2.fromOffset(math.ceil(len), t.Thickness or 1)
                    t._frame.Position = UDim2.fromOffset(mid.X, mid.Y)
                    t._frame.Rotation = math.deg(angle)
                end
            end
        end
    })

    return line
end

local function NewText(size, color)
    local gui = getGui()
    if not gui then return nil end
    local f = Instance.new("TextLabel")
    f.Name = rname()
    f.BackgroundTransparency = 1
    f.TextColor3 = color or Color3.fromRGB(255, 255, 255)
    f.TextStrokeTransparency = 0
    f.TextSize = size or 14
    f.Font = Enum.Font.Code
    f.Visible = false
    f.Size = UDim2.fromOffset(200, 30)
    f.TextXAlignment = Enum.TextXAlignment.Center
    f.TextYAlignment = Enum.TextYAlignment.Center
    f.ZIndex = 10
    f.Parent = gui

    local txt = {
        _label = f,
        Visible = false,
        Text = "",
        Position = Vector2.new(0, 0),
        Color = color,
        Size = size or 14,
        Center = true,
    }

    function txt:Remove() pcall(function() self._label:Destroy() end) end

    setmetatable(txt, {
        __newindex = function(t, k, v)
            rawset(t, k, v)
            if k == "Visible" then t._label.Visible = v
            elseif k == "Text" then t._label.Text = v
            elseif k == "Color" then t._label.TextColor3 = v
            elseif k == "Size" then t._label.TextSize = v
            elseif k == "Position" then
                t._label.Position = UDim2.fromOffset(v.X - 100, v.Y - 8)
            end
        end
    })

    return txt
end

------------------------------------------------------------
-- Module table
------------------------------------------------------------
local ESP = {}
local Config = {
    BoxEnabled       = false,
    NameEnabled      = false,
    HealthEnabled    = false,
    TracersEnabled   = false,
    SkeletonEnabled  = false,
    BoxColor         = Color3.fromRGB(255, 255, 255),
    TracerColor      = Color3.fromRGB(255, 255, 255),
    TracerOrigin     = "Bottom",   -- "Bottom" or "Middle"
    BoxThickness     = 1,
    TracerThickness  = 1,
    MaxDistance       = 500,
}

local tracked = {}  -- [player] = { box, tracer, name, health, skeleton }

------------------------------------------------------------
-- Helpers
------------------------------------------------------------
local function isAlive(p)
    if not p or not p.Character then return false end
    local h = p.Character:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0
end

------------------------------------------------------------
-- Per-player drawing objects
------------------------------------------------------------
local function createPlayerDrawings(plr)
    if plr == LocalPlayer then return end
    if tracked[plr] then return end

    tracked[plr] = {
        -- Box (4 lines: top, bottom, left, right)
        boxLines = {
            NewLine(Config.BoxThickness, Config.BoxColor),
            NewLine(Config.BoxThickness, Config.BoxColor),
            NewLine(Config.BoxThickness, Config.BoxColor),
            NewLine(Config.BoxThickness, Config.BoxColor),
        },
        -- Tracer
        tracer = NewLine(Config.TracerThickness, Config.TracerColor),
        -- Name
        nameText = NewText(14, Color3.fromRGB(255, 255, 255)),
        -- Health bar (background + fill)
        healthBg = NewLine(3, Color3.fromRGB(0, 0, 0)),
        healthFill = NewLine(2, Color3.fromRGB(0, 255, 0)),
        -- Skeleton lines
        skeletonLines = {},
        skeletonParts = {},
    }
end

local function destroyPlayerDrawings(plr)
    local d = tracked[plr]
    if not d then return end
    pcall(function()
        for _, ln in ipairs(d.boxLines or {}) do if ln then ln:Remove() end end
        if d.tracer then d.tracer:Remove() end
        if d.nameText then d.nameText:Remove() end
        if d.healthBg then d.healthBg:Remove() end
        if d.healthFill then d.healthFill:Remove() end
        for _, ln in ipairs(d.skeletonLines or {}) do if ln then ln:Remove() end end
    end)
    tracked[plr] = nil
end

------------------------------------------------------------
-- Build skeleton bone pairs for a character
------------------------------------------------------------
local function buildSkeleton(plr)
    local d = tracked[plr]
    if not d then return end
    -- Destroy old skeleton lines
    for _, ln in ipairs(d.skeletonLines or {}) do
        pcall(function() ln:Remove() end)
    end
    d.skeletonLines = {}
    d.skeletonParts = {}

    local char = plr.Character
    if not char then return end

    local head       = char:FindFirstChild("Head")
    local torso      = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
    local lowerTorso = char:FindFirstChild("LowerTorso")
    local leftArm    = char:FindFirstChild("LeftUpperArm") or char:FindFirstChild("Left Arm")
    local rightArm   = char:FindFirstChild("RightUpperArm") or char:FindFirstChild("Right Arm")
    local leftHand   = char:FindFirstChild("LeftHand") or char:FindFirstChild("LeftLowerArm")
    local rightHand  = char:FindFirstChild("RightHand") or char:FindFirstChild("RightLowerArm")
    local leftLeg    = char:FindFirstChild("LeftUpperLeg") or char:FindFirstChild("Left Leg")
    local rightLeg   = char:FindFirstChild("RightUpperLeg") or char:FindFirstChild("Right Leg")
    local leftFoot   = char:FindFirstChild("LeftFoot") or char:FindFirstChild("LeftLowerLeg")
    local rightFoot  = char:FindFirstChild("RightFoot") or char:FindFirstChild("RightLowerLeg")

    local pairs_ = {}
    if head and torso then table.insert(pairs_, {head, torso}) end
    if torso and lowerTorso then table.insert(pairs_, {torso, lowerTorso}) end
    if torso and leftArm then table.insert(pairs_, {torso, leftArm}) end
    if torso and rightArm then table.insert(pairs_, {torso, rightArm}) end
    if leftArm and leftHand then table.insert(pairs_, {leftArm, leftHand}) end
    if rightArm and rightHand then table.insert(pairs_, {rightArm, rightHand}) end
    if (lowerTorso or torso) and leftLeg then table.insert(pairs_, {lowerTorso or torso, leftLeg}) end
    if (lowerTorso or torso) and rightLeg then table.insert(pairs_, {lowerTorso or torso, rightLeg}) end
    if leftLeg and leftFoot then table.insert(pairs_, {leftLeg, leftFoot}) end
    if rightLeg and rightFoot then table.insert(pairs_, {rightLeg, rightFoot}) end

    for _, pair in ipairs(pairs_) do
        local ln = NewLine(2, Color3.fromRGB(255, 255, 255))
        if ln then
            table.insert(d.skeletonLines, ln)
            table.insert(d.skeletonParts, pair)
        end
    end
end

------------------------------------------------------------
-- Hide all drawings for a player
------------------------------------------------------------
local function hideAll(d)
    if not d then return end
    for _, ln in ipairs(d.boxLines or {}) do pcall(function() ln.Visible = false end) end
    pcall(function() d.tracer.Visible = false end)
    pcall(function() d.nameText.Visible = false end)
    pcall(function() d.healthBg.Visible = false end)
    pcall(function() d.healthFill.Visible = false end)
    for _, ln in ipairs(d.skeletonLines or {}) do pcall(function() ln.Visible = false end) end
end

------------------------------------------------------------
-- Master render loop (ONE Heartbeat connection for ALL)
------------------------------------------------------------
RunService.Heartbeat:Connect(function()
    for plr, d in pairs(tracked) do
        pcall(function()
            if not isAlive(plr) then
                hideAll(d)
                -- cleanup if player left
                if not Players:FindFirstChild(plr.Name) then
                    destroyPlayerDrawings(plr)
                end
                return
            end

            local char = plr.Character
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local head = char:FindFirstChild("Head")
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if not hrp or not head or not humanoid then hideAll(d) return end

            local hrpPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
            if not onScreen then hideAll(d) return end

            -- Distance
            local localChar = LocalPlayer.Character
            local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")
            if not localRoot then hideAll(d) return end
            local dist = (hrp.Position - localRoot.Position).Magnitude
            if dist > Config.MaxDistance then hideAll(d) return end

            -- Projections for box/name/health
            local topPos = Camera:WorldToViewportPoint(hrp.Position + Vector3.new(0, 3, 0))
            local botPos = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
            local height = math.abs(botPos.Y - topPos.Y)
            local width = height / 2
            local cx, cy = hrpPos.X, hrpPos.Y

            ---- BOX ESP ----
            if Config.BoxEnabled then
                local bl = d.boxLines
                -- top
                bl[1].From = Vector2.new(cx - width, cy - height/2)
                bl[1].To   = Vector2.new(cx + width, cy - height/2)
                bl[1].Color = Config.BoxColor
                bl[1].Visible = true
                -- bottom
                bl[2].From = Vector2.new(cx - width, cy + height/2)
                bl[2].To   = Vector2.new(cx + width, cy + height/2)
                bl[2].Color = Config.BoxColor
                bl[2].Visible = true
                -- left
                bl[3].From = Vector2.new(cx - width, cy - height/2)
                bl[3].To   = Vector2.new(cx - width, cy + height/2)
                bl[3].Color = Config.BoxColor
                bl[3].Visible = true
                -- right
                bl[4].From = Vector2.new(cx + width, cy - height/2)
                bl[4].To   = Vector2.new(cx + width, cy + height/2)
                bl[4].Color = Config.BoxColor
                bl[4].Visible = true
            else
                for _, ln in ipairs(d.boxLines) do ln.Visible = false end
            end

            ---- NAME ESP ----
            if Config.NameEnabled then
                d.nameText.Text = plr.DisplayName or plr.Name
                d.nameText.Position = Vector2.new(cx, cy - height/2 - 18)
                d.nameText.Visible = true
            else
                d.nameText.Visible = false
            end

            ---- HEALTH ESP ----
            if Config.HealthEnabled then
                local hp = humanoid.Health / humanoid.MaxHealth
                local barX = cx - width - 5
                local barTop = cy - height/2
                local barBot = cy + height/2
                local barH = barBot - barTop

                d.healthBg.From = Vector2.new(barX, barBot)
                d.healthBg.To   = Vector2.new(barX, barTop)
                d.healthBg.Visible = true

                d.healthFill.From = Vector2.new(barX, barBot)
                d.healthFill.To   = Vector2.new(barX, barBot - barH * hp)
                d.healthFill.Color = Color3.fromRGB(255, 0, 0):Lerp(Color3.fromRGB(0, 255, 0), hp)
                d.healthFill.Visible = true
            else
                d.healthBg.Visible = false
                d.healthFill.Visible = false
            end

            ---- TRACERS ----
            if Config.TracersEnabled then
                local origin
                if Config.TracerOrigin == "Middle" then
                    origin = Camera.ViewportSize * 0.5
                else
                    origin = Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y)
                end
                d.tracer.From = origin
                d.tracer.To   = Vector2.new(cx, cy + height/2)
                d.tracer.Color = Config.TracerColor
                d.tracer.Visible = true
            else
                d.tracer.Visible = false
            end

            ---- SKELETON ESP ----
            if Config.SkeletonEnabled then
                -- Rebuild if no parts yet
                if #d.skeletonParts == 0 then
                    buildSkeleton(plr)
                end
                for i, pair in ipairs(d.skeletonParts) do
                    local ln = d.skeletonLines[i]
                    pcall(function()
                        if pair[1] and pair[2] and pair[1].Parent and pair[2].Parent and ln then
                            local s1, on1 = Camera:WorldToViewportPoint(pair[1].Position)
                            local s2, on2 = Camera:WorldToViewportPoint(pair[2].Position)
                            if (on1 or on2) and s1.Z > 0 and s2.Z > 0 then
                                ln.From = Vector2.new(s1.X, s1.Y)
                                ln.To   = Vector2.new(s2.X, s2.Y)
                                ln.Visible = true
                            else
                                ln.Visible = false
                            end
                        else
                            if ln then ln.Visible = false end
                        end
                    end)
                end
            else
                for _, ln in ipairs(d.skeletonLines or {}) do
                    pcall(function() ln.Visible = false end)
                end
            end
        end)
    end
end)

------------------------------------------------------------
-- Player tracking
------------------------------------------------------------
local function setupPlayer(plr)
    if plr == LocalPlayer then return end
    pcall(function()
        createPlayerDrawings(plr)
        if plr.Character then
            buildSkeleton(plr)
        end
        plr.CharacterAdded:Connect(function()
            task.wait(0.5)
            pcall(buildSkeleton, plr)
        end)
    end)
end

for _, plr in ipairs(Players:GetPlayers()) do
    pcall(setupPlayer, plr)
end
Players.PlayerAdded:Connect(function(plr)
    pcall(setupPlayer, plr)
end)
Players.PlayerRemoving:Connect(function(plr)
    pcall(destroyPlayerDrawings, plr)
end)

------------------------------------------------------------
-- Public API
------------------------------------------------------------
function ESP:Init() end

function ESP:SetBoxEsp(state)
    Config.BoxEnabled = state
end
function ESP:SetNameEsp(state)
    Config.NameEnabled = state
end
function ESP:SetHealthEsp(state)
    Config.HealthEnabled = state
end
function ESP:SetTracers(state)
    Config.TracersEnabled = state
end
function ESP:SetSkeletonEsp(state)
    Config.SkeletonEnabled = state
    if state then
        for plr in pairs(tracked) do
            pcall(buildSkeleton, plr)
        end
    else
        for _, d in pairs(tracked) do
            for _, ln in ipairs(d.skeletonLines or {}) do
                pcall(function() ln.Visible = false end)
            end
        end
    end
end

return ESP
