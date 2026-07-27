local function assertEqual(expected, actual, message)
    if expected ~= actual then
        error(message or ('expected %s, got %s'):format(tostring(expected), tostring(actual)), 3)
    end
end

local function run()
    local handlers = {}
    local starts = 0
    MBT.SnapshotClient.InstallRuntimeHooks({
        addEventHandler = function(eventName, handler)
            handlers[eventName] = handler
        end,
        currentResourceName = function() return 'mbt_meta_clothes' end,
        start = function() starts = starts + 1 end,
    })

    assertEqual('function', type(handlers.onClientResourceStart),
        'client runtime must subscribe to onClientResourceStart')
    assertEqual(nil, handlers.onResourceStart,
        'client runtime must not subscribe to the server-only onResourceStart event')

    handlers.onClientResourceStart('another_resource')
    assertEqual(0, starts, 'another resource start must not start the snapshot loop')
    handlers.onClientResourceStart('mbt_meta_clothes')
    assertEqual(1, starts, 'own client resource start must start the snapshot loop')
    return 1
end

if RegisterCommand then
    if MBT.Debug then
        RegisterCommand('mbt_client_start_selftest', function(source)
            if source ~= 0 then
                print('^1[mbt_meta_clothes] mbt_client_start_selftest is server-console only.^0')
                return
            end
            local ok, result = xpcall(run, debug.traceback)
            if not ok then
                print(('^1[mbt_meta_clothes][client start test] FAIL\n%s^0'):format(result))
                return
            end
            print(('^2[mbt_meta_clothes][client start test] PASS: %d/1 case^0'):format(result))
        end, true)
    end
else
    MBT = MBT or {}
    IsDuplicityVersion = function() return true end
    dofile('modules/snapshot/client.lua')
    local passed = run()
    print(('PASS: %d/1 case'):format(passed))
end
