local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local M = {}
M.Enabled = false
M.OrigDist = nil
M.OrigNear = nil
M.ISTable = nil

local function findIS()
    if M.ISTable then return M.ISTable end
    pcall(function()
        for _, v in ipairs(getgc(true)) do
            if typeof(v) == "table" and rawget(v, "InteractionDistance") and rawget(v, "NearBypassDistance") and rawget(v, "CheckConditions") then
                M.ISTable = v
                M.OrigDist = v.InteractionDistance
                M.OrigNear = v.NearBypassDistance
                break
            end
        end
    end)
    return M.ISTable
end

local API = {}

function API:Init()
    findIS()
end

function API:SetEnabled(s)
    M.Enabled = s
    pcall(function()
        local is = findIS()
        if not is then return end
        if s then
            is.InteractionDistance = 9999
            is.NearBypassDistance = 9999
            is.BypassWhenNear = true
        else
            is.InteractionDistance = M.OrigDist or 15
            is.NearBypassDistance = M.OrigNear or 8
            is.BypassWhenNear = false
        end
    end)
end

return API
