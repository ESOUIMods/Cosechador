-----------------------------------------
--                                     --
--  Harvester based off of code        --
--  from Esohead by Zam Network        --
--                                     --
-----------------------------------------

Harvester = {}

-----------------------------------------
--           Core Functions            --
-----------------------------------------

function Harvester.Initialize()
    Harvester.savedVars = {}
    Harvester.debugDefault = 0
    Harvester.dataDefault = {
        data = {}
    }
    Harvester.name = ""
    Harvester.time = 0
    Harvester.isHarvesting = false
    Harvester.action = ""

    Harvester.currentConversation = {
        npcName = "",
        npcLevel = 0,
        x = 0,
        y = 0,
        subzone = ""
    }

    -- 22 meters            0.000029
    -- recorded node at     0.000014
    -- Min Distance         0.000010
    -- Old Value Harvester.maxDist = 0.00025 -- 0.005^2
    Harvester.minDefault = 0.000025 -- 0.005^2
    Harvester.minReticleover = 0.000049 -- 0.007^2
end

function Harvester.InitSavedVariables()
    Harvester.savedVars = {
        ["internal"]     = ZO_SavedVars:NewAccountWide("Harvester_SavedVariables", 1, "internal", { debug = Harvester.debugDefault, language = "" }),
        ["harvest"]      = ZO_SavedVars:NewAccountWide("Harvester_SavedVariables", 1, "harvest", Harvester.dataDefault),
        ["chest"]        = ZO_SavedVars:NewAccountWide("Harvester_SavedVariables", 1, "chest", Harvester.dataDefault),
        ["fish"]         = ZO_SavedVars:NewAccountWide("Harvester_SavedVariables", 1, "fish", Harvester.dataDefault),
    }

    if Harvester.savedVars["internal"].debug == 1 then
        Harvester.Debug("Harvester addon initialized. Debugging is enabled.")
    else
        Harvester.Debug("Harvester addon initialized. Debugging is disabled.")
    end
end

