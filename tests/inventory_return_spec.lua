if not MBT.Debug then return end

local function fail(message)
    error(message, 3)
end

local Assert = {}

function Assert.equal(expected, actual, message)
    if expected ~= actual then
        fail(message or ('expected %s, got %s'):format(tostring(expected), tostring(actual)))
    end
end

local function payload(receiver, item_name, metadata)
    return {
        receiver = receiver,
        itemName = item_name,
        count = 1,
        metadata = metadata or {},
    }
end

local function runtimeFixture(initial, add_item, options)
    options = options or {}
    local state = initial
    local clears = {}
    local playerState = {}
    local clothesDescription, propsDescription
    if not options.useRuntimeLocale then
        clothesDescription = 'Piece of clothing belonging to %s'
        propsDescription = 'Accessory belonging to %s'
    end

    function playerState.GetSlot(_, slot_type, slot_index)
        return state[slot_type] and state[slot_type][slot_index]
    end

    function playerState.ClearSlot(_, slot_type, slot_index)
        local metadata = state[slot_type] and state[slot_type][slot_index]
        if metadata then
            state[slot_type][slot_index] = nil
            clears[#clears + 1] = { slotType = slot_type, slotIndex = slot_index }
        end
        return metadata
    end

    local runtime = MBT.GiveItems.NewRuntime({
        addItem = add_item,
        getPlayer = function(src) return { source = src, name = 'Test Player' } end,
        getPlayerName = function(player) return player.name end,
        getPlayerSource = function(player) return player.source end,
        PlayerState = playerState,
        Drawables = {
            [3] = { Item = 'arms', Default = { male = { 15 } } },
            [6] = { Item = 'shoes', Default = { male = { 34 } } },
            [8] = { Item = 'tshirt', Default = { male = { 15 } } },
            [11] = { Item = { 'jacket', 'designer_jacket' }, Default = { male = { 15 } } },
        },
        Props = {
            [0] = { Item = 'hat' },
        },
        TorsoKitSlots = { 3, 8, 11 },
        TorsoSlotNames = { [3] = 'Arms', [8] = 'Tshirt', [11] = 'Jacket' },
        resolveItemName = options.useSharedResolver and MBT.ResolveItemName or function(slot_config, metadata)
            if metadata.item_name then return metadata.item_name end
            return type(slot_config.Item) == 'table' and slot_config.Item[1] or slot_config.Item
        end,
        normalizeSex = function(sex) return sex end,
        getPlayerSex = options.getPlayerSex,
        cleanExpiredDNA = function() end,
        clothesDescription = clothesDescription,
        propsDescription = propsDescription,
        log = options.log or function() end,
    })

    return runtime, state, clears
end

local cases = {
    {
        name = 'add failure never commits authoritative state',
        run = function()
            local committed = 0
            local coordinator = MBT.GiveItems.New({
                addItem = function() return false, 'inventory_full' end,
                log = function() end,
            })
            local result = coordinator:Transfer('7:Drawables:11', function()
                return payload(7, 'jacket', { dna = 'kept' })
            end, function()
                committed = committed + 1
                return true
            end)

            Assert.equal(false, result.ok)
            Assert.equal('inventory_full', result.reason)
            Assert.equal(0, committed)
        end,
    },
    {
        name = 'successful add commits exactly once',
        run = function()
            local added, committed = 0, 0
            local coordinator = MBT.GiveItems.New({
                addItem = function(_, item_name, count, metadata)
                    added = added + 1
                    Assert.equal('jacket', item_name)
                    Assert.equal(1, count)
                    Assert.equal('kept', metadata.dna)
                    return true
                end,
                log = function() end,
            })
            local result = coordinator:Transfer('7:Drawables:11', function()
                return payload(7, 'jacket', { dna = 'kept' })
            end, function()
                committed = committed + 1
                return true, { slotType = 'Drawables', slotIndex = 11 }
            end)

            Assert.equal(true, result.ok)
            Assert.equal(1, added)
            Assert.equal(1, committed)
            Assert.equal(11, result.committed.slotIndex)
        end,
    },
    {
        name = 'same lock rejects a reentrant transfer',
        run = function()
            local coordinator
            local nested
            coordinator = MBT.GiveItems.New({
                addItem = function()
                    nested = coordinator:Transfer('8:Props:0', function()
                        return payload(8, 'hat')
                    end, function()
                        return true
                    end)
                    return true
                end,
                log = function() end,
            })

            local result = coordinator:Transfer('8:Props:0', function()
                return payload(8, 'hat')
            end, function()
                return true
            end)

            Assert.equal(true, result.ok)
            Assert.equal(false, nested.ok)
            Assert.equal('busy', nested.reason)
        end,
    },
    {
        name = 'dependency exception releases the lock',
        run = function()
            local should_throw = true
            local coordinator = MBT.GiveItems.New({
                addItem = function()
                    if should_throw then error('inventory exploded') end
                    return true
                end,
                log = function() end,
            })
            local function build()
                return payload(9, 'watch')
            end

            local failed = coordinator:Transfer('9:Props:6', build, function() return true end)
            should_throw = false
            local retried = coordinator:Transfer('9:Props:6', build, function() return true end)

            Assert.equal(false, failed.ok)
            Assert.equal('internal_error', failed.reason)
            Assert.equal(true, retried.ok)
        end,
    },
    {
        name = 'cleanup releases every lock owned by a source',
        run = function()
            local coordinator
            local nested
            coordinator = MBT.GiveItems.New({
                addItem = function()
                    coordinator:CleanupSource(10)
                    nested = coordinator:Transfer('10:Drawables:4', function()
                        return payload(10, 'trousers')
                    end, function()
                        return true
                    end)
                    return true
                end,
                log = function() end,
            })

            coordinator:Transfer('10:Drawables:4', function()
                return payload(10, 'trousers')
            end, function()
                return true
            end)

            Assert.equal(true, nested.ok)
        end,
    },
    {
        name = 'normalizes inventory add results',
        run = function()
            local ok, reason = MBT.GiveItems.NormalizeAddResult(false, 'invalid_item')
            Assert.equal(false, ok)
            Assert.equal('invalid_item', reason)

            ok, reason = MBT.GiveItems.NormalizeAddResult(nil, nil)
            Assert.equal(false, ok)
            Assert.equal('add_failed', reason)

            ok, reason = MBT.GiveItems.NormalizeAddResult(true, { slot = 4 })
            Assert.equal(true, ok)
            Assert.equal(nil, reason)
        end,
    },
    {
        name = 'custom inventory callback fails closed',
        run = function()
            local ok, reason = MBT.GiveItems.CallCustom(nil, 12, 'hat', 1, {})
            Assert.equal(false, ok)
            Assert.equal('unsupported_inventory', reason)

            ok, reason = MBT.GiveItems.CallCustom(function()
                error('custom exploded')
            end, 12, 'hat', 1, {})
            Assert.equal(false, ok)
            Assert.equal('custom_error', reason)

            ok, reason = MBT.GiveItems.CallCustom(function()
                return nil
            end, 12, 'hat', 1, {})
            Assert.equal(false, ok)
            Assert.equal('add_failed', reason)

            ok, reason = MBT.GiveItems.CallCustom(function(src, name, count, metadata)
                Assert.equal(12, src)
                Assert.equal('hat', name)
                Assert.equal(1, count)
                Assert.equal('male', metadata.sex)
                return true
            end, 12, 'hat', 1, { sex = 'male' })
            Assert.equal(true, ok)
            Assert.equal(nil, reason)
        end,
    },
    {
        name = 'item resolver accepts only names configured for the slot',
        run = function()
            local slot = { Item = { 'jacket', 'designer_jacket' } }
            Assert.equal('designer_jacket', MBT.ResolveItemName(slot, {
                item_name = 'designer_jacket',
            }))
            Assert.equal('jacket', MBT.ResolveItemName(slot, {}))
            Assert.equal(nil, MBT.ResolveItemName(slot, { item_name = 'admin_item' }))
            Assert.equal(nil, MBT.ResolveItemName(slot, { item_name = 42 }))
        end,
    },
    {
        name = 'forged item name never reaches inventory or clears wearing state',
        run = function()
            local stored = {
                index = 11,
                drawable = 29,
                texture = 2,
                palette = 0,
                sex = 'male',
                item_name = 'admin_item',
            }
            local adds = 0
            local runtime, state, clears = runtimeFixture({
                Drawables = { [11] = stored },
                Props = {},
            }, function()
                adds = adds + 1
                return true
            end, { useSharedResolver = true })

            local result = runtime:ReturnSlot(14, 'Drawables', 11)

            Assert.equal(false, result.ok)
            Assert.equal('invalid_item', result.reason)
            Assert.equal(0, adds)
            Assert.equal(0, #clears)
            Assert.equal(stored, state.Drawables[11])
        end,
    },
    {
        name = 'failed drawable return preserves live state and metadata',
        run = function()
            local stored = {
                index = 11,
                drawable = 29,
                texture = 2,
                palette = 0,
                sex = 'male',
                item_name = 'designer_jacket',
                description = 'original',
                last_worn_by = { { identifier = 'char:1' } },
            }
            local runtime, state, clears = runtimeFixture({
                Drawables = { [11] = stored },
                Props = {},
            }, function(_, name, _, metadata)
                Assert.equal('designer_jacket', name)
                Assert.equal('char:1', metadata.last_worn_by[1].identifier)
                return false, 'inventory_full'
            end)

            local result = runtime:ReturnSlot(14, 'Drawables', 11)

            Assert.equal(false, result.ok)
            Assert.equal('inventory_full', result.reason)
            Assert.equal(stored, state.Drawables[11])
            Assert.equal('original', stored.description)
            Assert.equal(0, #clears)
        end,
    },
    {
        name = 'successful drawable return preserves rich metadata then clears',
        run = function()
            local addedMetadata
            local runtime, state, clears = runtimeFixture({
                Drawables = {
                    [11] = {
                        index = 11,
                        drawable = 29,
                        texture = 2,
                        palette = 0,
                        sex = 'male',
                        item_name = 'designer_jacket',
                        last_worn_by = { { identifier = 'char:1' } },
                    },
                },
                Props = {},
            }, function(_, name, _, metadata)
                Assert.equal('designer_jacket', name)
                addedMetadata = metadata
                return true
            end)

            local result = runtime:ReturnSlot(14, 'Drawables', 11)

            Assert.equal(true, result.ok)
            Assert.equal(nil, state.Drawables[11])
            Assert.equal(1, #clears)
            Assert.equal('char:1', addedMetadata.last_worn_by[1].identifier)
            Assert.equal(29, addedMetadata.drawable)
        end,
    },
    {
        name = 'empty authoritative slot never creates an item',
        run = function()
            local adds = 0
            local runtime = runtimeFixture({ Drawables = {}, Props = {} }, function()
                adds = adds + 1
                return true
            end)

            local result = runtime:ReturnSlot(14, 'Props', 0)

            Assert.equal(false, result.ok)
            Assert.equal('no_item', result.reason)
            Assert.equal(0, adds)
        end,
    },
    {
        name = 'torso return commits every slot only after one successful add',
        run = function()
            local addedMetadata
            local runtime, state, clears = runtimeFixture({
                Drawables = {
                    [3] = { index = 3, drawable = 15, texture = 0, palette = 0, sex = 'male' },
                    [8] = { index = 8, drawable = 20, texture = 1, palette = 0, sex = 'male' },
                    [11] = { index = 11, drawable = 29, texture = 2, palette = 0, sex = 'male' },
                },
                Props = {},
            }, function(_, name, count, metadata)
                Assert.equal('topdress', name)
                Assert.equal(1, count)
                addedMetadata = metadata
                return true
            end)

            local result = runtime:ReturnTorso(14)

            Assert.equal(true, result.ok)
            Assert.equal(3, #clears)
            Assert.equal(nil, state.Drawables[3])
            Assert.equal(nil, state.Drawables[8])
            Assert.equal(nil, state.Drawables[11])
            Assert.equal(29, addedMetadata.Jacket.drawable)
        end,
    },
    {
        name = 'runtime resolves locale descriptions after deferred locale initialization',
        run = function()
            local previousLocale = MBT.Locale
            MBT.Locale = {}
            local runtime = runtimeFixture({
                Drawables = {
                    [8] = { index = 8, drawable = 21, texture = 0, sex = 'male' },
                },
                Props = {},
            }, function(_, _, _, metadata)
                Assert.equal('Late locale for Test Player', metadata.description)
                return true
            end, { useRuntimeLocale = true })

            MBT.Locale = {
                clothes_desc = 'Late locale for %s',
                props_desc = 'Late prop locale for %s',
            }
            local result = runtime:ReturnTorso(7)
            MBT.Locale = previousLocale

            Assert.equal(true, result.ok, result.reason)
        end,
    },
    {
        name = 'failed torso add clears no slot',
        run = function()
            local runtime, state, clears = runtimeFixture({
                Drawables = {
                    [3] = { index = 3, drawable = 15, sex = 'male' },
                    [8] = { index = 8, drawable = 20, sex = 'male' },
                    [11] = { index = 11, drawable = 29, sex = 'male' },
                },
                Props = {},
            }, function()
                return false, 'inventory_full'
            end)

            local result = runtime:ReturnTorso(14)

            Assert.equal(false, result.ok)
            Assert.equal(0, #clears)
            Assert.equal(29, state.Drawables[11].drawable)
        end,
    },
    {
        name = 'torso item fills absent slots with configured defaults',
        run = function()
            local addedMetadata
            local runtime = runtimeFixture({
                Drawables = {
                    [11] = { index = 11, drawable = 29, texture = 2, sex = 'male' },
                },
                Props = {},
            }, function(_, _, _, metadata)
                addedMetadata = metadata
                return true
            end)

            local result = runtime:ReturnTorso(14)

            Assert.equal(true, result.ok)
            Assert.equal(15, addedMetadata.Arms.drawable)
            Assert.equal(15, addedMetadata.Tshirt.drawable)
            Assert.equal(29, addedMetadata.Jacket.drawable)
        end,
    },
    {
        name = 'legacy single-slot metadata receives trusted PED sex',
        run = function()
            local addedMetadata
            local runtime = runtimeFixture({
                Drawables = {
                    [6] = { index = 6, drawable = 12, texture = 1, palette = 0 },
                },
                Props = {},
            }, function(_, _, _, metadata)
                addedMetadata = metadata
                return true
            end, {
                getPlayerSex = function(src)
                    Assert.equal(14, src)
                    return 'male'
                end,
            })

            local result = runtime:ReturnSlot(14, 'Drawables', 6)

            Assert.equal(true, result.ok, result.reason)
            Assert.equal('male', addedMetadata.sex)
        end,
    },
    {
        name = 'legacy torso metadata receives trusted PED sex',
        run = function()
            local addedMetadata
            local runtime = runtimeFixture({
                Drawables = {
                    [8] = { index = 8, drawable = 20, texture = 1, palette = 0 },
                    [11] = { index = 11, drawable = 29, texture = 2, palette = 0 },
                },
                Props = {},
            }, function(_, _, _, metadata)
                addedMetadata = metadata
                return true
            end, {
                getPlayerSex = function(src)
                    Assert.equal(14, src)
                    return 'male'
                end,
            })

            local result = runtime:ReturnTorso(14)

            Assert.equal(true, result.ok, result.reason)
            Assert.equal('male', addedMetadata.sex)
            Assert.equal('male', addedMetadata.Arms.sex)
            Assert.equal('male', addedMetadata.Tshirt.sex)
            Assert.equal('male', addedMetadata.Jacket.sex)
        end,
    },
    {
        name = 'steal transfers victim metadata to thief before clearing',
        run = function()
            local receiver
            local runtime, state = runtimeFixture({
                Drawables = {
                    [11] = {
                        index = 11,
                        drawable = 29,
                        texture = 2,
                        sex = 'male',
                        item_name = 'designer_jacket',
                        description = 'Original victim description',
                        last_worn_by = { { identifier = 'victim:1' } },
                    },
                },
                Props = {},
            }, function(src, _, _, metadata)
                receiver = src
                Assert.equal('victim:1', metadata.last_worn_by[1].identifier)
                Assert.equal('Original victim description', metadata.description)
                return true
            end)

            local result = runtime:TransferSlot(20, 21, 'Drawables', 11, {
                preserveDescription = true,
            })

            Assert.equal(true, result.ok)
            Assert.equal(21, receiver)
            Assert.equal(nil, state.Drawables[11])
        end,
    },
    {
        name = 'partial batch reports only committed selections',
        run = function()
            local calls = 0
            local selections = {
                { stealType = 'drawable', slotIndex = 4 },
                { stealType = 'prop', slotIndex = 0 },
                { stealType = 'drawable', slotIndex = 6 },
            }

            local summary = MBT.GiveItems.ProcessBatch(selections, function(selection)
                calls = calls + 1
                if calls == 3 then
                    return { ok = false, reason = 'inventory_full' }
                end
                return {
                    ok = true,
                    committed = {
                        stealType = selection.stealType,
                        slotIndex = selection.slotIndex,
                    },
                }
            end)

            Assert.equal(3, summary.requested)
            Assert.equal(2, summary.succeeded)
            Assert.equal(1, summary.failed)
            Assert.equal(2, #summary.committed)
            Assert.equal(0, summary.committed[2].slotIndex)
            Assert.equal('inventory_full', summary.lastReason)
        end,
    },
    {
        name = 'steal selections are validated deduplicated and sorted',
        run = function()
            local function validateSlot(slot_type, index)
                index = tonumber(index)
                if slot_type == 'Drawables' and (index == 4 or index == 11) then return true, index end
                if slot_type == 'Props' and index == 0 then return true, index end
                return false
            end
            local config = {
                validateSlot = validateSlot,
                torsoSlots = { 3, 8, 11 },
                maxSelections = 4,
            }

            local normalized = MBT.GiveItems.NormalizeStealSelections({
                { stealType = 'prop', slotIndex = '0' },
                { stealType = 'drawable', slotIndex = 4 },
                { stealType = 'drawable', slotIndex = 11 },
            }, config)
            Assert.equal('torso', normalized[1].stealType)
            Assert.equal('drawable', normalized[2].stealType)
            Assert.equal(4, normalized[2].slotIndex)
            Assert.equal('prop', normalized[3].stealType)

            local duplicate = MBT.GiveItems.NormalizeStealSelections({
                { stealType = 'torso' },
                { stealType = 'drawable', slotIndex = 11 },
            }, config)
            Assert.equal(nil, duplicate)

            local malformed = MBT.GiveItems.NormalizeStealSelections({
                [1] = { stealType = 'prop', slotIndex = 0 },
                extra = true,
            }, config)
            Assert.equal(nil, malformed)
        end,
    },
}

RegisterCommand('mbt_inventory_return_selftest', function(source)
    if source ~= 0 then
        print('^1[mbt_meta_clothes] mbt_inventory_return_selftest is server-console only.^0')
        return
    end

    local passed = 0
    for _, case in ipairs(cases) do
        local ok, reason = xpcall(case.run, debug.traceback)
        if not ok then
            print(('^1[mbt_meta_clothes][inventory return test] FAIL: %s\n%s^0'):format(case.name, reason))
            return
        end
        passed = passed + 1
    end
    print(('^2[mbt_meta_clothes][inventory return test] PASS: %d/%d cases^0'):format(passed, #cases))
end, true)
