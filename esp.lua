local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local ESP = {}
local Config = {
    BoxEnabled = false,
    NameEnabled = false,
    HealthEnabled = false,
    TracersEnabled = false,
    SkeletonEnabled = false,
    BoxColor = Color3.fromRGB(255, 255, 255),
    TracerColor = Color3.fromRGB(255, 255, 255),
    BoxThickness = 1,
    TracerThickness = 1,
    MaxDistance = 500,
}

local tracked = {}

local function isAlive(p)
    if not p or not p.Character then return false end
    local h = p.Character:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0
end

local function w2s(pos)
    local s, on = Camera:WorldToViewportPoint(pos)
    return Vector2.new(s.X, s.Y), on, s.Z
end

local function createPlayerDrawings(plr)
    if plr == LocalPlayer then return end
    if tracked[plr] then return end

    local d = {}
    pcall(function()
        d.boxTop = Drawing.new("Line")
        d.boxBot = Drawing.new("Line")
        d.boxLeft = Drawing.new("Line")
        d.boxRight = Drawing.new("Line")
        for _, k in ipairs({"boxTop","boxBot","boxLeft","boxRight"}) do
            d[k].Visible = false
            d[k].Color = Config.BoxColor
            d[k].Thickness = Config.BoxThickness
        end

        d.tracer = Drawing.new("Line")
        d.tracer.Visible = false
        d.tracer.Color = Config.TracerColor
        d.tracer.Thickness = Config.TracerThickness

        d.name = Drawing.new("Text")
        d.name.Visible = false
        d.name.Color = Color3.fromRGB(255, 255, 255)
        d.name.Size = 14
        d.name.Center = true
        d.name.Outline = true

        d.healthBg = Drawing.new("Line")
        d.healthBg.Visible = false
        d.healthBg.Color = Color3.fromRGB(0, 0, 0)
        d.healthBg.Thickness = 3

        d.healthFill = Drawing.new("Line")
        d.healthFill.Visible = false
        d.healthFill.Thickness = 2

        d.skeletonLines = {}
        d.skeletonMode = nil
    end)

    tracked[plr] = d
end

local function destroyPlayerDrawings(plr)
    local d = tracked[plr]
    if not d then return end
    pcall(function()
        for _, k in ipairs({"boxTop","boxBot","boxLeft","boxRight","tracer","name","healthBg","healthFill"}) do
            if d[k] then d[k]:Remove() end
        end
        for _, ln in ipairs(d.skeletonLines or {}) do
            pcall(function() ln:Remove() end)
        end
    end)
    tracked[plr] = nil
end

local function buildSkeleton(plr)
    local d = tracked[plr]
    if not d then return end
    for _, ln in ipairs(d.skeletonLines or {}) do
        pcall(function() ln:Remove() end)
    end
    d.skeletonLines = {}
    d.skeletonMode = nil

    local char = plr.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    local count = 8
    if humanoid.RigType == Enum.HumanoidRigType.R15 then
        count = 10
        d.skeletonMode = "R15"
    else
        d.skeletonMode = "R6"
    end

    for i = 1, count do
        local ln = Drawing.new("Line")
        ln.Color = Color3.fromRGB(255, 255, 255)
        ln.Thickness = 2
        ln.Visible = false
        d.skeletonLines[i] = ln
    end
end

local function hideAll(d)
    if not d then return end
    pcall(function()
        for _, k in ipairs({"boxTop","boxBot","boxLeft","boxRight","tracer","name","healthBg","healthFill"}) do
            if d[k] then d[k].Visible = false end
        end
        for _, ln in ipairs(d.skeletonLines or {}) do
            pcall(function() ln.Visible = false end)
        end
    end)
end

local function setLine(ln, from2d, to2d)
    if not ln then return end
    ln.From = from2d
    ln.To = to2d
    ln.Visible = true
end

