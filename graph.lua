-- Corona Libraries
local json = require("json")
local physics = require("physics")
local composer = require("composer")

-- Contrib
local scene = composer.newScene()
local perspective = require("perspective")

-- Create new SkillTree
local skillTree = require("skillTree")
table.foreach(skillTree.imageZoomLevels, print)

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
