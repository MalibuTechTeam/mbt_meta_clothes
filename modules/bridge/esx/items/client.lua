if GetResourceState('es_extended') ~= 'started' then return end
if GetResourceState('ox_inventory') ~= 'started' then return end

ESX = exports.es_extended:getSharedObject()

MBT.OxItems.RegisterItems(function()
    local sex = ESX.GetPlayerData().sex
    local sexLabel = sex == "m" and "male" or "female"
    return sex, sexLabel
end)
