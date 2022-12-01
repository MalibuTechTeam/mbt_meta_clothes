local ox_inventory = exports.ox_inventory
local currLang = MBT.Labels[MBT.Language]

RegisterServerEvent('mbt_metaclothes:giveDress')
AddEventHandler('mbt_metaclothes:giveDress', function(data)
    local _source = source
    local xPlayer = (MBT.Framework == "OX" and Ox.GetPlayer(_source)) or (MBT.Framework == "ESX" and ESX.GetPlayerFromId(_source)) or (MBT.Framework == "QB" and QBCore.Functions.GetPlayer(_source))
    if xPlayer then
        local playerIdentity = (MBT.Framework == "OX" and xPlayer.name) or (MBT.Framework == "ESX" and xPlayer.getName()) or (MBT.Framework == "QB" and xPlayer.PlayerData.name) 
        ox_inventory:AddItem(_source, data.Item, 1 , {description = currLang["clothes_desc"]:format(playerIdentity), index = data.Index, sex = data.Sex, drawable = data.Drawable, texture = data.Texture, palette = data.Palette})
    end
end)

RegisterServerEvent('mbt_metaclothes:giveDressKit')
AddEventHandler('mbt_metaclothes:giveDressKit', function(data)
    local _source = source
    local xPlayer = (MBT.Framework == "OX" and Ox.GetPlayer(_source)) or (MBT.Framework == "ESX" and ESX.GetPlayerFromId(_source)) or (MBT.Framework == "QB" and QBCore.Functions.GetPlayer(_source))

    if xPlayer then
        local playerIdentity = (MBT.Framework == "OX" and xPlayer.name) or (MBT.Framework == "ESX" and xPlayer.getName()) or (MBT.Framework == "QB" and xPlayer.PlayerData.name) 
        local metadata = {description = currLang["clothes_desc"]:format(playerIdentity), sex = data.Sex}

        for k,v in pairs(data.Kit) do
            metadata[tostring(k)] = {}
            metadata[tostring(k)]["index"] = v.Index
            metadata[tostring(k)]["drawable"] = v.Drawable
            metadata[tostring(k)]["texture"]  = v.Texture
            metadata[tostring(k)]["palette"]  = v.Palette
        end

        Wait(100)
        ox_inventory:AddItem(_source, data.Item, 1, metadata)
    end

end)

RegisterServerEvent('mbt_metaclothes:giveProp')
AddEventHandler('mbt_metaclothes:giveProp', function(data)
    local _source = source

    local xPlayer = (MBT.Framework == "OX" and Ox.GetPlayer(_source)) or (MBT.Framework == "ESX" and ESX.GetPlayerFromId(_source)) or (MBT.Framework == "QB" and QBCore.Functions.GetPlayer(_source))

    if xPlayer then
        local playerIdentity = (MBT.Framework == "OX" and xPlayer.name) or (MBT.Framework == "ESX" and xPlayer.getName()) or (MBT.Framework == "QB" and xPlayer.PlayerData.name) 
        ox_inventory:AddItem(_source, data.Item, 1 , {description = currLang["props_desc"]:format(playerIdentity), index = data.Index, sex = data.Sex, drawable = data.Drawable, texture = data.Texture})
    end

end)