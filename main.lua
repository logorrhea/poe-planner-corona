-----------------------------------------------------------------------------------------
--
-- main.lua
--
-----------------------------------------------------------------------------------------

-- Corona Libraries
local json = require("json")
local physics = require("physics")

-- Contrib
local perspective = require("perspective")

-- Load Personal Libraries
require("jsonDecoder")

local camera = perspective.createView()

local function drawNode(node)
   x = node.location.x
   y = node.location.y
   tier = node.tier
   radius = 20 + 10*node.tier
   camera.add(display.newCircle(x, y, radius))
end

-- Read JSON data from file
local path = system.pathForFile("combined_node_data.json", system.ResourceDirectory)
local file = io.open(path, "r")
local nodes = json.decode(file:read("*a"))

for _, node in ipairs(nodes) do
   drawNode(node)
end

local function dragListener(event)
   if(event.phase == "began") then
	  print("began")
   elseif(event.phase == "moved") then
	  print("moved")
   elseif(event.phase == "ended" or event.phase == "cancelled") then
	  print("ended")
   end

   return true
end

Runtime:addEventListener("touch", dragListener)
