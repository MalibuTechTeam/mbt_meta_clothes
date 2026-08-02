if GetResourceState('es_extended') ~= 'started' then return end

ESX = exports.es_extended:getSharedObject()

-- If the resource restarts while an ESX player is already active, the next
-- playerLoaded is a genuine switch and must not be discarded.
local playerReadySent = ESX.IsPlayerLoaded()

AddEventHandler('esx:loadingScreenOff', function()
    while not ESX.IsPlayerLoaded() do Wait(200) end
    if playerReadySent then return end
    playerReadySent = true

    MBT.Trace.Begin('esx:loadingScreenOff')
    MBT.Trace.OwnAlpha(0)
    SetEntityAlpha(PlayerPedId(), 0, false)
    -- Safety net: if nobody closes the transition within 5s, reveal anyway.
    if MBT.Utils.SchedulePedVisibilityWatchdog then
        MBT.Utils.SchedulePedVisibilityWatchdog("loadingScreenOff")
    end
    -- playerReady FIRST and with no waiting: it starts the server-side state
    -- push, and every millisecond here is a millisecond of wrong outfit on
    -- screen. A `Wait(2000)` that used to sit here cost 2s out of 2083ms of
    -- total latency, and duplicated an identifier retry the server already has.
    TriggerServerEvent("mbt_meta_clothes:playerReady")
    MBT.Utils.UpdatePlayerClothes()
    MBT.Utils.Target()
    MBT.Utils.StartHybridDetection()
end)

-- Pause/resume driven by the server: only the server knows for certain when
-- logout and load happen, while the client-side esx:onPlayerLogout is not
-- reliable across every multicharacter setup.
RegisterNetEvent('mbt_meta_clothes:multichar:pauseDetection')
AddEventHandler('mbt_meta_clothes:multichar:pauseDetection', function()
    MBT.Trace.Begin('pauseDetection')
    if MBT.Utils.PauseHybridDetection then
        MBT.Utils.PauseHybridDetection()
    end
    -- Hide before the new character's appearance script applies its skin.
    MBT.Trace.OwnAlpha(0)
    SetEntityAlpha(PlayerPedId(), 0, false)

    -- Once only, never in a loop: multicharacter resources write the alpha too,
    -- and contradicting them repeatedly produces a strobe instead of a hidden
    -- PED. Wrong garments applied in the meantime are fixed by restore
    -- protection, which reacts within one frame.
end)

-- Only fires from the second load onwards: on the first login `playerReadySent`
-- is already true from loadingScreenOff.
--
-- RegisterNetEvent is mandatory — esx:playerLoaded arrives via TriggerClientEvent
-- and without registration FiveM drops it silently.
--
-- Detection stays paused: restoreWearing does the resume, because that is the
-- only point where we know the expected state to realign the baseline to.
RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function()
    if not playerReadySent then
        -- First load after resource start: loadingScreenOff handles that one.
        return
    end
    -- No waiting: we apply immediately, and restore protection covers any late
    -- appearance-script change for 15s.
    MBT.Trace.Begin('esx:playerLoaded')
    MBT.Trace.OwnAlpha(0)
    SetEntityAlpha(PlayerPedId(), 0, false)
    if MBT.Utils.SchedulePedVisibilityWatchdog then
        MBT.Utils.SchedulePedVisibilityWatchdog("esx:playerLoaded")
    end
    MBT.Utils.UpdatePlayerClothes()
    MBT.Utils.Target()
    TriggerServerEvent("mbt_meta_clothes:playerReady")
    MBT.Utils.StartHybridDetection()
end)

MBT.SharedClient.SetupInventoryChecks()
MBT.SharedClient.SetupStealDress()
