if GetResourceState('es_extended') ~= 'started' then return end

ESX = exports.es_extended:getSharedObject()

-- Se la risorsa viene riavviata con un player ESX già attivo, il prossimo
-- playerLoaded è uno switch vero e non va scartato.
local playerReadySent = ESX.IsPlayerLoaded()

AddEventHandler('esx:loadingScreenOff', function()
    while not ESX.IsPlayerLoaded() do Wait(200) end
    if playerReadySent then return end
    playerReadySent = true

    MBT.Trace.Begin('esx:loadingScreenOff')
    MBT.Trace.OwnAlpha(0)
    SetEntityAlpha(PlayerPedId(), 0, false)
    -- Rete di sicurezza: se entro 5s nessuno chiude la transizione, rivela.
    if MBT.Utils.SchedulePedVisibilityWatchdog then
        MBT.Utils.SchedulePedVisibilityWatchdog("loadingScreenOff")
    end
    -- playerReady per PRIMO e senza attese: fa partire il push dello stato dal
    -- server, e ogni millisecondo qui è un millisecondo di outfit sbagliato
    -- visibile. Un `Wait(2000)` che stava qui costava 2s su 2083 di latenza
    -- totale, e duplicava il retry sull'identifier che il server ha già.
    TriggerServerEvent("mbt_meta_clothes:playerReady")
    MBT.Utils.UpdatePlayerClothes()
    MBT.Utils.Target()
    MBT.Utils.StartHybridDetection()
end)

-- Pause/resume pilotati dal server: solo lui sa con certezza quando scattano
-- logout e load, mentre esx:onPlayerLogout client-side non è affidabile su
-- tutti i setup multicharacter.
RegisterNetEvent('mbt_meta_clothes:multichar:pauseDetection')
AddEventHandler('mbt_meta_clothes:multichar:pauseDetection', function()
    MBT.Trace.Begin('pauseDetection')
    if MBT.Utils.PauseHybridDetection then
        MBT.Utils.PauseHybridDetection()
    end
    -- Nascondi prima che l'appearance script del char nuovo applichi il suo skin.
    MBT.Trace.OwnAlpha(0)
    SetEntityAlpha(PlayerPedId(), 0, false)

    -- Una volta sola, mai in loop: l'alpha la scrivono anche i multicharacter, e
    -- contraddirli a ripetizione produce uno stroboscopio invece di un PED
    -- nascosto. I capi sbagliati applicati nel frattempo li corregge la restore
    -- protection, che reagisce entro un frame.
end)

-- Scatta solo dai caricamenti successivi al primo: al primo login
-- `playerReadySent` è già true da loadingScreenOff.
--
-- RegisterNetEvent è obbligatorio — esx:playerLoaded arriva via
-- TriggerClientEvent e senza registrazione FiveM lo droppa in silenzio.
--
-- La detection resta in pausa: il resume lo fa restoreWearing, che è l'unico
-- punto in cui conosciamo lo stato atteso su cui riallineare la baseline.
RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function()
    if not playerReadySent then
        -- Primo load dopo l'avvio della risorsa: lo gestisce loadingScreenOff.
        return
    end
    -- Nessuna attesa: applichiamo subito, e la restore protection copre per 15s
    -- qualunque modifica tardiva dell'appearance script.
    MBT.Trace.Begin('esx:playerLoaded')
    MBT.Trace.OwnAlpha(0)
    SetEntityAlpha(PlayerPedId(), 0, false)
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
