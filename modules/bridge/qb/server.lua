if GetResourceState('qb-core') ~= 'started' then return end

QBCore = exports['qb-core']:GetCoreObject()

local isQBInventory = GetResourceState('qb-inventory'):find('start')
local isOXInventory = GetResourceState('ox_inventory'):find('start')

local Utils = loadModule('modules.utils.server')

RegisterNetEvent('mbt_meta_clothes:saveSkin', function(source, appearance)
    local identifier = getPlayerIdentifier(source)
    MySQL.update.await("UPDATE playerskins SET active = ? WHERE citizenid = ?", {0, identifier})
    MySQL.query.await("DELETE FROM playerskins WHERE citizenid = ? AND model = ?", {identifier, appearance.model})
    MySQL.insert.await("INSERT INTO playerskins (citizenid, model, skin, active) VALUES (?, ?, ?, ?)", {identifier, appearance.model, json.encode(appearance), 1})
end)

RegisterNetEvent('mbt_meta_clothes:removeWear', function(itemName)
	local Player = QBCore.Functions.GetPlayer(source)
	if not Player then return end
	Player.Functions.RemoveItem(itemName, 1)
end)

---@param data table
function giveDress(data)
    local player = QBCore.Functions.GetPlayer(source)
    if player then
        local playerIdentity = player.PlayerData.name
        if isOXInventory then exports.ox_inventory:AddItem(source, data.Item, 1 , {description = MBT.Labels["clothes_desc"]:format(playerIdentity), index = data.Index, sex = data.Sex, drawable = data.Drawable, texture = data.Texture, palette = data.Palette, type = "Drawable"}); return end
        if isQBInventory then player.Functions.AddItem(data.Item, 1, false, {description = MBT.Labels["clothes_desc"]:format(playerIdentity), index = data.Index, sex = data.Sex, drawable = data.Drawable, texture = data.Texture, palette = data.Palette, type = "Drawable"}); TriggerEvent("inventory:client:ItemBox", data, "add"); return end
        assert(type(MBT.CustomInventory) == "function", Utils.PrintWarning())
        MBT.CustomInventory(data.Item, {description = MBT.Labels["clothes_desc"]:format(playerIdentity), index = data.Index, sex = data.Sex, drawable = data.Drawable, texture = data.Texture, palette = data.Palette, type = "Drawable"})
    end
end

---@param data table
function giveDressKit(data)
    local player = QBCore.Functions.GetPlayer(source)
    if player then
        local playerIdentity = player.PlayerData.name
        local metadata = {description = MBT.Labels["clothes_desc"]:format(playerIdentity), sex = data.Sex, type = "DressKit"}

        for k,v in pairs(data.Kit) do
            metadata[tostring(k)] = {}
            metadata[tostring(k)]["index"]    = v.Index
            metadata[tostring(k)]["drawable"] = v.Drawable
            metadata[tostring(k)]["texture"]  = v.Texture
            metadata[tostring(k)]["palette"]  = v.Palette
        end

        Wait(100)
        if isOXInventory then ox_inventory:AddItem(player.PlayerData.source, data.Item, 1, metadata) return end
        if isQBInventory then player.Functions.AddItem(data.Item, 1, false, metadata); TriggerEvent("inventory:client:ItemBox", QBCore.Shared.Items[data.Item], "add"); return end
        assert(type(MBT.CustomInventory) == 'function', Utils.PrintWarning())
        MBT.CustomInventory(data.Item, metadata)
    end
end

---@param data table
function giveProp(data)
    local player = QBCore.Functions.GetPlayer(source)
    if player then
        local playerIdentity = player.PlayerData.name
        if isOXInventory then ox_inventory:AddItem(player.PlayerData.source, data.Item, 1 , {description = MBT.Labels["props_desc"]:format(playerIdentity), index = data.Index, sex = data.Sex, drawable = data.Drawable, texture = data.Texture, type ="Prop"}) return end
        if isQBInventory then player.Functions.AddItem(data.Item, 1, false, {description = MBT.Labels["props_desc"]:format(playerIdentity), index = data.Index, sex = data.Sex, drawable = data.Drawable, texture = data.Texture, type ="Prop"}); TriggerEvent("inventory:client:ItemBox", QBCore.Shared.Items[data.Item], "add"); return end
        assert(type(MBT.CustomInventory) == 'function', Utils.PrintWarning())
        MBT.CustomInventory(data.Item, {description = MBT.Labels["props_desc"]:format(playerIdentity), index = data.Index, sex = data.Sex, drawable = data.Drawable, texture = data.Texture,  type ="Prop"})
    end
end

---@param source number
---@param targetWearing table
---@param playerSex string
function giveStolenItemDress(source, targetWearing, playerSex)
    local xPlayer = QBCore.Functions.GetPlayer(source)
    local playerIdentity = player.PlayerData.name

    for k,v in pairs(targetWearing["Drawables"]) do
        if MBT.Drawables[k]["Item"] then
            if v.Drawable ~= MBT.Drawables[k]["Default"][playerSex] then
                if isOXInventory then exports.ox_inventory:AddItem(source, MBT.Drawables[k]["Item"], 1, {description = MBT.Labels["clothes_desc"]:format(playerIdentity), index = k, sex = playerSex, drawable = v.Drawable, texture = v.Texture, palette = v.Palette, type = "Drawable"}) return end
                if isQBInventory then return end -- TODO: QBInventory
                assert(type(MBT.CustomInventory) == 'function', Utils.PrintWarning())
            end
        end
    end

    for k,v in pairs(targetWearing["Props"]) do
        if MBT.Props[k]["Item"] then
            if v.Drawable ~= MBT.Props[k]["Default"][playerSex] then
                if isOXInventory then exports.ox_inventory:AddItem(source, MBT.Props[k]["Item"], 1, {description = MBT.Labels["clothes_desc"]:format(playerIdentity), index = k, sex = playerSex, drawable = v.Drawable, texture = v.Texture, palette = v.Palette, type = "Prop"}) return end
                if isQBInventory then return end -- TODO: QBInventory
                assert(type(MBT.CustomInventory) == 'function', Utils.PrintWarning())
            end
        end
    end
end

---@param source number
---@return string
function getPlayerIdentifier(source)
    local player = QBCore.Functions.GetPlayer(source)
    if player then
        return player.PlayerData.citizenid
    end
end