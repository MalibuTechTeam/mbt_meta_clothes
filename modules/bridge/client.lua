-----------------------------------------------------------
-- Shared bridge client logic
-- Eliminates duplicated checkDress, inventory checks,
-- and stealPlayerDress across QB/ESX/OX bridges.
-----------------------------------------------------------

MBT.SharedClient = {}

--- Setup the checkDress event handler
--- @param sexToLabel function Converts raw sex value to "male"|"female"
function MBT.SharedClient.SetupCheckDress(sexToLabel)
    RegisterNetEvent('mbt_meta_clothes:checkDress')
    AddEventHandler('mbt_meta_clothes:checkDress', function(data)
        data.pedSex = sexToLabel(data.sex)
        local isDefault = true

        MBT.Utils.UpdatePlayerClothes()

        if type(data.index) == "table" and data.index["Arms"] then
            isDefault = MBT.Utils.HandleTopDress(data)
        else
            -- Normalize index to number: JSON deserializers can return string keys
            -- e.g. OX metadata may decode index as "6" instead of 6.
            local idx = tonumber(data.index) or data.index
            data.index = idx

            assert(
                MBT[data.type][idx] and
                MBT[data.type][idx]["Default"][data.pedSex] and
                type(MBT[data.type][idx]["Default"][data.pedSex]) == "table",
                "Invalid value or wrong type for key " .. tostring(idx)
            )

            -- Read current PED drawable directly — avoids any stale-cache edge cases
            local ped = PlayerPedId()
            local currentVariation
            if data.type == "Drawables" then
                currentVariation = GetPedDrawableVariation(ped, idx)
            else
                currentVariation = GetPedPropIndex(ped, idx)
            end

            if not MBT.TableContains(MBT[data.type][idx]["Default"][data.pedSex], currentVariation) then
                isDefault = false
            end
        end

        if isDefault then
            -- Prefer metadata.type ("Drawable"/"Prop"/"DressKit") over the inventory
            -- engine's own .type field (which is always "item" in ox_inventory and
            -- would shadow the correct value if checked first).
            local dressType
            if data.itemInfo and data.itemInfo.metadata and data.itemInfo.metadata.type then
                dressType = data.itemInfo.metadata.type
            elseif data.itemInfo and data.itemInfo.type then
                dressType = data.itemInfo.type
            end

            if not dressType then
                MBT.Debugger("checkDress: dressType is nil, cannot apply clothing")
                MBT.Notification(MBT.Locale["undress"])
                return
            end

            MBT.Debugger("checkDress: applying dressType =", dressType)

            if dressType == 'Drawable' then TriggerEvent("mbt_meta_clothes:applyDress", data.itemInfo) end
            if dressType == 'Prop'     then TriggerEvent("mbt_meta_clothes:applyProps", data.itemInfo) end
            if dressType == 'DressKit' then TriggerEvent("mbt_meta_clothes:applyKitDress", data.itemInfo) end
        else
            MBT.Notification(MBT.Locale["undress"])
        end
    end)
end

--- Setup inventory state check functions (checkMaskState, checkBagState, checkArmorState)
function MBT.SharedClient.SetupInventoryChecks()
    if GetResourceState('ox_inventory') ~= 'started' then
        function checkMaskState() return false end
        function checkBagState() return false end
        function checkArmorState() return false end
        return
    end

    function checkMaskState()
        -- Has mask item in inventory AND something non-default is on component 1 (mask slot)
        if exports.ox_inventory:Search('count', 'mask') < 1 then return false end
        return GetPedDrawableVariation(PlayerPedId(), 1) ~= 0
    end

    function checkBagState()
        -- Has bag item in inventory AND something non-default is on component 5 (bag slot)
        if exports.ox_inventory:Search('count', 'bag') < 1 then return false end
        return GetPedDrawableVariation(PlayerPedId(), 5) ~= 0
    end

    function checkArmorState()
        -- Has any armor item in inventory AND something non-default is on component 9 (armor slot)
        local hasItem = exports.ox_inventory:Search('count', 'smallarmor') >= 1
                     or exports.ox_inventory:Search('count', 'medarmor') >= 1
                     or exports.ox_inventory:Search('count', 'heavyarmor') >= 1
        if not hasItem then return false end
        return GetPedDrawableVariation(PlayerPedId(), 9) ~= 0
    end
end

