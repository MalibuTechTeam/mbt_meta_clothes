if GetResourceState('es_extended') ~= 'started' then return end

ESX = exports.es_extended:getSharedObject()

local isOXInventory = GetResourceState('ox_inventory'):find('start')

-- Inventory-agnostic addItem: tries OX → Custom fallback
local function addItem(src, itemName, count, metadata)
    if isOXInventory then
        exports.ox_inventory:AddItem(src, itemName, count, metadata)
    else
        assert(type(MBT.CustomInventory) == 'function', MBT.ServerUtils.PrintWarning())
        MBT.CustomInventory(itemName, metadata)
    end
end

-- Setup shared give* global functions
MBT.GiveItems.Setup({
    getPlayer = function(src) return ESX.GetPlayerFromId(src) end,
    getPlayerName = function(player) return player.getName() end,
    getPlayerSource = function(player) return player.source end,
    addItem = addItem
})

---@param src number
---@return string
function getPlayerIdentifier(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer then return xPlayer.identifier end
end
