MBT                      = {}

-----------------------------------------------------------
-- General Settings
-----------------------------------------------------------
MBT.Debug                = true -- Enable debug prints in server/client console
MBT.MenuKey              = "J"  -- Keybind to open the clothing menu
MBT.ActionCooldown       = 1500 -- ms between actions (prevents animation spam)
MBT.TargetEnabled        = true -- Auto-detects ox_target, qb-target, or qtarget

-----------------------------------------------------------
-- Clothing Props (3D prop in hand during undress)
-----------------------------------------------------------

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

MBT.CustomInventory      = function(itemName, metadata)
    -- Put your cutom inventory event here
    -- TriggerEvent('qs-inventory:addItem', source, data.item , 1, data.metadata, {
    --         Firstname = '',
    --         Lastname = '',
    --         showAllDescriptions = true
    --     })
    -- end
end

MBT.NotifyHandler        = function(text, type)
    -- Put your notify here
    --[[
        -- Notify({ msg = text, title = "Clothes", style = "dark", type = type or "error", icon = "fa-solid fa-campground", position = "bottom-right", duration = 5000, sound = type or "error" })
    ]]
end

MBT.Labels               = {
    ["nothing_to_unwear"] = "You don't have any clothes to take off!",
    ["props_desc"] = "Accessory belonging to %s",
    ["clothes_desc"] = "Piece of clothing belonging to %s",
    ["ear_acc"] = "Ear Accessories",
    ["glasses"] = "Glasses",
    ["chain"] = "Torso Accessories",
    ["hats"] = "Hats",
    ["arms"] = "Arms",
    ["legs"] = "Legs",
    ["foot"] = "Foot",
    ["t_shirt"] = "TShirt",
    ["jacket"] = "Jacket",
    ["watch"] = "Watch",
    ["sett_name"] = "Clothes Menu",
    ["wrong_sex"] = "This piece of clothing is not for ",
    ["undress"] = "You must first undress",
    ["use_dress_kit"] = "Using Top Dress",
    ["use_trousers"] = "Using Trousers",
    ["use_shoes"] = "Using Shoes",
    ["use_chain"] = "Using Chain",
    ["use_hat"] = "Using Hat",
    ["use_glasses"] = "Using Glasses",
    ["use_earaccess"] = "Using Ear Access",
    ["use_watch"] = "Using Watch",
    ["steal_dress"] = "Steal Dress",
    ["stealing"] = "Stealing...",
    ["stealing_all"] = "Stripping clothes...",
    ["nothing_to_steal"] = "Nothing to steal",
}

MBT.Drawables            = {
    [3] = {
        ["Label"] = MBT.Labels["arms"],
        ["Default"] = {
            ["male"] = { 15 },
            ["female"] = { 15 }
        }
    },
    [4] = {
        ["Label"] = MBT.Labels["legs"],
        ["Default"] = {
            ["male"] = { 21 },
            ["female"] = { 14, 105 }
        },
        ["Animation"] = { ["Dict"] = "re@construction", ["Anim"] = "out_of_breath", ["Flag"] = 51, ["Duration"] = 1300 },
        ["Item"] = "trousers",
        ["PropModel"] = "prop_ld_jeans_01"
    },
    [6] = {
        ["Label"] = MBT.Labels["foot"],
        ["Default"] = {
            ["male"] = { 34 },
            ["female"] = { 118 }
        },
        ["Animation"] = { ["Dict"] = "random@domestic", ["Anim"] = "pickup_low", ["Flag"] = 0, ["Duration"] = 1200 },
        ["Item"] = "shoes",
        ["PropModel"] = "v_ret_ps_shoe_01"
    },
    [7] = {
        ["Label"] = MBT.Labels["chain"],
        ["Default"] = {
            ["male"] = { 0 },
            ["female"] = { 0 }
        },
        ["Animation"] = { ["Dict"] = "clothingtie", ["Anim"] = "try_tie_positive_a", ["Flag"] = 0, ["Duration"] = 2500 },
        ["Item"] = "chain",
        ["PropModel"] = "p_cletus_necklace_s"
    },
    [8] = {
        ["Label"] = MBT.Labels["t_shirt"],
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
        ["Label"] = MBT.Labels["jacket"],
        ["Default"] = {
            ["male"] = { 15 },
            ["female"] = { 15 }
        },
        ["Item"] = "jacket",
        ["PropModel"] = "v_24_bdr_mesh_lstshirt"
    }
}

MBT.Props                = {
    [0] = {
        ["Label"] = MBT.Labels["hats"],
        ["Default"] = {
            ["male"] = { -1 },
            ["female"] = { -1 }
        },
        ["Animation"] = { ["Dict"] = "missheist_agency2ahelmet", ["Anim"] = "take_off_helmet_stand", ["Flag"] = 51, ["Duration"] = 600 },
        ["Item"] = "hat",
        ["PropModel"] = "xm3_prop_xm3_hat_ron_01a"
    },
    [1] = {
        ["Label"] = MBT.Labels["glasses"],
        ["Default"] = {
            ["male"] = { -1 },
            ["female"] = { -1 }
        },
        ["Animation"] = { ["Dict"] = "clothingspecs", ["Anim"] = "take_off", ["Flag"] = 51, ["Duration"] = 1400 },
        ["Item"] = "glasses",
        ["PropModel"] = "v_44_m_spyglasses"
    },
    [2] = {
        ["Label"] = MBT.Labels["ear_acc"],
        ["Default"] = {
            ["male"] = { -1 },
            ["female"] = { -1 }
        },
        ["Animation"] = { ["Dict"] = "mp_cp_stolen_tut", ["Anim"] = "b_think", ["Flag"] = 51, ["Duration"] = 900 },
        ["Item"] = "earaccess",
        ["PropModel"] = "p_tmom_earrings_s"
    },
    [6] = {
        ["Label"] = MBT.Labels["watch"],
        ["Default"] = {
            ["male"] = { -1 },
            ["female"] = { -1 }
        },
        ["Animation"] = { ["Dict"] = "nmt_3_rcm-10", ["Anim"] = "cs_nigel_dual-10", ["Flag"] = 51, ["Duration"] = 900 },
        ["Item"] = "watch",
        ["PropModel"] = "p_watch_01"
    },
}
