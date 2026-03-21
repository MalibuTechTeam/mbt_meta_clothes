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
            assert(
                MBT[data.type][data.index]["Default"][data.pedSex] and
                type(MBT[data.type][data.index]["Default"][data.pedSex]) == "table",
                "Invalid value or wrong type for key " .. data.index
            )

            if not playerWearing[data.type] or not MBT.Utils.TableContainsValue({
                table = MBT[data.type][data.index]["Default"][data.pedSex],
                value = playerWearing[data.type][data.index]
            }) then
                isDefault = false
            end
        end

        if isDefault then
            local dressType
            if data.itemInfo and data.itemInfo.type then
                dressType = data.itemInfo.type
            elseif data.itemInfo and data.itemInfo.metadata and data.itemInfo.metadata.type then
                dressType = data.itemInfo.metadata.type
            end

            if not dressType then
                MBT.Utils.MbtDebugger("checkDress: dressType is nil, cannot apply clothing")
                MBT.NotifyHandler(MBT.Labels["undress"], "error")
                return
            end

            if dressType == 'Drawable' then TriggerEvent("mbt_meta_clothes:applyDress", data.itemInfo) end
            if dressType == 'Prop'     then TriggerEvent("mbt_meta_clothes:applyProps", data.itemInfo) end
            if dressType == 'DressKit' then TriggerEvent("mbt_meta_clothes:applyKitDress", data.itemInfo) end
        else
            MBT.NotifyHandler(MBT.Labels["undress"], "error")
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
        local maskCount = exports.ox_inventory:Search('count', 'mask')
        return maskCount >= 1
    end

    function checkBagState()
        local bagCount = exports.ox_inventory:Search('count', 'bag')
        return bagCount >= 1
    end

    function checkArmorState()
        local armorCount = exports.ox_inventory:Search('count', {'smallarmor', 'medarmor', 'heavyarmor'})
        for _, v in pairs(armorCount) do
            if v >= 1 then return true end
        end
        return false
    end
end

--- Setup steal player dress function
function MBT.SharedClient.SetupStealDress()
    function stealPlayerDress(data)
        local ped = PlayerPedId()
        local closestPlayer = data and data.entity

        if not closestPlayer then
            MBT.Utils.MbtDebugger("stealPlayerDress: no target entity")
            return
        end

        if exports.ox_lib:progressCircle({
            duration = 2000,
            label = 'Steal clothes',
            position = 'bottom',
            useWhileDead = false,
            canCancel = true,
            disable = {
                car = true,
                move = true,
                combat = true,
            },
        }) then
            MBT.Utils.StealAnim()
            TriggerServerEvent('mbt_meta_clothes:syncStealDress', GetPlayerServerId(NetworkGetPlayerIndexFromPed(closestPlayer)))
        else
            print('Do stuff when cancelled')
        end
    end
end
