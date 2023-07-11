if GetResourceState('es_extended') ~= 'started' then return end

ESX = exports.es_extended:getSharedObject()

local isFivemAppearance    = GetResourceState('fivem-appearance'):find('start')
local isIlleniumAppearance = GetResourceState('illenium-appearance'):find('start')
local appearance

local Utils = loadModule('modules.utils.client')

AddEventHandler('esx:loadingScreenOff', function()
    while not ESX.IsPlayerLoaded() do Wait(200) end
    Citizen.Wait(2000)
    Utils.UpdatePlayerClothes()
    Utils.Target()
end)

RegisterNetEvent('mbt_meta_clothes:checkDress')
AddEventHandler('mbt_meta_clothes:checkDress', function(data)
    data.pedSex = data.sex == "m" and "male" or "female"
    local currentTopDress = {}
    local isDefault = true

    Utils.UpdatePlayerClothes()

    if type(data.index) =="table" and data.index["Arms"] then
        isDefault = Utils.HandleTopDress(data)
    else
        assert(MBT[data.type][data.index]["Default"][data.pedSex] and type(MBT[data.type][data.index]["Default"][data.pedSex]) == "table", "Invalid value or wrong type for key " ..data.index)
        
        if not Utils.TableContainsValue({table = MBT[data.type][data.index]["Default"][data.pedSex], value = playerWearing[data.type][data.index]}) then
            isDefault = false
        end
    end
    
    -- TODO : Fix This!!
    print(isDefault)
    if isDefault then
        local dressType    = data.itemInfo.type or data.itemInfo.metadata.type

        if dressType == 'Drawable' then TriggerEvent("mbt_meta_clothes:applyDress", data.itemInfo.metadata) end
        if dressType == 'Prop'     then TriggerEvent("mbt_meta_clothes:applyProps", data.itemInfo.metadata) end
        if dressType == 'DressKit' then TriggerEvent("mbt_meta_clothes:applyKitDress", data.itemInfo) end
    else
        MBT.NotifyHandler(MBT.Labels["undress"], "error")    
    end
end)

function checkMaskState()
    local maskCount = exports.ox_inventory:Search('count', 'mask')
    if maskCount >= 1 then maskState = true else maskState = false end
    return maskState
end

function checkBagState()
    local bagCount  = exports.ox_inventory:Search('count', 'bag')
    if bagCount >= 1 then bagState = true else bagState = false end
    return bagState
end

function checkArmorState()
    local armorCount  = exports.ox_inventory:Search('count', {'smallarmor', 'medarmor', 'heavyarmor'})
        for k,v in pairs(armorCount) do
            if v >=1 then armorState = true else armorState = false end
        end

    return armorState
end

function stealPlayerDress()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local closestPlayer = data.entity


    -- TODO : Check if player doesn't have default clothes
    if exports.ox_lib:progressCircle({
        duration = 2000,
        label = 'Steal clothes',
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true,
        },
    }) then
        Utils.StealAnim()
        TriggerServerEvent('mbt_meta_clothes:syncStealDress', GetPlayerServerId(NetworkGetPlayerIndexFromPed(closestPlayer)))
    else 
        print('Do stuff when cancelled') 
    end
-- else
    -- TriggerEvent('notification', 'Cant.', 2)
-- end
end

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