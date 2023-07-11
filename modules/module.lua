local moduleCache = {}

function loadModule(path)
    path = string.gsub(path, "%.", "/")
    
    local cachedModule = moduleCache[path]
    if cachedModule then
        return cachedModule
    end


    local code = LoadResourceFile(GetCurrentResourceName(), path .. ".lua")
    if code then
        local f, err = load(code, "/" .. path .. ".lua")
        if f then
            local ok, res = pcall(f)
            if ok then
                moduleCache[path] = res
                return res
            else
                error("Error loading module " .. path .. ": " .. res)
            end
        else
            error("Error parsing module " .. path .. ": " .. err)
        end
    else
        return nil
    end
end