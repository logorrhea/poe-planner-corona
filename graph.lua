system.activate("multitouch")

local root = nil
local firstSkilled = nil
local available = {} -- use to keep track of active node neighbors
local skilled = {}

ACTIVE_CLASS = 0
MAX_ZOOM = 2
MIN_ZOOM = 0.25

FRAME_LAYER = 1
PATH_LAYER = 2
ICON_LAYER = 3
CLASS_FRAME_LAYER = 4

ARC_MAX_STEPS = 30
PATH_STROKE_WIDTH = 5

-- Corona Libraries
local json = require("json")
local physics = require("physics")
local composer = require("composer")

-- Contrib
local scene = composer.newScene()
local perspective = require("perspective")
local utils = require('utils')

-- Create new SkillTree
local SkillTree = require("skillTree")
local tree = SkillTree.LoadFromFile("skillTree.json")

-- Create background image(s)
local bgImage = utils.pathfix(tree.assets["Background1"])
local bgGroup = display.newGroup()
local bgTileSize = 98
local covered = {x = -2*bgTileSize, y = -2*bgTileSize}
local screenSize = {x = display.actualContentWidth + 2*bgTileSize,
                    y = display.actualContentHeight + 2*bgTileSize}
while covered.x < screenSize.x do
    covered.y = 0
    while covered.y < screenSize.y do
        display.newImage(bgGroup, bgImage, system.ResourceDirectory, covered.x, covered.y, true)
        covered.y = covered.y + bgTileSize
    end
    covered.x = covered.x + bgTileSize
end

-- Create view and set up camera tracker
local camera = perspective.createView()
local width = display.pixelWidth
local height = display.pixelHeight
local tracker = display.newRect(height/2, width/2, height, width)
tracker:setFillColor(0.5, 0.0) -- make invisible! yu're a wizerd!
camera:setFocus(tracker)
camera:track()

-- Generate sprite sheets
local SpriteSheets = {}
table.foreach(tree.spriteSheets, function(name, sheet)
    local opts = {frames = sheet.frames}
    local path = utils.pathfix(sheet.src)
    SpriteSheets[name] = graphics.newImageSheet(path, system.ResourceDirectory, opts)
end)

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
            if prevLength > newLength and camera.xScale >= MIN_ZOOM then
                 camera:scale(0.98, 0.98)
            elseif prevLength < newLength and camera.xScale <= MAX_ZOOM then
                 camera:scale(1.02, 1.02)
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
    if e.phase == "down" then
        local sx, sy = camera.xScale, camera.yScale
        if e.keyName == "up" and camera.xScale <= MAX_ZOOM then
            camera:scale(1.1, 1.1)
        elseif e.keyName == "down" and camera.xScale >= MIN_ZOOM then
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
    --sg:insert(backButton)
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

function nodePositionInfo(node)
    local data = {}
    local a = arc(node)
    local r = OrbitRadii[node.orbit]
    return {
        position = {
            x = node.group.position.x - r * math.sin(-a),
            y = node.group.position.y - r * math.cos(-a),
        },
        angle = a
    }
end

function createSkillIcon(active, node)
    local activeIdx = active and "active" or "inactive"
    local sheet = active and node.activeSheet or node.inactiveSheet
    local pos = nodePosition(node)
    local textureData = tree.spriteSheets[sheet].sprites[node.icon]
    if textureData[activeIdx] ~= nil then
        return display.newImage(
                SpriteSheets[textureData[activeIdx].sheet],
                textureData[activeIdx].frame,
                pos.x, pos.y, true)
    elseif textureData.sheet == "mastery" then
        return display.newImage(
            SpriteSheets[textureData.sheet],
            textureData.frame,
            pos.x, pos.y, true)
    end
    return nil
end

function createSkillFrame(isActive, node)
    local pos = nodePosition(node)
    local frameKey = ""
    if node.isKeystone then
        if isActive then
            frameKey = "KeystoneFrameAllocated"
        else
            frameKey = "KeystoneFrameUnallocated"
        end
    elseif node.isNotable then
        if isActive then
            frameKey = "NotableFrameAllocated"
        else
            frameKey = "NotableFrameUnallocated"
        end
    else
        if isActive then
            frameKey = "PSSkillFrameActive"
        else
            frameKey = "PSSkillFrame"
        end
    end
    return display.newImage(tree.assets[frameKey], system.ResourceDirectory, pos.x, pos.y, true)
