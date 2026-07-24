--- Normalize metadata from different inventory formats (OX vs QB)
--- OX inventory wraps our metadata inside item.metadata, while QB stores it directly
--- in item.info. OX also adds its own root-level fields (e.g. type = "item") that
--- must NOT shadow our MBT types ("Drawable"/"Prop"/"DressKit").
local function normalizeMetadata(data)
    local meta = {}

    -- Read from root level first (covers QB where item.info IS the metadata)
    meta.index    = data.index
    meta.drawable = data.drawable
    meta.texture  = data.texture
    meta.palette  = data.palette
    meta.sex      = MBT.NormalizeSex(data.sex)
    meta.description = data.description
    meta.item_name = type(data.name) == "string" and data.name or nil

    -- Root-level type only if it's an MBT clothing type — ignore inventory engine types like "item"
    local MBT_TYPES = { Drawable = true, Prop = true, DressKit = true }
    if MBT_TYPES[data.type] then
        meta.type = data.type
    end

    -- Overlay from the nested .metadata table (OX inventory format)
    -- MBT fields always win over whatever was at root level
    if data.metadata and type(data.metadata) == "table" then
        meta.index    = meta.index    or data.metadata.index
        meta.drawable = meta.drawable or data.metadata.drawable
        meta.texture  = meta.texture  or data.metadata.texture
        meta.palette  = meta.palette  or data.metadata.palette
        meta.sex      = meta.sex      or MBT.NormalizeSex(data.metadata.sex)
        meta.description = meta.description or data.metadata.description
        meta.item_name   = meta.item_name   or (type(data.metadata.item_name) == "string" and data.metadata.item_name or nil)

        -- type: prefer metadata MBT type over root-level inventory type ("item")
        if MBT_TYPES[data.metadata.type] then
            meta.type = data.metadata.type
        elseif not meta.type then
            meta.type = data.metadata.type
        end

        -- Copy any remaining metadata fields not already set
        for k, v in pairs(data.metadata) do
            if meta[k] == nil then meta[k] = v end
        end
    end

    return meta
end

-- onResourceStart is handled by the framework bridge (esx/qb/ox client.lua)
-- to avoid duplicate playerReady events

-- Server requests PED scan (new players only, after Load completed)
RegisterNetEvent('mbt_meta_clothes:requestPedScan')
AddEventHandler('mbt_meta_clothes:requestPedScan', function(context)
    if not context or not MBT.SnapshotClient.SetContext(context) then return end
    -- New player: lascia che l'appearance script applichi il SUO skin,
    -- POI scansiona il PED per popolare il nostro state.

    -- Resume detection SUBITO così l'appearance script può applicare il suo skin
    -- senza che noi blocchiamo nulla. Il PED resta invisibile (alpha=0 dal bridge)
    -- durante questo periodo per evitare il flash "nudo → vestito".
    if MBT.Utils.ResumeHybridDetection then
        MBT.Utils.ResumeHybridDetection()
    end
    MBT.SnapshotClient.Resume('character')
    MBT.SnapshotClient.SetRestoreProtection(false)

    -- IMPORTANTE: il scan del PED è ritardato di 2.5s per dare tempo a
    -- illenium-appearance (o qualunque skin script) di applicare il vero
    -- outfit del char. Senza delay, il scan cattura uno stato BARE (modello
    -- default appena spawnato) e lo salva come baseline → al prossimo
    -- restoreWearing il player apparirebbe nudo per sempre.
    MBT.SnapshotClient.ForceInitialScan(2500)

    -- Mostra il PED solo dopo PedRevealDelay (default 2s), così illenium ha
    -- tempo di applicare il suo skin completo PRIMA che il player veda. Senza
    -- questo delay il player vedrebbe il PED nudo (default model) per ~1s
    -- finché illenium non finisce di applicare. La camera del selector copre
    -- normalmente questi 2s.
    Citizen.SetTimeout(MBT.PedRevealDelay or 2000, function()
        if MBT.Utils.StopKeepPedHidden then
            MBT.Utils.StopKeepPedHidden()
        end
        ResetEntityAlpha(PlayerPedId())
        SetEntityAlpha(PlayerPedId(), 255, false)
    end)
end)

