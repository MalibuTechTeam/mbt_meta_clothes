if GetResourceState('qb-core') ~= 'started' then return end

local isQBInventory = GetResourceState('qb-inventory'):find('start')
local isOXInventory = GetResourceState('ox_inventory'):find('start')

QBCore = exports['qb-core']:GetCoreObject()

if isOXInventory then
    Drawables = {'topdress', 'trousers', 'shoes', 'chain'}
    Props     = {'watch', 'hat', 'glasses', 'earaccess'}
    
    for i = 1, #Drawables do
        if Drawables[i] == 'topdress' then
            exports(Drawables[i], function(data, slot)
                local playerSex = QBCore.Functions.GetPlayerData().charinfo.gender
                local sexLabel = playerSex == 0 and "male" or "female"
    
                if sexLabel ~= slot.metadata.sex then
                    MBT.NotifyHandler(MBT.Labels["wrong_sex"]..sexLabel, "error")
                    return        
                end
        
                exports.ox_inventory:useItem(data, function(data)
                    if data then
                        TriggerEvent("mbt_meta_clothes:checkDress", {
                            type = "Drawables",
                            index = data.metadata, 
                            sex = playerSex,
                            itemInfo = data.metadata
                        })
                    end
                end)
            end)
        else
            exports(Drawables[i], function(data, slot)
                local playerSex = QBCore.Functions.GetPlayerData().charinfo.gender
                local sexLabel = playerSex == 0 and "male" or "female"
    
                if sexLabel ~= slot.metadata.sex then
                    MBT.NotifyHandler(MBT.Labels["wrong_sex"]..sexLabel, "error")
                    return     
                end
        
                exports.ox_inventory:useItem(data, function(data)
                    if data then
                        TriggerEvent("mbt_meta_clothes:checkDress", {
                            type = "Drawables",
                            index = data.metadata.index, 
                            sex = playerSex,
                            itemInfo = data
                        })
                    end
                end)
            end)
        end
    end
    
    for i = 1, #Props do
        exports(Props[i], function(data, slot)
            local playerSex = QBCore.Functions.GetPlayerData().charinfo.gender
            local sexLabel = playerSex == 0 and "male" or "female"
            
            if sexLabel ~= slot.metadata.sex then
                MBT.NotifyHandler(MBT.Labels["wrong_sex"]..sexLabel, "error")  
                return
            end
    
            exports.ox_inventory:useItem(data, function(data)
                if data then
                    TriggerEvent("mbt_meta_clothes:checkDress", {
                        type = "Props",
                        index = data.metadata.index, 
                        sex = playerSex,
                        itemInfo = data
                    })
                end
            end)
        end)
    end
end

