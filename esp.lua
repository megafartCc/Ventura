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

        -- Skeleton lines + part refs
        d.skeletonLines = {}
        d.skeletonParts = {}
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
            if ln then ln:Remove() end
        end
    end)
    tracked[plr] = nil
end

local function buildSkeleton(plr)
    local d = tracked[plr]
    if not d then return end
    pcall(function()
        for _, ln in ipairs(d.skeletonLines or {}) do
            if ln then ln:Remove() end
        end
    end)
    d.skeletonLines = {}
    d.skeletonParts = {}

    local char = plr.Character
    if not char then return end

    pcall(function()
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
            local ln = Drawing.new("Line")
            ln.Visible = false
            ln.Color = Color3.fromRGB(255, 255, 255)
            ln.Thickness = 2
            table.insert(d.skeletonLines, ln)
            table.insert(d.skeletonParts, pair)
        end
    end)
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
                                ln.To = Vector2.new(s2.X, s2.Y)
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
