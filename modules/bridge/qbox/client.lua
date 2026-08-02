if GetResourceState('qbx_core') ~= 'started' then return end

local loadedHandled = false

local function onPlayerLoaded(reason)
    -- QBox signals login through the legacy event and through the state bag
    -- 'isLoggedIn'. Both arrive, but the work must happen once: hiding the PED
    -- twice breaks nothing, whereas a second TriggerServerEvent would waste a
    -- round-trip for nothing.
    if loadedHandled then return end
    loadedHandled = true

    MBT.Trace.Begin(reason)
    MBT.Utils.UpdatePlayerClothes()
    MBT.Utils.Target()
    MBT.Trace.OwnAlpha(0)
    SetEntityAlpha(PlayerPedId(), 0, false)
    if MBT.Utils.SchedulePedVisibilityWatchdog then
        MBT.Utils.SchedulePedVisibilityWatchdog(reason)
    end
    TriggerServerEvent("mbt_meta_clothes:playerReady")
    MBT.Utils.StartHybridDetection()
end

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    onPlayerLoaded('QBCore:Client:OnPlayerLoaded')
end)

-- Logging out reopens the gate: without this a character switch would be
-- ignored, because loadedHandled stayed true from the previous login.
AddEventHandler('QBCore:Client:OnPlayerUnload', function()
    loadedHandled = false
end)

AddEventHandler('qbx_core:client:playerLoggedOut', function()
    loadedHandled = false
end)

-- State bag fallback: qbx_core treats it as the source of truth for login, so
-- it covers the case where the legacy event is never fired.
AddStateBagChangeHandler('isLoggedIn', ('player:%s'):format(GetPlayerServerId(PlayerId())), function(_, _, value)
    if value == true then
        onPlayerLoaded('qbx:isLoggedIn')
    else
        loadedHandled = false
    end
end)

MBT.SharedClient.SetupInventoryChecks()
MBT.SharedClient.SetupStealDress()
