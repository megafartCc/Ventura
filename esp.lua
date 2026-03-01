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
local SkeletonGui

local function getSkeletonGui()
    if SkeletonGui and SkeletonGui.Parent then
        return SkeletonGui
    end

    local parent
    pcall(function()
        if gethui then
            parent = gethui()
        end
    end)
    if not parent then
        parent = game:GetService("CoreGui")
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "Ventura_SkeletonESP"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 1000
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = parent
    SkeletonGui = gui
    return gui
end

local function createSkeletonLine()
    local ln = Instance.new("Frame")
    ln.Name = "Bone"
    ln.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    ln.BorderSizePixel = 0
    ln.AnchorPoint = Vector2.new(0.5, 0.5)
    ln.ZIndex = 1000
    ln.Visible = false
    ln.Parent = getSkeletonGui()
    return ln
end

local function setSkeletonLine2D(ln, fromPos, toPos, thickness, color)
    if not ln then return end
    local delta = toPos - fromPos
    local length = delta.Magnitude
    if length < 0.5 then
        ln.Visible = false
        return
    end

    local mid = fromPos + (delta * 0.5)
    ln.Size = UDim2.fromOffset(math.floor(length + 0.5), thickness or 2)
    ln.Position = UDim2.fromOffset(mid.X, mid.Y)
    ln.Rotation = math.deg(math.atan2(delta.Y, delta.X))
    ln.BackgroundColor3 = color or Color3.fromRGB(255, 255, 255)
    ln.Visible = true
end

local function removeSkeletonLine(ln)
    if not ln then return end
    pcall(function()
        if typeof(ln) == "Instance" then
            ln:Destroy()
        else
            ln:Remove()
        end
    end)
end

local function isAlive(p)
    if not p or not p.Character then return false end
    local h = p.Character:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0
end

local function createPlayerDrawings(plr)
    if plr == LocalPlayer then return end
    if tracked[plr] then return end

    local d = {}

    pcall(function()
        -- Box (4 lines)
        d.boxTop = Drawing.new("Line")
        d.boxBot = Drawing.new("Line")
        d.boxLeft = Drawing.new("Line")
        d.boxRight = Drawing.new("Line")
        for _, k in ipairs({"boxTop","boxBot","boxLeft","boxRight"}) do
            d[k].Visible = false
            d[k].Color = Config.BoxColor
            d[k].Thickness = Config.BoxThickness
        end

        -- Tracer
        d.tracer = Drawing.new("Line")
        d.tracer.Visible = false
        d.tracer.Color = Config.TracerColor
        d.tracer.Thickness = Config.TracerThickness

        -- Name
        d.name = Drawing.new("Text")
        d.name.Visible = false
        d.name.Color = Color3.fromRGB(255, 255, 255)
        d.name.Size = 14
        d.name.Center = true
        d.name.Outline = true

        -- Health bg + fill
        d.healthBg = Drawing.new("Line")
        d.healthBg.Visible = false
        d.healthBg.Color = Color3.fromRGB(0, 0, 0)
        d.healthBg.Thickness = 3

        d.healthFill = Drawing.new("Line")
        d.healthFill.Visible = false
        d.healthFill.Thickness = 2

        -- Skeleton lines + segment refs
        d.skeletonLines = {}
        d.skeletonSegments = {}
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
            removeSkeletonLine(ln)
        end
    end)
    tracked[plr] = nil
end

local function addSkeletonSegment(d, partA, partB, offsetA, offsetB)
    if not d or not partA or not partB then return end

    local ln = createSkeletonLine()

    table.insert(d.skeletonLines, ln)
    table.insert(d.skeletonSegments, {
        a = partA,
        b = partB,
        aOffset = offsetA,
        bOffset = offsetB,
    })
end

local function segmentWorldPoint(part, offset)
    if not part or not part.Parent then return nil end
    if offset then
        return part.CFrame:PointToWorldSpace(offset)
    end
    return part.Position
end

