local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LP = Players.LocalPlayer
local V2 = Vector2.new
local CF = CFrame.new
local C3 = Color3.fromRGB

local M = {}
M.BoxEnabled = false
M.NameEnabled = false
M.HealthEnabled = false
M.TracersEnabled = false
M.SkeletonEnabled = false
M.TeamEnabled = false
M.HeldItemEnabled = false
M.MaxDist = 500
M.AdminEnabled = false
M.AdminBoxEnabled = true
M.AdminNameEnabled = true
M.AdminTracersEnabled = true
M.AdminSkeletonEnabled = true
M.AdminTeamEnabled = true
M.AdminHeldItemEnabled = true
M.AdminListEnabled = false
M.AdminListOffset = Vector2.new(0,0)
local ADMIN_GROUP_ID = 17180419

-- Vehicle ESP settings
M.VehBoxEnabled = false
M.VehNameEnabled = false
M.VehTracersEnabled = false
M.VehHealthEnabled = false
M.VehMaxDist = 600

local tracked = {}
local vehTracked = {}
local vehHealthCache = {}
local vehBoxCache = {}

local function w2s(p)
    local v, on = Camera:WorldToViewportPoint(p)
    return V2(v.X, v.Y), on, v.Z
end

-- Admin check: anyone in the group with rank > 1 (not regular Member)
-- Member = rank 1, Moderator+ = rank > 1
local function checkAdmin(plr)
    local ok, result = pcall(function()
        if not plr:IsInGroup(ADMIN_GROUP_ID) then return false end
        local rank = plr:GetRankInGroup(ADMIN_GROUP_ID)
        if rank > 1 then return true end
        return false
    end)
    if ok then return result == true end
    -- Fallback: try role name check
    local ok2, role = pcall(function()
        return plr:GetRoleInGroup(ADMIN_GROUP_ID)
    end)
    if ok2 and role and role ~= "" and role ~= "Member" and role ~= "Guest" then
        return true
    end
    return false
end

-- Guarded version for ESP rendering (only highlights when Admin ESP toggle is on)
local function isAdmin(plr)
    if not M.AdminEnabled then return false end
    return checkAdmin(plr)
end

-- Admin list: scans ALL players, updated on join/leave
local cachedAdminCount = 0

local function refreshAdminList()
    local count = 0
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            pcall(function()
                if checkAdmin(plr) then
                    count = count + 1
                end
            end)
        end
    end
    cachedAdminCount = count
end

-- Scan immediately on load so count is ready
task.spawn(refreshAdminList)

local function alive(p)
    local c = p and p.Character
    if not c then return false end
    local h = c:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0
end

local function make(plr)
    if plr == LP or tracked[plr] then return end
    local d = {}
    pcall(function()
        d.box = {}
        for i = 1, 4 do
            local l = Drawing.new("Line")
            l.Visible = false
            l.Color = C3(255,255,255)
            l.Thickness = 1
            d.box[i] = l
        end

        d.tracer = Drawing.new("Line")
        d.tracer.Visible = false
        d.tracer.Color = C3(255,255,255)
        d.tracer.Thickness = 1

        d.name = Drawing.new("Text")
        d.name.Visible = false
        d.name.Color = C3(255,255,255)
        d.name.Size = 14
        d.name.Center = true
        d.name.Outline = true

        d.team = Drawing.new("Text")
        d.team.Visible = false
        d.team.Color = C3(255,255,255)
        d.team.Size = 13
        d.team.Center = false
        d.team.Outline = true

        d.hpBg = Drawing.new("Line")
        d.hpBg.Visible = false
        d.hpBg.Color = C3(0,0,0)
        d.hpBg.Thickness = 3

        d.hpFill = Drawing.new("Line")
        d.hpFill.Visible = false
        d.hpFill.Thickness = 2

        d.skel = {}
        d.skelBuilt = false

        d.heldItem = Drawing.new("Text")
        d.heldItem.Visible = false
        d.heldItem.Color = C3(255,200,0)
        d.heldItem.Size = 13
        d.heldItem.Center = true
        d.heldItem.Outline = true

        d.tag = nil -- reserved for future labels
    end)
    tracked[plr] = d
end

local function nuke(plr)
    local d = tracked[plr]
    if not d then return end
    pcall(function()
        for _, l in ipairs(d.box or {}) do l:Remove() end
        if d.tracer then d.tracer:Remove() end
        if d.name then d.name:Remove() end
        if d.team then d.team:Remove() end
        if d.hpBg then d.hpBg:Remove() end
        if d.hpFill then d.hpFill:Remove() end
        if d.heldItem then d.heldItem:Remove() end
        for _, l in ipairs(d.skel or {}) do l:Remove() end
    end)
    tracked[plr] = nil
end

local function buildSkel(plr)
    local d = tracked[plr]
    if not d then return end
    for _, l in ipairs(d.skel or {}) do
        pcall(function() l:Remove() end)
    end
    d.skel = {}
    d.skelBuilt = false

    local char = plr.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    local n = 8
    if hum.RigType == Enum.HumanoidRigType.R15 then n = 10 end

    for i = 1, n do
        local l = Drawing.new("Line")
        l.Color = C3(255,255,255)
        l.Thickness = 2
        l.Visible = false
        d.skel[i] = l
    end
    d.skelBuilt = true