-----------------------------------------------------------
-- Authoritative PED restore from server wearing state
-----------------------------------------------------------

--- Apply the wearing state to the PED
local function applyWearingState(wearingState)
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return end

    local sex = MBT.Utils.GetPedSex(ped)
    if sex == "customSkin" then return end

    for k, v in pairs(MBT.Drawables) do
        local stored = wearingState.Drawables and (wearingState.Drawables[tostring(k)] or wearingState.Drawables[k])

        if stored and stored.drawable then
            SetPedComponentVariation(ped, k, stored.drawable, stored.texture or 0, stored.palette or 0)
        else
            local default = v["Default"][sex]
            if type(default) == "table" then
                SetPedComponentVariation(ped, k, default[1], 0, 0)
            end
        end
    end

    for k, v in pairs(MBT.Props) do
        local stored = wearingState.Props and (wearingState.Props[tostring(k)] or wearingState.Props[k])

        if stored and stored.drawable then
            SetPedPropIndex(ped, k, stored.drawable, stored.texture or 0, true)
            -- Hat/hair clip fix: apply on restore if wearing hat
            if MBT.Props[k] and MBT.Props[k]["ApplyHairFix"] then
                MBT.Utils.ApplyHatHairFix(ped)
            end
        else
            local default = v["Default"][sex]
            if type(default) == "table" then
                ClearPedProp(ped, k)
            end
        end
    end

    MBT.Utils.UpdatePlayerClothes()
end

-- Generation counter per restoreWearing — incrementato ad ogni nuovo restore.
-- I re-apply ritardati controllano la generation prima di applicare: se un
-- nuovo restoreWearing è arrivato (generation incrementata) in mezzo, il
-- re-apply diventa no-op così non sovrascrivono lo state più recente con
-- uno vecchio. CRITICO per multichar fast-switch (char1 -> char2 -> char1
-- in 1-2s): senza questo guard, i re-apply di char1 firerebbero mentre sei
-- già su char2 e gli applicherebbero i drawable di char1.
local restoreGeneration = 0

