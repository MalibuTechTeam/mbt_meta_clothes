if GetResourceState('ox_core') ~= 'started' then return end

local file = ('imports/%s.lua'):format(IsDuplicityVersion() and 'server' or 'client')
local import = LoadResourceFile('ox_core', file)
local chunk = assert(load(import, ('@@ox_core/%s'):format(file)))
chunk()

Drawables = {'topdress', 'trousers', 'shoes', 'chain'}
Props     = {'watch', 'hat', 'glasses', 'earaccess'}

for i = 1, #Drawables do
    if Drawables[i] == 'topdress' then
        exports(Drawables[i], function(data, slot)
            local playerSex = player.get('gender')
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
            local playerSex = player.get('gender')
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
        local playerSex = player.get('gender')
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