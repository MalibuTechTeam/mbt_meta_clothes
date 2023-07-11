local playerSex
playerWearing = { Drawables = {}, Props = {} }

local Utils = {} 

function Utils.UpdatePlayerClothes()
    local playerPed = PlayerPedId()
    for k,v in pairs(MBT.Drawables) do
        playerWearing["Drawables"][k] = GetPedDrawableVariation(playerPed, k)
    end
    
    for k,v in pairs(MBT.Props) do
        playerWearing["Props"][k] = GetPedPropIndex(playerPed, k)
    end

    SendNUIMessage({
        action = "checkPlayerClothes", 
        clothes = playerWearing, 
        defaultIndexCLothes = MBT.Drawables, 
        defaultIndexProps = MBT.Props,
        playerSex = Utils.GetPedSex(PlayerPedId())
    })
end

---@param data table
---@return boolean
function Utils.HandleTopDress(data)
    local canWear = true

    for k,v in pairs(data.index) do
        if type(v) == "table" and k ~= "Arms" then
            if not Utils.TableContainsValue({table = MBT[data.type][v.index]["Default"][data.pedSex], value = playerWearing["Drawables"][v.index]}) then
                canWear = false
                break
            end
        end
    end

    return canWear
end

---@param data table
function Utils.HandleProps(propIndex)
    local playerSex = Utils.GetPedSex(PlayerPedId()) 
    local currentProp = GetPedPropIndex(PlayerPedId(), propIndex)
    local propData = {
        Item = MBT.Props[propIndex]["Item"],
        Index = propIndex,
        Sex = playerSex,
        Drawable = currentProp,
        Texture  = GetPedPropTextureIndex(PlayerPedId(), propIndex)
    }

    if Utils.IsAbleToUndress({Type = "Props", Index = propIndex, Drawable = currentProp}) then
        Utils.SetDefaultPropVariation({
            Player = PlayerPedId(),
            Sex = playerSex,
            Index = propIndex,
            isAnimated = true
        })
        TriggerServerEvent("mbt_meta_clothes:giveProp", propData)
    else
        MBT.NotifyHandler(MBT.Labels["nothing_to_unwear"], "error")    
    end
    SendNUIMessage({action = "sendUiState", status = false})
end

function Utils.HandleTorsoUndress()
    local playerSex = Utils.GetPedSex(PlayerPedId())

    local topDressData = {
        Item = "topdress",
        Sex = playerSex,
        Kit = {
            Arms = {
                Index = 3,
                Drawable = GetPedDrawableVariation(PlayerPedId(), 3),
                Texture  = GetPedTextureVariation(PlayerPedId(), 3),
                Palette =  GetPedPaletteVariation(PlayerPedId(), 3)
            },
            Tshirt = {
                Index = 8,
                Drawable = GetPedDrawableVariation(PlayerPedId(), 8),
                Texture  = GetPedTextureVariation(PlayerPedId(), 8),
                Palette =  GetPedPaletteVariation(PlayerPedId(), 8),
                isAnimated = true
            },
            Jacket = {
                Index = 11,
                Drawable = GetPedDrawableVariation(PlayerPedId(), 11),
                Texture  = GetPedTextureVariation(PlayerPedId(), 11),
                Palette =  GetPedPaletteVariation(PlayerPedId(), 11)
            }
        }
    }

    if Utils.IsAbleToUndress({Type = "Drawables", Index = topDressData["Kit"]["Tshirt"]["Index"], Drawable = topDressData["Kit"]["Tshirt"]["Drawable"]}) then

        Utils.SetDefaultVariation({
            isAnimated = true,
            Player = PlayerPedId(),
            Sex = playerSex,
            Index = topDressData["Kit"]["Tshirt"]["Index"]
        })
        Utils.SetDefaultVariation({
            isAnimated = false,
            Player = PlayerPedId(),
            Sex = playerSex,
            Index = topDressData["Kit"]["Arms"]["Index"]
        })
        Utils.SetDefaultVariation({
            isAnimated = false,
            Player = PlayerPedId(),
            Sex = playerSex,
            Index = topDressData["Kit"]["Jacket"]["Index"]
        })
        TriggerServerEvent("mbt_meta_clothes:giveDressKit", topDressData)
    else
        MBT.NotifyHandler(MBT.Labels["nothing_to_unwear"], "error")  
    end
    SendNUIMessage({action = "sendUiState", status = false})
end

---@param data table
function Utils.HandleUndress(dressIndex)
    local playerSex = Utils.GetPedSex(PlayerPedId()) 
    local currentDrawable = GetPedDrawableVariation(PlayerPedId(), dressIndex)
    local dressData = {
        Item = MBT.Drawables[dressIndex]["Item"],
        Index = dressIndex,
        Sex = playerSex,
        Drawable = currentDrawable,
        Texture  = GetPedTextureVariation(PlayerPedId(), dressIndex),
        Palette =  GetPedPaletteVariation(PlayerPedId(), dressIndex)
    }

    if Utils.IsAbleToUndress({Type = "Drawables", Index = dressIndex, Drawable = currentDrawable}) then
        Utils.SetDefaultVariation({
            Player = PlayerPedId(),
            Sex = playerSex,
            Index = dressIndex,
            isAnimated = true
        })
        TriggerServerEvent("mbt_meta_clothes:giveDress", dressData)
    else
        MBT.NotifyHandler(MBT.Labels["nothing_to_unwear"], "error") 
    end
    SendNUIMessage({action = "sendUiState", status = false})
