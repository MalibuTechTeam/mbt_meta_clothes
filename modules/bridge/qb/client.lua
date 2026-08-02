if GetResourceState('qb-core') ~= 'started' then return end
-- On QBox the authority is qbx_core: some servers keep a qb-core shim running
-- for legacy resources, and without this early return two bridges would activate
-- on the same player.
if GetResourceState('qbx_core') == 'started' then return end

QBCore = exports['qb-core']:GetCoreObject()

-- Player loaded event
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    MBT.Trace.Begin('QBCore:Client:OnPlayerLoaded')
    MBT.Utils.UpdatePlayerClothes()
    MBT.Utils.Target()
    MBT.Trace.OwnAlpha(0)
    SetEntityAlpha(PlayerPedId(), 0, false)
    -- Watchdog: se entro 5s nessun restoreWearing/requestPedScan resetta alpha,
    -- force visibility so the player is not left invisible (multichar
    -- fast-switch o eventi di rete persi).
    if MBT.Utils.SchedulePedVisibilityWatchdog then
        MBT.Utils.SchedulePedVisibilityWatchdog("QBCore:Client:OnPlayerLoaded")
    end
    TriggerServerEvent("mbt_meta_clothes:playerReady")
    MBT.Utils.StartHybridDetection()
end)

MBT.SharedClient.SetupInventoryChecks()
MBT.SharedClient.SetupStealDress()
