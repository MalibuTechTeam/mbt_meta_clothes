if GetResourceState('qb-core') ~= 'started' then return end
-- Su QBox l'autorità è qbx_core: alcuni server tengono acceso uno shim
-- qb-core per risorse legacy, e senza questa uscita si attiverebbero due
-- bridge sullo stesso player.
if GetResourceState('qbx_core') == 'started' then return end
if GetResourceState('qb-inventory') ~= 'started' then return end

QBCore = exports['qb-core']:GetCoreObject()

MBT.QbUseable.RegisterItems()
