if GetResourceState('qb-core') ~= 'started' then return end

QBCore = exports['qb-core']:GetCoreObject()

local isQBInventory = GetResourceState('qb-inventory'):find('start')
local isOXInventory = GetResourceState('ox_inventory'):find('start')

-- Inventory-agnostic addItem: tries OX → QB → Custom fallback
local function addItem(src, itemName, count, metadata)
    if isOXInventory then
        local success, response = exports.ox_inventory:AddItem(src, itemName, count, metadata)
        return MBT.GiveItems.NormalizeAddResult(success, response)
    elseif isQBInventory then
        local player = QBCore.Functions.GetPlayer(src)
        if not player then return false, 'invalid_player' end

        local success = player.Functions.AddItem(itemName, count, false, metadata)
        if success then
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], "add")
        end
        return MBT.GiveItems.NormalizeAddResult(success, success and nil or 'inventory_full')
    else
        if type(MBT.CustomInventory) == 'function' then
            return MBT.GiveItems.CallCustom(MBT.CustomInventory, src, itemName, count, metadata)
        else
            MBT.ServerUtils.PrintWarning()
            return false, 'unsupported_inventory'
        end
    end
end

-- Setup shared give* global functions
MBT.GiveItems.Setup({
    getPlayer = function(src) return QBCore.Functions.GetPlayer(src) end,
    getPlayerName = function(player) return player.PlayerData.name end,
    getPlayerSource = function(player) return player.PlayerData.source end,
    addItem = addItem
})

---@param src number
---@return string
function getPlayerIdentifier(src)
    local player = QBCore.Functions.GetPlayer(src)
    if player then
        return player.PlayerData.citizenid
    end
end

-----------------------------------------------------------
-- Multicharacter switch — server-side handlers
-----------------------------------------------------------

-- QBCore:Server:PlayerLoaded fires server-side con il Player già pronto.
-- Qui getPlayerIdentifier(src) restituisce SEMPRE il citizenid corretto.
AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    local src = Player and Player.PlayerData and Player.PlayerData.source
    if not src then return end
    MBT.PlayerState.PushStateToClient(src)
end)

-- Pre-unload: salva lo stato del character che sta uscendo
AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
    TriggerClientEvent('mbt_meta_clothes:multichar:pauseDetection', src)
    if MBT.PlayerState.IsLoaded(src) then
        MBT.PlayerState.Save(src)
    end
    MBT.SnapshotServer.Cleanup(src)
end)
