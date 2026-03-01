local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local camera = game:GetService("Workspace").CurrentCamera
local player = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local THEME = {
    panel = Color3.fromRGB(16, 18, 24),
    panel2 = Color3.fromRGB(22, 24, 30),
    text = Color3.fromRGB(230, 235, 240),
    textDim = Color3.fromRGB(170, 176, 186),
    accentA = Color3.fromRGB(64, 156, 255),
    accentB = Color3.fromRGB(0, 204, 204),
    gold = Color3.fromRGB(255, 215, 0),
}

local BlissfulSettings = {
    Box_Color = Color3.fromRGB(255, 255, 255),
    Tracer_Color = Color3.fromRGB(255, 255, 255),
    Tracer_Thickness = 1,
    Box_Thickness = 1,
    Tracer_Origin = "Bottom",
    Tracer_FollowMouse = false,
}
local hotbarDisplaySet = {}

local boxEspEnabled = false
local healthEspEnabled = false
local tracersEnabled = false
local teamCheckEnabled = false
local teamColorEnabled = true
local nameEspEnabled = false
local hotbarEspEnabled = false
local skeletonEspEnabled = false

local trackedPlayers = {}
local black = Color3.fromRGB(0, 0, 0)
local mouse = player:GetMouse()

local hasDrawing = (typeof(Drawing) == "table" or typeof(Drawing) == "userdata")
    and typeof(Drawing.new) == "function"
if hasDrawing then
    local success, obj = pcall(function() return Drawing.new("Line") end)
    if not success or not obj then
        hasDrawing = false
    else
        pcall(function() obj:Remove() end)
    end
end
local hasTaskCancel = (type(task) == "table" or type(task) == "userdata")
    and type(task.cancel) == "function"

local autoDigEnabled = false
local autoDigThread = nil
local autoDigManualEnabled = false
local autoSprinklerEnabled = false
local autoBuffItemsState = { false }
local autoBuffItemsThread = { nil }


local function safeFire(event, ...)
    if not event then return end
    local args = { ... }
    pcall(function()
        if #args == 0 then
            event:FireServer()
        else
            event:FireServer(table.unpack(args))
        end
    end)
end
local function getPlayerActivesCommand()
    local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
    or ReplicatedStorage:WaitForChild("Events", 1)
    return eventsFolder and eventsFolder:FindFirstChild("PlayerActivesCommand")
end
local function firePlayerActives(name)
    local ev = getPlayerActivesCommand()
    if not ev then return end
    safeFire(ev, { Name = tostring(name) })
end
local function startAutoLoop(stateRef, threadRef, interval, callback)
    if threadRef[1] then return end
    stateRef[1] = true
    threadRef[1] = task.spawn(function()
        while stateRef[1] do
            callback()
            task.wait(interval)
        end
        threadRef[1] = nil
    end)
end
local function stopAutoLoop(stateRef, threadRef)
    stateRef[1] = false
    if threadRef[1] then
        if hasTaskCancel then
            pcall(function()
                task.cancel(threadRef[1])
            end)
        end
        threadRef[1] = nil
    end
end
local function startAutoDig()
    if autoDigThread then
        return
    end
    autoDigEnabled = true
    autoDigThread = task.spawn(function()
        local args = {}
        while autoDigEnabled do
            local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
            or ReplicatedStorage:WaitForChild("Events", 1)
            local toolCollectRemote = eventsFolder and eventsFolder:FindFirstChild("ToolCollect")
            if toolCollectRemote then
                pcall(function()
                    toolCollectRemote:FireServer(table.unpack(args))
                end)
            end
            task.wait(0.1)
        end
        autoDigThread = nil
    end)
end
local function stopAutoDig()
    autoDigEnabled = false
    if autoDigThread then
        if hasTaskCancel then
            pcall(function()
                task.cancel(autoDigThread)
            end)
        end
        autoDigThread = nil
    end
end
local function refreshAutoDig(isAutoFarmEnabled)
    local shouldRun = isAutoFarmEnabled or autoDigManualEnabled
    if shouldRun and not autoDigEnabled then
        startAutoDig()
    elseif not shouldRun and autoDigEnabled then
        stopAutoDig()
    end
end
local function releaseBuffs()
    local buffs = {
        "Blue Extract",
        "Red Extract",
        "Oil",
        "Enzymes",
        "Glue",
        "Glitter",
        "Tropical Drink",
    }
    for _, name in ipairs(buffs) do
        firePlayerActives(name)
        task.wait(0.1)
    end
end

local function getHudRoot()
    local ok, ui = pcall(function()
        return gethui and gethui()
    end)
    if ok and ui then
        return ui
    end
    return (gethui and gethui() or game:GetService("CoreGui"))
