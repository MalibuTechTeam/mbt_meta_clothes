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
        exports.ox_inventory:AddItem(src, itemName, count, metadata)
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
