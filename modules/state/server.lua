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
local PlayerHasDbEntry = {}
local PlayerDripXp = {}
local PlayerJustSwitched = {} -- true quando CheckCharacterSwitch ha rilevato uno switch
local initialized = false

function MBT.PlayerState.Init()
    if initialized then return end
    initialized = true

    MySQL.ready(function()
        MySQL.query([[
            CREATE TABLE IF NOT EXISTS mbt_player_wearing (
                identifier VARCHAR(60) NOT NULL,
                wearing_data LONGTEXT NOT NULL,
                drip_xp INT NOT NULL DEFAULT 0,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (identifier)
            )
        ]])
        MySQL.query([[
            ALTER TABLE mbt_player_wearing ADD COLUMN IF NOT EXISTS drip_xp INT NOT NULL DEFAULT 0
        ]])
        MBT.Debugger("PlayerState: Database table ready")
    end)

    Citizen.CreateThread(function()
        while true do
            Wait((MBT.StateSaveInterval or 300) * 1000)
            MBT.PlayerState.SaveAllDirty()
        end
    end)


    -- Periodic DNA expiry cleanup — removes stale last_worn_by entries from
    -- in-memory wearing state for items that stay equipped for a long time.
    -- Runs every hour; only active when DnaEnabled and DnaExpiryHours are set.
    if MBT.DnaEnabled and MBT.DnaExpiryHours then
        Citizen.CreateThread(function()
            while true do
                Wait(3600 * 1000) -- hourly

                local cleaned = 0
                for src, wearing in pairs(PlayerWearing) do
                    for _, slotData in pairs(wearing.Drawables or {}) do
                        if slotData and slotData.last_worn_by then
                            local before = #slotData.last_worn_by
                            MBT.ServerUtils.CleanExpiredDNA(slotData)
                            local after = slotData.last_worn_by and #slotData.last_worn_by or 0
                            if after < before then
                                cleaned = cleaned + 1
                                DirtyPlayers[src] = true
                            end
                        end
                    end
                    for _, slotData in pairs(wearing.Props or {}) do
                        if slotData and slotData.last_worn_by then
                            local before = #slotData.last_worn_by
                            MBT.ServerUtils.CleanExpiredDNA(slotData)
                            local after = slotData.last_worn_by and #slotData.last_worn_by or 0
                            if after < before then
                                cleaned = cleaned + 1
                                DirtyPlayers[src] = true
                            end
                        end
                    end
                end

                if cleaned > 0 then
                    MBT.Debugger("DNA cleanup: purged expired entries from", cleaned, "slot(s)")
                end
            end
        end)
    end
end

function MBT.PlayerState.InitPlayer(src)
    PlayerWearing[src] = { Drawables = {}, Props = {} }
    PlayerDripXp[src] = PlayerDripXp[src] or 0
    DirtyPlayers[src] = false
end

function MBT.PlayerState.SetSlot(src, slotType, slotIndex, metadata)
    -- Safety net multicharacter: se il character è cambiato senza che gli event
    -- framework siano scattati (alcuni multichar non emettono esx:playerLoaded
    -- server-side), rileviamo lo switch qui e reload prima di scrivere.
    if MBT.PlayerState.CheckCharacterSwitch(src) then
        MBT.PlayerState.Load(src)
    end

    slotIndex = tonumber(slotIndex) or slotIndex
    if not PlayerWearing[src] then MBT.PlayerState.InitPlayer(src) end
    PlayerWearing[src][slotType][slotIndex] = metadata
    DirtyPlayers[src] = true
    -- Broadcast for consumers (e.g. mbt_wearable_props capacity).
    -- Server-side event so listeners can recompute without polling.
    TriggerEvent('mbt_meta_clothes:onClothingChanged', src, slotType, slotIndex, metadata)
end

function MBT.PlayerState.GetSlot(src, slotType, slotIndex)
    slotIndex = tonumber(slotIndex) or slotIndex
    if not PlayerWearing[src] then return nil end
    return PlayerWearing[src][slotType][slotIndex]
end

function MBT.PlayerState.ClearSlot(src, slotType, slotIndex)
    -- Safety net multicharacter (vedi nota su SetSlot)
    if MBT.PlayerState.CheckCharacterSwitch(src) then
        MBT.PlayerState.Load(src)
    end

    slotIndex = tonumber(slotIndex) or slotIndex
    if not PlayerWearing[src] then return nil end
    local metadata = PlayerWearing[src][slotType][slotIndex]
    PlayerWearing[src][slotType][slotIndex] = nil
    if metadata then
        DirtyPlayers[src] = true
        TriggerEvent('mbt_meta_clothes:onClothingChanged', src, slotType, slotIndex, nil)
    end
    return metadata
end

function MBT.PlayerState.ClearAllSlots(src, slotType)
    -- Safety net multicharacter
    if MBT.PlayerState.CheckCharacterSwitch(src) then
        MBT.PlayerState.Load(src)
    end

    if not PlayerWearing[src] then return {} end
    local allMetadata = PlayerWearing[src][slotType] or {}
    PlayerWearing[src][slotType] = {}
    if next(allMetadata) then
        DirtyPlayers[src] = true
        TriggerEvent('mbt_meta_clothes:onClothingChanged', src, slotType, nil, nil)
    end
    return allMetadata
