-----------------------------------------------------------
-- Drip Reputation Engine (server-side)
--
-- Calculates a "drip rate" from the player's current outfit
-- and periodically adds it to their cumulative Drip XP.
-- XP never decreases — it's a fashion career, not a score.
--
-- Server owners configure DripValues per drawable in config.lua.
-- Unconfigured drawables use DefaultDrip fallback.
-- Default drawables (nude/base) = 0 rate.
--
-- Exports:
--   getPlayerDripXp(src) → number
--   getPlayerDripLevel(src) → name, index, progress
--   getPlayerDripRate(src) → number
-----------------------------------------------------------

MBT.Drip = {}

--- Calculate the instantaneous drip rate from a player's current outfit
--- @param src number Player source
--- @return number rate The drip points per tick this outfit earns
function MBT.Drip.CalculateRate(src)
    local wearing = MBT.PlayerState.GetAll(src)
    if not wearing then return 0 end

    local rate = 0
    local defaultDrip = MBT.DefaultDrip or 1

    -- Drawables
    for slotIndex, metadata in pairs(wearing.Drawables or {}) do
        local slotConfig = MBT.Drawables[slotIndex]
        if slotConfig and metadata and metadata.drawable then
            -- metadata.dripValue overrides all config-based values (validate number to prevent injection)
            if type(metadata.dripValue) == "number" then
                rate = rate + metadata.dripValue
            else
                local drawableIdx = tonumber(metadata.drawable) or metadata.drawable
                local dripValues = slotConfig["DripValues"]
                if dripValues and dripValues[drawableIdx] then
                    rate = rate + dripValues[drawableIdx]
                elseif slotConfig["DefaultDrip"] then
                    rate = rate + slotConfig["DefaultDrip"]
                else
                    rate = rate + defaultDrip
                end
            end
        end
    end

    -- Props
    for slotIndex, metadata in pairs(wearing.Props or {}) do
        local slotConfig = MBT.Props[slotIndex]
        if slotConfig and metadata and metadata.drawable then
            -- metadata.dripValue overrides all config-based values (validate number)
            if type(metadata.dripValue) == "number" then
                rate = rate + metadata.dripValue
            else
                local drawableIdx = tonumber(metadata.drawable) or metadata.drawable
                local dripValues = slotConfig["DripValues"]
                if dripValues and dripValues[drawableIdx] then
                    rate = rate + dripValues[drawableIdx]
                elseif slotConfig["DefaultDrip"] then
                    rate = rate + slotConfig["DefaultDrip"]
                else
                    rate = rate + defaultDrip
                end
            end
        end
    end

    -- Future: wearable_props bonus via export
    -- if GetResourceState('mbt_wearable_props') == 'started' then
    --     local bonus = exports.mbt_wearable_props:getDripBonus(src)
    --     rate = rate + (bonus or 0)
    -- end

    return rate
end

--- Calculate the breakdown of drip points per item
--- @param src number Player source
--- @return table breakdown A list of { type, index, rate }
function MBT.Drip.CalculateBreakdown(src)
    local wearing = MBT.PlayerState.GetAll(src)
    if not wearing then return {} end

    local breakdown = {}
    local defaultDrip = MBT.DefaultDrip or 1

    -- Drawables
    for slotIndex, metadata in pairs(wearing.Drawables or {}) do
        local slotConfig = MBT.Drawables[slotIndex]
        if slotConfig and metadata and metadata.drawable then
            local rate = 0
            if type(metadata.dripValue) == "number" then
                rate = metadata.dripValue
            else
                local drawableIdx = tonumber(metadata.drawable) or metadata.drawable
                local dripValues = slotConfig["DripValues"]
                if dripValues and dripValues[drawableIdx] then
                    rate = dripValues[drawableIdx]
                elseif slotConfig["DefaultDrip"] then
                    rate = slotConfig["DefaultDrip"]
                else
                    rate = defaultDrip
                end
            end

            if rate > 0 then
                table.insert(breakdown, { slotType = "Drawables", slotIndex = slotIndex, rate = rate })
            end
        end
    end

    -- Props
    for slotIndex, metadata in pairs(wearing.Props or {}) do
        local slotConfig = MBT.Props[slotIndex]
        if slotConfig and metadata and metadata.drawable then
            local rate = 0
            if type(metadata.dripValue) == "number" then
                rate = metadata.dripValue
            else
                local drawableIdx = tonumber(metadata.drawable) or metadata.drawable
                local dripValues = slotConfig["DripValues"]
                if dripValues and dripValues[drawableIdx] then
                    rate = dripValues[drawableIdx]
                elseif slotConfig["DefaultDrip"] then
                    rate = slotConfig["DefaultDrip"]
                else
                    rate = defaultDrip
                end
            end

            if rate > 0 then
                table.insert(breakdown, { slotType = "Props", slotIndex = slotIndex, rate = rate })
            end
        end
    end

    return breakdown
