if GetResourceState('ox_core') ~= 'started' then return end

local file = ('imports/%s.lua'):format(IsDuplicityVersion() and 'server' or 'client')
local import = LoadResourceFile('ox_core', file)
local chunk = assert(load(import, ('@@ox_core/%s'):format(file)))
chunk()

local Utils = loadModule('modules.utils.server')

---@param data table
function giveDress(data)
    local xPlayer = Ox.GetPlayer(source)
    if xPlayer then
        local playerIdentity = xPlayer.name
        exports.ox_inventory:AddItem(xPlayer.source, data.Item, 1 , {description = MBT.Labels["clothes_desc"]:format(playerIdentity), index = data.Index, sex = data.Sex, drawable = data.Drawable, texture = data.Texture, palette = data.Palette, type = "Drawable"})
    end
end

---@param data table
function giveDressKit(data)
    local xPlayer = Ox.GetPlayer(source)
    if xPlayer then
        local playerIdentity = xPlayer.name
        local metadata = {description = MBT.Labels["clothes_desc"]:format(playerIdentity), sex = data.Sex, type = "DressKit"}

        for k,v in pairs(data.Kit) do
            metadata[tostring(k)] = {}
            metadata[tostring(k)]["index"]    = v.Index
            metadata[tostring(k)]["drawable"] = v.Drawable
            metadata[tostring(k)]["texture"]  = v.Texture
            metadata[tostring(k)]["palette"]  = v.Palette
        end

        Wait(100)
        exports.ox_inventory:AddItem(xPlayer.source, data.Item, 1, metadata)
    end
end

---@param data table
function giveProp(data)
    local xPlayer = Ox.GetPlayer(source)
    if xPlayer then
        local playerIdentity = xPlayer.name
        exports.ox_inventory:AddItem(xPlayer.source, data.Item, 1 , {description = MBT.Labels["props_desc"]:format(playerIdentity), index = data.Index, sex = data.Sex, drawable = data.Drawable, texture = data.Texture, type ="Prop"})
    end
end

---@param source number
---@param targetWearing table
---@param playerSex string
function giveStolenItemDress(source, targetWearing, playerSex)
    local xPlayer = Ox.GetPlayer(source)
    local playerIdentity = xPlayer.get('name')

    for k,v in pairs(targetWearing["Drawables"]) do
        if MBT.Drawables[k]["Item"] then
            if v.Drawable ~= MBT.Drawables[k]["Default"][playerSex] then
                exports.ox_inventory:AddItem(source, MBT.Drawables[k]["Item"], 1, {description = MBT.Labels["clothes_desc"]:format(playerIdentity), index = k, sex = playerSex, drawable = v.Drawable, texture = v.Texture, palette = v.Palette, type = "Drawable"})
            end
        end
    end

    for k,v in pairs(targetWearing["Props"]) do
        if MBT.Props[k]["Item"] then
            if v.Drawable ~= MBT.Props[k]["Default"][playerSex] then
                exports.ox_inventory:AddItem(source, MBT.Props[k]["Item"], 1, {description = MBT.Labels["clothes_desc"]:format(playerIdentity), index = k, sex = playerSex, drawable = v.Drawable, texture = v.Texture, palette = v.Palette, type = "Prop"})
            end
        end
    end
end