local utils = {}

-- Fixes url paths depending on platform
utils.pathfix = function(path)
    if system.getInfo("platformName") == "Win" then
        path = path:gsub("/","\\")
    end
    return path
end

return utils