if isQBInventory then
    RegisterNetEvent('mbt_meta_clothes:useTopDress', function(indexT, sexT, itemInfoT, itemData)
        local ped = PlayerPedId()
        QBCore.Functions.Progressbar("use_dress_kit", MBT.Labels["use_dress_kit"], 1200, false, true, {
            disableMovement = false,
            disableCarMovement = false,
            disableMouse = false,
            disableCombat = true,
        }, {
            animDict = 'clothingshirt',
            anim = 'try_shirt_positive_d',
            flags = 51,
        }, {}, {}, function() -- Done
            StopAnimTask(ped, "clothingshirt", "try_shirt_positive_d", 1.0)
            TriggerEvent("mbt_meta_clothes:checkDress", {
                type = "Drawables",
                index = indexT,
                sex = sexT,
                itemInfo = itemInfoT
            })
            TriggerServerEvent('mbt_meta_clothes:removeWear', itemData.name)
            TriggerEvent('inventory:client:ItemBox', itemData, "remove")
        end, function() -- Cancel
            StopAnimTask(ped, "clothingshirt", "try_shirt_positive_d", 1.0)
            QBCore.Functions.Notify(Lang:t('consumables.canceled'), "error")
        end)
    end)

    RegisterNetEvent('mbt_meta_clothes:useTrousers', function(indexT, sexT, itemInfoT, itemData)        
        local ped = PlayerPedId()
        QBCore.Functions.Progressbar("use_trousers", MBT.Labels["use_trousers"], 1200, false, true, {
            disableMovement = false,
            disableCarMovement = false,
            disableMouse = false,
            disableCombat = true,
        }, {
            animDict = 're@construction',
            anim = 'out_of_breath',
            flags = 51,
        }, {}, {}, function() -- Done
            StopAnimTask(ped, 're@construction', 'out_of_breath', 1.0)
            TriggerEvent("mbt_meta_clothes:checkDress", {
                type = "Drawables",
                index = indexT,
                sex = sexT,
                itemInfo = itemInfoT
            })
            TriggerServerEvent('mbt_meta_clothes:removeWear', itemData.name)
            TriggerEvent('inventory:client:ItemBox', itemData, "remove")
        end, function() -- Cancel
            StopAnimTask(ped, 're@construction', 'out_of_breath', 1.0)
            QBCore.Functions.Notify(Lang:t('consumables.canceled'), "error")
        end)
    end)

    RegisterNetEvent('mbt_meta_clothes:useShoes', function(indexT, sexT, itemInfoT, itemData)
        local ped = PlayerPedId()
        QBCore.Functions.Progressbar("use_shoes", MBT.Labels["use_shoes"], 1200, false, true, {
            disableMovement = false,
            disableCarMovement = false,
            disableMouse = false,
            disableCombat = true,
        }, {
            animDict = 'random@domestic',
            anim = 'pickup_low',
            flags = 0,
        }, {}, {}, function() -- Done
            StopAnimTask(ped, 'random@domestic', 'pickup_low', 1.0)
            TriggerEvent("mbt_meta_clothes:checkDress", {
                type = "Drawables",
                index = indexT,
                sex = sexT,
                itemInfo = itemInfoT
            })
            TriggerServerEvent('mbt_meta_clothes:removeWear', itemData.name)
            TriggerEvent('inventory:client:ItemBox', itemData, "remove")
        end, function() -- Cancel
            StopAnimTask(ped, 'random@domestic', 'pickup_low', 1.0)
            QBCore.Functions.Notify(Lang:t('consumables.canceled'), "error")
        end)
    end)

    RegisterNetEvent('mbt_meta_clothes:useChain', function(indexT, sexT, itemInfoT, itemData)
        local ped = PlayerPedId()
        QBCore.Functions.Progressbar("use_chain", MBT.Labels["use_chain"], 2500, false, true, {
            disableMovement = false,
            disableCarMovement = false,
            disableMouse = false,
            disableCombat = true,
        }, {
            animDict = 'clothingtie',
            anim = 'try_tie_positive_a',
            flags = 51,
        }, {}, {}, function() -- Done
            StopAnimTask(ped, 'clothingtie', 'try_tie_positive_a', 1.0)
            TriggerEvent("mbt_meta_clothes:checkDress", {
                type = "Drawables",
                index = indexT,
                sex = sexT,
                itemInfo = itemInfoT
            })
            TriggerServerEvent('mbt_meta_clothes:removeWear', itemData.name)
            TriggerEvent('inventory:client:ItemBox', itemData, "remove")
        end, function() -- Cancel
            StopAnimTask(ped, 'clothingtie', 'try_tie_positive_a', 1.0)
            QBCore.Functions.Notify(Lang:t('consumables.canceled'), "error")
        end)
    end)

    RegisterNetEvent('mbt_meta_clothes:useHat', function(indexT, sexT, itemInfoT, itemData)
        local ped = PlayerPedId()
        QBCore.Functions.Progressbar("use_hat", MBT.Labels["use_hat"], 1200, false, true, {
            disableMovement = false,
            disableCarMovement = false,
            disableMouse = false,
            disableCombat = true,
        }, {
            animDict = 'missheist_agency2ahelmet',
            anim = 'take_off_helmet_stand',
            flags = 51,
        }, {}, {}, function() -- Done
            StopAnimTask(ped, 'missheist_agency2ahelmet', 'take_off_helmet_stand', 1.0)
            TriggerEvent("mbt_meta_clothes:checkDress", {
                type = "Props",
                index = indexT,
                sex = sexT,
                itemInfo = itemInfoT
            })
            TriggerServerEvent('mbt_meta_clothes:removeWear', itemData.name)
            TriggerEvent('inventory:client:ItemBox', itemData, "remove")
        end, function() -- Cancel
            StopAnimTask(ped, 'missheist_agency2ahelmet', 'take_off_helmet_stand', 1.0)
            QBCore.Functions.Notify(Lang:t('consumables.canceled'), "error")
        end)
    end)

    RegisterNetEvent('mbt_meta_clothes:useGlasses', function(indexT, sexT, itemInfoT, itemData)
        local ped = PlayerPedId()
        QBCore.Functions.Progressbar("use_glasses", MBT.Labels["use_glasses"], 1200, false, true, {
            disableMovement = false,
            disableCarMovement = false,
            disableMouse = false,
            disableCombat = true,
        }, {
            animDict = 'clothingspecs',
            anim = 'take_off',
            flags = 51,
        }, {}, {}, function() -- Done
            StopAnimTask(ped, 'clothingspecs', 'take_off', 1.0)
            TriggerEvent("mbt_meta_clothes:checkDress", {
                type = "Props",
                index = indexT,
                sex = sexT,
                itemInfo = itemInfoT
            })
            TriggerServerEvent('mbt_meta_clothes:removeWear', itemData.name)
            TriggerEvent('inventory:client:ItemBox', itemData, "remove")
        end, function() -- Cancel
            StopAnimTask(ped, 'clothingspecs', 'take_off', 1.0)
            QBCore.Functions.Notify(Lang:t('consumables.canceled'), "error")
        end)
    end)

    RegisterNetEvent('mbt_meta_clothes:useEarAccess', function(indexT, sexT, itemInfoT, itemData)
        local ped = PlayerPedId()
        QBCore.Functions.Progressbar("use_earaccess", MBT.Labels["use_earaccess"], 1200, false, true, {
            disableMovement = false,
            disableCarMovement = false,
            disableMouse = false,
            disableCombat = true,
        }, {
            animDict = 'mp_cp_stolen_tut',
            anim = 'b_think',
            flags = 51,
        }, {}, {}, function() -- Done
            StopAnimTask(ped, 'mp_cp_stolen_tut', 'b_think', 1.0)
            TriggerEvent("mbt_meta_clothes:checkDress", {
                type = "Props",
                index = indexT,
                sex = sexT,
                itemInfo = itemInfoT
            })
            TriggerServerEvent('mbt_meta_clothes:removeWear', itemData.name)
            TriggerEvent('inventory:client:ItemBox', itemData, "remove")
        end, function() -- Cancel
            StopAnimTask(ped, 'mp_cp_stolen_tut', 'b_think', 1.0)
            QBCore.Functions.Notify(Lang:t('consumables.canceled'), "error")
        end)
    end)

    RegisterNetEvent('mbt_meta_clothes:useWatch', function(indexT, sexT, itemInfoT, itemData)
        local ped = PlayerPedId()
        QBCore.Functions.Progressbar("use_watch", MBT.Labels["use_watch"], 1200, false, true, {
            disableMovement = false,
            disableCarMovement = false,
            disableMouse = false,
            disableCombat = true,
        }, {
            animDict = 'nmt_3_rcm-10',
            anim = 'cs_nigel_dual-10',
            flags = 51,
        }, {}, {}, function() -- Done
            StopAnimTask(ped, 'nmt_3_rcm-10', 'cs_nigel_dual-10', 1.0)
            TriggerEvent("mbt_meta_clothes:checkDress", {
                type = "Props",
                index = indexT,
                sex = sexT,
                itemInfo = itemInfoT
            })
            TriggerServerEvent('mbt_meta_clothes:removeWear', itemData.name)
            TriggerEvent('inventory:client:ItemBox', itemData, "remove")
        end, function() -- Cancel
            StopAnimTask(ped, 'nmt_3_rcm-10', 'cs_nigel_dual-10', 1.0)
            QBCore.Functions.Notify(Lang:t('consumables.canceled'), "error")
        end)
    end)
end