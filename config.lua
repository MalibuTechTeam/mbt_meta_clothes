MBT                      = MBT or {}

-----------------------------------------------------------
-- General Settings
-----------------------------------------------------------
MBT.Debug                = true -- Enable debug prints in server/client console
MBT.Language             = 'en'  -- Language: 'en', 'it' (add your own in locales/)
MBT.MenuKey              = "J"   -- Keybind to open the clothing menu
MBT.ActionCooldown       = 1500  -- ms between actions (prevents animation spam)
MBT.TargetEnabled        = true  -- Auto-detects ox_target, qb-target, or qtarget

-----------------------------------------------------------
-- Stealing
-----------------------------------------------------------
MBT.StealDistance        = 5.0   -- Max distance (meters) to steal from a player
MBT.TargetDistance       = 2.0   -- ox_target / qb-target interaction distance
MBT.StealDuration        = 1500  -- ms progress bar for single item steal
MBT.StealAllDuration     = 2500  -- ms progress bar for steal all
MBT.VictimAnimCap        = 10000 -- ms max victim animation (anti-grief)

-- Animations that count as "hands up" — target option appears only when one of these is active.
-- Add the dict/clip used by your server's hands-up script.
-- Common values:
--   ESX/vanilla:  { dict = "missminuteman_1ig_2", clip = "handsup_base" }
--   QB/ps-hands:  { dict = "random@mugging3",     clip = "handsup_base" }
MBT.HandsUpAnims         = {
    { dict = "missminuteman_1ig_2", clip = "handsup_base" },
    { dict = "random@mugging3",     clip = "handsup_standing_base" },
}

-----------------------------------------------------------
-- Security
-----------------------------------------------------------
MBT.RateLimitWindow      = 2000 -- ms window for rate limiting
MBT.RateLimitMax         = 5    -- Max calls per window per player

-----------------------------------------------------------
-- Persistence
-----------------------------------------------------------
MBT.StateSaveInterval    = 300   -- Seconds between periodic dirty saves (5 min)
MBT.RestoreProtection    = 15000 -- ms to protect restored state from external overwrites
MBT.PedRevealDelay       = 2000  -- ms to keep PED hidden after restore (covers appearance script late apply + our re-apply, prevents visible blink). Keep <= 4500 (the bridge keepPedHidden loop caps at 5000ms before auto-recovery).

-- Hybrid snapshot synchronization. The client polls locally but submits only
-- stable full-state changes; the server remains authoritative for metadata.
MBT.SnapshotPollInterval        = 1000
MBT.SnapshotRestorePollInterval = 500
MBT.SnapshotDebounce            = 400
MBT.SnapshotAckTimeout          = 2000
MBT.SnapshotWriteBehind         = 5000
MBT.SnapshotMaxPayload          = 16384
MBT.SnapshotBounds             = {
    componentDrawable = { min = 0, max = 4095 },
    propDrawable = { min = -1, max = 4095 },
    texture = { min = 0, max = 255 },
    palette = { min = 0, max = 3 },
}

-----------------------------------------------------------
-- DNA Forensics
-----------------------------------------------------------
MBT.DnaEnabled           = true -- Track who wore each clothing item
MBT.DnaMaxEntries        = 3    -- Max DNA entries per item (FIFO)
MBT.DnaExpiryHours       = 48   -- Hours before DNA expires from items

