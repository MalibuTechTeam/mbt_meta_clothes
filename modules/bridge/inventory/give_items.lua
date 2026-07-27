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

---@param selections table
---@param transfer function
---@return table summary
function MBT.GiveItems.ProcessBatch(selections, transfer)
    local summary = {
        requested = #selections,
        succeeded = 0,
        failed = 0,
        committed = {},
    }

    for _, selection in ipairs(selections) do
        local result = transfer(selection)
        if result and result.ok == true then
            summary.succeeded = summary.succeeded + 1
            summary.committed[#summary.committed + 1] = result.committed or selection
        else
            summary.failed = summary.failed + 1
            summary.lastReason = result and result.reason or "internal_error"
        end
    end

    return summary
end

---@param selections table
---@param config table
---@return table|nil normalized
function MBT.GiveItems.NormalizeStealSelections(selections, config)
    if type(selections) ~= "table" or type(config) ~= "table" then return nil end
    local length = #selections
    if length < 1 or length > config.maxSelections then return nil end

    local pairCount = 0
    for key in pairs(selections) do
        if type(key) ~= "number" or key ~= math.floor(key) or key < 1 or key > length then
            return nil
        end
        pairCount = pairCount + 1
    end
    if pairCount ~= length then return nil end

    local function isTorsoSlot(slotIndex)
        for _, configuredIndex in ipairs(config.torsoSlots) do
            if configuredIndex == slotIndex then return true end
        end
        return false
    end

    local normalized, seen = {}, {}
    for _, selection in ipairs(selections) do
        if type(selection) ~= "table" then return nil end
        local stealType = selection.stealType
        local slotIndex

        if stealType == "torso" then
            slotIndex = nil
        elseif stealType == "drawable" or stealType == "prop" then
            local slotType = stealType == "drawable" and "Drawables" or "Props"
            local valid, index = config.validateSlot(slotType, selection.slotIndex)
            if not valid then return nil end
            if stealType == "drawable" and isTorsoSlot(index) then
                stealType, index = "torso", nil
            end
            slotIndex = index
        else
            return nil
        end

        local logicalKey = stealType == "torso" and "torso" or (stealType .. ":" .. slotIndex)
        if seen[logicalKey] then return nil end
        seen[logicalKey] = true
        normalized[#normalized + 1] = { stealType = stealType, slotIndex = slotIndex }
    end

    local typeOrder = { torso = 1, drawable = 2, prop = 3 }
    table.sort(normalized, function(left, right)
        local leftOrder, rightOrder = typeOrder[left.stealType], typeOrder[right.stealType]
        if leftOrder ~= rightOrder then return leftOrder < rightOrder end
        return (left.slotIndex or -1) < (right.slotIndex or -1)
    end)
    return normalized
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
    local normalizeSex = config.normalizeSex or MBT.NormalizeSex
    local getPlayerSex = config.getPlayerSex
        or (MBT.ServerUtils and MBT.ServerUtils.GetPlayerSex)
    local cleanExpiredDNA = config.cleanExpiredDNA or MBT.ServerUtils.CleanExpiredDNA
    local configuredClothesDescription = config.clothesDescription
    local configuredPropsDescription = config.propsDescription
    local coordinator = MBT.GiveItems.New({
        addItem = config.addItem,
        log = config.log or function(...)
            MBT.Debugger("inventory transfer", ...)
        end,
    })
    local runtime = {}

    local function resolveDescription(configuredDescription, localeKey)
        if type(configuredDescription) == "string" then return configuredDescription end
        local localized = MBT.Locale and MBT.Locale[localeKey]
        if type(localized) == "string" then return localized end
        return nil
    end

    local function getIdentity(src)
        local player = config.getPlayer(src)
        if not player then return nil end
        return player, config.getPlayerName(player), config.getPlayerSource(player)
    end

    local function resolveMetadataSex(src, metadataSex)
        local trustedSex = getPlayerSex and normalizeSex(getPlayerSex(src)) or nil
        return trustedSex or normalizeSex(metadataSex)
    end

    ---@param ownerSrc number
    ---@param receiverSrc number
    ---@param slotType string
    ---@param slotIndex number
    ---@param options? table
    ---@return table result
    function runtime:TransferSlot(ownerSrc, receiverSrc, slotType, slotIndex, options)
        options = options or {}
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
            local sex = resolveMetadataSex(ownerSrc, metadata.sex)
            if not sex then return nil, "invalid_metadata" end
            metadata.sex = sex
            if not options.preserveDescription then
                local descriptionFormat = slotType == "Drawables"
                    and resolveDescription(configuredClothesDescription, "clothes_desc")
                    or resolveDescription(configuredPropsDescription, "props_desc")
                if not descriptionFormat then return nil, "invalid_locale" end
                metadata.description = buildDescription(descriptionFormat:format(playerIdentity), metadata)
            end
            cleanExpiredDNA(metadata)

            local itemName = resolveItemName(slotConfig, metadata)
            if not itemName then
                MBT.Warn('inventory return rejected invalid item metadata', {
                    source = ownerSrc,
                    receiver = receiverSrc,
                    slotType = slotType,
                    slotIndex = slotIndex,
                    itemName = metadata.item_name,
                })
                return nil, "invalid_item"
            end
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
            local descriptionFormat = resolveDescription(configuredClothesDescription, "clothes_desc")
            if not descriptionFormat then return nil, "invalid_locale" end
            local metadata = {
                description = descriptionFormat:format(playerIdentity),
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

            local sex = resolveMetadataSex(ownerSrc, metadata.sex)
            if not sex then return nil, "invalid_metadata" end
            metadata.sex = sex
            for _, slotIndex in ipairs(torsoSlots) do
                local slotName = torsoNames[slotIndex]
                if metadata[slotName] then
                    metadata[slotName].sex = sex
                else
                    local defaults = drawables[slotIndex]
                        and drawables[slotIndex].Default
                        and drawables[slotIndex].Default[sex]
                    if not defaults or defaults[1] == nil then
                        return nil, "invalid_config"
                    end
                    metadata[slotName] = {
                        index = slotIndex,
                        drawable = defaults[1],
                        texture = 0,
                        palette = 0,
                        sex = sex,
                    }
                end
            end
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

    function giveDress(src, data)
        return runtime:ReturnSlot(src, "Drawables", data.Index)
    end

    function giveDressKit(src)
        return runtime:ReturnTorso(src)
    end

    function giveProp(src, data)
        return runtime:ReturnSlot(src, "Props", data.Index)
    end

end
