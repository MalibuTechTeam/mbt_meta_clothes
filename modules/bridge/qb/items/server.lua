if GetResourceState('qb-core') ~= 'started' then return end

QBCore = exports['qb-core']:GetCoreObject()

QBCore.Functions.CreateUseableItem('topdress', function(source, item)
	local player = QBCore.Functions.GetPlayer(source)
	if not player.Functions.GetItemByName(item.name) then return end
    
    local sexMatch = player.PlayerData.charinfo.gender == 0 and "male" or "female"
    local sexLabel = { ["m"] = "man", ["f"] = "woman"}

	if sexMatch ~= item.info.sex then 
        -- Trigger your notify here
        -- Text: This piece of clothing is not for "..sexLabel[PlayerData.sex]
    end

	-- Trigger code here for what item should do
    TriggerClientEvent("mbt_metaclothes:checkDress", {
		type = "Drawables",
		index = item.info,
		sex = player.PlayerData.charinfo.gender,
		cb = function(canDress)
			if not canDress then
				-- lib.notify({title = 'You must first undress', description = 'CLOTHES', duration = 10000, position = 'bottom-right', style = {borderRadius = 7, backgroundColor = '#2e3847', color = '#white', fontFamily = 'Poppins', fontWeight = '500', fontSize = 15, textShadowColor = '#0000', borderRightColor = '#2e3847' , borderBottomColor = '#2e3847', borderTopColor = '#2e3847', borderLeftColor = '#d54090', borderLeftWidth = 5 , borderBottomWidth = 0, borderTopWidth = 0, borderRightWidth = 0, borderTopRightRadius = 7, borderLeftRadius  = 7, borderBottomRadius  = 7, borderTopRadius  = 7,  borderRightRadius  =7, borderStyle = 'solid', marginBottom = 20}, icon = 'shirt', iconColor = '#C53030'})
				return 
			end 
			
			TriggerEvent("mbt_metaclothes:applyKitDress", item.info)
		end
	})
end)

QBCore.Functions.CreateUseableItem('shoes', function(source, item)
	local player = QBCore.Functions.GetPlayer(source)
	if not player.Functions.GetItemByName(item.name) then return end

    print("PRAY")
    local sexMatch = player.PlayerData.charinfo.gender == 0 and "male" or "female"
    local sexLabel = { ["m"] = "man", ["f"] = "woman"}

    if sexMatch ~= item.info.sex then 
        -- Trigger your notify here
        -- Text: This piece of clothing is not for "..sexLabel[PlayerData.sex]
    end
    TriggerClientEvent("mbt_metaclothes:checkDress", player.PlayerData.source, {
		type = "Drawables",
		index = item.info.index,
		sex = player.PlayerData.charinfo.gender,
		cb = function(canDress)
            print(canDress)
			if not canDress then
				-- lib.notify({title = 'You must first undress', description = 'CLOTHES', duration = 10000, position = 'bottom-right', style = {borderRadius = 7, backgroundColor = '#2e3847', color = '#white', fontFamily = 'Poppins', fontWeight = '500', fontSize = 15, textShadowColor = '#0000', borderRightColor = '#2e3847' , borderBottomColor = '#2e3847', borderTopColor = '#2e3847', borderLeftColor = '#d54090', borderLeftWidth = 5 , borderBottomWidth = 0, borderTopWidth = 0, borderRightWidth = 0, borderTopRightRadius = 7, borderLeftRadius  = 7, borderBottomRadius  = 7, borderTopRadius  = 7,  borderRightRadius  =7, borderStyle = 'solid', marginBottom = 20}, icon = 'shirt', iconColor = '#C53030'})
				return 
			end 
			--TriggerEvent("mbt_metaclothes:applyDress", player.PlayerData.source, item.info)
		end
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
    }
})