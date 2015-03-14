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
-- These sizes seem too big at the moment...
node_widths = { 27, 38, 53 }
-- radii = { 27*2/3, 38*2/3, 53*2/3 }

camera:track()

-- Read JSON data from file
local path = system.pathForFile("combined_node_data.json", system.ResourceDirectory)
local file = io.open(path, "r")
local nodes = json.decode(file:read("*a"))

-- Draw all the nodes
function drawNode(node)
   x = node.location.x
   y = node.location.y
   tier = tonumber(node.tier)
   radius = node_widths[tier+1]/2 -- Divide by 2 b/c this is a radius, not a width
   local circ = display.newCircle(x, y, radius)
   circ.fill = off
   circ.active = false
   function circ:tap(e)
	  if self.active then
		 self.active = false
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
   elseif(e.phase == "moved") then
	  local moveX = e.x - lastX
	  local moveY = e.y - lastY
	  tracker.x, tracker.y = (tracker.x - moveX), (tracker.y - moveY)
	  lastX, lastY = e.x, e.y
   elseif(e.phase == "ended" or e.phase == "cancelled") then
   end

   return false
end

function keyboardListener(e)
   if e.phase == "up" then
	  local sx, sy = camera.xScale, camera.yScale
	  print(sx, sy)
	  if e.keyName == "up" then
		 print("zoom in")
		 camera:scale(2, 2)
	  elseif e.keyName == "down" then
		 print("zoom out")
		 camera:scale(0.5, 0.5)
	  end
   end
end

for _, node in ipairs(nodes) do
   drawNode(node)
end

local lastX = nil
local lastY = nil


Runtime:addEventListener("touch", dragListener)
Runtime:addEventListener("key", keyboardListener)

