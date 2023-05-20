if GetResourceState('ox_core') ~= 'started' then return end

local file = ('imports/%s.lua'):format(IsDuplicityVersion() and 'server' or 'client')
local import = LoadResourceFile('ox_core', file)
local chunk = assert(load(import, ('@@ox_core/%s'):format(file)))
chunk()

RegisterNetEvent('mbt_metaclothes:checkDress')
AddEventHandler('mbt_metaclothes:checkDress', function(data)
    data.pedSex = data.sex
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

        if dressType == 'Drawable' then TriggerEvent("mbt_metaclothes:applyDress", data.itemInfo.metadata) end
        if dressType == 'Prop'     then TriggerEvent("mbt_metaclothes:applyProps", data.itemInfo.metadata) end
        if dressType == 'DressKit' then TriggerEvent("mbt_metaclothes:applyKitDress", data.itemInfo) end
    else
        MBT.NotifyHandler(MBT.Labels["undress"], "error")    
    end
end)

function saveOutfit()
    local appearance = exports['fivem-appearance']:getPedAppearance(PlayerPedId())
    TriggerServerEvent('ox_appearance:save', appearance)
end