if GetResourceState('qb-core') ~= 'started' then return end
if GetResourceState('qb-inventory') ~= 'started' then return end

QBCore = exports['qb-core']:GetCoreObject()

QBCore.Functions.CreateUseableItem('topdress', function(source, item)
	local player = QBCore.Functions.GetPlayer(source)
	if not player.Functions.GetItemByName(item.name) then return end
    
    local sexMatch = player.PlayerData.charinfo.gender == 0 and "male" or "female"
    local sexLabel = { ["m"] = "man", ["f"] = "woman"}

	if sexMatch ~= item.info.sex then 
        MBT.NotifyHandler(MBT.Labels["wrong_sex"]..sexLabel, "error")
        return
    end

    TriggerClientEvent('mbt_meta_clothes:useTopDress', player.PlayerData.source, item.info, player.PlayerData.charinfo.gender, item.info, item)
end)

QBCore.Functions.CreateUseableItem('trousers', function(source, item)
	local player = QBCore.Functions.GetPlayer(source)
	if not player.Functions.GetItemByName(item.name) then return end

    local sexMatch = player.PlayerData.charinfo.gender == 0 and "male" or "female"
    local sexLabel = { ["m"] = "man", ["f"] = "woman"}

    if sexMatch ~= item.info.sex then 
        MBT.NotifyHandler(MBT.Labels["wrong_sex"]..sexLabel, "error")
        return
    end

    TriggerClientEvent('mbt_meta_clothes:useTrousers', player.PlayerData.source, item.info.index, player.PlayerData.charinfo.gender, item.info, item)
end)

QBCore.Functions.CreateUseableItem('shoes', function(source, item)
	local player = QBCore.Functions.GetPlayer(source)
	if not player.Functions.GetItemByName(item.name) then return end

    local sexMatch = player.PlayerData.charinfo.gender == 0 and "male" or "female"
    local sexLabel = { ["m"] = "man", ["f"] = "woman"}

    if sexMatch ~= item.info.sex then 
        MBT.NotifyHandler(MBT.Labels["wrong_sex"]..sexLabel, "error")
        return
    end

    TriggerClientEvent('mbt_meta_clothes:useShoes', player.PlayerData.source, item.info.index, player.PlayerData.charinfo.gender, item.info, item)
end)

QBCore.Functions.CreateUseableItem('chain', function(source, item)
	local player = QBCore.Functions.GetPlayer(source)
	if not player.Functions.GetItemByName(item.name) then return end

    local sexMatch = player.PlayerData.charinfo.gender == 0 and "male" or "female"
    local sexLabel = { ["m"] = "man", ["f"] = "woman"}

    if sexMatch ~= item.info.sex then 
        MBT.NotifyHandler(MBT.Labels["wrong_sex"]..sexLabel, "error")
        return
    end

    TriggerClientEvent('mbt_meta_clothes:useChain', player.PlayerData.source, item.info.index, player.PlayerData.charinfo.gender, item.info, item)
end)

QBCore.Functions.CreateUseableItem('watch', function(source, item)
	local player = QBCore.Functions.GetPlayer(source)
	if not player.Functions.GetItemByName(item.name) then return end

    local sexMatch = player.PlayerData.charinfo.gender == 0 and "male" or "female"
    local sexLabel = { ["m"] = "man", ["f"] = "woman"}

    if sexMatch ~= item.info.sex then 
        MBT.NotifyHandler(MBT.Labels["wrong_sex"]..sexLabel, "error")
        return
    end

    TriggerClientEvent('mbt_meta_clothes:useWatch', player.PlayerData.source, item.info.index, player.PlayerData.charinfo.gender, item.info, item)
end)

QBCore.Functions.CreateUseableItem('hat', function(source, item)
	local player = QBCore.Functions.GetPlayer(source)
	if not player.Functions.GetItemByName(item.name) then return end

    local sexMatch = player.PlayerData.charinfo.gender == 0 and "male" or "female"
    local sexLabel = { ["m"] = "man", ["f"] = "woman"}

    if sexMatch ~= item.info.sex then 
        MBT.NotifyHandler(MBT.Labels["wrong_sex"]..sexLabel, "error")
        return
    end

    TriggerClientEvent('mbt_meta_clothes:useHat', player.PlayerData.source, item.info.index, player.PlayerData.charinfo.gender, item.info, item)
end)

