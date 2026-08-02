if GetResourceState('ox_core') ~= 'started' then return end

local file = ('imports/%s.lua'):format(IsDuplicityVersion() and 'server' or 'client')
local import = LoadResourceFile('ox_core', file)
local chunk = assert(load(import, ('@@ox_core/%s'):format(file)))
chunk()

-- Player loaded event
AddEventHandler('ox:playerLoaded', function(data)
    MBT.Trace.Begin('ox:playerLoaded')
    MBT.Utils.UpdatePlayerClothes()
    MBT.Utils.Target()
    MBT.Trace.OwnAlpha(0)
    SetEntityAlpha(PlayerPedId(), 0, false)
    -- Watchdog: se entro 5s nessun restoreWearing/requestPedScan resetta alpha,
    -- force visibility so the player is not left invisible (multichar
    -- fast-switch o eventi di rete persi).
    if MBT.Utils.SchedulePedVisibilityWatchdog then
        MBT.Utils.SchedulePedVisibilityWatchdog("ox:playerLoaded")
    end
    TriggerServerEvent("mbt_meta_clothes:playerReady")
    MBT.Utils.StartHybridDetection()
end)

MBT.SharedClient.SetupInventoryChecks()
MBT.SharedClient.SetupStealDress()