--- Setup steal player dress function
function MBT.SharedClient.SetupStealDress()
    -- Store target data for NUI callbacks
    local stealTarget = {}
    local stealItemsList = {}

    function stealPlayerDress(data)
        local ped = PlayerPedId()
        local closestPlayer = data and data.entity

        if not closestPlayer then
            MBT.Debugger("stealPlayerDress: no target entity")
            return
        end

        local targetServerId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(closestPlayer))
        local targetSex = MBT.Utils.GetPedSex(closestPlayer)
        if not targetSex or targetSex == "customSkin" then return end

        -- Store target for NUI callbacks
        stealTarget = {
            ped = closestPlayer,
            serverId = targetServerId,
            thiefPed = ped
        }

        -- Build items list for NUI + victim wearing snapshot
        -- La NUI usa victimWearing per mostrare cosa indossa la vittima sul
        -- mannequin durante lo steal mode (altrimenti mostrerebbe i drawable
        -- del ladro, cosa che confonde totalmente l'utente).
        stealItemsList = {}
        local stealItems = stealItemsList
        local victimWearing = { Drawables = {}, Props = {} }

        -- Check torso kit
        local hasTorso = false
        for _, idx in ipairs(MBT.TorsoKitSlots or {}) do
            if MBT.Drawables[idx] and MBT.Drawables[idx]["Default"][targetSex] then
                local current = GetPedDrawableVariation(closestPlayer, idx)
                if not MBT.TableContains(MBT.Drawables[idx]["Default"][targetSex], current) then
                    hasTorso = true
                    -- Cattura ogni slot torso non-default del victim
                    victimWearing.Drawables[tostring(idx)] = {
                        index = idx,
                        drawable = current,
                        texture = GetPedTextureVariation(closestPlayer, idx),
                        palette = GetPedPaletteVariation(closestPlayer, idx),
                    }
                end
            end
        end
        if hasTorso then
            stealItems[#stealItems + 1] = {
                label = MBT.Locale["top"] or MBT.Locale["jacket"],
                stealType = "torso",
                slotIndex = nil
            }
        end

        -- Check other drawables
        for k, v in pairs(MBT.Drawables) do
            if not MBT.TableContains(MBT.TorsoKitSlots, k) and MBT.GetSlotItemNames(v)[1] and v["Default"][targetSex] then
                local current = GetPedDrawableVariation(closestPlayer, k)
                if not MBT.TableContains(v["Default"][targetSex], current) then
                    stealItems[#stealItems + 1] = {
                        label = MBT.Locale[MBT.SlotLocaleKeys.Drawables[k]] or ("Slot " .. k),
                        stealType = "drawable",
                        slotIndex = k
                    }
                    victimWearing.Drawables[tostring(k)] = {
                        index = k,
                        drawable = current,
                        texture = GetPedTextureVariation(closestPlayer, k),
                        palette = GetPedPaletteVariation(closestPlayer, k),
                    }
                end
            end
        end

        -- Check props
        for k, v in pairs(MBT.Props) do
            if MBT.GetSlotItemNames(v)[1] and v["Default"][targetSex] then
                local current = GetPedPropIndex(closestPlayer, k)
                if not MBT.TableContains(v["Default"][targetSex], current) then
                    stealItems[#stealItems + 1] = {
                        label = MBT.Locale[MBT.SlotLocaleKeys.Props[k]] or ("Prop " .. k),
                        stealType = "prop",
                        slotIndex = k
                    }
                    victimWearing.Props[tostring(k)] = {
                        index = k,
                        drawable = current,
                        texture = GetPedPropTextureIndex(closestPlayer, k),
                    }
                end
            end
        end

        if #stealItems == 0 then
            MBT.Notification(MBT.Locale["nothing_to_steal"])
            return
        end

        -- Send to NUI
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = "stealMenu",
            status = true,
            items = stealItems,
            wearing = victimWearing,
            sex = targetSex == "female" and 1 or 0,
            labels = MBT.Locale.UI or {},
        })
    end

    -- NUI callbacks for steal
    -- cb(1) viene chiamato subito; la logica steal gira in un Citizen.CreateThread
    -- per avere pieno supporto a Wait() e animazioni.
    RegisterNUICallback('handleStealItem', function(data, cb)
        SetNuiFocus(false, false)
        SendNUIMessage({action = "stealMenu", status = false})
        cb(1)

        local ped    = stealTarget.thiefPed
        local target = stealTarget.ped
        local server = stealTarget.serverId
        local sType  = data.stealType
        local sIdx   = data.slotIndex
        if ped and server then
            Citizen.CreateThread(function()
                MBT.Utils.StealSingleItem(ped, target, server, sType, sIdx)
            end)
        end
    end)

    RegisterNUICallback('handleStealAll', function(data, cb)
        SetNuiFocus(false, false)
        SendNUIMessage({action = "stealMenu", status = false})
        cb(1)

        local ped    = stealTarget.thiefPed
        local target = stealTarget.ped
        local server = stealTarget.serverId
        if ped and server then
            Citizen.CreateThread(function()
                MBT.Utils.StealAllItems(ped, target, server)
            end)
        end
    end)

    -- Multi-select confirm: NUI sends array of selected items
    RegisterNUICallback('confirmSteal', function(data, cb)
        SetNuiFocus(false, false)
        SendNUIMessage({action = "stealMenu", status = false})
        cb(1)

        if not stealTarget.ped or not stealTarget.serverId then return end

        local items = data.items
        if not items or #items == 0 then return end

        local ped    = stealTarget.thiefPed
        local target = stealTarget.ped
        local server = stealTarget.serverId

        -- Check if all stealable items are selected → use StealAll for efficiency
        if #items >= #stealItemsList then
            Citizen.CreateThread(function()
                MBT.Utils.StealAllItems(ped, target, server)
            end)
        else
            -- Multi-select parziale: UNA animazione patdown + server event per ogni item
            Citizen.CreateThread(function()
                MBT.Utils.StealMultipleItems(ped, target, server, items)
            end)
        end
    end)

    RegisterNUICallback('closeStealMenu', function(data, cb)
        SetNuiFocus(false, false)
        SendNUIMessage({action = "stealMenu", status = false})
        cb(1)
    end)
end