end

local function safeDisconnectConn(conn)
    if conn and typeof(conn) == "RBXScriptConnection" then
        pcall(function()
            conn:Disconnect()
        end)
    end
end

local function getFallbackGui()
    local core = gethui and gethui() or game:GetService("CoreGui")
    local gui = core:FindFirstChild("ESPFallbackGui")
    if not gui then
        gui = Instance.new("ScreenGui")
        gui.Name = "ESPFallbackGui"
        gui.ResetOnSpawn = false
        gui.Parent = core
    end
    return gui
end

local function NewQuad(thickness, color)
    if hasDrawing then
        local success, quad = pcall(function() return Drawing.new("Quad") end)
        if success and quad then
            quad.Visible = false
            quad.PointA = Vector2.new(0, 0)
            quad.PointB = Vector2.new(0, 0)
            quad.PointC = Vector2.new(0, 0)
            quad.PointD = Vector2.new(0, 0)
            quad.Color = color
            quad.Filled = false
            quad.Thickness = thickness
            quad.Transparency = 1
            return quad
        end
    end
    -- Fallback for Box ESP (4 lines instead of 1 quad, or 1 Frame)
    local f = Instance.new("Frame")
    f.BackgroundTransparency = 1
    f.BorderSizePixel = thickness
    f.BorderColor3 = color
    f.Visible = false
    f.Parent = getFallbackGui()
    
    local quad = {
        Visible = false,
        PointA = Vector2.new(0, 0),
        PointB = Vector2.new(0, 0),
        PointC = Vector2.new(0, 0),
        PointD = Vector2.new(0, 0),
        Color = color,
        Filled = false,
        Thickness = thickness,
        Transparency = 1,
        _frame = f
    }
    
    -- The quad needs a metatable to update the Frame when properties change
    setmetatable(quad, {
        __newindex = function(t, k, v)
            rawset(t, k, v)
            if k == "Visible" then t._frame.Visible = v
            elseif k == "Color" then t._frame.BorderColor3 = v
            elseif k == "PointA" or k == "PointD" then
                if t.PointA and t.PointD then
                    local minX = math.min(t.PointA.X, t.PointD.X)
                    local minY = math.min(t.PointA.Y, t.PointD.Y)
                    local maxX = math.max(t.PointA.X, t.PointD.X)
                    local maxY = math.max(t.PointA.Y, t.PointD.Y)
                    t._frame.Position = UDim2.fromOffset(minX, minY)
                    t._frame.Size = UDim2.fromOffset(maxX - minX, maxY - minY)
                end
            end
        end
    })
    
    function quad:Remove() self._frame:Destroy() end
    return quad
end

local function NewLine(thickness, color)
    if hasDrawing then
        local success, line = pcall(function() return Drawing.new("Line") end)
        if success and line then
            line.Visible = false
            line.From = Vector2.new(0, 0)
            line.To = Vector2.new(0, 0)
            line.Color = color
            line.Thickness = thickness
            line.Transparency = 1
            return line
        end
    end

    local f = Instance.new("Frame")
    f.BorderSizePixel = 0
    f.BackgroundColor3 = color
    f.Visible = false
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.Parent = getFallbackGui()

    local line = {
        Visible = false,
        From = Vector2.new(0, 0),
        To = Vector2.new(0, 0),
        Color = color,
        Thickness = thickness,
        Transparency = 1,
        _frame = f
    }
    
    setmetatable(line, {
        __newindex = function(t, k, v)
            rawset(t, k, v)
            if k == "Visible" then t._frame.Visible = v
            elseif k == "Color" then t._frame.BackgroundColor3 = v
            elseif k == "From" or k == "To" then
                if t.From and t.To then
                    local dist = (t.To - t.From).Magnitude
                    local center = (t.From + t.To) / 2
                    local angle = math.atan2(t.To.Y - t.From.Y, t.To.X - t.From.X)
                    t._frame.Position = UDim2.fromOffset(center.X, center.Y)
                    t._frame.Size = UDim2.fromOffset(dist, t.Thickness)
                    t._frame.Rotation = math.deg(angle)
                end
            end
        end
    })
    
    function line:Remove() self._frame:Destroy() end
    return line
end