RegisterNetEvent('mbt_meta_clothes:restoreWearing')
AddEventHandler('mbt_meta_clothes:restoreWearing', function(wearingState, context)
    if not wearingState then return end

    -- Legacy watchdog unblock: no context means this is not an authoritative
    -- restore and must never apply an empty state over the active character.
    if not context then
        if MBT.Utils.ResumeHybridDetection then MBT.Utils.ResumeHybridDetection() end
        if MBT.Utils.StopKeepPedHidden then MBT.Utils.StopKeepPedHidden() end
        ResetEntityAlpha(PlayerPedId())
        SetEntityAlpha(PlayerPedId(), 255, false)
        return
    end

    -- Normalize JSON string keys to numeric (json.decode creates "3" not 3)
    local normalized = { Drawables = {}, Props = {} }
    for k, v in pairs(wearingState.Drawables or {}) do
        normalized.Drawables[tonumber(k) or k] = v
    end
    for k, v in pairs(wearingState.Props or {}) do
        normalized.Props[tonumber(k) or k] = v
    end
    wearingState = normalized
    if not MBT.SnapshotClient.SetContext(context, wearingState) then return end
    MBT.SnapshotClient.Resume('character')

    -- Bump generation: invalida ogni re-apply pendente del restore precedente
    restoreGeneration = restoreGeneration + 1
    local myGen = restoreGeneration

    -- Enable restore protection: for the next 15 seconds, Hybrid Detection
    -- will REVERT any external changes to our managed slots instead of tracking them.
    -- This prevents the appearance script from overwriting our restored state.
    MBT.Utils.EnableRestoreProtection(wearingState, MBT.RestoreProtection or 15000)

    -- Apply immediately — restore guard (100ms polling, 15s) handles late appearance script changes
    applyWearingState(wearingState)

    -- Re-apply finale 200ms prima del reveal: garantisce che lo state sia
    -- esattamente quello giusto nel momento in cui il PED diventa visibile.
    -- Coprire la race con illenium-appearance (che applica il SUO skin async
    -- via NUI ~500-1500ms dopo il load) è già fatto dal loop hybrid detection
    -- con restoreProtection 15s + poll 500ms — questo re-apply è solo un
    -- "polish" deterministico al momento del reveal.
    --
    -- Generation guard: se un nuovo restoreWearing è arrivato dopo (es. fast-switch
    -- ad altro char), non re-applicare lo stato vecchio sul char nuovo.
    local reapplyDelay = (MBT.PedRevealDelay or 2000) - 300
    if reapplyDelay > 0 then
        Citizen.SetTimeout(reapplyDelay, function()
            if myGen == restoreGeneration then
                applyWearingState(wearingState)
            end
        end)
    end

    -- Riprende la detection con il cache settato sullo stato ATTESO (wearingState).
    -- Questo è cruciale post-multichar: se l'appearance script ha applicato
    -- qualcosa che non ci dovrebbe essere (es. vecchio cappello salvato da
    -- esx_skin), il cache non lo congela come normale — al prossimo poll la
    -- restoreProtection vede il diff e reverte tornando al nostro state.
    if MBT.Utils.ResumeHybridDetection then
        MBT.Utils.ResumeHybridDetection(wearingState)
    end

    -- Mostra il PED solo DOPO che tutta la sequenza apply-then-revert è stable.
    --
    -- Sequenza tipica al login/switch:
    --   T=0     applyWearingState (nostro state corretto)
    --   T=~700  illenium-appearance applica il SUO skin (potrebbe overrideare)
    --   T=700   re-apply nostro #1 (reverte illenium)
    --   T=1500  re-apply nostro #2 (finale)
    --   T=2000  PED mostrato (state ora stable)
    --
    -- Se mostrassimo il PED a T=0 (come prima), il player vedrebbe un BLINK
    -- visibile tra T=700 (illenium override) e T=1500 (revert). Questi 2s
    -- coincidono normalmente con la camera del selector multichar / loading
    -- screen, quindi l'utente non percepisce il delay.
    --
    -- Generation guard: se un nuovo restoreWearing arriva (fast-switch ad altro
    -- char), il timeout scaduto non mostra il vecchio PED — sarà il nuovo
    -- restoreWearing a gestire la propria reveal.
    Citizen.SetTimeout(MBT.PedRevealDelay or 2000, function()
        if myGen ~= restoreGeneration then return end
        if MBT.Utils.StopKeepPedHidden then
            MBT.Utils.StopKeepPedHidden()
        end
        ResetEntityAlpha(PlayerPedId())
        SetEntityAlpha(PlayerPedId(), 255, false)
    end)
end)

RegisterNUICallback('handleDress', function(data, cb)
    -- Delegate to wearable_props if the slot belongs to it and the resource is running
    local wpItemType = MBT.WearablePropsSlots and MBT.WearablePropsSlots[data.Index]
    if wpItemType and MBT.Utils.MbtWearableProps() then
        -- Armor slot: detect which tier is actually worn via statebag
        if data.Index == 9 then
            if LocalPlayer.state.mbt_isWearingHeavyarmor then
                wpItemType = "heavyarmor"
            elseif LocalPlayer.state.mbt_isWearingMedarmor then
                wpItemType = "medarmor"
            else
                wpItemType = "smallarmor"
            end
        end
        exports['mbt_wearable_props']:removeWearable(wpItemType)
        cb(1)
        return
    end
    -- Torso slots are a single kit — always undress together
    if MBT.TorsoKitSlots and MBT.TableContains(MBT.TorsoKitSlots, data.Index) then
        MBT.Utils.HandleTorsoUndress()
    else
        MBT.Utils.HandleUndress(data.Index)
    end
    cb(1)
end)

RegisterNUICallback('handleProps', function(data, cb)
    MBT.Utils.HandleProps(data.Index)
    cb(1)
end)

