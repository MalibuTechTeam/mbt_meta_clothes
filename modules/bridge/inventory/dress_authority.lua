MBT = MBT or {}
MBT.DressAuthority = MBT.DressAuthority or {}

local function clone(value, seen)
    if type(value) ~= 'table' then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end

    local copy = {}
    seen[value] = copy
    for key, child in pairs(value) do
        copy[clone(key, seen)] = clone(child, seen)
    end
    return copy
end

local function itemNames(slotConfig)
    if type(slotConfig) ~= 'table' then return {} end
    local configured = slotConfig.Item
    if type(configured) == 'string' then return { configured } end
    if type(configured) ~= 'table' then return {} end
    return configured
end

--- La DNA viaggia legittimamente con l'item — rubi una camicia e la sua storia
--- forensic history comes with it — but it arrives from inventory metadata, so
--- it is not trusted: it must be shape-checked and bounded. Without this a forged
--- item can inject an arbitrary forensic chain and grow the JSON without limit
--- persistito per quel giocatore.
local function sanitizeDna(entries, maxEntries)
    if type(entries) ~= 'table' then return nil end

    local cleaned = {}
    for _, entry in ipairs(entries) do
        if type(entry) == 'table'
            and type(entry.identifier) == 'string'
            and entry.identifier ~= ''
            and #entry.identifier <= 128 then
            -- Missing or invalid timestamp → 0, consistent with CleanExpiredDNA
            -- which already reads `dna.timestamp or 0`. The entry survives but
            -- reads as expired, instead of vanishing silently from a forensic
            -- history that may be legitimate and merely older than the field.
            local timestamp = entry.timestamp
            if type(timestamp) ~= 'number' or timestamp ~= timestamp
                or timestamp == math.huge or timestamp < 0 then
                timestamp = 0
            end
            cleaned[#cleaned + 1] = {
                identifier = entry.identifier,
                timestamp = math.floor(timestamp),
            }
        end
    end

    while #cleaned > maxEntries do table.remove(cleaned, 1) end
    return #cleaned > 0 and cleaned or nil
end

local function normalizedInteger(value)
    local number = tonumber(value)
    if not number or number ~= math.floor(number) then return nil end
    return number
end

local function inBounds(value, bounds)
    return not bounds or (value >= bounds.min and value <= bounds.max)
end

local function normalizeVisual(metadata, slotType, slotIndex, expectedSex, normalizeSex, bounds)
    if type(metadata) ~= 'table' then return nil end

    local index = normalizedInteger(metadata.index)
    local drawable = normalizedInteger(metadata.drawable)
    local texture = normalizedInteger(metadata.texture)
    local palette = normalizedInteger(metadata.palette or 0)
    local sex = normalizeSex(metadata.sex)

    if index ~= slotIndex or not drawable or not texture or not palette or not sex then return nil end
    if expectedSex and sex ~= expectedSex then return nil end
    local drawableBounds = slotType == 'Props' and bounds.propDrawable or bounds.componentDrawable
    if not inBounds(drawable, drawableBounds) then return nil end
    if not inBounds(texture, bounds.texture) or not inBounds(palette, bounds.palette) then return nil end

    local normalized = clone(metadata)
    normalized.index = slotIndex
    normalized.drawable = drawable
    normalized.texture = texture
    normalized.palette = palette
    normalized.sex = sex
    normalized.type = slotType == 'Props' and 'Prop' or 'Drawable'
    normalized.provenance = 'inventory'
    return normalized
end

