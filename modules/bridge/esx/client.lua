if GetResourceState('es_extended') ~= 'started' then return end

ESX = exports.es_extended:getSharedObject()

-- If this resource is ensured while an ESX player is already active, the next
-- playerLoaded event is a real character switch and must not be discarded.
local playerReadySent = ESX.IsPlayerLoaded()

-- First login: hide PED to prevent clothing flash
AddEventHandler('esx:loadingScreenOff', function()
    while not ESX.IsPlayerLoaded() do Wait(200) end
    if playerReadySent then return end
    playerReadySent = true

    MBT.Trace.Begin('esx:loadingScreenOff')
    MBT.Trace.OwnAlpha(0)
    SetEntityAlpha(PlayerPedId(), 0, false)
    -- Watchdog: se entro 5s nessun restoreWearing/requestPedScan resetta alpha,
    -- forza la visibilità per non lasciare il player invisibile.
    if MBT.Utils.SchedulePedVisibilityWatchdog then
        MBT.Utils.SchedulePedVisibilityWatchdog("loadingScreenOff")
    end
    Citizen.Wait(2000)
    MBT.Utils.UpdatePlayerClothes()
    MBT.Utils.Target()
    TriggerServerEvent("mbt_meta_clothes:playerReady")
    MBT.Utils.StartHybridDetection()
end)

-- Multicharacter: pause/resume della hybrid detection pilotati dal server
-- tramite net event custom. Il server sa con certezza quando scatta il logout
-- (esx:playerLogout) e il load (esx:playerLoaded), mentre il corrispettivo
-- esx:onPlayerLogout client-side non scatta in tutti i setup multicharacter.
RegisterNetEvent('mbt_meta_clothes:multichar:pauseDetection')
AddEventHandler('mbt_meta_clothes:multichar:pauseDetection', function()
    MBT.Trace.Begin('pauseDetection')
    if MBT.Utils.PauseHybridDetection then
        MBT.Utils.PauseHybridDetection()
    end
    -- Nascondi il PED SUBITO (all'inizio del /relog), prima che l'appearance
    -- script del nuovo char applichi drawable sbagliati. Verrà riportato
    -- visibile dal restoreWearing handler dopo l'apply corretto.
    MBT.Trace.OwnAlpha(0)
    SetEntityAlpha(PlayerPedId(), 0, false)

    -- NIENTE loop di riasserzione. Qui c'era un ciclo che rimetteva alpha=0 ogni
    -- 50ms per cinque secondi. Misurato in gioco il 2026-07-30: il multichar
    -- rimette il PED visibile e questo loop lo rinascondeva entro 7-49ms, in
    -- un'oscillazione regolare — dodici transizioni in 300ms, a schermo visibile.
    -- Quello ERA il lampo.
    --
    -- L'alpha non è una proprietà nostra: la scrivono anche i multicharacter
    -- (verificato in mbt_character e in esx_multicharacter), ed è giusto così
    -- perché sono loro a decidere quando mostrarti il personaggio. Un loop che
    -- contraddice l'altro scrittore non vince la discussione: la rende visibile.
    --
    -- L'hide qui sopra resta come dichiarazione d'intento una tantum, e chi
    -- gestisce lo spawn fa il resto. I capi sbagliati applicati nel frattempo
    -- li corregge la restore protection, che ora reagisce entro un frame.
end)

-- Multicharacter: esx:playerLoaded fires per ogni character (compreso lo switch).
-- Al primo login il flag playerReadySent è già true dopo loadingScreenOff, quindi
-- questo handler scatta solo per i caricamenti successivi (switch character).
-- RegisterNetEvent è obbligatorio: esx:playerLoaded arriva via TriggerClientEvent
-- dal server e senza registrazione FiveM logga "event not safe for net" e lo
-- droppa silenziosamente.
--
-- NOTA: la detection resta in pausa. Il resume lo fa il restoreWearing handler
-- lato client con il wearingState corretto — solo lì sappiamo che la
-- restoreProtection è attiva e il cache viene settato sullo stato atteso.
RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function()
    if not playerReadySent then
        -- First load dopo l'init del resource: verrà gestito da loadingScreenOff
        return
    end
    -- Nessun Wait: applichiamo subito il nostro stato. La restoreProtection
    -- (attivata dal restoreWearing handler) coprirà per 15s qualsiasi
    -- modifica tardiva dell'appearance script, revertendola al nostro state.
    -- Stesso principio delle armi: le applichi subito, nessuno le tocca.
    --
    -- Passa la ownership dell'hide al coordinator PRIMA che inizi a pulsare.
    -- Lasciare vivo il keep loop significa che il suo fallback a 5s rivela il
    -- PED mentre il Pulse lo sta ancora nascondendo: flicker e poi fino ad
    -- altri 5s di invisibilità sbagliata. requestPedScan e restoreWearing
    -- fanno già questo handoff; questo era l'unico ingresso che lo saltava.
    MBT.Trace.Begin('esx:playerLoaded')
    MBT.Trace.OwnAlpha(0)
    SetEntityAlpha(PlayerPedId(), 0, false)
    -- Watchdog insurance net (vedi commento in loadingScreenOff)
    if MBT.Utils.SchedulePedVisibilityWatchdog then
        MBT.Utils.SchedulePedVisibilityWatchdog("esx:playerLoaded")
    end
    MBT.Utils.UpdatePlayerClothes()
    MBT.Utils.Target()
    TriggerServerEvent("mbt_meta_clothes:playerReady")
    MBT.Utils.StartHybridDetection()
end)

MBT.SharedClient.SetupInventoryChecks()
MBT.SharedClient.SetupStealDress()
