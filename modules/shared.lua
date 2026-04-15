MBT = MBT or {}
Locales = Locales or {}

local resName = GetCurrentResourceName()

-----------------------------------------------------------
-- Debugger
-----------------------------------------------------------
local side = IsDuplicityVersion() and "^4S" or "^5C"

--- Log a debug message (only when MBT.Debug is true)
--- @param ... any Values to print (auto-converted to string)
function MBT.Debugger(...)
    if not MBT.Debug then return end
    local args = { ... }
    local parts = {}
    for _, v in ipairs(args) do
        parts[#parts + 1] = tostring(v)
    end
    print(("^7[%s] [%s^7] %s^0"):format(resName, side, table.concat(parts, " ")))
end

--- Log a warning (always prints, regardless of MBT.Debug)
function MBT.Warn(...)
    local args = { ... }
    local parts = {}
    for _, v in ipairs(args) do
        parts[#parts + 1] = tostring(v)
    end
    print(("^3[%s] [WARN] %s^0"):format(resName, table.concat(parts, " ")))
end

-----------------------------------------------------------
-- Utilities
-----------------------------------------------------------

--- Resolve the item name to give back for a slot.
--- Prefers the item_name stored in metadata (set when the item was first used),
--- then falls back to the config ["Item"] value.
--- ["Item"] can be a string ("trousers") or a table ({"trousers","jeans"}).
--- @param slotCfg table  The MBT.Drawables[k] or MBT.Props[k] config entry
--- @param metadata table The stored wearing metadata (may have item_name)
--- @return string|nil
function MBT.ResolveItemName(slotCfg, metadata)
    if metadata and metadata.item_name then
        return metadata.item_name
    end
    if not slotCfg then return nil end
    local item = slotCfg["Item"]
    if type(item) == "table" then
        return item[1]   -- first entry is the canonical / generic item name
    end
    return item
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
