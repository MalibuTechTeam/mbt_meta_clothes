if GetResourceState('es_extended') ~= 'started' then return end

ESX = exports.es_extended:getSharedObject()

local isOXInventory = GetResourceState('ox_inventory'):find('start')

RegisterNetEvent('mbt_meta_clothes:saveSkin', function(source, appearance)
    local identifier = getPlayerIdentifier(source)
    MySQL.update.await("UPDATE users SET skin = ? WHERE identifier = ?", {json.encode(appearance), identifier})
end)

function giveDress(data)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        local playerIdentity = xPlayer.getName()
        if isOXInventory then exports.ox_inventory:AddItem(xPlayer.source, data.Item, 1, {description = MBT.Labels["clothes_desc"]:format(playerIdentity), index = data.Index, sex = data.Sex, drawable = data.Drawable, texture = data.Texture, palette = data.Palette, type = "Drawable"}) end
        assert(type(MBT.CustomInventory) == "function", printWarning())
        MBT.CustomInventory(data.Item, {description = MBT.Labels["clothes_desc"]:format(playerIdentity), index = data.Index, sex = data.Sex, drawable = data.Drawable, texture = data.Texture, palette = data.Palette, type = "Drawable"})
    end
end

function giveDressKit(data)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        local playerIdentity = xPlayer.getName()
        local metadata = {description = MBT.Labels["clothes_desc"]:format(playerIdentity), sex = data.Sex, type = "DressKit"}

        for k,v in pairs(data.Kit) do
            metadata[tostring(k)] = {}
            metadata[tostring(k)]["index"]    = v.Index
            metadata[tostring(k)]["drawable"] = v.Drawable
            metadata[tostring(k)]["texture"]  = v.Texture
            metadata[tostring(k)]["palette"]  = v.Palette
        end

        Wait(100)
        if isOXInventory then exports.ox_inventory:AddItem(xPlayer.source, data.Item, 1, metadata) end
        assert(type(MBT.CustomInventory) == 'function', printWarning())
        MBT.CustomInventory(data.Item, metadata)
    end
end

function giveProp(data)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        local playerIdentity = xPlayer.getName()
        if isOXInventory then exports.ox_inventory:AddItem(xPlayer.source, data.Item, 1, {description = MBT.Labels["props_desc"]:format(playerIdentity), index = data.Index, sex = data.Sex, drawable = data.Drawable, texture = data.Texture, type ="Prop"}) end
        assert(type(MBT.CustomInventory) == 'function', printWarning())
        MBT.CustomInventory(data.Item, {description = MBT.Labels["props_desc"]:format(playerIdentity), index = data.Index, sex = data.Sex, drawable = data.Drawable, texture = data.Texture, type ="Prop"})
    end
end

function printWarning()
    print("~r~ You are using a different type of inventory, please remember to fill the custom events on the config.If you have problems contact us on Discord: https://discord.gg/tqk3kAEr4f")
    return
end

function getPlayerIdentifier(source)
	local xPlayer = ESX.GetPlayerFromId(source)
	if xPlayer then return xPlayer.identifier end
end