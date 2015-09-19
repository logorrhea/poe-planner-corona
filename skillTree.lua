local skillTree = {}

-- Corona libs
local json = require("json")

-- Creates the organized tree from JSON data downloaded from pathofexile.com
function skillTree.BuildFromData(dataString)
    -- Parse json data string
    local data = json.decode(dataString)

    -- Create skill tree from parsed data
    local tree = {}

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
        node.orbit = n.o
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