end

local function hideD(d)
    pcall(function()
        for _, l in ipairs(d.box or {}) do l.Visible = false end
        if d.tracer then d.tracer.Visible = false end
        if d.name then d.name.Visible = false end
        if d.team then d.team.Visible = false end
        if d.hpBg then d.hpBg.Visible = false end
        if d.hpFill then d.hpFill.Visible = false end
        if d.heldItem then d.heldItem.Visible = false end
        for _, l in ipairs(d.skel or {}) do l.Visible = false end
    end)
end

local function drawSkelR6(d, char)
    local head = char:FindFirstChild("Head")
    local torso = char:FindFirstChild("Torso")
    if not head or not torso then
        for _, l in ipairs(d.skel) do l.Visible = false end
        return
    end
    local lA = char:FindFirstChild("Left Arm")
    local rA = char:FindFirstChild("Right Arm")
    local lL = char:FindFirstChild("Left Leg")
    local rL = char:FindFirstChild("Right Leg")

    local tc = torso.CFrame
    local neck = (tc * CF(0,1,0)).Position
    local pelvis = (tc * CF(0,-1,0)).Position
    local lS = (tc * CF(-1.5,1,0)).Position
    local rS = (tc * CF(1.5,1,0)).Position
    local lH = (tc * CF(-0.5,-1,0)).Position
    local rH = (tc * CF(0.5,-1,0)).Position
    local lHand = lA and (lA.CFrame * CF(0,-1,0)).Position or lS
    local rHand = rA and (rA.CFrame * CF(0,-1,0)).Position or rS
    local lFoot = lL and (lL.CFrame * CF(0,-1,0)).Position or lH
    local rFoot = rL and (rL.CFrame * CF(0,-1,0)).Position or rH

    local j = {
        {head.Position, neck},
        {lS, rS},
        {lS, lHand},
        {rS, rHand},
        {neck, pelvis},
        {lH, rH},
        {lH, lFoot},
        {rH, rFoot},
    }
    for i, p in ipairs(j) do
        local l = d.skel[i]
        if l then
            local a, oA, zA = w2s(p[1])
            local b, oB, zB = w2s(p[2])
            if (oA or oB) and zA > 0 and zB > 0 then
                l.From = a
                l.To = b
                l.Visible = true
            else
                l.Visible = false
            end
        end
    end
end

local function drawSkelR15(d, char)
    local head = char:FindFirstChild("Head")
    local uT = char:FindFirstChild("UpperTorso")
    local lT = char:FindFirstChild("LowerTorso")
    local lUA = char:FindFirstChild("LeftUpperArm")
    local lLA = char:FindFirstChild("LeftLowerArm")
    local rUA = char:FindFirstChild("RightUpperArm")
    local rLA = char:FindFirstChild("RightLowerArm")
    local lUL = char:FindFirstChild("LeftUpperLeg")
    local lLL = char:FindFirstChild("LeftLowerLeg")
    local rUL = char:FindFirstChild("RightUpperLeg")
    local rLL = char:FindFirstChild("RightLowerLeg")

    if not head or not uT then
        for _, l in ipairs(d.skel) do l.Visible = false end
        return
    end

    local parts = {
        {head, uT}, {uT, lT},
        {uT, lUA}, {lUA, lLA},
        {uT, rUA}, {rUA, rLA},
        {lT, lUL}, {lUL, lLL},
        {lT, rUL}, {rUL, rLL},
    }
    for i, p in ipairs(parts) do
        local l = d.skel[i]
        if l then
            if p[1] and p[2] and p[1].Parent and p[2].Parent then
                local a, oA, zA = w2s(p[1].Position)
                local b, oB, zB = w2s(p[2].Position)
                if (oA or oB) and zA > 0 and zB > 0 then
                    l.From = a
                    l.To = b
                    l.Visible = true
                else
                    l.Visible = false
                end
            else
                l.Visible = false
            end
        end
    end
end

