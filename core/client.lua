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

-- Server-owned resource restart recovery pushes state for connected players.
-- The client start hook below only rebuilds local runtime registrations and
-- deliberately does not emit another playerReady event.

local restoreGeneration = 0
local pendingInitialReveal

--- @return boolean revealed False when the PED is not available yet; the
--- coordinator keeps the transition open and retries instead of consuming it.
local function revealPed(reason)
    if MBT.Utils.CompletePedVisibilityWait then
        -- The coordinator owns the keep-loop shutdown: it stops it only after
        -- the PED was really revealed. Stopping it here would release the loop
        -- that follows model replacement even when the reveal did not happen.
        local revealed = MBT.Utils.CompletePedVisibilityWait(reason)
        MBT.Debugger(revealed and 'ped reveal' or 'ped reveal deferred; no ped yet', reason)
        return revealed
    end
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return false end
    MBT.Trace.OwnAlpha(255)
    ResetEntityAlpha(ped)
    SetEntityAlpha(ped, 255, false)
    MBT.Debugger('ped reveal', reason)
    return true
end

RegisterNetEvent('mbt_meta_clothes:multichar:pauseDetection', function()
    restoreGeneration = restoreGeneration + 1
end)

-- Rebuild client-only registrations after an ensure/restart without treating
-- the already spawned player as a new character lifecycle.
AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    MBT.Utils.UpdatePlayerClothes()
    MBT.Utils.Target()
    MBT.Utils.StartHybridDetection()
end)

-- A stop must never leave a PED hidden that we hid ourselves: the timers die
-- with the instance and the restart path deliberately refuses alpha ownership,
-- so nobody would ever reveal it again.
--
-- This covers an orderly stop only. Surviving a crash would need a marker
-- outside Lua state, which could not tell our alpha 0 from another resource's
-- fade and would trample its transition.
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if MBT.Utils.CancelPedVisibilityWait then MBT.Utils.CancelPedVisibilityWait() end
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then
        MBT.Debugger('resource stop: no ped to reveal')
        return
    end
    -- The alpha BEFORE the reset tells whether the PED really was hidden by us:
    -- without it, "recovered" and "missed the window" look identical.
    local alphaBefore = GetEntityAlpha(ped)
    MBT.Trace.OwnAlpha(255)
    ResetEntityAlpha(ped)
    SetEntityAlpha(ped, 255, false)
    MBT.Debugger('resource stop: ped revealed', { alphaBefore = alphaBefore })
end)

-- Server requests PED scan (new players only, after Load completed)
RegisterNetEvent('mbt_meta_clothes:requestPedScan')
AddEventHandler('mbt_meta_clothes:requestPedScan', function(context, lifecycle)
    MBT.Trace.Mark('requestPedScan', { lifecycle = lifecycle })
    if not context or not MBT.SnapshotClient.SetContext(context) then return end
    local shouldObscure = MBT.PedVisibility.ShouldObscure(lifecycle)
    restoreGeneration = restoreGeneration + 1
    local myGen = restoreGeneration
    pendingInitialReveal = shouldObscure
        and { generation = myGen, session = context.session }
        or nil
    if shouldObscure then
        MBT.Trace.OwnAlpha(0)
        SetEntityAlpha(PlayerPedId(), 0, false)
        if MBT.Utils.SchedulePedVisibilityWatchdog then
            MBT.Utils.SchedulePedVisibilityWatchdog('requestPedScan')
        end
    end
    -- New player: let the appearance script apply ITS skin first, THEN scan the
    -- PED to populate our state.

    -- Resume detection immediately so the appearance script can apply its skin.
    -- Spawn/switch remains hidden; hot resource recovery preserves current alpha.
    if MBT.Utils.ResumeHybridDetection then
        MBT.Utils.ResumeHybridDetection()
    end
    MBT.SnapshotClient.Resume('character')
    MBT.SnapshotClient.SetRestoreProtection(false)

    -- The 2.5s give the appearance script time to apply the real outfit. Without
    -- it the scan captures the freshly spawned naked model and stores it as the
    -- baseline: from then on the player relogs naked forever.
    MBT.SnapshotClient.ForceInitialScan(2500)

    if not shouldObscure then
        MBT.Debugger('ped scan without visibility transition', lifecycle)
    end

    -- A guarded spawn reveals only after the initial snapshot ACK. Hot resource
    -- recovery never registered a pending reveal and leaves alpha untouched.
end)

