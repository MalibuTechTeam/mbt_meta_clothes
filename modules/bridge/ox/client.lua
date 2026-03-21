if GetResourceState('ox_core') ~= 'started' then return end

local file = ('imports/%s.lua'):format(IsDuplicityVersion() and 'server' or 'client')
local import = LoadResourceFile('ox_core', file)
local chunk = assert(load(import, ('@@ox_core/%s'):format(file)))
chunk()

-- Player loaded event
AddEventHandler('ox:playerLoaded', function(data)
    MBT.Utils.UpdatePlayerClothes()
    MBT.Utils.Target()
    SetEntityAlpha(PlayerPedId(), 0, false)
    TriggerServerEvent("mbt_meta_clothes:playerReady")
    MBT.Utils.InitClothingCache()
    MBT.Utils.StartHybridDetection()
end)

-- Setup shared handlers with OX sex format ("m" = male, "f" = female)
MBT.SharedClient.SetupCheckDress(function(sex)
    return sex == "m" and "male" or "female"
end)

MBT.SharedClient.SetupInventoryChecks()
MBT.SharedClient.SetupStealDress()
