if GetResourceState('es_extended') ~= 'started' then return end

ESX = exports.es_extended:getSharedObject()

local isOXInventory = GetResourceState('ox_inventory'):find('start')

local Utils = loadModule('modules.utils.server')

RegisterNetEvent('mbt_meta_clothes:saveSkin', function(source, appearance)
    local identifier = getPlayerIdentifier(source)
    MySQL.update.await("UPDATE users SET skin = ? WHERE identifier = ?", {json.encode(appearance), identifier})
end)

---@param data table
function giveDress(data)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        local playerIdentity = xPlayer.getName()
        if isOXInventory then exports.ox_inventory:AddItem(xPlayer.source, data.Item, 1, {description = MBT.Labels["clothes_desc"]:format(playerIdentity), index = data.Index, sex = data.Sex, drawable = data.Drawable, texture = data.Texture, palette = data.Palette, type = "Drawable"}) return end
        assert(type(MBT.CustomInventory) == "function", Utils.PrintWarning())
        MBT.CustomInventory(data.Item, {description = MBT.Labels["clothes_desc"]:format(playerIdentity), index = data.Index, sex = data.Sex, drawable = data.Drawable, texture = data.Texture, palette = data.Palette, type = "Drawable"})
    end
end

---@param data table
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
        if isOXInventory then exports.ox_inventory:AddItem(xPlayer.source, data.Item, 1, metadata) return end
        assert(type(MBT.CustomInventory) == 'function', Utils.PrintWarning())
        MBT.CustomInventory(data.Item, metadata)
    end
end

---@param data table
function giveProp(data)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        local playerIdentity = xPlayer.getName()
        if isOXInventory then exports.ox_inventory:AddItem(xPlayer.source, data.Item, 1, {description = MBT.Labels["props_desc"]:format(playerIdentity), index = data.Index, sex = data.Sex, drawable = data.Drawable, texture = data.Texture, type ="Prop"}) return end
        assert(type(MBT.CustomInventory) == 'function', Utils.PrintWarning())
        MBT.CustomInventory(data.Item, {description = MBT.Labels["props_desc"]:format(playerIdentity), index = data.Index, sex = data.Sex, drawable = data.Drawable, texture = data.Texture, type ="Prop"})
    end
end

---@param source number
---@param targetWearing table
---@param playerSex string
function giveStolenItemDress(source, targetWearing, playerSex)
    local xPlayer = ESX.GetPlayerFromId(source)
    local playerIdentity = xPlayer.getName()

    for k,v in pairs(targetWearing["Drawables"]) do
        if MBT.Drawables[k]["Item"] then
            if v.Drawable ~= MBT.Drawables[k]["Default"][playerSex] then
                if isOXInventory then exports.ox_inventory:AddItem(source, MBT.Drawables[k]["Item"], 1, {description = MBT.Labels["clothes_desc"]:format(playerIdentity), index = k, sex = playerSex, drawable = v.Drawable, texture = v.Texture, palette = v.Palette, type = "Drawable"}) return end
                assert(type(MBT.CustomInventory) == 'function', Utils.PrintWarning())
            end
        end
    end

    for k,v in pairs(targetWearing["Props"]) do
        if MBT.Props[k]["Item"] then
            if v.Drawable ~= MBT.Props[k]["Default"][playerSex] then
                if isOXInventory then exports.ox_inventory:AddItem(source, MBT.Props[k]["Item"], 1, {description = MBT.Labels["clothes_desc"]:format(playerIdentity), index = k, sex = playerSex, drawable = v.Drawable, texture = v.Texture, palette = v.Palette, type = "Prop"}) return end
                assert(type(MBT.CustomInventory) == 'function', Utils.PrintWarning())
            end
        end
    end
end

---@param source number
function getPlayerIdentifier(source)
	local xPlayer = ESX.GetPlayerFromId(source)
	if xPlayer then return xPlayer.identifier end
end