
local Utils = {} 

---@param repository string
---@return nil
function Utils.MbtVersionCheck(repository)
	local resource = GetInvokingResource() or GetCurrentResourceName()
    
	local currentVersion = GetResourceMetadata(resource, 'version', 0)
    
	if currentVersion then
		currentVersion = currentVersion:match('%d+%.%d+%.%d+')
	end
    
	if not currentVersion then return print(("^1Unable to determine current resource version for '%s' ^0"):format(resource)) end
    
	SetTimeout(1000, function()
		PerformHttpRequest(('https://api.github.com/repos/%s/releases/latest'):format(repository), function(status, response)
			if status ~= 200 then return end
            
			response = json.decode(response)
			if response.prerelease then return end
            
			local latestVersion = response.tag_name:match('%d+%.%d+%.%d+')
			if not latestVersion or latestVersion == currentVersion then return end
            
            local cv = { string.strsplit('.', currentVersion) }
            local lv = { string.strsplit('.', latestVersion) }
            
            for i = 1, #cv do
                local current, minimum = tonumber(cv[i]), tonumber(lv[i])
                
                if current ~= minimum then
                    if current < minimum then
                        return print(('^3An update is available for %s (current version: %s)\r\n%s^0'):format(resource, currentVersion, response.html_url))
                    else break end
                end
            end
		end, 'GET')
	end)
end

function Utils.PrintWarning()
    print("~r~ You are using a different type of inventory, please remember to fill the custom events on the config. If you have problems contact us on Discord: https://discord.gg/tqk3kAEr4f")
    return
end

function Utils.MbtDebugger(...)
	if MBT.Debug then
		local arg = {...}
		local printResult = "["..GetCurrentResourceName().."] | " 
		for _,v in ipairs(arg) do
			printResult = printResult .. tostring(v) .. "\t"
		end
		printResult = printResult .. "\n"
		print(printResult)
	end
end

Utils.MbtVersionCheck('MalibuTechTeam/mbt_meta_clothes')

return Utils