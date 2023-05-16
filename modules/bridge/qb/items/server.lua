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

    TriggerClientEvent("mbt_metaclothes:checkDress", {
		type = "Drawables",
		index = item.info,
		sex = player.PlayerData.charinfo.gender,
        itemInfo = item.info
	})
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

    TriggerClientEvent("mbt_metaclothes:checkDress", player.PlayerData.source, {
		type = "Drawables",
		index = item.info.index,
		sex = player.PlayerData.charinfo.gender,
        itemInfo = item.info
	})
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

    TriggerClientEvent("mbt_metaclothes:checkDress", player.PlayerData.source, {
		type = "Drawables",
		index = item.info.index,
		sex = player.PlayerData.charinfo.gender,
        itemInfo = item.info
	})
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

    TriggerClientEvent("mbt_metaclothes:checkDress", player.PlayerData.source, {
		type = "Drawables",
		index = item.info.index,
		sex = player.PlayerData.charinfo.gender,
        itemInfo = item.info
	})
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

    TriggerClientEvent("mbt_metaclothes:checkDress", player.PlayerData.source, {
		type = "Props",
		index = item.info.index,
		sex = player.PlayerData.charinfo.gender,
        itemInfo = item.info
	})
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

    TriggerClientEvent("mbt_metaclothes:checkDress", player.PlayerData.source, {
		type = "Props",
		index = item.info.index,
		sex = player.PlayerData.charinfo.gender,
        itemInfo = item.info
	})
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

    TriggerClientEvent("mbt_metaclothes:checkDress", player.PlayerData.source, {
		type = "Props",
		index = item.info.index,
		sex = player.PlayerData.charinfo.gender,
        itemInfo = item.info
	})
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

    TriggerClientEvent("mbt_metaclothes:checkDress", player.PlayerData.source, {
		type = "Props",
		index = item.info.index,
		sex = player.PlayerData.charinfo.gender,
        itemInfo = item.info
	})
end)

QBCore.Functions.AddItems({
    ['topdress'] = {
        name = 'topdress',
        label = 'YOUR_DESCRIPTION',
        weight = 100,
        type = 'item',
        image = 'water_bottle.png',
        unique = true,
        useable = true,
        shouldClose = true,
        combinable = nil,
        description = 'For all the thirsty out there'
    },
    ['trousers'] = {
        name = 'trousers',
        label = 'Trousers',
        weight = 10,
        type = 'item',
        image = 'sandwich.png',
        unique = false,
        useable = true,
        shouldClose = true,
        combinable = nil,
        description = 'Nice bread for your stomach'
    },
    ['shoes'] = {
        name = 'shoes',
        label = 'Sandwich',
        weight = 10,
        type = 'item',
        image = 'sandwich.png',
        unique = false,
        useable = true,
        shouldClose = true,
        combinable = nil,
        description = 'Nice bread for your stomach'
    },
    ['chain'] = {
        name = 'chain',
        label = 'Chain',
        weight = 10,
        type = 'item',
        image = 'sandwich.png',
        unique = false,
        useable = true,
        shouldClose = true,
        combinable = nil,
        description = 'Nice bread for your stomach'
    },

    ['watch'] = {
        name = 'watch',
        label = 'Watch',
        weight = 10,
        type = 'item',
        image = 'sandwich.png',
        unique = false,
        useable = true,
        shouldClose = true,
        combinable = nil,
        description = 'Nice bread for your stomach'
    },
    ['hat'] = {
        name = 'hat',
        label = 'Hat',
        weight = 10,
        type = 'item',
        image = 'sandwich.png',
        unique = false,
        useable = true,
        shouldClose = true,
        combinable = nil,
        description = 'Nice bread for your stomach'
    },
    ['glasses'] = {
        name = 'glasses',
        label = 'Glasses',
        weight = 10,
        type = 'item',
        image = 'sandwich.png',
        unique = false,
        useable = true,
        shouldClose = true,
        combinable = nil,
        description = 'Nice bread for your stomach'
    },
    ['earaccess'] = {
        name = 'earaccess',
        label = 'Ear Access',
        weight = 10,
        type = 'item',
        image = 'sandwich.png',
        unique = false,
        useable = true,
        shouldClose = true,
        combinable = nil,
        description = 'Nice bread for your stomach'
    },  
})