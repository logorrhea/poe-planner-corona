system.activate("multitouch")

-- Corona Libraries
local json = require("json")
local physics = require("physics")
local composer = require("composer")

-- Contrib
local scene = composer.newScene()
local perspective = require("perspective")

-- Create new SkillTree
local SkillTree = require("skillTree")
local tree = SkillTree.LoadFromFile("skillTree.json")

-- Generate sprite sheets
local SpriteSheets = {}
table.foreach(tree.spriteSheets, function(name, sheet)
    local opts = {frames = sheet.frames}
    local path = sheet.src

    -- Change slashes for windows
    if system.getInfo("platformName") == "Win" then
        path = path:gsub("/","\\")
    end

    SpriteSheets[name] = graphics.newImageSheet(path, system.ResourceDirectory, opts)
end)

-- Create view and set up camera tracker
local camera = perspective.createView()
local width = display.pixelWidth
local height = display.pixelHeight
local tracker = display.newRect(height/2, width/2, height, width)
tracker:setFillColor(0.5, 0.0) -- make invisible! yu're a wizerd!
camera:setFocus(tracker)
camera:track()

-- Some constants
local SkillsPerOrbit = {1, 6, 12, 12, 12}
local OrbitRadii = {0, 82, 162, 335, 493}
local NodeRadii = {
    standard = 51,
    keystone = 109,
    notable = 70,
    mastery = 107,
    classStart = 200
}

-- Colors (won't need this forever)
off = { 1, 0, 0}
on  = { 0, 1, 0 }

-- Camera controls
local touches = {}
local touchCount = 0
function lengthOf(a, b)
    local w, h = b.x-a.x, b.y-a.y
    return (w*w + h*h)^0.5
end
function directionVector(a, b)
    local length = lengthOf(a, b)
    local diffx = b.x - a.x
    local diffy = b.y - a.y
    return {x = diffx/length, y = diffy/length}
end
function touchListener(e)
    local touchId = e.xStart..e.yStart
    local moveSpeed = 10

    if e.phase == "began" then
        -- Store up to two touches
        local touch = {
            last = {
                x = e.xStart,
                y = e.yStart,
            }
        }
        touchCount = touchCount + 1
        touches[touchId] = touch
        return true

    elseif e.phase == "moved" then

        local touch = touches[touchId]

        -- Handle panning
        if touchCount == 1 then
            --local sx, sy = camera.xScale, camera.yScale
            local moveX = (e.x - touch.last.x)/camera.xScale
            local moveY = (e.y - touch.last.y)/camera.yScale
            tracker.x, tracker.y = (tracker.x - moveX), (tracker.y - moveY)

        -- Handle pinch zoom
        else
            local other = nil
            table.foreach(touches, function(i, t)
                if i ~= touchId then
                    other = t
                end
            end)
            local prevLength = lengthOf(touch.last, other.last)
            local newLength = lengthOf({x = e.x, y = e.y}, other.last)
            if prevLength > newLength then
                -- zoom out
                 camera:scale(0.9, 0.9)
            elseif prevLength < newLength then
                -- zoom in
                 camera:scale(1.1, 1.1)
            end
        end

        touch.last.x, touch.last.y = e.x, e.y
        touches[touchId] = touch

        -- Update touch coords
        return true

    elseif e.phase == "ended" or e.phase == "cancelled" then
        touchCount = touchCount - 1
        touches[touchId] = nil
        return true
    end

    -- Pinch zoom
    return false
end
Runtime:addEventListener("touch", touchListener)

function keyboardListener(e)
    if e.phase == "up" then
        local sx, sy = camera.xScale, camera.yScale
        print(sx, sy)
        if e.keyName == "up" then
            print("zoom in")
            camera:scale(1.1, 1.1)
        elseif e.keyName == "down" then
            print("zoom out")
            camera:scale(0.9, 0.9)
        end
    end
end
Runtime:addEventListener("key", keyboardListener)

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

function arc(node)
    return 2 * math.pi * node.orbitIndex / SkillsPerOrbit[node.orbit]
end

function nodePosition(node)
    local x = 0
    local y = 0

    if node.group ~= nil then
        local r = OrbitRadii[node.orbit]
        local a = arc(node)

        x = node.group.position.x - r * math.sin(-a)
        y = node.group.position.y - r * math.cos(-a)
    end
    
    return {x = x, y = y}
end

function createSkillIcon(isActive, node)
    local pos = nodePosition(node)
    local textureData = tree.sprites[node.icon]
    if textureData[isActive] ~= nil then
        return display.newImage(
                SpriteSheets[textureData[isActive].sheet],
                textureData[isActive].frame,
                pos.x, pos.y)
    elseif textureData.sheet == "mastery" then
        return display.newImage(
            SpriteSheets[textureData.sheet],
            textureData.frame,
            pos.x, pos.y)
    else
        print(isActive, node.icon)
    end
    return nil
end

-- Node click handler
function toggleNode(e)
    local g = e.target

    -- Remove child image
    for i=1,g.numChildren do
        g[i]:removeSelf()
    end

    -- Retrieve node and texture data
    local node = tree.nodes[g.nid]

    -- Attach proper icon
    local skillIcon = createSkillIcon(g.active, node)
    g:insert(skillIcon)

    -- Toggle active
    if g.active == "active" then g.active = "inactive" else g.active = "active" end
end


table.foreach(tree.nodes, function(i, node)
    local group = display.newGroup()
    group.nid = i
    group.active = "inactive"

    local icon = createSkillIcon(group.active, node)
    if icon ~= nil then
        group:insert(icon)
    end

    group:addEventListener("tap", toggleNode)
    camera:add(group, 1)
end)

return scene
