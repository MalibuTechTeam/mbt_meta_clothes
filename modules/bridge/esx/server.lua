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
-----------------------------------------------------------

-- Carica nuovo character: CheckCharacterSwitch rileva il mismatch e resetta.
-- Se c'è stato uno switch, facciamo subito Load per il nuovo identifier in modo
-- che PlayerIdentifiers[src] sia già aggiornato prima che eventuali Save (es.
-- dal periodico o da playerDropped) possano fire con cache nil.
-- NB: il resume della hybrid detection lo fa il client direttamente quando
-- riceve restoreWearing o requestPedScan (vedi core/client.lua), così la
-- restoreProtection appena attivata parte SUBITO ed è in grado di revertire
-- le modifiche dell'appearance script.
AddEventHandler('esx:playerLoaded', function(src, xPlayer, isNew)
    if MBT.PlayerState.CheckCharacterSwitch(src) then
        MBT.PlayerState.Load(src)
    end
end)

-- Logout (compreso /relog): salva lo stato usando l'identifier ancora
-- valido in cache PRIMA che l'xPlayer venga sostituito dal nuovo character,
-- e mette in pausa la hybrid detection del client per evitare che i
-- drawable applicati dall'appearance script del nuovo char siano attribuiti
-- al char vecchio tramite externalDress.
AddEventHandler('esx:playerLogout', function(src)
    TriggerClientEvent('mbt_meta_clothes:multichar:pauseDetection', src)
    if MBT.PlayerState.IsLoaded(src) then
        MBT.PlayerState.Save(src)
    end
end)

-- Safety net: esx:playerDropped viene emesso anche quando il drop è interno
-- a ESX (es. /relog chiama onPlayerDropped che emette questo event)
AddEventHandler('esx:playerDropped', function(src)
    TriggerClientEvent('mbt_meta_clothes:multichar:pauseDetection', src)
    if MBT.PlayerState.IsLoaded(src) then
        MBT.PlayerState.Save(src)
    end
end)
