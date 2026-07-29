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
local PlayerRevisions = {}
local PlayerSaveGenerations = {}
local PlayerHasDbEntry = {}
local PlayerHasBaseline = {}
local PlayerDripXp = {}
local PlayerJustSwitched = {} -- true quando CheckCharacterSwitch ha rilevato uno switch
local initialized = false

local function markDirty(src)
    DirtyPlayers[src] = true
    PlayerSaveGenerations[src] = (PlayerSaveGenerations[src] or 0) + 1
end

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
                                markDirty(src)
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
                                markDirty(src)
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
    PlayerRevisions[src] = PlayerRevisions[src] or 0
    PlayerSaveGenerations[src] = PlayerSaveGenerations[src] or 0
    DirtyPlayers[src] = false
    PlayerHasBaseline[src] = PlayerHasBaseline[src] or false
end

local function touchRevision(src)
    PlayerRevisions[src] = (PlayerRevisions[src] or 0) + 1
    local revision = PlayerRevisions[src]
    if MBT.SnapshotServer and MBT.SnapshotServer.OnRevisionChanged then
        MBT.SnapshotServer.OnRevisionChanged(src, revision)
    end
    return revision
end

function MBT.PlayerState.GetRevision(src)
    return PlayerRevisions[src] or 0
end

function MBT.PlayerState.GetIdentifier(src)
    return PlayerIdentifiers[src]
end

function MBT.PlayerState.IsSaveGuardCurrent(expectedIdentifier, expectedGeneration, currentIdentifier, currentGeneration)
    return expectedIdentifier ~= nil
        and expectedIdentifier == currentIdentifier
        and expectedGeneration == currentGeneration
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
    markDirty(src)
    touchRevision(src)
    -- Broadcast for consumers (e.g. mbt_wearable_props capacity).
    -- Server-side event so listeners can recompute without polling.
    TriggerEvent('mbt_meta_clothes:onClothingChanged', src, slotType, slotIndex, metadata, 'state')
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
        markDirty(src)
        touchRevision(src)
        TriggerEvent('mbt_meta_clothes:onClothingChanged', src, slotType, slotIndex, nil, 'state')
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
        markDirty(src)
        touchRevision(src)
        TriggerEvent('mbt_meta_clothes:onClothingChanged', src, slotType, nil, nil, 'state')
    end
    return allMetadata
end

function MBT.PlayerState.GetAll(src)
    return PlayerWearing[src]
end

function MBT.PlayerState.IsLoaded(src)
    return PlayerWearing[src] ~= nil
end

--- Atomically replace the wearing state produced by snapshot reconciliation.
--- @return integer revision
function MBT.PlayerState.CommitSnapshot(src, nextState, changes)
    if type(nextState) ~= 'table' or type(changes) ~= 'table' then
        return MBT.PlayerState.GetRevision(src)
    end
    if #changes == 0 then return MBT.PlayerState.GetRevision(src) end

    PlayerWearing[src] = nextState
    markDirty(src)
    local revision = touchRevision(src)
    for _, change in ipairs(changes) do
        TriggerEvent(
            'mbt_meta_clothes:onClothingChanged',
            src,
            change.slotType,
            change.slotIndex,
            change.metadata,
            'snapshot'
        )
    end
    return revision
end

local function validVisual(slotType, slotIndex, visual)
    local valid, normalizedIndex = MBT.ServerUtils.ValidateSlot(slotType, slotIndex)
    if not valid or type(visual) ~= 'table' then return nil, 'invalid_slot' end
    local drawableBounds = slotType == 'Drawables'
        and MBT.SnapshotBounds.componentDrawable
        or MBT.SnapshotBounds.propDrawable
    local palette = visual.palette == nil and 0 or visual.palette
    local function boundedInteger(value, bounds)
        return type(value) == 'number' and value == value and value % 1 == 0
            and value >= bounds.min and value <= bounds.max
    end
    if not boundedInteger(visual.drawable, drawableBounds)
        or not boundedInteger(visual.texture, MBT.SnapshotBounds.texture)
        or not boundedInteger(palette, MBT.SnapshotBounds.palette) then
        return nil, 'invalid_visual'
    end
    return {
        index = normalizedIndex,
        drawable = visual.drawable,
        texture = visual.texture,
        palette = palette,
    }