RegisterNUICallback('handleToggleState', function(data, cb)
    if data and data.slotType and data.slotIndex then
        MBT.Utils.ToggleClothingState(data.slotType, tonumber(data.slotIndex))
    end
    cb(1)
end)

RegisterNUICallback('handleHairToggle', function(data, cb)
    local toggled = MBT.Utils.ToggleHair()
    SendNUIMessage({ action = "hairToggleUpdate", hairToggled = toggled })
    cb(1)
end)

RegisterNUICallback('exitUI', function(data, cb)
    SetNuiFocus(false, false)
    cb(1)
end)

--- Send slot update to NUI after any dress/undress action
--- @param slotType string "Drawables" or "Props"
--- @param slotIndex number The slot index
--- @param isWearing boolean Whether the slot is now worn (non-default)
function MBT.Utils.SendSlotUpdate(slotType, slotIndex, isWearing)
    local ped = PlayerPedId()
    local update = {
        action = "updateSlot",
        slotType = slotType,
        slotIndex = slotIndex,
        isWearing = isWearing
    }
    if isWearing then
        if slotType == "Drawables" then
            update.drawable = GetPedDrawableVariation(ped, slotIndex)
            update.texture = GetPedTextureVariation(ped, slotIndex)
        else
            update.drawable = GetPedPropIndex(ped, slotIndex)
            update.texture = GetPedPropTextureIndex(ped, slotIndex)
        end
    end
    SendNUIMessage(update)
end

RegisterNetEvent('mbt_meta_clothes:applyDress')
AddEventHandler('mbt_meta_clothes:applyDress', function(data)
    local meta = normalizeMetadata(data)
    MBT.Debugger("applyDress: slot", meta.index, "drawable", meta.drawable, "texture", meta.texture, "type", meta.type)
    MBT.Utils.ExpectChange("Drawables", meta.index)
    SetPedComponentVariation(PlayerPedId(), meta.index, meta.drawable, meta.texture, meta.palette)
    MBT.Utils.UpdatePlayerClothes() -- keep cache in sync so next checkDress sees the new state
    MBT.Utils.SendSlotUpdate("Drawables", meta.index, true)
    TriggerServerEvent("mbt_meta_clothes:storeWearing", "Drawables", meta)
end)

RegisterNetEvent('mbt_meta_clothes:applyKitDress')
AddEventHandler('mbt_meta_clothes:applyKitDress', function(data)
    local kitMetadata = {}
    for k, v in pairs(data) do
        if type(v) == "table" and v.index then
            MBT.Debugger("applyKitDress: slot", v.index, "(", k, ") drawable", v.drawable, "texture", v.texture)
            MBT.Utils.ExpectChange("Drawables", v.index)
            SetPedComponentVariation(PlayerPedId(), v.index, v.drawable, v.texture, v.palette)
            kitMetadata[v.index] = {
                index = v.index,
                drawable = v.drawable,
                texture = v.texture,
                palette = v.palette,
            }
        end
    end
    MBT.Utils.SendSlotUpdate("Drawables", 3, true)
    MBT.Utils.SendSlotUpdate("Drawables", 8, true)
    MBT.Utils.SendSlotUpdate("Drawables", 11, true)
    TriggerServerEvent("mbt_meta_clothes:storeWearingKit", kitMetadata)
end)

RegisterNetEvent('mbt_meta_clothes:applyProps')
AddEventHandler('mbt_meta_clothes:applyProps', function(data)
    local meta = normalizeMetadata(data)
    MBT.Utils.ExpectChange("Props", meta.index)
    SetPedPropIndex(PlayerPedId(), meta.index, meta.drawable, meta.texture, true)
    -- Hat/hair clip fix: hide hair when putting on hat
    if MBT.Props[meta.index] and MBT.Props[meta.index]["ApplyHairFix"] then
        MBT.Utils.ApplyHatHairFix(PlayerPedId())
    end
    MBT.Utils.UpdatePlayerClothes() -- keep cache in sync so next checkDress sees the new state
    MBT.Utils.SendSlotUpdate("Props", meta.index, true)
    TriggerServerEvent("mbt_meta_clothes:storeWearing", "Props", meta)
end)