end

function MBT.PlayerState.GetAll(src)
    return PlayerWearing[src]
end

function MBT.PlayerState.IsLoaded(src)
    return PlayerWearing[src] ~= nil
end

-----------------------------------------------------------
-- Drip XP functions (cumulative, never decreases)
-----------------------------------------------------------

function MBT.PlayerState.GetDripXp(src)
    return PlayerDripXp[src] or 0
end

function MBT.PlayerState.SetDripXp(src, xp)
    PlayerDripXp[src] = xp
    DirtyPlayers[src] = true
end

function MBT.PlayerState.AddDripXp(src, amount)
    PlayerDripXp[src] = (PlayerDripXp[src] or 0) + amount
    DirtyPlayers[src] = true
end

-----------------------------------------------------------
-- Persistence
-----------------------------------------------------------

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
    local dripXp = PlayerDripXp[src] or 0

    -- Usare la variante sincrona (.await) garantisce che il save completi
    -- prima che il resource muoia in onResourceStop. MySQL.insert async
    -- fire-and-forget può perdersi se la risorsa si ferma subito dopo.
    MySQL.insert.await(
        "INSERT INTO mbt_player_wearing (identifier, wearing_data, drip_xp) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE wearing_data = VALUES(wearing_data), drip_xp = VALUES(drip_xp), updated_at = CURRENT_TIMESTAMP",
        { identifier, data, dripXp }
    )
    DirtyPlayers[src] = false
end

--- Rileva switch di character (multicharacter): se il src ha già stato caricato
--- ma l'identifier è cambiato, salva lo stato vecchio sul suo DB row e resetta
--- le cache. Da chiamare PRIMA di Load() in modo che lo stato del nuovo char
--- venga caricato pulito.
--- @param src number Player source
--- @return boolean switched True se è stato rilevato uno switch
function MBT.PlayerState.CheckCharacterSwitch(src)
    if not getPlayerIdentifier then return false end
    local oldId = PlayerIdentifiers[src]
    if not oldId then return false end

    local newId = getPlayerIdentifier(src)
    if not newId or newId == oldId then return false end

    MBT.Debugger("CheckCharacterSwitch: src", src, "identifier cambiato da", oldId, "a", newId, "- salvo e resetto")

    -- Salva lo stato del vecchio character sulla sua chiave corretta
    if DirtyPlayers[src] and PlayerWearing[src] then
        MBT.PlayerState.Save(src, oldId)
    end

    -- Reset completo in-memory per il nuovo character
    PlayerWearing[src] = nil
    DirtyPlayers[src] = nil
    PlayerIdentifiers[src] = nil
    PlayerHasDbEntry[src] = nil
    PlayerDripXp[src] = nil
    -- Flag: il prossimo playerReady è dovuto a switch, NON deve fare PED scan
    -- (il PED potrebbe avere ancora i drawable del char precedente se
    -- l'appearance script non ha già applicato il nuovo skin)
    PlayerJustSwitched[src] = true
    return true
end

--- Query/consume del flag "ha appena fatto switch". Ritorna true una sola volta
--- per switch — il flag viene azzerato dalla prima chiamata in modo che il
--- successivo playerReady (primo login dopo drop completo) torni a comportarsi
--- come new-player normale.
function MBT.PlayerState.ConsumeSwitchFlag(src)
    local was = PlayerJustSwitched[src] == true
    PlayerJustSwitched[src] = nil
    return was
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

    local result = MySQL.query.await(
        "SELECT wearing_data, drip_xp FROM mbt_player_wearing WHERE identifier = ?",
        { identifier }
    )

    if result and result[1] then
        local row = result[1]
        PlayerDripXp[src] = row.drip_xp or 0
        local ok, decoded = pcall(json.decode, row.wearing_data)
        if ok and decoded and type(decoded) == "table" then
            -- CRITICAL: json.decode creates STRING keys ("3", "11")
            -- but SetSlot/ClearSlot use NUMERIC keys (3, 11).
            -- In Lua, tbl["3"] and tbl[3] are DIFFERENT keys.
            -- Normalize all keys to numeric to prevent ghost entries.
            local normalized = { Drawables = {}, Props = {} }
            for k, v in pairs(decoded.Drawables or {}) do
                if type(v) == "table" then
                    normalized.Drawables[tonumber(k) or k] = v
                end
            end
            for k, v in pairs(decoded.Props or {}) do
                if type(v) == "table" then
                    normalized.Props[tonumber(k) or k] = v
                end
            end
            PlayerWearing[src] = normalized
        else
            MBT.Debugger("PlayerState: corrupted DB data for", identifier, "- resetting")
            MBT.PlayerState.InitPlayer(src)
        end
        PlayerHasDbEntry[src] = true
    else
        MBT.PlayerState.InitPlayer(src)
        PlayerHasDbEntry[src] = false
    end

    DirtyPlayers[src] = false
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
    PlayerDripXp[src] = nil
    PlayerJustSwitched[src] = nil
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
        MBT.Debugger("PlayerState: Periodic save — saved", count, "players")
    end
end
