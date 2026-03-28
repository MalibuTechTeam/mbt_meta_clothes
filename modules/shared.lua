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
    local args = {...}
    local parts = {}
    for _, v in ipairs(args) do
        parts[#parts + 1] = tostring(v)
    end
    print(("^7[%s] [%s^7] %s^0"):format(resName, side, table.concat(parts, " ")))
end

--- Log a warning (always prints, regardless of MBT.Debug)
function MBT.Warn(...)
    local args = {...}
    local parts = {}
    for _, v in ipairs(args) do
        parts[#parts + 1] = tostring(v)
    end
    print(("^3[%s] [WARN] %s^0"):format(resName, table.concat(parts, " ")))
end

-----------------------------------------------------------
-- Utilities
-----------------------------------------------------------

--- Check if a table (array) contains a value
function MBT.TableContains(tbl, value)
    if type(tbl) ~= "table" then return tbl == value end
    for i = 1, #tbl do
        if tbl[i] == value then return true end
    end
    return false
end

-----------------------------------------------------------
-- Slot → Locale key mappings
-----------------------------------------------------------
MBT.SlotLocaleKeys = {
    Drawables = { [3] = "arms", [4] = "legs", [6] = "foot", [7] = "chain", [8] = "t_shirt", [11] = "jacket" },
    Props = { [0] = "hats", [1] = "glasses", [2] = "ear_acc", [6] = "watch" },
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
end)