end

--- Get the drip level and progress from XP amount
--- @param xp number Total drip XP
--- @return table level The current level {name, minXp, index}
--- @return number progress 0.0-1.0 progress toward next level
function MBT.Drip.GetLevel(xp)
    xp = xp or 0
    local levels = MBT.DripLevels
    if not levels or #levels == 0 then
        return { name = MBT.Locale["drip_unknown"] or "Unknown", minXp = 0, index = 1 }, 1.0
    end

    local currentLevel = levels[1]
    local currentIndex = 1

    for i = #levels, 1, -1 do
        if xp >= levels[i].minXp then
            currentLevel = levels[i]
            currentIndex = i
            break
        end
    end

    -- Calculate progress toward next level
    local nextLevel = levels[currentIndex + 1]
    local progress
    if nextLevel then
        local range = nextLevel.minXp - currentLevel.minXp
        progress = range > 0 and ((xp - currentLevel.minXp) / range) or 1.0
    else
        progress = 1.0 -- max level reached
    end

    return {
        name = currentLevel.name,
        minXp = currentLevel.minXp,
        index = currentIndex
    }, progress
end

-----------------------------------------------------------
-- /drip command handler — player requests their drip info
-----------------------------------------------------------
RegisterNetEvent('mbt_meta_clothes:requestDripInfo', function()
    local src = source
    if not MBT.PlayerState.IsLoaded(src) then return end

    local totalXp = MBT.PlayerState.GetDripXp(src)
    local rate = MBT.Drip.CalculateRate(src)
    local level, progress = MBT.Drip.GetLevel(totalXp)
    local breakdown = MBT.Drip.CalculateBreakdown(src)

    local dripData = {
        xp = totalXp,
        rate = rate,
        level = level.name,
        levelIndex = level.index or 1,
        progress = progress,
        breakdown = breakdown
    }
    MBT.Debugger("dripInfo sending:", json.encode(dripData))
    TriggerClientEvent('mbt_meta_clothes:dripInfo', src, dripData)
end)

-----------------------------------------------------------
-- Periodic XP tick — runs every DripInterval seconds
-----------------------------------------------------------
if MBT.DripEnabled then
    Citizen.CreateThread(function()
        local interval = (MBT.DripInterval or 300) * 1000

        -- Wait for PlayerState to initialize
        Wait(5000)

        while true do
            Wait(interval)

            for _, playerId in ipairs(GetPlayers()) do
                local src = tonumber(playerId)
                if MBT.PlayerState.IsLoaded(src) then
                    local rate = MBT.Drip.CalculateRate(src)
                    if rate > 0 then
                        local prevXp = MBT.PlayerState.GetDripXp(src)
                        MBT.PlayerState.AddDripXp(src, rate)
                        local totalXp = MBT.PlayerState.GetDripXp(src)

                        local level, progress = MBT.Drip.GetLevel(totalXp)
                        local prevLevel = MBT.Drip.GetLevel(prevXp)

                        -- Only notify client if level changed or first tick
                        local levelChanged = level.index ~= prevLevel.index

                        TriggerClientEvent('mbt_meta_clothes:dripUpdate', src, {
                            xp = totalXp,
                            rate = rate,
                            level = level.name,
                            levelIndex = level.index,
                            progress = progress,
                        })

                        -- Only update state bags on level change (avoids per-tick overhead)
                        if levelChanged then
                            MBT.UpdateStateBags(src)
                        end

                        MBT.Debugger("Drip tick:", src, "+" .. rate .. "XP", "total:" .. totalXp, level.name)
                    end
                end
                Wait(0) -- yield between players to avoid server hitch
            end
        end
    end)
end
