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
    Harvester.langs = { "en", "de", "fr", }

    Harvester.minDefault = 0.000025 -- 0.005^2
    Harvester.minReticleover = 0.000049 -- 0.007^2
end

function Harvester.InitSavedVariables()
    Harvester.savedVars = {
        ["internal"]     = ZO_SavedVars:NewAccountWide("Harvester_SavedVariables", 1, "internal", { debug = Harvester.debugDefault, language = "" }),
        ["harvest"]      = ZO_SavedVars:NewAccountWide("Harvester_SavedVariables", 1, "harvest", Harvester.dataDefault),
        ["chest"]        = ZO_SavedVars:NewAccountWide("Harvester_SavedVariables", 1, "chest", Harvester.dataDefault),
        ["fish"]         = ZO_SavedVars:NewAccountWide("Harvester_SavedVariables", 1, "fish", Harvester.dataDefault),
        ["mapnames"]     = ZO_SavedVars:NewAccountWide("Harvester_SavedVariables", 1, "mapnames", Harvester.dataDefault),
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
    local log = true
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

    for i = 1, #sv do
        local item = sv[i]

        dx = item[1] - x
        dy = item[2] - y
        -- (x - center_x)2 + (y - center_y)2 = r2, where center is the player
        dist = math.pow(dx, 2) + math.pow(dy, 2)
        -- both ensure that the entire table isn't parsed
        if dist < distance then -- near player location
            if name == nil then -- npc, quest, vendor all but harvesting
                return false
            else -- harvesting only
                if item[4] == name then
                    return false
                elseif item[4] ~= name then
                    return true
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
    local x, y, a, world, subzone, playerLocation, textureName = Harvester.GetUnitPosition("player")
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

        if textureName ~= Harvester.lastMap then
            --d("Map Name : " .. textureName)
            Harvester.saveMapName(textureName, world, subzone, playerLocation)
            Harvester.lastMap = textureName
        end

        if action ~= Harvester.action then
            Harvester.action = action -- Harvester.action is the global current action

            -- Check Reticle and Non Harvest Actions
            -- Chest
            if type == INTERACTION_NONE and Harvester.action == GetString(SI_GAMECAMERAACTIONTYPE12) then
                targetType = "chest"

                Harvester.recordData(targetType, textureName, nil, x, y, "chest", nil )

            -- Fishing Nodes
            elseif Harvester.action == GetString(SI_GAMECAMERAACTIONTYPE16) then
                targetType = "fish"

                Harvester.recordData(targetType, textureName, nil, x, y, "chest", nil )
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

function Harvester.saveMapName(textureName, world, subzone, location)

    local savemapdata = true

    if Harvester.savedVars["mapnames"] == nil then
        Harvester.savedVars["mapnames"] = {}
    end

    if Harvester.savedVars["mapnames"].data == nil then
        Harvester.savedVars["mapnames"].data = {}
    end

    data = { world, subzone, location }
    for index, maps in pairs(Harvester.savedVars["mapnames"].data) do
        for _, map in pairs(maps) do
            if textureName == index then
                savemapdata = false
            end
            for i = 1, 3 do
                if textureName == index and (data[i] ~= map[i]) then
                    savemapdata = true
                end
            end
        end
    end

    if savemapdata then
        if Harvester.savedVars["mapnames"].data[textureName] == nil then
            Harvester.savedVars["mapnames"].data[textureName] = {}

            if Harvester.savedVars["mapnames"].data[textureName] then
                --d("It was not here")
                table.insert( Harvester.savedVars["mapnames"].data[textureName], data )
            end
        end
    end
end

function Harvester.GetUnitPosition(tag)
    local setMap = SetMapToPlayerLocation() -- Fix for bug #23
    if setMap == 2 then
        CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged") -- Fix for bug #23
    end

    local x, y, a = GetMapPlayerPosition(tag)
    local subzone = GetMapName()
    local world = GetUnitZone(tag)
    local textureName = GetMapTileTexture()
    textureName = string.lower(textureName)
    textureName = string.gsub(textureName, "^.*maps/", "")
    textureName = string.gsub(textureName, "_%d+%.dds$", "")
    
    local playerLocation = GetPlayerLocationName()
    local location
    location = string.lower(playerLocation)
    location = string.gsub(location, "%s", "")
    location = string.gsub(location, "\'", "")
    textureName = textureName .. "/" .. location
    
    return x, y, a, world, subzone, playerLocation, textureName
end

function Harvester.contains(table, value)
    for key, v in pairs(table) do
        if v == value then
            return key
        end
    end
    return nil
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

function Harvester.recordData(dataType, map, material, x, y, nodeName, itemId )
    local world, subzone, location = select(3,map:find("([%w%-]+)/([%w%-]+_[%w%-]+)/([%w%-]+)"))
    local blackListMap = world .. "\/" .. subzone
    d(blackListMap)
    if Harvester.blacklistMap(map) then
        return
    end

    if (dataType == "chest" or dataType == "fish") then
        if Harvester.LogCheck(dataType, { world, subzone, location }, x, y, Harvester.minReticleover, nil) then
            Harvester.Log(dataType, { world, subzone, location }, x, y)
        end
    else
        if Harvester.LogCheck(dataType, { world, subzone, location, material}, x, y, nil, nodeName) then
            Harvester.Log(dataType, { world, subzone, location, material}, x, y, nodeName, itemId)
        end
    end
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
        local x, y, a, world, subzone, playerLocation, textureName = Harvester.GetUnitPosition("player")

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
            if Harvester.LogCheck("provisioning", {subzone, material, link.id}, x, y, nil, nil) then
                Harvester.Log("provisioning", {subzone, material, link.id}, x, y, stackCount, targetName)
        else
        ]]--
        Harvester.recordData("harvest", textureName, material, x, y, targetName, link.id )
            --[[
            if Harvester.LogCheck("harvest", {subzone, material}, x, y, nil, targetName) then
                Harvester.Log("harvest", {subzone, material}, x, y, stackCount, targetName, link.id)
            else -- when there is an existing node of a different type, save a new entry
                if not Harvester.IsDupeHarvestNode(subzone, material, data[1], data[2], data[3], data[4], data[5]) then
                    Harvester.Log("harvest", {subzone, material}, x, y, stackCount, targetName, link.id)
                end
            end
            ]]--
   --[[ end ]]--
    end
