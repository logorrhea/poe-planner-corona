local skillTree = {}

-- Corona libs
local json = require("json")

function fileExists(filename)
    local f = io.open(system.pathForFile(filename, system.DocumentsDirectory))
    if f ~= nil then io.close(f) return true else return false end
end

function NetworkListener(event)
    if (event.isError) then
    elseif (event.phase == "began") then
        if (event.bytesEstimated <= 0) then
            print("Download starting, size unknown")
        else
            print("Download starting, estimated size: " .. event.bytesEstimated)
        end
    elseif (event.phase == "progress") then
        if (event.bytesEstimated <= 0) then
            print("Download progress: "..event.bytesTransferred)
        else
            print("Download progress: "..event.bytesTransferred.." of estimated "..event.bytesEstimated)
        end
    elseif (event.phase == "ended") then
        print("Download complete, total bytes transferred: " .. event.bytesTransferred)
    end
end

function GetImage(file, url)
    local params = {
        progress = "download",
        response = {
            filename = file,
            baseDirectory = system.DocumentsDirectory,
        }
    }
    network.request(url, "GET", function(event)
        if event.phase == "ended" then
            print("Download complete for " .. file)
        end
    end, params)
end

-- Creates the organized tree from JSON data downloaded from pathofexile.com
function skillTree.BuildFromData(dataString)
    -- Parse json data string
    local data = json.decode(dataString)

    -- Create skill tree from parsed data
    local tree = {}

    -- Download and store assets
    tree.assets = {}
    --GetImage("Background1.png", data.assets["Background1"]["0.3835"])
    --tree.assets["Background1"] = "data/images/Background1.png"
    table.foreach(data.assets, function(label, items)
        local href = nil
        local file = label..".png"

        -- Just get the largest one
        table.foreach(items, function(size, link)
            href = link
        end)

        if not fileExists(file) then
            GetImage(file, href)
        end

        tree.assets[label] = "data/images/"..file
    end)

    tree.constants = data.constants

    -- Translate start classes
    tree.constants.classframes = {
        'centerscion',
        'centermarauder',
        'centerranger',
        'centerwitch',
        'centerduelist',
        'centertemplar',
        'centershadow',
    }

    -- Set up skill icons
    local imageRoot = data.imageRoot .. "/build-gen/passive-skill-sprite/"
    spriteSheets = {}
    table.foreach(data.skillSprites, function(label, list)

        -- Get the last (highest-rez) one in the list for each set
        local last = list[#list]

        -- Download the file if it doesn't exist
        if not fileExists(last.filename) then
            GetImage(imageRoot, last.filename)
        end

        -- Construct spriteSheet frames array, save indices in sprites table
        local frames = {}
        local sprites = {}
        table.foreach(last.coords, function(icon, coords)
            local idx = #frames + 1
            frames[idx] = {
                x = coords.x,
                y = coords.y,
                width = coords.w,
                height = coords.h
            }

            local iconData = {
                frame = idx,
                sheet = label
            }

            -- Create empty if not exists
            if sprites[icon] == nil then sprites[icon] = {} end
            
            -- Add coords depending on icon type
            if label:find("Active") then
                sprites[icon].active = iconData
            elseif label:find("Inactive") then
                sprites[icon].inactive = iconData
            else
                sprites[icon] = iconData -- mastery, no inactive state
            end
        end)
        spriteSheets[label] = {
            src = "data/images/"..last.filename,
            frames = frames,
            sprites = sprites,
        }
    end)
    tree.spriteSheets = spriteSheets

    -- Parse nodes
    tree.nodes = {}
    table.foreach(data.nodes, function(i, n)
        -- Build new node
        node = {}

        -- Get attributes from json node
        node.dexAdded = n.da
        node.intAdded = n.ia
        node.strAdded = n.sa
        node.name = n.dn
        node.gid = n.g
        node.icon = n.icon
        node.id = n.id
        node.isKeystone = n.ks
        node.isMastery = n.m
        node.isNotable = n["not"] -- n.not is reserved :(
        node.orbit = n.o + 1 -- lua arrays are not 0-indexed
        node.orbitIndex = n.oidx
        node.links = table.copy(n.out)
        node.neighbors = table.copy(n.out)
        node.startPositionClasses = n.spc

        -- Determine sprite sheet to use
        if node.isNotable then
            node.activeSheet = "notableActive"
            node.inactiveSheet = "notableInactive"
        elseif node.isKeystone then
            node.activeSheet = "keystoneActive"
            node.inactiveSheet = "keystoneInactive"
        elseif node.isMastery then
            node.activeSheet = "mastery"
            node.inactiveSheet = "mastery"
        else
            node.activeSheet = "normalActive"
            node.inactiveSheet = "normalInactive"
        end

        -- Add to nodes
        tree.nodes[tonumber(node.id)] = node
    end)

    -- Run through nodes a second time, so we can make links
    -- go both directions
    for nid, node in pairs(tree.nodes) do
        for _, lnid in ipairs(node.links) do
            if lnid ~= nid and table.indexOf(tree.nodes[lnid].neighbors, nid) == nil then
                table.insert(tree.nodes[lnid].neighbors, nid)
            end
        end
    end

    -- Parse groups
    tree.groups = {}
    table.foreach(data.groups, function(i, g)
        -- Build new group
        group = {}

        -- Get attributes from json group
        group.position = {x = g.x, y = g.y}
        group.nodes = g.n
        group.ocpOrb = g.oo
        
        for _, nid in ipairs(group.nodes) do
            tree.nodes[nid].group = group
        end

        tree.groups[i] = group
    end)

    print("done")

    return tree
end

-- Loads a JSON-serialized SkillTree from json file
function skillTree.LoadFromFile(filename)
    local path = system.pathForFile(filename, system.ResourceDirectory)
    local file = io.open(path, "r")
    return json.decode(file:read("*all"))
end

return skillTree
