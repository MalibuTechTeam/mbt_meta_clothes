-----------------------------------------------------------
-- Shared OX Inventory item registration (client-side)
-- Eliminates duplicated ox_inventory exports() handlers
-- across QB, ESX, and OX framework bridges.
-----------------------------------------------------------

MBT.OxItems = {}

local DrawableItems = {'topdress', 'trousers', 'shoes', 'chain'}
local PropItems     = {'watch', 'hat', 'glasses', 'earaccess'}

--- Register all clothing items with ox_inventory exports
--- @param getPlayerSex function Must return two values: rawSex, sexLabel ("male"|"female")
function MBT.OxItems.RegisterItems(getPlayerSex)
    for i = 1, #DrawableItems do
        local itemName = DrawableItems[i]
        local isTopDress = itemName == 'topdress'

        exports(itemName, function(data, slot)
            local sex, sexLabel = getPlayerSex()

            if sexLabel ~= slot.metadata.sex then
                MBT.NotifyHandler(MBT.Labels["wrong_sex"]..sexLabel, "error")
                return
            end

            exports.ox_inventory:useItem(data, function(data)
                if data then
                    TriggerEvent("mbt_meta_clothes:checkDress", {
                        type = "Drawables",
                        index = isTopDress and data.metadata or data.metadata.index,
                        sex = sex,
                        itemInfo = isTopDress and data.metadata or data
                    })
                end
            end)
        end)
    end

    for i = 1, #PropItems do
        exports(PropItems[i], function(data, slot)
            local sex, sexLabel = getPlayerSex()

            if sexLabel ~= slot.metadata.sex then
                MBT.NotifyHandler(MBT.Labels["wrong_sex"]..sexLabel, "error")
                return
            end

            exports.ox_inventory:useItem(data, function(data)
                if data then
                    TriggerEvent("mbt_meta_clothes:checkDress", {
                        type = "Props",
                        index = data.metadata.index,
                        sex = sex,
                        itemInfo = data
                    })
                end
            end)
        end)
    end
end