local function buildSkeleton(plr)
    local d = tracked[plr]
    if not d then return end
    pcall(function()
        for _, ln in ipairs(d.skeletonLines or {}) do
            removeSkeletonLine(ln)
        end
    end)
    d.skeletonLines = {}
    d.skeletonSegments = {}
    d.skeletonMode = nil

    local char = plr.Character
    if not char then return end

    pcall(function()
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not humanoid then return end

        local head = char:FindFirstChild("Head")
        local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
        local lowerTorso = char:FindFirstChild("LowerTorso")
        local leftArm = char:FindFirstChild("LeftUpperArm") or char:FindFirstChild("Left Arm")
        local rightArm = char:FindFirstChild("RightUpperArm") or char:FindFirstChild("Right Arm")
        local leftHand = char:FindFirstChild("LeftHand") or char:FindFirstChild("LeftLowerArm")
        local rightHand = char:FindFirstChild("RightHand") or char:FindFirstChild("RightLowerArm")
        local leftLeg = char:FindFirstChild("LeftUpperLeg") or char:FindFirstChild("Left Leg")
        local rightLeg = char:FindFirstChild("RightUpperLeg") or char:FindFirstChild("Right Leg")
        local leftFoot = char:FindFirstChild("LeftFoot") or char:FindFirstChild("LeftLowerLeg")
        local rightFoot = char:FindFirstChild("RightFoot") or char:FindFirstChild("RightLowerLeg")

        if humanoid.RigType == Enum.HumanoidRigType.R6 then
            d.skeletonMode = "R6"
            for _ = 1, 8 do
                table.insert(d.skeletonLines, createSkeletonLine())
            end
            return
        end

        if lowerTorso then
            d.skeletonMode = "R15"
            -- R15
            if head and torso then addSkeletonSegment(d, head, torso) end
            if torso and lowerTorso then addSkeletonSegment(d, torso, lowerTorso) end
            if torso and leftArm then addSkeletonSegment(d, torso, leftArm) end
            if leftArm and leftHand then addSkeletonSegment(d, leftArm, leftHand) end
            if torso and rightArm then addSkeletonSegment(d, torso, rightArm) end
            if rightArm and rightHand then addSkeletonSegment(d, rightArm, rightHand) end
            if lowerTorso and leftLeg then addSkeletonSegment(d, lowerTorso, leftLeg) end
            if leftLeg and leftFoot then addSkeletonSegment(d, leftLeg, leftFoot) end
            if lowerTorso and rightLeg then addSkeletonSegment(d, lowerTorso, rightLeg) end
            if rightLeg and rightFoot then addSkeletonSegment(d, rightLeg, rightFoot) end
        end
    end)
end

local function updateR6Skeleton(d, char)
    local head = char:FindFirstChild("Head")
    local torso = char:FindFirstChild("Torso")
    local leftArm = char:FindFirstChild("Left Arm")
    local rightArm = char:FindFirstChild("Right Arm")
    local leftLeg = char:FindFirstChild("Left Leg")
    local rightLeg = char:FindFirstChild("Right Leg")

    if not (head and torso and leftArm and rightArm and leftLeg and rightLeg) then
        for _, ln in ipairs(d.skeletonLines or {}) do
            if ln then ln.Visible = false end
        end
        return
    end

    local function worldPoint(part, localOffset)
        return part.CFrame:PointToWorldSpace(localOffset)
    end

    local function jointWorldPos(part, jointName, fallbackOffset)
        local joint = part and part:FindFirstChild(jointName)
        if joint and joint:IsA("Motor6D") and joint.Part0 then
            return (joint.Part0.CFrame * joint.C0).Position
        end
        if part and fallbackOffset then
            return worldPoint(part, fallbackOffset)
        end
        return nil
    end

    local headTop = worldPoint(head, Vector3.new(0, head.Size.Y * 0.5, 0))
    local neckPos = jointWorldPos(torso, "Neck", Vector3.new(0, torso.Size.Y * 0.5, 0))
    local leftShoulderPos = jointWorldPos(torso, "Left Shoulder", Vector3.new(-torso.Size.X * 0.5, torso.Size.Y * 0.25, 0))
    local rightShoulderPos = jointWorldPos(torso, "Right Shoulder", Vector3.new(torso.Size.X * 0.5, torso.Size.Y * 0.25, 0))
    local leftHipPos = jointWorldPos(torso, "Left Hip", Vector3.new(-torso.Size.X * 0.25, -torso.Size.Y * 0.5, 0))
    local rightHipPos = jointWorldPos(torso, "Right Hip", Vector3.new(torso.Size.X * 0.25, -torso.Size.Y * 0.5, 0))

    local leftArmEnd = worldPoint(leftArm, Vector3.new(0, -leftArm.Size.Y * 0.5, 0))
    local rightArmEnd = worldPoint(rightArm, Vector3.new(0, -rightArm.Size.Y * 0.5, 0))
    local leftLegEnd = worldPoint(leftLeg, Vector3.new(0, -leftLeg.Size.Y * 0.5, 0))
    local rightLegEnd = worldPoint(rightLeg, Vector3.new(0, -rightLeg.Size.Y * 0.5, 0))

    if not (neckPos and leftShoulderPos and rightShoulderPos and leftHipPos and rightHipPos) then
        for _, ln in ipairs(d.skeletonLines or {}) do
            if ln then ln.Visible = false end
        end
        return
    end

    local shoulderCenter = (leftShoulderPos + rightShoulderPos) * 0.5
    local hipCenter = (leftHipPos + rightHipPos) * 0.5
    local r6Segments = {
        {headTop, neckPos},
        {neckPos, shoulderCenter},
        {shoulderCenter, hipCenter},
        {leftShoulderPos, rightShoulderPos},
        {leftShoulderPos, leftArmEnd},
        {rightShoulderPos, rightArmEnd},
        {leftHipPos, leftLegEnd},
        {rightHipPos, rightLegEnd},
    }

    local lines = d.skeletonLines
    local color = Color3.fromRGB(255, 255, 255)
    for i, ln in ipairs(lines) do
        local seg = r6Segments[i]
        if not ln or not seg or not seg[1] or not seg[2] then
            if ln then ln.Visible = false end
        else
            local s1, on1 = Camera:WorldToViewportPoint(seg[1])
            local s2, on2 = Camera:WorldToViewportPoint(seg[2])
            if (on1 or on2) and s1.Z > 0 and s2.Z > 0 then
                setSkeletonLine2D(ln, Vector2.new(s1.X, s1.Y), Vector2.new(s2.X, s2.Y), 2, color)
            else
                ln.Visible = false
            end
        end
    end
