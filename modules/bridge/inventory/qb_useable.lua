-----------------------------------------------------------
-- QB-Inventory server-side item registration
-----------------------------------------------------------

MBT.QbUseable = {}

local ItemConfig = {
    { name = 'topdress',  event = 'mbt_meta_clothes:useTopDress',  label = 'Top Dress',     weight = 100, unique = true,  isTopDress = true },
    { name = 'trousers',  event = 'mbt_meta_clothes:useTrousers',  label = 'Trousers',      weight = 10,  unique = false },
    { name = 'shoes',     event = 'mbt_meta_clothes:useShoes',     label = 'Shoes',          weight = 10,  unique = false },
    { name = 'chain',     event = 'mbt_meta_clothes:useChain',     label = 'Chain',          weight = 10,  unique = false },
    { name = 'watch',     event = 'mbt_meta_clothes:useWatch',     label = 'Watch',          weight = 10,  unique = false },
    { name = 'hat',       event = 'mbt_meta_clothes:useHat',       label = 'Hat',            weight = 10,  unique = false },
    { name = 'glasses',   event = 'mbt_meta_clothes:useGlasses',   label = 'Glasses',        weight = 10,  unique = false },
    { name = 'earaccess', event = 'mbt_meta_clothes:useEarAccess', label = 'Ear Accessory',  weight = 10,  unique = false },
}

function MBT.QbUseable.RegisterItems()
    for _, cfg in ipairs(ItemConfig) do
        QBCore.Functions.CreateUseableItem(cfg.name, function(source, item)
            local player = QBCore.Functions.GetPlayer(source)
            if not player or not player.Functions.GetItemByName(item.name) then return end

            local sexMatch = player.PlayerData.charinfo.gender == 0 and "male" or "female"

            if sexMatch ~= item.info.sex then
                TriggerClientEvent('mbt_meta_clothes:notify', player.PlayerData.source, { title = MBT.Locale["wrong_sex"].title, description = MBT.Locale["wrong_sex"].description .. sexMatch, type = "error", icon = "ban" })
                return
            end

            local index = cfg.isTopDress and item.info or item.info.index
            TriggerClientEvent(cfg.event, player.PlayerData.source, index, player.PlayerData.charinfo.gender, item.info, item)
        end)
    end

    local items = {}
    for _, cfg in ipairs(ItemConfig) do
        items[cfg.name] = {
            name = cfg.name,
            label = cfg.label,
            weight = cfg.weight,
            type = 'item',
            image = cfg.name .. '.png',
            unique = cfg.unique,
            useable = true,
            shouldClose = true,
            combinable = nil,
            description = cfg.label
        }
    end
    QBCore.Functions.AddItems(items)
end
