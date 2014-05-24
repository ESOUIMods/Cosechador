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
        Harvester.Debug("COS: Logged [" .. type .. "] data: " .. dataStr)
    end

    if #sv == 0 then
        sv[1] = data
    else
        sv[#sv+1] = data
    end
end

-- Checks if we already have an entry for the object/npc within a certain x/y distance
function Harvester.LogCheck(type, nodes, x, y, scale)
    local log = nil
    local sv

    local distance
    if scale == nil then
        distance = 0.005
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

        if math.abs(item[1] - x) < distance and math.abs(item[2] - y) < distance then
            log = item
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
            -- Skyshard
            if type == INTERACTION_NONE and Harvester.action == GetString(SI_GAMECAMERAACTIONTYPE5) then
                targetType = "skyshard"

                if Harvester.name == "Skyshard" then
                    data = Harvester.LogCheck(targetType, {subzone}, x, y, nil)
                    if not data then
                        Harvester.Log(targetType, {subzone}, x, y)
                    end
                end

            -- Chest
            elseif type == INTERACTION_NONE and Harvester.action == GetString(SI_GAMECAMERAACTIONTYPE12) then
                targetType = "chest"

                data = Harvester.LogCheck(targetType, {subzone}, x, y, 0.05)
                if not data then
                    Harvester.Log(targetType, {subzone}, x, y)
                end

            -- Fishing Nodes
            elseif Harvester.action == GetString(SI_GAMECAMERAACTIONTYPE16) then
                targetType = "fish"

                data = Harvester.LogCheck(targetType, {subzone}, x, y, 0.05)
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

function Harvester.IsDupeHarvestNode(map, profession, locX, locY, stackCount, nodeName, ItemID)
    local nodes = Harvester.savedVars["harvest"]["data"][map][profession]
    for _, node in pairs(nodes) do
        if (node[1] == locX) and (node[2] == locY) and (node[4] == nodeName) then
            return true
        end
    end
    
    return false
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
            data = Harvester.LogCheck("provisioning", {subzone, material, link.id}, x, y, nil)
            if not data then -- when there is no node at the given location, save a new entry
                Harvester.Log("provisioning", {subzone, material, link.id}, x, y, stackCount, targetName)
        else
        ]]--
            data = Harvester.LogCheck("harvest", {subzone, material}, x, y, nil)
            if not data then -- when there is no node at the given location, save a new entry
                Harvester.Log("harvest", {subzone, material}, x, y, stackCount, targetName, link.id)
            else -- when there is an existing node of a different type, save a new entry
                if not Harvester.IsDupeHarvestNode(subzone, material, x, y, stackCount, targetName, link.id) then
                    Harvester.Log("harvest", {subzone, material}, x, y, stackCount, targetName, link.id)
                end
            end
   --[[ end ]]--
    end
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

SLASH_COMMANDS["/harvest"] = function (cmd)
    local commands = {}
    local index = 1
    for i in string.gmatch(cmd, "%S+") do
        if (i ~= nil and i ~= "") then
            commands[index] = i
            index = index + 1
        end
    end

    if #commands == 0 then
        return Harvester.Debug("Please enter a valid command")
    end

    if #commands == 2 and commands[1] == "debug" then
        if commands[2] == "on" then
            Harvester.Debug("Esohead debugger toggled on")
            Harvester.savedVars["internal"].debug = 1
        elseif commands[2] == "off" then
            Harvester.Debug("Esohead debugger toggled off")
            Harvester.savedVars["internal"].debug = 0
        end

    elseif commands[1] == "reset" then
        if #commands ~= 2 then 
            for type,sv in pairs(Harvester.savedVars) do
                if type ~= "internal" then
                    Harvester.savedVars[type].data = {}
                end
            end
            Harvester.Debug("Saved data has been completely reset")
        else
            if commands[2] ~= "internal" then
                if Harvester.IsValidCategory(commands[2]) then
                    Harvester.savedVars[commands[2]].data = {}
                    Harvester.Debug("Saved data : " .. commands[2] .. " has been reset")
                else
                    return Harvester.Debug("Please enter a valid category to reset")
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