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
M.VehTrunkEnabled = false
M.VehTrunkShowEmpty = false
M.VehTrunkUseRemote = true
M.VehTrunkScanInterval = 0.8
M.VehTrunkMaxItems = 4
M.VehTrunkRemoteDist = 250
M.VehMaxDist = 600

local tracked = {}
local vehTracked = {}
local trunkCache = {}

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
        for i = 1, 4 do
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
        d.trunkLabel = Drawing.new("Text")
        d.trunkLabel.Visible = false
        d.trunkLabel.Color = C3(255,170,60)
        d.trunkLabel.Size = 12
        d.trunkLabel.Center = true
        d.trunkLabel.Outline = true
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
        if d.trunkLabel then d.trunkLabel:Remove() end
    end)
    trunkCache[car] = nil
    vehTracked[car] = nil
end

local function hideVeh(d)
    pcall(function()
        for _, l in ipairs(d.box or {}) do l.Visible = false end
        if d.tracer then d.tracer.Visible = false end
        if d.name then d.name.Visible = false end
        if d.hpBg then d.hpBg.Visible = false end
        if d.hpFill then d.hpFill.Visible = false end
        if d.trunkLabel then d.trunkLabel.Visible = false end
    end)
end

local function getVehCenter(car)
    local pp = car.PrimaryPart
    if pp then return pp.Position end
    local bp = car:FindFirstChildWhichIsA("BasePart", true)
    return bp and bp.Position or nil
end

local trunkNameIgnore = {
    [""] = true,
    success = true, status = true, error = true, message = true, result = true,
    tools = true, items = true, inventory = true, contents = true,
    weight = true, itemweights = true, maxweight = true, currentweight = true,
    trunk = true, trunkpart = true, trunksystem = true, closetrunk = true,
    civtrunk = true, lawtrunk = true, securitytrunk = true,
    car = true, vehicle = true, body = true, owner = true, name = true, count = true,
    ["true"] = true, ["false"] = true,
}

