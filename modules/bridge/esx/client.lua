if GetResourceState('es_extended') ~= 'started' then return end

ESX = exports.es_extended:getSharedObject()

local playerReadySent = false

-- First login: hide PED to prevent clothing flash
AddEventHandler('esx:loadingScreenOff', function()
    while not ESX.IsPlayerLoaded() do Wait(200) end
    if playerReadySent then return end
    playerReadySent = true

    SetEntityAlpha(PlayerPedId(), 0, false)
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
    -- il nuovo PED resta invisibile finché restoreWearing non chiama
    -- ResetEntityAlpha (che setta keepPedHidden=false tramite una exit-flag).
    keepPedHidden = true
    Citizen.CreateThread(function()
        local startTime = GetGameTimer()
        while keepPedHidden and GetGameTimer() - startTime < 5000 do
            local ped = PlayerPedId()
            if DoesEntityExist(ped) and GetEntityAlpha(ped) > 0 then
                SetEntityAlpha(ped, 0, false)
            end
            Wait(50)
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
    SetEntityAlpha(PlayerPedId(), 0, false)
    MBT.Utils.UpdatePlayerClothes()
    MBT.Utils.Target()
    TriggerServerEvent("mbt_meta_clothes:playerReady")
    MBT.Utils.StartHybridDetection()
end)

-- Script restart (ensure): NO PED hide, player is already in game
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    if not ESX.IsPlayerLoaded() then return end
    playerReadySent = true
    Citizen.Wait(500)
    MBT.Utils.UpdatePlayerClothes()
    MBT.Utils.Target()
    TriggerServerEvent("mbt_meta_clothes:playerReady")
    MBT.Utils.InitClothingCache()
    MBT.Utils.StartHybridDetection()
end)

MBT.SharedClient.SetupCheckDress(function(sex)
    return sex == "m" and "male" or "female"
end)

MBT.SharedClient.SetupInventoryChecks()
MBT.SharedClient.SetupStealDress()
