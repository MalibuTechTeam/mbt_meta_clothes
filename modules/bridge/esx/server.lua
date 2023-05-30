if GetResourceState('es_extended') ~= 'started' then return end

ESX = exports.es_extended:getSharedObject()

RegisterNetEvent('mbt_meta_clothes:saveSkin', function(source, appearance)
    local identifier = getPlayerIdentifier(source)
    MySQL.update.await("UPDATE users SET skin = ? WHERE identifier = ?", {json.encode(appearance), identifier})
end)

function giveDress(data)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        local playerIdentity = xPlayer.getName()
        exports.ox_inventory:AddItem(xPlayer.source, data.Item, 1, {description = MBT.Labels["clothes_desc"]:format(playerIdentity), index = data.Index, sex = data.Sex, drawable = data.Drawable, texture = data.Texture, palette = data.Palette, type = "Drawable"})
    end
end

function giveDressKit(data)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        local playerIdentity = xPlayer.getName()
        local metadata = {description = MBT.Labels["clothes_desc"]:format(playerIdentity), sex = data.Sex, type = "DressKit"}

        for k,v in pairs(data.Kit) do
            metadata[tostring(k)] = {}
            metadata[tostring(k)]["index"] = v.Index
            metadata[tostring(k)]["drawable"] = v.Drawable
            metadata[tostring(k)]["texture"]  = v.Texture
            metadata[tostring(k)]["palette"]  = v.Palette
        end

        Wait(100)
        exports.ox_inventory:AddItem(xPlayer.source, data.Item, 1, metadata)
    end
end

function giveProp(data)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        local playerIdentity = xPlayer.getName()
        exports.ox_inventory:AddItem(xPlayer.source, data.Item, 1, {description = MBT.Labels["props_desc"]:format(playerIdentity), index = data.Index, sex = data.Sex, drawable = data.Drawable, texture = data.Texture, type ="Prop"})
    end
end

function getPlayerIdentifier(source)
	local xPlayer = ESX.GetPlayerFromId(source)
	if xPlayer then return xPlayer.identifier end
end