system.activate("multitouch")

local root = nil
local firstSkilled = nil
local available = {} -- use to keep track of active node neighbors
local skilled = {}
local connections = {}
local roots = {}

ACTIVE_PATH_COLOR = {1.0, 1.0, 51/255}
INACTIVE_PATH_COLOR = {0.5, 0.5, 0.5}

ACTIVE_CLASS = 1
MAX_ZOOM = 2
MIN_ZOOM = 0.25

FRAME_LAYER = 1
ICON_LAYER = 2
CLASS_FRAME_LAYER = 3
ACTIVE_PATH_LAYER = 4
PATH_LAYER = 5

ARC_MAX_STEPS = 30
PATH_STROKE_WIDTH = 5

-- Corona Libraries
local json = require("json")
local physics = require("physics")
local composer = require("composer")
local widget = require("widget")

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

-- Create view and set up camera tracker
local camera = perspective.createView()
local width = display.pixelWidth
local height = display.pixelHeight
local tracker = display.newRect(height/2, width/2, height, width)
tracker:setFillColor(0.5, 0.0) -- make invisible! yu're a wizerd!
camera:setFocus(tracker)
camera:track()

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

    local spc = node.startPositionClasses[1]+1 -- there is only ever one
    roots[spc] = node

    local src
    if spc == ACTIVE_CLASS then
        root = node
        src = tree.assets[tree.constants.classframes[spc]]
    else
        src = tree.assets['PSStartNodeBackgroundInactive']
    end
    src = utils.pathfix(src)
    g:insert(display.newImage(src, system.ResourceDirectory, pos.x, pos.y, true))
    return g
end

function drawConnections(node)
    for i=1,#node.neighbors do
        local onid = tostring(node.neighbors[i])
        local other = tree.nodes[onid]
        drawConnection(node, other)
    end
end

function drawConnection(node, other)
    -- Remove old line if it exists
    if connections[node.id] ~= nil and connections[node.id][other.id] ~= nil then
        connections[node.id][other.id]:removeSelf()
        connections[node.id][other.id] = nil
    end
    if connections[other.id] ~= nil and connections[other.id][node.id] ~= nil then
        connections[other.id][node.id]:removeSelf()
        connections[other.id][node.id] = nil
    end

    -- Draw new line
    if (node.gid ~= other.gid) or (node.orbit ~= other.orbit) then
        local line = drawStraightConnection(node, other)
        if connections[node.id] == nil then connections[node.id] = {} end
        connections[node.id][other.id] = line
    else
        local line = drawArcedConnection(node, other)
        if connections[node.id] == nil then connections[node.id] = {} end
        connections[node.id][other.id] = line
    end
end

function drawStraightConnection(node, other)
    local p1, p2 = nodePosition(node), nodePosition(other)
    local line = display.newLine(p1.x, p1.y, p2.x, p2.y)
    if node.dGroup.active and (other.dGroup.active or other.id == root.id) then
        line:setStrokeColor(unpack(ACTIVE_PATH_COLOR))
        line.strokeWidth = PATH_STROKE_WIDTH
        camera:add(line, ACTIVE_PATH_LAYER)
    else
        line:setStrokeColor(unpack(INACTIVE_PATH_COLOR))
        line.strokeWidth = PATH_STROKE_WIDTH
        camera:add(line, PATH_LAYER)
    end
    return line
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

    if node.dGroup.active and (other.dGroup.active or other.id == root.id) then
        line:setStrokeColor(unpack(ACTIVE_PATH_COLOR))
        line.strokeWidth = PATH_STROKE_WIDTH
        camera:add(line, ACTIVE_PATH_LAYER)
    else
        line:setStrokeColor(unpack(INACTIVE_PATH_COLOR))
        line.strokeWidth = PATH_STROKE_WIDTH
        camera:add(line, PATH_LAYER)
    end
    return line
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
    for i=1,#node.neighbors do
        if not tree.nodes[tostring(node.neighbors[i])].active then
            table.insert(available, node.neighbors[i])
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
    for i=1,#node.neighbors do
        sid = tostring(node.neighbors[i])
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

function findReachable(from, reachable, searched)
    reachable[from.id] = from
    for _, nid in pairs(from.neighbors) do
        local node = tree.nodes[tostring(nid)]
        if skilled[nid] ~= nil and reachable[nid] == nil then
            reachable[nid] = node
            findReachable(node, reachable)
        end
    end
end

function refund(node)
    -- Remove node from skilled list
    skilled[node.id] = nil

    local reachable = {}
    if firstSkilled.id ~= node.id then
        findReachable(firstSkilled, reachable)
    end

    -- Deactivate unreachable nodes
    for nid, _node in pairs(skilled) do
        if reachable[nid] == nil then
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
    if #node.startPositionClasses > 0 then
        local classframe = createClassFrame(dGroup.active, node)
        dGroup:insert(classframe)
    else
        local skillIcon = createSkillIcon(dGroup.active, node)
        dGroup:insert(skillIcon)
        if not node.isMastery then
            local frame = createSkillFrame(dGroup.active, node)
            dGroup:insert(frame)
        end
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


-- Set up class change button
local opts = {'Scion', 'Marauder', 'Ranger', 'Witch', 'Duelist', 'Templar', 'Shadow'}
local picker = widget.newPickerWheel({
    left = display.contentWidth/2-160,
    top = display.contentHeight/2-111,
    columns = {
        {
            align = 'center',
            startIndex = ACTIVE_CLASS,
            labels = opts
        }
    }
})
picker.isVisible = false
local pickerButton = widget.newButton({
    label = 'Select',
    onPress = function(e)
        local values = picker:getValues()
        if ACTIVE_CLASS ~= values[1].index then
            for _, nid in pairs(root.neighbors) do
                local n = tree.nodes[tostring(nid)]
                if n.dGroup.active then
                    refund(n)
                    n.dGroup.active = false
                    updateNode(n.dGroup)
                end
            end
            ACTIVE_CLASS = values[1].index
            root = roots[ACTIVE_CLASS]
            for _, r in pairs(roots) do
                updateNode(r.dGroup)
            end
            tracker.x, tracker.y = root.group.position.x, root.group.position.y
        end
        picker.isVisible = false
        e.target.isVisible = false
    end,
    shape = 'rect',
    width = 320,
    height = 50,
    font = native.systemFontBold,
    left = display.contentWidth/2-160,
    top = display.contentHeight/2+(111),
})
pickerButton.isVisible = false
local showPickerWidgetButton = widget.newButton({
    x = 0, y = 50-10,
    label = 'Class',
    width = 50, height = 50,
    shape = 'rect',
    fillColor = {
        default = {1, 0.2, 0.5, 0.7},
        over = {1, 0.2, 0.5, 1}
    },
    onPress = function(e) 
        picker.isVisible = true
        pickerButton.isVisible = true
    end
})

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
        if touch ~= nil then
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
                if other ~= nil then
                    local prevLength = lengthOf(touch.last, other.last)
                    local newLength = lengthOf({x = e.x, y = e.y}, other.last)
                    if prevLength > newLength and camera.xScale >= MIN_ZOOM then
                         camera:scale(0.98, 0.98)
                    elseif prevLength < newLength and camera.xScale <= MAX_ZOOM then
                         camera:scale(1.02, 1.02)
                    end
                end
            end

            touch.last.x, touch.last.y = e.x, e.y
            touches[touchId] = touch
        end

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

tracker.x, tracker.y = root.group.position.x, root.group.position.y

return scene
