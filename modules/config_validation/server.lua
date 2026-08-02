MBT = MBT or {}
Locales = Locales or {}

MBT.ConfigValidation = MBT.ConfigValidation or {}

local ConfigValidation = MBT.ConfigValidation
local VALID_SEX = { male = true, female = true }
local SLOT_LIMITS = {
    Drawables = { min = 0, max = 11 },
    Props = { min = 0, max = 7 },
}
local FRAMEWORK_RESOURCES = { 'es_extended', 'qb-core', 'ox_core', 'qbx_core' }
local INVENTORY_RESOURCES = { 'ox_inventory', 'qb-inventory' }

local function isInteger(value)
    return type(value) == 'number' and value == math.floor(value)
end

local function addIssue(target, path, message)
    target[#target + 1] = ('%s: %s'):format(path, message)
end

local function startedResources(resourceNames)
    local started = {}
    for _, resourceName in ipairs(resourceNames) do
        if GetResourceState(resourceName) == 'started' then
            started[#started + 1] = resourceName
        end
    end
    return started
end

local function validateRuntimeBridge(config, errors, stats)
    local frameworks = startedResources(FRAMEWORK_RESOURCES)
    local inventories = startedResources(INVENTORY_RESOURCES)
    local hasCustomInventory = type(config.CustomInventory) == 'function'

    -- Some QBox servers keep a qb-core shim running for legacy resources.
    -- These are not two conflicting frameworks: qbx_core is the authority, and
    -- the qb/ bridge stands down by itself when it sees it. Without this, the
    -- pair would read as "two active frameworks" and stop the resource.
    if #frameworks > 1 then
        local hasQbox, filtered = false, {}
        for _, name in ipairs(frameworks) do
            if name == 'qbx_core' then hasQbox = true end
            if name ~= 'qb-core' then filtered[#filtered + 1] = name end
        end
        if hasQbox then frameworks = filtered end
    end

    stats.framework = frameworks[1] or 'none'
    stats.inventory = inventories[1] or (hasCustomInventory and 'custom' or 'none')

    if #frameworks == 0 then
        addIssue(errors, 'runtime.framework', 'start one supported framework before mbt_meta_clothes: es_extended, qb-core, qbx_core, or ox_core')
    elseif #frameworks > 1 then
        addIssue(errors, 'runtime.framework', ('multiple supported frameworks are active: %s'):format(table.concat(frameworks, ', ')))
    end

    if #inventories > 1 then
        addIssue(errors, 'runtime.inventory', ('multiple supported inventories are active: %s'):format(table.concat(inventories, ', ')))
        return
    end

    if #inventories == 0 then
        if not hasCustomInventory then
            addIssue(errors, 'runtime.inventory', 'start ox_inventory or qb-inventory before mbt_meta_clothes, or configure MBT.CustomInventory')
        elseif frameworks[1] == 'ox_core' then
            addIssue(errors, 'runtime.inventory', 'the ox_core bridge requires ox_inventory; MBT.CustomInventory is supported by the ESX, QBCore and QBox bridges')
        end
        return
    end

    if inventories[1] == 'qb-inventory' and frameworks[1] ~= 'qb-core' then
        addIssue(errors, 'runtime.inventory', 'qb-inventory is supported only with the qb-core bridge')
    end
end

local function arrayContains(values, expected)
    if type(values) ~= 'table' then return false end
    for index = 1, #values do
        if values[index] == expected then return true end
    end
    return false
end

local function validatePositiveNumber(config, key, errors, allowZero)
    local value = config[key]
    if type(value) ~= 'number' or value ~= value or value == math.huge or value == -math.huge then
        addIssue(errors, 'MBT.' .. key, 'must be a finite number')
        return
    end
    if allowZero and value < 0 or not allowZero and value <= 0 then
        addIssue(errors, 'MBT.' .. key, allowZero and 'must be zero or greater' or 'must be greater than zero')
    end
end

local function validateTheme(config, errors)
    local theme = config.Theme
    if type(theme) ~= 'table' then
        addIssue(errors, 'MBT.Theme', 'must be a table')
        return
    end
    -- Same convention as mbt_emote_menu: six hex digits without '#'. A leading
    -- '#' is the likeliest mistake when copying a colour out of a picker, so the
    -- message is worth spelling out.
    if type(theme.Accent) ~= 'string' or not theme.Accent:match('^%x%x%x%x%x%x$') then
        addIssue(errors, 'MBT.Theme.Accent', "must be a 6-digit hex colour without '#', e.g. '00e676'")
    end
end

local function validateBounds(config, errors)
    local bounds = config.SnapshotBounds
    if type(bounds) ~= 'table' then
        addIssue(errors, 'MBT.SnapshotBounds', 'must be a table')
        return
    end

    for _, key in ipairs({ 'componentDrawable', 'propDrawable', 'texture', 'palette' }) do
        local range = bounds[key]
        local path = 'MBT.SnapshotBounds.' .. key
        if type(range) ~= 'table' or not isInteger(range.min) or not isInteger(range.max) then
            addIssue(errors, path, 'must define integer min and max values')
        elseif range.min > range.max then
            addIssue(errors, path, 'min cannot be greater than max')
        end
    end
end

local function configuredDefaults(config, slotType, slotIndex, slotConfig, sex)
    local defaults = slotConfig.Default
    if type(defaults) == 'table' and defaults[sex] ~= nil then
        return defaults[sex]
    end

    local fallbackType = config.FreemodeDefaults and config.FreemodeDefaults[slotType]
    local fallbackSex = fallbackType and fallbackType[sex]
    local fallback = fallbackSex and fallbackSex[slotIndex]
    return fallback ~= nil and { fallback } or nil
end

local function validateItemNames(item, path, owner, errors)
    if item == nil then return 0 end

    local names = type(item) == 'table' and item or { item }
    if type(item) ~= 'string' and type(item) ~= 'table' then
        addIssue(errors, path, 'must be a string or an array of strings')
        return 0
    end
    if #names == 0 then
        addIssue(errors, path, 'cannot be an empty item array')
        return 0
    end

    local localNames = {}
    local validCount = 0
    for index, itemName in ipairs(names) do
        local itemPath = ('%s[%d]'):format(path, index)
        if type(itemName) ~= 'string' or itemName == '' then
            addIssue(errors, itemPath, 'must be a non-empty string')
        elseif localNames[itemName] then
            addIssue(errors, itemPath, ('duplicates item %q in the same slot'):format(itemName))
        elseif owner[itemName] then
            addIssue(errors, itemPath, ('item %q is already owned by %s'):format(itemName, owner[itemName]))
        else
            localNames[itemName] = true
            owner[itemName] = path
            validCount = validCount + 1
        end
    end
    return validCount
end

local function validateSlots(config, errors, warnings, stats)
    local itemOwner = {}

    for _, slotType in ipairs({ 'Drawables', 'Props' }) do
        local slots = config[slotType]
        local limits = SLOT_LIMITS[slotType]
        if type(slots) ~= 'table' then
            addIssue(errors, 'MBT.' .. slotType, 'must be a table')
        else
            for slotIndex, slotConfig in pairs(slots) do
                local path = ('MBT.%s[%s]'):format(slotType, tostring(slotIndex))
                if not isInteger(slotIndex) or slotIndex < limits.min or slotIndex > limits.max then
                    addIssue(errors, path, ('slot index must be an integer from %d to %d'):format(limits.min, limits.max))
                elseif type(slotConfig) ~= 'table' then
                    addIssue(errors, path, 'must be a table')
                else
                    stats.slots = stats.slots + 1
                    stats.items = stats.items + validateItemNames(slotConfig.Item, path .. '.Item', itemOwner, errors)

                    for _, sex in ipairs({ 'male', 'female' }) do
                        local values = configuredDefaults(config, slotType, slotIndex, slotConfig, sex)
                        local defaultPath = ('%s.Default.%s'):format(path, sex)
                        if type(values) ~= 'table' or #values == 0 then
                            addIssue(errors, defaultPath, 'must contain at least one drawable default or have a freemode fallback')
                        else
                            for valueIndex, value in ipairs(values) do
                                if not isInteger(value) then
                                    addIssue(errors, ('%s[%d]'):format(defaultPath, valueIndex), 'must be an integer')
                                elseif slotType == 'Drawables' and value < 0 then
                                    addIssue(errors, ('%s[%d]'):format(defaultPath, valueIndex), 'drawable defaults cannot be negative')
                                elseif slotType == 'Props' and value < -1 then
                                    addIssue(errors, ('%s[%d]'):format(defaultPath, valueIndex), 'prop defaults cannot be below -1')
                                end
                            end
                        end
                    end

                    if slotConfig.Item == nil and not (slotType == 'Drawables' and arrayContains(config.TorsoKitSlots, slotIndex)) then
                        addIssue(warnings, path .. '.Item', 'slot has no inventory item and cannot be independently returned')
                    end
                end
            end
        end
    end
end

local function validateTorsoKit(config, errors)
    local slots = config.TorsoKitSlots
    local names = config.TorsoSlotNames
    if type(slots) ~= 'table' or #slots == 0 then
        addIssue(errors, 'MBT.TorsoKitSlots', 'must be a non-empty array')
        return
    end
    if type(names) ~= 'table' then
        addIssue(errors, 'MBT.TorsoSlotNames', 'must be a table')
        return
    end

    local seenSlots = {}
    local seenNames = {}
    for position, slotIndex in ipairs(slots) do
        local path = ('MBT.TorsoKitSlots[%d]'):format(position)
        if not isInteger(slotIndex) or not config.Drawables or not config.Drawables[slotIndex] then
            addIssue(errors, path, 'must reference a configured drawable slot')
        elseif seenSlots[slotIndex] then
            addIssue(errors, path, ('duplicates drawable slot %d'):format(slotIndex))
        else
            seenSlots[slotIndex] = true
        end

        local metadataName = names[slotIndex]
        if type(metadataName) ~= 'string' or metadataName == '' then
            addIssue(errors, ('MBT.TorsoSlotNames[%s]'):format(tostring(slotIndex)), 'must be a non-empty string')
        elseif seenNames[metadataName] then
            addIssue(errors, ('MBT.TorsoSlotNames[%s]'):format(tostring(slotIndex)), ('duplicates metadata key %q'):format(metadataName))
        else
            seenNames[metadataName] = true
        end
    end
end

local function validateDripLevels(config, errors, stats)
    local levels = config.DripLevels
    if type(levels) ~= 'table' or #levels == 0 then
        addIssue(errors, 'MBT.DripLevels', 'must be a non-empty array')
        return
    end

    local previousXp = -1
    local names = {}
    for index, level in ipairs(levels) do
        local path = ('MBT.DripLevels[%d]'):format(index)
        if type(level) ~= 'table' then
            addIssue(errors, path, 'must be a table')
        else
            if type(level.name) ~= 'string' or level.name == '' then
                addIssue(errors, path .. '.name', 'must be a non-empty string')
            elseif names[level.name] then
                addIssue(errors, path .. '.name', ('duplicates level name %q'):format(level.name))
            else
                names[level.name] = true
            end

            if not isInteger(level.minXp) or level.minXp < 0 then
                addIssue(errors, path .. '.minXp', 'must be a non-negative integer')
            elseif index == 1 and level.minXp ~= 0 then
                addIssue(errors, path .. '.minXp', 'the first level must start at zero')
            elseif level.minXp <= previousXp then
                addIssue(errors, path .. '.minXp', 'levels must be ordered by strictly increasing XP')
            else
                previousXp = level.minXp
            end
            stats.dripLevels = stats.dripLevels + 1
        end
    end
end

local function validateLocaleShape(reference, candidate, path, errors)
    for key, referenceValue in pairs(reference) do
        local value = candidate and candidate[key]
        local valuePath = path .. '.' .. tostring(key)
        if type(referenceValue) == 'table' then
            if type(value) ~= 'table' then
                addIssue(errors, valuePath, 'must be a table')
            else
                validateLocaleShape(referenceValue, value, valuePath, errors)
            end
        elseif type(value) ~= type(referenceValue) then
            addIssue(errors, valuePath, ('must be a %s'):format(type(referenceValue)))
        elseif type(value) == 'string' and value == '' then
            addIssue(errors, valuePath, 'cannot be empty')
        end
    end
end

local function validateLocales(config, locales, errors, stats)
    local english = locales.en
    if type(english) ~= 'table' then
        addIssue(errors, 'Locales.en', 'English fallback locale is required')
        return
    end

    if type(config.Language) ~= 'string' or type(locales[config.Language]) ~= 'table' then
        addIssue(errors, 'MBT.Language', ('locale %q is not loaded'):format(tostring(config.Language)))
    end

    for localeName, locale in pairs(locales) do
        if type(localeName) ~= 'string' or type(locale) ~= 'table' then
            addIssue(errors, 'Locales.' .. tostring(localeName), 'must be a named locale table')
        else
            validateLocaleShape(english, locale, 'Locales.' .. localeName, errors)
            stats.locales = stats.locales + 1
        end
    end
end

local function validateStatePairs(statePairs, path, errors, stats, requireLabel)
    if type(statePairs) ~= 'table' then
        addIssue(errors, path, 'must be an array')
        return
    end

    local mappings = {}
    for index, pair in ipairs(statePairs) do
        local pairPath = ('%s[%d]'):format(path, index)
        if type(pair) ~= 'table' then
            addIssue(errors, pairPath, 'must be a table')
        else
            if not VALID_SEX[pair.sex] then
                addIssue(errors, pairPath .. '.sex', 'must be "male" or "female"')
            end
            if not isInteger(pair.from) or pair.from < 0 then
                addIssue(errors, pairPath .. '.from', 'must be a non-negative integer')
            end
            if not isInteger(pair.to) or pair.to < 0 then
                addIssue(errors, pairPath .. '.to', 'must be a non-negative integer')
            end
            if pair.from == pair.to then
                addIssue(errors, pairPath, 'from and to cannot be identical')
            end
            if requireLabel and (type(pair.label) ~= 'string' or pair.label == '') then
                addIssue(errors, pairPath .. '.label', 'must be a non-empty string')
            end
            if pair.single ~= nil and type(pair.single) ~= 'boolean' then
                addIssue(errors, pairPath .. '.single', 'must be a boolean when provided')
            end

            if VALID_SEX[pair.sex] and isInteger(pair.from) and isInteger(pair.to) then
                local key = pair.sex .. ':' .. pair.from
                if mappings[key] and mappings[key] ~= pair.to then
                    addIssue(errors, pairPath, ('conflicts with another mapping from %s to %d'):format(key, mappings[key]))
                else
                    mappings[key] = pair.to
                end
            end
            stats.statePairs = stats.statePairs + 1
        end
    end
end

local function validateClothingStates(config, errors, stats)
    local states = config.ClothingStates
    if type(states) ~= 'table' then
        addIssue(errors, 'MBT.ClothingStates', 'must be a table')
        return
    end

    validateStatePairs(states.Hair, 'MBT.ClothingStates.Hair', errors, stats, false)
    for _, slotType in ipairs({ 'Drawables', 'Props' }) do
        local slotStates = states[slotType]
        if type(slotStates) ~= 'table' then
            addIssue(errors, 'MBT.ClothingStates.' .. slotType, 'must be a table')
        else
            for slotIndex, slotPairs in pairs(slotStates) do
                if not isInteger(slotIndex) or slotIndex < SLOT_LIMITS[slotType].min or slotIndex > SLOT_LIMITS[slotType].max then
                    addIssue(errors, ('MBT.ClothingStates.%s[%s]'):format(slotType, tostring(slotIndex)), 'uses an invalid slot index')
                else
                    validateStatePairs(slotPairs, ('MBT.ClothingStates.%s[%d]'):format(slotType, slotIndex), errors, stats, true)
                end
            end
        end
    end
end

function ConfigValidation.Validate(config, locales)
    config = config or {}
    locales = locales or {}

    local report = {
        errors = {},
        warnings = {},
        stats = { slots = 0, items = 0, locales = 0, dripLevels = 0, statePairs = 0 },
    }

    for _, key in ipairs({
        'ActionCooldown', 'StealDistance', 'TargetDistance', 'StealDuration',
        'StealAllDuration', 'VictimAnimCap', 'StealTokenGrace', 'StealRequestTimeout',
        'RateLimitWindow', 'RateLimitMax', 'StateSaveInterval', 'RestoreProtection',
        'PedRevealStableWindow', 'PedRevealTimeout', 'SnapshotPollInterval',
        'SnapshotAckTimeout', 'SnapshotWriteBehind',
        'SnapshotMaxPayload', 'DnaMaxEntries', 'DnaExpiryHours', 'DripInterval',
        'PropCleanupTime',
    }) do
        validatePositiveNumber(config, key, report.errors, false)
    end
    validatePositiveNumber(config, 'SnapshotDebounce', report.errors, true)
    -- Zero is legitimate and means "every frame": it is the value that makes the
    -- correzione di un apply esterno praticamente istantanea.
    validatePositiveNumber(config, 'SnapshotRestorePollInterval', report.errors, true)
    validatePositiveNumber(config, 'DefaultDrip', report.errors, true)

    validateTheme(config, report.errors)
    validateBounds(config, report.errors)
    validateTorsoKit(config, report.errors)
    validateSlots(config, report.errors, report.warnings, report.stats)
    validateDripLevels(config, report.errors, report.stats)
    validateLocales(config, locales, report.errors, report.stats)
    validateClothingStates(config, report.errors, report.stats)
    validateRuntimeBridge(config, report.errors, report.stats)

    if type(config.ProgressBar) ~= 'function' then
        addIssue(report.errors, 'MBT.ProgressBar', 'must be a function')
    end
    if type(config.Notification) ~= 'function' then
        addIssue(report.errors, 'MBT.Notification', 'must be a function')
    end
    if config.CustomInventory ~= nil and type(config.CustomInventory) ~= 'function' then
        addIssue(report.errors, 'MBT.CustomInventory', 'must be a function when configured')
    end

    report.ok = #report.errors == 0
    return report
end

local report = ConfigValidation.Validate(MBT, Locales)
for _, warning in ipairs(report.warnings) do
    MBTLog.Warn('configuration warning: ' .. warning)
end

if not report.ok then
    for _, configError in ipairs(report.errors) do
        MBTLog.Error('configuration error: ' .. configError)
    end
    -- error() on its own stops ONLY this file: the other server_scripts load
    -- anyway and the resource runs with an invalid config, which is the
    -- opposite of the fail-fast the manifest claims. StopResource is what
    -- actually stops it; the error() stays because it is what keeps the rest of
    -- THIS file from running before the stop takes effect.
    StopResource(GetCurrentResourceName())
    error(('mbt_meta_clothes configuration validation failed with %d error(s)'):format(#report.errors), 0)
end

MBTLog.Debug('Configuration validation passed', report.stats)
