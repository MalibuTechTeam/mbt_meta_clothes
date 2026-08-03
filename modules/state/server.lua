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
local PlayerHasBaseline = {}
local PlayerDripXp = {}
local PlayerJustSwitched = {} -- true when CheckCharacterSwitch has detected a switch
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
    -- Multicharacter safety net: if the character changed without the lifecycle
    -- framework events firing (some multichar resources never emit esx:playerLoaded
    -- events firing (some multichar resources only propagate server-side), we
    -- detect the switch here and reload before writing.
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
    -- Multicharacter safety net (see the note on SetSlot)
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

    -- Using the synchronous variant (.await) guarantees the save completes
    -- before the resource dies in onResourceStop. A fire-and-forget async
    -- MySQL.insert can be lost if the resource stops right afterwards.
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

--- Detect a character switch (multicharacter): if this src already has loaded
--- state but the identifier changed, save the old state to its own DB row and
--- reset the caches. Call this BEFORE Load() so the new character state
--- venga caricato pulito.
--- @param src number Player source
--- @return boolean switched True when a switch was detected
function MBT.PlayerState.CheckCharacterSwitch(src)
    if not getPlayerIdentifier then return false end
    local oldId = PlayerIdentifiers[src]
    if not oldId then return false end

    local newId = getPlayerIdentifier(src)
    if not newId or newId == oldId then return false end

    MBT.Debugger("CheckCharacterSwitch: src", src, "identifier cambiato da", oldId, "a", newId, "- salvo e resetto")

    -- Save the outgoing character state under its own correct key
    if DirtyPlayers[src] and PlayerWearing[src] then
        MBT.PlayerState.Save(src, oldId)
    end
    if MBT.SnapshotServer then MBT.SnapshotServer.Cleanup(src) end

    -- Reset completo in-memory per il nuovo character
    PlayerWearing[src] = nil
    DirtyPlayers[src] = nil
    PlayerIdentifiers[src] = nil
    PlayerSaveGenerations[src] = nil
    PlayerHasBaseline[src] = nil
    PlayerDripXp[src] = nil
    -- Flag: the next playerReady comes from a switch and must NOT run a PED scan
    -- (the PED may still carry the previous character drawables if the
    -- appearance script has not applied the new skin yet)
    PlayerJustSwitched[src] = true
    return true
end

--- Query and consume the "just switched" flag. Returns true only once per
--- switch: the first call clears it, so the next playerReady (a first login
--- after a full drop) goes back to behaving
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
        -- NIL IDENTIFIER — do not clear the state. The caller has its own retry
        -- logic: clearing here would lose the previous character PlayerWearing,
        -- possibly unsaved, and we would send an empty restoreWearing.
        -- Initialise empty ONLY when nothing exists yet (a genuine first call).
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
        PlayerHasBaseline[src] = true
        MBT.Debugger('PlayerState.Load: DB hit', { source = src, identifier = identifier })
    else
        MBT.PlayerState.InitPlayer(src)
        PlayerHasBaseline[src] = false
        -- Info, not Debug: a miss sends this player down the PED-scan branch,
        -- which adopts whatever the appearance script put on as the new truth.
        -- For a genuinely new identifier that is correct and happens once. For
        -- an existing player it means their saved outfit was just replaced —
        -- and at MBT.Debug = false nobody would ever see it happen.
        MBT.Info('PlayerState.Load: DB miss — falling back to a PED scan', {
            source = src,
            identifier = identifier,
            switched = PlayerJustSwitched[src] == true,
        })
    end

    DirtyPlayers[src] = false
    PlayerSaveGenerations[src] = PlayerSaveGenerations[src] or 0
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
    PlayerHasBaseline[src] = nil
    PlayerDripXp[src] = nil
    PlayerJustSwitched[src] = nil
end

function MBT.PlayerState.SaveAllDirty()
    -- Save yielda su MySQL.insert.await. Un playerDropped durante lo yield
    -- calls Cleanup, which removes a key from DirtyPlayers OTHER than the current
    -- one. In Lua, removing a non-current key during pairs() is undefined and can
    -- raise "invalid key to 'next'", aborting the save for every remaining player.
    -- So we snapshot the list before yielding.
    local pending = {}
    for src, dirty in pairs(DirtyPlayers) do
        if dirty then pending[#pending + 1] = src end
    end

    local count = 0
    for _, src in ipairs(pending) do
        -- Re-check: meanwhile the player may have left and Cleanup may have
        -- already saved them.
        if DirtyPlayers[src] then
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
-- The push can be driven by the client (playerReady) or by the server (bridge):
-- the latter covers multichar resources that do not propagate the client-side
-- chain, where the PED would otherwise stay paused until the watchdog. The 500ms
-- debounce
-- absorbs the case where both fire for the same load.
local lastPushAt = {} -- [src] = GetGameTimer()

--- Load the player state from the DB (if not already done), pick the branch
--- (restoreWearing existing/empty, or requestPedScan) and trigger
--- il client event corrispondente. Idempotente con debounce 500ms.
--- @param src number Player source
--- @param attempt number Internal: counter retry (default 1)
--- @param force boolean Internal: bypass duplicate-readiness debounce after a detected switch
--- @param lifecycle string|nil Server-owned reason for this state push
function MBT.PlayerState.PushStateToClient(src, attempt, force, lifecycle)
    if not src or src <= 0 then return end
    attempt = attempt or 1

    -- Some multichar resources fire esx:onPlayerJoined before the identifier is
    -- populated: carrying on with nil would mean missing the switch,
    -- azzerare PlayerWearing e mandare un restoreWearing vuoto — player nudo.
    -- Fixed 200ms retry, 8 attempts max; then we give up, because a later
    -- a later event will drive the push again.
    if not getPlayerIdentifier or not getPlayerIdentifier(src) then
        if attempt >= 8 then
            local detail = { source = src, attempts = attempt, elapsedMs = attempt * 200 }
            -- Restart recovery loops over EVERY connected player, including those
            -- sitting in the selector without a character: there a missing
            -- identifier is the normal state and the push will arrive with their
            -- playerLoaded. Warning here would mean one alarm per player in the
            -- selector on every resource restart.
            if lifecycle == MBT.PedVisibility.ResourceRestart then
                MBT.Debugger('PushStateToClient: no character yet; deferring to next lifecycle trigger', detail)
            else
                MBT.Warn('PushStateToClient: identifier unavailable; waiting for next lifecycle trigger', detail)
            end
            return
        end
        Citizen.SetTimeout(200, function()
            -- Make sure the player has not disconnected in the meantime
            if GetPlayerName(src) then
                MBT.PlayerState.PushStateToClient(src, attempt + 1, force, lifecycle)
            end
        end)
        return
    end

    local now = GetGameTimer()
    if not force and lastPushAt[src] and (now - lastPushAt[src]) < 500 then
        -- Debounce: skip silently, we pushed recently.
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
        -- A new player and a new character take the same route: requestPedScan.
        -- An empty restoreWearing would apply the MBT.Drawables defaults and
        -- would fight the appearance script that is applying the real skin.
        -- The scan instead lets it work and reads the result once it is stable.
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

--- Clear the debounce when the player disconnects
AddEventHandler('playerDropped', function()
    lastPushAt[source] = nil
end)