function MBT.DressAuthority.New(config)
    assert(type(config) == 'table', 'dress authority config is required')
    assert(type(config.PlayerState) == 'table', 'dress authority PlayerState is required')

    local playerState = config.PlayerState
    local drawables = config.Drawables or {}
    local props = config.Props or {}
    local torsoSlots = config.TorsoKitSlots or {}
    local torsoNames = config.TorsoSlotNames or {}
    local normalizeSex = config.normalizeSex or function(value) return value end
    local bounds = config.Bounds or {
        componentDrawable = { min = 0, max = 4095 },
        propDrawable = { min = -1, max = 4095 },
        texture = { min = 0, max = 255 },
        palette = { min = 0, max = 3 },
    }
    local getPlayerSex = config.getPlayerSex
    local dnaMaxEntries = tonumber(config.dnaMaxEntries) or 3
    local injectDNA = config.injectDNA or function() end
    local apply = config.apply or function() end
    local itemMap = {}
    local ambiguousItems = {}

    local function indexItems(slotType, slots)
        for slotIndex, slotConfig in pairs(slots) do
            for _, itemName in ipairs(itemNames(slotConfig)) do
                if type(itemName) == 'string' and itemName ~= '' then
                    if itemMap[itemName] then
                        itemMap[itemName] = nil
                        ambiguousItems[itemName] = true
                    elseif not ambiguousItems[itemName] then
                        itemMap[itemName] = { slotType = slotType, slotIndex = slotIndex }
                    end
                end
            end
        end
    end

    indexItems('Drawables', drawables)
    indexItems('Props', props)

    local runtime = {}

    local function expectedSexFor(src, metadata)
        local trusted = getPlayerSex and normalizeSex(getPlayerSex(src)) or nil
        return trusted or normalizeSex(metadata and metadata.sex)
    end

    local function prepareKit(src, metadata)
        if type(metadata) ~= 'table' or metadata.type ~= 'DressKit' then
            return nil, 'invalid_metadata'
        end

        local expectedSex = expectedSexFor(src, metadata)
        if not expectedSex or normalizeSex(metadata.sex) ~= expectedSex then
            return nil, 'invalid_metadata'
        end

        local prepared = {
            kind = 'DressKit',
            slots = {},
            payload = clone(metadata),
        }

        for _, slotIndex in ipairs(torsoSlots) do
            local slotName = torsoNames[slotIndex]
            local normalized = slotName and normalizeVisual(
                metadata[slotName],
                'Drawables',
                slotIndex,
                expectedSex,
                normalizeSex,
                bounds
            ) or nil
            if not normalized then return nil, 'invalid_metadata' end
            normalized.last_worn_by = sanitizeDna(normalized.last_worn_by, dnaMaxEntries)

            prepared.slots[#prepared.slots + 1] = {
                slotType = 'Drawables',
                slotIndex = slotIndex,
                metadata = normalized,
            }
            prepared.payload[slotName] = normalized
        end

        prepared.payload.type = 'DressKit'
        prepared.payload.sex = expectedSex
        prepared.payload.provenance = 'inventory'
        return prepared
    end

    local function prepareSingle(src, itemName, metadata)
        local mapping = itemMap[itemName]
        if not mapping then return nil, 'invalid_item' end

        local expectedSex = expectedSexFor(src, metadata)
        local normalized = normalizeVisual(
            metadata,
            mapping.slotType,
            mapping.slotIndex,
            expectedSex,
            normalizeSex,
            bounds
        )
        if not normalized then return nil, 'invalid_metadata' end
        normalized.last_worn_by = sanitizeDna(normalized.last_worn_by, dnaMaxEntries)

        normalized.item_name = itemName
        return {
            kind = normalized.type,
            slots = {
                {
                    slotType = mapping.slotType,
                    slotIndex = mapping.slotIndex,
                    metadata = normalized,
                },
            },
            payload = normalized,
        }
    end

    local function prepare(src, itemName, metadata)
        if type(itemName) ~= 'string' or itemName == '' then return nil, 'invalid_item' end
        if itemName == 'topdress' then return prepareKit(src, metadata) end
        return prepareSingle(src, itemName, metadata)
    end

    local function checkVacancy(src, prepared)
        for _, slot in ipairs(prepared.slots) do
            if playerState.GetSlot(src, slot.slotType, slot.slotIndex) then
                return false, 'slot_occupied'
            end
        end
        return true
    end

    function runtime:CanUse(src, itemName, metadata)
        local prepared, reason = prepare(src, itemName, metadata)
        if not prepared then return false, reason end
        local vacant, vacancyReason = checkVacancy(src, prepared)
        if not vacant then return false, vacancyReason end
        return true, nil, prepared
    end

    function runtime:Commit(src, itemName, metadata)
        local prepared, reason = prepare(src, itemName, metadata)
        if not prepared then return { ok = false, reason = reason } end

        local vacant, vacancyReason = checkVacancy(src, prepared)
        if not vacant then return { ok = false, reason = vacancyReason } end

        for _, slot in ipairs(prepared.slots) do
            injectDNA(slot.metadata, src)
            playerState.SetSlot(src, slot.slotType, slot.slotIndex, slot.metadata)
        end

        apply(src, prepared.kind, prepared.payload)
        return { ok = true, kind = prepared.kind, slots = prepared.slots }
    end

    return runtime
end
