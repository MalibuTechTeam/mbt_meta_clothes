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

local function cloneTable(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end

    local copy = {}
    seen[value] = copy
    for key, entry in pairs(value) do
        copy[cloneTable(key, seen)] = cloneTable(entry, seen)
    end
    return copy
end

---@param config table
---@return table runtime
function MBT.GiveItems.NewRuntime(config)
    local playerState = config.PlayerState or MBT.PlayerState
    local drawables = config.Drawables or MBT.Drawables
    local props = config.Props or MBT.Props
    local torsoSlots = config.TorsoKitSlots or MBT.TorsoKitSlots
    local torsoNames = config.TorsoSlotNames or MBT.TorsoSlotNames
    local resolveItemName = config.resolveItemName or MBT.ResolveItemName
    local cleanExpiredDNA = config.cleanExpiredDNA or MBT.ServerUtils.CleanExpiredDNA
    local clothesDescription = config.clothesDescription or MBT.Locale["clothes_desc"]
    local propsDescription = config.propsDescription or MBT.Locale["props_desc"]
    local coordinator = MBT.GiveItems.New({
        addItem = config.addItem,
        log = config.log,
    })
    local runtime = {}

    local function getIdentity(src)
        local player = config.getPlayer(src)
        if not player then return nil end
        return player, config.getPlayerName(player), config.getPlayerSource(player)
    end

    ---@param ownerSrc number
    ---@param receiverSrc number
    ---@param slotType string
    ---@param slotIndex number
    ---@return table result
    function runtime:TransferSlot(ownerSrc, receiverSrc, slotType, slotIndex)
        local slotConfig = slotType == "Drawables" and drawables[slotIndex] or props[slotIndex]
        if not slotConfig then return { ok = false, reason = "invalid_slot" } end

        local _, playerIdentity, resolvedReceiver = getIdentity(receiverSrc)
        if not playerIdentity then return { ok = false, reason = "invalid_player" } end
        receiverSrc = resolvedReceiver

        local lockKey = ("%s:%s:%s"):format(ownerSrc, slotType, slotIndex)
        local original
        return coordinator:Transfer(lockKey, function()
            original = playerState.GetSlot(ownerSrc, slotType, slotIndex)
            if not original then return nil, "no_item" end

            local metadata = cloneTable(original)
            local descriptionFormat = slotType == "Drawables" and clothesDescription or propsDescription
            metadata.description = buildDescription(descriptionFormat:format(playerIdentity), metadata)
            cleanExpiredDNA(metadata)

            local itemName = resolveItemName(slotConfig, metadata)
            if not itemName then return nil, "invalid_item" end
            return {
                receiver = receiverSrc,
                itemName = itemName,
                count = 1,
                metadata = metadata,
            }
        end, function()
            if playerState.GetSlot(ownerSrc, slotType, slotIndex) ~= original then
                return false
            end
            local cleared = playerState.ClearSlot(ownerSrc, slotType, slotIndex)
            return cleared ~= nil, { slotType = slotType, slotIndex = slotIndex }
        end)
    end

    ---@param src number
    ---@param slotType string
    ---@param slotIndex number
    ---@return table result
    function runtime:ReturnSlot(src, slotType, slotIndex)
        return self:TransferSlot(src, src, slotType, slotIndex)
    end

    ---@param ownerSrc number
    ---@param receiverSrc number
    ---@return table result
    function runtime:TransferTorso(ownerSrc, receiverSrc)
        local _, playerIdentity, resolvedReceiver = getIdentity(receiverSrc)
        if not playerIdentity then return { ok = false, reason = "invalid_player" } end
        receiverSrc = resolvedReceiver

        local lockKey = ("%s:torso"):format(ownerSrc)
        local originals = {}
        return coordinator:Transfer(lockKey, function()
            local metadata = {
                description = clothesDescription:format(playerIdentity),
                type = "DressKit",
            }
            local found = false

            for _, slotIndex in ipairs(torsoSlots) do
                local stored = playerState.GetSlot(ownerSrc, "Drawables", slotIndex)
                originals[slotIndex] = stored
                if stored then
                    found = true
                    local slotMetadata = cloneTable(stored)
                    metadata[torsoNames[slotIndex]] = slotMetadata
                    metadata.sex = metadata.sex or slotMetadata.sex
                end
            end

            if not found then return nil, "no_item" end
            cleanExpiredDNA(metadata)
            return {
                receiver = receiverSrc,
                itemName = "topdress",
                count = 1,
                metadata = metadata,
            }
        end, function()
            for _, slotIndex in ipairs(torsoSlots) do
                if playerState.GetSlot(ownerSrc, "Drawables", slotIndex) ~= originals[slotIndex] then
                    return false
                end
            end

            local committed = {}
            for _, slotIndex in ipairs(torsoSlots) do
                if originals[slotIndex] then
                    playerState.ClearSlot(ownerSrc, "Drawables", slotIndex)
                    committed[#committed + 1] = {
                        slotType = "Drawables",
                        slotIndex = slotIndex,
                    }
                end
            end
            return true, committed
        end)
    end

    ---@param src number
    ---@return table result
    function runtime:ReturnTorso(src)
        return self:TransferTorso(src, src)
    end

    function runtime:CleanupSource(src)
        coordinator:CleanupSource(src)
    end

    return runtime
end

--- Setup global give* functions used by core/server.lua event handlers
function MBT.GiveItems.Setup(config)

    local runtime = MBT.GiveItems.NewRuntime(config)
    MBT.GiveItems.Runtime = runtime

    -- Expose addItem globally for use by core/server.lua (e.g. externalUndress)
    addItemToPlayer = config.addItem

    function giveDress(src, data)
        return runtime:ReturnSlot(src, "Drawables", data.Index)
    end

    function giveDressKit(src)
        return runtime:ReturnTorso(src)
    end

    function giveProp(src, data)
        return runtime:ReturnSlot(src, "Props", data.Index)
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
