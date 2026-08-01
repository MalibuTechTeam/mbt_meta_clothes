MBT                      = MBT or {}

-----------------------------------------------------------
-- General Settings
-----------------------------------------------------------
MBT.Debug                = true -- Enable debug prints in server/client console
MBT.Language             = 'en'  -- Language: 'en', 'it' (add your own in locales/)
MBT.MenuKey              = "J"   -- Keybind to open the clothing menu
MBT.ActionCooldown       = 1500  -- ms between actions (prevents animation spam)

-----------------------------------------------------------
-- Theme
-- Stessa convenzione di mbt_emote_menu: hex SENZA '#'. Viene inviato alla NUI
-- all'apertura e trasformato in custom properties CSS, così un solo valore
-- ritinge laser, anelli, marcatori del manichino e stati attivi.
--
-- Oggi meta_clothes espone solo l'accento: le altre chiavi di emote_menu
-- (Background, Card, Text…) non sono qui perché la sua UI non le usa ancora, e
-- una config che non fa niente è peggio di una config assente.
--
-- Il rosso della modalità furto NON è tematizzabile di proposito: lì il colore
-- distingue "sto rubando" da "sto vestendomi", non è decorazione.
-----------------------------------------------------------
MBT.Theme                = {
    Accent = '00e676', -- Brand green
}

-----------------------------------------------------------
-- Stealing
-----------------------------------------------------------
-- Spegne il furto su ENTRAMBI i percorsi: opzione target e comando /steal.
-- Server PVE o RP che considerano il furto vestiti una forma di griefing lo
-- mettono a false e la feature sparisce, non a metà.
MBT.StealEnabled         = true

-- Nessun toggle per il target: se ox_target, qb-target o qtarget è avviato la
-- risorsa registra l'interazione da sola, altrimenti resta il comando /steal.
MBT.StealDistance        = 5.0   -- Max distance (meters) to steal from a player
MBT.TargetDistance       = 2.0   -- ox_target / qb-target interaction distance
MBT.StealDuration        = 1500  -- ms progress bar for single item steal
MBT.StealAllDuration     = 2500  -- ms progress bar for steal all
MBT.VictimAnimCap        = 10000 -- ms max victim animation (anti-grief)
MBT.StealTokenGrace      = 10000 -- ms allowed to complete after the authoritative minimum duration
MBT.StealRequestTimeout  = 5000  -- ms before a missing begin ACK is discarded client-side

-- Fixed animation catalog. Clients request only a bounded action/stance; the
-- server selects one of these keys and owns every effective duration.
MBT.StealAnimations      = {
    target_down    = { dict = "missexile3",          clip = "ex03_dingy_search_case_base_michael", flag = 1,  dur = 2000 },
    standing_low   = { dict = "random@domestic",     clip = "pickup_low",                          flag = 0,  dur = 2000 },
    standing_high  = { dict = "random@shop_robbery", clip = "robbery_action_b",                    flag = 49, dur = 2500 },
    steal_all      = { dict = "missfbi2",            clip = "handsup_search_cop",                   flag = 49, dur = 5000 },
    steal_all_down = { dict = "missexile3",          clip = "ex03_dingy_search_case_base_michael", flag = 1,  dur = 3000 },
    victim_stand   = { dict = "random@mugging3",      clip = "handsup_standing_base",                flag = 49 },
    victim_down    = { dict = "missexile3",          clip = "ex03_dingy_search_case_base_michael", flag = 1  },
}

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
MBT.PedRevealStableWindow = 500  -- ms the PED must continuously match authoritative wearing before reveal
MBT.PedRevealTimeout      = 4500 -- bounded wait; the 5s visibility watchdog remains the final recovery

-- Hybrid snapshot synchronization. The client polls locally but submits only
-- stable full-state changes; the server remains authoritative for metadata.
MBT.SnapshotPollInterval        = 1000
-- 0 = ogni frame. Durante la finestra di restore protection un appearance
-- script può rimettere un capo che il giocatore aveva tolto (illenium, skinchanger,
-- qb-clothing, chiunque): il tempo che passa fra la sua scrittura e la nostra
-- correzione è esattamente il "lampo" che si vede — e che vedono anche gli altri
-- giocatori, perché i vestiti viaggiano in rete mentre l'alpha no.
-- Controllare a ogni frame costa ~11 letture native e riduce quella finestra da
-- 500ms a un frame. Non ci lega a nessuno script: guardiamo il PED, non gli eventi.
MBT.SnapshotRestorePollInterval = 0
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
-- The callback MUST return true only after the item was added, otherwise
-- false plus a stable reason such as "inventory_full" or "add_failed".
-- Metadata must be forwarded unchanged; meta_clothes remains authoritative
-- for which item and clothing state may be transferred.
-----------------------------------------------------------
-- MBT.CustomInventory = function(source, itemName, count, metadata)
--     local success = YourInventoryAddItem(source, itemName, count, metadata)
--     return success == true, success and nil or "add_failed"
-- end

MBT.Notification         = function(data)
    data = type(data) == "table" and data or { description = tostring(data or "") }

    -- Every provider below is optional and guarded: the resource stays
    -- dependency-free and always falls through to the native GTA feed.
    local payload = {
        title = data.title or "Clothes",
        description = data.description,
        type = data.type or "info",
        icon = data.icon or "shirt",   
        duration = data.duration or 4000
    }

    -- Preset for mbt_visual
    -- exports.mbt_visual:notify(payload)

    -- Preset ox_lib 
    -- exports.ox_lib:notify(payload)

    -- Native client fallback: always available, regardless of framework.
    -- BeginTextCommandThefeedPost("STRING")
    -- AddTextComponentSubstringPlayerName(data.description or data.title or "Notification")
    -- EndTextCommandThefeedPostTicker(false, true)

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

MBT.WearablePropsSlots   = {
    [1] = "mask",
    [5] = "bag",
    [9] = "smallarmor",
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
