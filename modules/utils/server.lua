MBT.ServerUtils = {}

---@param repository string
function MBT.ServerUtils.MbtVersionCheck(repository)
    local resource = GetInvokingResource() or GetCurrentResourceName()

    local currentVersion = GetResourceMetadata(resource, 'version', 0)

    if currentVersion then
        currentVersion = currentVersion:match('%d+%.%d+%.%d+')
    end

    if not currentVersion then
        return MBT.Error('unable to determine current resource version', { resource = resource })
    end

    SetTimeout(1000, function()
        PerformHttpRequest(('https://api.github.com/repos/%s/releases/latest'):format(repository), function(status, response)
            if status ~= 200 then return end

            response = json.decode(response)
            if response.prerelease then return end

            local latestVersion = response.tag_name:match('%d+%.%d+%.%d+')
            if not latestVersion or latestVersion == currentVersion then return end

            local cv = { string.strsplit('.', currentVersion) }
            local lv = { string.strsplit('.', latestVersion) }

            for i = 1, #cv do
                local current, minimum = tonumber(cv[i]), tonumber(lv[i])

                if current ~= minimum then
                    if current < minimum then
                        return MBT.Info('resource update available', {
                            resource = resource,
                            currentVersion = currentVersion,
                            url = response.html_url,
                        })
                    else break end
                end
            end
        end, 'GET')
    end)
end

function MBT.ServerUtils.PrintWarning()
    MBT.Warn("You are using a different type of inventory, please fill the custom events in config.lua. Discord: https://discord.gg/tqk3kAEr4f")
end


-----------------------------------------------------------
-- Security: Input validation + Rate limiting + Proximity check
-----------------------------------------------------------

--- Validate slotType and slotIndex (derived from config)
function MBT.ServerUtils.ValidateSlot(slotType, slotIndex)
    if slotType ~= "Drawables" and slotType ~= "Props" then return false end
    local slots = slotType == "Drawables" and MBT.Drawables or MBT.Props
    if not slots then return false end
    local idx = tonumber(slotIndex)
    if not idx then return false end
    return slots[idx] ~= nil, idx
end

--- Rate limiter: per-source, per-event
local rateLimits = {} -- [source] = { [eventName] = { count, lastReset } }

function MBT.ServerUtils.CheckRateLimit(src, eventName)
    local now = GetGameTimer()
    if not rateLimits[src] then rateLimits[src] = {} end
    if not rateLimits[src][eventName] then
        rateLimits[src][eventName] = { count = 0, lastReset = now }
    end

    local limit = rateLimits[src][eventName]
    if now - limit.lastReset > (MBT.RateLimitWindow or 2000) then
        limit.count = 0
        limit.lastReset = now
    end

    limit.count = limit.count + 1
    if limit.count > (MBT.RateLimitMax or 5) then
        MBT.Debugger("RATE LIMITED:", src, eventName, limit.count, "calls in window")
        return false
    end
    return true
end

-- Cleanup rate limits on disconnect
AddEventHandler('playerDropped', function()
    rateLimits[source] = nil
end)

--- Check proximity between two players (server-side)
function MBT.ServerUtils.CheckProximity(src1, src2, maxDistance)
    local ped1 = GetPlayerPed(src1)
    local ped2 = GetPlayerPed(src2)
    if not ped1 or ped1 == 0 or not ped2 or ped2 == 0 then return false end

    local c1 = GetEntityCoords(ped1)
    local c2 = GetEntityCoords(ped2)
    local dist = #(c1 - c2)
    return dist <= (maxDistance or 5.0)
end

--- Validate that a source is a real online player
function MBT.ServerUtils.IsValidPlayer(src)
    return src and GetPlayerPing(src) > 0
end

--- Require a victim-owned replicated observation before allowing a steal.
--- A forged thief payload cannot write another player's state bag; a modified
--- victim can only consent to being stolen from themselves.
function MBT.ServerUtils.IsPlayerStealable(src)
    if not MBT.ServerUtils.IsValidPlayer(src) then return false end
    local player = Player(src)
    return player and player.state[MBT.StealableStateKey] == true or false
end

--- Resolve the active PED sex from the server-owned network entity.
--- This keeps inventory metadata independent from client-provided sex values.
---@param src number Player source
---@return string|nil sex
function MBT.ServerUtils.GetPlayerSex(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local model = GetEntityModel(ped)
    return MBT.NormalizeSex(MBT.GenderModels and MBT.GenderModels[model])
end

--- Check if wearable_props has gloves export available
--- Cached at startup to avoid repeated pcall overhead
local hasGlovesExport = false
if GetResourceState('mbt_wearable_props') == 'started' then
    local ok, result = pcall(function()
        return exports.mbt_wearable_props:isPlayerWearingGloves(0)
    end)
    hasGlovesExport = ok
end

--- Inject DNA into clothing metadata when a player dresses
--- Only injects on "big" clothing slots (torso, pants, shoes, hat) — not accessories
--- @param metadata table Item metadata to inject DNA into
--- @param src number Player source
function MBT.ServerUtils.InjectDNA(metadata, src)
    if not MBT.DnaEnabled then return end
    if not metadata then return end

    -- Only inject DNA on slots that make sense (big clothing, not small accessories)
    local dnaSlots = {
        Drawables = { [3] = true, [4] = true, [6] = true, [8] = true, [11] = true },
        Props = { [0] = true }
    }
    local slotType = metadata.type == "Drawable" and "Drawables" or (metadata.type == "Prop" and "Props" or nil)
    if not slotType or not dnaSlots[slotType] then return end
    if not dnaSlots[slotType][metadata.index] then return end

    -- Check gloves (wearable_props integration) — skip DNA if wearing gloves
    if hasGlovesExport then
        local wearing = exports.mbt_wearable_props:isPlayerWearingGloves(src)
        if wearing then return end
    end

    -- Get player identifier for DNA
    local identifier = nil
    if getPlayerIdentifier then
        identifier = getPlayerIdentifier(src)
    end
    if not identifier then return end

    -- Initialize last_worn_by array if needed
    if not metadata.last_worn_by then
        metadata.last_worn_by = {}
    end

    -- Don't add duplicate (player already in DNA list)
    for _, dna in ipairs(metadata.last_worn_by) do
        if dna.identifier == identifier then return end
    end

    -- Add DNA entry with timestamp
    table.insert(metadata.last_worn_by, {
        identifier = identifier,
        timestamp = os.time()
    })

    -- Trim to max entries (FIFO)
    while #metadata.last_worn_by > (MBT.DnaMaxEntries or 3) do
        table.remove(metadata.last_worn_by, 1)
    end
end

--- Clean expired DNA entries from metadata
--- @param metadata table Item metadata
function MBT.ServerUtils.CleanExpiredDNA(metadata)
    if not MBT.DnaEnabled then return end
    if not metadata or not metadata.last_worn_by then return end

    local expirySeconds = (MBT.DnaExpiryHours or 48) * 3600
    local now = os.time()
    local cleaned = {}

    for _, dna in ipairs(metadata.last_worn_by) do
        if (now - (dna.timestamp or 0)) < expirySeconds then
            cleaned[#cleaned + 1] = dna
        end
    end

    metadata.last_worn_by = #cleaned > 0 and cleaned or nil
end

MBT.ServerUtils.MbtVersionCheck('MalibuTechTeam/mbt_meta_clothes')