-- Logs saved variables
function Harvester.Log(type, nodes, ...)
    local data = {}
    local dataStr = ""
    local sv

    if Harvester.savedVars[type] == nil or Harvester.savedVars[type].data == nil then
        Harvester.Debug("Attempted to log unknown type: " .. type)
        return
    else
        sv = Harvester.savedVars[type].data
    end

    for i = 1, #nodes do
        local node = nodes[i];
        if string.find(node, '\"') then
            node = string.gsub(node, '\"', '\'')
        end

        if sv[node] == nil then
            sv[node] = {}
        end
        sv = sv[node]
    end

    for i = 1, select("#", ...) do
        local value = select(i, ...)
        data[i] = value
        dataStr = dataStr .. "[" .. tostring(value) .. "] "
    end

    if Harvester.savedVars["internal"].debug == 1 then
        Harvester.Debug("Harvester: Logged [" .. type .. "] data: " .. dataStr)
    end

    if #sv == 0 then
        sv[1] = data
    else
        sv[#sv+1] = data
    end
end

-- Checks if we already have an entry for the object/npc within a certain x/y distance
function Harvester.LogCheck(type, nodes, x, y, scale, name)
    local log
    local sv

    local distance
    if scale == nil then
        distance = Harvester.minDefault
    else
        distance = scale
    end

    if Harvester.savedVars[type] == nil or Harvester.savedVars[type].data == nil then
        return nil
    else
        sv = Harvester.savedVars[type].data
    end

    for i = 1, #nodes do
        local node = nodes[i];
        if string.find(node, '\"') then
            node = string.gsub(node, '\"', '\'')
        end

        if sv[node] == nil then
            sv[node] = {}
        end
        sv = sv[node]
    end

    --[[ d("sv " .. tostring(#sv)) ]]--
    for i = 1, #sv do
        local item = sv[i]

        dx = item[1] - x
        dy = item[2] - y
        -- (x - center_x)2 + (y - center_y)2 = r2, where center is the player
        dist = math.pow(dx, 2) + math.pow(dy, 2)
        --d(string.format("Distance %10.5f", distance))
        --d(string.format("Distance X %10.5f", math.abs(item[1] - x)))
        --d(string.format("Distance Y %10.5f", math.abs(item[2] - y)))
        if dx <= 0 and dy <= 0 then -- Dupe Node
            --[[ d("Dupe Node!") ]]--
            if name == nil then -- name is nil because it's not harvesting
                --[[
                if type == "harvest" then
                    d(item[4] .. " found, Name is nil")
                else
                    d(tostring(type) .. " found, Name is nil")
                end
                ]]--
                log = item
            else -- harvesting only
                if item[4] == name then
                    --[[
                    if type == "harvest" then
                        d(name .." is equal to node found " .. item[4])
                    else
                        d(tostring(type) .." is equal to node found " .. tostring(type))
                    end
                    ]]--
                    log = item
                    --[[
                else
                    if type == "harvest" then
                        d(name .." is NOT equal to node found " .. item[4].. ", logging node")
                    else
                        d(tostring(type) .." is NOT equal to node found " .. tostring(type).. ", logging node")
                    end
                    ]]--
                end
            end
        elseif dist < distance then
            --[[ d("Within area of the circle!") ]]--
            if name == nil then -- name is nil because it's not harvesting
                --[[
                if type == "harvest" then
                    d(item[4] .. " found, Name is nil")
                else
                    d(tostring(type) .. " found, Name is nil")
                end
                ]]--
                log = item
            else -- harvesting only
                if item[4] == name then
                    --[[
                    if type == "harvest" then
                        d(name .." is equal to node found " .. item[4])
                    else
                        d(tostring(type) .." is equal to node found " .. tostring(type))
                    end
                    ]]--
                    log = item
                    --[[
                else
                    if type == "harvest" then
                        d(name .." is NOT equal to node found " .. item[4].. ", logging node")
                    else
                        d(tostring(type) .." is NOT equal to node found " .. tostring(type).. ", logging node")
                    end
                    ]]--
                end
            end
        end
    end

    return log
end

-- formats a number with commas on thousands
function Harvester.NumberFormat(num)
    local formatted = num
    local k

    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then
            break
        end
    end

    return formatted
end

-- Listens for anything that is not event driven by the API but needs to be tracked
function Harvester.OnUpdate(time)
    if IsGameCameraUIModeActive() or IsUnitInCombat("player") then
        return
    end

    local type = GetInteractionType()
    local active = IsPlayerInteractingWithObject()
    local x, y, a, subzone, world = Harvester.GetUnitPosition("player")
    local targetType
    local action, name, interactionBlocked, additionalInfo, context = GetGameCameraInteractableActionInfo()

    local isHarvesting = ( active and (type == INTERACTION_HARVEST) )
    if not isHarvesting then
        if name then
            Harvester.name = name -- Harvester.name is the global current node
        end

        if Harvester.isHarvesting and time - Harvester.time > 1 then
            Harvester.isHarvesting = false
        end

        if action ~= Harvester.action then
            Harvester.action = action -- Harvester.action is the global current action

            -- Check Reticle and Non Harvest Actions
            -- Chest
            if type == INTERACTION_NONE and Harvester.action == GetString(SI_GAMECAMERAACTIONTYPE12) then
                targetType = "chest"

                data = Harvester.LogCheck(targetType, {subzone}, x, y, Harvester.minReticleover, nil)
                if not data then
                    Harvester.Log(targetType, {subzone}, x, y)
                end

            -- Fishing Nodes
            elseif Harvester.action == GetString(SI_GAMECAMERAACTIONTYPE16) then
                targetType = "fish"

                data = Harvester.LogCheck(targetType, {subzone}, x, y, Harvester.minReticleover, nil)
                if not data then
                    Harvester.Log(targetType, {subzone}, x, y)
                end

            end
        end
    else
        Harvester.isHarvesting = true
        Harvester.time = time

    end
end

-----------------------------------------
--         Coordinate System           --
-----------------------------------------

function Harvester.UpdateCoordinates()
    local mouseOverControl = WINDOW_MANAGER:GetMouseOverControl()

    if (mouseOverControl == ZO_WorldMapContainer or mouseOverControl:GetParent() == ZO_WorldMapContainer) then
        local currentOffsetX = ZO_WorldMapContainer:GetLeft()
        local currentOffsetY = ZO_WorldMapContainer:GetTop()
        local parentOffsetX = ZO_WorldMap:GetLeft()
        local parentOffsetY = ZO_WorldMap:GetTop()
        local mouseX, mouseY = GetUIMousePosition()
        local mapWidth, mapHeight = ZO_WorldMapContainer:GetDimensions()
        local parentWidth, parentHeight = ZO_WorldMap:GetDimensions()

        local normalizedX = math.floor((((mouseX - currentOffsetX) / mapWidth) * 100) + 0.5)
        local normalizedY = math.floor((((mouseY - currentOffsetY) / mapHeight) * 100) + 0.5)

        HarvesterCoordinates:SetAlpha(0.8)
        HarvesterCoordinates:SetDrawLayer(ZO_WorldMap:GetDrawLayer() + 1)
        HarvesterCoordinates:SetAnchor(TOPLEFT, nil, TOPLEFT, parentOffsetX + 0, parentOffsetY + parentHeight)
        HarvesterCoordinatesValue:SetText("Coordinates: " .. normalizedX .. ", " .. normalizedY)
    else
        HarvesterCoordinates:SetAlpha(0)
    end
end

-----------------------------------------
--            API Helpers              --
-----------------------------------------

function Harvester.GetUnitPosition(tag)
    local setMap = SetMapToPlayerLocation() -- Fix for bug #23
    if setMap == 2 then
        CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged") -- Fix for bug #23
    end

    local x, y, a = GetMapPlayerPosition(tag)
    local subzone = GetMapName()
    local world = GetUnitZone(tag)

    return x, y, a, subzone, world
end

function Harvester.GetUnitName(tag)
    return GetUnitName(tag)
end

function Harvester.GetUnitLevel(tag)
    return GetUnitLevel(tag)
end

function Harvester.GetLootEntry(index)
    return GetLootItemInfo(index)
end

-----------------------------------------
--           Debug Logger              --
-----------------------------------------

local function EmitMessage(text)
    if(CHAT_SYSTEM)
    then
        if(text == "")
        then
            text = "[Empty String]"
        end

        CHAT_SYSTEM:AddMessage(text)
    end
end

local function EmitTable(t, indent, tableHistory)
    indent          = indent or "."
    tableHistory    = tableHistory or {}

    for k, v in pairs(t)
    do
        local vType = type(v)

        EmitMessage(indent.."("..vType.."): "..tostring(k).." = "..tostring(v))

        if(vType == "table")
        then
            if(tableHistory[v])
            then
                EmitMessage(indent.."Avoiding cycle on table...")
            else
                tableHistory[v] = true
                EmitTable(v, indent.."  ", tableHistory)
            end
        end
    end
end

function Harvester.Debug(...)
    for i = 1, select("#", ...) do
        local value = select(i, ...)
        if(type(value) == "table")
        then
            EmitTable(value)
        else
            EmitMessage(tostring (value))
        end
    end
end

-----------------------------------------
--           Loot Tracking             --
-----------------------------------------

function Harvester.ItemLinkParse(link)

    local Field1, Field2, Field3, Field4, Field5 = ZO_LinkHandler_ParseLink( link )

    -- name = Field1
    -- unused = Field2
    -- type = Field3
    -- id = Field4
    -- quality = Field5

    return {
        type = Field3,
        id = tonumber(Field4),
        quality = tonumber(Field5),
        name = zo_strformat(SI_TOOLTIP_ITEM_NAME, Field1)
    }
end

function Harvester.OnLootReceived(eventCode, receivedBy, objectName, stackCount, soundCategory, lootType, lootedBySelf)
    if not IsGameCameraUIModeActive() then
        targetName = Harvester.name

        -- There is no provisioning now so if the player isn't harvesting
        -- then you don't need to do anything.
        if not Harvester.isHarvesting then
            return
        end

        -- if not Harvester.IsValidNode(targetName) then
        --     return
        -- end

        local link = Harvester.ItemLinkParse(objectName)
        local material = Harvester.GetTradeskillByMaterial(link.id)
        local x, y, a, subzone, world = Harvester.GetUnitPosition("player")

        --[[
        if not Harvester.isHarvesting and material >= 1 then
            material = 5
        elseif Harvester.isHarvesting and material == 5 then
            material = 0
        end
        ]]--

        if material == 0 then
            return
        end

        --[[
        if material == 5 then
            data = Harvester.LogCheck("provisioning", {subzone, material, link.id}, x, y, nil, nil)
            if not data then -- when there is no node at the given location, save a new entry
                Harvester.Log("provisioning", {subzone, material, link.id}, x, y, stackCount, targetName)
        else
        ]]--
            data = Harvester.LogCheck("harvest", {subzone, material}, x, y, nil, targetName)
            if not data then -- when there is no node at the given location, save a new entry
                Harvester.Log("harvest", {subzone, material}, x, y, stackCount, targetName, link.id)
            --[[
            else -- when there is an existing node of a different type, save a new entry
                if not Harvester.IsDupeHarvestNode(subzone, material, data[1], data[2], data[3], data[4], data[5]) then
                    Harvester.Log("harvest", {subzone, material}, x, y, stackCount, targetName, link.id)
                end
            ]]--
            end
   --[[ end ]]--
    end
end

-----------------------------------------
--         HarvestMap Routines         --
-----------------------------------------
-- "chest", "fish", "harvest",

function Harvester.newMapNameFishChest(type, newMapName, x, y)
    -- 1) type 2) map name 3) x 4) y 5) profession 6) nodeName 7) itemID 8) scale
        if type == "fish" then
            data = Harvester.LogCheck("fish", {newMapName}, x, y, Harvester.minReticleover, nil)
            if not data then
                Harvester.Log("fish", {newMapName}, x, y)
            end
        elseif type == "chest" then
            data = Harvester.LogCheck("chest", {newMapName}, x, y, Harvester.minReticleover, nil)
            if not data then
                Harvester.Log("chest", {newMapName}, x, y)
            end
        else
            d("unsupported type : " .. type)
        end