RegisterNetEvent('mbt_meta_clothes:stealPlayerDress')
AddEventHandler('mbt_meta_clothes:stealPlayerDress', function(data)
    stealPlayerDress(data)
end, false)

RegisterNetEvent('mbt_meta_clothes:setDefaultDressTarget')
AddEventHandler('mbt_meta_clothes:setDefaultDressTarget', function(stealingPlayer)
    local playerPed = PlayerPedId()
    local playerSex = MBT.Utils.GetPedSex(playerPed)
    local targetWearing = { Drawables = {}, Props = {} }

    -- Scatter all non-default clothing as 3D props BEFORE stripping
    MBT.ClothingProps.ScatterAllFromPed(playerPed, playerSex)

    for k, v in pairs(MBT.Drawables) do
        targetWearing["Drawables"][k] = {
            Drawable = GetPedDrawableVariation(playerPed, k),
            Texture =
                GetPedTextureVariation(playerPed, k),
            Palette = GetPedPaletteVariation(playerPed, k)
        }
        MBT.Utils.ExpectChange("Drawables", k)
        SetPedComponentVariation(playerPed, k, MBT.Drawables[k]["Default"][playerSex][1], 0, 0)
    end

    for k, v in pairs(MBT.Props) do
        targetWearing["Props"][k] = {
            Drawable = GetPedPropIndex(playerPed, k),
            Texture = GetPedPropTextureIndex(
                playerPed, k),
            Palette = 0
        }
        MBT.Utils.ExpectChange("Props", k)
        SetPedPropIndex(playerPed, k, MBT.Props[k]["Default"][playerSex][1], 0, 0)
    end

    TriggerServerEvent('mbt_meta_clothes:giveStolenItemDress', stealingPlayer, targetWearing, playerSex)
end)

-----------------------------------------------------------
-- Steal single item: victim resets the stolen slot to default
-----------------------------------------------------------
RegisterNetEvent('mbt_meta_clothes:stealApplyDefault')
AddEventHandler('mbt_meta_clothes:stealApplyDefault', function(stealType, slotIndex)
    local ped = PlayerPedId()
    local sex = MBT.Utils.GetPedSex(ped)
    if sex == "customSkin" then return end

    if stealType == "torso" then
        for _, idx in ipairs(MBT.TorsoKitSlots) do
            if MBT.ClothingPropsEnabled then
                local propModel = MBT.Drawables[idx] and MBT.Drawables[idx]["PropModel"]
                MBT.ClothingProps.ScatterFromPed(ped, propModel, "Drawables", idx)
            end
            MBT.Utils.ExpectChange("Drawables", idx)
            local default = MBT.Drawables[idx] and MBT.Drawables[idx]["Default"][sex]
            if default then
                SetPedComponentVariation(ped, idx, default[1], 0, 0)
            end
            MBT.Utils.SendSlotUpdate("Drawables", idx, false)
        end
    elseif stealType == "drawable" and slotIndex then
        if MBT.ClothingPropsEnabled then
            local propModel = MBT.Drawables[slotIndex] and MBT.Drawables[slotIndex]["PropModel"]
            MBT.ClothingProps.ScatterFromPed(ped, propModel, "Drawables", slotIndex)
        end
        MBT.Utils.ExpectChange("Drawables", slotIndex)
        local default = MBT.Drawables[slotIndex] and MBT.Drawables[slotIndex]["Default"][sex]
        if default then
            SetPedComponentVariation(ped, slotIndex, default[1], 0, 0)
        end
        MBT.Utils.SendSlotUpdate("Drawables", slotIndex, false)
    elseif stealType == "prop" and slotIndex then
        if MBT.ClothingPropsEnabled then
            local propModel = MBT.Props[slotIndex] and MBT.Props[slotIndex]["PropModel"]
            MBT.ClothingProps.ScatterFromPed(ped, propModel, "Props", slotIndex)
        end
        MBT.Utils.ExpectChange("Props", slotIndex)
        local default = MBT.Props[slotIndex] and MBT.Props[slotIndex]["Default"][sex]
        if default then
            ClearPedProp(ped, slotIndex)
        end
        -- Restore hair if hat was stolen
        if MBT.Props[slotIndex] and MBT.Props[slotIndex]["ApplyHairFix"] then
            MBT.Utils.RestoreHairFromHatFix(ped)
        end
        MBT.Utils.SendSlotUpdate("Props", slotIndex, false)
    end

    MBT.Utils.UpdatePlayerClothes()
end)

