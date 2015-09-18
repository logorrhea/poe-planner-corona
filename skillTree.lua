-- Corona libs
local json = require("json")

local path = system.pathForFile("treeData.json", system.ResourceDirectory)
local file = io.open(path, "r")
local tree = json.decode(file:read("*all"))

return tree