end
function Harvester.oldMapNameFishChest(type, oldMapName, x, y)
    -- 1) type 2) map name 3) x 4) y 5) profession 6) nodeName 7) itemID 8) scale
    if type == Harvester.fishID then
            data = Harvester.LogCheck("fish", {oldMapName}, x, y, Harvester.minReticleover, nil)
            if not data then
                Harvester.Log("fish", {oldMapName}, x, y)
            end
    elseif type == Harvester.chestID then
            data = Harvester.LogCheck("chest", {oldMapName}, x, y, Harvester.minReticleover, nil)
            if not data then
                Harvester.Log("chest", {oldMapName}, x, y)
            end
    else
        d("unsupported type : " .. type)
    end
end

function Harvester.newMapNilItemIDHarvest(newMapName, x, y, profession, nodeName)
    local material = Harvester.GetTradeskillByMaterial(itemID)
    local stackCount = math.random(1,4)

    -- 1) type 2) map name 3) x 4) y 5) profession 6) nodeName 7) itemID 8) scale
    if not Harvester.IsValidContainerOnImport(nodeName) then
        data = Harvester.LogCheck("harvest", {newMapName, material}, x, y, nil, nodeName)
        if not data then -- when there is no node at the given location, save a new entry
            Harvester.Log("harvest", {newMapName, material}, x, y, stackCount, nodeName, itemID)
        end
    else        data = Harvester.LogCheck("harvest", {newMapName, material}, x, y, nil, nodeName)
        if not data then -- when there is no node at the given location, save a new entry
            Harvester.Log("harvest", {newMapName, material}, x, y, stackCount, nodeName, itemID)
        end
    end
