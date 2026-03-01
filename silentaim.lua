local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LP = Players.LocalPlayer
local V2 = Vector2.new
local C3 = Color3.fromRGB

local SA = {}
SA.Enabled = false
SA.FOVRadius = 120
SA.ShowFOV = true
SA.TargetPart = "Head"
SA.Wallbang = false

local fovCircle = Drawing.new("Circle")
fovCircle.Color = C3(255, 255, 255)
fovCircle.Thickness = 1
fovCircle.Filled = false
fovCircle.Transparency = 0.5
fovCircle.Radius = SA.FOVRadius
fovCircle.Visible = false
fovCircle.NumSides = 64

local lockedTarget = nil

local function getClosestHead()
    local closest = nil
    local closestDist = SA.FOVRadius
    local cx = Camera.ViewportSize.X / 2
    local cy = Camera.ViewportSize.Y / 2
    local center = V2(cx, cy)

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LP then continue end
        pcall(function()
            if plr.Team and LP.Team and plr.Team == LP.Team then return end
            local char = plr.Character
            if not char then return end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then return end
            local part = char:FindFirstChild(SA.TargetPart) or char:FindFirstChild("Head")
            if not part then return end
            local pos, onScreen = Camera:WorldToViewportPoint(part.Position)
            if not onScreen and not SA.Wallbang then return end
            local screenPos = V2(pos.X, pos.Y)
            local dist = (screenPos - center).Magnitude
            if dist < closestDist then
                closestDist = dist
                closest = part
            end
        end)
    end
    return closest
end

local oldNamecall
oldNamecall = hookmetamethod(workspace, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    if SA.Enabled and method == "Raycast" then
        local args = {...}
        local origin = args[1]
        if typeof(origin) == "Vector3" then
            local camPos = Camera.CFrame.Position
            local dist = (origin - camPos).Magnitude
            if dist < 5 then
                local target = getClosestHead()
                if target and target.Parent then
                    local targetPos = target.Position
                    local direction = (targetPos - origin).Unit
                    local range = args[2] and args[2].Magnitude or 1000
                    args[2] = direction * range

                    if SA.Wallbang then
                        local p = RaycastParams.new()
                        p.FilterType = Enum.RaycastFilterType.Include
                        local chars = {}
                        for _, plr in ipairs(Players:GetPlayers()) do
                            if plr ~= LP and plr.Character then
                                table.insert(chars, plr.Character)
                            end
                        end
                        p.FilterDescendantsInstances = chars
                        args[3] = p
                    end

                    return oldNamecall(self, unpack(args))
                end
            end
        end
    end
    return oldNamecall(self, ...)
end))


RunService.Heartbeat:Connect(function()
    Camera = workspace.CurrentCamera
    pcall(function()
        if SA.ShowFOV and SA.Enabled then
            local cx = Camera.ViewportSize.X / 2
            local cy = Camera.ViewportSize.Y / 2
            fovCircle.Position = V2(cx, cy)
            fovCircle.Radius = SA.FOVRadius
            fovCircle.Visible = true
        else
            fovCircle.Visible = false
        end
    end)
end)

local API = {}
function API:Init() end
function API:SetEnabled(s)
    SA.Enabled = s
    if not s then
        fovCircle.Visible = false
    end
end
function API:SetFOV(r)
    SA.FOVRadius = r
    fovCircle.Radius = r
end
function API:SetShowFOV(s) SA.ShowFOV = s end
function API:SetWallbang(s) SA.Wallbang = s end
function API:Destroy()
    pcall(function()
        fovCircle:Remove()
    end)
end
return API
