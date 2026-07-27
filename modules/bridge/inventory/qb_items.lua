-----------------------------------------------------------
-- QB-Inventory client-side item handler
-- Single unified event 'mbt_meta_clothes:useClothing' handles
-- all clothing items. Animation is derived from slot config
-- (MBT.Drawables[k]["Animation"] or MBT.Props[k]["Animation"])
-- so adding a new slot in config automatically gets the right anim.
-----------------------------------------------------------

MBT.QbItems = {}

-- Fallback animation when a slot has no ["Animation"] key configured
local DEFAULT_ANIM = {
    Dict     = "clothingshirt",
    Anim     = "try_shirt_positive_d",
    Flag     = 51,
    Duration = 1200,
}

function MBT.QbItems.RegisterItems()
    RegisterNetEvent('mbt_meta_clothes:useClothing')
    AddEventHandler('mbt_meta_clothes:useClothing', function(data)
        local ped = PlayerPedId()

        -- Resolve animation from config
        local animCfg
        if data.isTopDress then
            -- Torso kit: use tshirt slot (8) animation
            animCfg = MBT.Drawables[8] and MBT.Drawables[8]["Animation"]
        elseif data.slotType == "Drawables" then
            animCfg = MBT.Drawables[data.slotIndex] and MBT.Drawables[data.slotIndex]["Animation"]
        else
            animCfg = MBT.Props[data.slotIndex] and MBT.Props[data.slotIndex]["Animation"]
        end
        animCfg = animCfg or DEFAULT_ANIM

        local dict     = animCfg.Dict     or DEFAULT_ANIM.Dict
        local anim     = animCfg.Anim     or DEFAULT_ANIM.Anim
        local flags    = animCfg.Flag     or DEFAULT_ANIM.Flag
        local duration = tonumber(data.duration) or animCfg.Duration or DEFAULT_ANIM.Duration

        -- Progress bar label: try "use_{itemName}" locale key, then item name
        local itemName = data.itemData and data.itemData.name or ""
        local progLabel = MBT.Locale["use_" .. itemName]
                       or MBT.Locale["use_item"]
                       or itemName

        QBCore.Functions.Progressbar('mbt_use_clothing', progLabel, duration, false, true, {
            disableMovement    = false,
            disableCarMovement = false,
            disableMouse       = false,
            disableCombat      = true,
        }, {
            animDict = dict,
            anim     = anim,
            flags    = flags,
        }, {}, {}, function() -- Done
            StopAnimTask(ped, dict, anim, 1.0)
            TriggerServerEvent('mbt_meta_clothes:completeClothingUse', data.token)
        end, function() -- Cancel
            StopAnimTask(ped, dict, anim, 1.0)
            TriggerServerEvent('mbt_meta_clothes:cancelClothingUse', data.token)
            QBCore.Functions.Notify(MBT.Locale['cancel'] or 'Cancelled', "error")
        end)
    end)
end