end

-- "harvest", "chest", "fish", "mapinvalid"
-- "esoharvest", "esochest", "esofish", "esoinvalid"

function Harvester.oldMapNilItemIDHarvest(oldMapName, x, y, profession, nodeName)
    local material = Harvester.GetTradeskillByMaterial(itemID)
    local stackCount = math.random(1,4)

    -- 1) type 2) map name 3) x 4) y 5) profession 6) nodeName 7) itemID 8) scale
    if not Harvester.IsValidContainerOnImport(nodeName) then
        data = Harvester.LogCheck("harvest", {oldMapName, material}, x, y, nil, nodeName)
        if not data then -- when there is no node at the given location, save a new entry
            Harvester.Log("harvest", {oldMapName, material}, x, y, stackCount, nodeName, itemID)
        end
    else
        data = Harvester.LogCheck("harvest", {oldMapName, material}, x, y, nil, nodeName)
        if not data then -- when there is no node at the given location, save a new entry
            Harvester.Log("harvest", {oldMapName, material}, x, y, stackCount, nodeName, itemID)
        end
    end
end

function Harvester.newMapItemIDHarvest(newMapName, x, y, profession, nodeName, itemID)
    local material = Harvester.GetTradeskillByMaterial(itemID)
    local stackCount = math.random(1,4)

    -- 1) type 2) map name 3) x 4) y 5) profession 6) nodeName 7) itemID 8) scale
    if not Harvester.IsValidContainerOnImport(nodeName) then -- returns true or false
        data = Harvester.LogCheck("harvest", {newMapName, material}, x, y, nil, nodeName)
        if not data then -- when there is no node at the given location, save a new entry
            Harvester.Log("harvest", {newMapName, material}, x, y, stackCount, nodeName, itemID)
        end
    else
        data = Harvester.LogCheck("harvest", {newMapName, material}, x, y, nil, nodeName)
        if not data then -- when there is no node at the given location, save a new entry
            Harvester.Log("harvest", {newMapName, material}, x, y, stackCount, nodeName, itemID)
        end
    end