QBCore.Functions.CreateUseableItem('glasses', function(source, item)
	local player = QBCore.Functions.GetPlayer(source)
	if not player.Functions.GetItemByName(item.name) then return end

    local sexMatch = player.PlayerData.charinfo.gender == 0 and "male" or "female"
    local sexLabel = { ["m"] = "man", ["f"] = "woman"}

    if sexMatch ~= item.info.sex then 
        MBT.NotifyHandler(MBT.Labels["wrong_sex"]..sexLabel, "error")
        return
    end

    TriggerClientEvent('mbt_meta_clothes:useGlasses', player.PlayerData.source, item.info.index, player.PlayerData.charinfo.gender, item.info, item)
end)

QBCore.Functions.CreateUseableItem('earaccess', function(source, item)
	local player = QBCore.Functions.GetPlayer(source)
	if not player.Functions.GetItemByName(item.name) then return end

    local sexMatch = player.PlayerData.charinfo.gender == 0 and "male" or "female"
    local sexLabel = { ["m"] = "man", ["f"] = "woman"}

    if sexMatch ~= item.info.sex then 
        MBT.NotifyHandler(MBT.Labels["wrong_sex"]..sexLabel, "error")
        return
    end
    
    if not Player.Functions.RemoveItem(item.name, 1, item.slot) then return end

    TriggerClientEvent('mbt_meta_clothes:useEarAccess', player.PlayerData.source, item.info.index, player.PlayerData.charinfo.gender, item.info, item)
end)

QBCore.Functions.AddItems({
    ['topdress'] = {
        name = 'topdress',
        label = 'Top Dress',
        weight = 100,
        type = 'item',
        image = 'topdress.png',
        unique = true,
        useable = true,
        shouldClose = true,
        combinable = nil,
        description = 'Top Dress'
    },
    ['trousers'] = {
        name = 'trousers',
        label = 'Trousers',
        weight = 10,
        type = 'item',
        image = 'trousers.png',
        unique = false,
        useable = true,
        shouldClose = true,
        combinable = nil,
        description = 'Trousers'
    },
    ['shoes'] = {
        name = 'shoes',
        label = 'Shoes',
        weight = 10,
        type = 'item',
        image = 'shoes.png',
        unique = false,
        useable = true,
        shouldClose = true,
        combinable = nil,
        description = 'Shoes'
    },
    ['chain'] = {
        name = 'chain',
        label = 'Chain',
        weight = 10,
        type = 'item',
        image = 'chain.png',
        unique = false,
        useable = true,
        shouldClose = true,
        combinable = nil,
        description = 'Chain'
    },

    ['watch'] = {
        name = 'watch',
        label = 'Watch',
        weight = 10,
        type = 'item',
        image = 'watch.png',
        unique = false,
        useable = true,
        shouldClose = true,
        combinable = nil,
        description = 'Watch'
    },
    ['hat'] = {
        name = 'hat',
        label = 'Hat',
        weight = 10,
        type = 'item',
        image = 'hat.png',
        unique = false,
        useable = true,
        shouldClose = true,
        combinable = nil,
        description = 'Hat'
    },
    ['glasses'] = {
        name = 'glasses',
        label = 'Glasses',
        weight = 10,
        type = 'item',
        image = 'glasses.png',
        unique = false,
        useable = true,
        shouldClose = true,
        combinable = nil,
        description = 'Glasses'
    },
    ['earaccess'] = {
        name = 'earaccess',
        label = 'Ear Accessory',
        weight = 10,
        type = 'item',
        image = 'earaccess.png',
        unique = false,
        useable = true,
        shouldClose = true,
        combinable = nil,
        description = 'Ear Accessory'
    },  
})