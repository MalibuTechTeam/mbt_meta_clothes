local function fail(message)
    error(message, 3)
end

local Assert = {}

function Assert.equal(expected, actual, message)
    if expected ~= actual then
        fail(message or ('expected %s, got %s'):format(tostring(expected), tostring(actual)))
    end
end

function Assert.truthy(value, message)
    if not value then fail(message or 'expected a truthy value') end
end

local function clone(value)
    if type(value) ~= 'table' then return value end
    local copy = {}
    for key, child in pairs(value) do copy[key] = clone(child) end
    return copy
end

local function fixture(initial)
    local state = clone(initial or { Drawables = {}, Props = {} })
    local applied = {}
    local dnaInjections = 0

    local playerState = {}

    function playerState.GetSlot(_, slotType, slotIndex)
        return state[slotType] and state[slotType][slotIndex]
    end

    function playerState.SetSlot(_, slotType, slotIndex, metadata)
        state[slotType][slotIndex] = metadata
    end

    local runtime = MBT.DressAuthority.New({
        PlayerState = playerState,
        Drawables = {
            [3] = { Item = 'arms' },
            [6] = { Item = 'shoes' },
            [8] = { Item = 'tshirt' },
            [11] = { Item = { 'jacket', 'designer_jacket' } },
        },
        Props = {
            [0] = { Item = 'hat' },
        },
        TorsoKitSlots = { 3, 8, 11 },
        TorsoSlotNames = { [3] = 'Arms', [8] = 'Tshirt', [11] = 'Jacket' },
        Bounds = {
            componentDrawable = { min = 0, max = 4095 },
            propDrawable = { min = -1, max = 4095 },
            texture = { min = 0, max = 255 },
            palette = { min = 0, max = 3 },
        },
        normalizeSex = function(sex) return sex end,
        getPlayerSex = function() return 'male' end,
        injectDNA = function(metadata)
            dnaInjections = dnaInjections + 1
            metadata.dna = 'server-dna'
        end,
        apply = function(src, kind, payload)
            applied[#applied + 1] = { src = src, kind = kind, payload = payload }
        end,
    })

    return runtime, state, applied, function() return dnaInjections end
end

local cases = {
    {
        name = 'preflight validates without mutating wearing state',
        run = function()
            local runtime, state, applied = fixture()
            local ok, reason, descriptor = runtime:CanUse(7, 'designer_jacket', {
                index = 11,
                drawable = 29,
                texture = 2,
                palette = 0,
                sex = 'male',
                type = 'Drawable',
            })

            Assert.equal(true, ok, reason)
            Assert.equal('Drawable', descriptor.kind)
            Assert.equal(11, descriptor.slots[1].slotIndex)
            Assert.equal(nil, state.Drawables[11])
            Assert.equal(0, #applied)
        end,
    },
    {
        name = 'unconfigured item cannot create wearing state',
        run = function()
            local runtime, state = fixture()
            local result = runtime:Commit(7, 'admin_jacket', {
                index = 11,
                drawable = 999,
                texture = 0,
                palette = 0,
                sex = 'male',
                type = 'Drawable',
            })

            Assert.equal(false, result.ok)
            Assert.equal('invalid_item', result.reason)
            Assert.equal(nil, state.Drawables[11])
        end,
    },
    {
        name = 'configured item cannot target another slot',
        run = function()
            local runtime, state = fixture()
            local result = runtime:Commit(7, 'shoes', {
                index = 11,
                drawable = 29,
                texture = 0,
                palette = 0,
                sex = 'male',
                type = 'Drawable',
            })

            Assert.equal(false, result.ok)
            Assert.equal('invalid_metadata', result.reason)
            Assert.equal(nil, state.Drawables[11])
        end,
    },
    {
        name = 'out of bounds visual metadata is rejected before commit',
        run = function()
            local runtime, state = fixture()
            local result = runtime:Commit(7, 'designer_jacket', {
                index = 11,
                drawable = 5000,
                texture = 999,
                palette = 0,
                sex = 'male',
                type = 'Drawable',
            })

            Assert.equal(false, result.ok)
            Assert.equal('invalid_metadata', result.reason)
            Assert.equal(nil, state.Drawables[11])
        end,
    },
    {
        name = 'occupied authoritative slot rejects item use',
        run = function()
            local runtime, state = fixture({
                Drawables = { [11] = { item_name = 'jacket', drawable = 20 } },
                Props = {},
            })
            local ok, reason = runtime:CanUse(7, 'designer_jacket', {
                index = 11,
                drawable = 29,
                texture = 2,
                palette = 0,
                sex = 'male',
                type = 'Drawable',
            })

            Assert.equal(false, ok)
            Assert.equal('slot_occupied', reason)
            Assert.equal(20, state.Drawables[11].drawable)
        end,
    },
    {
        name = 'single item commits authoritative metadata and exact item name',
        run = function()
            local runtime, state, applied, dnaCount = fixture()
            local sourceMetadata = {
                index = 11,
                drawable = 29,
                texture = 2,
                palette = 0,
                sex = 'male',
                type = 'Drawable',
                custom_label = 'Midnight jacket',
            }
            local result = runtime:Commit(7, 'designer_jacket', sourceMetadata)

            Assert.equal(true, result.ok, result.reason)
            Assert.equal('designer_jacket', state.Drawables[11].item_name)
            Assert.equal('Midnight jacket', state.Drawables[11].custom_label)
            Assert.equal('server-dna', state.Drawables[11].dna)
            Assert.equal(nil, sourceMetadata.dna)
            Assert.equal(1, dnaCount())
            Assert.equal(1, #applied)
            Assert.equal('Drawable', applied[1].kind)
            Assert.equal(29, applied[1].payload.drawable)
        end,
    },
    {
        name = 'torso kit rejects atomically when one managed slot is occupied',
        run = function()
            local runtime, state, applied = fixture({
                Drawables = { [8] = { item_name = 'tshirt', drawable = 12 } },
                Props = {},
            })
            local result = runtime:Commit(7, 'topdress', {
                type = 'DressKit',
                sex = 'male',
                Arms = { index = 3, drawable = 15, texture = 0, palette = 0, sex = 'male' },
                Tshirt = { index = 8, drawable = 20, texture = 0, palette = 0, sex = 'male' },
                Jacket = { index = 11, drawable = 29, texture = 2, palette = 0, sex = 'male' },
            })

            Assert.equal(false, result.ok)
            Assert.equal('slot_occupied', result.reason)
            Assert.equal(nil, state.Drawables[3])
            Assert.equal(12, state.Drawables[8].drawable)
            Assert.equal(nil, state.Drawables[11])
            Assert.equal(0, #applied)
        end,
    },
    {
        name = 'torso kit commits every slot from one authoritative item',
        run = function()
            local runtime, state, applied, dnaCount = fixture()
            local result = runtime:Commit(7, 'topdress', {
                type = 'DressKit',
                sex = 'male',
                Arms = { index = 3, drawable = 15, texture = 0, palette = 0, sex = 'male' },
                Tshirt = { index = 8, drawable = 20, texture = 1, palette = 0, sex = 'male' },
                Jacket = {
                    index = 11,
                    drawable = 29,
                    texture = 2,
                    palette = 0,
                    sex = 'male',
                    item_name = 'designer_jacket',
                },
            })

            Assert.equal(true, result.ok, result.reason)
            Assert.equal(nil, state.Drawables[3].item_name)
            Assert.equal(nil, state.Drawables[8].item_name)
            Assert.equal('designer_jacket', state.Drawables[11].item_name)
            Assert.equal(3, dnaCount())
            Assert.equal(1, #applied)
            Assert.equal('DressKit', applied[1].kind)
        end,
    },
}

local function run()
    local passed = 0
    for _, case in ipairs(cases) do
        local ok, reason = xpcall(case.run, debug.traceback)
        if not ok then
            error(('FAIL: %s\n%s'):format(case.name, reason), 0)
        end
        passed = passed + 1
    end
    return passed
end

if RegisterCommand then
    if MBT.Debug then
        RegisterCommand('mbt_dress_authority_selftest', function(source)
            if source ~= 0 then
                print('^1[mbt_meta_clothes] mbt_dress_authority_selftest is server-console only.^0')
                return
            end

            local ok, result = xpcall(run, debug.traceback)
            if not ok then
                print(('^1[mbt_meta_clothes][dress authority test] %s^0'):format(result))
                return
            end
            print(('^2[mbt_meta_clothes][dress authority test] PASS: %d/%d cases^0'):format(result, #cases))
        end, true)
    end
else
    MBT = MBT or {}
    dofile('modules/bridge/inventory/dress_authority.lua')
    local passed = run()
    print(('PASS: %d/%d cases'):format(passed, #cases))
end