RunService.Heartbeat:Connect(function()
    Camera = workspace.CurrentCamera
    for plr, d in pairs(tracked) do
        pcall(function()
            if not alive(plr) then
                hideD(d)
                if not Players:FindFirstChild(plr.Name) then nuke(plr) end
                return
            end

            local char = plr.Character
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hrp or not hum then hideD(d) return end

            local sv, onS = Camera:WorldToViewportPoint(hrp.Position)
            if not onS then hideD(d) return end

            local me = LP.Character
            local myR = me and me:FindFirstChild("HumanoidRootPart")
            if not myR then hideD(d) return end
            local dist = (hrp.Position - myR.Position).Magnitude
            if dist > M.MaxDist then hideD(d) return end

            local tP = Camera:WorldToViewportPoint(hrp.Position + Vector3.new(0,3,0))
            local bP = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0,3,0))
            local h = math.abs(bP.Y - tP.Y)
            local w = h / 2
            local cx, cy = sv.X, sv.Y
            local adm = isAdmin(plr)
            local baseColor = adm and C3(255,0,0) or C3(255,255,255)

            local boxOn   = adm and M.AdminBoxEnabled     or M.BoxEnabled
            local nameOn  = adm and M.AdminNameEnabled    or M.NameEnabled
            local teamOn  = adm and M.AdminTeamEnabled    or M.TeamEnabled
            local tracersOn = adm and M.AdminTracersEnabled or M.TracersEnabled
            local skelOn  = adm and M.AdminSkeletonEnabled or M.SkeletonEnabled
            local heldItemOn = adm and M.AdminHeldItemEnabled or M.HeldItemEnabled

            if boxOn then
                for i=1,4 do d.box[i].Color = baseColor end
                d.box[1].From = V2(cx-w, cy-h/2)
                d.box[1].To = V2(cx+w, cy-h/2)
                d.box[1].Visible = true
                d.box[2].From = V2(cx-w, cy+h/2)
                d.box[2].To = V2(cx+w, cy+h/2)
                d.box[2].Visible = true
                d.box[3].From = V2(cx-w, cy-h/2)
                d.box[3].To = V2(cx-w, cy+h/2)
                d.box[3].Visible = true
                d.box[4].From = V2(cx+w, cy-h/2)
                d.box[4].To = V2(cx+w, cy+h/2)
                d.box[4].Visible = true
            else
                for i=1,4 do d.box[i].Visible = false end
            end

            if nameOn then
                d.name.Color = baseColor
                d.name.Text = plr.DisplayName or plr.Name
                d.name.Position = V2(cx, cy - h/2 - 18)
                d.name.Visible = true
            else
                d.name.Visible = false
            end

            if teamOn then
                local teamName = "No Team"
                if plr.Team then
                    teamName = plr.Team.Name
                end
                d.team.Text = adm and ("[STAFF] "..teamName) or teamName
                d.team.Color = plr.TeamColor and plr.TeamColor.Color or baseColor

                if boxOn then
                    d.team.Position = V2(cx + w + 8, cy - h / 2)
                    d.team.Visible = true
                else
                    local head = char:FindFirstChild("Head") or hrp
                    local hv, hon, hz = w2s(head.Position + Vector3.new(0, 0.45, 0))
                    if hon and hz > 0 then
                        d.team.Position = V2(hv.X + 10, hv.Y - 8)
                        d.team.Visible = true
                    else
                        d.team.Visible = false
                    end
                end
            else
                d.team.Visible = false
            end

            if M.HealthEnabled then
                local hp = hum.Health / hum.MaxHealth
                local bx = cx - w - 5
                local bt = cy - h/2
                local bb = cy + h/2
                d.hpBg.From = V2(bx, bb)
                d.hpBg.To = V2(bx, bt)
                d.hpBg.Visible = true
                d.hpFill.From = V2(bx, bb)
                d.hpFill.To = V2(bx, bb - (bb-bt)*hp)
                d.hpFill.Color = C3(255,0,0):Lerp(C3(0,255,0), hp)
                d.hpFill.Visible = true
            else
                d.hpBg.Visible = false
                d.hpFill.Visible = false
            end

            if tracersOn then
                d.tracer.Color = baseColor
                local ox = Camera.ViewportSize.X / 2
                local oy = Camera.ViewportSize.Y
                d.tracer.From = V2(ox, oy)
                d.tracer.To = V2(cx, cy + h/2)
                d.tracer.Visible = true
            else
                d.tracer.Visible = false
            end

            if skelOn then
                for _, l in ipairs(d.skel or {}) do l.Color = baseColor end
                if not d.skelBuilt then buildSkel(plr) end
                if hum.RigType == Enum.HumanoidRigType.R15 then
                    drawSkelR15(d, char)
                else
                    drawSkelR6(d, char)
                end
            else
                for _, l in ipairs(d.skel or {}) do
                    pcall(function() l.Visible = false end)
                end
            end

            if heldItemOn then
                local tool = char:FindFirstChildWhichIsA("Tool")
                if tool then
                    d.heldItem.Text = tool.Name
                    d.heldItem.Position = V2(cx, cy + h/2 + 4)
                    d.heldItem.Visible = true
                else
                    d.heldItem.Visible = false
                end
            else
                d.heldItem.Visible = false
            end
        end)
    end
    if M.AdminListEnabled then
        if not adminLabel then
            adminLabel = Drawing.new("Text")
            adminLabel.Size = 16
            adminLabel.Center = false
            adminLabel.Outline = true
            adminLabel.Color = C3(255,0,0)
            refreshAdminList() -- scan immediately
        end
        local vp = Camera and Camera.ViewportSize or Vector2.new(1920,1080)
        adminLabel.Position = Vector2.new(vp.X - 160, 10) + M.AdminListOffset
        adminLabel.Text = "Admins: " .. cachedAdminCount
        adminLabel.Visible = true
    elseif adminLabel then
        adminLabel.Visible = false
    end
end)