local function renderR6Skeleton(d, char)
    local head = char:FindFirstChild("Head")
    local torso = char:FindFirstChild("Torso")
    local lArm = char:FindFirstChild("Left Arm")
    local rArm = char:FindFirstChild("Right Arm")
    local lLeg = char:FindFirstChild("Left Leg")
    local rLeg = char:FindFirstChild("Right Leg")
    if not head or not torso then
        for _, ln in ipairs(d.skeletonLines) do ln.Visible = false end
        return
    end

    local tc = torso.CFrame
    local neck = (tc * CFrame.new(0, 1, 0)).Position
    local pelvis = (tc * CFrame.new(0, -1, 0)).Position
    local lS = (tc * CFrame.new(-1.5, 1, 0)).Position
    local rS = (tc * CFrame.new(1.5, 1, 0)).Position
    local lH = (tc * CFrame.new(-0.5, -1, 0)).Position
    local rH = (tc * CFrame.new(0.5, -1, 0)).Position
    local lHand = lArm and (lArm.CFrame * CFrame.new(0, -1, 0)).Position or lS
    local rHand = rArm and (rArm.CFrame * CFrame.new(0, -1, 0)).Position or rS
    local lFoot = lLeg and (lLeg.CFrame * CFrame.new(0, -1, 0)).Position or lH
    local rFoot = rLeg and (rLeg.CFrame * CFrame.new(0, -1, 0)).Position or rH

    local joints = {
        {head.Position, neck},
        {lS, rS},
        {lS, lHand},
        {rS, rHand},
        {neck, pelvis},
        {lH, rH},
        {lH, lFoot},
        {rH, rFoot},
    }

    for i, pair in ipairs(joints) do
        local ln = d.skeletonLines[i]
        if ln then
            local a, onA, zA = w2s(pair[1])
            local b, onB, zB = w2s(pair[2])
            if (onA or onB) and zA > 0 and zB > 0 then
                setLine(ln, a, b)
            else
                ln.Visible = false
            end
        end
    end
end

local function renderR15Skeleton(d, char)
    local head = char:FindFirstChild("Head")
    local uTorso = char:FindFirstChild("UpperTorso")
    local lTorso = char:FindFirstChild("LowerTorso")
    local lUA = char:FindFirstChild("LeftUpperArm")
    local lLA = char:FindFirstChild("LeftLowerArm")
    local rUA = char:FindFirstChild("RightUpperArm")
    local rLA = char:FindFirstChild("RightLowerArm")
    local lUL = char:FindFirstChild("LeftUpperLeg")
    local lLL = char:FindFirstChild("LeftLowerLeg")
    local rUL = char:FindFirstChild("RightUpperLeg")
    local rLL = char:FindFirstChild("RightLowerLeg")

    if not head or not uTorso then
        for _, ln in ipairs(d.skeletonLines) do ln.Visible = false end
        return
    end

    local parts = {
        {head, uTorso},
        {uTorso, lTorso},
        {uTorso, lUA},
        {lUA, lLA},
        {uTorso, rUA},
        {rUA, rLA},
        {lTorso, lUL},
        {lUL, lLL},
        {lTorso, rUL},
        {rUL, rLL},
    }

    for i, pair in ipairs(parts) do
        local ln = d.skeletonLines[i]
        if ln then
            if pair[1] and pair[2] and pair[1].Parent and pair[2].Parent then
                local a, onA, zA = w2s(pair[1].Position)
                local b, onB, zB = w2s(pair[2].Position)
                if (onA or onB) and zA > 0 and zB > 0 then
                    setLine(ln, a, b)
                else
                    ln.Visible = false
                end
            else
                ln.Visible = false
            end
        end
    end
end

