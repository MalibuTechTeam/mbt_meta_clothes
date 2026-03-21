if GetResourceState('ox_core') ~= 'started' then return end

local file = ('imports/%s.lua'):format(IsDuplicityVersion() and 'server' or 'client')
local import = LoadResourceFile('ox_core', file)
local chunk = assert(load(import, ('@@ox_core/%s'):format(file)))
chunk()

MBT.OxItems.RegisterItems(function()
    local sex = player.get('gender')
    local sexLabel = sex == "m" and "male" or "female"
    return sex, sexLabel
end)
