if not MBT.Debug then return end

local function assertEqual(expected, actual, message)
    if expected ~= actual then
        error(message or ('expected %s, got %s'):format(tostring(expected), tostring(actual)), 3)
    end
end

local function run()
    local isCurrent = MBT.PlayerState.IsSaveGuardCurrent
    assertEqual(true, isCurrent('char:1', 4, 'char:1', 4), 'unchanged save guard must finalize')
    assertEqual(false, isCurrent('char:1', 4, 'char:1', 5), 'newer mutation must stay dirty')
    assertEqual(false, isCurrent('char:1', 4, 'char:2', 4), 'character switch must stay dirty')
    return 3
end

RegisterCommand('mbt_state_save_selftest', function(source)
    if source ~= 0 then
        print('^1[mbt_meta_clothes] mbt_state_save_selftest is server-console only.^0')
        return
    end
    local ok, result = xpcall(run, debug.traceback)
    if not ok then
        print(('^1[mbt_meta_clothes][state save test] FAIL\n%s^0'):format(result))
        return
    end
    print(('^2[mbt_meta_clothes][state save test] PASS: %d/3 cases^0'):format(result))
end, true)