-----------------------------------------------------------
-- Drip Reputation
-----------------------------------------------------------
MBT.DripEnabled          = true -- Enable drip XP accumulation
MBT.DripInterval         = 300  -- Seconds between drip XP ticks (5 min)
MBT.DefaultDrip          = 1    -- Default drip points for non-configured drawables
MBT.DripLevels           = {
    { name = "Freshman",     minXp = 0 },
    { name = "Trendy",       minXp = 100 },
    { name = "Stylish",      minXp = 300 },
    { name = "Fashion Icon", minXp = 600 },
    { name = "Drip God",     minXp = 1000 },
}
MBT.DripSlotWeights      = {
    Drawables = {
        [3]  = 0, -- Arms (part of torso kit, doesn't count separately)
        [4]  = 2, -- Pants
        [6]  = 2, -- Shoes
        [7]  = 1, -- Chain
        [8]  = 0, -- T-shirt (part of torso kit)
        [11] = 3, -- Jacket/Top (most visible piece)
    },
    Props = {
        [0] = 1,   -- Hat
        [1] = 1,   -- Glasses
        [2] = 0.5, -- Earrings
        [6] = 0.5, -- Watch
    }
}

-----------------------------------------------------------
-- Progress Bar
-- Replace with your own progress bar system if needed.
-- Animation is handled separately by the script.
-----------------------------------------------------------
MBT.ProgressBar          = function(options, cb)
    if GetResourceState('ox_lib') == 'started' then
        local result = exports.ox_lib:progressCircle({
            duration = options.duration,
            label = options.label or '',
            position = 'bottom',
            useWhileDead = false,
            canCancel = true,
            disable = { car = true, move = true, combat = true },
        })
        cb(result)
    else
        Wait(options.duration)
        cb(true)
    end
end

-----------------------------------------------------------
-- Clothing Props (3D props during undress/steal)
-----------------------------------------------------------
MBT.ClothingPropsEnabled = false -- Enable 3D prop in hand during undress animation
MBT.PropCleanupTime      = 60    -- Seconds before scattered props auto-delete

-----------------------------------------------------------
-- Hat/Hair Clip Fix
-- Only enable if your server uses custom hair addons that clip through hats.
-- Map the custom hair drawable IDs that have clipping issues.
-----------------------------------------------------------
MBT.HatHairFix           = false
MBT.HairFixDrawables     = {
    -- Example: [73] = true, [74] = true,
}

-----------------------------------------------------------
-- Custom Inventory Fallback
-- Only needed if you DON'T use ox_inventory or qb-inventory.
-- Uncomment and fill with your inventory's addItem logic.
-----------------------------------------------------------
-- MBT.CustomInventory = function(source, itemName, count, metadata)
--     exports['qs-inventory']:AddItem(source, itemName, count, metadata)
-- end

MBT.Notification         = function(data)
    -- Preset for ox_lib (uncomment to use)
    exports.ox_lib:notify({
        title = data.title or "Clothes",
        description = data.description,
        type = data.type or "info",
        icon = data.icon or "shirt",
        duration = data.duration or 4000
    })

    -- Preset for ESX Standard
    -- ESX.ShowNotification(data.description or data.title)

    -- Preset for QBCore Standard
    -- QBCore.Functions.Notify(data.description or data.title, data.type or "primary")
end

-----------------------------------------------------------
-- Freemode Defaults
-- Vanilla GTA V default drawable/prop values for mp_m_freemode_01 and
-- mp_f_freemode_01. Used as a fallback when a configured slot omits
-- the ["Default"] key, so server owners adding new slots don't have to
-- look up the vanilla defaults manually.
-----------------------------------------------------------
MBT.FreemodeDefaults     = {
    Drawables = {
        male   = { [0] = 0, [1] = 0, [2] = 0, [3] = 15, [4] = 21, [5] = 0, [6] = 34, [7] = 0, [8] = 15, [9] = 0, [10] = 0, [11] = 15 },
        female = { [0] = 0, [1] = 0, [2] = 0, [3] = 15, [4] = 14, [5] = 0, [6] = 118, [7] = 0, [8] = 15, [9] = 0, [10] = 0, [11] = 15 },
    },
    Props = {
        male   = { [0] = -1, [1] = -1, [2] = -1, [3] = -1, [4] = -1, [5] = -1, [6] = -1, [7] = -1 },
        female = { [0] = -1, [1] = -1, [2] = -1, [3] = -1, [4] = -1, [5] = -1, [6] = -1, [7] = -1 },
    },
}

-----------------------------------------------------------
-- Gender Model Mapping
-- Model hashes that map to "male" or "female" sex strings.
-- Extend this table to support additional ped models beyond the
-- standard freemode characters.
-----------------------------------------------------------
MBT.GenderModels         = {
    [`mp_m_freemode_01`] = "male",
    [`mp_f_freemode_01`] = "female",
}

-----------------------------------------------------------
-- wearable_props Integration
-- Maps drawable component slot indices to mbt_wearable_props item types.
-- When a player clicks one of these slots in the NUI, the action is
-- delegated to mbt_wearable_props:removeWearable().
-- Armor slot (9) is a special case: the actual tier is read from statebags.
-----------------------------------------------------------
MBT.WearablePropsSlots   = {
    [1] = "mask",
    [5] = "bag",
    [9] = "smallarmor",  -- overridden at runtime by mbt_isWearingHeavyarmor/mbt_isWearingMedarmor statebags
}

MBT.Drawables            = {
    [3] = {
        ["Default"] = {
            ["male"] = { 15 },
            ["female"] = { 15 }
        }
    },
    [4] = {
        ["Default"] = {
            ["male"] = { 21 },
            ["female"] = { 14, 105 }
        },
        ["Animation"] = { ["Dict"] = "re@construction", ["Anim"] = "out_of_breath", ["Flag"] = 51, ["Duration"] = 1300 },
        ["Item"] = "trousers",
        ["PropModel"] = "prop_ld_jeans_01"
    },
    [6] = {
        ["Default"] = {
            ["male"] = { 34 },
            ["female"] = { 118 }
        },
        ["Animation"] = { ["Dict"] = "random@domestic", ["Anim"] = "pickup_low", ["Flag"] = 0, ["Duration"] = 1200 },
        ["Item"] = "shoes",
        ["PropModel"] = "v_ret_ps_shoe_01"
    },
    [7] = {
        ["Default"] = {
            ["male"] = { 0 },
            ["female"] = { 0 }
        },
        ["Animation"] = { ["Dict"] = "clothingtie", ["Anim"] = "try_tie_positive_a", ["Flag"] = 0, ["Duration"] = 2500 },
        ["Item"] = "chain",
        ["PropModel"] = "p_cletus_necklace_s"
    },
    [8] = {
        ["Default"] = {
            ["male"] = { 15 },
            ["female"] = { 15 }
        },
        ["Animation"] = {
            ["Dict"] = "clothingshirt",
            ["Anim"] = "try_shirt_positive_d",
            ["Flag"] = 51,
            ["Duration"] = 1200
        },
        ["PropModel"] = "v_24_bdr_mesh_lstshirt"
    },
    [11] = {
        ["Default"] = {
            ["male"] = { 15 },
            ["female"] = { 15 }
        },
        ["ToggleAnimation"] = { ["Dict"] = "missmic4", ["Anim"] = "michael_tux_fidget", ["Flag"] = 51, ["Duration"] = 1500 },
        ["Item"] = "jacket",
        ["PropModel"] = "v_24_bdr_mesh_lstshirt"
    }
}

MBT.Props                = {
    [0] = {
        ["Default"] = {
            ["male"] = { -1 },
            ["female"] = { -1 }
        },
        ["Animation"] = { ["Dict"] = "missheist_agency2ahelmet", ["Anim"] = "take_off_helmet_stand", ["Flag"] = 51, ["Duration"] = 600 },
        ["Item"] = "hat",
        ["PropModel"] = "xm3_prop_xm3_hat_ron_01a",
        ["ApplyHairFix"] = true, -- GTA V: hats clip through hair; this hides hair drawable when hat is on. Do not add to other slots.
    },
    [1] = {
        ["Default"] = {
            ["male"] = { -1 },
            ["female"] = { -1 }
        },
        ["Animation"] = { ["Dict"] = "clothingspecs", ["Anim"] = "take_off", ["Flag"] = 51, ["Duration"] = 1400 },
        ["Item"] = "glasses",
        ["PropModel"] = "v_44_m_spyglasses"
    },
    [2] = {
        ["Default"] = {
            ["male"] = { -1 },
            ["female"] = { -1 }
        },
        ["Animation"] = { ["Dict"] = "mp_cp_stolen_tut", ["Anim"] = "b_think", ["Flag"] = 51, ["Duration"] = 900 },
        ["Item"] = "earaccess",
        ["PropModel"] = "p_tmom_earrings_s"
    },
    [6] = {
        ["Default"] = {
            ["male"] = { -1 },
            ["female"] = { -1 }
        },
        ["Animation"] = { ["Dict"] = "nmt_3_rcm-10", ["Anim"] = "cs_nigel_dual-10", ["Flag"] = 51, ["Duration"] = 900 },
        ["Item"] = "watch",
        ["PropModel"] = "p_watch_01"
    },
    [7] = {
        ["Default"] = {
            ["male"] = { -1 },
            ["female"] = { -1 }
        },
        ["Animation"] = { ["Dict"] = "nmt_3_rcm-10", ["Anim"] = "cs_nigel_dual-10", ["Flag"] = 51, ["Duration"] = 900 },
        ["Item"] = "bracelet",
        ["PropModel"] = "p_jewel_m_bracelet_02"
    },
}