end

function Harvester.oldMapItemIDHarvest(oldMapName, x, y, profession, nodeName, itemID)
    local material = Harvester.GetTradeskillByMaterial(link.id)
    local stackCount = math.random(1,4)

    -- 1) type 2) map name 3) x 4) y 5) profession 6) nodeName 7) itemID 8) scale
    if not Harvester.IsValidContainerOnImport(nodeName) then -- returns true or false
        data = Harvester.LogCheck("harvest", {oldMapName, material}, x, y, nil, nodeName)
        if not data then -- when there is no node at the given location, save a new entry
            Harvester.Log("harvest", {oldMapName, material}, x, y, stackCount, nodeName, itemID)
        end
    else
        data = Harvester.LogCheck("harvest", {oldMapName, material}, x, y, nil, nodeName)
        if not data then -- when there is no node at the given location, save a new entry
            Harvester.Log("harvest", {oldMapName, material}, x, y, stackCount, nodeName, itemID)
        end
    end
end

function Harvester.GetMap()
    local textureName = GetMapTileTexture()
    textureName = string.lower(textureName)
    textureName = string.gsub(textureName, "^.*maps/", "")
    textureName = string.gsub(textureName, "_%d+%.dds$", "")

    local mapType = GetMapType()
    local mapContentType = GetMapContentType()
    if (mapType == MAPTYPE_SUBZONE) or (mapContentType == MAP_CONTENT_DUNGEON) then
        Harvester.minDist = 0.00005  -- Larger value for minDist since map is smaller
    elseif (mapContentType == MAP_CONTENT_AVA) then
        Harvester.minDist = 0.00001 -- Smaller value for minDist since map is larger
    else
        Harvester.minDist = 0.000025 -- This is the default value for minDist
    end

    return textureName
end

function Harvester.saveData(type, zone, x, y, profession, nodeName, itemID, scale )

    if not profession then
        return
    end

    if Harvester.savedVars[type] == nil or Harvester.savedVars[type].data == nil then
        d("Attempted to log unknown type: " .. type)
        return
    end

    if Harvester.alreadyFound(type, zone, x, y, profession, nodeName, scale ) then
        return
    end

    -- If this check is not here the next routine will fail
    -- after the loading screen because for a brief moment
    -- the information is not available.
    if Harvester.savedVars[type] == nil then
        return
    end

    if not Harvester.savedVars[type].data[zone] then
        Harvester.savedVars[type].data[zone] = {}
    end

    if not Harvester.savedVars[type].data[zone][profession] then
        Harvester.savedVars[type].data[zone][profession] = {}
    end

    if Harvester.savedVars["internal"].debug == 1 then
        d("Save data!")
    end

    table.insert( Harvester.savedVars[type].data[zone][profession], { x, y, { nodeName }, itemID } )

end

function Harvester.contains(table, value)
    for key, v in pairs(table) do
        if v == value then
            return key
        end
    end
    return nil
