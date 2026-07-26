--[[ MalibuTech logger — canonical, vendored utility.

  Single source of truth: copy this file into every mbt_* resource — verbatim
  except the PER-RESOURCE IDENTITY block at the top (the badge tag + colour) —
  and load it as a shared_script. FiveM already prefixes
  every print with "[script:<resource>]", so this logger adds only what's
  missing: a coloured severity tag, an optional timestamp (the raw FXServer
  console has none of its own), the caller file:line on warnings/errors, and
  recursive table pretty-printing.

  API (also aliased onto each resource's MBT.* loggers for back-compat):
    MBTLog.Debug(...)  -- gated by MBT.Debug
    MBTLog.Info(...)
    MBTLog.Warn(...)   -- + caller file:line
    MBTLog.Error(...)  -- + caller file:line
    MBTLog.Log(level, ...)

  Config (set in the PER-RESOURCE IDENTITY block at the top; read at call time):
    Level     = "debug"  -- minimum printed: debug < info < warn < error
    Timestamp = true     -- prepend HH:MM:SS
    Caller    = "auto"   -- file:line: "never" | "auto" (debug+warn+error) | "always"
    Tag       = nil      -- short per-resource badge, e.g. "ELV" (nil = no badge)
    Color     = "^7"     -- badge colour code (^0-^9)
]]

MBT = MBT or {}

-- ── PER-RESOURCE IDENTITY ──────────────────────────────────────────────────
-- The ONLY lines that differ between resources: this resource's console badge.
-- Everything below is copied verbatim into every mbt_* script. It lives here,
-- not in config.lua, because the badge is the resource's identity — not a
-- server-owner setting.
MBT.Log = MBT.Log or {}
MBT.Log.Tag = 'CLOTH'  -- short badge, printed as [CLOTH]
MBT.Log.Color = '^6'   -- badge colour (^0-^9) — purple
-- MBT.Log.Timestamp = false  -- default true (prepend HH:MM:SS)
-- MBT.Log.Caller = 'always'  -- 'never' | 'auto' (default: debug+warn+error) | 'always'
-- ───────────────────────────────────────────────────────────────────────────

local DEFAULTS = {
	Level = "debug",
	Timestamp = true,
	Caller = "auto",
}

local LEVELS = {
	debug = { rank = 10, color = "^5", label = "DEBUG" },
	info  = { rank = 20, color = "^2", label = "INFO" },
	warn  = { rank = 30, color = "^3", label = "WARN" },
	error = { rank = 40, color = "^1", label = "ERROR" },
}

local function cfg(key)
	local conf = MBT.Log
	if conf and conf[key] ~= nil then return conf[key] end
	return DEFAULTS[key]
end

local function prettyTable(t, indent)
	indent = indent or 1
	local pad = string.rep("  ", indent)
	local lines = {}
	for k, v in pairs(t) do
		local key = type(k) == "number" and ("[" .. k .. "]") or tostring(k)
		if type(v) == "table" then
			lines[#lines + 1] = pad .. key .. " = " .. prettyTable(v, indent + 1)
		else
			lines[#lines + 1] = pad .. key .. " = " .. tostring(v)
		end
	end
	return "{\n" .. table.concat(lines, ",\n") .. "\n" .. string.rep("  ", indent - 1) .. "}"
end

local function serialize(v)
	if type(v) == "table" then return prettyTable(v) end
	return tostring(v)
end

-- Stack at print time: callsite -> Debug/Info/Warn/Error -> log -> callerLoc
-- -> getinfo, so level 4 is the real call site (not this file).
local function callerLoc()
	local info = debug.getinfo(4, "Sl")
	if not info then return nil end
	local src = info.short_src:gsub("^@@?[^/\\]+[/\\]", "")
	return src .. ":" .. tostring(info.currentline or "?")
end

local function wantsCaller(levelName)
	local mode = cfg("Caller")
	if mode == "never" then return false end
	if mode == "always" then return true end
	-- "auto" (default): caller on debug (dev-only, where the source matters most)
	-- plus warnings and errors; INFO stays clean (it's the operational level).
	-- "warn" kept as an alias for issues-only (warn + error).
	if mode == "warn" then return levelName == "warn" or levelName == "error" end
	return levelName ~= "info"
end

-- HH:MM:SS, context-safe: the FiveM client sandbox has no `os` library, so
-- fall back to the GetLocalTime() native there; "" if neither is available.
local function clock()
	if os and os.date then
		return os.date("%H:%M:%S")
	end
	if GetLocalTime then
		local _, _, _, h, m, s = GetLocalTime()
		return ("%02d:%02d:%02d"):format(h, m, s)
	end
	return ""
end

local function log(levelName, ...)
	local meta = LEVELS[levelName] or LEVELS.debug
	-- Debug is the only level gated behind MBT.Debug; warn/error/info always
	-- surface (subject to the Level threshold).
	if levelName == "debug" and not MBT.Debug then return end
	local threshold = LEVELS[cfg("Level")] or LEVELS.debug
	if meta.rank < threshold.rank then return end

	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = serialize(select(i, ...))
	end
	local msg = table.concat(parts, " ")

	-- Level + timestamp share one bracket ("[DEBUG 21:04:45]"); the label is
	-- padded to 6 so the timestamps line up across levels. Without a timestamp
	-- it's just "[LEVEL]" with trailing pad so messages still align.
	local label = meta.label
	local tsStr = cfg("Timestamp") and clock() or ""
	local bracket, pad
	if tsStr ~= "" then
		bracket = "[" .. label .. string.rep(" ", math.max(1, 6 - #label)) .. tsStr .. "]"
		pad = " "
	else
		bracket = "[" .. label .. "]"
		pad = string.rep(" ", math.max(1, 8 - #bracket))
	end

	-- Caller file:line in round parens, dimmed cyan, on debug/warn/error.
	local loc = ""
	if wantsCaller(levelName) then
		local l = callerLoc()
		if l then loc = " ^5(" .. l .. ")^7" end
	end

	-- Optional per-resource badge (e.g. ^5[CHAR]^7) so interleaved multi-resource
	-- consoles are scannable by colour. Set MBT.Log.Tag + .Color per resource;
	-- omitted entirely when no Tag is configured.
	local badge = ""
	local btag = cfg("Tag")
	if btag and btag ~= "" then
		badge = (cfg("Color") or "^7") .. "[" .. btag .. "]^7 "
	end

	print(("%s%s%s^7%s%s%s^0"):format(badge, meta.color, bracket, pad, msg, loc))
end

MBTLog = MBTLog or {}
function MBTLog.Debug(...) log("debug", ...) end
function MBTLog.Info(...) log("info", ...) end
function MBTLog.Warn(...) log("warn", ...) end
function MBTLog.Error(...) log("error", ...) end
function MBTLog.Log(level, ...) log(string.lower(level or "debug"), ...) end
