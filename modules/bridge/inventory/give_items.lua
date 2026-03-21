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
            metadata.description = MBT.Labels["clothes_desc"]:format(playerIdentity)
        else
            metadata = {
                description = MBT.Labels["clothes_desc"]:format(playerIdentity),
                index = data.Index, sex = data.Sex,
                drawable = data.Drawable, texture = data.Texture, palette = data.Palette,
                type = "Drawable"
            }
        end

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
            MBT.ServerUtils.MbtDebugger("  giveDressKit: clearing slot", k, "index:", v.Index)
            local storedSlot = MBT.PlayerState.ClearSlot(source, "Drawables", v.Index)
            MBT.ServerUtils.MbtDebugger("    storedSlot:", storedSlot and json.encode(storedSlot) or "NIL")
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
            metadata.description = MBT.Labels["props_desc"]:format(playerIdentity)
        else
            metadata = {
                description = MBT.Labels["props_desc"]:format(playerIdentity),
                index = data.Index, sex = data.Sex,
                drawable = data.Drawable, texture = data.Texture,
                type = "Prop"
            }
        end

        config.addItem(config.getPlayerSource(player), data.Item, 1, metadata)
    end

    function giveStolenItemDress(stealSource, targetWearing, playerSex)
        local player = config.getPlayer(stealSource)
        if not player then return end
        local playerIdentity = config.getPlayerName(player)

        for k, v in pairs(targetWearing["Drawables"]) do
            if MBT.Drawables[k] and MBT.Drawables[k]["Item"] then
                if not tableContainsValue(MBT.Drawables[k]["Default"][playerSex], v.Drawable) then
                    config.addItem(stealSource, MBT.Drawables[k]["Item"], 1, {
                        description = MBT.Labels["clothes_desc"]:format(playerIdentity),
                        index = k, sex = playerSex,
                        drawable = v.Drawable, texture = v.Texture, palette = v.Palette,
                        type = "Drawable"
                    })
                end
            end
        end

        for k, v in pairs(targetWearing["Props"]) do
            if MBT.Props[k] and MBT.Props[k]["Item"] then
                if not tableContainsValue(MBT.Props[k]["Default"][playerSex], v.Drawable) then
                    config.addItem(stealSource, MBT.Props[k]["Item"], 1, {
                        description = MBT.Labels["props_desc"]:format(playerIdentity),
                        index = k, sex = playerSex,
                        drawable = v.Drawable, texture = v.Texture, palette = v.Palette,
                        type = "Prop"
                    })
                end
            end
        end
    end
end
