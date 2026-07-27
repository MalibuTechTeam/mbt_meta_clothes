local function fail(message)
    error(message, 3)
end

local Assert = {}

function Assert.equal(expected, actual, message)
    if expected ~= actual then
        fail(message or ('expected %s, got %s'):format(tostring(expected), tostring(actual)))
    end
end

local function fixture(options)
    options = options or {}
    local now = 1000
    local processed = 0
    local runtime = MBT.StealAuthority.New({
        now = function() return now end,
        validateBegin = options.validateBegin or function() return true end,
        validateComplete = options.validateComplete or function() return true end,
        normalizeSelections = function(selections)
            if type(selections) ~= 'table' then return nil end
            local normalized = {}
            for _, selection in ipairs(selections) do
                if type(selection) ~= 'table' or type(selection.stealType) ~= 'string' then return nil end
                normalized[#normalized + 1] = selection
            end
            return normalized
        end,
        buildAllSelections = function()
            return { { stealType = 'torso' } }
        end,
        processSelections = options.processSelections or function(_, _, selections)
            processed = processed + 1
            return { requested = #selections, succeeded = #selections, failed = 0 }
        end,
        isLowSelection = function(selection)
            return selection.stealType == 'drawable' and selection.slotIndex == 6
        end,
        profiles = {
            target_down = { duration = 2000 },
            standing_low = { duration = 2000 },
            standing_high = { duration = 2500 },
            steal_all = { duration = 5000 },
            steal_all_down = { duration = 3000 },
        },
        singleProgressDuration = 1500,
        batchProgressDuration = 2500,
        graceDuration = 10000,
    })

    return runtime, function(value) now = value end, function() return processed end
end

local function singlePayload()
    return {
        requestId = 1,
        targetServerId = 22,
        mode = 'single',
        stance = 'standing',
        selections = { { stealType = 'drawable', slotIndex = 6 } },
    }
end

local cases = {
    {
        name = 'complete without begin is rejected',
        run = function()
            local runtime, _, processed = fixture()
            local result = runtime:Complete(11, 'forged')
            Assert.equal(false, result.ok)
            Assert.equal('invalid_token', result.reason)
            Assert.equal(0, processed())
        end,
    },
    {
        name = 'early completion is rejected without consuming token',
        run = function()
            local runtime, setNow, processed = fixture()
            local begun = runtime:Begin(11, singlePayload())
            Assert.equal(true, begun.ok, begun.reason)
            Assert.equal('standing_low', begun.thiefAnimKey)
            Assert.equal(3500, begun.victimDuration)

            setNow(4499)
            local early = runtime:Complete(11, begun.token)
            Assert.equal(false, early.ok)
            Assert.equal('early_complete', early.reason)
            Assert.equal(0, processed())

            setNow(4500)
            Assert.equal(true, runtime:Complete(11, begun.token).ok)
            Assert.equal(1, processed())
        end,
    },
    {
        name = 'successful token is one use only',
        run = function()
            local runtime, setNow, processed = fixture()
            local begun = runtime:Begin(11, singlePayload())
            setNow(4500)
            Assert.equal(true, runtime:Complete(11, begun.token).ok)
            local replay = runtime:Complete(11, begun.token)
            Assert.equal(false, replay.ok)
            Assert.equal('invalid_token', replay.reason)
            Assert.equal(1, processed())
        end,
    },
    {
        name = 'token is bound to the initiating source',
        run = function()
            local runtime, setNow, processed = fixture()
            local begun = runtime:Begin(11, singlePayload())
            setNow(4500)
            local result = runtime:Complete(12, begun.token)
            Assert.equal(false, result.ok)
            Assert.equal('invalid_token', result.reason)
            Assert.equal(0, processed())
        end,
    },
    {
        name = 'active thief and victim sessions cannot be replaced',
        run = function()
            local runtime = fixture()
            local first = runtime:Begin(11, singlePayload())
            Assert.equal(true, first.ok)

            local repeated = singlePayload()
            repeated.requestId = 2
            Assert.equal('busy', runtime:Begin(11, repeated).reason)

            local competing = singlePayload()
            competing.requestId = 3
            Assert.equal('target_busy', runtime:Begin(12, competing).reason)
        end,
    },
    {
        name = 'arbitrary mode and stance cannot select animations',
        run = function()
            local runtime = fixture()
            local payload = singlePayload()
            payload.mode = 'admin'
            Assert.equal('invalid_request', runtime:Begin(11, payload).reason)

            payload = singlePayload()
            payload.stance = 'custom_animation_dict'
            Assert.equal('invalid_request', runtime:Begin(11, payload).reason)

            payload = singlePayload()
            payload.dict = 'arbitrary@dict'
            payload.clip = 'arbitrary_clip'
            payload.duration = 1
            local fixed = runtime:Begin(11, payload)
            Assert.equal(true, fixed.ok)
            Assert.equal('standing_low', fixed.thiefAnimKey)
            Assert.equal(2000, fixed.animationDuration)
        end,
    },
    {
        name = 'expired token is rejected and releases victim lock',
        run = function()
            local runtime, setNow, processed = fixture()
            local begun = runtime:Begin(11, singlePayload())
            setNow(14501)
            local expired = runtime:Complete(11, begun.token)
            Assert.equal(false, expired.ok)
            Assert.equal('expired_token', expired.reason)
            Assert.equal(0, processed())

            local retry = singlePayload()
            retry.requestId = 2
            Assert.equal(true, runtime:Begin(12, retry).ok)
        end,
    },
    {
        name = 'completion revalidates context and consumes denied token',
        run = function()
            local runtime, setNow, processed = fixture({
                validateComplete = function() return false end,
            })
            local begun = runtime:Begin(11, singlePayload())
            setNow(4500)
            local denied = runtime:Complete(11, begun.token)
            Assert.equal(false, denied.ok)
            Assert.equal('not_allowed', denied.reason)
            Assert.equal('invalid_token', runtime:Complete(11, begun.token).reason)
            Assert.equal(0, processed())
        end,
    },
    {
        name = 'cancel invalidates token and returns victim source',
        run = function()
            local runtime, _, processed = fixture()
            local begun = runtime:Begin(11, singlePayload())
            Assert.equal(22, runtime:Cancel(11, begun.token))
            Assert.equal('invalid_token', runtime:Complete(11, begun.token).reason)
            Assert.equal(0, processed())
        end,
    },
    {
        name = 'transfer exception consumes token and fails closed',
        run = function()
            local runtime, setNow = fixture({
                processSelections = function() error('inventory exploded') end,
            })
            local begun = runtime:Begin(11, singlePayload())
            setNow(4500)
            local failed = runtime:Complete(11, begun.token)
            Assert.equal(false, failed.ok)
            Assert.equal('internal_error', failed.reason)
            Assert.equal('invalid_token', runtime:Complete(11, begun.token).reason)
        end,
    },
}

local function run()
    local passed = 0
    for _, case in ipairs(cases) do
        local ok, reason = xpcall(case.run, debug.traceback)
        if not ok then error(('FAIL: %s\n%s'):format(case.name, reason), 0) end
        passed = passed + 1
    end
    return passed
end

if RegisterCommand then
    if MBT.Debug then
        RegisterCommand('mbt_steal_authority_selftest', function(source)
            if source ~= 0 then
                print('^1[mbt_meta_clothes] mbt_steal_authority_selftest is server-console only.^0')
                return
            end
            local ok, result = xpcall(run, debug.traceback)
            if not ok then
                print(('^1[mbt_meta_clothes][steal authority test] %s^0'):format(result))
                return
            end
            print(('^2[mbt_meta_clothes][steal authority test] PASS: %d/%d cases^0'):format(result, #cases))
        end, true)
    end
else
    MBT = MBT or {}
    dofile('modules/steal/server.lua')
    print(('PASS: %d/%d cases'):format(run(), #cases))
end
