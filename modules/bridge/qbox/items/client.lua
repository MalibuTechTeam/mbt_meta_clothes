if GetResourceState('qbx_core') ~= 'started' then return end
if not GetResourceState('ox_inventory'):find('start') then return end

-- QBox non ha GetCoreObject: i dati del personaggio arrivano dall'export
-- diretto. Il pcall evita che una firma diversa fra versioni di qbx_core
-- faccia esplodere la registrazione degli item.
MBT.OxItems.RegisterItems(function()
    local ok, data = pcall(function() return exports.qbx_core:GetPlayerData() end)
    local gender = ok and data and data.charinfo and data.charinfo.gender or 0
    local sexLabel = gender == 0 and "male" or "female"
    return gender, sexLabel
end)
