Locales = Locales or {}

Locales['it'] = {
    -----------------------------------------------------------
    -- Notifiche
    -----------------------------------------------------------
    ["nothing_to_unwear"] = {
        ["title"] = "Vestiti",
        ["description"] = "Non hai vestiti da togliere!",
        ["type"] = "error",
        ["icon"] = "shirt",
    },
    ["wrong_sex"] = {
        ["title"] = "Vestiti",
        ["description"] = "Questo capo non è per ",
        ["type"] = "error",
        ["icon"] = "ban",
    },
    ["undress"] = {
        ["title"] = "Vestiti",
        ["description"] = "Devi prima svestirti",
        ["type"] = "error",
        ["icon"] = "shirt",
    },
    ["nothing_to_steal"] = {
        ["title"] = "Vestiti",
        ["description"] = "Niente da rubare",
        ["type"] = "error",
        ["icon"] = "ban",
    },
    ["tuck_usage"] = {
        ["title"] = "Vestiti",
        ["description"] = "Uso: /tuck [slot]",
        ["type"] = "info",
        ["icon"] = "info",
    },
    ["tuck_invalid_slot"] = {
        ["title"] = "Vestiti",
        ["description"] = "Slot non valido",
        ["type"] = "error",
        ["icon"] = "ban",
    },
    ["inventory_full"] = {
        ["title"] = "Vestiti",
        ["description"] = "Non hai abbastanza spazio nell'inventario.",
        ["type"] = "error",
        ["icon"] = "box",
    },
    ["inventory_error"] = {
        ["title"] = "Vestiti",
        ["description"] = "Non è stato possibile spostare il capo.",
        ["type"] = "error",
        ["icon"] = "triangle-exclamation",
    },
    ["action_busy"] = {
        ["title"] = "Vestiti",
        ["description"] = "Questa operazione è già in corso.",
        ["type"] = "error",
        ["icon"] = "clock",
    },
    ["partial_steal"] = {
        ["title"] = "Vestiti",
        ["description"] = "È stato possibile prendere solo una parte dei capi selezionati.",
        ["type"] = "warning",
        ["icon"] = "triangle-exclamation",
    },

    -----------------------------------------------------------
    -- Etichette Slot
    -----------------------------------------------------------
    ["ear_acc"]     = "Orecchini",
    ["glasses"]     = "Occhiali",
    ["chain"]       = "Collana",
    ["hats"]        = "Cappello",
    ["arms"]        = "Braccia",
    ["legs"]        = "Pantaloni",
    ["foot"]        = "Scarpe",
    ["t_shirt"]     = "Maglietta",
    ["jacket"]      = "Giacca",
    ["watch"]       = "Orologio",
    ["bracelet"]    = "Bracciale",
    ["top"]         = "Sopra",

    -----------------------------------------------------------
    -- Descrizioni Oggetti
    -----------------------------------------------------------
    ["props_desc"]      = "Accessorio appartenente a %s",
    ["clothes_desc"]    = "Capo di abbigliamento di %s",
    ["stolen_clothing"] = "Vestiti rubati",

    -----------------------------------------------------------
    -- Barra Progresso / Uso
    -----------------------------------------------------------
    ["use_dress_kit"]  = "Indossando il completo",
    ["use_trousers"]   = "Indossando i pantaloni",
    ["use_shoes"]      = "Indossando le scarpe",
    ["use_chain"]      = "Indossando la collana",
    ["use_hat"]        = "Indossando il cappello",
    ["use_glasses"]    = "Indossando gli occhiali",
    ["use_earaccess"]  = "Indossando gli orecchini",
    ["use_watch"]      = "Indossando l'orologio",
    ["use_bracelet"]   = "Indossando il bracciale",
    ["use_item"]       = "Indossando...",
    ["cancel"]         = "Annullato",
    ["stealing"]       = "Rubando...",
    ["stealing_all"]   = "Svestendo...",

    -----------------------------------------------------------
    -- UI / Menu
    -----------------------------------------------------------
    ["sett_name"]    = "Menu Vestiti",
    ["steal_dress"]  = "Ruba Vestiti",

    -----------------------------------------------------------
    -- Drip Reputation
    -----------------------------------------------------------
    ["drip_info"]    = "🔥 Drip: %s (Lv.%d) | XP: %d | Rate: +%d/tick",
    ["drip_label"]   = "Drip",
    ["drip_unknown"] = "Sconosciuto",

    -----------------------------------------------------------
    -- UI (inviato al frontend React via NUI — non usato dal Lua)
    -----------------------------------------------------------
    ["UI"] = {
        ["hotspots"] = {
            ["head"]        = "Testa & Volto",
            ["torso"]       = "Torso",
            ["accessories"] = "Accessori",
            ["armor"]       = "Kevlar",
            ["bags"]        = "Zaini",
            ["legs"]        = "Pantaloni",
            ["feet"]        = "Scarpe",
        },
        ["slots"] = {
            ["hat"]      = "Cappello",
            ["glasses"]  = "Occhiali",
            ["earrings"] = "Orecchini",
            ["watch"]    = "Orologio",
            ["bracelet"] = "Bracciale",
            ["mask"]     = "Maschera",
            ["backpack"] = "Zaino",
            ["armor"]    = "Giubbotto",
            ["chain"]    = "Collana",
            ["top"]      = "Top",
            ["pants"]    = "Pantaloni",
            ["shoes"]    = "Scarpe",
        },
        ["steal"] = {
            ["stealAll"]           = "RUBA TUTTO",
            ["collect"]            = "PRELEVA",
            ["lootingInProgress"]  = "SVALIGIAMENTO IN CORSO",
        },
    },
}
