if GetResourceState('qbx_core') ~= 'started' then return end
if not GetResourceState('ox_inventory'):find('start') then return end

-- QBox has no GetCoreObject: character data comes from the direct export.
-- The pcall keeps a signature change between qbx_core versions
-- from blowing up item registration.
MBT.OxItems.RegisterItems(function()
    local ok, data = pcall(function() return exports.qbx_core:GetPlayerData() end)
    local gender = ok and data and data.charinfo and data.charinfo.gender or 0
    local sexLabel = gender == 0 and "male" or "female"
    return gender, sexLabel
end)