end

function fileExists(filename)
    local f = io.open(system.pathForFile(filename, system.ResourceDirectory))
    if f ~= nil then io.close(f) return true else return false end
end

function createClassFrame(active, node)
    local g = display.newGroup()
    local pos = nodePosition(node)

    -- Always the same background
    local fancy = utils.pathfix(tree.assets['PSGroupBackground3'])

    local top = display.newImage(fancy, system.ResourceDirectory, pos.x, pos.y, true)
    top:translate(0, -top.path.height/2)

    local bottom = display.newImage(fancy, system.ResourceDirectory, pos.x, pos.y, true)
    bottom:rotate(180)
    bottom:translate(0, bottom.path.height/2)

    g:insert(bottom)
    g:insert(top)

    local spc = node.startPositionClasses[1] -- there is only ever one
    local src
    if spc == ACTIVE_CLASS then
        root = node
        src = tree.assets[tree.constants.classframes[spc+1]]
    else
        src = tree.assets['PSStartNodeBackgroundInactive']
    end
    src = utils.pathfix(src)
    g:insert(display.newImage(src, system.ResourceDirectory, pos.x, pos.y, true))
    return g
end

function drawConnections(node)
    for i=1,#node.links do
        local onid = tostring(node.links[i])
        local other = tree.nodes[onid]
        --if node.dGroup.active and other.dGroup.active then
            drawConnection(node, other)
        --end
    end
end

function drawConnection(node, other)
    if (node.gid ~= other.gid) or (node.orbit ~= other.orbit) then
        drawStraightConnection(node, other)
    else
        drawArcedConnection(node, other)
    end
end

function drawStraightConnection(node, other)
    local p1, p2 = nodePosition(node), nodePosition(other)
    local line = display.newLine(p1.x, p1.y, p2.x, p2.y)
    line:setStrokeColor(0.5, 0.5, 0.5)
    line.strokeWidth = PATH_STROKE_WIDTH
    camera:add(line, PATH_LAYER)
end

function drawArcedConnection(node, other)
    local s, e = nodePositionInfo(node), nodePositionInfo(other)

    local startAngle, endAngle = e.angle, s.angle
    if startAngle > endAngle then
        startAngle, endAngle = endAngle, startAngle
    end
    local delta = endAngle - startAngle

    if delta > math.pi then
        local c = 2*math.pi - delta
        endAngle = startAngle
        startAngle = endAngle + c
        delta = c
    end

    local center = node.group.position
    local radius = OrbitRadii[node.orbit]
    local steps = math.ceil(ARC_MAX_STEPS*(delta/(math.pi*2)))
    local stepSize = delta/steps

    local points = {}
    local radians = 0
    endAngle = endAngle - math.pi/2
    for i=0,steps do
        radians = endAngle - stepSize*i
        table.insert(points, radius*math.cos(radians)+center.x)
        table.insert(points, radius*math.sin(radians)+center.y)
    end

    local y, x = table.remove(points), table.remove(points)
    local y2, x2 = table.remove(points), table.remove(points)
    local line = display.newLine(x, y, x2, y2)
    while #points ~= 0 do
        y, x = table.remove(points), table.remove(points)
        line:append(x, y)
    end

    line:setStrokeColor(0.5, 0.5, 0.5)
    line.strokeWidth = PATH_STROKE_WIDTH
    camera:add(line, PATH_LAYER)
end

function updateAvailableNodes()
    -- Clear current table
    for k in pairs(available) do
        available[k] = nil
    end

    for nid, node in pairs(skilled) do
        addNeighbors(node)
    end
end

function addNeighbors(node)
    for i=1,#node.links do
        if not tree.nodes[tostring(node.links[i])].active then
            table.insert(available, node.links[i])
        end
    end
end

