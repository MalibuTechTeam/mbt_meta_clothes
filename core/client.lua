local Utils = loadModule('modules.utils.client')

AddEventHandler('onResourceStart', function(resourceName)
	if (GetCurrentResourceName() == resourceName) then
		if NetworkIsPlayerActive(PlayerId()) then
            Utils.UpdatePlayerClothes()
            Utils.Target()
		end
	end
end)

RegisterNUICallback('handleDress', function(data, cb)
    if data.Index == 8 then Utils.HandleTorsoUndress() else Utils.HandleUndress(data.Index) end
    saveOutfit()
    cb(1)
end)

RegisterNUICallback('handleProps', function(data, cb)
    Utils.HandleProps(data.Index)
    saveOutfit()
    cb(1)
end)

RegisterNUICallback('exitUI', function(data, cb)
	SetNuiFocus(false, false)
    cb(1)
end)

RegisterNetEvent('mbt_meta_clothes:applyDress')
AddEventHandler('mbt_meta_clothes:applyDress', function(data)
    SetPedComponentVariation(PlayerPedId(), data.index, data.drawable, data.texture, data.palette)
    SendNUIMessage({action = "applyDress", indexDress = data.index}) 
    saveOutfit() 
end)

RegisterNetEvent('mbt_meta_clothes:applyKitDress')
AddEventHandler('mbt_meta_clothes:applyKitDress', function(data)
    for k,v in pairs(data) do
        SetPedComponentVariation(PlayerPedId(), v.index, v.drawable, v.texture, v.palette)
    end
    SendNUIMessage({action = "applyDress", indexDress = 8})
    saveOutfit()  
end)

RegisterNetEvent('mbt_meta_clothes:applyProps')
AddEventHandler('mbt_meta_clothes:applyProps', function(data)
    SetPedPropIndex(PlayerPedId(), data.index, data.drawable, data.texture, true)
    SendNUIMessage({action = "applyProps", indexProp = data.index}) 
    saveOutfit()  
end)

RegisterNetEvent('mbt_meta_clothes:stealPlayerDress')
AddEventHandler('mbt_meta_clothes:stealPlayerDress', function(data)
    stealPlayerDress(data)
end, false)

RegisterNetEvent('mbt_meta_clothes:setDefaultDressTarget')
AddEventHandler('mbt_meta_clothes:setDefaultDressTarget', function(stealingPlayer)
	local playerPed = PlayerPedId()
	local stealingPed = GetPlayerPed(GetPlayerFromServerId(stealingPlayer))
    local playerSex = Utils.GetPedSex(playerPed)
    local targetWearing = {Drawables = {}, Props = {}}

    for k,v in pairs(MBT.Drawables) do
        targetWearing["Drawables"][k] = {Drawable = GetPedDrawableVariation(playerPed, k), Texture = GetPedTextureVariation(playerPed, k), Palette = GetPedPaletteVariation(playerPed, k)}
        SetPedComponentVariation(playerPed, k, MBT.Drawables[k]["Default"][playerSex][1], 0, 0)
    end
    
    for k,v in pairs(MBT.Props) do
        targetWearing["Props"][k] = {Drawable = GetPedPropIndex(playerPed, k), Texture = GetPedPropTextureIndex(playerPed, k), Palette = 0}
        SetPedPropIndex(playerPed, k, MBT.Props[k]["Default"][playerSex][1], 0, 0)
    end

    TriggerServerEvent('mbt_meta_clothes:giveStolenItemDress', stealingPlayer, targetWearing, playerSex)
end)

RegisterCommand("toggleUndress", function()
    if IsPedOnFoot(PlayerPedId()) and not IsPedDeadOrDying(PlayerPedId(), false) and not IsPedCuffed(PlayerPedId()) then
        local bagState = checkBagState()
        local maskState = checkMaskState()
        local armorState = checkArmorState()
        local resourceState = Utils.MbtWearableProps()

        SetNuiFocus(true, true)
        SendNUIMessage({action = "ui", status = true, mask = maskState, bag = bagState, armor = armorState, wearableProps = resourceState})
    end
end, false)

RegisterKeyMapping('toggleUndress', MBT.Labels["sett_name"], 'keyboard', MBT.MenuKey)