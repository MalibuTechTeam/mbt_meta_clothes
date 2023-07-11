if GetResourceState('qb-core') ~= 'started' then return end

QBCore = exports['qb-core']:GetCoreObject()

local isQbClothing = GetResourceState('qb-clothing'):find('start')
local isIlleniumAppearance = GetResourceState('illenium-appearance'):find('start')
local appearance

local Utils = loadModule('modules.utils.client')

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    Utils.UpdatePlayerClothes()
end)

RegisterNetEvent('mbt_meta_clothes:checkDress')
AddEventHandler('mbt_meta_clothes:checkDress', function(data)
    data.pedSex = data.sex == 0 and "male" or "female"
    local currentTopDress = {}
    local isDefault = true

    updatePlayerClothes()

    if type(data.index) =="table" and data.index["Arms"] then
        isDefault = Utils.HandleTopDress(data)
    else
        assert(MBT[data.type][data.index]["Default"][data.pedSex] and type(MBT[data.type][data.index]["Default"][data.pedSex]) == "table", "Invalid value or wrong type for key " ..data.index)
        
        if not Utils.TableContainsValue({table = MBT[data.type][data.index]["Default"][data.pedSex], value = playerWearing[data.type][data.index]}) then
            isDefault = false
        end
    end
    
    if isDefault then
        local dressType = data.itemInfo.type or data.itemInfo.metadata.type

        if dressType == 'Drawable' then TriggerEvent("mbt_meta_clothes:applyDress", data.itemInfo) end
        if dressType == 'Prop'     then TriggerEvent("mbt_meta_clothes:applyProps", data.itemInfo) end
        if dressType == 'DressKit' then TriggerEvent("mbt_meta_clothes:applyKitDress", data.itemInfo) end
    else
        MBT.NotifyHandler(MBT.Labels["undress"], "error")    
    end
end)

-- function checkMaskState()
--     local maskCount = exports.ox_inventory:Search('count', 'mask')
--     if maskCount >= 1 then maskState = true else maskState = false end
--     return maskState
-- end

-- function checkBagState()
--     local bagCount  = exports.ox_inventory:Search('count', 'bag')
--     if bagCount >= 1 then bagState = true else bagState = false end
--     return bagState
-- end

-- function checkArmorState()
--     local armorCount  = exports.ox_inventory:Search('count', {'smallarmor', 'medarmor', 'heavyarmor'})
--         for k,v in pairs(armorCount) do
--             if v >=1 then armorState = true else armorState = false end
--         end

--     return armorState
-- end

-- RegisterNetEvent('mbt_meta_clothes:stealPlayerDress')
-- AddEventHandler('mbt_meta_clothes:stealPlayerDress', function(data)
--     local ped = PlayerPedId()
--     local coords = GetEntityCoords(ped)
--     local closestPlayer = data.entity

--     QBCore.Functions.Progressbar("steal_clothes", "Steal Clothes", 2000, false, true, {
--         disableMovement = true,
--         disableCarMovement = false,
--         disableMouse = false,
--         disableCombat = true,
--     }, {}, {}, {}, function() -- Done
--         Utils.stealAnim()
--         TriggerServerEvent('mbt_meta_clothes:syncStealDress', GetPlayerServerId(NetworkGetPlayerIndexFromPed(closestPlayer)))
--     end, function() -- Cancel
--         print("Canceled")
--     end)
-- end, false)

function saveOutfit()
    if isFivemAppearance then 
        appearance = exports['fivem-appearance']:getPedAppearance(PlayerPedId())
        TriggerServerEvent('mbt_meta_clothes:storePlayerSkin', appearance)
    end

    if isIlleniumAppearance then
        local pedComponents = exports['illenium-appearance']:getPedComponents(PlayerPedId())
        local pedProps = exports['illenium-appearance']:getPedProps(PlayerPedId())
    
        exports['illenium-appearance']:setPedComponents(PlayerPedId(), pedComponents)
        exports['illenium-appearance']:setPedProps(PlayerPedId(), pedProps)
    
        appearance = exports['illenium-appearance']:getPedAppearance(PlayerPedId())
        TriggerServerEvent('mbt_meta_clothes:storePlayerSkin', appearance)
    end
end


