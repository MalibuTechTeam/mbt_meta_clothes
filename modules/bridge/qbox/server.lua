if GetResourceState('qbx_core') ~= 'started' then return end

-- QBox does not expose GetCoreObject: we work with the direct qbx_core exports.
-- The pcall guards the case where the resource reports 'started' but its
-- exports are not registered yet.
local function getPlayer(src)
    local ok, player = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    if ok and player then return player end
    return nil
end

local isOXInventory = GetResourceState('ox_inventory'):find('start')

-- QBox requires ox_inventory: no qb-inventory branch here, only OX plus the
-- custom fallback for servers running their own inventory.
local function addItem(src, itemName, count, metadata)
    if isOXInventory then
        local success, response = exports.ox_inventory:AddItem(src, itemName, count, metadata)
        return MBT.GiveItems.NormalizeAddResult(success, response)
    elseif type(MBT.CustomInventory) == 'function' then
        return MBT.GiveItems.CallCustom(MBT.CustomInventory, src, itemName, count, metadata)
    else
        MBT.ServerUtils.PrintWarning()
        return false, 'unsupported_inventory'
    end
end

local function getPlayerName(player)
    local data = player and player.PlayerData
    if not data then return nil end
    local charinfo = data.charinfo
    if charinfo and charinfo.firstname and charinfo.lastname then
        return charinfo.firstname .. ' ' .. charinfo.lastname
    end
    return data.name
end

MBT.GiveItems.Setup({
    getPlayer = getPlayer,
    getPlayerName = getPlayerName,
    getPlayerSource = function(player) return player.PlayerData.source end,
    addItem = addItem
})

---@param src number
---@return string|nil
function getPlayerIdentifier(src)
    local player = getPlayer(src)
    if player and player.PlayerData then
        return player.PlayerData.citizenid
    end
end

-----------------------------------------------------------
-- Multicharacter switch — server-side handlers
--
-- QBox fires the legacy QBCore names *and* its own. We listen to both,
-- because the legacy compatibility is documented but not guaranteed forever,
-- and a double arrival is harmless: PushStateToClient is already debounced.
-----------------------------------------------------------

local function onLoaded(player)
    local src = player and player.PlayerData and player.PlayerData.source
    if not src then return end
    MBT.PlayerState.PushStateToClient(src)
end

AddEventHandler('QBCore:Server:PlayerLoaded', onLoaded)
AddEventHandler('qbx_core:server:playerLoaded', onLoaded)

local function onUnload(src)
    if not src then return end
    TriggerClientEvent('mbt_meta_clothes:multichar:pauseDetection', src)
    if MBT.PlayerState.IsLoaded(src) then
        MBT.PlayerState.Save(src)
    end
    MBT.SnapshotServer.Cleanup(src)
end

AddEventHandler('QBCore:Server:OnPlayerUnload', onUnload)
AddEventHandler('qbx_core:server:playerLoggedOut', onUnload)
