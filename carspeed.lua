local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LP = Players.LocalPlayer

local M = {}
M.Enabled = false
M.Multiplier = 1.5
M.Originals = {}
M.Conn = nil

local function getCarModel()
    local ok, result = pcall(function()
        local char = LP.Character
        if not char then return nil end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or not hum.SeatPart then return nil end
        local seat = hum.SeatPart
        local car = seat:FindFirstAncestorWhichIsA("Model")
        if car and car.Parent and car.Parent.Name == "Cars" then
            return car
        end
        return nil
    end)
    if ok then return result end
    return nil
end

local function boostCar(car)
    if not car then return end
    pcall(function()
        for _, d in ipairs(car:GetDescendants()) do
            pcall(function()
                local id = tostring(d) .. d:GetFullName()
                if d:IsA("CylindricalConstraint") then
                    if not M.Originals[id] then
                        M.Originals[id] = {
                            obj = d,
                            torque = d.MotorMaxTorque,
                            vel = d.MotorMaxAngularVelocity,
                        }
                    end
                    d.MotorMaxTorque = M.Originals[id].torque * M.Multiplier
                    d.MotorMaxAngularVelocity = M.Originals[id].vel * M.Multiplier
                elseif d:IsA("HingeConstraint") and d.ActuatorType == Enum.ActuatorType.Motor then
                    if not M.Originals[id] then
                        M.Originals[id] = {
                            obj = d,
                            torque = d.MotorMaxTorque,
                            vel = d.MotorMaxAngularVelocity,
                        }
                    end
                    d.MotorMaxTorque = M.Originals[id].torque * M.Multiplier
                    d.MotorMaxAngularVelocity = M.Originals[id].vel * M.Multiplier
                elseif d:IsA("VehicleSeat") then
                    if not M.Originals[id] then
                        M.Originals[id] = {
                            obj = d,
                            speed = d.MaxSpeed,
                            torque = d.Torque,
                        }
                    end
                    d.MaxSpeed = M.Originals[id].speed * M.Multiplier
                    d.Torque = M.Originals[id].torque * M.Multiplier
                end
            end)
        end
    end)
end

local function revertAll()
    for _, data in pairs(M.Originals) do
        pcall(function()
            local d = data.obj
            if not d or not d.Parent then return end
            if d:IsA("CylindricalConstraint") then
                d.MotorMaxTorque = data.torque
                d.MotorMaxAngularVelocity = data.vel
            elseif d:IsA("HingeConstraint") then
                d.MotorMaxTorque = data.torque
                d.MotorMaxAngularVelocity = data.vel
            elseif d:IsA("VehicleSeat") then
                d.MaxSpeed = data.speed
                d.Torque = data.torque
            end
        end)
    end
    M.Originals = {}
end

local API = {}
function API:Init() end

function API:SetEnabled(s)
    M.Enabled = s
    if s then
        local car = getCarModel()
        if car then boostCar(car) end
        if M.Conn then M.Conn:Disconnect() end
        M.Conn = RunService.Heartbeat:Connect(function()
            if not M.Enabled then return end
            pcall(function()
                local car = getCarModel()
                if car then boostCar(car) end
            end)
        end)
    else
        if M.Conn then M.Conn:Disconnect(); M.Conn = nil end
        revertAll()
    end
end

function API:SetMultiplier(n)
    M.Multiplier = n
    if M.Enabled then
        revertAll()
        local car = getCarModel()
        if car then boostCar(car) end
    end
end

return API
