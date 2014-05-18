-----------------------------------------
-- Cosechador is based off of Esohead  --
-----------------------------------------

COS = {}

-----------------------------------------
--           Core Functions            --
-----------------------------------------

function COS.Initialize()
    COS.savedVars = {}
    COS.debugDefault = 0
    COS.dataDefault = {
        data = {}
    }
    COS.name = ""
    COS.time = 0
    COS.isHarvesting = false
    COS.action = ""

COS.currentConversation = {
    npcName = "",
    npcLevel = 0,
    x = 0,
    y = 0,
    subzone = ""
}
end

function COS.InitSavedVariables()
    COS.savedVars = {
        ["internal"]     = ZO_SavedVars:NewAccountWide("Cosechador_SavedVariables", 1, "internal", { debug = COS.debugDefault, language = "" }),
        ["skyshard"]     = ZO_SavedVars:NewAccountWide("Cosechador_SavedVariables", 2, "skyshard", COS.dataDefault),
        ["book"]         = ZO_SavedVars:NewAccountWide("Cosechador_SavedVariables", 2, "book", COS.dataDefault),
        ["harvest"]      = ZO_SavedVars:NewAccountWide("Cosechador_SavedVariables", 5, "harvest", COS.dataDefault),
        ["provisioning"] = ZO_SavedVars:NewAccountWide("Cosechador_SavedVariables", 5, "provisioning", COS.dataDefault),
        ["chest"]        = ZO_SavedVars:NewAccountWide("Cosechador_SavedVariables", 2, "chest", COS.dataDefault),
        ["fish"]         = ZO_SavedVars:NewAccountWide("Cosechador_SavedVariables", 2, "fish", COS.dataDefault),
        ["npc"]          = ZO_SavedVars:NewAccountWide("Cosechador_SavedVariables", 2, "npc", COS.dataDefault),
        ["vendor"]       = ZO_SavedVars:NewAccountWide("Cosechador_SavedVariables", 2, "vendor", COS.dataDefault),
        ["quest"]        = ZO_SavedVars:NewAccountWide("Cosechador_SavedVariables", 2, "quest", COS.dataDefault),
    }

    if COS.savedVars["internal"].debug == 1 then
        COS.Debug("Cosechador addon initialized. Debugging is enabled.")
    else
        COS.Debug("Cosechador addon initialized. Debugging is disabled.")
    end
end