RunService.Heartbeat:Connect(function()
    for plr, d in pairs(tracked) do
        pcall(function()
            if not isAlive(plr) then
                hideAll(d)
                if not Players:FindFirstChild(plr.Name) then
                    destroyPlayerDrawings(plr)
                end
                return
            end

            local char = plr.Character
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if not hrp or not humanoid then hideAll(d) return end

            local hrpPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
            if not onScreen then hideAll(d) return end

            local localChar = LocalPlayer.Character
            local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")
            if not localRoot then hideAll(d) return end
            local dist = (hrp.Position - localRoot.Position).Magnitude
            if dist > Config.MaxDistance then hideAll(d) return end

            local topPos = Camera:WorldToViewportPoint(hrp.Position + Vector3.new(0, 3, 0))
            local botPos = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
            local height = math.abs(botPos.Y - topPos.Y)
            local width = height / 2
            local cx, cy = hrpPos.X, hrpPos.Y

            if Config.BoxEnabled then
                d.boxTop.From = Vector2.new(cx - width, cy - height/2)
                d.boxTop.To = Vector2.new(cx + width, cy - height/2)
                d.boxTop.Color = Config.BoxColor
                d.boxTop.Visible = true
                d.boxBot.From = Vector2.new(cx - width, cy + height/2)
                d.boxBot.To = Vector2.new(cx + width, cy + height/2)
                d.boxBot.Color = Config.BoxColor
                d.boxBot.Visible = true
                d.boxLeft.From = Vector2.new(cx - width, cy - height/2)
                d.boxLeft.To = Vector2.new(cx - width, cy + height/2)
                d.boxLeft.Color = Config.BoxColor
                d.boxLeft.Visible = true
                d.boxRight.From = Vector2.new(cx + width, cy - height/2)
                d.boxRight.To = Vector2.new(cx + width, cy + height/2)
                d.boxRight.Color = Config.BoxColor
                d.boxRight.Visible = true
            else
                d.boxTop.Visible = false
                d.boxBot.Visible = false
                d.boxLeft.Visible = false
                d.boxRight.Visible = false
            end

            if Config.NameEnabled then
                d.name.Text = plr.DisplayName or plr.Name
                d.name.Position = Vector2.new(cx, cy - height/2 - 18)
                d.name.Visible = true
            else
                d.name.Visible = false
            end

            if Config.HealthEnabled then
                local hp = humanoid.Health / humanoid.MaxHealth
                local barX = cx - width - 5
                local barTop = cy - height/2
                local barBot = cy + height/2
                d.healthBg.From = Vector2.new(barX, barBot)
                d.healthBg.To = Vector2.new(barX, barTop)
                d.healthBg.Visible = true
                d.healthFill.From = Vector2.new(barX, barBot)
                d.healthFill.To = Vector2.new(barX, barBot - (barBot - barTop) * hp)
                d.healthFill.Color = Color3.fromRGB(255, 0, 0):Lerp(Color3.fromRGB(0, 255, 0), hp)
                d.healthFill.Visible = true
            else
                d.healthBg.Visible = false
                d.healthFill.Visible = false
            end

            if Config.TracersEnabled then
                local origin = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                d.tracer.From = origin
                d.tracer.To = Vector2.new(cx, cy + height/2)
                d.tracer.Color = Config.TracerColor
                d.tracer.Visible = true
            else
                d.tracer.Visible = false
            end

            if Config.SkeletonEnabled then
                if #d.skeletonLines == 0 or not d.skeletonMode then
                    buildSkeleton(plr)
                end
                if d.skeletonMode == "R6" then
                    renderR6Skeleton(d, char)
                elseif d.skeletonMode == "R15" then
                    renderR15Skeleton(d, char)
                end
            else
                for _, ln in ipairs(d.skeletonLines or {}) do
                    pcall(function() ln.Visible = false end)
                end
            end
        end)
    end
end)

local function setupPlayer(plr)
    if plr == LocalPlayer then return end
    pcall(function()
        createPlayerDrawings(plr)
        plr.CharacterAdded:Connect(function()
            task.wait(0.5)
            pcall(buildSkeleton, plr)
        end)
    end)
end

for _, plr in ipairs(Players:GetPlayers()) do
    pcall(setupPlayer, plr)
end
Players.PlayerAdded:Connect(function(plr) pcall(setupPlayer, plr) end)
Players.PlayerRemoving:Connect(function(plr) pcall(destroyPlayerDrawings, plr) end)

function ESP:Init() end
function ESP:SetBoxEsp(state) Config.BoxEnabled = state end
function ESP:SetNameEsp(state) Config.NameEnabled = state end
function ESP:SetHealthEsp(state) Config.HealthEnabled = state end
function ESP:SetTracers(state) Config.TracersEnabled = state end
function ESP:SetSkeletonEsp(state)
    Config.SkeletonEnabled = state
    if state then
        for plr in pairs(tracked) do pcall(buildSkeleton, plr) end
    else
        for _, d in pairs(tracked) do
            for _, ln in ipairs(d.skeletonLines or {}) do
                pcall(function() ln.Visible = false end)
            end
        end
    end
end

return ESP
