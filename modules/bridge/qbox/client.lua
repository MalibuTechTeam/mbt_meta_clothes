if GetResourceState('qbx_core') ~= 'started' then return end

local loadedHandled = false

local function onPlayerLoaded(reason)
    -- QBox segnala il login sia con l'evento legacy sia con lo state bag
    -- 'isLoggedIn'. Arrivano entrambi, ma il lavoro va fatto una volta sola:
    -- nascondere il PED due volte non rompe niente, ma TriggerServerEvent sì
    -- sprecherebbe un round-trip per nulla.
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

-- Il logout riapre la porta: senza questo un cambio personaggio verrebbe
-- ignorato perché loadedHandled è rimasto true dal login precedente.
AddEventHandler('QBCore:Client:OnPlayerUnload', function()
    loadedHandled = false
end)

AddEventHandler('qbx_core:client:playerLoggedOut', function()
    loadedHandled = false
end)

-- Fallback sullo state bag: qbx_core lo usa come sorgente di verità del login,
-- quindi copre il caso in cui l'evento legacy non venga emesso.
AddStateBagChangeHandler('isLoggedIn', ('player:%s'):format(GetPlayerServerId(PlayerId())), function(_, _, value)
    if value == true then
        onPlayerLoaded('qbx:isLoggedIn')
    else
        loadedHandled = false
    end
end)

MBT.SharedClient.SetupInventoryChecks()
MBT.SharedClient.SetupStealDress()
