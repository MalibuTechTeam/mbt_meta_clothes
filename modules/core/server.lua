local playerSkins = {}

RegisterNetEvent('mbt_meta_clothes:giveDress', function(data)
    giveDress(data)
end)

RegisterNetEvent('mbt_meta_clothes:giveDressKit', function(data)
    giveDressKit(data)
end)

RegisterNetEvent('mbt_meta_clothes:giveProp', function(data)
    giveProp(data)
end)

RegisterNetEvent('mbt_meta_clothes:storePlayerSkin', function(appearance)
    playerSkins[source] = appearance
end)

AddEventHandler('playerDropped', function(reason)
    if playerSkins[source] then
        TriggerEvent('mbt_meta_clothes:saveSkin', source, playerSkins[source])
    end
end)