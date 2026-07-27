MBT = MBT or {}
Locales = Locales or {}

-- Canonical MalibuTech logger aliases. Direct references preserve caller depth.
MBT.Debugger = MBTLog.Debug
MBT.Info = MBTLog.Info
MBT.Warn = MBTLog.Warn
MBT.Error = MBTLog.Error


-----------------------------------------------------------
-- Utilities
-----------------------------------------------------------

--- Resolve the item name to give back for a slot.
--- Stored metadata may select one of the item names configured for this exact
--- slot, but it can never introduce an arbitrary inventory item.
--- ["Item"] can be a string ("trousers") or a table ({"trousers","jeans"}).
--- @param slotCfg table  The MBT.Drawables[k] or MBT.Props[k] config entry
--- @param metadata table The stored wearing metadata (may have item_name)
--- @return string|nil
function MBT.ResolveItemName(slotCfg, metadata)
    if not slotCfg then return nil end
    local item = slotCfg["Item"]

    if metadata and metadata.item_name ~= nil then
        if type(metadata.item_name) ~= "string" or metadata.item_name == "" then
            return nil
        end

        if type(item) == "string" then
            return metadata.item_name == item and item or nil
        end
        if type(item) == "table" then
            for _, configuredName in ipairs(item) do
                if metadata.item_name == configuredName then return configuredName end
            end
        end
        return nil
    end

    if type(item) == "table" then return item[1] end
    return type(item) == "string" and item or nil
end

--- Collect ALL item names registered for a slot (handles string and array).
--- Used when registering item use callbacks.
--- @param slotCfg table
--- @return table  Array of item name strings
function MBT.GetSlotItemNames(slotCfg)
    if not slotCfg then return {} end
    local item = slotCfg["Item"]
    if type(item) == "table" then return item end
    if type(item) == "string" then return {item} end
    return {}
end

--- Normalize any sex/gender value to "male" or "female".
--- Handles all formats written by different frameworks and external scripts:
---   "male" / "female"  → returned as-is
---   "m" / "M"          → "male"
---   "f" / "F"          → "female"
---   0 / "0"            → "male"  (QB integer format)
---   1 / "1"            → "female" (QB integer format)
---   anything else      → nil
--- @param v any The raw sex value from metadata or framework data
--- @return string|nil "male", "female", or nil
function MBT.NormalizeSex(v)
    if v == "male"   or v == "m" or v == "M" or v == 0  or v == "0" then return "male"   end
    if v == "female" or v == "f" or v == "F" or v == 1  or v == "1" then return "female"  end
    if v ~= nil then
        MBT.Debugger("NormalizeSex: unrecognized value '" .. tostring(v) .. "' (" .. type(v) .. ")")
    end
    return nil
end

--- Check if a table (array) contains a value
function MBT.TableContains(tbl, value)
    if type(tbl) ~= "table" then return tbl == value end
    for i = 1, #tbl do
        if tbl[i] == value then return true end
    end
    return false
end

-----------------------------------------------------------
-- GTA V internal constants
-- These reflect engine facts and should not need changing.
-- Advanced users can override in config.lua if they have
-- a non-standard slot layout (e.g. custom EUP manifests).
-----------------------------------------------------------

--- Slots that form the torso kit (dressed/undressed together to avoid mesh clipping).
MBT.TorsoKitSlots  = MBT.TorsoKitSlots  or {3, 8, 11}

--- Human-readable key names for torso kit slots (used as metadata keys in DressKit items).
MBT.TorsoSlotNames = MBT.TorsoSlotNames or {[3] = "Arms", [8] = "Tshirt", [11] = "Jacket"}

-----------------------------------------------------------
-- Slot → Locale key mappings
-----------------------------------------------------------
MBT.SlotLocaleKeys = {
    Drawables = { [3] = "arms", [4] = "legs", [6] = "foot", [7] = "chain", [8] = "t_shirt", [11] = "jacket" },
    Props = { [0] = "hats", [1] = "glasses", [2] = "ear_acc", [6] = "watch", [7] = "bracelet" },
}

-----------------------------------------------------------
-- Locales
-----------------------------------------------------------
local function setLocale(lang)
    lang = lang or 'en'
    if not Locales[lang] then
        MBT.Warn("Language '" .. tostring(lang) .. "' not found in locales/. Falling back to 'en'.")
        MBT.Locale = Locales['en'] or (next(Locales) ~= nil and Locales[next(Locales)]) or {}
    else
        MBT.Locale = Locales[lang]
        MBT.Debugger("Language set to " .. tostring(lang))
    end
end

-- Placeholder until locales load (prevents nil access in config.lua)
MBT.Locale = {}

function MBT.RefreshLocale(lang)
    setLocale(lang or MBT.Language)
end

-- Finalize after all shared_scripts have loaded (locales + config)
SetTimeout(0, function()
    MBT.RefreshLocale(MBT.Language)

    -- Populate missing ["Default"] entries from MBT.FreemodeDefaults so server
    -- owners can add new slots without manually specifying vanilla defaults.
    if MBT.FreemodeDefaults then
        for slotType, slotTable in pairs({ Drawables = MBT.Drawables, Props = MBT.Props }) do
            local fallbacks = MBT.FreemodeDefaults[slotType]
            if type(fallbacks) == "table" and slotTable then
                for idx, slotCfg in pairs(slotTable) do
                    if not slotCfg["Default"] then
                        slotCfg["Default"] = {}
                    end
                    for gender, defaults in pairs(fallbacks) do
                        if type(defaults) == "table" and not slotCfg["Default"][gender] then
                            local v = defaults[idx]
                            if v ~= nil then
                                slotCfg["Default"][gender] = { v }
                            end
                        end
                    end
                end
            end
        end
    end
end)
