-----------------------------------------------------------
-- Shared bridge client logic
-- Eliminates duplicated inventory checks and stealPlayerDress
-- across QB/ESX/OX bridges.
-----------------------------------------------------------

MBT.SharedClient = {}

--- Setup inventory state checks used while building the clothing NUI state.
function MBT.SharedClient.SetupInventoryChecks()
    if GetResourceState('ox_inventory') ~= 'started' then
        MBT.SharedClient.CheckMaskState = function() return false end
        MBT.SharedClient.CheckBagState = function() return false end
        MBT.SharedClient.CheckArmorState = function() return false end
        return
    end

    function MBT.SharedClient.CheckMaskState()
        -- Has mask item in inventory AND something non-default is on component 1 (mask slot)
        if exports.ox_inventory:Search('count', 'mask') < 1 then return false end
        return GetPedDrawableVariation(PlayerPedId(), 1) ~= 0
    end

    function MBT.SharedClient.CheckBagState()
        -- Has bag item in inventory AND something non-default is on component 5 (bag slot)
        if exports.ox_inventory:Search('count', 'bag') < 1 then return false end
        return GetPedDrawableVariation(PlayerPedId(), 5) ~= 0
    end

    function MBT.SharedClient.CheckArmorState()
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

    function MBT.SharedClient.OpenStealMenu(data)
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
        -- The NUI uses victimWearing to show what the victim is wearing on the
        -- mannequin during steal mode (otherwise it would show the thief's own
        -- drawables, which is thoroughly confusing).
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
                    -- Capture every non-default torso slot of the victim
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
            theme = MBT.Theme,
        })
    end

    -- NUI callbacks for steal
    -- cb(1) is called immediately; the steal logic runs inside a
    -- Citizen.CreateThread so Wait() and animations are fully supported.
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
            -- Partial multi-select: ONE patdown animation + a server event per item
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