end

function Harvester.alreadyFound(type, zone, x, y, profession, nodeName, scale )

    -- If this check is not here the next routine will fail
    -- after the loading screen because for a brief moment
    -- the information is not available.
    if Harvester.savedVars[type] == nil then
        return
    end

    if not Harvester.savedVars[type].data[zone] then
        return false
    end

    if not Harvester.savedVars[type].data[zone][profession] then
        return false
    end

    local distance
    if scale == nil then
        distance = Harvester.minDefault
    else
        distance = scale
    end

    for _, entry in pairs( Harvester.savedVars[type].data[zone][profession] ) do
        --if entry[3] == nodeName then
            dx = entry[1] - x
            dy = entry[2] - y
            -- (x - center_x)2 + (y - center_y)2 = r2, where center is the player
            dist = math.pow(dx, 2) + math.pow(dy, 2)
            if dist < distance then
                if profession > 0 then
                    if not Harvester.contains(entry[3], nodeName) then
                        table.insert(entry[3], nodeName)
                    end
                    if Harvester.savedVars["internal"].debug == 1 then
                        d("Node : " .. nodeName .. " on : " .. zone .. " x:" .. x .." , y:" .. y .. " for profession " .. profession .. " already found!")
                    end
                    return true
                else
                    if entry[3][1] == nodeName then
                        if Harvester.savedVars["internal"].debug == 1 then
                            d("Node : " .. nodeName .. " on : " .. zone .. " x:" .. x .." , y:" .. y .. " for profession " .. profession .. " already found!")
                        end
                        return true
                    end
                end
            end
        --end
        end
    if Harvester.savedVars["internal"].debug == 1 then
        d("Node : " .. nodeName .. " on : " .. zone .. " x:" .. x .." , y:" .. y .. " for profession " .. profession .. " not found!")
    end
    return false
end

-----------------------------------------
--           Merge Nodes               --
-----------------------------------------
function Harvester.importFromEsoheadMerge()
    if not EHM then
        d("Please enable the EsoheadMerge addon to import data!")
        return
    end

    Harvester.Debug("Harvester Starting Import from EsoheadMerge")
    for category, data in pairs(EHM.savedVars) do
        if category ~= "internal" and (category == "chest" or category == "fish") then
            for map, location in pairs(data.data) do
                -- Harvester.Debug(category .. map)
                for v1, node in pairs(location) do
                    -- Harvester.Debug(node[1] .. node[2])
                    dupeNode = Harvester.LogCheck(category, { map }, node[1], node[2], Harvester.minReticleover, nil)
                    if not dupeNode then
                        Harvester.Log(category, { map }, node[1], node[2])
                    end
                end
            end
        elseif category ~= "internal" and category == "harvest" then
            for map, location in pairs(data.data) do
                -- Harvester.Debug(category .. map)
                for profession, nodes in pairs(location) do
                    for v1, node in pairs(nodes) do
                        dupeNode = Harvester.LogCheck(category, {map, profession}, node[1], node[2], nil, node[4])
                        if not dupeNode then
                            Harvester.Log(category, {map, profession}, node[1], node[2], node[3], node[4], node[5])
                        end
                    end
                end
            end
        end
    end
    Harvester.Debug("Import Complete")
end

function Harvester.importFromEsohead()
    if not EH then
        d("Please enable the Esohead addon to import data!")
        return
    end

    Harvester.Debug("Harvester Starting Import from Esohead")
    for category, data in pairs(EH.savedVars) do
        if category ~= "internal" and (category == "chest" or category == "fish") then
            for map, location in pairs(data.data) do
                -- Harvester.Debug(category .. map)
                for v1, node in pairs(location) do
                    -- Harvester.Debug(node[1] .. node[2])
                    dupeNode = Harvester.LogCheck(category, { map }, node[1], node[2], Harvester.minReticleover, nil)
                    if not dupeNode then
                        Harvester.Log(category, { map }, node[1], node[2])
                    end
                end
            end
        elseif category ~= "internal" and category == "harvest" then
            for map, location in pairs(data.data) do
                -- Harvester.Debug(category .. map)
                for profession, nodes in pairs(location) do
                    for v1, node in pairs(nodes) do
                        dupeNode = Harvester.LogCheck(category, {map, profession}, node[1], node[2], nil, node[4])
                        if not dupeNode then
                            Harvester.Log(category, {map, profession}, node[1], node[2], node[3], node[4], node[5])
                        end
                    end
                end
            end
        end
    end
    Harvester.Debug("Import Complete")
