if GetResourceState('qb-core') ~= 'started' then return end
-- On QBox the authority is qbx_core: some servers keep a qb-core shim running
-- for legacy resources, and without this early return two bridges would activate
-- on the same player.
if GetResourceState('qbx_core') == 'started' then return end
if GetResourceState('qb-inventory') ~= 'started' then return end

QBCore = exports['qb-core']:GetCoreObject()

MBT.QbUseable.RegisterItems()