-- Logs saved variables
function COS.Log(type, nodes, ...)
    local data = {}
    local dataStr = ""
    local sv

    if COS.savedVars[type] == nil or COS.savedVars[type].data == nil then
        COS.Debug("Attempted to log unknown type: " .. type)
        return
    else
        sv = COS.savedVars[type].data
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

    if COS.savedVars["internal"].debug == 1 then
        COS.Debug("COS: Logged [" .. type .. "] data: " .. dataStr)
    end

    if #sv == 0 then
        sv[1] = data
    else
        sv[#sv+1] = data
    end
end

-- Checks if we already have an entry for the object/npc within a certain x/y distance
function COS.LogCheck(type, nodes, x, y, scale)
    local log = nil
    local sv

    local distance
    if scale == nil then
        distance = 0.005
    else
        distance = scale
    end

    if COS.savedVars[type] == nil or COS.savedVars[type].data == nil then
        return nil
    else
        sv = COS.savedVars[type].data
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
function COS.NumberFormat(num)
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
function COS.OnUpdate(time)
    if IsGameCameraUIModeActive() or IsUnitInCombat("player") then
        return
    end

    local type = GetInteractionType()
    local active = IsPlayerInteractingWithObject()
    local x, y, a, subzone, world = COS.GetUnitPosition("player")
    local targetType
    local action, name, interactionBlocked, additionalInfo, context = GetGameCameraInteractableActionInfo()

    local isHarvesting = ( active and (type == INTERACTION_HARVEST) )
    if not isHarvesting then
        -- d("I am NOT busy! Time : " .. time)
        if name then
            COS.name = name -- COS.name is the global current node
        end

        if COS.isHarvesting and time - COS.time > 1 then
            COS.isHarvesting = false
    end

        if action ~= COS.action then
            COS.action = action -- COS.action is the global current action
            -- if COS.action ~= nil then
            --     d("New Action! : " .. COS.action .. " : " .. time)
            -- end
            -- d(COS.action .. " : " .. GetString(SI_GAMECAMERAACTIONTYPE16))

            -- Check Reticle and Non Harvest Actions
            -- Skyshard
            if type == INTERACTION_NONE and COS.action == GetString(SI_GAMECAMERAACTIONTYPE5) then
                targetType = "skyshard"

                if COS.name == "Skyshard" then
                    if COS.LogCheck(targetType, {subzone}, x, y) then
                        COS.Log(targetType, {subzone}, x, y)
                    end
                end

            -- Chest
            elseif type == INTERACTION_NONE and COS.action == GetString(SI_GAMECAMERAACTIONTYPE12) then
                targetType = "chest"

                if COS.LogCheck(targetType, {subzone}, x, y) then
                    COS.Log(targetType, {subzone}, x, y)
                end

            -- Fishing Nodes
            elseif COS.action == GetString(SI_GAMECAMERAACTIONTYPE16) then
                targetType = "fish"

                if COS.LogCheck(targetType, {subzone}, x, y) then
                    COS.Log(targetType, {subzone}, x, y)
                end

            end
        end -- End of {{if action ~= COS.action then}}
    else -- End of {{if not isHarvesting then}}
        -- d("I am REALLY busy! Time : " .. time)
        COS.isHarvesting = true
        COS.time = time

    -- End of Else Block
    end -- End of Else Block
end

-----------------------------------------
--         Coordinate System           --
-----------------------------------------

function COS.UpdateCoordinates()
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

        CosechadorCoordinates:SetAlpha(0.8)
        CosechadorCoordinates:SetDrawLayer(ZO_WorldMap:GetDrawLayer() + 1)
        CosechadorCoordinates:SetAnchor(TOPLEFT, nil, TOPLEFT, parentOffsetX + 0, parentOffsetY + parentHeight)
        CosechadorCoordinatesValue:SetText("Coordinates: " .. normalizedX .. ", " .. normalizedY)
    else
        CosechadorCoordinates:SetAlpha(0)
    end
end

-----------------------------------------
--            API Helpers              --
-----------------------------------------

function COS.GetUnitPosition(tag)
    local setMap = SetMapToPlayerLocation() -- Fix for bug #23
    if setMap == 2 then
        CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged") -- Fix for bug #23
    end

    local x, y, a = GetMapPlayerPosition(tag)
    local subzone = GetMapName()
    local world = GetUnitZone(tag)

    return x, y, a, subzone, world
end

function COS.GetUnitName(tag)
    return GetUnitName(tag)
end

function COS.GetUnitLevel(tag)
    return GetUnitLevel(tag)
end

function COS.GetLootEntry(index)
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

function COS.Debug(...)
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

function COS.ItemLinkParse(link)
    
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

function COS.CheckDupeContents(items, itemName)
    for _, entry in pairs( items ) do
        if entry[1] == itemName then
            return true
        end
    end
    return false
end
function COS.OnLootReceived(eventCode, receivedBy, objectName, stackCount, soundCategory, lootType, lootedBySelf)
    if not IsGameCameraUIModeActive() then
        targetName = COS.name

        if not COS.IsValidNode(targetName) then
            return
        end

        local link = COS.ItemLinkParse(objectName)
        local material = COS.GetTradeskillByMaterial(link.id)
        local x, y, a, subzone, world = COS.GetUnitPosition("player")

        -- This attempts to resolve an issue where you can loot a harvesting
        -- node that has worms or plump worms in it and it gets recorded.
        -- It also attempts to resolve adding non harvest nodes to harvest
        -- such as bottles, crates, barrels, baskets, wine racks, and
        -- heavy sacks.  Some of those containers give random items but can
        -- also give solvents.  Heavy Sacks can contain Enchanting reagents.
        if not COS.isHarvesting and material >= 1 then
            material = 5
        elseif COS.isHarvesting and material == 5 then
            material = 0
        end

        if material == 0 then
            return
        end

        if material == 5 then
            data = COS.LogCheck("provisioning", { subzone, material }, x, y, 0.003)
            if not data then -- when there is no node at the given location, save a new entry
                COS.Log("provisioning", { subzone, material }, x, y, targetName, { {link.name, link.id, stackCount} } )
            else --otherwise add the new data to the entry
                if data[3] == targetName then
                    if not COS.CheckDupeContents(data[4], link.name) then
                        table.insert(data[4], {link.name, link.id, stackCount} )
                    end
                else
                    COS.Log("provisioning", { subzone, material }, x, y, targetName, { {link.name, link.id, stackCount} } )
                end
            end
        else
            data = COS.LogCheck("harvest", { subzone, material }, x, y, 0.003)
            if not data then -- when there is no node at the given location, save a new entry
                COS.Log("harvest", { subzone, material }, x, y, targetName, { {link.name, link.id, stackCount} } )
            else --otherwise add the new data to the entry
                if data[3] == targetName then
                    if not COS.CheckDupeContents(data[4], link.name) then
                        table.insert(data[4], {link.name, link.id, stackCount} )
                    end
                else
                    COS.Log("harvest", { subzone, material }, x, y, targetName, { {link.name, link.id, stackCount} } )
                end
            end
        end
        
    end
end

-----------------------------------------
--         Lore Book Tracking          --
-----------------------------------------

function COS.OnShowBook(eventCode, title, body, medium, showTitle)
    local x, y, a, subzone, world = COS.GetUnitPosition("player")

    local targetType = "book"

    data = COS.LogCheck(targetType, {subzone, title}, x, y, nil)
    if not data then -- when there is no node at the given location, save a new entry
        COS.Log(targetType, {subzone, title}, x, y)
    end
end

-----------------------------------------
--          Vendor Tracking            --
-----------------------------------------

function COS.VendorOpened()
    local x, y, a, subzone, world = COS.GetUnitPosition("player")

    targetType = "vendor"

    local storeItems = {}

    data = COS.LogCheck(targetType, {subzone, COS.name}, x, y, nil)
    if not data then -- when there is no node at the given location, save a new entry
        for entryIndex = 1, GetNumStoreItems() do
            local icon, name, stack, price, sellPrice, meetsRequirementsToBuy, meetsRequirementsToEquip, quality, questNameColor, currencyType1, currencyId1, currencyQuantity1, currencyIcon1,
            currencyName1, currencyType2, currencyId2, currencyQuantity2, currencyIcon2, currencyName2 = GetStoreEntryInfo(entryIndex)

            if(stack > 0) then
            local itemData =
            {
                name,
                stack,
                price,
                quality,
                questNameColor,
                currencyType1,
                currencyQuantity1,
                currencyType2,
                currencyQuantity2,
                { GetStoreEntryTypeInfo(entryIndex) },
                GetStoreEntryStatValue(entryIndex),
                }

                storeItems[#storeItems + 1] = itemData
            end
        end

        COS.Log(targetType, {subzone, COS.name}, x, y, storeItems)
    end
end

-----------------------------------------
--           Quest Tracking            --
-----------------------------------------

function COS.OnQuestAdded(_, questIndex)
    local questName = GetJournalQuestInfo(questIndex)
    local questLevel = GetJournalQuestLevel(questIndex)

    local targetType = "quest"

    if COS.currentConversation.npcName == "" or COS.currentConversation.npcName == nil then
        return
    end

    data = COS.LogCheck(targetType, {COS.currentConversation.subzone, questName}, COS.currentConversation.x, COS.currentConversation.y, nil)
    if not data then -- when there is no node at the given location, save a new entry
        COS.Log(
            targetType,
            {
                COS.currentConversation.subzone,
                questName
            },
            COS.currentConversation.x,
            COS.currentConversation.y,
            questLevel,
            COS.currentConversation.npcName,
            COS.currentConversation.npcLevel
        )
    end
end

-----------------------------------------
--        Conversation Tracking        --
-----------------------------------------

function COS.OnChatterBegin()
    local x, y, a, subzone, world = COS.GetUnitPosition("player")
    local npcLevel = COS.GetUnitLevel("interact")

    COS.currentConversation.npcName = COS.name
    COS.currentConversation.npcLevel = npcLevel
    COS.currentConversation.x = x
    COS.currentConversation.y = y
    COS.currentConversation.subzone = subzone
end

-----------------------------------------
--        Better NPC Tracking          --
-----------------------------------------

-- Fired when the reticle hovers a new target
function COS.OnTargetChange(eventCode)
    local tag = "reticleover"
    local type = GetUnitType(tag)

    -- ensure the unit that the reticle is hovering is a non-playing character
    if type == 2 then
        local name = COS.GetUnitName(tag)
        local x, y, a, subzone, world = COS.GetUnitPosition(tag)

        if name == nil or name == "" or x <= 0 or y <= 0 then
            return
        end

        local level = COS.GetUnitLevel(tag)

    data = COS.LogCheck("npc", {subzone, name }, x, y, nil)
    if not data then -- when there is no node at the given location, save a new entry
            COS.Log("npc", {subzone, name}, x, y, level)
        end
    end
end

-----------------------------------------
--           Slash Command             --
-----------------------------------------

SLASH_COMMANDS["/cosecha"] = function (cmd)
    local commands = {}
    local index = 1
    for i in string.gmatch(cmd, "%S+") do
        if (i ~= nil and i ~= "") then
            commands[index] = i
            index = index + 1
        end
    end

    if #commands == 0 then
        return COS.Debug("Please enter a valid command")
    end

    if #commands == 2 and commands[1] == "debug" then
        if commands[2] == "on" then
            COS.Debug("Cosechador debugger toggled on")
            COS.savedVars["internal"].debug = 1
        elseif commands[2] == "off" then
            COS.Debug("Cosechador debugger toggled off")
            COS.savedVars["internal"].debug = 0
        end

    elseif commands[1] == "reset" then
        for type,sv in pairs(COS.savedVars) do
            if type ~= "internal" then
                COS.savedVars[type].data = {}
            end
        end

        COS.Debug("Saved data has been completely reset")

    elseif commands[1] == "datalog" then
        COS.Debug("---")
        COS.Debug("Complete list of gathered data:")
        COS.Debug("---")

        local counter = {
            ["skyshard"] = 0,
            ["npc"] = 0,
            ["harvest"] = 0,
            ["provisioning"] = 0,
            ["chest"] = 0,
            ["fish"] = 0,
            ["book"] = 0,
            ["vendor"] = 0,
            ["quest"] = 0,
        }

        for type,sv in pairs(COS.savedVars) do
            if type ~= "internal" and (type == "skyshard" or type == "chest" or type == "fish") then
                for zone, t1 in pairs(COS.savedVars[type].data) do
                    counter[type] = counter[type] + #COS.savedVars[type].data[zone]
                end
            elseif type ~= "internal" and type == "provisioning" then
                for zone, t1 in pairs(COS.savedVars[type].data) do
                    for item, t2 in pairs(COS.savedVars[type].data[zone]) do
                        for data, t3 in pairs(COS.savedVars[type].data[zone][item]) do
                            counter[type] = counter[type] + #COS.savedVars[type].data[zone][item][data]
                        end
                    end
                end
            elseif type ~= "internal" then
                for zone, t1 in pairs(COS.savedVars[type].data) do
                    for data, t2 in pairs(COS.savedVars[type].data[zone]) do
                        counter[type] = counter[type] + #COS.savedVars[type].data[zone][data]
                    end
                end
            end
        end

        COS.Debug("Skyshards: "        .. COS.NumberFormat(counter["skyshard"]))
        COS.Debug("Monster/NPCs: "     .. COS.NumberFormat(counter["npc"]))
        COS.Debug("Lore/Skill Books: " .. COS.NumberFormat(counter["book"]))
        COS.Debug("Harvest: "          .. COS.NumberFormat(counter["harvest"]))
        COS.Debug("Provisioning: "     .. COS.NumberFormat(counter["provisioning"]))
        COS.Debug("Treasure Chests: "  .. COS.NumberFormat(counter["skyshard"]))
        COS.Debug("Fishing Pools: "    .. COS.NumberFormat(counter["fish"]))
        COS.Debug("Quests: "           .. COS.NumberFormat(counter["quest"]))
        COS.Debug("Vendor Lists: "     .. COS.NumberFormat(counter["vendor"]))

        COS.Debug("---")
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

function COS.OnLoad(eventCode, addOnName)
    if addOnName ~= "Cosechador" then
        return
    end

    COS.language = (GetCVar("language.2") or "en")
    COS.InitSavedVariables()
    COS.savedVars["internal"]["language"] = COS.language

    EVENT_MANAGER:RegisterForEvent("Cosechador", EVENT_RETICLE_TARGET_CHANGED, COS.OnTargetChange)
    EVENT_MANAGER:RegisterForEvent("Cosechador", EVENT_CHATTER_BEGIN, COS.OnChatterBegin)
    EVENT_MANAGER:RegisterForEvent("Cosechador", EVENT_SHOW_BOOK, COS.OnShowBook)
    EVENT_MANAGER:RegisterForEvent("Cosechador", EVENT_QUEST_ADDED, COS.OnQuestAdded)
    EVENT_MANAGER:RegisterForEvent("Cosechador", EVENT_LOOT_RECEIVED, COS.OnLootReceived)
    EVENT_MANAGER:RegisterForEvent("Cosechador", EVENT_OPEN_STORE, COS.VendorOpened)
end

EVENT_MANAGER:RegisterForEvent("Cosechador", EVENT_ADD_ON_LOADED, function (eventCode, addOnName)
    if addOnName == "Cosechador" then
        COS.Initialize()
        COS.OnLoad(eventCode, addOnName)
	end
end)