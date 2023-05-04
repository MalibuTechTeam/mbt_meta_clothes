
-- local isUiBusy = false

AddEventHandler('onResourceStart', function(resourceName)
	if (GetCurrentResourceName() == resourceName) then
		if NetworkIsPlayerActive(PlayerId()) then
            updatePlayerClothes()
		end
	end
end)

RegisterNUICallback('handleDress', function(data, cb)
    if data.Index == 8 then handleTorsoUndress() else handleUndress(data.Index) end
    saveOutfit()
    cb(1)
end)
 
RegisterNUICallback('handleProps', function(data, cb)
    handleProps(data.Index)
    saveOutfit()
    cb(1)
end)
 
RegisterNUICallback('exitUI', function(data, cb)
	SetNuiFocus(false, false)
    cb(1)
end)

RegisterNetEvent('mbt_metaclothes:applyDress')
AddEventHandler('mbt_metaclothes:applyDress', function(data)
    SetPedComponentVariation(cache.ped or PlayerPedId(), data.index, data.drawable, data.texture, data.palette) 
    saveOutfit() 
end)

RegisterNetEvent('mbt_metaclothes:applyKitDress')
AddEventHandler('mbt_metaclothes:applyKitDress', function(data)
    for k,v in pairs(data) do
        SetPedComponentVariation(cache.ped or PlayerPedId(), v.index, v.drawable, v.texture, v.palette)
        saveOutfit()  
    end
end)

RegisterNetEvent('mbt_metaclothes:applyProps')
AddEventHandler('mbt_metaclothes:applyProps', function(data)
    SetPedPropIndex(cache.ped or PlayerPedId(), data.index, data.drawable, data.texture, true)
    saveOutfit()  
end)

RegisterCommand("toggleUndress", function()
    if IsPedOnFoot(cache.ped or PlayerPedId()) and not IsPedDeadOrDying(cache.ped or PlayerPedId(), false) and not IsPedCuffed(cache.ped or PlayerPedId()) then
        SetNuiFocus(true, true)
        SendNUIMessage({action = "ui", status = true})
    end
end, false)

RegisterKeyMapping('toggleUndress', MBT.Labels[MBT.Language]["sett_name"], 'keyboard', MBT.MenuKey)

if MBT.Debug then
    RegisterCommand("setprop", function(source, args) 
        local propToSet = tonumber(args[1]) or 0
        local propDrawToSet = tonumber(args[2]) or 0
        print("Prop check ", propToSet)
        print("Prop check ", propDrawToSet)

        if propToSet == -1 then
            ClearPedProp(cache.ped or PlayerPedId(), 0)
        else
            SetPedPropIndex(cache.ped or PlayerPedId(), 0, propToSet, propDrawToSet, true)
        end
    end, false)

    RegisterCommand("setdraw", function(source, args) 
        local drawToSet = tonumber(args[1])
        local drawIndex = tonumber(args[2])
        local texture = tonumber(args[3]) or 0
        local palette = tonumber(args[4]) or 0
        SetPedComponentVariation(cache.ped or PlayerPedId(), drawToSet, drawIndex, texture, palette) 
    end, false)

    RegisterCommand("getdraw", function(source, args) 
        local drawToCheck = tonumber(args[1]) or 0
        print("Drawable check ", drawToCheck)
    
        print(MBT.Drawables[drawToCheck]["Label"]..": ", GetPedDrawableVariation(cache.ped or PlayerPedId(), drawToCheck))
        print("GetPedTextureVariation ", GetPedTextureVariation(cache.ped or PlayerPedId(), drawToCheck))
        print("GetPedPaletteVariation ", GetPedPaletteVariation(cache.ped or PlayerPedId(), drawToCheck))
    end, false)

    RegisterCommand("getprop", function(source, args) 
        local propToCheck = tonumber(args[1]) or 0
        print("Prop check ", propToCheck)
        
        print(MBT.Props[propToCheck]["Label"]..": ", GetPedPropIndex(cache.ped or PlayerPedId(), propToCheck))
        print("GetPedPropTextureIndex ", GetPedPropTextureIndex(cache.ped or PlayerPedId(), propToCheck))
        print("GetPedPaletteVariation ", GetPedPaletteVariation(cache.ped or PlayerPedId(), propToCheck))
    end, false)
    
    RegisterCommand("pcloth", function(source, args) 
        for k,v in pairs(playerWearing["Drawables"]) do
            print(k, v)
        end
        for k,v in pairs(playerWearing["Props"]) do
            print(k, v)
        end
    end, false)
end

