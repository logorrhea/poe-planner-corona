local skillTree = {}

-- Corona libs
local json = require("json")

function fileExists(filename)
    local f = io.open(system.pathForFile(filename, system.DocumentsDirectory))
    if f ~= nil then io.close(f) return true else return false end
end

function GetImage(imageRoot, image)
    local params = {
        progress = "download",
        response = {
            filename = image,
            baseDirectory = system.DocumentsDirectory,
        }
    }
    local url = imageRoot..image
    network.request(url, "GET", function(event)
        if event.phase == "ended" then
            print("Download complete")
        end
    end, params)
end

-- Creates the organized tree from JSON data downloaded from pathofexile.com
function skillTree.BuildFromData(dataString)
    -- Parse json data string
    local data = json.decode(dataString)

    -- Create skill tree from parsed data
    local tree = {}

    -- Set up skill icons
    local imageRoot = data.imageRoot .. "/build-gen/passive-skill-sprite/"
    sprites = {}
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
            if table.indexOf(sprites[icon]) == nil then
                sprites[icon] = {}
            end
            
            -- Add coords depending on icon type
            if label:match("Active") then
                sprites[icon].active = iconData
            elseif label:match("Inactive") then
                sprites[icon].inactive = iconData
            else
                sprites[icon] = iconData -- mastery, no inactive state
            end
        end)
        spriteSheets[label] = {
            src = "data/images/"..last.filename,
            frames = frames
        }
    end)
    tree.sprites = sprites
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
        node.isKeyStone = n.ks
        node.isMastery = n.m
        node.isNotable = n["not"] -- n.not is reserved :(
        node.orbit = n.o + 1 -- lua arrays are not 0-indexed
        node.orbitIndex = n.oidx
        node.links = n.out

        -- Add to nodes
        tree.nodes[node.id] = node
    end)

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

    return tree
end

-- Loads a JSON-serialized SkillTree from json file
function skillTree.LoadFromFile(filename)
    local path = system.pathForFile(filename, system.ResourceDirectory)
    local file = io.open(path, "r")
    return json.decode(file:read("*all"))
end

return skillTree
