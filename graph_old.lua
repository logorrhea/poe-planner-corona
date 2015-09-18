-- Corona Libraries
local json = require("json")
local physics = require("physics")
local composer = require("composer")

-- Contrib
local scene = composer.newScene("graph")
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

-- Read node data from file
local path = system.pathForFile("combined_node_data.json", system.ResourceDirectory)
local file = io.open(path, "r")
local nodes = json.decode(file:read("*a"))
io.close()

-- Read line data from file
local path = system.pathForFile("line_data_formatted.json", system.ResourceDirectory)
local file = io.open(path, "r")
local lines = json.decode(file:read("*a"))
io.close()


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

-- Draw straight lines
function drawStraightLine(line)
    local line = display.newLine(line.start_x, line.start_y, line.end_x, line.end_y)
    line:setStrokeColor(1, 0, 0, 1)
    line.strokeWidth = 5
    camera:add(line, 1)
end

-- Draw the curvey lines
function drawArcLine(line)
    local arc = display.newGroup()

    local steps = 20
    local start = tonumber(line.start)
    local delta = - tonumber(line.delta)
    local radius = tonumber(line.radius)
    local stepSize = delta/steps

    -- This is the center point of the arc
    local x, y = tonumber(line.x), tonumber(line.y)

    local x0, y0, x1, y1 = nil
    for i = 0,steps do
        local radians = start - stepSize * i;
        if x0 == nil then
            x0, y0 = radius*math.cos(radians), radius*math.sin(radians)
        else
            x1, y1 = radius*math.cos(radians), radius*math.sin(radians)
            local line = display.newLine(x0+x, y0+y, x1+x, y1+y)
            line:append(points)
            line:setStrokeColor(1, 0, 0, 1)
            line.strokeWidth = 5
            arc:insert(line)
            x0, y0 = x1, y1
        end
    end

    camera:add(arc, 1)
end

-- Camera panning
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

-- Draw lines first so they end up on the bottom
for i, line in ipairs(lines) do
    if line.type == "0" then drawStraightLine(line) else drawArcLine(line) end
end

for _, node in ipairs(nodes) do
    drawNode(node)
end


local lastX = nil
local lastY = nil


Runtime:addEventListener("touch", dragListener)
Runtime:addEventListener("key", keyboardListener)



-- Event handler for the back button
local function backToMenu(event)
    if (event.phase == "ended") then
        composer.gotoScene("menu", { effect="crossFade", time=333})
    end
end

function scene:create(event)
    local sg = self.view

    -- go back button
    local backButton = widget.newButton({
        label = "<- Back",
        id = 1,
        onEvent = backToMenu,
        emboss = false,
        shape = "roundedRect",
        widtdh = 200,
        height = 50,
        font = native.systemFontBold,
        fontSize = 18,
        labelColor = { default = {1, 1, 1 }, over = { 0.5, 0.5, 0.5 } },
        cornerRadius = 8,
        labelYOffset = -6,
        fillColor = { default={0, 0.5, 1, 1}, over = { 0.5, 0.75, 1, 1 }},
        strokeColor = { default={0, 0, 1, 1}, over={0.333, 0.667, 1, 1}},
        strokeWidth = 2,
        x = 50,
        y = 50
    })
    sceneGroup:insert(backButton)
end

return scene
