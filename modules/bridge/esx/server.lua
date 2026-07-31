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
-- Flusso esx_multicharacter: /relog → esx:playerLogout → onPlayerDropped →
-- esx:playerDropped; scelto il character → esx:playerLoaded col nuovo xPlayer.
-- `esx:onPlayerLogout` è client-side e sul server non scatta.
--
-- Alcuni multichar (mbt_character in fast-switch) emettono solo
-- esx:onPlayerJoined senza che ES core propaghi esx:playerLoaded: senza un
-- trigger alternativo il load non si chiude e il client resta in pausa.
-----------------------------------------------------------

-- [src] = GetGameTimer() del logout. Serve al watchdog per accorgersi di una
-- pausa scaduta senza il load corrispondente.
local pendingPauseSince = {}

local function logEsxEvent(name, src, extra)
    MBT.Debugger('esx bridge lifecycle', {
        event = name,
        source = src,
        detail = extra,
    })
end

-- Il push lo guida il server, non il playerReady del client: alcuni multichar
-- propagano esx:playerLoaded server-side ma non client-side, e il flow resterebbe
-- bloccato. Se poi arriva anche dal client, il debounce da 500ms lo assorbe.
AddEventHandler('esx:playerLoaded', function(src, xPlayer, isNew)
    logEsxEvent("esx:playerLoaded", src, "isNew=" .. tostring(isNew))
    pendingPauseSince[src] = nil
    MBT.PlayerState.PushStateToClient(src)
end)

-- Fallback per chi non propaga esx:playerLoaded. I 50ms danno allo xPlayer il
-- tempo di comparire in ESX.GetPlayerFromId.
AddEventHandler('esx:onPlayerJoined', function(src)
    logEsxEvent("esx:onPlayerJoined", src)
    Citizen.SetTimeout(50, function()
        pendingPauseSince[src] = nil
        MBT.PlayerState.PushStateToClient(src)
    end)
end)

-- Logout (compreso /relog): salva lo stato con l'identifier ancora valido in
-- cache, PRIMA che l'xPlayer venga sostituito dal nuovo character, e mette in
-- pausa il client perché i drawable del char nuovo non finiscano sul vecchio.
AddEventHandler('esx:playerLogout', function(src)
    logEsxEvent("esx:playerLogout", src)
    TriggerClientEvent('mbt_meta_clothes:multichar:pauseDetection', src)
    pendingPauseSince[src] = GetGameTimer()
    if MBT.PlayerState.IsLoaded(src) then
        MBT.PlayerState.Save(src)
    end
    MBT.SnapshotServer.Cleanup(src)
    -- Se entro 4s nessun load ha resettato pendingPauseSince, la catena del
    -- multichar si è rotta e il client resta in pausa: lo sblocchiamo. 4s sta
    -- sotto i 5s del watchdog client, così l'unblock arriva prima dell'auto
    -- recovery ed è più informativo.
    Citizen.SetTimeout(4000, function()
        if pendingPauseSince[src] then
            -- Con un multichar a selector il player resta senza character finché
            -- non sceglie, anche per un minuto: è attesa legittima. Solo un load
            -- mancante CON identifier già presente è un guasto vero — da cui il
            -- livello di log diverso, altrimenti l'allarme scatta a ogni relog.
            local detail = { source = src, timeoutMs = 4000 }
            if getPlayerIdentifier and getPlayerIdentifier(src) then
                MBT.Warn('esx bridge: load event missing after logout; forcing client unblock', detail)
            else
                MBT.Debugger('esx bridge: no character after logout (selector); unblocking client', detail)
            end
            pendingPauseSince[src] = nil
            TriggerClientEvent('mbt_meta_clothes:restoreWearing', src, { Drawables = {}, Props = {} })
        end
    end)
end)

-- Safety net: esx:playerDropped viene emesso anche quando il drop è interno
-- a ESX (es. /relog chiama onPlayerDropped che emette questo event)
AddEventHandler('esx:playerDropped', function(src)
    logEsxEvent("esx:playerDropped", src)
    TriggerClientEvent('mbt_meta_clothes:multichar:pauseDetection', src)
    if MBT.PlayerState.IsLoaded(src) then
        MBT.PlayerState.Save(src)
    end
    MBT.SnapshotServer.Cleanup(src)
end)

-- Drop vero (non /relog interno): evita che pendingPauseSince accumuli voci.
AddEventHandler('playerDropped', function()
    pendingPauseSince[source] = nil
end)
