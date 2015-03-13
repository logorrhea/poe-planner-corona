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
local width = display.pixelWidth
local height = display.pixelHeight
local tracker = display.newRect(height/2, width/2, height, width)
tracker:setFillColor(0.5, 0.25)
camera:setFocus(tracker)

off = { 1, 0, 0}
on  = { 0, 1, 0 }

camera:track()

-- Read JSON data from file
local path = system.pathForFile("combined_node_data.json", system.ResourceDirectory)
local file = io.open(path, "r")
local nodes = json.decode(file:read("*a"))

function drawNode(node)
   x = node.location.x
   y = node.location.y
   tier = node.tier
   radius = 20 + 10*node.tier
   local circ = display.newCircle(x, y, radius)
   circ.fill = off
   circ.active = false
   function circ:tap(e)
	  if self.active then
		 self.fill = off
	  else
		 self.active = true
		 self.fill = on
	  end
	  return true
   end
   circ:addEventListener("tap", circ)
   camera:add(circ, 1)
end

function dragListener(e)
   if(e.phase == "began") then
	  lastX = e.xStart
	  lastY = e.yStart
	  print(e.xStart)
   elseif(e.phase == "moved") then
	  local moveX = e.x - lastX
	  local moveY = e.y - lastY
	  tracker.x, tracker.y = (tracker.x + moveX), (tracker.y + moveY)
	  lastX, lastY = e.x, e.y
	  print(e.xStart)
   elseif(e.phase == "ended" or e.phase == "cancelled") then
   end

   return false
end

for _, node in ipairs(nodes) do
   drawNode(node)
end

local lastX = nil
local lastY = nil


Runtime:addEventListener("touch", dragListener)

