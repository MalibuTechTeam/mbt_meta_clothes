if GetResourceState('es_extended') ~= 'started' then return end

ESX = exports.es_extended:getSharedObject()

local isOXInventory = GetResourceState('ox_inventory'):find('start')

-- Inventory-agnostic addItem: tries OX → Custom fallback
local function addItem(src, itemName, count, metadata)
    if isOXInventory then
        exports.ox_inventory:AddItem(src, itemName, count, metadata)
    else
        if type(MBT.CustomInventory) == 'function' then
            MBT.CustomInventory(itemName, metadata)
        else
            MBT.ServerUtils.PrintWarning()
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
-- Multicharacter switch — server-side handlers
-- Analisi flusso esx_multicharacter:
--  /relog → esx_multicharacter:relog → esx:playerLogout (SERVER) →
--           ES core chiama onPlayerDropped() → emette esx:playerDropped
--  character scelto → esx:playerLoaded (SERVER) con xPlayer nuovo
-- NB: esx:onPlayerLogout è CLIENT-side (TriggerClientEvent), NON scatta sul server.
--
-- COMPATIBILITÀ MULTICHAR ALTERNATIVI:
-- Alcuni multichar (es. mbt_character con fast-switch) emettono solo
-- esx:onPlayerJoined senza che ES core triggeri esx:playerLoaded a valle —
-- in quei casi il flow "load del nuovo char" non si chiude e il client resta
-- in pausa keepPedHidden. Per coprire questo edge case ascoltiamo anche
-- esx:onPlayerJoined come trigger alternativo per CheckCharacterSwitch.
-----------------------------------------------------------

-- Track delle pause attive: serve al watchdog server-side per sapere se
-- una pause è scaduta senza un load corrispondente (= nessun playerReady
-- è arrivato dal client per quel src nei N secondi successivi al logout).
local pendingPauseSince = {} -- [src] = GetGameTimer() del logout

-- Diagnostic logs: stampati SEMPRE (no MBT.Debug gate) così quando il bug
-- si manifesta in produzione abbiamo subito la timeline completa degli event
-- per capire QUALE step della catena ESX→multichar non si chiude.
local function logEsxEvent(name, src, extra)
    print(("^6[mbt_meta_clothes][esx-bridge] %s src=%s%s^0"):format(
        name, tostring(src), extra and (" " .. extra) or ""
    ))
end

-- Carica nuovo character — guida direttamente il push al client.
--
-- IMPORTANTE: NON ci basiamo sul client esx:playerLoaded handler per inviare
-- playerReady a noi. Alcuni multichar (mbt_character fast-switch) propagano
-- esx:playerLoaded server-side ma NON client-side, lasciando il nostro flow
-- bloccato. Chiamando PushStateToClient direttamente qui, il flow funziona
-- indipendentemente dal client-event chain di ESX.
--
-- PushStateToClient è debounced 500ms — se il client ALSO manda playerReady,
-- la seconda chiamata è no-op silenzioso.
AddEventHandler('esx:playerLoaded', function(src, xPlayer, isNew)
    logEsxEvent("esx:playerLoaded", src, "isNew=" .. tostring(isNew))
    pendingPauseSince[src] = nil
    MBT.PlayerState.PushStateToClient(src)
end)

-- Fallback per multichar che non fanno fire esx:playerLoaded a valle di
-- esx:onPlayerJoined. Aspettiamo 50ms per dare tempo allo xPlayer di esistere
-- in ESX.GetPlayerFromId, poi push. Se esx:playerLoaded fira anche, il
-- debounce 500ms in PushStateToClient evita la doppia chiamata.
AddEventHandler('esx:onPlayerJoined', function(src)
    logEsxEvent("esx:onPlayerJoined", src)
    Citizen.SetTimeout(50, function()
        pendingPauseSince[src] = nil
        MBT.PlayerState.PushStateToClient(src)
    end)
end)

-- Logout (compreso /relog): salva lo stato usando l'identifier ancora
-- valido in cache PRIMA che l'xPlayer venga sostituito dal nuovo character,
-- e mette in pausa la hybrid detection del client per evitare che i
-- drawable applicati dall'appearance script del nuovo char siano attribuiti
-- al char vecchio tramite externalDress.
AddEventHandler('esx:playerLogout', function(src)
    logEsxEvent("esx:playerLogout", src)
    TriggerClientEvent('mbt_meta_clothes:multichar:pauseDetection', src)
    pendingPauseSince[src] = GetGameTimer()
    if MBT.PlayerState.IsLoaded(src) then
        MBT.PlayerState.Save(src)
    end
    -- Server-side watchdog: se entro 4s nessun playerLoaded/onPlayerJoined
    -- ha resettato pendingPauseSince[src], significa che la catena del
    -- multichar si è rotta e il client è bloccato in pausa. Forziamo manualmente
    -- un restoreWearing vuoto al client per sbloccarlo (e aggiungiamo un WARN).
    -- 4s < 5s del watchdog client così se entrambi sono attivi, scatta prima
    -- questo (più informativo) e il client riceve l'unblock prima di doversi
    -- auto-recoverare.
    Citizen.SetTimeout(4000, function()
        if pendingPauseSince[src] then
            print(("^3[mbt_meta_clothes][esx-bridge] WARN: 4s after esx:playerLogout for src=%s no esx:playerLoaded/onPlayerJoined arrived — forcing client unblock^0"):format(src))
            pendingPauseSince[src] = nil
            -- Trigger un restoreWearing vuoto sul client. Se il src non è più
            -- valido (player disconnesso), TriggerClientEvent è no-op.
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
end)

-- playerDropped (FiveM nativo): cleanup del watchdog tracking se il player
-- esce davvero (non un /relog interno). Evita leak di memoria su pendingPauseSince.
AddEventHandler('playerDropped', function()
    pendingPauseSince[source] = nil
end)
