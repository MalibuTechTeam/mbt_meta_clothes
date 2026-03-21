-----------------------------------------------------------
-- Player Wearing State Manager (server-side)
-- Tracks metadata for every clothing slot each player is wearing.
-- Memory: ~10KB per player = ~5MB for 500 players
-- Persistence: MySQL with dirty flag, periodic save every 5 minutes
-----------------------------------------------------------

MBT.PlayerState = {}

local PlayerWearing = {}
local DirtyPlayers = {}
local PlayerIdentifiers = {}
local PlayerHasDbEntry = {}  -- [source] = true if player has an existing DB record
local initialized = false

function MBT.PlayerState.Init()
    if initialized then return end
    initialized = true

    MySQL.ready(function()
        MySQL.query([[
            CREATE TABLE IF NOT EXISTS mbt_player_wearing (
                identifier VARCHAR(60) NOT NULL,
                wearing_data LONGTEXT NOT NULL,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (identifier)
            )
        ]])
        MBT.ServerUtils.MbtDebugger("PlayerState: Database table ready")
    end)

    Citizen.CreateThread(function()
        while true do
            Wait(300000)
            MBT.PlayerState.SaveAllDirty()
        end
    end)
end

function MBT.PlayerState.InitPlayer(src)
    PlayerWearing[src] = { Drawables = {}, Props = {} }
    DirtyPlayers[src] = false
end

function MBT.PlayerState.SetSlot(src, slotType, slotIndex, metadata)
    if not PlayerWearing[src] then MBT.PlayerState.InitPlayer(src) end
    PlayerWearing[src][slotType][slotIndex] = metadata
    DirtyPlayers[src] = true
    MBT.ServerUtils.MbtDebugger("PlayerState: SetSlot", src, slotType, slotIndex)
end

function MBT.PlayerState.GetSlot(src, slotType, slotIndex)
    if not PlayerWearing[src] then return nil end
    return PlayerWearing[src][slotType][slotIndex]
end

function MBT.PlayerState.ClearSlot(src, slotType, slotIndex)
    if not PlayerWearing[src] then return nil end
    local metadata = PlayerWearing[src][slotType][slotIndex]
    PlayerWearing[src][slotType][slotIndex] = nil
    if metadata then
        DirtyPlayers[src] = true
        MBT.ServerUtils.MbtDebugger("PlayerState: ClearSlot", src, slotType, slotIndex)
    end
    return metadata
end

function MBT.PlayerState.ClearAllSlots(src, slotType)
    if not PlayerWearing[src] then return {} end
    local allMetadata = PlayerWearing[src][slotType] or {}
    PlayerWearing[src][slotType] = {}
    if next(allMetadata) then
        DirtyPlayers[src] = true
    end
    return allMetadata
end

function MBT.PlayerState.GetAll(src)
    return PlayerWearing[src]
end

function MBT.PlayerState.IsLoaded(src)
    return PlayerWearing[src] ~= nil
end

function MBT.PlayerState.Save(src, identifier)
    if not PlayerWearing[src] then return end

    identifier = identifier or PlayerIdentifiers[src]
    if not identifier then
        if getPlayerIdentifier then
            identifier = getPlayerIdentifier(src)
            if identifier then
                PlayerIdentifiers[src] = identifier
            end
        end
    end
    if not identifier then return end

    -- Convert numeric keys to strings before encoding to force JSON object format.
    -- Without this, {[6] = {...}} encodes as [null,null,null,null,null,{...}] (array)
    -- instead of {"6": {...}} (object), causing decode issues with null holes.
    local forJson = { Drawables = {}, Props = {} }
    for k, v in pairs(PlayerWearing[src].Drawables or {}) do
        forJson.Drawables[tostring(k)] = v
    end
    for k, v in pairs(PlayerWearing[src].Props or {}) do
        forJson.Props[tostring(k)] = v
    end
    local data = json.encode(forJson)
    MySQL.insert(
        "INSERT INTO mbt_player_wearing (identifier, wearing_data) VALUES (?, ?) ON DUPLICATE KEY UPDATE wearing_data = VALUES(wearing_data), updated_at = CURRENT_TIMESTAMP",
        {identifier, data}
    )
    DirtyPlayers[src] = false
    MBT.ServerUtils.MbtDebugger("PlayerState: Saved state for", src)
end

function MBT.PlayerState.Load(src, identifier)
    if not identifier then
        if getPlayerIdentifier then
            identifier = getPlayerIdentifier(src)
        end
    end
    if not identifier then
        MBT.PlayerState.InitPlayer(src)
        return
    end

    PlayerIdentifiers[src] = identifier

    local result = MySQL.scalar.await(
        "SELECT wearing_data FROM mbt_player_wearing WHERE identifier = ?",
        {identifier}
    )

    if result then
        local decoded = json.decode(result)
        if decoded and type(decoded) == "table" then
            -- CRITICAL: json.decode creates STRING keys ("3", "11")
            -- but SetSlot/ClearSlot use NUMERIC keys (3, 11).
            -- In Lua, tbl["3"] and tbl[3] are DIFFERENT keys.
            -- Normalize all keys to numeric to prevent ghost entries.
            local normalized = { Drawables = {}, Props = {} }
            for k, v in pairs(decoded.Drawables or {}) do
                normalized.Drawables[tonumber(k) or k] = v
            end
            for k, v in pairs(decoded.Props or {}) do
                normalized.Props[tonumber(k) or k] = v
            end
            PlayerWearing[src] = normalized
        else
            MBT.PlayerState.InitPlayer(src)
        end
        PlayerHasDbEntry[src] = true
    else
        MBT.PlayerState.InitPlayer(src)
        PlayerHasDbEntry[src] = false
    end

    DirtyPlayers[src] = false
    MBT.ServerUtils.MbtDebugger("PlayerState: Loaded state for", src, identifier, "hasDbEntry:", PlayerHasDbEntry[src])
end

--- Check if a player has an existing DB record
--- Used by syncInitialWearing to skip PED scan for returning players
--- @param src number Player source
--- @return boolean
function MBT.PlayerState.HasDbEntry(src)
    return PlayerHasDbEntry[src] == true
end

function MBT.PlayerState.Cleanup(src)
    if DirtyPlayers[src] then
        MBT.PlayerState.Save(src)
    end
    PlayerWearing[src] = nil
    DirtyPlayers[src] = nil
    PlayerIdentifiers[src] = nil
    PlayerHasDbEntry[src] = nil
    MBT.ServerUtils.MbtDebugger("PlayerState: Cleaned up", src)
end

function MBT.PlayerState.SaveAllDirty()
    local count = 0
    for src, dirty in pairs(DirtyPlayers) do
        if dirty then
            MBT.PlayerState.Save(src)
            count = count + 1
        end
    end
    if count > 0 then
        MBT.ServerUtils.MbtDebugger("PlayerState: Periodic save — saved", count, "players")
    end
end
