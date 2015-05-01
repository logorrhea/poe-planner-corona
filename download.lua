-- Corona libs
local composer = require("composer")
local widget = require("widget")

-- Locals
local scene = composer.newScene()

-- Event handler for the back button
local function backToMenu(event)
    if (event.phase == "ended") then
        composer.gotoScene("menu", { effect="crossFade", time=333})
    end
end

function scene:create(event)
    local sceneGroup = self.view


    -- Create background
    local bg = display.newRect(0, 0, display.contentWidth, display.contentHeight)
    bg:setFillColor(1)
    bg.x = display.contentCenterX
    bg.y = display.contentCenterY
    sceneGroup:insert(bg)
    
    -- Create buttons
    local centerX = display.contentWidth / 2
    local centerY = display.contentHeight / 2

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

function scene:show(event)
    local sceneGroup = self.view
    local phase = event.phase

    if (phase == "will") then
        -- Called when the scene is still off screen (but is about to come on)
    elseif (phase == "did") then
        -- Called once the scene is on screen
        -- Insert code here to make the scene come alive
        -- Example: start timers, begin animation, play audio, etc.
    end
end

function scene:hide(event)
    local sceneGroup = self.view
    local phase = event.phase

    if (phase == "will") then
        -- Called when the scene is still on screen (but is about to come off)
        -- Insert code here to "pause" the scene.
        -- Example: stop timers, stop animation, stop audio, etc.
    elseif (phase == "did") then
        -- Called immediately after the scene goes off screen
    end
end

function scene:destroy(event)
    local sceneGroup = self.view

    -- Called prior to the removal of scene's view ("sceneGroup")
    -- Insert code here to clean up the scene
    -- Example: remove display objects, save state, etc.
end


-- Listener setup
scene:addEventListener("create", scene)
scene:addEventListener("show",   scene)
scene:addEventListener("hide",   scene)
scene:addEventListener("destroy",scene)

return scene