local function NewText(size, color)
    if hasDrawing then
        local success, txt = pcall(function() return Drawing.new("Text") end)
        if success and txt then
            txt.Visible = false
            txt.Center = true
            txt.Outline = true
            txt.Size = size
            txt.Color = color
            return txt
        end
    end

    local f = Instance.new("TextLabel")
    f.BackgroundTransparency = 1
    f.TextColor3 = color
    f.TextStrokeTransparency = 0
    f.TextSize = size
    f.Font = Enum.Font.Code
    f.Visible = false
    f.Parent = getFallbackGui()

    local txt = {
        Visible = false,
        Center = true,
        Outline = true,
        Size = size,
        Color = color,
        Text = "",
        Position = Vector2.new(0, 0),
        _label = f
    }
    
    setmetatable(txt, {
        __newindex = function(t, k, v)
            rawset(t, k, v)
            if k == "Visible" then t._label.Visible = v
            elseif k == "Color" then t._label.TextColor3 = v
            elseif k == "Text" then t._label.Text = v
            elseif k == "Size" then t._label.TextSize = v
            elseif k == "Position" then
                if t.Position then
                    t._label.Position = UDim2.fromOffset(t.Position.X, t.Position.Y)
                end
            elseif k == "Center" then
                if v then
                    t._label.AnchorPoint = Vector2.new(0.5, 0.5)
                else
                    t._label.AnchorPoint = Vector2.new(0, 0)
                end
            end
        end
    })
    
    function txt:Remove() self._label:Destroy() end
    return txt
end

