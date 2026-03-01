local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer

if _G.__VENTURA_R6ESP and _G.__VENTURA_R6ESP.Stop then
    pcall(function()
        _G.__VENTURA_R6ESP:Stop()
    end)
end

local Settings = {
    Enabled = false,
    TeamCheck = false,
    MaxDistance = 1200,
    Thickness = 2,
    Color = Color3.fromRGB(255, 255, 255),
    GuiName = "Ventura_R6ESP_Local",
}

local R6ESP = {}
local tracked = {}
local renderConnection

local function getGuiParent()
    local parent
    pcall(function()
        if gethui then
            parent = gethui()
        end
    end)
    if not parent then
        parent = game:GetService("CoreGui")
    end
    return parent
end

local function getOrCreateGui()
    local parent = getGuiParent()
    local gui = parent:FindFirstChild(Settings.GuiName)
    if gui and gui:IsA("ScreenGui") then
        for _, child in ipairs(gui:GetChildren()) do
            if child:IsA("Frame") then
                pcall(function() child:Destroy() end)
            end
        end
        return gui
    end

    local created = Instance.new("ScreenGui")
    created.Name = Settings.GuiName
    created.ResetOnSpawn = false
    created.IgnoreGuiInset = true
    created.DisplayOrder = 999999
    created.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    created.Parent = parent
    return created
end

local function newLine(gui)
    local line = Instance.new("Frame")
    line.Name = "Bone"
    line.AnchorPoint = Vector2.new(0.5, 0.5)
    line.BorderSizePixel = 0
    line.BackgroundColor3 = Settings.Color
    line.ZIndex = 999999
    line.Visible = false
    line.Parent = gui
    return line
end

local function setLine(line, fromPos, toPos)
    local delta = toPos - fromPos
    local length = delta.Magnitude
    if length <= 0.5 then
        line.Visible = false
        return
    end

    local mid = fromPos + (delta * 0.5)
    line.Size = UDim2.fromOffset(math.floor(length + 0.5), Settings.Thickness)
    line.Position = UDim2.fromOffset(mid.X, mid.Y)
    line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
    line.BackgroundColor3 = Settings.Color
    line.Visible = true
end

local function hideLines(lines)
    for _, line in ipairs(lines) do
        line.Visible = false
    end
end

local function destroyLines(lines)
    for _, line in ipairs(lines) do
        pcall(function() line:Destroy() end)
    end
end

local function worldPoint(part, localOffset)
    return part.CFrame:PointToWorldSpace(localOffset)
end

local function getJointWorld(torso, jointName, fallbackLocalOffset)
    local joint = torso:FindFirstChild(jointName)
    if joint and joint:IsA("Motor6D") and joint.Part0 then
        return (joint.Part0.CFrame * joint.C0).Position
    end
    return worldPoint(torso, fallbackLocalOffset)
end

local function getR6Segments(char)
    local head = char:FindFirstChild("Head")
    local torso = char:FindFirstChild("Torso")
    local leftArm = char:FindFirstChild("Left Arm")
    local rightArm = char:FindFirstChild("Right Arm")
    local leftLeg = char:FindFirstChild("Left Leg")
    local rightLeg = char:FindFirstChild("Right Leg")

    if not (head and torso and leftArm and rightArm and leftLeg and rightLeg) then
        return nil
    end

    local shoulderCenter = getJointWorld(torso, "Neck", Vector3.new(0, torso.Size.Y * 0.5, 0))
    local leftHip = getJointWorld(torso, "Left Hip", Vector3.new(-torso.Size.X * 0.25, -torso.Size.Y * 0.5, 0))
    local rightHip = getJointWorld(torso, "Right Hip", Vector3.new(torso.Size.X * 0.25, -torso.Size.Y * 0.5, 0))

    local headTop = worldPoint(head, Vector3.new(0, head.Size.Y * 0.5, 0))
    local leftArmEnd = worldPoint(leftArm, Vector3.new(0, -leftArm.Size.Y * 0.5, 0))
    local rightArmEnd = worldPoint(rightArm, Vector3.new(0, -rightArm.Size.Y * 0.5, 0))
    local leftLegEnd = worldPoint(leftLeg, Vector3.new(0, -leftLeg.Size.Y * 0.5, 0))
    local rightLegEnd = worldPoint(rightLeg, Vector3.new(0, -rightLeg.Size.Y * 0.5, 0))

    local hipCenter = (leftHip + rightHip) * 0.5
    return {
        {leftHip, leftLegEnd},           -- left leg
        {rightHip, rightLegEnd},         -- right leg
        {leftHip, rightHip},             -- hip horizontal connector
        {hipCenter, shoulderCenter},     -- torso vertical
        {shoulderCenter, leftArmEnd},    -- left arm
        {shoulderCenter, rightArmEnd},   -- right arm
        {shoulderCenter, headTop},       -- head line
    }