-----------------------------------------------------------
-- Victim animation relay (requested by thief via server)
-----------------------------------------------------------
RegisterNetEvent('mbt_meta_clothes:playVictimAnim')
AddEventHandler('mbt_meta_clothes:playVictimAnim', function(duration, targetDown, dict, clip)
    local ped = PlayerPedId()
    -- dict/clip are passed from the thief's client so victim always mirrors the thief's animation set
    while not HasAnimDictLoaded(dict) do
        RequestAnimDict(dict)
        Wait(50)
    end
    TaskPlayAnim(ped, dict, clip, 3.0, 3.0, duration, 49, 0, false, false, false)
    Wait(duration)
    ClearPedTasks(ped)
    RemoveAnimDict(dict)
end)

RegisterCommand("toggleUndress", function()
    if IsPedOnFoot(PlayerPedId()) and not IsPedDeadOrDying(PlayerPedId(), false) and not IsPedCuffed(PlayerPedId()) then
        local bagState = type(checkBagState) == 'function' and checkBagState() or false
        local maskState = type(checkMaskState) == 'function' and checkMaskState() or false
        local armorState = type(checkArmorState) == 'function' and checkArmorState() or false
        local resourceState = MBT.Utils.MbtWearableProps()

        -- Build wearing state for NUI: which slots have non-default drawables
        local ped = PlayerPedId()
        local sex = MBT.Utils.GetPedSex(ped)
        local wearing = { Drawables = {}, Props = {} }

        if sex ~= "customSkin" then
            for k, v in pairs(MBT.Drawables) do
                local drawable = GetPedDrawableVariation(ped, k)
                local isDefault = MBT.TableContains(v["Default"][sex], drawable)
                if not isDefault then
                    wearing.Drawables[tostring(k)] = {
                        index = k,
                        drawable = drawable,
                        texture = GetPedTextureVariation(ped, k)
                    }
                end
            end
            for k, v in pairs(MBT.Props) do
                local prop = GetPedPropIndex(ped, k)
                local isDefault = MBT.TableContains(v["Default"][sex], prop)
                if not isDefault then
                    wearing.Props[tostring(k)] = {
                        index = k,
                        drawable = prop,
                        texture = GetPedPropTextureIndex(ped, k)
                    }
                end
            end
        end

        -- Determine sex as numeric (0=male, 1=female) for NUI mannequin image
        local sexNumeric = (sex == "female") and 1 or 0

        -- Build toggleable slots list: which slots have ClothingStates configured.
        -- Solo Drawables e Props interessano per gli slot indicizzati; Hair ha
        -- una struttura diversa (flat array, non per-slot) e non va iterata qui.
        -- IMPORTANTE: ogni stato ha un campo `sex` — dobbiamo filtrarli per
        -- il sesso del player, altrimenti un maschio con drawable X finisce
        -- marcato toggleable quando esiste solo uno stato female con from=X
        -- (falso positivo che fa apparire l'icona di toggle per item non
        -- toggleabili per quel sesso).
        local toggleableSlots = { Drawables = {}, Props = {} }
        if MBT.ClothingStates then
            for _, slotType in ipairs({ "Drawables", "Props" }) do
                local slots = MBT.ClothingStates[slotType]
                if slots then
                    for slotIndex, states in pairs(slots) do
                        if #states > 0 then
                            local currentDrawable
                            if slotType == "Drawables" then
                                currentDrawable = GetPedDrawableVariation(ped, slotIndex)
                            else
                                currentDrawable = GetPedPropIndex(ped, slotIndex)
                            end
                            for _, state in ipairs(states) do
                                -- Match solo se sesso combacia (o se lo stato non specifica sesso)
                                local sexMatches = (not state.sex) or state.sex == sex
                                if sexMatches and (state.from == currentDrawable or state.to == currentDrawable) then
                                    toggleableSlots[slotType][tostring(slotIndex)] = true
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end

        -- Check hair toggleability for NUI
        local hairToggleable = MBT.Utils.IsHairToggleable and MBT.Utils.IsHairToggleable() or false

        -- Request drip data from server for NUI display
        TriggerServerEvent('mbt_meta_clothes:requestDripInfo')

        SetNuiFocus(true, true)
        SendNUIMessage({
            action = "ui",
            status = true,
            wearing = wearing,
            sex = sexNumeric,
            mask = maskState,
            bag = bagState,
            armor = armorState,
            wearableProps = resourceState,
            toggleableSlots = toggleableSlots,
            hairToggleable = hairToggleable,
            -- UI labels dal locale attivo (hotspots, slot names, steal strings).
            -- Un solo source of truth per lingua: il Lua pilota, React consuma.
            labels = MBT.Locale.UI or {},
        })
    end
end, false)

