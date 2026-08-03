if GetResourceState('es_extended') ~= 'started' then return end

ESX = exports.es_extended:getSharedObject()

local isOXInventory = GetResourceState('ox_inventory'):find('start')

-- Inventory-agnostic addItem: tries OX → Custom fallback
local function addItem(src, itemName, count, metadata)
    if isOXInventory then
        local success, response = exports.ox_inventory:AddItem(src, itemName, count, metadata)
        return MBT.GiveItems.NormalizeAddResult(success, response)
    else
        if type(MBT.CustomInventory) == 'function' then
            return MBT.GiveItems.CallCustom(MBT.CustomInventory, src, itemName, count, metadata)
        else
            MBT.ServerUtils.PrintWarning()
            return false, 'unsupported_inventory'
        end
    end
end

-- Setup shared give* global functions
MBT.GiveItems.Setup({
    getPlayer = function(src) return ESX.GetPlayerFromId(src) end,
    getPlayerName = function(player) return player.getName() end,
    getPlayerSource = function(player) return player.source end,
    addItem = addItem
})

---@param src number
---@return string
function getPlayerIdentifier(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer then return xPlayer.identifier end
end

-----------------------------------------------------------
-- Multicharacter switch — handler server-side
--
-- esx_multicharacter flow: /relog → esx:playerLogout → onPlayerDropped →
-- esx:playerDropped; once a character is chosen → esx:playerLoaded with the new
-- xPlayer. `esx:onPlayerLogout` is client-side and never fires on the server.
--
-- Some multichar resources (mbt_character in fast-switch) only fire
-- esx:onPlayerJoined without ES core propagating esx:playerLoaded: without an
-- alternative trigger the load never closes and the client stays paused.
-----------------------------------------------------------

-- [src] = GetGameTimer() at logout. The watchdog uses it to notice a pause that
-- expired without its matching load.
local pendingPauseSince = {}

local function logEsxEvent(name, src, extra)
    MBT.Debugger('esx bridge lifecycle', {
        event = name,
        source = src,
        detail = extra,
    })
end

-- The server drives the push, not the client's playerReady: some multichar
-- resources propagate esx:playerLoaded server-side but not client-side, and the
-- flow would stall. If it also arrives from the client, the 500ms debounce
-- absorbs it.
AddEventHandler('esx:playerLoaded', function(src, xPlayer, isNew)
    logEsxEvent("esx:playerLoaded", src, "isNew=" .. tostring(isNew))
    pendingPauseSince[src] = nil
    MBT.PlayerState.PushStateToClient(src)
end)

-- Fallback for setups that do not propagate esx:playerLoaded. The 50ms give the
-- xPlayer time to show up in ESX.GetPlayerFromId.
AddEventHandler('esx:onPlayerJoined', function(src)
    logEsxEvent("esx:onPlayerJoined", src)
    Citizen.SetTimeout(50, function()
        pendingPauseSince[src] = nil
        MBT.PlayerState.PushStateToClient(src)
    end)
end)

local UNBLOCK_POLL_INTERVAL = 4000
local UNBLOCK_DEADLINE = 120000

--- Unblocks a client left paused because the multichar chain never closed.
---
--- Sitting in a character selector is NOT a fault: the player has no character
--- until they choose, which can take a minute. Unblocking there is actively
--- harmful — it sends an empty restoreWearing and reveals the PED wearing
--- whatever the appearance script last applied, which is exactly the flash we
--- spent this whole subsystem removing. So we re-arm while no identifier
--- exists, and only give up at a deadline generous enough for a human.
---
--- A missing load WITH an identifier already present is a different story:
--- that chain really did break, and it is worth a warning immediately.
local function scheduleUnblockCheck(src, pauseStartedAt)
    Citizen.SetTimeout(UNBLOCK_POLL_INTERVAL, function()
        -- A newer logout replaces the timestamp: this check belongs to a chain
        -- that is no longer current.
        if pendingPauseSince[src] ~= pauseStartedAt then return end

        local elapsed = GetGameTimer() - pauseStartedAt
        local detail = { source = src, elapsedMs = elapsed }
        local hasIdentifier = getPlayerIdentifier and getPlayerIdentifier(src)

        if hasIdentifier then
            MBT.Warn('esx bridge: load event missing after logout; forcing client unblock', detail)
        elseif elapsed < UNBLOCK_DEADLINE then
            return scheduleUnblockCheck(src, pauseStartedAt)
        else
            MBT.Warn('esx bridge: no character chosen before the selector deadline; unblocking client', detail)
        end

        pendingPauseSince[src] = nil
        TriggerClientEvent('mbt_meta_clothes:restoreWearing', src, { Drawables = {}, Props = {} })
    end)
end

-- Logout (including /relog): save the state while the identifier is still valid
-- in cache, BEFORE the xPlayer is replaced by the new character, and pause the
-- client so the new character's drawables do not land on the old one.
AddEventHandler('esx:playerLogout', function(src)
    logEsxEvent("esx:playerLogout", src)
    TriggerClientEvent('mbt_meta_clothes:multichar:pauseDetection', src)
    local pauseStartedAt = GetGameTimer()
    pendingPauseSince[src] = pauseStartedAt
    if MBT.PlayerState.IsLoaded(src) then
        MBT.PlayerState.Save(src)
    end
    MBT.SnapshotServer.Cleanup(src)
    scheduleUnblockCheck(src, pauseStartedAt)
end)

-- Safety net: esx:playerDropped is fired even when the drop is internal to ESX
-- (e.g. /relog calls onPlayerDropped, which fires this event)
AddEventHandler('esx:playerDropped', function(src)
    logEsxEvent("esx:playerDropped", src)
    TriggerClientEvent('mbt_meta_clothes:multichar:pauseDetection', src)
    if MBT.PlayerState.IsLoaded(src) then
        MBT.PlayerState.Save(src)
    end
    MBT.SnapshotServer.Cleanup(src)
end)

-- A real drop (not an internal /relog): keeps pendingPauseSince from growing.
AddEventHandler('playerDropped', function()
    pendingPauseSince[source] = nil
end)
