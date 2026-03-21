if GetResourceState('es_extended') ~= 'started' then return end

ESX = exports.es_extended:getSharedObject()

-- Player loaded event
AddEventHandler('esx:loadingScreenOff', function()
    while not ESX.IsPlayerLoaded() do Wait(200) end
    -- Hide PED IMMEDIATELY before appearance script loads clothes
    SetEntityAlpha(PlayerPedId(), 0, false)
    Citizen.Wait(2000)
    MBT.Utils.UpdatePlayerClothes()
    MBT.Utils.Target()
    TriggerServerEvent("mbt_meta_clothes:playerReady")
    MBT.Utils.InitClothingCache()
    MBT.Utils.StartHybridDetection()
end)

-- Setup shared handlers with ESX sex format ("m" = male, "f" = female)
MBT.SharedClient.SetupCheckDress(function(sex)
    return sex == "m" and "male" or "female"
end)

MBT.SharedClient.SetupInventoryChecks()
MBT.SharedClient.SetupStealDress()
