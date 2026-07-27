-----------------------------------------------------------
-- QB-Inventory server-side item registration
-- Item names are derived dynamically from MBT.Drawables / MBT.Props
-- config so that ["Item"] = "belt" or ["Item"] = {"belt","fancy_belt"}
-- both get registered automatically without touching this file.
-----------------------------------------------------------

MBT.QbUseable = {}

local DEFAULT_DURATION = 1200

local function getDuration(slotType, slotIndex, isTopDress)
    local slotConfig
    if isTopDress then
        slotConfig = MBT.Drawables[8]
    elseif slotType == 'Drawables' then
        slotConfig = MBT.Drawables[slotIndex]
    else
        slotConfig = MBT.Props[slotIndex]
    end
    local animation = slotConfig and slotConfig.Animation
    return animation and tonumber(animation.Duration) or DEFAULT_DURATION
end

function MBT.QbUseable.RegisterItems()
    local registered    = {}
    local itemsToAdd    = {}

    local function registerItem(itemName, slotType, slotIndex, isTopDress)
        if registered[itemName] then return end
        registered[itemName] = true

        local name = itemName

        QBCore.Functions.CreateUseableItem(name, function(source, item)
            local player = QBCore.Functions.GetPlayer(source)
            if not player or not player.Functions.GetItemByName(name) then return end

            local gender   = player.PlayerData.charinfo.gender
            local sexLabel = gender == 0 and "male" or "female"

            if sexLabel ~= MBT.NormalizeSex(item.info and item.info.sex) then
                TriggerClientEvent('mbt_meta_clothes:notify', source, {
                    title       = MBT.Locale["wrong_sex"].title,
                    description = MBT.Locale["wrong_sex"].description .. sexLabel,
                    type = "error", icon = "ban"
                })
                return
            end

            local duration = getDuration(slotType, slotIndex, isTopDress)
            local pending = MBT.DressRuntime.BeginQb(source, item, duration)
            if not pending.ok then
                TriggerClientEvent('mbt_meta_clothes:notify', source, MBT.Locale['inventory_error'])
                return
            end

            TriggerClientEvent('mbt_meta_clothes:useClothing', source, {
                token      = pending.token,
                duration   = duration,
                slotType   = slotType,
                slotIndex  = isTopDress and item.info or item.info.index,
                sex        = gender,
                itemData   = item,
                isTopDress = isTopDress or false,
            })
        end)

        -- Derive label from slot locale key, fallback to item name
        local localeKey
        if slotType == "Drawables" and MBT.SlotLocaleKeys then
            localeKey = MBT.SlotLocaleKeys.Drawables[slotIndex]
        elseif slotType == "Props" and MBT.SlotLocaleKeys then
            localeKey = MBT.SlotLocaleKeys.Props[slotIndex]
        end
        local label = (localeKey and MBT.Locale[localeKey]) or name

        local slotCfg = slotType == "Drawables" and MBT.Drawables[slotIndex]
                     or slotType == "Props"      and MBT.Props[slotIndex]

        itemsToAdd[name] = {
            name        = name,
            label       = label,
            weight      = (slotCfg and slotCfg["ItemWeight"]) or 100,
            type        = 'item',
            image       = name .. '.png',
            unique      = isTopDress or false,
            useable     = true,
            shouldClose = true,
            combinable  = nil,
            description = label,
        }
    end

    -- topdress (torso kit item — always registered)
    registerItem('topdress', 'Drawables', nil, true)

    -- Drawables
    for slotIndex, slotCfg in pairs(MBT.Drawables) do
        for _, itemName in ipairs(MBT.GetSlotItemNames(slotCfg)) do
            registerItem(itemName, 'Drawables', slotIndex, false)
        end
    end

    -- Props
    for slotIndex, slotCfg in pairs(MBT.Props) do
        for _, itemName in ipairs(MBT.GetSlotItemNames(slotCfg)) do
            registerItem(itemName, 'Props', slotIndex, false)
        end
    end

    QBCore.Functions.AddItems(itemsToAdd)
end