-- ==================================================
-- VEHICLE ESP
-- ==================================================
local function makeVeh(car)
    if vehTracked[car] then return end
    local d = {}
    pcall(function()
        d.box = {}
        for i = 1, 12 do
            local l = Drawing.new("Line")
            l.Visible = false
            l.Color = C3(0,200,255)
            l.Thickness = 1
            d.box[i] = l
        end
        d.tracer = Drawing.new("Line")
        d.tracer.Visible = false
        d.tracer.Color = C3(0,200,255)
        d.tracer.Thickness = 1
        d.name = Drawing.new("Text")
        d.name.Visible = false
        d.name.Color = C3(0,200,255)
        d.name.Size = 14
        d.name.Center = true
        d.name.Outline = true
        d.hpBg = Drawing.new("Line")
        d.hpBg.Visible = false
        d.hpBg.Color = C3(0,0,0)
        d.hpBg.Thickness = 3
        d.hpFill = Drawing.new("Line")
        d.hpFill.Visible = false
        d.hpFill.Thickness = 2
    end)
    vehTracked[car] = d
end

local function nukeVeh(car)
    local d = vehTracked[car]
    if not d then return end
    pcall(function()
        for _, l in ipairs(d.box or {}) do l:Remove() end
        if d.tracer then d.tracer:Remove() end
        if d.name then d.name:Remove() end
        if d.hpBg then d.hpBg:Remove() end
        if d.hpFill then d.hpFill:Remove() end
    end)
    vehHealthCache[car] = nil
    vehBoxCache[car] = nil
    vehTracked[car] = nil
end

local function hideVeh(d)
    pcall(function()
        for _, l in ipairs(d.box or {}) do l.Visible = false end
        if d.tracer then d.tracer.Visible = false end
        if d.name then d.name.Visible = false end
        if d.hpBg then d.hpBg.Visible = false end
        if d.hpFill then d.hpFill.Visible = false end
    end)
end

local function getVehCenter(car)
    if not car then return nil end
    local body = car:FindFirstChild("Body")
    if body then
        if body:IsA("BasePart") then
            return body.Position
        end
        if body:IsA("Model") then
            if body.PrimaryPart then
                return body.PrimaryPart.Position
            end
            local driveSeat = body:FindFirstChild("DriveSeat", true)
            if driveSeat and driveSeat:IsA("BasePart") then
                return driveSeat.Position
            end
            local bodyPart = body:FindFirstChildWhichIsA("BasePart", true)
            if bodyPart then
                return bodyPart.Position
            end
        end
    end

    local seat = car:FindFirstChild("DriveSeat", true)
    if seat and seat:IsA("BasePart") then
        return seat.Position
    end

    local pp = car.PrimaryPart
    if pp then return pp.Position end
    local bp = car:FindFirstChildWhichIsA("BasePart", true)
    return bp and bp.Position or nil
end

local VEH_BOX_CORNER_SIGNS = {
    {-1,  1, -1},
    { 1,  1, -1},
    { 1,  1,  1},
    {-1,  1,  1},
    {-1, -1, -1},
    { 1, -1, -1},
    { 1, -1,  1},
    {-1, -1,  1},
}

local VEH_BOX_EDGES = {
    {1, 2}, {2, 3}, {3, 4}, {4, 1},
    {5, 6}, {6, 7}, {7, 8}, {8, 5},
    {1, 5}, {2, 6}, {3, 7}, {4, 8},
}

local function getVehBoundingBox(car)
    if not car then return nil, nil end
    local now = os.clock()
    local cached = vehBoxCache[car]
    if cached and (now - cached.t) < 0.08 then
        return cached.cf, cached.sz
    end

    local center = getVehCenter(car)
    if not center then return nil, nil end

    local refPart = car:FindFirstChild("DriveSeat", true)
    if not (refPart and refPart:IsA("BasePart")) then
        local body = car:FindFirstChild("Body")
        if body and body:IsA("Model") and body.PrimaryPart then
            refPart = body.PrimaryPart
        elseif car.PrimaryPart then
            refPart = car.PrimaryPart
        else
            refPart = car:FindFirstChildWhichIsA("BasePart", true)
        end
    end

    local orientCf
    if refPart and refPart:IsA("BasePart") then
        orientCf = CFrame.lookAt(center, center + refPart.CFrame.LookVector, refPart.CFrame.UpVector)
    else
        local okPivot, pivot = pcall(function()
            return car:GetPivot()
        end)
        if okPivot and pivot then
            orientCf = CFrame.lookAt(center, center + pivot.LookVector, pivot.UpVector)
        else
            orientCf = CFrame.new(center)
        end
    end

    local inv = orientCf:Inverse()
    local minX, minY, minZ = math.huge, math.huge, math.huge
    local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
    local seenPoint = false

    for _, inst in ipairs(car:GetDescendants()) do
        if inst:IsA("BasePart") then
            local h = inst.Size * 0.5
            local pcf = inst.CFrame
            for sx = -1, 1, 2 do
                for sy = -1, 1, 2 do
                    for sz = -1, 1, 2 do
                        local world = pcf * Vector3.new(h.X * sx, h.Y * sy, h.Z * sz)
                        local lp = inv:PointToObjectSpace(world)
                        if lp.X < minX then minX = lp.X end
                        if lp.Y < minY then minY = lp.Y end
                        if lp.Z < minZ then minZ = lp.Z end
                        if lp.X > maxX then maxX = lp.X end
                        if lp.Y > maxY then maxY = lp.Y end
                        if lp.Z > maxZ then maxZ = lp.Z end
                        seenPoint = true
                    end
                end
            end
        end
    end

    if not seenPoint then return nil, nil end

    local localCenter = Vector3.new(
        (minX + maxX) * 0.5,
        (minY + maxY) * 0.5,
        (minZ + maxZ) * 0.5
    )
    local size = Vector3.new(
        math.max(0.1, maxX - minX),
        math.max(0.1, maxY - minY),
        math.max(0.1, maxZ - minZ)
    )
    local boxCf = orientCf * CFrame.new(localCenter)

    vehBoxCache[car] = {
        t = now,
        cf = boxCf,
        sz = size,
    }
    return boxCf, size
