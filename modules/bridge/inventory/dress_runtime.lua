MBT = MBT or {}
MBT.DressRuntime = MBT.DressRuntime or {}

local initialized = false
local clothingItems = {}
local qbAdapter

local function notify(src, reason)
    local locale = reason == 'slot_occupied' and MBT.Locale['undress'] or MBT.Locale['inventory_error']
    TriggerClientEvent('mbt_meta_clothes:notify', src, locale or {
        type = 'error',
        description = reason or 'Inventory error',
    })
end

local function logFailure(adapter, src, itemName, reason)
    local message = ('%s dress failed src=%s item=%s reason=%s'):format(
        adapter,
        tostring(src),
        tostring(itemName),
        tostring(reason)
    )
    if reason == 'rollback_failed' then
        MBTLog.Error(message)
    else
        MBTLog.Warn(message)
    end
end

local function indexClothingItems()
    clothingItems.topdress = true
    for _, slots in ipairs({ MBT.Drawables or {}, MBT.Props or {} }) do
        for _, slotConfig in pairs(slots) do
            for _, itemName in ipairs(MBT.GetSlotItemNames(slotConfig)) do
                clothingItems[itemName] = true
            end
        end
    end
end

local function createAuthority()
    return MBT.DressAuthority.New({
        PlayerState = MBT.PlayerState,
        Drawables = MBT.Drawables,
        Props = MBT.Props,
        TorsoKitSlots = MBT.TorsoKitSlots,
        TorsoSlotNames = MBT.TorsoSlotNames,
        Bounds = MBT.SnapshotBounds,
        normalizeSex = MBT.NormalizeSex,
        getPlayerSex = MBT.ServerUtils.GetPlayerSex,
        injectDNA = MBT.ServerUtils.InjectDNA,
        apply = function(src, kind, payload)
            TriggerClientEvent('mbt_meta_clothes:applyAuthoritativeDress', src, kind, payload)
        end,
    })
end

local function setupOx(authority)
    if GetResourceState('ox_inventory') ~= 'started' then return end

    local adapter = MBT.DressAdapters.NewOx({
        authority = authority,
        restoreItem = function(src, itemName, count, metadata)
            local success = exports.ox_inventory:AddItem(src, itemName, count, metadata)
            return success == true
        end,
    })

    exports.ox_inventory:registerHook('usingItem', function(payload)
        local item = payload and payload.item
        if type(item) ~= 'table' then return false end

        local allowed, reason = adapter:CanUse(payload.source, item.name, item.metadata)
        if not allowed then
            notify(payload.source, reason)
            return false
        end
    end, { itemFilter = clothingItems })

    AddEventHandler('ox_inventory:usedItem', function(inventoryId, itemName, slot, metadata)
        if not clothingItems[itemName] then return end
        local src = tonumber(inventoryId)
        if not src then return end

        local result = adapter:CommitUsed(src, itemName, slot, metadata)
        if not result.ok then
            logFailure('ox_inventory', src, itemName, result.reason)
            notify(src, result.reason)
        end
    end)
end

local function setupQb(authority)
    if GetResourceState('qb-core') ~= 'started' or GetResourceState('qb-inventory') ~= 'started' then return end

    qbAdapter = MBT.DressAdapters.NewQb({
        authority = authority,
        getItemBySlot = function(src, slot)
            local player = QBCore and QBCore.Functions.GetPlayer(src)
            return player and player.Functions.GetItemBySlot(slot) or nil
        end,
        removeItem = function(src, itemName, count, slot)
            local player = QBCore and QBCore.Functions.GetPlayer(src)
            if not player then return false end
            local success = player.Functions.RemoveItem(itemName, count, slot)
            if success and QBCore.Shared.Items[itemName] then
                TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], 'remove')
            end
            return success == true
        end,
        restoreItem = function(src, itemName, count, metadata, slot)
            local player = QBCore and QBCore.Functions.GetPlayer(src)
            return player and player.Functions.AddItem(itemName, count, slot, metadata) == true or false
        end,
    })

    RegisterNetEvent('mbt_meta_clothes:completeClothingUse', function(token)
        local src = source
        local result = qbAdapter:Complete(src, token)
        if not result.ok then
            logFailure('qb-inventory', src, 'pending', result.reason)
            notify(src, result.reason)
        end
    end)

    RegisterNetEvent('mbt_meta_clothes:cancelClothingUse', function(token)
        qbAdapter:Cancel(source, token)
    end)

    AddEventHandler('playerDropped', function()
        qbAdapter:Cleanup(source)
    end)
end

function MBT.DressRuntime.Initialize()
    if initialized then return end
    initialized = true
    indexClothingItems()

    local authority = createAuthority()
    MBT.DressRuntime.Authority = authority
    setupOx(authority)
    setupQb(authority)
end

function MBT.DressRuntime.BeginQb(src, item, duration)
    if not qbAdapter then return { ok = false, reason = 'unsupported_inventory' } end
    return qbAdapter:Begin(src, item, duration)
end