local function trimStr(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function addTrunkItem(map, name, amount)
    if name == nil then return end
    local n = trimStr(tostring(name))
    if n == "" then return end
    if #n < 2 or #n > 60 then return end
    local l = string.lower(n)
    if trunkNameIgnore[l] then return end
    local c = tonumber(amount) or 1
    if c <= 0 then return end
    map[n] = (map[n] or 0) + c
end

local function countTrunkItems(map)
    local total = 0
    for _, c in pairs(map) do
        if type(c) == "number" and c > 0 then
            total = total + c
        end
    end
    return total
end

local function getTrunkRoots(car)
    local roots, seen = {}, {}
    local function push(root)
        if not root or seen[root] then return end
        if root:IsA("Folder") or root:IsA("Model") then
            seen[root] = true
            table.insert(roots, root)
        end
    end
    local function pushTrunkChildren(parent)
        if not parent then return end
        for _, child in ipairs(parent:GetChildren()) do
            if (child:IsA("Folder") or child:IsA("Model")) and string.find(string.lower(child.Name), "trunk", 1, true) then
                push(child)
            end
        end
    end

    local body = car and car:FindFirstChild("Body")
    if body then
        push(body:FindFirstChild("TrunkSystem"))
        push(body:FindFirstChild("Trunk"))
        pushTrunkChildren(body)
        local ts = body:FindFirstChild("TrunkSystem")
        pushTrunkChildren(ts)
    end
    push(car and car:FindFirstChild("TrunkSystem"))
    push(car and car:FindFirstChild("Trunk"))
    pushTrunkChildren(car)
    return roots
end

local function readTrunkOpen(car)
    local function readFrom(obj)
        if not obj then return nil end
        for _, key in ipairs({"TrunkOpen", "IsTrunkOpen"}) do
            local v = obj:FindFirstChild(key)
            if v and v:IsA("BoolValue") then
                return v.Value
            end
            local ok, attr = pcall(function() return obj:GetAttribute(key) end)
            if ok and type(attr) == "boolean" then
                return attr
            end
        end
        return nil
    end
    local body = car and car:FindFirstChild("Body")
    local b = readFrom(body)
    if b ~= nil then return b end
    return readFrom(car)
end

local function scanLocalTrunkItems(car)
    local map = {}
    for _, root in ipairs(getTrunkRoots(car)) do
        for _, inst in ipairs(root:GetDescendants()) do
            if inst:IsA("Tool") then
                addTrunkItem(map, inst.Name, 1)
            elseif inst:IsA("ObjectValue") then
                local v = inst.Value
                if v and v:IsA("Tool") then
                    addTrunkItem(map, v.Name, 1)
                elseif type(v) == "string" then
                    addTrunkItem(map, v, 1)
                end
            elseif inst:IsA("StringValue") then
                addTrunkItem(map, inst.Value, 1)
            elseif inst:IsA("IntValue") or inst:IsA("NumberValue") then
                if (tonumber(inst.Value) or 0) > 0 then
                    addTrunkItem(map, inst.Name, inst.Value)
                end
            end
        end
    end
    return map
end

local trunkRemoteFolder = nil
local trunkGetToolsRemote = nil
local trunkLeoSearchRemote = nil

local function getTrunkRemotes()
    if trunkRemoteFolder and trunkRemoteFolder.Parent then
        if trunkGetToolsRemote and trunkGetToolsRemote.Parent then
            return trunkGetToolsRemote, trunkLeoSearchRemote
        end
    end
    trunkRemoteFolder = game:GetService("ReplicatedStorage"):FindFirstChild("TrunkRemotes")
    trunkGetToolsRemote = trunkRemoteFolder and trunkRemoteFolder:FindFirstChild("GetTools") or nil
    trunkLeoSearchRemote = trunkRemoteFolder and trunkRemoteFolder:FindFirstChild("LEOSearch") or nil
    return trunkGetToolsRemote, trunkLeoSearchRemote
end

local function pushArgs(out, ...)
    local args, clean = { ... }, {}
    for i = 1, #args do
        if args[i] ~= nil then
            table.insert(clean, args[i])
        end
    end
    table.insert(out, clean)
end

local function parseRemoteItems(node, map, seen, depth)
    if node == nil or depth > 5 then return end
    local t = typeof(node)
    if t == "Instance" then
        if node:IsA("Tool") then
            addTrunkItem(map, node.Name, 1)
        elseif node:IsA("ObjectValue") and node.Value and node.Value:IsA("Tool") then
            addTrunkItem(map, node.Value.Name, 1)
        elseif node:IsA("StringValue") then
            addTrunkItem(map, node.Value, 1)
        end
        return
    end
    local lt = type(node)
    if lt == "string" then
        addTrunkItem(map, node, 1)
        return
    end
    if lt ~= "table" then return end
    if seen[node] then return end
    seen[node] = true

    for k, v in pairs(node) do
        local kt, vt = type(k), type(v)
        if kt == "string" then
            if vt == "number" and v > 0 then
                addTrunkItem(map, k, v)
            elseif vt == "boolean" and v then
                addTrunkItem(map, k, 1)
            end
        end
        if vt == "string" then
            addTrunkItem(map, v, 1)
        elseif vt == "table" or typeof(v) == "Instance" then
            parseRemoteItems(v, map, seen, depth + 1)
        end
    end
end

local function tryTrunkRemote(remote, argsList)
    local bestMap, bestCount = {}, 0
    if not (remote and remote:IsA("RemoteFunction")) then
        return bestMap, bestCount
    end
    for _, args in ipairs(argsList) do
        local ok, res = pcall(function()
            return remote:InvokeServer(unpack(args))
        end)
        if ok and res ~= nil then
            local m = {}
            parseRemoteItems(res, m, {}, 1)
            local c = countTrunkItems(m)
            if c > bestCount then
                bestMap, bestCount = m, c
            end
            if c > 0 then
                break
            end
        end
    end
    return bestMap, bestCount
end

local function fetchRemoteTrunkItems(car)
    local getTools, leoSearch = getTrunkRemotes()
    local body = car and car:FindFirstChild("Body")
    local roots = getTrunkRoots(car)
    local primaryRoot = roots[1]
    local argsList = {}
    pushArgs(argsList)
    pushArgs(argsList, car)
    pushArgs(argsList, body)
    pushArgs(argsList, primaryRoot)
    pushArgs(argsList, car, primaryRoot)
    pushArgs(argsList, primaryRoot, car)
    pushArgs(argsList, car, body)
    pushArgs(argsList, body, car)
    pushArgs(argsList, car and car.Name or nil)
    pushArgs(argsList, primaryRoot and primaryRoot.Name or nil)

    local m1, c1 = tryTrunkRemote(getTools, argsList)
    if c1 > 0 then
        return m1
    end
    local m2, c2 = tryTrunkRemote(leoSearch, argsList)
    if c2 > 0 then
        return m2
    end
    return {}
end

local function buildTrunkSummary(map)
    local total = countTrunkItems(map)
    if total <= 0 then
        return "", false
    end
    local entries = {}
    for name, count in pairs(map) do
        table.insert(entries, {name = name, count = count})
    end
    table.sort(entries, function(a, b)
        if a.count == b.count then
            return a.name < b.name
        end
        return a.count > b.count
    end)
    local shown = {}
    local cap = math.max(1, math.floor(tonumber(M.VehTrunkMaxItems) or 4))
    local lim = math.min(#entries, cap)
    for i = 1, lim do
        local e = entries[i]
        if e.count > 1 then
            table.insert(shown, e.name .. " x" .. tostring(e.count))
        else
            table.insert(shown, e.name)
        end
    end
    if #entries > lim then
        table.insert(shown, "+" .. tostring(#entries - lim) .. " more")
    end
    return "[" .. tostring(total) .. "] " .. table.concat(shown, ", "), true
end

local function getVehTrunkInfo(car, dist)
    local now = os.clock()
    local interval = math.max(0.2, tonumber(M.VehTrunkScanInterval) or 0.8)
    local cache = trunkCache[car]
    if cache and (now - cache.t) < interval then
        return cache.text, cache.hasItems
    end

    local itemMap = scanLocalTrunkItems(car)
    local localCount = countTrunkItems(itemMap)
    if localCount <= 0 and M.VehTrunkUseRemote and dist <= (tonumber(M.VehTrunkRemoteDist) or 250) then
        local remoteMap = fetchRemoteTrunkItems(car)
        local remoteCount = countTrunkItems(remoteMap)
        if remoteCount > 0 then
            itemMap = remoteMap
        end
    end

    local text, hasItems = buildTrunkSummary(itemMap)
    if not hasItems and M.VehTrunkShowEmpty then
        local openState = readTrunkOpen(car)
        if openState == false then
            text = "[closed]"
        else
            text = "[empty]"
        end
    end

    trunkCache[car] = {
        t = now,
        text = text,
        hasItems = hasItems,
    }
    return text, hasItems
end

RunService.Heartbeat:Connect(function()
    local anyVehOn = M.VehBoxEnabled or M.VehNameEnabled or M.VehTracersEnabled or M.VehHealthEnabled or M.VehTrunkEnabled
    if not anyVehOn then
        for car, d in pairs(vehTracked) do hideVeh(d) end
        return
    end
    local carsFolder = workspace:FindFirstChild("Cars")
    if not carsFolder then return end
    local me = LP.Character
    local myR = me and me:FindFirstChild("HumanoidRootPart")
    if not myR then return end
    -- Track new cars
    for _, car in ipairs(carsFolder:GetChildren()) do
        if car:IsA("Model") and not vehTracked[car] then
            makeVeh(car)
        end
    end
    -- Render
    for car, d in pairs(vehTracked) do
        pcall(function()
            if not car.Parent then nukeVeh(car) return end
            local pos = getVehCenter(car)
            if not pos then hideVeh(d) return end
            local dist = (pos - myR.Position).Magnitude
            if dist > M.VehMaxDist then hideVeh(d) return end
            local sv, onS = Camera:WorldToViewportPoint(pos)
            if not onS then hideVeh(d) return end
            local tP = Camera:WorldToViewportPoint(pos + Vector3.new(0,4,0))
            local bP = Camera:WorldToViewportPoint(pos - Vector3.new(0,2,0))
            local h = math.abs(bP.Y - tP.Y)
            local w = h * 1.2
            local cx, cy = sv.X, sv.Y
            if M.VehBoxEnabled then
                d.box[1].From = V2(cx-w, cy-h/2); d.box[1].To = V2(cx+w, cy-h/2); d.box[1].Visible = true
                d.box[2].From = V2(cx-w, cy+h/2); d.box[2].To = V2(cx+w, cy+h/2); d.box[2].Visible = true
                d.box[3].From = V2(cx-w, cy-h/2); d.box[3].To = V2(cx-w, cy+h/2); d.box[3].Visible = true
                d.box[4].From = V2(cx+w, cy-h/2); d.box[4].To = V2(cx+w, cy+h/2); d.box[4].Visible = true
            else
                for i=1,4 do d.box[i].Visible = false end
            end
            if M.VehNameEnabled then
                local rawName = car.Name
                local owner = rawName:match("(.+)Vehicle$") or rawName
                local vName = rawName:gsub("Vehicle$", ""):gsub("(%u)", " %1"):match("^%s*(.-)%s*$") or rawName
                d.name.Text = vName .. " [" .. owner .. "]"
                d.name.Position = V2(cx, cy - h/2 - 18)
                d.name.Visible = true
            else
                d.name.Visible = false
            end
            if M.VehTracersEnabled then
                local ox = Camera.ViewportSize.X / 2
                local oy = Camera.ViewportSize.Y
                d.tracer.From = V2(ox, oy)
                d.tracer.To = V2(cx, cy + h/2)
                d.tracer.Visible = true
            else
                d.tracer.Visible = false
            end
            if M.VehHealthEnabled then
                local hp = 1
                pcall(function()
                    local body = car:FindFirstChild("Body")
                    if body then
                        local hVal = body:FindFirstChild("Health") or car:FindFirstChild("Health")
                        if hVal and hVal:IsA("NumberValue") then
                            local maxH = body:FindFirstChild("MaxHealth") or car:FindFirstChild("MaxHealth")
                            local maxV = maxH and maxH.Value or 100
                            hp = math.clamp(hVal.Value / maxV, 0, 1)
                        end
                    end
                end)
                local bx = cx - w - 5
                local bt = cy - h/2
                local bb = cy + h/2
                d.hpBg.From = V2(bx, bb); d.hpBg.To = V2(bx, bt); d.hpBg.Visible = true
                d.hpFill.From = V2(bx, bb)
                d.hpFill.To = V2(bx, bb - (bb-bt)*hp)
                d.hpFill.Color = C3(255,0,0):Lerp(C3(0,255,0), hp)
                d.hpFill.Visible = true
            else
                d.hpBg.Visible = false
                d.hpFill.Visible = false
            end
            if M.VehTrunkEnabled then
                local summary, hasItems = getVehTrunkInfo(car, dist)
                if summary ~= "" then
                    d.trunkLabel.Text = summary
                    d.trunkLabel.Color = hasItems and C3(255,170,60) or C3(120,255,120)
                    d.trunkLabel.Position = V2(cx, cy + h/2 + 4)
                    d.trunkLabel.Visible = true
                else
                    d.trunkLabel.Visible = false
                end
            else
                d.trunkLabel.Visible = false
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
function API:SetVehHealthEsp(s) M.VehHealthEnabled = s end
function API:SetVehTrunkEsp(s) M.VehTrunkEnabled = s end
function API:SetVehTrunkShowEmpty(s)
    M.VehTrunkShowEmpty = s
    for car in pairs(trunkCache) do
        trunkCache[car] = nil
    end
end
function API:SetVehTrunkUseRemote(s)
    M.VehTrunkUseRemote = s
    for car in pairs(trunkCache) do
        trunkCache[car] = nil
    end
end
function API:SetVehTrunkScanInterval(v)
    M.VehTrunkScanInterval = math.max(0.2, tonumber(v) or M.VehTrunkScanInterval)
end
function API:SetVehTrunkMaxItems(v)
    M.VehTrunkMaxItems = math.max(1, math.floor(tonumber(v) or M.VehTrunkMaxItems))
    for car in pairs(trunkCache) do
        trunkCache[car] = nil
    end
end
function API:SetVehTrunkRemoteDist(v)
    M.VehTrunkRemoteDist = math.max(10, tonumber(v) or M.VehTrunkRemoteDist)
end
function API:SetHeldItemEsp(s) M.HeldItemEnabled = s end
function API:SetAdminHeldItem(s) M.AdminHeldItemEnabled = s end
return API