RegisterKeyMapping('toggleUndress', MBT.Locale["sett_name"] or "Clothes Menu", 'keyboard', MBT.MenuKey)

-----------------------------------------------------------
-- Slash commands for quick toggle per slot (/shirt, /trousers, etc.)
-- Toggle: if wearing non-default → undress with animation
--         if wearing default → notify nothing to remove
-----------------------------------------------------------

local function canToggle()
    local ped = PlayerPedId()
    return IsPedOnFoot(ped) and not IsPedDeadOrDying(ped, false) and not IsPedCuffed(ped)
end

-- Drawable commands
RegisterCommand("shirt", function() if canToggle() then MBT.Utils.HandleTorsoUndress() end end, false)
RegisterCommand("trousers", function() if canToggle() then MBT.Utils.HandleUndress(4) end end, false)
RegisterCommand("shoes", function() if canToggle() then MBT.Utils.HandleUndress(6) end end, false)
RegisterCommand("chain", function() if canToggle() then MBT.Utils.HandleUndress(7) end end, false)
RegisterCommand("jacket", function() if canToggle() then MBT.Utils.HandleTorsoUndress() end end, false)

-- Prop commands
RegisterCommand("hat", function() if canToggle() then MBT.Utils.HandleProps(0) end end, false)
RegisterCommand("glasses", function() if canToggle() then MBT.Utils.HandleProps(1) end end, false)
RegisterCommand("ears", function() if canToggle() then MBT.Utils.HandleProps(2) end end, false)
RegisterCommand("watch", function() if canToggle() then MBT.Utils.HandleProps(6) end end, false)

-- Hair toggle: tie up / let down
RegisterCommand("hair", function() if canToggle() then MBT.Utils.ToggleHair() end end, false)

-- Steal command (fallback for servers without target scripts)
RegisterCommand("steal", function()
    if not canToggle() then return end
    local myPed = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    local maxDist = MBT.StealDistance or 5.0
    local closestPed, closestDist = nil, maxDist

    for _, playerId in ipairs(GetActivePlayers()) do
        if playerId ~= PlayerId() then
            local targetPed = GetPlayerPed(playerId)
            if targetPed and targetPed ~= 0 then
                local dist = #(myCoords - GetEntityCoords(targetPed))
                if dist < closestDist then
                    local canSteal = IsEntityPlayingAnim(targetPed, "missminuteman_1ig_2", "handsup_base", 3)
                        or IsPedDeadOrDying(targetPed, false)
                        or IsPedRagdoll(targetPed)
                    if canSteal then
                        closestPed = targetPed
                        closestDist = dist
                    end
                end
            end
        end
    end

    if closestPed then
        stealPlayerDress({ entity = closestPed })
    else
        MBT.Notification(MBT.Locale["nothing_to_steal"])
    end
end, false)