end

local function hideAll(d)
    if not d then return end
    pcall(function()
        for _, k in ipairs({"boxTop","boxBot","boxLeft","boxRight","tracer","name","healthBg","healthFill"}) do
            if d[k] then d[k].Visible = false end
        end
        for _, ln in ipairs(d.skeletonLines or {}) do
            if ln then ln.Visible = false end
        end
    end)
end

-- Master render loop
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

            -- Projections
            local topPos = Camera:WorldToViewportPoint(hrp.Position + Vector3.new(0, 3, 0))
            local botPos = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
            local height = math.abs(botPos.Y - topPos.Y)
            local width = height / 2
            local cx, cy = hrpPos.X, hrpPos.Y

            -- BOX
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

            -- NAME
            if Config.NameEnabled then
                d.name.Text = plr.DisplayName or plr.Name
                d.name.Position = Vector2.new(cx, cy - height/2 - 18)
                d.name.Visible = true
            else
                d.name.Visible = false
            end

            -- HEALTH
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

            -- TRACERS
            if Config.TracersEnabled then
                local origin = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                d.tracer.From = origin
                d.tracer.To = Vector2.new(cx, cy + height/2)
                d.tracer.Color = Config.TracerColor
                d.tracer.Visible = true
            else
                d.tracer.Visible = false
            end

            -- SKELETON
            if Config.SkeletonEnabled then
                local wantedMode = humanoid.RigType == Enum.HumanoidRigType.R6 and "R6" or "R15"
                if #d.skeletonLines == 0 or d.skeletonMode ~= wantedMode then
                    buildSkeleton(plr)
                end

                if d.skeletonMode == "R6" then
                    pcall(function()
                        updateR6Skeleton(d, char)
                    end)
                else
                    for i, seg in ipairs(d.skeletonSegments) do
                        local ln = d.skeletonLines[i]
                        pcall(function()
                            if ln and seg and seg.a and seg.b and seg.a.Parent and seg.b.Parent then
                                local p1 = segmentWorldPoint(seg.a, seg.aOffset)
                                local p2 = segmentWorldPoint(seg.b, seg.bOffset)
                                if not p1 or not p2 then
                                    ln.Visible = false
                                    return
                                end

                                local s1, on1 = Camera:WorldToViewportPoint(p1)
                                local s2, on2 = Camera:WorldToViewportPoint(p2)
                                if (on1 or on2) and s1.Z > 0 and s2.Z > 0 then
                                    setSkeletonLine2D(
                                        ln,
                                        Vector2.new(s1.X, s1.Y),
                                        Vector2.new(s2.X, s2.Y),
                                        2,
                                        Color3.fromRGB(255, 255, 255)
                                    )
                                else
                                    ln.Visible = false
                                end
                            else
                                if ln then ln.Visible = false end
                            end
                        end)
                    end
                end
            else
                for _, ln in ipairs(d.skeletonLines or {}) do
                    pcall(function() ln.Visible = false end)
                end
            end
        end)
    end
end)

-- Player tracking
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
Players.PlayerAdded:Connect(function(plr) pcall(setupPlayer, plr) end)
Players.PlayerRemoving:Connect(function(plr) pcall(destroyPlayerDrawings, plr) end)

-- API
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
