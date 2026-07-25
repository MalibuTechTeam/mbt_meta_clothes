if GetResourceState('ox_core') ~= 'started' then return end

local file = ('imports/%s.lua'):format(IsDuplicityVersion() and 'server' or 'client')
local import = LoadResourceFile('ox_core', file)
local chunk = assert(load(import, ('@@ox_core/%s'):format(file)))
chunk()

-- OX Core always uses ox_inventory
MBT.GiveItems.Setup({
    getPlayer = function(src) return Ox.GetPlayer(src) end,
    getPlayerName = function(player) return player.name end,
    getPlayerSource = function(player) return player.source end,
    addItem = function(src, itemName, count, metadata)
        local success, response = exports.ox_inventory:AddItem(src, itemName, count, metadata)
        return MBT.GiveItems.NormalizeAddResult(success, response)
    end
})

---@param src number
---@return string|nil
function getPlayerIdentifier(src)
    local player = Ox.GetPlayer(src)
    if player then
        return tostring(player.stateId)
    end
end

-----------------------------------------------------------
-- Multicharacter switch — server-side handlers
-----------------------------------------------------------

-- ox:playerLoaded fires server-side quando un character viene caricato
-- (compreso multicharacter switch).
AddEventHandler('ox:playerLoaded', function(src)
    MBT.PlayerState.PushStateToClient(src)
end)

-- Pre-logout: salva lo stato del character che sta uscendo prima che
-- l'Ox player venga distrutto.
AddEventHandler('ox:playerLogout', function(src)
    TriggerClientEvent('mbt_meta_clothes:multichar:pauseDetection', src)
    if MBT.PlayerState.IsLoaded(src) then
        MBT.PlayerState.Save(src)
    end
    MBT.SnapshotServer.Cleanup(src)
end)