end

local function getLocalRoot()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function shouldDrawPlayer(player, char, humanoid)
    if not Settings.Enabled then
        return false
    end
    if not humanoid or humanoid.Health <= 0 then
        return false
    end
    if humanoid.RigType ~= Enum.HumanoidRigType.R6 then
        return false
    end
    if Settings.TeamCheck and player.Team == LocalPlayer.Team then
        return false
    end

    local root = char:FindFirstChild("HumanoidRootPart")
    local localRoot = getLocalRoot()
    if not root or not localRoot then
        return false
    end

    return (root.Position - localRoot.Position).Magnitude <= Settings.MaxDistance
end

local function addPlayer(player)
    if player == LocalPlayer or tracked[player] then
        return
    end

    local gui = getOrCreateGui()
    tracked[player] = {
        lines = {
            newLine(gui),
            newLine(gui),
            newLine(gui),
            newLine(gui),
            newLine(gui),
            newLine(gui),
            newLine(gui),
        }
    }
end

local function removePlayer(player)
    local data = tracked[player]
    if not data then
        return
    end
    destroyLines(data.lines)
    tracked[player] = nil
end

local function renderStep()
    for player, data in pairs(tracked) do
        local char = player.Character
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")

        if not char or not shouldDrawPlayer(player, char, humanoid) then
            hideLines(data.lines)
        else
            local segments = getR6Segments(char)
            if not segments then
                hideLines(data.lines)
            else
                for i, line in ipairs(data.lines) do
                    local seg = segments[i]
                    local a = seg and seg[1]
                    local b = seg and seg[2]

                    if not a or not b then
                        line.Visible = false
                    else
                        local a2d, onA = Camera:WorldToViewportPoint(a)
                        local b2d, onB = Camera:WorldToViewportPoint(b)
                        if (onA or onB) and a2d.Z > 0 and b2d.Z > 0 then
                            setLine(line, Vector2.new(a2d.X, a2d.Y), Vector2.new(b2d.X, b2d.Y))
                        else
                            line.Visible = false
                        end
                    end
                end
            end
        end
    end
end

function R6ESP:Start()
    if renderConnection then
        return
    end

    for _, player in ipairs(Players:GetPlayers()) do
        addPlayer(player)
    end

    Players.PlayerAdded:Connect(addPlayer)
    Players.PlayerRemoving:Connect(removePlayer)
    renderConnection = RunService.RenderStepped:Connect(renderStep)
end

function R6ESP:Stop()
    if renderConnection then
        renderConnection:Disconnect()
        renderConnection = nil
    end
    for player in pairs(tracked) do
        removePlayer(player)
    end
end

function R6ESP:SetEnabled(state)
    Settings.Enabled = state
end

function R6ESP:GetSettings()
    return Settings
end

R6ESP:Start()
_G.__VENTURA_R6ESP = R6ESP
return R6ESP