end

---@param data table
function Utils.IsAbleToUndress(data)
    local isAble = true
    local playerSex = Utils.GetPedSex(PlayerPedId()) 
    local isWearingDefault = Utils.TableContainsValue({table = MBT[data.Type][data.Index]["Default"][playerSex], value = data.Drawable})
    
    if Utils.IsTable(MBT[data.Type][data.Index]["Default"][playerSex]) then
        if isWearingDefault then
            if data.Index == 8 then
                local currentJacket = {Index = 11, Drawable = GetPedDrawableVariation(PlayerPedId(), 11)}
                if Utils.TableContainsValue({table = MBT[data.Type][currentJacket.Index]["Default"][playerSex], value = currentJacket.Drawable}) then -- Jacket?
                    isAble = false
                end
            else
                isAble = false
            end
        end
    end
    return isAble 
end

---@param data table
function Utils.SetDefaultVariation(data)
    local drawable = MBT.Drawables[data.Index]["Default"][data.Sex]
    if Utils.IsTable(MBT.Drawables[data.Index]["Default"][data.Sex]) then
        drawable = Utils.RandomizeDress(MBT.Drawables[data.Index]["Default"][data.Sex])
    end
    if data.isAnimated then
        Utils.PlayEmote({
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

---@param data table
function Utils.SetDefaultPropVariation(data)
    if data.isAnimated then
        Utils.PlayEmote({
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

---@param data table
---@param cb function
function Utils.PlayEmote(data, cb)
	while not HasAnimDictLoaded(data.Dict) do RequestAnimDict(data.Dict) Wait(100) end
	if IsPedInAnyVehicle(PlayerPedId()) then data.Flag = 51 end
	TaskPlayAnim(PlayerPedId(), data.Dict, data.Anim, 3.0, 3.0, data.Dur, data.Flag, 0, false, false, false)
	local Pause = data.Dur-500 if Pause < 500 then Pause = 500 end
	Wait(Pause)
	if cb then cb() end
end

---@param t table
function Utils.RandomizeDress(t)
    math.randomseed(GetGameTimer() * math.random(30123, 90456))
    return t[math.random(1, #t)]
end

---@param ped number
---@return string
function Utils.GetPedSex(ped)
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

---@param data table
function Utils.TableContainsValue(data) 
    for i = 1, #data.table do
        if data.table[i] == data.value then return true end
    end
    return false
end

---@param x table
function Utils.IsTable(x)
    return type(x) == "table" 
end

function Utils.Target()
	if MBT.Target["Active"] then
		for zId, zFunct in pairs(MBT.Target["Zones"]) do
			zFunct()
		end
    end
end

---@param dictionaries string
---@param clip string
---@param duration number
function Utils.PlayAnimation(dictionaries, clip, duration)
    local playerPed = PlayerPedId()
    if DoesEntityExist(playerPed) then
        Citizen.CreateThread(function()
            RequestAnimDict(dictionaries)
            while not HasAnimDictLoaded(dictionaries) do
                Citizen.Wait(100)
            end

			if IsEntityPlayingAnim(playerPed, dictionaries, clip, 3) then
                ClearPedSecondaryTask(playerPed)
            else
                TaskPlayAnim(playerPed, dictionaries, clip, 1.0, -1.0, duration, 8, 0, 0, 0, 0)
                RemoveAnimDict(dictionaries)
            end
        end)
    end
end

function Utils.StealAnim()
    Utils.PlayAnimation("anim@heists@load_box", "idle", 1000)
    Citizen.Wait(1000)
    Utils.PlayAnimation("anim@heists@box_carry@", "idle", 500)
    Citizen.Wait(500)
    Utils.PlayAnimation("missfam5_yoga", "start_pose", 500)
    Citizen.Wait(500)
    Utils.PlayAnimation("missbigscore2aig_7@driver", "boot_r_loop", 1000)
    Citizen.Wait(1000)
    Utils.PlayAnimation("mini@yoga", "outro_2", 1000)
    Citizen.Wait(1000)
    Utils.PlayAnimation("missbigscore2aig_7@driver", "boot_l_loop", 1000)
    Citizen.Wait(1000)
    Utils.PlayAnimation("mini@yoga", "outro_2", 1000)
    Citizen.Wait(1000)
    ClearPedTasks(PlayerPedId())
end

function Utils.MbtWearableProps()
    local resourceState = GetResourceState("mbt_wearable_props") ~= "missing"
    return resourceState
end

function Utils.MbtDebugger(...)
	if MBT.Debug then
		local arg = {...}
		local printResult = "["..GetCurrentResourceName().."] | " 
		for _,v in ipairs(arg) do
			printResult = printResult .. tostring(v) .. "\t"
		end
		printResult = printResult .. "\n"
		print(printResult)
	end
end

return Utils