-----------------------------------------------------------
-- Lifecycle tracer (client, only when MBT.Debug is on)
--
-- Ordinary logs have one-second granularity, but the windows we have to respect
-- are 400ms wide: we need milliseconds to measure instead of guessing.
--
-- It answers: how long the black-screen window lasts, where the reveal falls
-- inside it, and above all WHO touches the alpha besides us — by declaring our
-- own writes, every other change belongs to somebody else by elimination.
-----------------------------------------------------------

MBT.Trace = MBT.Trace or {}

if not MBT.Debug then
    function MBT.Trace.Mark() end
    function MBT.Trace.Begin() end
    function MBT.Trace.OwnAlpha() end
    return
end

-- The clock starts at resource boot, so even events that precede the first
-- transition get readable relative times instead of t=+0.
local originAt = GetGameTimer()
local expectedAlpha
local pendingOurWrite = false
local lastAlpha
local lastFaded

local function pedAlpha()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return nil end
    return GetEntityAlpha(ped)
end

--- Sort the keys: two runs of the same sequence must produce lines that compare
--- by eye, otherwise diffing two logs becomes impossible.
local function formatDetail(detail)
    if type(detail) ~= 'table' then
        return detail ~= nil and tostring(detail) or ''
    end
    local keys = {}
    for key in pairs(detail) do keys[#keys + 1] = tostring(key) end
    table.sort(keys)
    local parts = {}
    for _, key in ipairs(keys) do
        parts[#parts + 1] = ('%s=%s'):format(key, tostring(detail[key]))
    end
    return table.concat(parts, ' ')
end

--- Open a new measurement window. From here on, times are relative.
function MBT.Trace.Begin(reason)
    originAt = GetGameTimer()
    MBT.Trace.Mark('BEGIN', { reason = reason })
end

function MBT.Trace.Mark(event, detail)
    local at = GetGameTimer()
    local rel = originAt and (at - originAt) or 0
    local alpha = pedAlpha()
    print(('^5[CLOTH][TRACE]^7 t=%+7d  %-22s alpha=%-4s faded=%s  %s^0'):format(
        rel,
        tostring(event),
        alpha == nil and 'none' or tostring(alpha),
        IsScreenFadedOut() and 'Y' or (IsScreenFadingIn() and '~' or 'n'),
        formatDetail(detail)
    ))
end

--- Declare that we are about to write that alpha value ourselves.
--- Attributing by VALUE alone does not work: if we set 0 and then somebody else
--- sets 0 again, the comparison would say "ours". We need an announcement the
--- watcher consumes: a change is ours only if we declared it since the last
--- observed change.
function MBT.Trace.OwnAlpha(value)
    expectedAlpha = value
    pendingOurWrite = true
end

-- Sample every frame: a contention between two writers runs at the cadence of
-- the faster loop (50ms in our case), so sampling any slower would make it
-- invisible exactly when we need to see it.
CreateThread(function()
    while true do
        Wait(0)

        local alpha = pedAlpha()
        if alpha ~= lastAlpha then
            if lastAlpha ~= nil then
                local mine = pendingOurWrite and alpha == expectedAlpha
                MBT.Trace.Mark(mine and 'alpha:ours' or 'alpha:FOREIGN', {
                    from = lastAlpha,
                    to = alpha,
                })
            end
            pendingOurWrite = false
            lastAlpha = alpha
        end

        local faded = IsScreenFadedOut()
        if faded ~= lastFaded then
            if lastFaded ~= nil then
                MBT.Trace.Mark(faded and 'screen:black' or 'screen:visible')
            end
            lastFaded = faded
        end
    end
end)

-- Manual probe: prints what the PED is actually wearing right now. The tracer
-- only reports changes, so a garment that reappears while nothing is being
-- traced leaves no line — this answers "what is on the body at this instant".
RegisterCommand('mbt_pedstate', function()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then
        print('^1[CLOTH][PROBE]^7 no ped^0')
        return
    end
    local parts = {}
    for _, slot in ipairs({ 3, 4, 6, 7, 8, 11 }) do
        parts[#parts + 1] = ('D%d=%d'):format(slot, GetPedDrawableVariation(ped, slot))
    end
    for _, slot in ipairs({ 0, 1, 2, 6, 7 }) do
        parts[#parts + 1] = ('P%d=%d'):format(slot, GetPedPropIndex(ped, slot))
    end
    print(('^5[CLOTH][PROBE]^7 t=%+d  %s^0'):format(GetGameTimer() - originAt, table.concat(parts, ' ')))
end, false)
