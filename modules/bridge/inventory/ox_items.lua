-----------------------------------------------------------
-- Shared OX Inventory item registration (client-side)
-- Eliminates duplicated ox_inventory exports() handlers
-- across QB, ESX, and OX framework bridges.
-----------------------------------------------------------

MBT.OxItems = {}

-----------------------------------------------------------
-- Pre-use slot checks (BEFORE useItem consumes the item)
-----------------------------------------------------------

-- Controlla se uno slot Drawable è al valore default (PED nudo)
local function isDrawableDefault(slotIndex, sexLabel)
    local idx = tonumber(slotIndex)
    if not idx then return true end
    local cfg = MBT.Drawables[idx]
    if not cfg then return true end
    local defaults = cfg["Default"] and cfg["Default"][sexLabel]
    if not defaults then return true end
    return MBT.TableContains(defaults, GetPedDrawableVariation(PlayerPedId(), idx))
end

-- Controlla se uno slot Prop è al valore default (non indossato)
local function isPropDefault(slotIndex, sexLabel)
    local idx = tonumber(slotIndex)
    if not idx then return true end
    local cfg = MBT.Props[idx]
    if not cfg then return true end
    local defaults = cfg["Default"] and cfg["Default"][sexLabel]
    if not defaults then return true end
    return MBT.TableContains(defaults, GetPedPropIndex(PlayerPedId(), idx))
end

-- Controlla se tutti gli slot del torso kit sono al default
local function isTopDressDefault(sexLabel)
    for _, idx in ipairs(MBT.TorsoKitSlots or {}) do
        local cfg = MBT.Drawables[idx]
        if cfg and cfg["Default"] and cfg["Default"][sexLabel] then
            if not MBT.TableContains(cfg["Default"][sexLabel], GetPedDrawableVariation(PlayerPedId(), idx)) then
                return false
            end
        end
    end
    return true
end

-----------------------------------------------------------
-- Item registration
-----------------------------------------------------------

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
            -- Pre-check: almeno uno slot torso è già non-default → notifica senza consumare l'item
            if not isTopDressDefault(sexLabel) then
                MBT.Notification(MBT.Locale["undress"])
                return
            end
            -- OX consumes the item server-side; its authoritative usedItem event
            -- commits wearing state and sends the visual payload back to us.
            exports.ox_inventory:useItem(data)
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
                    -- Pre-check: slot già occupato → notifica senza consumare l'item
                    local idx = slot.metadata and slot.metadata.index
                    if not isDrawableDefault(idx, sexLabel) then
                        MBT.Notification(MBT.Locale["undress"])
                        return
                    end
                    exports.ox_inventory:useItem(data)
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
                    -- Pre-check: prop già indossato → notifica senza consumare l'item
                    local idx = slot.metadata and slot.metadata.index
                    if not isPropDefault(idx, sexLabel) then
                        MBT.Notification(MBT.Locale["undress"])
                        return
                    end
                    exports.ox_inventory:useItem(data)
                end)
            end
        end
    end
end