AddEventHandler('mbt_meta_clothes:initialSnapshotReady', function(ack)
    local pending = pendingInitialReveal
    if not pending or type(ack) ~= 'table' or ack.session ~= pending.session
        or pending.generation ~= restoreGeneration then return end
    pendingInitialReveal = nil
    revealPed('initial_snapshot_ack')
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

-- Every restore bumps the generation, and delayed re-applies check it before
-- writing. Without this guard, in a char1->char2->char1 fast switch the first
-- character's re-applies would land on the second.
RegisterNetEvent('mbt_meta_clothes:restoreWearing')
AddEventHandler('mbt_meta_clothes:restoreWearing', function(wearingState, context, lifecycle)
    MBT.Trace.Mark('restoreWearing', { lifecycle = lifecycle, context = context ~= nil })
    if not wearingState then return end

    -- Legacy watchdog unblock: no context means this is not an authoritative
    -- restore and must never apply an empty state over the active character.
    if not context then
        if MBT.Utils.ResumeHybridDetection then MBT.Utils.ResumeHybridDetection() end
        revealPed('legacy_unblock')
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
    local shouldObscure = MBT.PedVisibility.ShouldObscure(lifecycle)
    MBT.SnapshotClient.Resume('character')

    -- Bump the generation: invalidates every re-apply left from the last restore
    restoreGeneration = restoreGeneration + 1
    local myGen = restoreGeneration
    pendingInitialReveal = nil
    if shouldObscure then
        MBT.Trace.OwnAlpha(0)
        SetEntityAlpha(PlayerPedId(), 0, false)
        if MBT.Utils.SchedulePedVisibilityWatchdog then
            MBT.Utils.SchedulePedVisibilityWatchdog('restoreWearing')
        end
    end

    -- Enable restore protection: for the next 15 seconds, Hybrid Detection
    -- will REVERT any external changes to our managed slots instead of tracking them.
    -- This prevents the appearance script from overwriting our restored state.
    MBT.Utils.EnableRestoreProtection(wearingState, MBT.RestoreProtection or 15000)

    -- Apply immediately — restore guard (100ms polling, 15s) handles late appearance script changes
    applyWearingState(wearingState)
    MBT.Trace.Mark('apply:done')

    -- Restart with the baseline on the EXPECTED state, not on the current PED:
    -- whatever the appearance script put on top stays a diff to correct, instead
    -- of being frozen in as normal.
    if MBT.Utils.ResumeHybridDetection then
        MBT.Utils.ResumeHybridDetection(wearingState)
    end

    -- Resource restart recovery never takes ownership of PED alpha. Restore
    -- protection still converges late appearance changes in the background.
    if not shouldObscure then
        MBT.Debugger('ped restore without visibility transition', lifecycle)
        return
    end

    -- Condition-based reveal: the PED must match the authoritative state without
    -- interruption. A late apply from any skin script resets the window and gets
    -- corrected before the PED becomes visible again.
    Citizen.CreateThread(function()
        local startedAt = GetGameTimer()
        local stableSince
        local lastMismatch
        local stableWindow = MBT.PedRevealStableWindow or 500
        local timeout = MBT.PedRevealTimeout or 4500

        while myGen == restoreGeneration and GetGameTimer() - startedAt < timeout do
            local matches, mismatch = MBT.SnapshotClient.MatchesWearing(wearingState)
            if matches then
                stableSince = stableSince or GetGameTimer()
                if GetGameTimer() - stableSince >= stableWindow then
                    revealPed('authoritative_wearing_stable')
                    return
                end
            else
                stableSince = nil
                if mismatch ~= lastMismatch then
                    lastMismatch = mismatch
                    MBT.Debugger('ped reveal waiting', mismatch)
                    MBT.Trace.Mark('converge:mismatch', { slot = mismatch })
                end
                applyWearingState(wearingState)
            end
            Citizen.Wait(100)
        end
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

-- The server already owns the authoritative state: these functions only apply
-- the visuals the server just confirmed, they do not persist them again.
local function applyDress(data)
    local meta = normalizeMetadata(data)
    MBT.Debugger("applyDress: slot", meta.index, "drawable", meta.drawable, "texture", meta.texture, "type", meta.type)
    MBT.Utils.ExpectChange("Drawables", meta.index)
    SetPedComponentVariation(PlayerPedId(), meta.index, meta.drawable, meta.texture, meta.palette)
    MBT.Utils.UpdatePlayerClothes()
    MBT.Utils.SendSlotUpdate("Drawables", meta.index, true)
end

local function applyKitDress(data)
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
end

local function applyProps(data)
    local meta = normalizeMetadata(data)
    MBT.Utils.ExpectChange("Props", meta.index)
    SetPedPropIndex(PlayerPedId(), meta.index, meta.drawable, meta.texture, true)
    -- Hat/hair clip fix: hide hair when putting on hat
    if MBT.Props[meta.index] and MBT.Props[meta.index]["ApplyHairFix"] then
        MBT.Utils.ApplyHatHairFix(PlayerPedId())
    end
    MBT.Utils.UpdatePlayerClothes()
    MBT.Utils.SendSlotUpdate("Props", meta.index, true)
end

RegisterNetEvent('mbt_meta_clothes:applyAuthoritativeDress', function(kind, payload)
    if kind == 'Drawable' then return applyDress(payload) end
    if kind == 'Prop' then return applyProps(payload) end
    if kind == 'DressKit' then return applyKitDress(payload) end
end)

RegisterNetEvent('mbt_meta_clothes:stealPlayerDress')
AddEventHandler('mbt_meta_clothes:stealPlayerDress', function(data)
    MBT.SharedClient.OpenStealMenu(data)
end, false)

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
AddEventHandler('mbt_meta_clothes:playVictimAnim', function(animKey, duration)
    MBT.Utils.PlayVictimStealAnimation(animKey, duration)
end)

RegisterNetEvent('mbt_meta_clothes:stopVictimAnim')
AddEventHandler('mbt_meta_clothes:stopVictimAnim', function()
    MBT.Utils.StopVictimStealAnimation()
end)

RegisterCommand("toggleUndress", function()
    if IsPedOnFoot(PlayerPedId()) and not IsPedDeadOrDying(PlayerPedId(), false) and not IsPedCuffed(PlayerPedId()) then
        local bagState = MBT.SharedClient.CheckBagState and MBT.SharedClient.CheckBagState() or false
        local maskState = MBT.SharedClient.CheckMaskState and MBT.SharedClient.CheckMaskState() or false
        local armorState = MBT.SharedClient.CheckArmorState and MBT.SharedClient.CheckArmorState() or false
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

        -- Which slots have a ClothingState. Hair is excluded because its shape is
        -- flat, not per-slot. Filtering by sex is required: without it a male with
        -- drawable X would look toggleable because of a female-only state.
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
                                -- Match only when the sex agrees (or the state does not specify one)
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
            -- UI labels from the active locale (hotspots, slot names, steal strings).
            -- One source of truth per language: Lua drives, React consumes.
            labels = MBT.Locale.UI or {},
            theme = MBT.Theme,
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
-- Fallback for when no target script is running: same eligibility and same
-- distance as the target interaction, only reached by command.
RegisterCommand("stealclothes", function()
    if MBT.StealEnabled == false then return end
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
                if dist < closestDist and MBT.TargetModule.CanStealFrom(targetPed) then
                    closestPed = targetPed
                    closestDist = dist
                end
            end
        end
    end

    if closestPed then
        MBT.SharedClient.OpenStealMenu({ entity = closestPed })
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

    -- We need a channel even with the menu closed, but not chat:addMessage: it
    -- assumes the `chat` resource, which many servers replace or remove, and there
    -- it vanished without a warning. MBT.Notification degrades to the native feed.
    local lvl = data.level or MBT.Locale["drip_unknown"]
    local lvlIdx = data.levelIndex or 1
    local xp = data.xp or 0
    local rate = data.rate or 0
    MBT.Notification({
        title = MBT.Locale["drip_label"],
        description = MBT.Locale["drip_info"]:format(lvl, lvlIdx, xp, rate),
        type = 'info',
        icon = 'fire',
    })
end)