end

function Harvester.importFromHarvestMap()
    Harvester.NumbersNodesAdded = 0
    Harvester.NumFalseNodes = 0
    Harvester.NumContainerSkipped = 0
    Harvester.NumbersNodesFiltered = 0
    Harvester.NumNodesProcessed = 0
    Harvester.NumUnlocalizedFalseNodes = 0
    Harvester.NumbersUnlocalizedNodesAdded = 0

    if not Harvest then
        d("Please enable the HarvestMap addon to import data!")
        return
    end

    d("import data from HarvestMap")
    for newMapName, data in pairs(Harvest.savedVars["nodes"].data) do
        for profession, nodes in pairs(data) do
            for index, node in pairs(nodes) do
                for contents, nodeName in ipairs(node[3]) do
                    Harvester.NumNodesProcessed = Harvester.NumNodesProcessed + 1

                        if (nodeName) == "chest" or (nodeName) == "fish" then
                            Harvester.newMapNameFishChest(nodeName, newMapName, node[1], node[2])
                        else
                            -- if node[4] == nil then it can't be nill
                            if node[4] ~= nil then
                            --    Harvester.newMapNilItemIDHarvest(newMapName, node[1], node[2], profession, nodeName)
                            --else -- node[4] which is the ItemID should not be nil at this point
                                Harvester.newMapItemIDHarvest(newMapName, node[1], node[2], profession, nodeName, node[4])
                            end
                        end

                end
            end
        end
    end

    d("Number of nodes processed : " .. tostring(Harvester.NumNodesProcessed) )
    d("Number of nodes added : " .. tostring(Harvester.NumbersNodesAdded) )
    d("Number of Containers skipped : " .. tostring(Harvester.NumContainerSkipped) )
    d("Number of False Nodes skipped : " .. tostring(Harvester.NumFalseNodes) )
    d("Finished.")
end

function Harvester.importFromHarvestMerge()
    Harvester.NumbersNodesAdded = 0
    Harvester.NumFalseNodes = 0
    Harvester.NumContainerSkipped = 0
    Harvester.NumbersNodesFiltered = 0
    Harvester.NumNodesProcessed = 0
    Harvester.NumUnlocalizedFalseNodes = 0
    Harvester.NumbersUnlocalizedNodesAdded = 0

    if not HarvestMerge then
        d("Please enable the HarvestMap addon to import data!")
        return
    end

    d("import data from HarvestMap")
    for newMapName, data in pairs(HarvestMerge.savedVars["nodes"].data) do
        for profession, nodes in pairs(data) do
            for index, node in pairs(nodes) do
                for contents, nodeName in ipairs(node[3]) do
                    Harvester.NumNodesProcessed = Harvester.NumNodesProcessed + 1

                        if (nodeName) == "chest" or (nodeName) == "fish" then
                            Harvester.newMapNameFishChest(nodeName, newMapName, node[1], node[2])
                        else
                            -- if node[4] == nil then it can't be nill
                            if node[4] ~= nil then
                            --    Harvester.newMapNilItemIDHarvest(newMapName, node[1], node[2], profession, nodeName)
                            --else -- node[4] which is the ItemID should not be nil at this point
                                Harvester.newMapItemIDHarvest(newMapName, node[1], node[2], profession, nodeName, node[4])
                            end
                        end

                end
            end
        end
    end

    d("Number of nodes processed : " .. tostring(Harvester.NumNodesProcessed) )
    d("Number of nodes added : " .. tostring(Harvester.NumbersNodesAdded) )
    d("Number of Containers skipped : " .. tostring(Harvester.NumContainerSkipped) )
    d("Number of False Nodes skipped : " .. tostring(Harvester.NumFalseNodes) )
    d("Finished.")
end

-----------------------------------------
--           Slash Command             --
-----------------------------------------

Harvester.validCategories = {
    "chest",
    "fish",
    "harvest",
}

