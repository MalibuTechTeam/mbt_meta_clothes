if GetResourceState('qb-core') ~= 'started' then return end

QBCore = exports['qb-core']:GetCoreObject()

-- Player loaded event
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    MBT.Utils.UpdatePlayerClothes()
    MBT.Utils.Target()
    SetEntityAlpha(PlayerPedId(), 0, false)
    -- Watchdog: se entro 5s nessun restoreWearing/requestPedScan resetta alpha,
    -- forza la visibilità per non lasciare il player invisibile (multichar
    -- fast-switch o eventi di rete persi).
    if MBT.Utils.SchedulePedVisibilityWatchdog then
        MBT.Utils.SchedulePedVisibilityWatchdog("QBCore:Client:OnPlayerLoaded")
    end
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