function hasActiveNeighbor(node)
    local idx = table.indexOf(available, node.id)
    
    -- If its in the table, remove it and add its links if they are not
    -- already active
    if idx ~= nil then
        table.remove(available, idx)
        addNeighbors(node)
        return true
    end

    -- Check links for root, active
    for i=1,#node.links do
        sid = tostring(node.links[i])
        local neighbor = tree.nodes[sid]
        if neighbor.id == root.id then
            addNeighbors(node)
            return true
        elseif neighbor.dGroup.active then
            addNeighbors(node)
            return true
        end
    end

    return false
end

function refund(node)
    -- Remove node from skilled list
    skilled[node.id] = nil

    if firstSkilled.id ~= node.id then
        -- Start with first node selected (the one closest to the root)
        local front = {}
        front[firstSkilled.id] = firstSkilled
        for _, nid in pairs(firstSkilled.links) do
            if skilled[nid] ~= nil then
                front[nid] = skilled[nid]
            end
        end

        -- Copy front into reachable
        local reachable = {}
        for nid, _node in pairs(front) do
            reachable[nid] = _node
        end

        -- March outward from each "front" node, discovering reachable nodes
        while #front > 0 do
            local newfront = {}
            for nid, _node in pairs(front) do
                for _, lnid in pairs(skilled[nid].links) do
                    if skilled[lnid] ~= nil and reachable[lnid] == nil then
                        newfront[lnid] = tree.nodes[tostring(lnid)]
                        reachable[lnid] = newfront[lnid]
                    end
                end
            end

            front = newfront
        end
    else
        -- This isn't technically true...
        reachable = {}
    end

    -- Deactivate unreachable nodes
    for nid, _node in pairs(skilled) do
        if reachable[nid] == nil then
            print(nid .. ' is unreachable')
            _node.dGroup.active = false
            updateNode(_node.dGroup)
        end
    end

    skilled = reachable

    updateAvailableNodes()
end

function updateNode(dGroup)
    local node = tree.nodes[dGroup.nid]

    -- Remove child image
    while dGroup[1] ~= nil do
        dGroup:remove(1)
    end

    -- Attach proper icon
    local skillIcon = createSkillIcon(dGroup.active, node)
    dGroup:insert(skillIcon)
    if not node.isMastery then
        local frame = createSkillFrame(dGroup.active, node)
        dGroup:insert(frame)
    end

    -- Redraw this node's connections
    drawConnections(node)
end

-- Node click handler
function toggleNode(e)
    local g = e.target

    -- Retrieve node and texture data
    local node = tree.nodes[g.nid]
    print(node.id)

    -- Refund the node, and re-build skilled and available tables
    if node.dGroup.active then
        refund(node)
        g.active = false
        updateNode(g)

    -- Otherwise, make sure it has active neighbors
    elseif hasActiveNeighbor(node) then
        -- Add to list of skilled nodes
        skilled[node.id] = node
        if firstSkilled == nil then firstSkilled = node end
        g.active = true
        updateNode(g)
    end
end

-- Draw nodes
table.foreach(tree.nodes, function(i, node)
    local group = display.newGroup()
    group.nid = i
    group.active = false

    -- We've got a starting class node, do the things!
    if #node.startPositionClasses > 0 then
        local classframe = createClassFrame(group.active, node)
        group:insert(classframe)
        camera:add(group, CLASS_FRAME_LAYER)

    -- Node is not a class node, carry on
    else
        local icon = createSkillIcon(group.active, node)

        if icon ~= nil then
            group:insert(icon)
        end

        if not node.isMastery then
            local frame = createSkillFrame(group.active, node)
            if frame ~= nil then
                group:insert(frame)
            end

            -- Don't need click handler on mastery nodes
            group:addEventListener("tap", toggleNode)
        end

        camera:add(group, 1)
    end

    -- Add display group to node information, and add it to the panning camera
    node.dGroup = group
end)

-- Draw connections
-- @TODO: This is probably SUPER inefficient, I'm guessing
-- we're drawing the same lines multiple times
-- Also this isn't going to work in the long run as each one
-- has no idea whether or not the other is active
for _, node in pairs(tree.nodes) do
    drawConnections(node)
end

camera:scale(0.75, 0.75)

return scene
