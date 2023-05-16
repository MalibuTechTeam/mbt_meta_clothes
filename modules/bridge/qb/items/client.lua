if GetResourceState('qb-core') ~= 'started' then return end
if GetResourceState('ox_inventory') ~= 'started' then return end

QBCore = exports['qb-core']:GetCoreObject()

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
                    TriggerEvent("mbt_metaclothes:checkDress", {
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
                    TriggerEvent("mbt_metaclothes:checkDress", {
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
                TriggerEvent("mbt_metaclothes:checkDress", {
                    type = "Props",
                    index = data.metadata.index, 
                    sex = playerSex,
                    itemInfo = data
                })
            end
        end)
    end)
end
