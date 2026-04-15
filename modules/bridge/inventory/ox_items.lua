-----------------------------------------------------------
-- Shared OX Inventory item registration (client-side)
-- Eliminates duplicated ox_inventory exports() handlers
-- across QB, ESX, and OX framework bridges.
-----------------------------------------------------------

MBT.OxItems = {}

--- Register all clothing items with ox_inventory exports.
--- Item names are derived from MBT.Drawables / MBT.Props config so that
--- ["Item"] = {"trousers", "jeans"} (array) or ["Item"] = "trousers" (string)
--- both register every individual item name.
--- @param getPlayerSex function Must return two values: rawSex, sexLabel ("male"|"female")
function MBT.OxItems.RegisterItems(getPlayerSex)
    local registered = {} -- deduplicate in case two slots share an item name

    -- Always register 'topdress' (torso kit)
    if not registered['topdress'] then
        registered['topdress'] = true
        exports('topdress', function(data, slot)
            local sex, sexLabel = getPlayerSex()
            if sexLabel ~= MBT.NormalizeSex(slot.metadata and slot.metadata.sex) then
                MBT.Notification({ title = MBT.Locale["wrong_sex"].title, description = MBT.Locale["wrong_sex"].description .. sexLabel, type = "error", icon = "ban" })
                return
            end
            exports.ox_inventory:useItem(data, function(data)
                if data then
                    TriggerEvent("mbt_meta_clothes:checkDress", {
                        type = "Drawables",
                        index = data.metadata,
                        sex = sex,
                        itemInfo = data.metadata
                    })
                end
            end)
        end)
    end

    -- Drawables
    for _, slotCfg in pairs(MBT.Drawables) do
        for _, itemName in ipairs(MBT.GetSlotItemNames(slotCfg)) do
            if not registered[itemName] then
                registered[itemName] = true
                local name = itemName -- capture for closure
                exports(name, function(data, slot)
                    local sex, sexLabel = getPlayerSex()
                    if sexLabel ~= MBT.NormalizeSex(slot.metadata and slot.metadata.sex) then
                        MBT.Notification({ title = MBT.Locale["wrong_sex"].title, description = MBT.Locale["wrong_sex"].description .. sexLabel, type = "error", icon = "ban" })
                        return
                    end
                    exports.ox_inventory:useItem(data, function(data)
                        if data and data.metadata then
                            TriggerEvent("mbt_meta_clothes:checkDress", {
                                type = "Drawables",
                                index = data.metadata.index,
                                sex = sex,
                                itemInfo = data
                            })
                        end
                    end)
                end)
            end
        end
    end

    -- Props
    for _, slotCfg in pairs(MBT.Props) do
        for _, itemName in ipairs(MBT.GetSlotItemNames(slotCfg)) do
            if not registered[itemName] then
                registered[itemName] = true
                local name = itemName -- capture for closure
                exports(name, function(data, slot)
                    local sex, sexLabel = getPlayerSex()
                    if sexLabel ~= MBT.NormalizeSex(slot.metadata and slot.metadata.sex) then
                        MBT.Notification({ title = MBT.Locale["wrong_sex"].title, description = MBT.Locale["wrong_sex"].description .. sexLabel, type = "error", icon = "ban" })
                        return
                    end
                    exports.ox_inventory:useItem(data, function(data)
                        if data and data.metadata then
                            TriggerEvent("mbt_meta_clothes:checkDress", {
                                type = "Props",
                                index = data.metadata.index,
                                sex = sex,
                                itemInfo = data
                            })
                        end
                    end)
                end)
            end
        end
    end
end
