local ox_appearance = GetResourceState('ox_appearance'):find('start')
local fivem_appearance = GetResourceState('fivem_appearance'):find('start')
local qb_clothing = GetResourceState('qb-clothing'):find('start')

local mbt_inventory  = exports["ox_inventory"]
local currLang = MBT.Labels[MBT.Language]
local playerSex
local isUiBusy = false

if MBT.Framework == 'ESX' then
    ESX = exports['es_extended']:getSharedObject()
elseif MBT.Framework == 'QB' then
    QBCore = exports['qb-core']:GetCoreObject()
elseif MBT.Framework == 'OX' then
    local file = ('imports/%s.lua'):format(IsDuplicityVersion() and 'server' or 'client')
    local import = LoadResourceFile('ox_core', file)
    local chunk = assert(load(import, ('@@ox_core/%s'):format(file)))
    chunk()
end

RegisterNUICallback('handleDress', function(data, cb)
    if data.Index == 8 then handleTorsoUndress() else handleUndress(data.Index) end
    saveOutfitCache()
    cb(1)
end)
 
RegisterNUICallback('handleProps', function(data, cb)
    handleProps(data.Index)
    saveOutfitCache()
    cb(1)
end)
 
RegisterNUICallback('exitUI', function(data, cb)
	SetNuiFocus(false, false)
    cb(1)
end)

RegisterNetEvent('mbt_metaclothes:applyDress')
AddEventHandler('mbt_metaclothes:applyDress', function(data)
    SetPedComponentVariation(cache.ped or PlayerPedId(), data.index, data.drawable, data.texture, data.palette) 
end)

RegisterNetEvent('mbt_metaclothes:applyKitDress')
AddEventHandler('mbt_metaclothes:applyKitDress', function(data)
    for k,v in pairs(data) do
        SetPedComponentVariation(cache.ped or PlayerPedId(), v.index, v.drawable, v.texture, v.palette) 
    end
end)

RegisterNetEvent('mbt_metaclothes:applyProps')
AddEventHandler('mbt_metaclothes:applyProps', function(data)
    SetPedPropIndex(cache.ped or PlayerPedId(), data.index, data.drawable, data.texture, true) 
end)

function saveOutfitCache()
    local appearance = exports['fivem-appearance']:getPedAppearance(cache.ped)
    if ox_appearance then
        TriggerServerEvent('ox_appearance:save', appearance)
    elseif fivem_appearance and MBT.Framework == 'ESX' then
        TriggerServerEvent('esx_skin:save', appearance)
    elseif qb_clothing and MBT.Framework == 'QB' then
        -- IMPLEMENT HERE LOGIC FOR SAVE CLOTHING FOR QBCore
    end
end

function handleProps(propIndex)
    local playerSex = getPedSex(cache.ped or PlayerPedId()) 
    local currentProp = GetPedPropIndex(cache.ped or PlayerPedId(), propIndex)
    local propData = {
        Item = MBT.Props[propIndex]["Item"],
        Index = propIndex,
        Sex = playerSex,
        Drawable = currentProp,
        Texture  = GetPedPropTextureIndex(cache.ped or PlayerPedId(), propIndex)
    }

    if isAbleToUndress({Type = "Props", Index = propIndex, Drawable = currentProp}) then
        setDefaultPropVariation({
            Player = cache.ped or PlayerPedId(),
            Sex = playerSex,
            Index = propIndex,
            isAnimated = true
        })
        TriggerServerEvent("mbt_metaclothes:giveProp", propData)
    else
        MBT.NotifyHandler(currLang["nothing_to_unwear"], "error")    
    end
    SendNUIMessage({action = "sendUiState", status = false})
end

function handleTorsoUndress()
    local playerSex = getPedSex(cache.ped or PlayerPedId()) 
    local Arms = {Index = 3, Drawable = GetPedDrawableVariation(cache.ped or PlayerPedId(), 3)}
    local Tshirt = {Index = 8, Drawable = GetPedDrawableVariation(cache.ped or PlayerPedId(), 8)}
    local Jacket = {Index = 11, Drawable = GetPedDrawableVariation(cache.ped or PlayerPedId(), 11)}

    local topDressData = {
        Item = "topdress",
        Sex = playerSex,
        Kit = {
            Arms = {
                Index = Arms.Index,
                Drawable = Arms.Drawable,
                Texture  = GetPedTextureVariation(cache.ped or PlayerPedId(), Arms.Index),
                Palette =  GetPedPaletteVariation(cache.ped or PlayerPedId(), Arms.Index)
            },
            Tshirt = {
                Index = Tshirt.Index,
                Drawable = Tshirt.Drawable,
                Texture  = GetPedTextureVariation(cache.ped or PlayerPedId(), Tshirt.Index),
                Palette =  GetPedPaletteVariation(cache.ped or PlayerPedId(), Tshirt.Index)
            },
            Jacket = {
                Index = Jacket.Index,
                Drawable = Jacket.Drawable,
                Texture  = GetPedTextureVariation(cache.ped or PlayerPedId(), Jacket.Index),
                Palette =  GetPedPaletteVariation(cache.ped or PlayerPedId(), Jacket.Index)
            }
        }
    }

    if isAbleToUndress({Type = "Drawables", Index = Tshirt.Index, Drawable = Tshirt.Drawable}) then
        setDefaultVariation({
            isAnimated = true,
            Player = cache.ped or PlayerPedId(),
            Sex = playerSex,
            Index = Tshirt.Index
        })
        setDefaultVariation({
            isAnimated = false,
            Player = cache.ped or PlayerPedId(),
            Sex = playerSex,
            Index = Arms.Index
        })
        setDefaultVariation({
            isAnimated = false,
            Player = cache.ped or PlayerPedId(),
            Sex = playerSex,
            Index = Jacket.Index
        })
        TriggerServerEvent("mbt_metaclothes:giveDressKit", topDressData)
    else
        MBT.NotifyHandler(currLang["nothing_to_unwear"], "error")  
    end
    SendNUIMessage({action = "sendUiState", status = false})
