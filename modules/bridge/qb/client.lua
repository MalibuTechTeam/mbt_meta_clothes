if GetResourceState('qb-core') ~= 'started' then return end
-- Su QBox l'autorità è qbx_core: alcuni server tengono acceso uno shim
-- qb-core per risorse legacy, e senza questa uscita si attiverebbero due
-- bridge sullo stesso player.
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
    -- forza la visibilità per non lasciare il player invisibile (multichar
    -- fast-switch o eventi di rete persi).
    if MBT.Utils.SchedulePedVisibilityWatchdog then
        MBT.Utils.SchedulePedVisibilityWatchdog("QBCore:Client:OnPlayerLoaded")
    end
    TriggerServerEvent("mbt_meta_clothes:playerReady")
    MBT.Utils.StartHybridDetection()
end)

MBT.SharedClient.SetupInventoryChecks()
MBT.SharedClient.SetupStealDress()
