local playerSkins = {}

AddEventHandler('playerDropped', function(reason)
    local _source = source
    
    if playerSkins[_source] then
        TriggerEvent('mbt_meta_clothes:saveSkin', _source, playerSkins[_source])
    end
end)

RegisterNetEvent('mbt_meta_clothes:storePlayerSkin', function(appearance)
    playerSkins[source] = appearance
end)

RegisterNetEvent('mbt_meta_clothes:giveDress', function(data)
    giveDress(data)
end)

RegisterNetEvent('mbt_meta_clothes:giveDressKit', function(data)
    giveDressKit(data)
end)

RegisterNetEvent('mbt_meta_clothes:giveProp', function(data)
    giveProp(data)
end)

RegisterNetEvent('mbt_meta_clothes:giveStolenItemDress', function(source, targetWearing, playerSex)
    giveStolenItemDress(source, targetWearing, playerSex)
end)

RegisterNetEvent('mbt_meta_clothes:syncStealDress', function(target)
	TriggerClientEvent('mbt_meta_clothes:setDefaultDressTarget', target, source)
end)