end

local function projectVehBounds(boxCf, boxSize)
    if not boxCf or not boxSize then return nil, nil, false end

    local hx, hy, hz = boxSize.X * 0.5, boxSize.Y * 0.5, boxSize.Z * 0.5
    local projected = {}
    local minX, maxX, minY, maxY
    local anyOnScreen = false

    for i, s in ipairs(VEH_BOX_CORNER_SIGNS) do
        local world = boxCf * Vector3.new(s[1] * hx, s[2] * hy, s[3] * hz)
        local vp, on = Camera:WorldToViewportPoint(world)
        local entry = {
            p = V2(vp.X, vp.Y),
            z = vp.Z,
            on = on,
        }
        projected[i] = entry

        if entry.z > 0 then
            if entry.on then anyOnScreen = true end
            local x, y = entry.p.X, entry.p.Y
            if minX == nil then
                minX, maxX = x, x
                minY, maxY = y, y
            else
                if x < minX then minX = x end
                if x > maxX then maxX = x end
                if y < minY then minY = y end
                if y > maxY then maxY = y end
            end
        end
    end

    if minX == nil then
        return projected, nil, false
    end

    return projected, {
        minX = minX,
        maxX = maxX,
        minY = minY,
        maxY = maxY,
        cx = (minX + maxX) * 0.5,
        cy = (minY + maxY) * 0.5,
        w = maxX - minX,
        h = maxY - minY,
    }, anyOnScreen
end

local function drawVeh3DBox(d, projected)
    local any = false
    for i, edge in ipairs(VEH_BOX_EDGES) do
        local line = d.box[i]
        local a = projected[edge[1]]
        local b = projected[edge[2]]
        if line and a and b and a.z > 0 and b.z > 0 and (a.on or b.on) then
            line.From = a.p
            line.To = b.p
            line.Visible = true
            any = true
        elseif line then
            line.Visible = false
        end
    end
    return any
end

local function trimStr(s)
    return (tostring(s or "")):gsub("^%s+", ""):gsub("%s+$", "")
end

local function readVehInfoField(info, key)
    if not info then return nil end
    local node = info:FindFirstChild(key)
    if node then
        if node:IsA("StringValue") then
            local v = trimStr(node.Value)
            if v ~= "" then return v end
        elseif node:IsA("ObjectValue") then
            local obj = node.Value
            if obj then
                local v = trimStr(obj.Name)
                if v ~= "" then return v end
            end
        elseif node:IsA("IntValue") or node:IsA("NumberValue") then
            return tostring(node.Value)
        end
    end
    local ok, attr = pcall(function()
        return info:GetAttribute(key)
    end)
    if ok and attr ~= nil then
        local v = trimStr(attr)
        if v ~= "" then return v end
    end
    return nil
end

local function isVehicleModel(car)
    if not (car and car:IsA("Model")) then
        return false
    end
    local body = car:FindFirstChild("Body")
    if body then
        local info = body:FindFirstChild("Info")
        if info and (info:FindFirstChild("CarModel") or info:FindFirstChild("Owner")) then
            return true
        end
        if body:FindFirstChild("DriveSeat", true) then
            return true
        end
    end
    if car:FindFirstChild("DriveSeat", true) and car:FindFirstChild("A-Chassis_Tune", true) then
        return true
    end
    if car:FindFirstChild("Wheels", true) and car:FindFirstChild("A-Chassis_Tune", true) then
        return true
    end
    return false
end

local VEH_CONTAINER_NAMES = {
    "Cars",
    "InsertedCars",
    "Vehicles",
    "PlayerVehicles",
    "PlayerCars",
    "SpawnedVehicles",
    "SpawnedCars",
}

local function gatherVehicleModels()
    local list, seen = {}, {}
    local function push(car)
        if car and not seen[car] and isVehicleModel(car) then
            seen[car] = true
            table.insert(list, car)
        end
    end

    for _, name in ipairs(VEH_CONTAINER_NAMES) do
        local container = workspace:FindFirstChild(name)
        if container then
            for _, child in ipairs(container:GetChildren()) do
                push(child)
            end
        end
    end

    if #list == 0 then
        for _, child in ipairs(workspace:GetChildren()) do
            if child:IsA("Model") then
                push(child)
            elseif child:IsA("Folder") then
                local n = string.lower(child.Name)
                if n:find("car", 1, true) or n:find("vehicle", 1, true) then
                    for _, nested in ipairs(child:GetChildren()) do
                        push(nested)
                    end
                end
            end
        end
    end

    return list
end

