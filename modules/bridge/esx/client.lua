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
    MBT.Utils.InitClothingCache()
    MBT.Utils.StartHybridDetection()
end)

-- Multicharacter: pause/resume della hybrid detection pilotati dal server
-- tramite net event custom. Il server sa con certezza quando scatta il logout
-- (esx:playerLogout) e il load (esx:playerLoaded), mentre il corrispettivo
-- esx:onPlayerLogout client-side non scatta in tutti i setup multicharacter.
local keepPedHidden = false

RegisterNetEvent('mbt_meta_clothes:multichar:pauseDetection')
AddEventHandler('mbt_meta_clothes:multichar:pauseDetection', function()
    if MBT.Utils.PauseHybridDetection then
        MBT.Utils.PauseHybridDetection()
    end
    -- Nascondi il PED SUBITO (all'inizio del /relog), prima che l'appearance
    -- script del nuovo char applichi drawable sbagliati. Verrà riportato
    -- visibile dal restoreWearing handler dopo l'apply corretto.
    SetEntityAlpha(PlayerPedId(), 0, false)

    -- Protezione extra: durante il switch il model swap crea un nuovo PED
    -- che è visibile di default. Loop di 5s che mantiene alpha=0 così anche
    -- il nuovo PED resta invisibile finché restoreWearing/requestPedScan
    -- chiama StopKeepPedHidden (exit flag) e fa ResetEntityAlpha.
    --
    -- RESILIENCE FALLBACK: se il loop scade SENZA che keepPedHidden venga
    -- resettato (cioè nessun evento restoreWearing/requestPedScan è arrivato
    -- entro 5s — può succedere con multichar fast-switch o eventi persi),
    -- forziamo manualmente alpha=255 + resume detection per non lasciare il
    -- player invisibile. WARN sempre stampato per visibilità del bug a monte.
    keepPedHidden = true
    Citizen.CreateThread(function()
        local startTime = GetGameTimer()
        local stoppedNormally = false
        while keepPedHidden and GetGameTimer() - startTime < 5000 do
            local ped = PlayerPedId()
            if DoesEntityExist(ped) and GetEntityAlpha(ped) > 0 then
                SetEntityAlpha(ped, 0, false)
            end
            if not keepPedHidden then
                stoppedNormally = true
                break
            end
            Wait(50)
        end
        if not stoppedNormally and keepPedHidden then
            MBT.Warn('keepPedHidden timer expired without restore or PED scan; auto-recovering visibility')
            keepPedHidden = false
            local ped = PlayerPedId()
            if DoesEntityExist(ped) then
                ResetEntityAlpha(ped)
                SetEntityAlpha(ped, 255, false)
            end
            if MBT.Utils.ResumeHybridDetection then
                MBT.Utils.ResumeHybridDetection()
            end
        end
    end)
end)

-- Exit flag usato dal restoreWearing lato client per fermare il loop di
-- SetEntityAlpha(0) quando è ora di far vedere il PED.
function MBT.Utils.StopKeepPedHidden()
    keepPedHidden = false
end

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
    if MBT.Utils.StopKeepPedHidden then MBT.Utils.StopKeepPedHidden() end
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

MBT.SharedClient.SetupCheckDress(function(sex)
    return sex == "m" and "male" or "female"
end)

MBT.SharedClient.SetupInventoryChecks()
MBT.SharedClient.SetupStealDress()
