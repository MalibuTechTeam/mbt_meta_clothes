MBT.Snapshot = MBT.Snapshot or {}

local SLOT_TYPES = { 'Drawables', 'Props' }

local function sortedKeys(value)
    local keys = {}
    for key in pairs(value or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys, function(left, right)
        if type(left) == type(right) then return left < right end
        return tostring(left) < tostring(right)
    end)
    return keys
end

local function isInteger(value)
    return type(value) == 'number' and value == value and value ~= math.huge
        and value ~= -math.huge and value % 1 == 0
end

local function inBounds(value, bounds)
    return isInteger(value) and value >= bounds.min and value <= bounds.max
end

local function slotConfig(slotType)
    return slotType == 'Drawables' and MBT.Drawables or MBT.Props
end

local function defaultDrawable(slotType, slotIndex, sex)
    local config = slotConfig(slotType)[slotIndex]
    local configured = config and config.Default and config.Default[sex]
    if type(configured) == 'table' and configured[1] ~= nil then
        return configured[1]
    end
    local fallback = MBT.FreemodeDefaults and MBT.FreemodeDefaults[slotType]
    fallback = fallback and fallback[sex]
    return fallback and fallback[slotIndex] or (slotType == 'Props' and -1 or 0)
end

local function isDefaultDrawable(slotType, slotIndex, sex, drawable)
    local config = slotConfig(slotType)[slotIndex]
    local configured = config and config.Default and config.Default[sex]
    if type(configured) == 'table' then
        for i = 1, #configured do
            if configured[i] == drawable then return true end
        end
    end
    return drawable == defaultDrawable(slotType, slotIndex, sex)
end

local function sameVisual(left, right)
    return type(left) == 'table' and type(right) == 'table'
        and left.drawable == right.drawable
        and left.texture == right.texture
        and (left.palette or 0) == (right.palette or 0)
end

local function resolveSex(model)
    local mapped = MBT.GenderModels and MBT.GenderModels[model] or nil
    return MBT.NormalizeSex(mapped)
end

--- Validate and normalize a full managed PED visual snapshot.
--- @param visual table
--- @param model number|string
--- @return table|nil normalized
--- @return string|nil reason
function MBT.Snapshot.Canonicalize(visual, model)
    if type(visual) ~= 'table' then return nil, 'invalid_visual' end
    local sex = resolveSex(model)
    if not sex then return nil, 'unsupported_model' end

    for key in pairs(visual) do
        if key ~= 'Drawables' and key ~= 'Props' then
            return nil, 'extra_slot_type'
        end
    end

    local normalized = { Drawables = {}, Props = {} }
    for _, slotType in ipairs(SLOT_TYPES) do
        local supplied = visual[slotType]
        if type(supplied) ~= 'table' then return nil, 'missing_slot_type' end
        local configured = slotConfig(slotType)
        local seen = {}

        for rawIndex in pairs(supplied) do
            local slotIndex = tonumber(rawIndex)
            if not slotIndex or configured[slotIndex] == nil then
                return nil, 'extra_slot'
            end
            if seen[slotIndex] then return nil, 'duplicate_slot' end
            seen[slotIndex] = true
        end

        for _, slotIndex in ipairs(sortedKeys(configured)) do
            local slot = supplied[slotIndex] or supplied[tostring(slotIndex)]
            if type(slot) ~= 'table' then return nil, 'missing_slot' end
            for field in pairs(slot) do
                if field ~= 'drawable' and field ~= 'texture' and field ~= 'palette' then
                    return nil, 'extra_field'
                end
            end

            local drawableBounds = slotType == 'Drawables'
                and MBT.SnapshotBounds.componentDrawable
                or MBT.SnapshotBounds.propDrawable
            local palette = slot.palette == nil and 0 or slot.palette
            if not inBounds(slot.drawable, drawableBounds) then return nil, 'invalid_drawable' end
            if not inBounds(slot.texture, MBT.SnapshotBounds.texture) then return nil, 'invalid_texture' end
            if not inBounds(palette, MBT.SnapshotBounds.palette) then return nil, 'invalid_palette' end

            normalized[slotType][slotIndex] = {
                drawable = slot.drawable,
                texture = slot.texture,
                palette = palette,
            }
        end
    end

    return normalized
end

--- Produce a stable fingerprint independent of Lua table insertion order.
function MBT.Snapshot.Fingerprint(visual)
    if type(visual) ~= 'table' then return '' end
    local parts = {}
    for _, slotType in ipairs(SLOT_TYPES) do
        parts[#parts + 1] = slotType
        for _, slotIndex in ipairs(sortedKeys(visual[slotType])) do
            local slot = visual[slotType][slotIndex]
            parts[#parts + 1] = ('%d:%d:%d:%d'):format(
                slotIndex,
                slot.drawable,
                slot.texture,
                slot.palette or 0
            )
        end
    end
    return table.concat(parts, '|')
end

--- Expand sparse wearing metadata into a complete managed visual snapshot.
function MBT.Snapshot.VisualFromWearing(wearing, sex)
    sex = MBT.NormalizeSex(sex)
    if not sex then return nil, 'invalid_sex' end
    wearing = type(wearing) == 'table' and wearing or {}
    local visual = { Drawables = {}, Props = {} }

    for _, slotType in ipairs(SLOT_TYPES) do
        local current = wearing[slotType] or {}
        for _, slotIndex in ipairs(sortedKeys(slotConfig(slotType))) do
            local metadata = current[slotIndex] or current[tostring(slotIndex)]
            visual[slotType][slotIndex] = {
                drawable = metadata and metadata.drawable or defaultDrawable(slotType, slotIndex, sex),
                texture = metadata and metadata.texture or 0,
                palette = metadata and (metadata.palette or 0) or 0,
            }
        end
    end
    return visual
end

--- Reconcile canonical PED visuals with authoritative rich wearing metadata.
function MBT.Snapshot.Reconcile(current, visual, sex)
    current = type(current) == 'table' and current or {}
    sex = MBT.NormalizeSex(sex)
    local nextState = { Drawables = {}, Props = {} }
    local changes = {}

    for _, slotType in ipairs(SLOT_TYPES) do
        for key, metadata in pairs(current[slotType] or {}) do
            nextState[slotType][tonumber(key) or key] = metadata
        end

        for _, slotIndex in ipairs(sortedKeys(slotConfig(slotType))) do
            local slot = visual[slotType][slotIndex]
            local previous = nextState[slotType][slotIndex]
            local replacement

            if not isDefaultDrawable(slotType, slotIndex, sex, slot.drawable) then
                if sameVisual(previous, slot) then
                    replacement = previous
                else
                    replacement = {
                        index = slotIndex,
                        drawable = slot.drawable,
                        texture = slot.texture,
                        palette = slot.palette or 0,
                        sex = sex,
                        type = slotType == 'Props' and 'Prop' or 'Drawable',
                        provenance = 'external',
                    }
                end
            end

            if replacement ~= previous then
                nextState[slotType][slotIndex] = replacement
                changes[#changes + 1] = {
                    slotType = slotType,
                    slotIndex = slotIndex,
                    previous = previous,
                    metadata = replacement,
                }
            end
        end
    end

    return nextState, changes, #changes > 0
end
