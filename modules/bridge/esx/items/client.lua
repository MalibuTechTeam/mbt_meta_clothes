if GetResourceState('es_extended') ~= 'started' then return end
if GetResourceState('ox_inventory') ~= 'started' then return end

ESX = exports.es_extended:getSharedObject()

Drawables = {'topdress', 'trousers', 'shoes', 'chain'}
Props     = {'watch', 'hat', 'glasses', 'earaccess'}

for i = 1, #Drawables do
    if Drawables[i] == 'topdress' then
        exports(Drawables[i], function(data, slot)
            local playerSex = ESX.PlayerData.sex
            local sexLabel = playerSex == "m" and "male" or "female"

            if sexLabel ~= slot.metadata.sex then
                MBT.NotifyHandler(MBT.Labels["wrong_sex"]..sexLabel, "error")        
            end
    
            TriggerEvent("mbt_metaclothes:checkDress", {
                type = "Drawables",
                index = slot.metadata, 
                sex = playerSex,
                cb = function(canDress)
                    if not canDress then
                        MBT.NotifyHandler(MBT.Labels["undress"], "error")  
                        return 
                    end 
                    
                    exports.ox_inventory:useItem(data, function(data)
                        if data then
                            TriggerEvent("mbt_metaclothes:applyKitDress", data.metadata)
                        end
                    end)
                end
            })
        end)
    else
        exports(Drawables[i], function(data, slot)
            local playerSex = ESX.PlayerData.sex
            local sexLabel = playerSex == "m" and "male" or "female"

            if sexLabel ~= slot.metadata.sex then
                MBT.NotifyHandler(MBT.Labels["wrong_sex"]..sexLabel, "error")     
            end
    
            TriggerEvent("mbt_metaclothes:checkDress", {
                type = "Drawables",
                index = slot.metadata.index, 
                sex = playerSex,
                cb = function(canDress)
                    if not canDress then
                        MBT.NotifyHandler(MBT.Labels["undress"], "error")  
                        return 
                    end 
                    
                    exports.ox_inventory:useItem(data, function(data)
                        if data then
                            TriggerEvent("mbt_metaclothes:applyDress", data.metadata)
                        end
                    end)
                end
            })
        end)
    end
end

for i = 1, #Props do
    exports(Props[i], function(data, slot)
        local playerSex = ESX.PlayerData.sex
        local sexLabel = playerSex == "m" and "male" or "female"
       
        if sexLabel ~= slot.metadata.sex then
            MBT.NotifyHandler(MBT.Labels["wrong_sex"]..sexLabel, "error")     
        end

        TriggerEvent("mbt_metaclothes:checkDress", {
            type = "Props",
            index = slot.metadata.index, 
            sex = playerSex,
            cb = function(canDress)
                if not canDress then
                    MBT.NotifyHandler(MBT.Labels["undress"], "error")  
                    return 
                end 
                
                exports.ox_inventory:useItem(data, function(data)
                    if data then
                        TriggerEvent("mbt_metaclothes:applyProps", data.metadata)
                    end
                end)
            end
        })
    end)
end