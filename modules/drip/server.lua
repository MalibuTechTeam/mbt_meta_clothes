-----------------------------------------------------------
-- Drip Reputation Engine (server-side)
--
-- Calcola un "drip rate" dall'outfit indossato e lo somma periodicamente all'XP
-- cumulativo, che non decresce mai. I capi di default valgono 0.
--
-- I pesi si configurano in MBT.DripSlotWeights, o per singolo drawable con
-- DripValues dentro lo slot. Nessun export: i consumatori leggono gli state bag
-- (mbt_dripLevel, mbt_dripTitle, mbt_dripXp, mbt_slotsWorn).
-----------------------------------------------------------

MBT.Drip = {}

local SLOT_TYPES = { "Drawables", "Props" }

-- Un valore drip che arriva dalla metadata dell'item non è fidato: deve essere
-- finito, non negativo e limitato. Senza questo, un item con dripValue enorme,
-- negativo o NaN corrompe l'XP in modo permanente — e "l'XP non decresce mai"
-- smette di essere vero. Il tetto è generoso: serve a escludere l'assurdo, non
-- a limitare un'economia legittima.
local MAX_ITEM_DRIP = 1000

local function sanitizeItemDrip(value)
    if type(value) ~= "number" then return nil end
    if value ~= value then return nil end -- NaN
    if value == math.huge or value == -math.huge then return nil end
    if value < 0 then return 0 end
    if value > MAX_ITEM_DRIP then return MAX_ITEM_DRIP end
    return value
end

--- Risolve i punti drip di un singolo slot indossato.
--- Precedenza: metadata dell'item → DripValues per drawable → DefaultDrip dello
--- slot → MBT.DripSlotWeights → MBT.DefaultDrip.
--- @param slotType string "Drawables" | "Props"
--- @param slotIndex number
--- @param metadata table Metadata dello slot da PlayerState
--- @return number rate
local function resolveSlotRate(slotType, slotIndex, metadata)
    local slots = slotType == "Drawables" and MBT.Drawables or MBT.Props
    local slotConfig = slots and slots[slotIndex]
    if not slotConfig or not metadata or not metadata.drawable then return 0 end

    local fromItem = sanitizeItemDrip(metadata.dripValue)
    if fromItem then return fromItem end

    local drawableIdx = tonumber(metadata.drawable) or metadata.drawable
    local dripValues = slotConfig["DripValues"]
    if dripValues and dripValues[drawableIdx] then
        return dripValues[drawableIdx]
    end
    if slotConfig["DefaultDrip"] then
        return slotConfig["DefaultDrip"]
    end

    -- Pesi per slot da config.lua. Prima di questo non venivano letti da nessuna
    -- riga della risorsa: ogni capo valeva DefaultDrip, quindi un orecchino
    -- pesava quanto un giubbotto e la tabella dei pesi era inerte.
    local weights = MBT.DripSlotWeights and MBT.DripSlotWeights[slotType]
    local weight = weights and weights[slotIndex]
    if weight ~= nil then return weight end

    return MBT.DefaultDrip or 1
end

-- Esposta perché è una funzione pura e testabile: la catena di precedenza è
-- proprio dove si era rotta (i pesi di config non venivano letti da nessuno).
MBT.Drip.ResolveSlotRate = resolveSlotRate

--- Calculate the instantaneous drip rate from a player's current outfit
--- @param src number Player source
--- @return number rate The drip points per tick this outfit earns
function MBT.Drip.CalculateRate(src)
    local wearing = MBT.PlayerState.GetAll(src)
    if not wearing then return 0 end

    local rate = 0
    for _, slotType in ipairs(SLOT_TYPES) do
        for slotIndex, metadata in pairs(wearing[slotType] or {}) do
            rate = rate + resolveSlotRate(slotType, slotIndex, metadata)
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
    for _, slotType in ipairs(SLOT_TYPES) do
        for slotIndex, metadata in pairs(wearing[slotType] or {}) do
            local rate = resolveSlotRate(slotType, slotIndex, metadata)
            if rate > 0 then
                breakdown[#breakdown + 1] = { slotType = slotType, slotIndex = slotIndex, rate = rate }
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
    if not MBT.ServerUtils.CheckRateLimit(src, 'requestDripInfo') then return end

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
    -- Guard su MBT.Debug: gli argomenti si valutano prima della chiamata, quindi
    -- senza questo l'encode gira a ogni richiesta anche a log spenti.
    if MBT.Debug then
        MBT.Debugger("dripInfo sending:", json.encode(dripData))
    end
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
