if not MBT.Debug then return end

local function assertEqual(expected, actual, message)
    if expected ~= actual then
        error(message or ('expected %s, got %s'):format(tostring(expected), tostring(actual)), 3)
    end
end

-- Le asserzioni sui pesi confrontano con i valori di config invece di numeri
-- fissi: il test resta vero anche se il server owner ritara MBT.DripSlotWeights.
local function run()
    local resolve = MBT.Drip.ResolveSlotRate
    local cases = 0

    -- Un valore dall'item vince su qualunque configurazione.
    assertEqual(7, resolve('Drawables', 4, { drawable = 999, dripValue = 7 }),
        'item drip value must win over configuration')
    cases = cases + 1

    -- L'XP non decresce mai: un valore negativo va azzerato, non sottratto.
    assertEqual(0, resolve('Drawables', 4, { drawable = 999, dripValue = -5 }),
        'negative item drip must clamp to zero')
    cases = cases + 1

    -- Un valore assurdo va limitato prima di finire nella colonna XP.
    assertEqual(1000, resolve('Drawables', 4, { drawable = 999, dripValue = 1e18 }),
        'oversized item drip must clamp to the ceiling')
    cases = cases + 1

    -- NaN e infinito non sono valori: si ignorano e si torna alla config.
    local baseline = resolve('Drawables', 4, { drawable = 999 })
    assertEqual(baseline, resolve('Drawables', 4, { drawable = 999, dripValue = 0 / 0 }),
        'NaN item drip must fall back to configuration')
    cases = cases + 1
    assertEqual(baseline, resolve('Drawables', 4, { drawable = 999, dripValue = math.huge }),
        'infinite item drip must fall back to configuration')
    cases = cases + 1

    -- Uno slot senza drawable non è indossato.
    assertEqual(0, resolve('Drawables', 4, { dripValue = 5 }),
        'a slot without a drawable earns nothing')
    cases = cases + 1

    -- Uno slot non configurato non contribuisce.
    assertEqual(0, resolve('Drawables', 99, { drawable = 1 }),
        'an unconfigured slot earns nothing')
    cases = cases + 1

    -- Il cuore della regressione: i pesi per slot devono essere letti davvero.
    -- Prima di questo la tabella era inerte e ogni capo valeva DefaultDrip.
    for _, slotType in ipairs({ 'Drawables', 'Props' }) do
        local weights = MBT.DripSlotWeights and MBT.DripSlotWeights[slotType]
        local slots = slotType == 'Drawables' and MBT.Drawables or MBT.Props
        for slotIndex, weight in pairs(weights or {}) do
            local slotConfig = slots and slots[slotIndex]
            if slotConfig and not slotConfig.DripValues and not slotConfig.DefaultDrip then
                assertEqual(weight, resolve(slotType, slotIndex, { drawable = 999 }),
                    ('configured weight for %s[%s] must be used'):format(slotType, tostring(slotIndex)))
                cases = cases + 1
            end
        end
    end

    return cases
end

RegisterCommand('mbt_drip_selftest', function(source)
    if source ~= 0 then
        print('^1[mbt_meta_clothes] mbt_drip_selftest is server-console only.^0')
        return
    end
    local ok, result = xpcall(run, debug.traceback)
    if not ok then
        print(('^1[mbt_meta_clothes][drip test] FAIL\n%s^0'):format(result))
        return
    end
    print(('^2[mbt_meta_clothes][drip test] PASS: %d cases^0'):format(result))
end, true)