local function ESP(plr)
    local library = {
        blacktracer = NewLine(BlissfulSettings.Tracer_Thickness * 2, black),
        tracer = NewLine(BlissfulSettings.Tracer_Thickness, BlissfulSettings.Tracer_Color),
        black = NewQuad(BlissfulSettings.Box_Thickness * 2, black),
        box = NewQuad(BlissfulSettings.Box_Thickness, BlissfulSettings.Box_Color),
        healthbar = NewLine(5, black),
        greenhealth = NewLine(3, black),
        nametext = nil,
        hotbartext = nil,
        teamtext = nil,
    }

    local hotbarGui = nil
    local hotbarFrame = nil
    local hotbarViewport = nil
    local hotbarCam = nil
    local lastToolName = nil

    local function ensureHotbarGui(anchorPart)
        if hotbarGui and hotbarGui.Parent == nil then
            hotbarGui = nil
        end
        if hotbarGui then
            return
        end
        local BillboardGui = (gethui and gethui() or game:GetService("CoreGui")):FindFirstChild("Eps_HotbarBillboard_" .. plr.Name)
        if BillboardGui then
            hotbarGui = BillboardGui
        else
            hotbarGui = Instance.new("BillboardGui")
            hotbarGui.Name = "HotbarBillboard_" .. plr.Name
            hotbarGui.AlwaysOnTop = true
            hotbarGui.Size = UDim2.fromOffset(64, 64)
            hotbarGui.StudsOffset = Vector3.new(0, -3.8, 0)
            hotbarGui.MaxDistance = 500
            hotbarGui.Adornee = anchorPart
            hotbarGui.Parent = getHudRoot()
        end

        hotbarFrame = hotbarGui:FindFirstChild("HotbarFrame")
        if not hotbarFrame then
            hotbarFrame = Instance.new("Frame")
            hotbarFrame.Name = "HotbarFrame"
            hotbarFrame.Size = UDim2.fromScale(1, 1)
            hotbarFrame.BackgroundColor3 = THEME.panel
            hotbarFrame.BackgroundTransparency = 0.35
            hotbarFrame.BorderSizePixel = 0
            hotbarFrame.Parent = hotbarGui
            local corner = Instance.new("UICorner", hotbarFrame)
            corner.CornerRadius = UDim.new(0, 10)
        end
        hotbarViewport = hotbarFrame:FindFirstChild("HotbarViewport")
        if not hotbarViewport then
            hotbarViewport = Instance.new("ViewportFrame")
            hotbarViewport.Name = "HotbarViewport"
            hotbarViewport.AnchorPoint = Vector2.new(0.5, 0.5)
            hotbarViewport.Position = UDim2.fromScale(0.5, 0.5)
            hotbarViewport.Size = UDim2.fromScale(0.9, 0.9)
            hotbarViewport.BackgroundTransparency = 1
            hotbarViewport.Ambient = Color3.fromRGB(200, 200, 200)
            hotbarViewport.LightColor = Color3.fromRGB(255, 255, 255)
            hotbarViewport.LightDirection = Vector3.new(0, -1, -1)
            hotbarViewport.Parent = hotbarFrame
            local cam = Instance.new("Camera")
            cam.Name = "HotbarCam"
            cam.FieldOfView = 40
            cam.Parent = hotbarViewport
            hotbarCam = cam
            hotbarViewport.CurrentCamera = hotbarCam
        else
            hotbarCam = hotbarViewport:FindFirstChild("HotbarCam")
            if not hotbarCam then
                local cam = Instance.new("Camera")
                cam.Name = "HotbarCam"
                cam.FieldOfView = 40
                cam.Parent = hotbarViewport
                hotbarCam = cam
                hotbarViewport.CurrentCamera = hotbarCam
            end
        end
    end
    
    local function clearViewport()
        if hotbarViewport then
            for _, ch in ipairs(hotbarViewport:GetChildren()) do
                if ch:IsA("Model") or ch:IsA("BasePart") or ch:IsA("Camera") then
                    if ch.Name ~= "HotbarCam" then
                        ch:Destroy()
                    end
                end
            end
        end
    end
    
    local function setViewportToTool(tool)
        if not tool then
            return
        end
        clearViewport()
        local model = Instance.new("Model")
        model.Name = "ToolPreview"
        model.Parent = hotbarViewport
        
        local function cloneParts(instance)
            for _, d in ipairs(instance:GetDescendants()) do
                if d:IsA("BasePart") then
                    local cp = d:Clone()
                    cp.Anchored = true
                    cp.CanCollide = false
                    cp.Parent = model
                end
            end
        end
        
        pcall(cloneParts, tool)
        local handle = tool:FindFirstChild("Handle")
        if handle and #model:GetChildren() == 0 then
            local h = handle:Clone()
            h.Anchored = true
            h.CanCollide = false
            h.Parent = model
        end
        
        local cf, size = model:GetBoundingBox()
        local center = cf.Position
        local maxDim = math.max(size.X, size.Y, size.Z)
        local distance = (maxDim == 0 and 2) or (maxDim * 2.2)
        local viewPos = (cf * CFrame.new(0, 0, distance)).Position
        if hotbarCam then
            hotbarCam.CFrame = CFrame.new(viewPos, center)
        end
    end
    
    local function destroyHotbarGui()
        if hotbarGui then
            pcall(function()
                hotbarGui:Destroy()
            end)
        end
        hotbarGui, hotbarFrame, hotbarViewport, hotbarCam = nil, nil, nil, nil
        lastToolName = nil
    end

    local function Updater()
        local connection
        connection = RunService.RenderStepped
            :Connect(function()
                if
                    plr.Character ~= nil
                    and plr.Character:FindFirstChild("Humanoid") ~= nil
                    and plr.Character:FindFirstChild("HumanoidRootPart") ~= nil
                    and plr.Character.Humanoid.Health > 0
                    and plr.Character:FindFirstChild("Head") ~= nil
                then
                    local humanoid = plr.Character.Humanoid
                    local hrp = plr.Character.HumanoidRootPart
                    local shakeOffset = humanoid.CameraOffset
                    local stable_hrp_pos_3d = hrp.Position - shakeOffset
                    local HumPos, OnScreen =
                        camera:WorldToViewportPoint(stable_hrp_pos_3d)
                    if OnScreen then
                        local box_top_3d = stable_hrp_pos_3d + Vector3.new(0, 3, 0)
                        local box_bottom_3d = stable_hrp_pos_3d + Vector3.new(0, -3, 0)
                        local box_top_2d = camera:WorldToViewportPoint(box_top_3d)
                        local box_bottom_2d = camera:WorldToViewportPoint(box_bottom_3d)
                        
                        local proj_height = box_bottom_2d.Y - box_top_2d.Y
                        local half_height = proj_height / 2
                        local half_width = half_height / 2
                        half_height = math.clamp(half_height, 2, math.huge)
                        half_width = math.clamp(half_width, 1, math.huge)
                        
                        local center_x = HumPos.X
                        local center_y = HumPos.Y
                        local yTop = center_y - half_height
                        local scale = math.clamp(half_height, 8, 220)
                        local nameSize = math.floor(math.clamp(scale * 0.30, 10, 18))
                        local hotbarSize = math.floor(math.clamp(scale * 0.28, 9, 16))
                        local teamSize = math.floor(math.clamp(scale * 0.22, 8, 13))
                        local margin = math.floor(math.clamp(scale * 0.10, 5, 12))

                        if nameEspEnabled then
                            if not library.nametext then
                                local t = NewText(nameSize, Color3.fromRGB(255, 255, 255))
                                library.nametext = t
                            end
                            if library.nametext then
                                local t = library.nametext
                                t.Size = nameSize
                                t.Text = plr.DisplayName or plr.Name
                                t.Position = Vector2.new(
                                    center_x,
                                    yTop - (margin + math.floor(nameSize * 0.60))
                                )
                                t.Color = Color3.fromRGB(255, 255, 255)
                                t.Visible = true
                            end
                        elseif library.nametext then
                            library.nametext.Visible = false
                        end

                        if boxEspEnabled then
                            local function Size(item)
                                item.PointA = Vector2.new(center_x + half_width, center_y - half_height)
                                item.PointB = Vector2.new(center_x - half_width, center_y - half_height)
                                item.PointC = Vector2.new(center_x - half_width, center_y + half_height)
                                item.PointD = Vector2.new(center_x + half_width, center_y + half_height)
                            end
                            Size(library.box)
                            Size(library.black)
                            library.box.Color = BlissfulSettings.Box_Color
                            library.box.Visible = true
                            library.black.Visible = true
                        else
                            library.box.Visible = false
                            library.black.Visible = false
                        end

                        if tracersEnabled then
                            if BlissfulSettings.Tracer_Origin == "Middle" then
                                library.tracer.From = camera.ViewportSize * 0.5
                                library.blacktracer.From = camera.ViewportSize * 0.5
                            elseif BlissfulSettings.Tracer_Origin == "Bottom" then
                                library.tracer.From = Vector2.new(camera.ViewportSize.X * 0.5, camera.ViewportSize.Y)
                                library.blacktracer.From = Vector2.new(camera.ViewportSize.X * 0.5, camera.ViewportSize.Y)
                            end
                            if BlissfulSettings.Tracer_FollowMouse then
                                library.tracer.From = Vector2.new(mouse.X, mouse.Y + 36)
                                library.blacktracer.From = Vector2.new(mouse.X, mouse.Y + 36)
                            end
                            library.tracer.To = Vector2.new(center_x, center_y + half_height)
                            library.blacktracer.To = Vector2.new(center_x, center_y + half_height)
                            library.tracer.Color = BlissfulSettings.Tracer_Color
                            library.tracer.Visible = true
                            library.blacktracer.Visible = true
                        else
                            library.tracer.Visible = false
                            library.blacktracer.Visible = false
                        end

                        if healthEspEnabled then
                            local d = 2 * half_height
                            local healthoffset = plr.Character.Humanoid.Health / plr.Character.Humanoid.MaxHealth * d
                            local healthbar_x = center_x - half_width - 4
                            local healthbar_top_y = center_y - half_height
                            local healthbar_bottom_y = center_y + half_height
                            
                            library.greenhealth.From = Vector2.new(healthbar_x, healthbar_bottom_y)
                            library.greenhealth.To = Vector2.new(healthbar_x, healthbar_bottom_y - healthoffset)
                            library.healthbar.From = Vector2.new(healthbar_x, healthbar_bottom_y)
                            library.healthbar.To = Vector2.new(healthbar_x, healthbar_top_y)
                            
                            local green = Color3.fromRGB(0, 255, 0)
                            local red = Color3.fromRGB(255, 0, 0)
                            library.greenhealth.Color = red:lerp(green, plr.Character.Humanoid.Health / plr.Character.Humanoid.MaxHealth)
                            library.healthbar.Visible = true
                            library.greenhealth.Visible = true
                        else
                            library.healthbar.Visible = false
                            library.greenhealth.Visible = false
                        end

                        local tool = nil
                        pcall(function()
                            tool = plr.Character:FindFirstChildOfClass("Tool")
                        end)
                        
                        if hotbarEspEnabled and hotbarDisplaySet.Text then
                            if not library.hotbartext then
                                local ht = NewText(hotbarSize, Color3.fromRGB(200, 200, 200))
                                library.hotbartext = ht
                            end
                            if library.hotbartext then
                                local ht = library.hotbartext
                                ht.Size = hotbarSize
                                local label = (tool and tool.Name) or ""
                                ht.Text = label
                                local yBottom = center_y + half_height
                                local y = yBottom + math.max(1, margin - math.floor(hotbarSize * 0.35))
                                ht.Position = Vector2.new(center_x, y)
                                ht.Visible = (label ~= "")
                            end
                        elseif library.hotbartext then
                            library.hotbartext.Visible = false
                        end
                        
                        if hotbarEspEnabled and hotbarDisplaySet.Image and tool then
                            ensureHotbarGui(plr.Character.HumanoidRootPart)
                            if hotbarGui then
                                local px = math.floor(math.clamp(half_width * 1.2, 26, 84))
                                hotbarGui.Size = UDim2.fromOffset(px, px)
                                local currName = tool.Name
                                if currName ~= lastToolName then
                                    lastToolName = currName
                                    setViewportToTool(tool)
                                end
                            end
                        else
                            destroyHotbarGui()
                        end

                        local teamLabel = nil
                        local teamObj = plr.Team
                        if teamCheckEnabled and teamObj and teamObj.Name and teamObj.Name ~= "" then
                            teamLabel = teamObj.Name
                        elseif teamCheckEnabled and plr.TeamColor then
                            teamLabel = tostring(plr.TeamColor)
                        end
                        
                        if teamLabel and teamCheckEnabled then
                            if not library.teamtext then
                                local tt = NewText(teamSize, (teamColorEnabled and teamObj and teamObj.TeamColor.Color) or Color3.fromRGB(255, 255, 255))
                                tt.Center = false
                                library.teamtext = tt
                            end
                            if library.teamtext then
                                local tt = library.teamtext
                                tt.Size = teamSize
                                tt.Text = teamLabel
                                tt.Position = Vector2.new(
                                    center_x + half_width + 4,
                                    yTop + math.max(2, math.floor(teamSize * 0.3))
                                )
                                tt.Color = (teamColorEnabled and teamObj and teamObj.TeamColor.Color) or Color3.fromRGB(255, 255, 255)
                                tt.Visible = true
                            end
                        elseif library.teamtext then
                            library.teamtext.Visible = false
                        end

                    else
                        for _, drawing in pairs(library) do
                            if drawing and drawing.Visible then
                                drawing.Visible = false
                            end
                        end
                        destroyHotbarGui()
                    end
                else
                    for _, drawing in pairs(library) do
                        if drawing and drawing.Visible then
                            drawing.Visible = false
                        end
                    end
                    destroyHotbarGui()
                    if Players:FindFirstChild(plr.Name) == nil then
                        connection:Disconnect()
                        for _, drawing in pairs(library) do
                            pcall(function()
                                if drawing and drawing.Remove then
                                    drawing:Remove()
                                end
                            end)
                        end
                        library = nil
                        if trackedPlayers[plr] then
                            if trackedPlayers[plr].SkeletonConnection then
                                safeDisconnectConn(trackedPlayers[plr].SkeletonConnection)
                            end
                            if trackedPlayers[plr].SkeletonLimbs then
                                for _, line in pairs(trackedPlayers[plr].SkeletonLimbs) do
                                    pcall(function()
                                        line:Remove()
                                    end)
                                end
                            end
                            trackedPlayers[plr] = nil
                        end
                    end
                end
            end)
    end
    coroutine.wrap(Updater)()