-----------------------------------------------------------
-- Server → Client notification relay
-----------------------------------------------------------
RegisterNetEvent('mbt_meta_clothes:notify', function(data)
    MBT.Notification(data)
end)

-----------------------------------------------------------
-- wearable_props statebag listeners
-- Keep NUI extraState in sync when mask/bag/armor change
-- outside of the meta_clothes NUI (e.g. via wearable_props UI)
-----------------------------------------------------------
local wpStatebags = {
    { key = 'mbt_isWearingMask',       nuiKey = 'mask'  },
    { key = 'mbt_isWearingBag',        nuiKey = 'bag'   },
    { key = 'mbt_isWearingSmallarmor', nuiKey = 'armor' },
    { key = 'mbt_isWearingMedarmor',   nuiKey = 'armor' },
    { key = 'mbt_isWearingHeavyarmor', nuiKey = 'armor' },
}
for _, sb in ipairs(wpStatebags) do
    local sbKey  = sb.key
    local nuiKey = sb.nuiKey
    AddStateBagChangeHandler(sbKey, nil, function(bagName, _, value)
        -- Only react to own player statebag
        if bagName ~= ('player:%d'):format(GetPlayerServerId(PlayerId())) then return end
        SendNUIMessage({ action = 'extraStateUpdate', [nuiKey] = value == true })
    end)
end

-----------------------------------------------------------
-- Clothing States (Tuck/Untuck)
-- /tuck = auto-detect first toggleable slot
-- /tuck [slot] = toggle specific drawable slot (e.g. /tuck 11)
-----------------------------------------------------------
RegisterCommand("tuck", function(_, args)
    if not canToggle() then return end
    local slotIndex = tonumber(args[1])
    if not slotIndex then
        MBT.Notification(MBT.Locale["tuck_usage"])
        return
    end
    if MBT.Props[slotIndex] then
        MBT.Utils.ToggleClothingState("Props", slotIndex)
    elseif MBT.Drawables[slotIndex] then
        MBT.Utils.ToggleClothingState("Drawables", slotIndex)
    else
        MBT.Notification(MBT.Locale["tuck_invalid_slot"])
    end
end, false)

-----------------------------------------------------------
-- Drip Reputation — client listener + /drip command
-----------------------------------------------------------

RegisterNetEvent('mbt_meta_clothes:dripUpdate')
AddEventHandler('mbt_meta_clothes:dripUpdate', function(data)
    -- Forward to NUI for display
    SendNUIMessage({
        action = "dripUpdate",
        xp = data.xp,
        rate = data.rate,
        level = data.level,
        levelIndex = data.levelIndex,
        progress = data.progress
    })
end)

RegisterCommand("drip", function()
    TriggerServerEvent('mbt_meta_clothes:requestDripInfo')
end, false)

RegisterNUICallback('requestDripScore', function(data, cb)
    TriggerServerEvent('mbt_meta_clothes:requestDripInfo')
    cb(1)
end)

RegisterNetEvent('mbt_meta_clothes:dripInfo')
AddEventHandler('mbt_meta_clothes:dripInfo', function(data)
    -- Update NUI
    SendNUIMessage({
        action = "dripUpdate",
        xp = data.xp,
        rate = data.rate,
        level = data.level,           -- The name string from server
        levelIndex = data.levelIndex, -- The numeric level from server
        progress = data.progress
    })

    -- Show in chat
    local lvl = data.level or MBT.Locale["drip_unknown"]
    local lvlIdx = data.levelIndex or 1
    local xp = data.xp or 0
    local rate = data.rate or 0
    local msg = MBT.Locale["drip_info"]:format(lvl, lvlIdx, xp, rate)
    TriggerEvent('chat:addMessage', {
        color = { 0, 200, 200 },
        args = { MBT.Locale["drip_label"], msg }
    })
end)
