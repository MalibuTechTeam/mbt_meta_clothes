if GetResourceState('qb-core') ~= 'started' then return end

local isQBInventory = GetResourceState('qb-inventory'):find('start')
local isOXInventory = GetResourceState('ox_inventory'):find('start')

QBCore = exports['qb-core']:GetCoreObject()

if isOXInventory then
    MBT.OxItems.RegisterItems(function()
        local sex = QBCore.Functions.GetPlayerData().charinfo.gender
        local sexLabel = sex == 0 and "male" or "female"
        return sex, sexLabel
    end)
end

if isQBInventory then
    MBT.QbItems.RegisterItems()
end