end

--- Persist an MBT-owned visual variant while preserving trusted rich metadata.
function MBT.PlayerState.UpdateSlotVisual(src, slotType, slotIndex, visual)
    local normalized, reason = validVisual(slotType, slotIndex, visual)
    if not normalized then return false, reason end
    if MBT.PlayerState.CheckCharacterSwitch(src) then MBT.PlayerState.Load(src) end
    local current = MBT.PlayerState.GetSlot(src, slotType, normalized.index)
    if not current then return false, 'missing_metadata' end
    if current.drawable == normalized.drawable
        and current.texture == normalized.texture
        and (current.palette or 0) == normalized.palette then
        return false, MBT.PlayerState.GetRevision(src)
    end

    local updated = {}
    for key, value in pairs(current) do updated[key] = value end
    updated.index = normalized.index
    updated.drawable = normalized.drawable
    updated.texture = normalized.texture
    updated.palette = normalized.palette
    PlayerWearing[src][slotType][normalized.index] = updated
    markDirty(src)
    local revision = touchRevision(src)
    TriggerEvent(
        'mbt_meta_clothes:onClothingChanged',
        src,
        slotType,
        normalized.index,
        updated,
        'internal_visual'
    )
    return true, revision
end

-----------------------------------------------------------
-- Drip XP functions (cumulative, never decreases)
-----------------------------------------------------------

function MBT.PlayerState.GetDripXp(src)
    return PlayerDripXp[src] or 0
end

function MBT.PlayerState.SetDripXp(src, xp)
    PlayerDripXp[src] = xp
    markDirty(src)
end

function MBT.PlayerState.AddDripXp(src, amount)
    PlayerDripXp[src] = (PlayerDripXp[src] or 0) + amount
    markDirty(src)
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
    local saveGeneration = PlayerSaveGenerations[src] or 0

    -- Usare la variante sincrona (.await) garantisce che il save completi
    -- prima che il resource muoia in onResourceStop. MySQL.insert async
    -- fire-and-forget può perdersi se la risorsa si ferma subito dopo.
    MySQL.insert.await(
        "INSERT INTO mbt_player_wearing (identifier, wearing_data, drip_xp) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE wearing_data = VALUES(wearing_data), drip_xp = VALUES(drip_xp), updated_at = CURRENT_TIMESTAMP",
        { identifier, data, dripXp }
    )
    -- The await yields to other handlers. Preserve a newer dirty state instead
    -- of marking it as persisted by this older database write.
    local saveCurrent = MBT.PlayerState.IsSaveGuardCurrent(
        identifier,
        saveGeneration,
        PlayerIdentifiers[src],
        PlayerSaveGenerations[src] or 0
    )
    if saveCurrent then
        DirtyPlayers[src] = false
        if MBT.SnapshotServer and MBT.SnapshotServer.CancelPendingSave then
            MBT.SnapshotServer.CancelPendingSave(src)
        end
    end
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
    if MBT.SnapshotServer then MBT.SnapshotServer.Cleanup(src) end

    -- Reset completo in-memory per il nuovo character
    PlayerWearing[src] = nil
    DirtyPlayers[src] = nil
    PlayerIdentifiers[src] = nil
    PlayerSaveGenerations[src] = nil
    PlayerHasDbEntry[src] = nil
    PlayerHasBaseline[src] = nil
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
        -- IDENTIFIER NIL — non azzerare lo stato! Il caller (es. PushStateToClient)
        -- ha la sua logica di retry e si aspetta di poter ritentare. Se chiamassimo
        -- InitPlayer qui, perderemmo PlayerWearing del char precedente (che potrebbe
        -- non essere ancora stato salvato) e PlayerHasDbEntry resterebbe stantio
        -- → restoreWearing inviato vuoto al client → player nudo.
        --
        -- Init a vuoto SOLO se PlayerWearing[src] non esiste ancora (truly first call).
        if not PlayerWearing[src] then
            MBT.PlayerState.InitPlayer(src)
        end
        MBT.Warn('PlayerState.Load: identifier unavailable; preserving current state', { source = src })
        return
    end

    if PlayerIdentifiers[src] ~= identifier then
        PlayerRevisions[src] = 0
        PlayerSaveGenerations[src] = 0
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
        PlayerHasBaseline[src] = true
        MBT.Debugger('PlayerState.Load: DB hit', { source = src, identifier = identifier })
    else
        MBT.PlayerState.InitPlayer(src)
        PlayerHasDbEntry[src] = false
        PlayerHasBaseline[src] = false
        MBT.Debugger('PlayerState.Load: DB miss', {
            source = src,
            identifier = identifier,
            switched = PlayerJustSwitched[src] == true,
        })
    end

    DirtyPlayers[src] = false
    PlayerSaveGenerations[src] = PlayerSaveGenerations[src] or 0
