if GetResourceState('ox_core') ~= 'started' then return end

local file = ('imports/%s.lua'):format(IsDuplicityVersion() and 'server' or 'client')
local import = LoadResourceFile('ox_core', file)
local chunk = assert(load(import, ('@@ox_core/%s'):format(file)))
chunk()

local ox_inventory = exports.ox_inventory

function giveDress(data)
    local xPlayer = Ox.GetPlayer(source)
    if xPlayer then
        local playerIdentity = xPlayer.name
        ox_inventory:AddItem(xPlayer.source, data.Item, 1 , {description = currLang["clothes_desc"]:format(playerIdentity), index = data.Index, sex = data.Sex, drawable = data.Drawable, texture = data.Texture, palette = data.Palette})
    end
end

function giveDressKit(data)
    local xPlayer = Ox.GetPlayer(source)
    if xPlayer then
        local playerIdentity = xPlayer.name
        local metadata = {description = currLang["clothes_desc"]:format(playerIdentity), sex = data.Sex}

        for k,v in pairs(data.Kit) do
            metadata[tostring(k)] = {}
            metadata[tostring(k)]["index"] = v.Index
            metadata[tostring(k)]["drawable"] = v.Drawable
            metadata[tostring(k)]["texture"]  = v.Texture
            metadata[tostring(k)]["palette"]  = v.Palette
        end

        Wait(100)
        ox_inventory:AddItem(xPlayer.source, data.Item, 1, metadata)
    end
end

function giveProp(data)
    local xPlayer = Ox.GetPlayer(source)
    if xPlayer then
        local playerIdentity = xPlayer.name
        ox_inventory:AddItem(xPlayer.source, data.Item, 1 , {description = currLang["props_desc"]:format(playerIdentity), index = data.Index, sex = data.Sex, drawable = data.Drawable, texture = data.Texture})
    end
end