end

-----------------------------------------
--           Merge Nodes               --
-----------------------------------------
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
                    if Harvester.LogCheck(category, { map }, node[1], node[2], Harvester.minReticleover, nil) then
                        Harvester.Log(category, { map }, node[1], node[2])
                    end
                end
            end
        elseif category ~= "internal" and category == "harvest" then
            for map, location in pairs(data.data) do
                -- Harvester.Debug(category .. map)
                for profession, nodes in pairs(location) do
                    for v1, node in pairs(nodes) do
                        if Harvester.LogCheck(category, {map, profession}, node[1], node[2], nil, node[4]) then
                            Harvester.Log(category, {map, profession}, node[1], node[2], node[3], node[4], node[5])
                        end
                    end
                end
            end
        end
    end
    Harvester.Debug("Import Complete")
end

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
                    if Harvester.LogCheck(category, { map }, node[1], node[2], Harvester.minReticleover, nil) then
                        Harvester.Log(category, { map }, node[1], node[2])
                    end
                end
            end
        elseif category ~= "internal" and category == "harvest" then
            for map, location in pairs(data.data) do
                -- Harvester.Debug(category .. map)
                for profession, nodes in pairs(location) do
                    for v1, node in pairs(nodes) do
                        if Harvester.LogCheck(category, {map, profession}, node[1], node[2], nil, node[4]) then
                            Harvester.Log(category, {map, profession}, node[1], node[2], node[3], node[4], node[5])
                        end
                    end
                end
            end
        end
    end
    Harvester.Debug("Import Complete")
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
        -- if commands[2] == "esohead" then
        --     Harvester.importFromEsohead()
        -- elseif commands[2] == "esomerge" then
        --     Harvester.importFromEsoheadMerge()
        -- end

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