local function getVehDisplayText(car)
    local body = car and car:FindFirstChild("Body")
    local info = body and body:FindFirstChild("Info")

    local modelName = readVehInfoField(info, "CarModel")
    local ownerName = readVehInfoField(info, "Owner")

    if not ownerName then
        ownerName = trimStr((car and car.Name or ""):match("(.+)Vehicle$"))
    end
    if not modelName or modelName == "" then
        local rawName = car and car.Name or "Vehicle"
        modelName = trimStr(rawName:gsub("Vehicle$", ""):gsub("(%u)", " %1"))
        if modelName == "" then
            modelName = rawName
        end
    end

    if ownerName and ownerName ~= "" then
        return modelName .. " [" .. ownerName .. "]"
    end
    return modelName
end

local function normalizeVehKey(name)
    return string.lower((tostring(name or "")):gsub("[^%w]", ""))
end

local VEH_HEALTH_KEYS = {
    health = true, vehiclehealth = true, carhealth = true, bodyhealth = true,
    hullhealth = true, hp = true, integrity = true, condition = true, durability = true,
}
local VEH_MAX_HEALTH_KEYS = {
    maxhealth = true, vehiclemaxhealth = true, maxvehiclehealth = true,
    carmaxhealth = true, maxcarhealth = true, bodymaxhealth = true,
    maxintegrity = true, maxcondition = true, maxdurability = true,
    starthealth = true, maxhp = true,
}
local VEH_HEALTH_PCT_KEYS = {
    healthpercent = true, vehiclehealthpercent = true, carhealthpercent = true,
    integritypercent = true, conditionpercent = true, durabilitypercent = true,
}
local VEH_DAMAGE_KEYS = {
    damage = true, vehicledamage = true, cardamage = true, bodydamage = true, hulldamage = true,
}
local VEH_MAX_DAMAGE_KEYS = {
    maxdamage = true, maxvehicledamage = true, maxcardamage = true, maxbodydamage = true, maxhulldamage = true,
}

local function vehSourceScore(inst, key)
    local score = 0
    local fullName = ""
    pcall(function() fullName = string.lower(inst:GetFullName()) end)
    if fullName:find("workspace.cars", 1, true) then score = score + 8 end
    if fullName:find(".body", 1, true) then score = score + 5 end
    if fullName:find("achassis", 1, true) then score = score + 2 end
    if fullName:find("wheel", 1, true) then score = score - 15 end
    if fullName:find("humanoid", 1, true) then score = score - 25 end

    if key:find("health", 1, true) then score = score + 5 end
    if key:find("vehicle", 1, true) or key:find("car", 1, true) then score = score + 3 end
    if key:find("damage", 1, true) then score = score + 2 end
    if key:find("max", 1, true) then score = score + 1 end
    return score
end

local function classifyVehKey(key)
    if key == "" then return nil end
    if VEH_HEALTH_PCT_KEYS[key] or ((key:find("percent", 1, true) or key:find("pct", 1, true)) and key:find("health", 1, true)) then
        return "percent"
    end
    if VEH_MAX_DAMAGE_KEYS[key] or (key:find("max", 1, true) and key:find("damage", 1, true)) then
        return "maxDamage"
    end
    if VEH_DAMAGE_KEYS[key] or key:find("damage", 1, true) then
        return "damage"
    end
    if VEH_MAX_HEALTH_KEYS[key] or (key:find("max", 1, true) and (key:find("health", 1, true) or key:find("integrity", 1, true) or key:find("condition", 1, true) or key:find("durability", 1, true))) then
        return "maxHealth"
    end
    if VEH_HEALTH_KEYS[key] or key:find("health", 1, true) or key:find("integrity", 1, true) or key:find("condition", 1, true) or key:find("durability", 1, true) then
        return "health"
    end
    return nil
end

local function addVehCandidate(bucket, inst, key, value)
    local n = tonumber(value)
    if not n or n ~= n or math.abs(n) > 1e8 then return end
    table.insert(bucket, {
        inst = inst,
        key = key,
        value = n,
        score = vehSourceScore(inst, key),
    })
end

local function collectVehHealthCandidates(car)
    local out = {
        health = {},
        maxHealth = {},
        percent = {},
        damage = {},
        maxDamage = {},
    }

    local function collectFrom(inst)
        if not inst then return end
        if inst:IsA("NumberValue") or inst:IsA("IntValue") then
            local key = normalizeVehKey(inst.Name)
            local bucket = classifyVehKey(key)
            if bucket then
                addVehCandidate(out[bucket], inst, key, inst.Value)
            end
        end
        local ok, attrs = pcall(function()
            return inst:GetAttributes()
        end)
        if ok and type(attrs) == "table" then
            for attrName, attrVal in pairs(attrs) do
                if type(attrVal) == "number" then
                    local key = normalizeVehKey(attrName)
                    local bucket = classifyVehKey(key)
                    if bucket then
                        addVehCandidate(out[bucket], inst, key, attrVal)
                    end
                end
            end
        end
    end

    local body = car and car:FindFirstChild("Body")
    collectFrom(car)
    collectFrom(body)
    if car then
        for _, inst in ipairs(car:GetDescendants()) do
            collectFrom(inst)
        end
    end
    return out