end

--- Check if a player has an existing DB record
--- Used by syncInitialWearing to skip PED scan for returning players
--- @param src number Player source
--- @return boolean
function MBT.PlayerState.HasDbEntry(src)
    return PlayerHasDbEntry[src] == true
end


function MBT.PlayerState.HasBaseline(src)
    return PlayerHasBaseline[src] == true
end

function MBT.PlayerState.MarkBaseline(src)
    PlayerHasBaseline[src] = true
end

function MBT.PlayerState.Cleanup(src, discard)
    if DirtyPlayers[src] and not discard then
        MBT.PlayerState.Save(src)
    end
    PlayerWearing[src] = nil
    DirtyPlayers[src] = nil
    PlayerIdentifiers[src] = nil
    PlayerRevisions[src] = nil
    PlayerSaveGenerations[src] = nil
    PlayerHasDbEntry[src] = nil
    PlayerHasBaseline[src] = nil
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

-----------------------------------------------------------
-- Push state to client (load + decide branch + trigger client event)
-----------------------------------------------------------
-- Estratto da playerReady handler così sia il client (via playerReady event)
-- sia il server (via esx:playerLoaded bridge handler) possono guidare il push.
-- Indispensabile per multichar che bypassano il client-side esx:playerLoaded
-- chain (es. mbt_character fast-switch): senza questo, il ped resta in pausa
-- finché il watchdog client non scatta a 5s.
--
-- Idempotente: se chiamato di nuovo entro 500ms per lo stesso src, no-op.
-- Questo evita doppio push quando entrambi i flow (server bridge + client
-- playerReady) firano per lo stesso load event.
local lastPushAt = {} -- [src] = GetGameTimer()