function Harvester.IsValidCategory(name)
    for k, v in pairs(Harvester.validCategories) do
        if string.lower(v) == string.lower(name) then
            return true
        end
    end

    return false
end

SLASH_COMMANDS["/harvester"] = function (cmd)
    local commands = {}
    local index = 1
    for i in string.gmatch(cmd, "%S+") do
        if (i ~= nil and i ~= "") then
            commands[index] = i
            index = index + 1
        end
    end

    if #commands == 0 then
        return Harvester.Debug("Please enter a valid Harvester command")
    end

    if #commands == 2 and commands[1] == "debug" then
        if commands[2] == "on" then
            Harvester.Debug("Harvester debugger toggled on")
            Harvester.savedVars["internal"].debug = 1
        elseif commands[2] == "off" then
            Harvester.Debug("Harvester debugger toggled off")
            Harvester.savedVars["internal"].debug = 0
        end

    elseif #commands == 2 and commands[1] == "import" then
        if commands[2] == "esohead" then
            Harvester.importFromEsohead()
        elseif commands[2] == "esomerge" then
            Harvester.importFromEsoheadMerge()
        -- elseif commands[2] == "harvest" then
        --     Harvester.importFromHarvestMap()
        -- elseif commands[2] == "merger" then
        --     Harvester.importFromHarvestMerge()
        end

    elseif commands[1] == "reset" then
        if #commands ~= 2 then
            for type,sv in pairs(Harvester.savedVars) do
                if type ~= "internal" then
                    Harvester.savedVars[type].data = {}
                end
            end
            Harvester.Debug("Harvester saved data has been completely reset")
        else
            if commands[2] ~= "internal" then
                if Harvester.IsValidCategory(commands[2]) then
                    Harvester.savedVars[commands[2]].data = {}
                    Harvester.Debug("Harvester saved data : " .. commands[2] .. " has been reset")
                else
                    return Harvester.Debug("Please enter a valid Harvester category to reset")
                end
            end
        end

    elseif commands[1] == "datalog" then
        Harvester.Debug("---")
        Harvester.Debug("Complete list of gathered data:")
        Harvester.Debug("---")

        local counter = {
            ["harvest"] = 0,
            ["chest"] = 0,
            ["fish"] = 0,
        }

        for type,sv in pairs(Harvester.savedVars) do
            if type ~= "internal" and (type == "chest" or type == "fish") then
                for zone, t1 in pairs(Harvester.savedVars[type].data) do
                    counter[type] = counter[type] + #Harvester.savedVars[type].data[zone]
                end
            elseif type ~= "internal" then
                for zone, t1 in pairs(Harvester.savedVars[type].data) do
                    for data, t2 in pairs(Harvester.savedVars[type].data[zone]) do
                        counter[type] = counter[type] + #Harvester.savedVars[type].data[zone][data]
                    end
                end
            end
        end

        Harvester.Debug("Harvest: "          .. Harvester.NumberFormat(counter["harvest"]))
        Harvester.Debug("Treasure Chests: "  .. Harvester.NumberFormat(counter["chest"]))
        Harvester.Debug("Fishing Pools: "    .. Harvester.NumberFormat(counter["fish"]))

        Harvester.Debug("---")
    end
end

SLASH_COMMANDS["/rl"] = function()
    ReloadUI("ingame")
end

SLASH_COMMANDS["/reload"] = function()
    ReloadUI("ingame")
end

-----------------------------------------
--        Addon Initialization         --
-----------------------------------------

function Harvester.OnLoad(eventCode, addOnName)
    if addOnName ~= "Harvester" then
        return
    end

    Harvester.language = (GetCVar("language.2") or "en")
    Harvester.InitSavedVariables()
    Harvester.savedVars["internal"]["language"] = Harvester.language

    EVENT_MANAGER:RegisterForEvent("Harvester", EVENT_LOOT_RECEIVED, Harvester.OnLootReceived)
end

EVENT_MANAGER:RegisterForEvent("Harvester", EVENT_ADD_ON_LOADED, function (eventCode, addOnName)
    if addOnName == "Harvester" then
        Harvester.Initialize()
        Harvester.OnLoad(eventCode, addOnName)
    end
end)