end

function handleUndress(dressIndex)
    local playerSex = getPedSex(cache.ped or PlayerPedId()) 
    local currentDrawable = GetPedDrawableVariation(cache.ped or PlayerPedId(), dressIndex)
    local dressData = {
        Item = MBT.Drawables[dressIndex]["Item"],
        Index = dressIndex,
        Sex = playerSex,
        Drawable = currentDrawable,
        Texture  = GetPedTextureVariation(cache.ped or PlayerPedId(), dressIndex),
        Palette =  GetPedPaletteVariation(cache.ped or PlayerPedId(), dressIndex)
    }

    if isAbleToUndress({Type = "Drawables", Index = dressIndex, Drawable = currentDrawable}) then
        setDefaultVariation({
            Player = cache.ped or PlayerPedId(),
            Sex = playerSex,
            Index = dressIndex,
            isAnimated = true
        })
        TriggerServerEvent("mbt_metaclothes:giveDress", dressData)
    else
        MBT.NotifyHandler(currLang["nothing_to_unwear"], "error") 
    end
    SendNUIMessage({action = "sendUiState", status = false})
end

function isAbleToUndress(data)
    local isAble = true
    local playerSex = getPedSex(cache.ped or PlayerPedId()) 
    local isWearingDefault = tableContainsValue({table = MBT[data.Type][data.Index]["Default"][playerSex], value = data.Drawable})
    
    if isTable(MBT[data.Type][data.Index]["Default"][playerSex]) then
        if isWearingDefault then
            if data.Index == 8 then
                local currentJacket = {Index = 11, Drawable = GetPedDrawableVariation(cache.ped or PlayerPedId(), 11)}
                if tableContainsValue({table = MBT[data.Type][currentJacket.Index]["Default"][playerSex], value = currentJacket.Drawable}) then -- Jacket?
                    isAble = false
                end
            else
                isAble = false
            end
        end
    end
    return isAble 
end

function setDefaultVariation(data)
    local drawable = MBT.Drawables[data.Index]["Default"][data.Sex]
    if isTable(MBT.Drawables[data.Index]["Default"][data.Sex]) then
        drawable = randomizeDress(MBT.Drawables[data.Index]["Default"][data.Sex])
    end
    if data.isAnimated then
        playEmote({
            Dict = MBT.Drawables[data.Index]["Animation"]["Dict"],
            Anim = MBT.Drawables[data.Index]["Animation"]["Anim"],
            Flag = MBT.Drawables[data.Index]["Animation"]["Flag"],
            Dur = MBT.Drawables[data.Index]["Animation"]["Duration"]
        }, function()
            SetPedComponentVariation(data.Player, data.Index, drawable, 0, 0)
        end)
    else
        SetPedComponentVariation(data.Player, data.Index, drawable, 0, 0)
    end
end

function setDefaultPropVariation (data)
    if data.isAnimated then
        playEmote({
            Dict = MBT.Props[data.Index]["Animation"]["Dict"],
            Anim = MBT.Props[data.Index]["Animation"]["Anim"],
            Flag = MBT.Props[data.Index]["Animation"]["Flag"],
            Dur = MBT.Props[data.Index]["Animation"]["Duration"]
        }, function()
            ClearPedProp(data.Player, data.Index)
        end)
    else
        ClearPedProp(data.Player, data.Index)
    end
end

function playEmote(data, cb)
	while not HasAnimDictLoaded(data.Dict) do RequestAnimDict(data.Dict) Wait(100) end
	if IsPedInAnyVehicle(cache.ped or PlayerPedId()) then data.Flag = 51 end
	TaskPlayAnim(cache.ped or PlayerPedId(), data.Dict, data.Anim, 3.0, 3.0, data.Dur, data.Flag, 0, false, false, false)
	local Pause = data.Dur-500 if Pause < 500 then Pause = 500 end
	Wait(Pause)
	if cb then cb() end
end

function randomizeDress(t)
    math.randomseed(GetGameTimer() * math.random(30123, 90456))
    return t[math.random(1, #t)]
end

function getPedSex(ped)
    local maleModel, femaleModel = `mp_m_freemode_01`, `mp_f_freemode_01`
    local playerModel = GetEntityModel(ped)
    if playerModel then
        if playerModel == maleModel then 
            return "male" 
        elseif playerModel == femaleModel then
            return "female"
        else  
            return "customSkin"
        end
    end
end

function tableContainsValue(data) 
    for i = 1, #data.table do
        if data.table[i] == data.value then return true end
    end
    return false
end

function isTable(x)
    return type(x) == "table" 
end

RegisterCommand("toggleUndress", function()
    if IsPedOnFoot(cache.ped or PlayerPedId()) and not IsPedDeadOrDying(cache.ped or PlayerPedId(), false) and not IsPedCuffed(cache.ped or PlayerPedId()) then
        SetNuiFocus(true, true)
        SendNUIMessage({action = "ui", status = true})
    end
end, false)

RegisterKeyMapping('toggleUndress', currLang["sett_name"], 'keyboard', MBT.MenuKey)

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
end

