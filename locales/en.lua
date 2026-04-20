Locales = Locales or {}

Locales['en'] = {
    -----------------------------------------------------------
    -- Notifications (object format for ox_lib / custom notify)
    -----------------------------------------------------------
    ["nothing_to_unwear"] = {
        ["title"] = "Clothes",
        ["description"] = "You don't have any clothes to take off!",
        ["type"] = "error",
        ["icon"] = "shirt",
    },
    ["wrong_sex"] = {
        ["title"] = "Clothes",
        ["description"] = "This piece of clothing is not for ",
        ["type"] = "error",
        ["icon"] = "ban",
    },
    ["undress"] = {
        ["title"] = "Clothes",
        ["description"] = "You must first undress",
        ["type"] = "error",
        ["icon"] = "shirt",
    },
    ["nothing_to_steal"] = {
        ["title"] = "Clothes",
        ["description"] = "Nothing to steal",
        ["type"] = "error",
        ["icon"] = "ban",
    },
    ["tuck_usage"] = {
        ["title"] = "Clothes",
        ["description"] = "Usage: /tuck [slot]",
        ["type"] = "info",
        ["icon"] = "info",
    },
    ["tuck_invalid_slot"] = {
        ["title"] = "Clothes",
        ["description"] = "Invalid slot",
        ["type"] = "error",
        ["icon"] = "ban",
    },

    -----------------------------------------------------------
    -- Slot Labels (used in config Drawables/Props, steal menu, target)
    -----------------------------------------------------------
    ["ear_acc"]     = "Ear Accessories",
    ["glasses"]     = "Glasses",
    ["chain"]       = "Torso Accessories",
    ["hats"]        = "Hats",
    ["arms"]        = "Arms",
    ["legs"]        = "Legs",
    ["foot"]        = "Foot",
    ["t_shirt"]     = "TShirt",
    ["jacket"]      = "Jacket",
    ["watch"]       = "Watch",
    ["bracelet"]    = "Bracelet",
    ["top"]         = "Top",

    -----------------------------------------------------------
    -- Item Descriptions
    -----------------------------------------------------------
    ["props_desc"]      = "Accessory belonging to %s",
    ["clothes_desc"]    = "Piece of clothing belonging to %s",
    ["stolen_clothing"] = "Stolen clothing",

    -----------------------------------------------------------
    -- Progress Bar / Use Labels
    -----------------------------------------------------------
    ["use_dress_kit"]  = "Using Top Dress",
    ["use_trousers"]   = "Using Trousers",
    ["use_shoes"]      = "Using Shoes",
    ["use_chain"]      = "Using Chain",
    ["use_hat"]        = "Using Hat",
    ["use_glasses"]    = "Using Glasses",
    ["use_earaccess"]  = "Using Ear Access",
    ["use_watch"]      = "Using Watch",
    ["use_bracelet"]   = "Using Bracelet",
    ["use_item"]       = "Using item...",
    ["cancel"]         = "Cancelled",
    ["stealing"]       = "Stealing...",
    ["stealing_all"]   = "Stripping clothes...",

    -----------------------------------------------------------
    -- UI / Menu
    -----------------------------------------------------------
    ["sett_name"]    = "Clothes Menu",
    ["steal_dress"]  = "Steal Dress",

    -----------------------------------------------------------
    -- Drip Reputation
    -----------------------------------------------------------
    ["drip_info"]    = "🔥 Drip: %s (Lv.%d) | XP: %d | Rate: +%d/tick",
    ["drip_label"]   = "Drip",
    ["drip_unknown"] = "Unknown",

    -----------------------------------------------------------
    -- UI (inviato al frontend React via NUI — non usato dal Lua)
    -----------------------------------------------------------
    ["UI"] = {
        ["hotspots"] = {
            ["head"]        = "Head & Face",
            ["torso"]       = "Torso",
            ["accessories"] = "Accessories",
            ["armor"]       = "Body Armor",
            ["bags"]        = "Bags",
            ["legs"]        = "Pants",
            ["feet"]        = "Shoes",
        },
        ["slots"] = {
            ["hat"]      = "Hat",
            ["glasses"]  = "Glasses",
            ["earrings"] = "Earrings",
            ["watch"]    = "Watch",
            ["bracelet"] = "Bracelet",
            ["mask"]     = "Mask",
            ["backpack"] = "Backpack",
            ["armor"]    = "Body Armor",
            ["chain"]    = "Chain",
            ["top"]      = "Top",
            ["pants"]    = "Pants",
            ["shoes"]    = "Shoes",
        },
        ["steal"] = {
            ["stealAll"]           = "STEAL ALL",
            ["collect"]            = "COLLECT",
            ["lootingInProgress"]  = "LOOTING IN PROGRESS",
        },
    },
}
