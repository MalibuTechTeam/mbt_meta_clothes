if GetResourceState('qb-core') ~= 'started' then return end

QBCore = exports['qb-core']:GetCoreObject()

local isQBInventory = GetResourceState('qb-inventory'):find('start')
local isOXInventory = GetResourceState('ox_inventory'):find('start')

function giveDress(data)
    local xPlayer = QBCore.Functions.GetPlayer(source)
    if xPlayer then
        local playerIdentity = xPlayer.PlayerData.name
        ox_inventory:AddItem(source, data.Item, 1 , {description = currLang["clothes_desc"]:format(playerIdentity), index = data.Index, sex = data.Sex, drawable = data.Drawable, texture = data.Texture, palette = data.Palette})
    end
end

function giveDressKit(data)
    local xPlayer = QBCore.Functions.GetPlayer(source)
    if xPlayer then
        local playerIdentity = xPlayer.PlayerData.name
        local metadata = {description = currLang["clothes_desc"]:format(playerIdentity), sex = data.Sex}

        for k,v in pairs(data.Kit) do
            metadata[tostring(k)] = {}
            metadata[tostring(k)]["index"] = v.Index
            metadata[tostring(k)]["drawable"] = v.Drawable
            metadata[tostring(k)]["texture"]  = v.Texture
            metadata[tostring(k)]["palette"]  = v.Palette
        end

        Wait(100)
        ox_inventory:AddItem(source, data.Item, 1, metadata)
    end
end

function giveProp(data)
    local xPlayer = QBCore.Functions.GetPlayer(source)
    if xPlayer then
        local playerIdentity = xPlayer.PlayerData.name
        ox_inventory:AddItem(source, data.Item, 1 , {description = currLang["props_desc"]:format(playerIdentity), index = data.Index, sex = data.Sex, drawable = data.Drawable, texture = data.Texture})
    end
end