end

local function DrawSkeletonESP(plr)
    local data = trackedPlayers[plr]
    if not data then
        return
    end

    local function DrawLine()
        return NewLine(1, Color3.fromRGB(255, 255, 255))
    end
    
    repeat task.wait() until plr.Character ~= nil and plr.Character:FindFirstChild("Humanoid") ~= nil

    local limbs = {}
    local isR15 = (plr.Character.Humanoid.RigType == Enum.HumanoidRigType.R15)
    
    if isR15 then
        limbs = {
            Head_UpperTorso = DrawLine(),
            UpperTorso_LowerTorso = DrawLine(),
            UpperTorso_LeftUpperArm = DrawLine(),
            LeftUpperArm_LeftLowerArm = DrawLine(),
            LeftLowerArm_LeftHand = DrawLine(),
            UpperTorso_RightUpperArm = DrawLine(),
            RightUpperArm_RightLowerArm = DrawLine(),
            RightLowerArm_RightHand = DrawLine(),
            LowerTorso_LeftUpperLeg = DrawLine(),
            LeftUpperLeg_LeftLowerLeg = DrawLine(),
            LefLowerLeg_LeftFoot = DrawLine(),
            LowerTorso_RightUpperLeg = DrawLine(),
            RightUpperLeg_RightLowerLeg = DrawLine(),
            RightLowerLeg_RightFoot = DrawLine(),
        }
    else
        limbs = {
            Head_Torso = DrawLine(),
            Torso_LeftArm = DrawLine(),
            Torso_RightArm = DrawLine(),
            Torso_LeftLeg = DrawLine(),
            Torso_RightLeg = DrawLine(),
        }
    end

    local function SetVisible(state)
        if limbs then
            for _, v in pairs(limbs) do
                if v and v.Visible ~= state then
                    v.Visible = state
                end
            end
        end
    end
    data.SkeletonVisibilityFunc = SetVisible
    data.SkeletonLimbs = limbs

    local function UpdateR15Skeleton(char)
        local H, UT, LT, LUA, LLA, LH, RUA, RLA, RH, LUL, LLL, LF, RUL, RLL, RF = nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
        pcall(function()
            H = char.Head.Position
            UT = char.UpperTorso.Position
            LT = char.LowerTorso.Position
            LUA = char.LeftUpperArm.Position
            LLA = char.LeftLowerArm.Position
            LH = char.LeftHand.Position
            RUA = char.RightUpperArm.Position
            RLA = char.RightLowerArm.Position
            RH = char.RightHand.Position
            LUL = char.LeftUpperLeg.Position
            LLL = char.LeftLowerLeg.Position
            LF = char.LeftFoot.Position
            RUL = char.RightUpperLeg.Position
            RLL = char.RightLowerLeg.Position
            RF = char.RightFoot.Position
        end)
        if not H or not UT then return false end

        local function WTP(p)
            local wtp, onScreen = camera:WorldToViewportPoint(p)
            return Vector2.new(wtp.X, wtp.Y), onScreen
        end

        local H2, onScreen = WTP(H)
        if not onScreen then return false end
        local UT2, _ = WTP(UT)
        local LT2, _ = WTP(LT)
        local LUA2, _ = WTP(LUA)
        local LLA2, _ = WTP(LLA)
        local LH2, _ = WTP(LH)
        local RUA2, _ = WTP(RUA)
        local RLA2, _ = WTP(RLA)
        local RH2, _ = WTP(RH)
        local LUL2, _ = WTP(LUL)
        local LLL2, _ = WTP(LLL)
        local LF2, _ = WTP(LF)
        local RUL2, _ = WTP(RUL)
        local RLL2, _ = WTP(RLL)
        local RF2, _ = WTP(RF)

        limbs.Head_UpperTorso.From, limbs.Head_UpperTorso.To = H2, UT2
        limbs.UpperTorso_LowerTorso.From, limbs.UpperTorso_LowerTorso.To = UT2, LT2
        limbs.UpperTorso_LeftUpperArm.From, limbs.UpperTorso_LeftUpperArm.To = UT2, LUA2
        limbs.LeftUpperArm_LeftLowerArm.From, limbs.LeftUpperArm_LeftLowerArm.To = LUA2, LLA2
        limbs.LeftLowerArm_LeftHand.From, limbs.LeftLowerArm_LeftHand.To = LLA2, LH2
        limbs.UpperTorso_RightUpperArm.From, limbs.UpperTorso_RightUpperArm.To = UT2, RUA2
        limbs.RightUpperArm_RightLowerArm.From, limbs.RightUpperArm_RightLowerArm.To = RUA2, RLA2
        limbs.RightLowerArm_RightHand.From, limbs.RightLowerArm_RightHand.To = RLA2, RH2
        limbs.LowerTorso_LeftUpperLeg.From, limbs.LowerTorso_LeftUpperLeg.To = LT2, LUL2
        limbs.LeftUpperLeg_LeftLowerLeg.From, limbs.LeftUpperLeg_LeftLowerLeg.To = LUL2, LLL2
        limbs.LeftLowerLeg_LeftFoot.From, limbs.LeftLowerLeg_LeftFoot.To = LLL2, LF2
        limbs.LowerTorso_RightUpperLeg.From, limbs.LowerTorso_RightUpperLeg.To = LT2, RUL2
        limbs.RightUpperLeg_RightLowerLeg.From, limbs.RightUpperLeg_RightLowerLeg.To = RUL2, RLL2
        limbs.RightLowerLeg_RightFoot.From, limbs.RightLowerLeg_RightFoot.To = RLL2, RF2

        return true
    end

    local function UpdateR6Skeleton(char)
        local H, T, LA, RA, LL, RL = nil, nil, nil, nil, nil, nil
        pcall(function()
            H = char.Head.Position
            T = char.Torso.Position
            LA = char["Left Arm"].Position
            RA = char["Right Arm"].Position
            LL = char["Left Leg"].Position
            RL = char["Right Leg"].Position
        end)
        if not H or not T then return false end

        local function WTP(p)
            local wtp, onScreen = camera:WorldToViewportPoint(p)
            return Vector2.new(wtp.X, wtp.Y), onScreen
        end

        local H2, onScreen = WTP(H)
        if not onScreen then return false end
        local T2, _ = WTP(T)
        local LA2, _ = WTP(LA)
        local RA2, _ = WTP(RA)
        local LL2, _ = WTP(LL)
        local RL2, _ = WTP(RL)

        limbs.Head_Torso.From, limbs.Head_Torso.To = H2, T2
        limbs.Torso_LeftArm.From, limbs.Torso_LeftArm.To = T2, LA2
        limbs.Torso_RightArm.From, limbs.Torso_RightArm.To = T2, RA2
        limbs.Torso_LeftLeg.From, limbs.Torso_LeftLeg.To = T2, LL2
        limbs.Torso_RightLeg.From, limbs.Torso_RightLeg.To = T2, RL2

        return true
    end

    local connection
    connection = RunService.RenderStepped:Connect(function()
        if not skeletonEspEnabled or not plr.Character or plr.Character.Humanoid.Health <= 0 then
            SetVisible(false)
            return
        end

        local isVisible = false
        if plr.Character.Humanoid.RigType == Enum.HumanoidRigType.R15 then
            isVisible = UpdateR15Skeleton(plr.Character)
        else
            isVisible = UpdateR6Skeleton(plr.Character)
        end

        if isVisible then
            if not limbs.Head_UpperTorso.Visible then
                SetVisible(true)
            end
        else
            if limbs.Head_UpperTorso.Visible then
                SetVisible(false)
            end
        end

        if not Players:FindFirstChild(plr.Name) then
            safeDisconnectConn(connection)
        end
    end)
    data.SkeletonConnection = connection
