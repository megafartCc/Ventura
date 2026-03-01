local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local M = {}
M.Enabled = false
M.Multiplier = 1.4
M.Originals = {}

local function getSeatCar()
    local char = LP.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or not hum.SeatPart then return nil end
    local seat = hum.SeatPart
    local car = seat:FindFirstAncestorWhichIsA("Model")
    if not car then return nil end
    if not car:FindFirstChild("A-Chassis Tune") then
        for _, d in ipairs(car:GetDescendants()) do
            if d.Name == "A-Chassis Tune" or d.Name == "A-Chassis_Tune" then
                return car, d
            end
        end
        return nil
    end
    return car, car:FindFirstChild("A-Chassis Tune") or car:FindFirstChild("A-Chassis_Tune")
end

local function applyBoost()
    if not M.Enabled then return end
    pcall(function()
        for _, t in ipairs(getgc(true)) do
            if typeof(t) == "table" and rawget(t, "Horsepower") and rawget(t, "PeakRPM") and rawget(t, "Redline") and rawget(t, "FinalDrive") then
                local id = tostring(t)
                if not M.Originals[id] then
                    M.Originals[id] = {
                        HP = t.Horsepower,
                        Peak = t.PeakRPM,
                        Red = t.Redline,
                        Rev = t.RevAccel,
                    }
                end
                local o = M.Originals[id]
                t.Horsepower = o.HP * M.Multiplier
                t.PeakRPM = o.Peak * M.Multiplier
                t.Redline = o.Red * M.Multiplier
                if t.RevAccel then
                    t.RevAccel = o.Rev * M.Multiplier
                end
            end
        end
    end)
end

local function revertBoost()
    pcall(function()
        for _, t in ipairs(getgc(true)) do
            if typeof(t) == "table" and rawget(t, "Horsepower") and rawget(t, "PeakRPM") and rawget(t, "Redline") and rawget(t, "FinalDrive") then
                local id = tostring(t)
                local o = M.Originals[id]
                if o then
                    t.Horsepower = o.HP
                    t.PeakRPM = o.Peak
                    t.Redline = o.Red
                    if t.RevAccel then
                        t.RevAccel = o.Rev
                    end
                end
            end
        end
    end)
    M.Originals = {}
end

local API = {}
function API:Init() end
function API:SetEnabled(s)
    M.Enabled = s
    if s then
        applyBoost()
    else
        revertBoost()
    end
end
function API:SetMultiplier(n)
    M.Multiplier = n
    if M.Enabled then
        revertBoost()
        applyBoost()
    end
end
return API
