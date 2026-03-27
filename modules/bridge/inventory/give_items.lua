-----------------------------------------------------------
-- Shared server-side item giving functions
-- Integrates with MBT.PlayerState to preserve rich metadata
-----------------------------------------------------------

MBT.GiveItems = {}

local function tableContainsValue(tbl, value)
    if type(tbl) ~= "table" then return tbl == value end
    for i = 1, #tbl do
        if tbl[i] == value then return true end
    end
    return false
end

--- Build item description with optional clothing ID for admin reference
--- @param baseDesc string The base description (e.g. "Piece of clothing belonging to John")
--- @param metadata table The item metadata containing drawable/texture
--- @return string description The formatted description
local function buildDescription(baseDesc, metadata)
    if not metadata or not metadata.drawable then return baseDesc end
    local id = "ID: " .. (metadata.index or "?") .. "/" .. metadata.drawable
    if metadata.texture and metadata.texture > 0 then
        id = id .. "/" .. metadata.texture
    end
    return baseDesc .. " | " .. id
end

--- Setup global give* functions used by core/server.lua event handlers
function MBT.GiveItems.Setup(config)

    -- Expose addItem globally for use by core/server.lua (e.g. externalUndress)
    addItemToPlayer = config.addItem

    function giveDress(data)
        local player = config.getPlayer(source)
        if not player then return end
        local playerIdentity = config.getPlayerName(player)

        local storedMetadata = MBT.PlayerState.ClearSlot(source, "Drawables", data.Index)

        local metadata
        if storedMetadata then
            metadata = storedMetadata
            metadata.description = buildDescription(MBT.Labels["clothes_desc"]:format(playerIdentity), metadata)
        else
            metadata = {
                index = data.Index, sex = data.Sex,
                drawable = data.Drawable, texture = data.Texture, palette = data.Palette,
                type = "Drawable"
            }
            metadata.description = buildDescription(MBT.Labels["clothes_desc"]:format(playerIdentity), metadata)
        end

        -- Clean expired DNA before returning item to inventory
        MBT.ServerUtils.CleanExpiredDNA(metadata)

        config.addItem(config.getPlayerSource(player), data.Item, 1, metadata)
    end

    function giveDressKit(data)
        local player = config.getPlayer(source)
        if not player then return end
        local playerIdentity = config.getPlayerName(player)
        local metadata = {
            description = MBT.Labels["clothes_desc"]:format(playerIdentity),
            sex = data.Sex, type = "DressKit"
        }

        for k, v in pairs(data.Kit) do
            local storedSlot = MBT.PlayerState.ClearSlot(source, "Drawables", v.Index)
            if storedSlot then
                metadata[tostring(k)] = storedSlot
            else
                metadata[tostring(k)] = {
                    index = v.Index,
                    drawable = v.Drawable,
                    texture = v.Texture,
                    palette = v.Palette
                }
            end
        end

        Wait(100)
        config.addItem(config.getPlayerSource(player), data.Item, 1, metadata)
    end

    function giveProp(data)
        local player = config.getPlayer(source)
        if not player then return end
        local playerIdentity = config.getPlayerName(player)

        local storedMetadata = MBT.PlayerState.ClearSlot(source, "Props", data.Index)

        local metadata
        if storedMetadata then
            metadata = storedMetadata
            metadata.description = buildDescription(MBT.Labels["props_desc"]:format(playerIdentity), metadata)
        else
            metadata = {
                index = data.Index, sex = data.Sex,
                drawable = data.Drawable, texture = data.Texture,
                type = "Prop"
            }
            metadata.description = buildDescription(MBT.Labels["props_desc"]:format(playerIdentity), metadata)
        end

        -- Clean expired DNA before returning item to inventory
        MBT.ServerUtils.CleanExpiredDNA(metadata)

        config.addItem(config.getPlayerSource(player), data.Item, 1, metadata)
    end

    function giveStolenItemDress(stealSource, targetWearing, playerSex)
        local player = config.getPlayer(stealSource)
        if not player then return end
        local playerIdentity = config.getPlayerName(player)

        -- Check if torso slots (3, 8, 11) have non-default drawables → create topdress kit
        local torsoSlots = {3, 8, 11}
        local hasNonDefaultTorso = false
        local kitMetadata = {
            description = MBT.Labels["clothes_desc"]:format(playerIdentity),
            sex = playerSex, type = "DressKit"
        }
        local slotNames = {[3] = "Arms", [8] = "Tshirt", [11] = "Jacket"}

        for _, slotIdx in ipairs(torsoSlots) do
            local v = targetWearing["Drawables"][slotIdx]
            if v and MBT.Drawables[slotIdx] then
                local isDefault = tableContainsValue(MBT.Drawables[slotIdx]["Default"][playerSex], v.Drawable)
                if not isDefault then
                    hasNonDefaultTorso = true
                end
                kitMetadata[slotNames[slotIdx]] = {
                    index = slotIdx,
                    drawable = v.Drawable,
                    texture = v.Texture,
                    palette = v.Palette
                }
            end
        end

        if hasNonDefaultTorso then
            config.addItem(stealSource, "topdress", 1, kitMetadata)
        end

        -- Other drawable slots (not part of torso kit)
        for k, v in pairs(targetWearing["Drawables"]) do
            if k ~= 3 and k ~= 8 and k ~= 11 then
                if MBT.Drawables[k] and MBT.Drawables[k]["Item"] then
                    if not tableContainsValue(MBT.Drawables[k]["Default"][playerSex], v.Drawable) then
                        config.addItem(stealSource, MBT.Drawables[k]["Item"], 1, {
                            description = buildDescription(MBT.Labels["clothes_desc"]:format(playerIdentity), {index = k, drawable = v.Drawable, texture = v.Texture}),
                            index = k, sex = playerSex,
                            drawable = v.Drawable, texture = v.Texture, palette = v.Palette,
                            type = "Drawable"
                        })
                    end
                end
            end
        end

        -- Props
        for k, v in pairs(targetWearing["Props"]) do
            if MBT.Props[k] and MBT.Props[k]["Item"] then
                if not tableContainsValue(MBT.Props[k]["Default"][playerSex], v.Drawable) then
                    config.addItem(stealSource, MBT.Props[k]["Item"], 1, {
                        description = buildDescription(MBT.Labels["props_desc"]:format(playerIdentity), {index = k, drawable = v.Drawable, texture = v.Texture}),
                        index = k, sex = playerSex,
                        drawable = v.Drawable, texture = v.Texture, palette = v.Palette,
                        type = "Prop"
                    })
                end
            end
        end
    end
end
