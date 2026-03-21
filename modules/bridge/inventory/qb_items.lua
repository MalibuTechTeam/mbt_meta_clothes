-----------------------------------------------------------
-- QB-Inventory client-side item handlers (progress bar + animation)
-- Eliminates 8 nearly identical RegisterNetEvent handlers.
-----------------------------------------------------------

MBT.QbItems = {}

local ItemConfig = {
    { event = 'mbt_meta_clothes:useTopDress',  type = 'Drawables', progId = 'use_dress_kit', label = 'use_dress_kit', duration = 1200, dict = 'clothingshirt',           anim = 'try_shirt_positive_d',  flags = 51 },
    { event = 'mbt_meta_clothes:useTrousers',  type = 'Drawables', progId = 'use_trousers',  label = 'use_trousers',  duration = 1200, dict = 're@construction',         anim = 'out_of_breath',         flags = 51 },
    { event = 'mbt_meta_clothes:useShoes',     type = 'Drawables', progId = 'use_shoes',     label = 'use_shoes',     duration = 1200, dict = 'random@domestic',          anim = 'pickup_low',            flags = 0  },
    { event = 'mbt_meta_clothes:useChain',     type = 'Drawables', progId = 'use_chain',     label = 'use_chain',     duration = 2500, dict = 'clothingtie',              anim = 'try_tie_positive_a',    flags = 51 },
    { event = 'mbt_meta_clothes:useHat',       type = 'Props',     progId = 'use_hat',       label = 'use_hat',       duration = 600,  dict = 'missheist_agency2ahelmet', anim = 'take_off_helmet_stand', flags = 51 },
    { event = 'mbt_meta_clothes:useGlasses',   type = 'Props',     progId = 'use_glasses',   label = 'use_glasses',   duration = 1200, dict = 'clothingspecs',            anim = 'take_off',              flags = 51 },
    { event = 'mbt_meta_clothes:useEarAccess', type = 'Props',     progId = 'use_earaccess', label = 'use_earaccess', duration = 1200, dict = 'mp_cp_stolen_tut',         anim = 'b_think',               flags = 51 },
    { event = 'mbt_meta_clothes:useWatch',     type = 'Props',     progId = 'use_watch',     label = 'use_watch',     duration = 1200, dict = 'nmt_3_rcm-10',             anim = 'cs_nigel_dual-10',      flags = 51 },
}

function MBT.QbItems.RegisterItems()
    for _, cfg in ipairs(ItemConfig) do
        RegisterNetEvent(cfg.event, function(indexT, sexT, itemInfoT, itemData)
            local ped = PlayerPedId()
            QBCore.Functions.Progressbar(cfg.progId, MBT.Labels[cfg.label], cfg.duration, false, true, {
                disableMovement = false,
                disableCarMovement = false,
                disableMouse = false,
                disableCombat = true,
            }, {
                animDict = cfg.dict,
                anim = cfg.anim,
                flags = cfg.flags,
            }, {}, {}, function() -- Done
                StopAnimTask(ped, cfg.dict, cfg.anim, 1.0)
                TriggerEvent("mbt_meta_clothes:checkDress", {
                    type = cfg.type,
                    index = indexT,
                    sex = sexT,
                    itemInfo = itemInfoT
                })
                TriggerServerEvent('mbt_meta_clothes:removeWear', itemData.name)
                TriggerEvent('inventory:client:ItemBox', itemData, "remove")
            end, function() -- Cancel
                StopAnimTask(ped, cfg.dict, cfg.anim, 1.0)
                QBCore.Functions.Notify(Lang:t('consumables.canceled'), "error")
            end)
        end)
    end
end