end

local function trackPlayer(newplr)
    if newplr.Name ~= player.Name then
        trackedPlayers[newplr] = trackedPlayers[newplr] or {}
        coroutine.wrap(ESP)(newplr)
        task.spawn(DrawSkeletonESP, newplr)
    end
end

local function onPlayerRemoving(rem)
    local data = trackedPlayers[rem]
    if data then
        if data.SkeletonConnection then
            safeDisconnectConn(data.SkeletonConnection)
        end
        if data.SkeletonLimbs then
            for _, line in pairs(data.SkeletonLimbs) do
                pcall(function()
                    line:Remove()
                end)
            end
        end
        trackedPlayers[rem] = nil
    end
end

local PlayerESP = {
    refreshAutoDig = refreshAutoDig
}

function PlayerESP:Init()
    for _, v in pairs(Players:GetPlayers()) do
        trackPlayer(v)
    end
    Players.PlayerAdded:Connect(trackPlayer)
    Players.PlayerRemoving:Connect(onPlayerRemoving)
end

function PlayerESP:InitAutomation()
    local savedState = false
    if savedState then
        self:SetAutoItemBuffs(true)
    end
end

function PlayerESP:SetBoxEsp(state)
    boxEspEnabled = state
end
function PlayerESP:SetHealthEsp(state)
    healthEspEnabled = state
