-----------------------------------------------------------
-- Lifecycle tracer (client, debug only)
--
-- Esiste perché le misure fatte leggendo i log normali hanno una granularità di
-- UN SECONDO, mentre le finestre che dobbiamo rispettare sono da 400ms. Con
-- barre d'errore più grandi del fenomeno si indovina, non si misura.
--
-- Tre domande a cui deve rispondere:
--   1. quanto dura la finestra in cui lo schermo è nero (il giocatore non vede)
--   2. dove ci cade dentro il nostro reveal
--   3. CHI cambia l'alpha del PED oltre a noi
--
-- La terza è la più importante: l'alpha è una proprietà condivisa e i
-- multicharacter la scrivono anche loro. Registrando quale valore abbiamo
-- impostato NOI, ogni cambiamento diverso è per esclusione di qualcun altro.
-----------------------------------------------------------

MBT.Trace = MBT.Trace or {}

if not MBT.Debug then
    function MBT.Trace.Mark() end
    function MBT.Trace.Begin() end
    function MBT.Trace.OwnAlpha() end
    return
end

-- L'orologio parte dall'avvio della risorsa, così anche gli eventi che
-- precedono la prima transizione hanno tempi relativi leggibili invece di t=+0.
local originAt = GetGameTimer()
local expectedAlpha
local pendingOurWrite = false
local lastAlpha
local lastFaded

local function pedAlpha()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return nil end
    return GetEntityAlpha(ped)
end

--- Ordina le chiavi: due esecuzioni della stessa sequenza devono produrre righe
--- confrontabili a occhio, altrimenti diffare due log diventa impossibile.
local function formatDetail(detail)
    if type(detail) ~= 'table' then
        return detail ~= nil and tostring(detail) or ''
    end
    local keys = {}
    for key in pairs(detail) do keys[#keys + 1] = tostring(key) end
    table.sort(keys)
    local parts = {}
    for _, key in ipairs(keys) do
        parts[#parts + 1] = ('%s=%s'):format(key, tostring(detail[key]))
    end
    return table.concat(parts, ' ')
end

--- Apre una nuova finestra di misura. Da qui in poi i tempi sono relativi.
function MBT.Trace.Begin(reason)
    originAt = GetGameTimer()
    MBT.Trace.Mark('BEGIN', { reason = reason })
end

function MBT.Trace.Mark(event, detail)
    local at = GetGameTimer()
    local rel = originAt and (at - originAt) or 0
    local alpha = pedAlpha()
    print(('^5[CLOTH][TRACE]^7 t=%+7d  %-22s alpha=%-4s faded=%s  %s^0'):format(
        rel,
        tostring(event),
        alpha == nil and 'none' or tostring(alpha),
        IsScreenFadedOut() and 'Y' or (IsScreenFadingIn() and '~' or 'n'),
        formatDetail(detail)
    ))
end

--- Dichiara che stiamo per scrivere noi quel valore di alpha.
--- Attribuire confrontando solo il VALORE non funziona: se noi mettiamo 0 e poi
--- qualcun altro rimette 0, il confronto direbbe "nostro". Serve un annuncio che
--- il watcher consuma: una variazione è nostra solo se l'abbiamo dichiarata
--- dall'ultima variazione osservata.
function MBT.Trace.OwnAlpha(value)
    expectedAlpha = value
    pendingOurWrite = true
end

-- Campionamento a ogni frame: una contesa fra due scrittori gira alla cadenza
-- del loop più veloce (50ms nel nostro caso), quindi campionare più lentamente
-- la renderebbe invisibile proprio quando serve vederla.
CreateThread(function()
    while true do
        Wait(0)

        local alpha = pedAlpha()
        if alpha ~= lastAlpha then
            if lastAlpha ~= nil then
                local mine = pendingOurWrite and alpha == expectedAlpha
                MBT.Trace.Mark(mine and 'alpha:ours' or 'alpha:FOREIGN', {
                    from = lastAlpha,
                    to = alpha,
                })
            end
            pendingOurWrite = false
            lastAlpha = alpha
        end

        local faded = IsScreenFadedOut()
        if faded ~= lastFaded then
            if lastFaded ~= nil then
                MBT.Trace.Mark(faded and 'screen:black' or 'screen:visible')
            end
            lastFaded = faded
        end
    end
end)