--- Carica lo stato del player dal DB (se non già fatto), decide quale branch
--- prendere (restoreWearing existing/empty oppure requestPedScan) e triggera
--- il client event corrispondente. Idempotente con debounce 500ms.
--- @param src number Player source
--- @param attempt number Internal: counter retry (default 1)
--- @param force boolean Internal: bypass duplicate-readiness debounce after a detected switch
--- @param lifecycle string|nil Server-owned reason for this state push
function MBT.PlayerState.PushStateToClient(src, attempt, force, lifecycle)
    if not src or src <= 0 then return end
    attempt = attempt or 1

    -- IDENTIFIER READINESS GUARD
    -- Alcuni multichar (mbt_character, esx_multicharacter veloce ecc.) emettono
    -- esx:onPlayerJoined PRIMA che ESX.GetPlayerFromId(src).identifier sia
    -- popolato. Nei 50-300ms successivi xPlayer è parzialmente inizializzato
    -- ma .identifier è ancora nil. Se proseguiamo:
    --   1. CheckCharacterSwitch vede newId=nil → ritorna false (non rileva lo switch)
    --   2. Load vede identifier=nil → early return con InitPlayer (AZZERA PlayerWearing)
    --   3. PlayerHasDbEntry resta TRUE (residuo del char precedente)
    --   4. PushStateToClient invia restoreWearing con state VUOTO → player nudo
    --
    -- Soluzione: retry a intervallo fisso di 200ms, max 8 tentativi (~1.4s).
    -- Se dopo l'ottavo tentativo l'identifier è ancora nil,
    -- abbandoniamo silenziosamente — un altro evento (es. esx:playerLoaded
    -- che firerà più tardi) rilancerà PushStateToClient.
    if not getPlayerIdentifier or not getPlayerIdentifier(src) then
        if attempt >= 8 then
            local detail = { source = src, attempts = attempt, elapsedMs = attempt * 200 }
            -- Il recovery del restart cicla su TUTTI i connessi, compresi quelli
            -- fermi nel selector senza character: lì l'identifier assente è lo
            -- stato normale e il push arriverà col loro playerLoaded. Warnare
            -- significherebbe un allarme per ogni giocatore nel selector a ogni
            -- restart della risorsa.
            if lifecycle == MBT.PedVisibility.ResourceRestart then
                MBT.Debugger('PushStateToClient: no character yet; deferring to next lifecycle trigger', detail)
            else
                MBT.Warn('PushStateToClient: identifier unavailable; waiting for next lifecycle trigger', detail)
            end
            return
        end
        Citizen.SetTimeout(200, function()
            -- Verifica che il player non si sia disconnesso nel frattempo
            if GetPlayerName(src) then
                MBT.PlayerState.PushStateToClient(src, attempt + 1, force, lifecycle)
            end
        end)
        return
    end

    local now = GetGameTimer()
    if not force and lastPushAt[src] and (now - lastPushAt[src]) < 500 then
        -- Debounce: skip silenziosamente. Già pushato di recente.
        return
    end
    lastPushAt[src] = now

    -- Multicharacter safety: reload only for a new/unloaded identifier. A
    -- duplicate readiness event must not overwrite newer dirty memory from DB.
    local identifier = getPlayerIdentifier(src)
    local switched = MBT.PlayerState.CheckCharacterSwitch(src)
    if switched or not MBT.PlayerState.IsLoaded(src)
        or MBT.PlayerState.GetIdentifier(src) ~= identifier then
        MBT.PlayerState.Load(src, identifier)
    end
    local context = MBT.SnapshotServer.Activate(src, MBT.PlayerState.GetIdentifier(src))
    if not context then return end

    if MBT.PlayerState.HasBaseline(src) then
        local wearingState = MBT.PlayerState.GetAll(src)
        MBT.Debugger('PushStateToClient: restoring existing wearing state', {
            source = src,
            lifecycle = lifecycle,
        })
        TriggerClientEvent('mbt_meta_clothes:restoreWearing', src, wearingState, context, lifecycle)
    else
        -- Sia "truly new player" sia "switched-to new char" → requestPedScan.
        --
        -- In passato lo switch-flag triggherava un restoreWearing vuoto per
        -- "ripulire" il PED dai drawable del char precedente. Ma applyWearingState
        -- vuoto applica i DEFAULT degli MBT.Drawables (slot 3 = 15, ecc.) → questo
        -- combatte contro illenium-appearance che sta applicando il vero skin del
        -- nuovo char e li sovrascrive con default vanilla.
        --
        -- requestPedScan lascia applicare la skin esterna; il client invia una
        -- visuale completa rimasta stabile per il debounce. Il server valida
        -- struttura e limiti, senza trattare drawable 0/default come una skin
        -- necessariamente incompleta: sono stati legittimi per molti script.
        local justSwitched = MBT.PlayerState.ConsumeSwitchFlag(src)
        MBT.Debugger('PushStateToClient: requesting initial PED scan', {
            source = src,
            switched = justSwitched,
            lifecycle = lifecycle,
        })
        TriggerClientEvent('mbt_meta_clothes:requestPedScan', src, context, lifecycle)
    end

    if MBT.UpdateStateBags then
        MBT.UpdateStateBags(src)
    end
end

--- Cleanup del debounce quando il player si disconnette
AddEventHandler('playerDropped', function()
    lastPushAt[source] = nil
end)
