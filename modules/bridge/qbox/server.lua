if GetResourceState('qbx_core') ~= 'started' then return end

-- QBox non espone GetCoreObject: si lavora con gli export diretti di qbx_core.
-- Il pcall protegge dal caso in cui la risorsa risulti 'started' ma gli export
-- non siano ancora registrati.
local function getPlayer(src)
    local ok, player = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    if ok and player then return player end
    return nil
end

local isOXInventory = GetResourceState('ox_inventory'):find('start')

-- QBox richiede ox_inventory: nessun ramo qb-inventory qui, solo OX e il
-- fallback custom per chi ha un inventario proprio.
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
-- QBox emette i nomi legacy di QBCore *e* i propri. Ascoltiamo entrambi
-- perché la compatibilità legacy è dichiarata ma non garantita a vita, e un
-- doppio arrivo non fa danno: PushStateToClient è già debounced.
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
