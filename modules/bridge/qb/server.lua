if GetResourceState('qb-core') ~= 'started' then return end

QBCore = exports['qb-core']:GetCoreObject()

local isQBInventory = GetResourceState('qb-inventory'):find('start')
local isOXInventory = GetResourceState('ox_inventory'):find('start')

-- Inventory-agnostic addItem: tries OX → QB → Custom fallback
local function addItem(src, itemName, count, metadata)
    if isOXInventory then
        exports.ox_inventory:AddItem(src, itemName, count, metadata)
    elseif isQBInventory then
        local player = QBCore.Functions.GetPlayer(src)
        if player then
            player.Functions.AddItem(itemName, count, false, metadata)
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], "add")
        end
    else
        assert(type(MBT.CustomInventory) == 'function', MBT.ServerUtils.PrintWarning())
        MBT.CustomInventory(itemName, metadata)
    end
end

-- Setup shared give* global functions
MBT.GiveItems.Setup({
    getPlayer = function(src) return QBCore.Functions.GetPlayer(src) end,
    getPlayerName = function(player) return player.PlayerData.name end,
    getPlayerSource = function(player) return player.PlayerData.source end,
    addItem = addItem
})

RegisterNetEvent('mbt_meta_clothes:removeWear', function(itemName)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    Player.Functions.RemoveItem(itemName, 1)
end)

---@param src number
---@return string
function getPlayerIdentifier(src)
    local player = QBCore.Functions.GetPlayer(src)
    if player then
        return player.PlayerData.citizenid
    end
end