end
function PlayerESP:SetTracers(state)
    tracersEnabled = state
end
function PlayerESP:SetTeamCheck(state)
    teamCheckEnabled = state
end
function PlayerESP:SetTeamColor(state)
    teamColorEnabled = state
end
function PlayerESP:SetSkeletonEsp(state)
    skeletonEspEnabled = state
end
function PlayerESP:SetNameEsp(state)
    nameEspEnabled = state
end
function PlayerESP:SetHotbarEsp(state)
    hotbarEspEnabled = state
    if not state then
        for _, data in pairs(trackedPlayers) do
            if data.destroyHotbarGui then
                data.destroyHotbarGui()
            end
        end
    end
end
function PlayerESP:SetHotbarDisplay(list)
    local set = {}
    if type(list) == "table" then
        for _, name in ipairs(list) do
            set[tostring(name)] = true
        end
    end
    hotbarDisplaySet = set
end

function PlayerESP:SetAutoDigManual(state, isAutoFarmEnabled)
    autoDigManualEnabled = state
    refreshAutoDig(isAutoFarmEnabled)
end

function PlayerESP:SetAutoSprinkler(state)
    autoSprinklerEnabled = state
end

function PlayerESP:SetAutoActive(enabled, interval, activeName)
    local state = { enabled }
    local threadRef = { nil }
    
    local function getAutoLoopState(name)
        if not PlayerESP.ActiveStates then PlayerESP.ActiveStates = {} end
        if not PlayerESP.ActiveStates[name] then
            PlayerESP.ActiveStates[name] = { state = state, thread = threadRef }
        end
        return PlayerESP.ActiveStates[name]
    end

    local tracker = getAutoLoopState(activeName)

    if enabled then
        startAutoLoop(tracker.state, tracker.thread, interval, function()
            firePlayerActives(activeName)
        end)
    else
        stopAutoLoop(tracker.state, tracker.thread)
    end
end

function PlayerESP:SetAutoItemBuffs(enabled)
    autoBuffItemsState[1] = enabled
    if enabled then
        startAutoLoop(autoBuffItemsState, autoBuffItemsThread, 600, releaseBuffs)
    else
        stopAutoLoop(autoBuffItemsState, autoBuffItemsThread)
    end
end

function PlayerESP:FireActive(activeName)
    firePlayerActives(activeName)
end

return PlayerESP