end

local function pickVehPair(currList, maxList, invert)
    local bestRatio, bestScore = nil, -math.huge
    for _, c in ipairs(currList) do
        for _, m in ipairs(maxList) do
            local maxVal = tonumber(m.value)
            if maxVal and maxVal > 0 then
                local ratio = c.value / maxVal
                if invert then
                    ratio = 1 - ratio
                end
                if ratio >= -0.2 and ratio <= 1.2 then
                    local score = c.score + m.score
                    if c.inst == m.inst or c.inst.Parent == m.inst.Parent then
                        score = score + 10
                    end
                    if maxVal >= c.value then
                        score = score + 3
                    else
                        score = score - 2
                    end
                    if score > bestScore then
                        bestScore = score
                        bestRatio = math.clamp(ratio, 0, 1)
                    end
                end
            end
        end
    end
    if bestRatio ~= nil then
        return bestRatio, true
    end
    return nil, false
end

local function pickBestVehPercent(percentList)
    local bestRatio, bestScore = nil, -math.huge
    for _, p in ipairs(percentList) do
        local ratio = tonumber(p.value)
        if ratio then
            if ratio > 1 then
                ratio = ratio / 100
            end
            if ratio >= 0 and ratio <= 1 then
                local score = p.score + 6
                if score > bestScore then
                    bestScore = score
                    bestRatio = ratio
                end
            end
        end
    end
    if bestRatio ~= nil then
        return math.clamp(bestRatio, 0, 1), true
    end
    return nil, false
end

local function pickBestVehSingle(list)
    local best, bestScore = nil, -math.huge
    for _, c in ipairs(list) do
        if c.score > bestScore then
            best = c
            bestScore = c.score
        end
    end
    return best
end

local function resolveVehHealthRatio(car, cache)
    local candidates = collectVehHealthCandidates(car)

    local ratio, ok = pickVehPair(candidates.health, candidates.maxHealth, false)
    if ok then return ratio, true end

    ratio, ok = pickVehPair(candidates.damage, candidates.maxDamage, true)
    if ok then return ratio, true end

    ratio, ok = pickVehPair(candidates.damage, candidates.maxHealth, true)
    if ok then return ratio, true end

    ratio, ok = pickBestVehPercent(candidates.percent)
    if ok then return ratio, true end

    local bestHealth = pickBestVehSingle(candidates.health)
    if bestHealth then
        local val = bestHealth.value
        if val >= 0 and val <= 1 then
            return math.clamp(val, 0, 1), true
        end
        if val > 1 and val <= 100 then
            return math.clamp(val / 100, 0, 1), true
        end
        if val > 0 then
            cache.maxObserved = math.max(cache.maxObserved or 0, val)
            if (cache.maxObserved or 0) > 0 then
                return math.clamp(val / cache.maxObserved, 0, 1), true
            end
        end
    end

    local bestDamage = pickBestVehSingle(candidates.damage)
    if bestDamage then
        local val = bestDamage.value
        if val >= 0 and val <= 1 then
            return math.clamp(1 - val, 0, 1), true
        end
        if val > 1 and val <= 100 then
            return math.clamp(1 - (val / 100), 0, 1), true
        end
    end

    return nil, false
end

local function getVehHealthRatio(car)
    local now = os.clock()
    local cache = vehHealthCache[car]
    if cache and (now - (cache.lastScan or 0)) < 0.5 then
        return cache.ratio, cache.valid
    end

    cache = cache or { maxObserved = 0 }
    local ratio, valid = resolveVehHealthRatio(car, cache)
    cache.lastScan = now
    cache.ratio = ratio
    cache.valid = valid
    vehHealthCache[car] = cache
    return ratio, valid
end

