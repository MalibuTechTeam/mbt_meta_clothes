MBT = {}

MBT.Debug     = true
MBT.MenuKey   = "J"


MBT.CustomInventory = function(itemName, metadata)
    
    -- Put your cutom inventory event here 
    -- TriggerEvent('qs-inventory:addItem', source, data.item , 1, data.metadata, {
    --         Firstname = '',
    --         Lastname = '',
    --         showAllDescriptions = true
    --     })
    -- end
end

MBT.NotifyHandler = function(text, type)
    -- Put your notify here 
    --[[
        -- Notify({ msg = text, title = "Clothes", style = "dark", type = type or "error", icon = "fa-solid fa-campground", position = "bottom-right", duration = 5000, sound = type or "error" })
    ]]

    exports.ox_lib:notify({
        title = text,
        description = 'CLOTHES',
        duration = 10000,
        position = 'bottom-right',
        style = {
            borderRadius = 7,
            backgroundColor = '#2e3847',
            color = '#white',
            fontFamily = 'Poppins',
            fontWeight = '500',
            fontSize = 15,
            textShadowColor = '#0000',

            borderRightColor = '#2e3847' ,
            borderBottomColor = '#2e3847',
            borderTopColor = '#2e3847', 
            borderLeftColor = '#d54090',
            
            borderLeftWidth = 5 ,
            borderBottomWidth = 0,
            borderTopWidth = 0, 
            borderRightWidth = 0,

            borderTopRightRadius = 7,
            borderLeftRadius  = 7,
            borderBottomRadius  = 7,
            borderTopRadius  = 7, 
            borderRightRadius  =7,

            borderStyle = 'solid',
            marginBottom = 20
        },
        icon = 'fa-solid fa-shirt',
        iconColor = '#ffcc48'
    })
end

MBT.Labels = {
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
}  

MBT.Target = {
	["Active"] = true,
    ["Zones"] = {
        ["T1"] = function ()
            exports.ox_target:addGlobalPlayer({
                {
                    name = 'steal',
                    icon = 'fa-solid fa-cube',
                    event = "mbt_meta_clothes:stealPlayerDress",
                    distance = 2.0,
                    label = MBT.Labels["steal_dress"],
                    canInteract = function(entity)
                        if IsEntityPlayingAnim(entity, "missminuteman_1ig_2", "handsup_base", 3) then 
                            return true
                        end
                    end
                }
            })
        end
    }
}

MBT.Drawables = {
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
        ["Animation"] = { ["Dict"] = "clothingshirt", ["Anim"] = "try_shirt_positive_d", ["Flag"] = 51,
            ["Duration"] = 1200 },
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

MBT.Props = {
    [0] = {
        ["Label"] = MBT.Labels["hats"],
        ["Default"] = {
            ["male"] = {-1},
            ["female"] = {-1}
        },
        ["Animation"] = { ["Dict"] = "missheist_agency2ahelmet", ["Anim"] = "take_off_helmet_stand", ["Flag"] = 51, ["Duration"] = 600 },
        ["Item"] = "hat",
        ["PropModel"] = "xm3_prop_xm3_hat_ron_01a"
    },
    [1] = {
        ["Label"] = MBT.Labels["glasses"],
        ["Default"] = {
            ["male"] = {-1, 0},
            ["female"] = {-1, 0}
        },
        ["Animation"] = { ["Dict"] = "clothingspecs", ["Anim"] = "take_off", ["Flag"] = 51, ["Duration"] = 1400 },
        ["Item"] = "glasses",
        ["PropModel"] = "v_44_m_spyglasses"
    },
    [2] = {
        ["Label"] = MBT.Labels["ear_acc"],
        ["Default"] = {
            ["male"] = {-1},
            ["female"] = {-1}
        },
        ["Animation"] = { ["Dict"] = "mp_cp_stolen_tut", ["Anim"] = "b_think", ["Flag"] = 51, ["Duration"] = 900 },
        ["Item"] = "earaccess",
        ["PropModel"] = "p_tmom_earrings_s"
    },
    [6] = {
        ["Label"] = MBT.Labels["watch"],
        ["Default"] = {
            ["male"] = {-1},
            ["female"] = {-1}
        },
        ["Animation"] = { ["Dict"] = "nmt_3_rcm-10", ["Anim"] = "cs_nigel_dual-10", ["Flag"] = 51, ["Duration"] = 900 },
        ["Item"] = "watch",
        ["PropModel"] = "p_watch_01"
    },
}

-- Prop cleanup time in seconds (how long scattered props stay on the ground)
MBT.PropCleanupTime = 60