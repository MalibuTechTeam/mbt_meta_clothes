if GetResourceState('qb-core') ~= 'started' then return end

QBCore = exports['qb-core']:GetCoreObject()

local isQbClothing = GetResourceState('qb-clothing'):find('start')
local isIlleniumAppearance = GetResourceState('illenium-appearance'):find('start')
local appearance

RegisterNetEvent('mbt_meta_clothes:checkDress')
AddEventHandler('mbt_meta_clothes:checkDress', function(data)
    data.pedSex = data.sex == 0 and "male" or "female"
    local currentTopDress = {}
    local isDefault = true

    updatePlayerClothes()

    if type(data.index) =="table" and data.index["Arms"] then
        isDefault = handleTopDress(data)
    else
        assert(MBT[data.type][data.index]["Default"][data.pedSex] and type(MBT[data.type][data.index]["Default"][data.pedSex]) == "table", "Invalid value or wrong type for key " ..data.index)
        
        if not tableContainsValue({table = MBT[data.type][data.index]["Default"][data.pedSex], value = playerWearing[data.type][data.index]}) then
            isDefault = false
        end
    end
    
    if isDefault then
        local dressType    = data.itemInfo.type or data.itemInfo.metadata.type

        if dressType == 'Drawable' then TriggerEvent("mbt_meta_clothes:applyDress", data.itemInfo) end
        if dressType == 'Prop'     then TriggerEvent("mbt_meta_clothes:applyProps", data.itemInfo) end
        if dressType == 'DressKit' then TriggerEvent("mbt_meta_clothes:applyKitDress", data.itemInfo) end
    else
        MBT.NotifyHandler(MBT.Labels["undress"], "error")    
    end
end)

local function saveSkinIllenium()
    local pedComponents = exports['illenium-appearance']:getPedComponents(PlayerPedId())
    local pedProps = exports['illenium-appearance']:getPedProps(PlayerPedId())

    exports['illenium-appearance']:setPedComponents(PlayerPedId(), pedComponents)
    exports['illenium-appearance']:setPedProps(PlayerPedId(),pedProps)

    appearance = exports['illenium-appearance']:getPedAppearance(PlayerPedId())
    TriggerServerEvent('mbt_meta_clothes:storePlayerSkin', appearance)
end

function saveOutfit()
    if isFivemAppearance then 
        appearance = exports['fivem-appearance']:getPedAppearance(PlayerPedId())
        TriggerServerEvent('mbt_meta_clothes:storePlayerSkin', appearance)
    end

    if isIlleniumAppearance then saveSkinIllenium() end
end


