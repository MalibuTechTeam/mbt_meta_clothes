-----------------------------------------------------------
-- Shared server-side item giving functions
-- Integrates with MBT.PlayerState to preserve rich metadata
-----------------------------------------------------------

MBT.GiveItems = {}

---@param success any
---@param reason any
---@return boolean success
---@return string|nil reason
function MBT.GiveItems.NormalizeAddResult(success, reason)
    if success == true then
        return true, nil
    end
    return false, type(reason) == "string" and reason or "add_failed"
end

---@param callback function|nil
---@param src number
---@param itemName string
---@param count number
---@param metadata table
---@return boolean success
---@return string|nil reason
function MBT.GiveItems.CallCustom(callback, src, itemName, count, metadata)
    if type(callback) ~= "function" then
        return false, "unsupported_inventory"
    end

    local called, success, reason = pcall(callback, src, itemName, count, metadata)
    if not called then
        return false, "custom_error"
    end
    return MBT.GiveItems.NormalizeAddResult(success, reason)
end

--- Create a small add-before-commit coordinator.
--- The caller owns payload construction and the authoritative state commit;
--- this helper only guarantees ordering and per-logical-slot exclusion.
---@param config table
---@return table coordinator
function MBT.GiveItems.New(config)
    assert(type(config) == "table", "MBT.GiveItems.New: config must be a table")
    assert(type(config.addItem) == "function", "MBT.GiveItems.New: addItem must be a function")

    local locks = {}
    local coordinator = {}

    ---@param lockKey string
    ---@param buildPayload function
    ---@param commitState function
    ---@return table result
    function coordinator:Transfer(lockKey, buildPayload, commitState)
        if locks[lockKey] then
            return { ok = false, reason = "busy" }
        end

        locks[lockKey] = true
        local protected, result = xpcall(function()
            local payload, buildReason = buildPayload()
            if not payload then
                return { ok = false, reason = buildReason or "no_item" }
            end

            local added, addReason = config.addItem(
                payload.receiver,
                payload.itemName,
                payload.count or 1,
                payload.metadata
            )
            if added ~= true then
                return {
                    ok = false,
                    reason = addReason or "add_failed",
                    itemName = payload.itemName,
                }
            end

            local committed, committedData = commitState(payload)
            if committed ~= true then
                if config.log then
                    config.log("commit_failed", lockKey, payload.itemName)
                end
                return {
                    ok = false,
                    reason = "commit_failed",
                    itemName = payload.itemName,
                }
            end

            return {
                ok = true,
                itemName = payload.itemName,
                committed = committedData,
            }
        end, debug.traceback)

        locks[lockKey] = nil

        if protected then
            return result
        end

        if config.log then
            config.log("exception", lockKey, result)
        end
        return { ok = false, reason = "internal_error" }
    end

    ---@param src number|string
    function coordinator:CleanupSource(src)
        local prefix = tostring(src) .. ":"
        for key in pairs(locks) do
            if key:sub(1, #prefix) == prefix then
                locks[key] = nil
            end
        end
    end

    return coordinator
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
            metadata.description = buildDescription(MBT.Locale["clothes_desc"]:format(playerIdentity), metadata)
        else
            metadata = {
                index = data.Index, sex = data.Sex,
                drawable = data.Drawable, texture = data.Texture, palette = data.Palette,
                type = "Drawable"
            }
            metadata.description = buildDescription(MBT.Locale["clothes_desc"]:format(playerIdentity), metadata)
        end

        -- Clean expired DNA before returning item to inventory
        MBT.ServerUtils.CleanExpiredDNA(metadata)

        local itemName = MBT.ResolveItemName(MBT.Drawables[data.Index], metadata) or data.Item
        config.addItem(config.getPlayerSource(player), itemName, 1, metadata)
    end

    function giveDressKit(data)
        local player = config.getPlayer(source)
        if not player then return end
        local playerIdentity = config.getPlayerName(player)
        local metadata = {
            description = MBT.Locale["clothes_desc"]:format(playerIdentity),
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
            metadata.description = buildDescription(MBT.Locale["props_desc"]:format(playerIdentity), metadata)
        else
            metadata = {
                index = data.Index, sex = data.Sex,
                drawable = data.Drawable, texture = data.Texture,
                type = "Prop"
            }
            metadata.description = buildDescription(MBT.Locale["props_desc"]:format(playerIdentity), metadata)
        end

        -- Clean expired DNA before returning item to inventory
        MBT.ServerUtils.CleanExpiredDNA(metadata)

        local itemName = MBT.ResolveItemName(MBT.Props[data.Index], metadata) or data.Item
        config.addItem(config.getPlayerSource(player), itemName, 1, metadata)
    end

    function giveStolenItemDress(stealSource, targetWearing, playerSex)
        local player = config.getPlayer(stealSource)
        if not player then return end
        local playerIdentity = config.getPlayerName(player)

        -- Check if torso slots have non-default drawables → create topdress kit
        local hasNonDefaultTorso = false
        local kitMetadata = {
            description = MBT.Locale["clothes_desc"]:format(playerIdentity),
            sex = playerSex, type = "DressKit"
        }

        for _, slotIdx in ipairs(MBT.TorsoKitSlots) do
            local v = targetWearing["Drawables"][slotIdx]
            if v and MBT.Drawables[slotIdx] then
                local isDefault = MBT.TableContains(MBT.Drawables[slotIdx]["Default"][playerSex], v.Drawable)
                if not isDefault then
                    hasNonDefaultTorso = true
                end
                kitMetadata[MBT.TorsoSlotNames[slotIdx]] = {
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
            if not MBT.TableContains(MBT.TorsoKitSlots, k) then
                local slotCfg = MBT.Drawables[k]
                local itemName = MBT.ResolveItemName(slotCfg, v)
                if slotCfg and itemName then
                    if not MBT.TableContains(slotCfg["Default"][playerSex], v.Drawable) then
                        config.addItem(stealSource, itemName, 1, {
                            description = buildDescription(MBT.Locale["clothes_desc"]:format(playerIdentity), {index = k, drawable = v.Drawable, texture = v.Texture}),
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
            local slotCfg = MBT.Props[k]
            local itemName = MBT.ResolveItemName(slotCfg, v)
            if slotCfg and itemName then
                if not MBT.TableContains(slotCfg["Default"][playerSex], v.Drawable) then
                    config.addItem(stealSource, itemName, 1, {
                        description = buildDescription(MBT.Locale["props_desc"]:format(playerIdentity), {index = k, drawable = v.Drawable, texture = v.Texture}),
                        index = k, sex = playerSex,
                        drawable = v.Drawable, texture = v.Texture, palette = v.Palette,
                        type = "Prop"
                    })
                end
            end
        end
    end
end