local _vehDbgLast = 0
RunService.Heartbeat:Connect(function()
    local anyVehOn = M.VehBoxEnabled or M.VehNameEnabled or M.VehTracersEnabled or M.VehHealthEnabled
    if not anyVehOn then
        for car, d in pairs(vehTracked) do hideVeh(d) end
        return
    end
    local now = os.clock()
    local dbg = (now - _vehDbgLast) > 5
    if dbg then _vehDbgLast = now end
    local vehicles = gatherVehicleModels()
    if dbg then warn("[VehESP] gatherVehicleModels found:", #vehicles) end
    if #vehicles == 0 then
        if dbg then
            local carsFolder = workspace:FindFirstChild("Cars")
            warn("[VehESP] Cars folder exists:", carsFolder ~= nil, "children:", carsFolder and #carsFolder:GetChildren() or 0)
            if carsFolder then
                for _, ch in ipairs(carsFolder:GetChildren()) do
                    local isM = ch:IsA("Model")
                    local body = ch:FindFirstChild("Body")
                    local info = body and body:FindFirstChild("Info")
                    local cm = info and info:FindFirstChild("CarModel")
                    warn("[VehESP]   child:", ch.Name, "isModel:", isM, "hasBody:", body ~= nil, "hasInfo:", info ~= nil, "hasCarModel:", cm ~= nil)
                end
            end
        end
        for car, d in pairs(vehTracked) do
            if not car.Parent then
                nukeVeh(car)
            else
                hideVeh(d)
            end
        end
        return
    end
    local me = LP.Character
    local myR = me and me:FindFirstChild("HumanoidRootPart")
    if not myR then
        if dbg then warn("[VehESP] No HRP") end
        return
    end
    -- Track new cars
    for _, car in ipairs(vehicles) do
        if not vehTracked[car] then
            makeVeh(car)
        end
    end
    -- Render
    for car, d in pairs(vehTracked) do
        pcall(function()
            if not car.Parent or not isVehicleModel(car) then nukeVeh(car) return end
            local boxCf, boxSize = getVehBoundingBox(car)
            if not boxCf or not boxSize then
                if dbg then warn("[VehESP] No bbox for:", car.Name) end
                hideVeh(d) return
            end
            local pos = boxCf.Position
            local dist = (pos - myR.Position).Magnitude
            if dist > M.VehMaxDist then hideVeh(d) return end
            local projected, screen, anyOnScreen = projectVehBounds(boxCf, boxSize)
            if not screen or not anyOnScreen then hideVeh(d) return end
            if dbg then warn("[VehESP] Rendering:", car.Name, "dist:", math.floor(dist)) end

            local cx, cy = screen.cx, screen.cy
            local h = math.max(screen.h, 10)
            local w = math.max(screen.w, 10)
            if M.VehBoxEnabled then
                drawVeh3DBox(d, projected)
            else
                for i = 1, #d.box do
                    d.box[i].Visible = false
                end
            end
            if M.VehNameEnabled then
                d.name.Text = getVehDisplayText(car)
                d.name.Position = V2(cx, screen.minY - 16)
                d.name.Visible = true
            else
                d.name.Visible = false
            end
            if M.VehTracersEnabled then
                local ox = Camera.ViewportSize.X / 2
                local oy = Camera.ViewportSize.Y
                d.tracer.From = V2(ox, oy)
                d.tracer.To = V2(cx, screen.maxY)
                d.tracer.Visible = true
            else
                d.tracer.Visible = false
            end
            if M.VehHealthEnabled then
                local hp, hpOk = getVehHealthRatio(car)
                if hpOk and hp ~= nil then
                    local bx = screen.minX - 5
                    local bt = screen.minY
                    local bb = screen.maxY
                    d.hpBg.From = V2(bx, bb)
                    d.hpBg.To = V2(bx, bt)
                    d.hpBg.Visible = true
                    d.hpFill.From = V2(bx, bb)
                    d.hpFill.To = V2(bx, bb - (bb-bt)*hp)
                    d.hpFill.Color = C3(255,0,0):Lerp(C3(0,255,0), hp)
                    d.hpFill.Visible = true
                else
                    d.hpBg.Visible = false
                    d.hpFill.Visible = false
                end
            else
                d.hpBg.Visible = false
                d.hpFill.Visible = false
            end
        end)
    end
end)

local function onPlr(plr)
    if plr == LP then return end
    pcall(function()
        make(plr)
        plr.CharacterAdded:Connect(function()
            task.wait(0.5)
            pcall(buildSkel, plr)
        end)
    end)
end

for _, p in ipairs(Players:GetPlayers()) do pcall(onPlr, p) end
Players.PlayerAdded:Connect(function(p)
    pcall(onPlr, p)
    task.delay(1, function() pcall(refreshAdminList) end)
end)
Players.PlayerRemoving:Connect(function(p)
    pcall(nuke, p)
    task.delay(0.5, function() pcall(refreshAdminList) end)
end)

local API = {}
function API:Init() end
function API:SetBoxEsp(s) M.BoxEnabled = s end
function API:SetNameEsp(s) M.NameEnabled = s end
function API:SetHealthEsp(s) M.HealthEnabled = s end
function API:SetTracers(s) M.TracersEnabled = s end
function API:SetTeamEsp(s) M.TeamEnabled = s end
function API:SetAdminEsp(s) M.AdminEnabled = s; if s then task.spawn(refreshAdminList) end end
function API:SetAdminBoxes(s) M.AdminBoxEnabled = s end
function API:SetAdminNames(s) M.AdminNameEnabled = s end
function API:SetAdminTracers(s) M.AdminTracersEnabled = s end
function API:SetAdminSkeleton(s) M.AdminSkeletonEnabled = s end
function API:SetAdminTeamEsp(s) M.AdminTeamEnabled = s end
function API:SetAdminList(s) M.AdminListEnabled = s; if s then task.spawn(refreshAdminList) end end
function API:SetSkeletonEsp(s)
    M.SkeletonEnabled = s
    if s then
        for p in pairs(tracked) do pcall(buildSkel, p) end
    end
end
function API:SetVehBoxEsp(s) M.VehBoxEnabled = s end
function API:SetVehNameEsp(s) M.VehNameEnabled = s end
function API:SetVehTracers(s) M.VehTracersEnabled = s end
function API:SetVehHealthEsp(s)
    M.VehHealthEnabled = s
    if not s then
        for car in pairs(vehHealthCache) do
            vehHealthCache[car] = nil
        end
    end
end
function API:SetHeldItemEsp(s) M.HeldItemEnabled = s end
function API:SetAdminHeldItem(s) M.AdminHeldItemEnabled = s end
return API
