if GetResourceState('qb-core') ~= 'started' then return end
if GetResourceState('qb-inventory') ~= 'started' then return end

QBCore = exports['qb-core']:GetCoreObject()

MBT.QbUseable.RegisterItems()
