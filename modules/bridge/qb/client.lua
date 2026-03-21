if GetResourceState('qb-core') ~= 'started' then return end

QBCore = exports['qb-core']:GetCoreObject()

-- Player loaded event
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    MBT.Utils.UpdatePlayerClothes()
    MBT.Utils.Target()
    SetEntityAlpha(PlayerPedId(), 0, false)
    TriggerServerEvent("mbt_meta_clothes:playerReady")
    MBT.Utils.InitClothingCache()
    MBT.Utils.StartHybridDetection()
end)

-- Setup shared handlers with QB sex format (0 = male, 1 = female)
MBT.SharedClient.SetupCheckDress(function(sex)
    return sex == 0 and "male" or "female"
end)

MBT.SharedClient.SetupInventoryChecks()
MBT.SharedClient.SetupStealDress()
