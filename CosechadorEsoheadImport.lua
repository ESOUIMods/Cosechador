-- Version 4 Format
-- [1] and [2] : X, Y
-- [3] Stack Count
-- [4] Node Name
-- [5] Item ID
function ProcessVersionFourNode(newMapName, node)
    Harvest.NumNodesProcessed = Harvest.NumNodesProcessed + 1
    if not Harvest.IsValidContainerOnImport(node[4]) then -- << Not a Container
        if Harvest.CheckProfessionTypeOnImport(node[5], node[4]) then -- << If Valid Profession Type
            professionFound = Harvest.GetProfessionType(node[5], node[4])
            if professionFound >= 1 then
                -- When import filter is false do NOT import the node
                if Harvest.settings.importFilters[ professionFound ] then
                    Harvest.saveData( newMapName, node[1], node[2], professionFound, node[4], node[5] )
                else
                    -- d("skipping Node : " .. node[4] .. " : ID : " .. tostring(node[5]))
                    Harvest.NumbersNodesFiltered = Harvest.NumbersNodesFiltered + 1
                end
            end
        else -- << If Valid Profession Type
            Harvest.NumFalseNodes = Harvest.NumFalseNodes + 1
            -- if Harvest.settings.verbose then
            --     d("Node:" .. node[4] .. " ItemID " .. tostring(node[5]) .. " skipped")
            -- end
        end -- << If Valid Profession Type
    else -- << Not a Container
        Harvest.NumContainerSkipped = Harvest.NumContainerSkipped + 1
        -- if Harvest.settings.verbose then
        --     d("Container :" .. node[4] .. " ItemID " .. tostring(node[5]) .. " skipped")
        -- end
    end -- << Not a Container
end

-- Version 5 Format
-- [1] and [2] : X, Y
-- [3] Node Name
-- [4] The Item itself broken down into other fields
-- -- [1] Item Name
-- -- [2] Item ID
-- -- [3] Stack Count
function ProcessVersionFiveNode(newMapName, node)
    Harvest.NumNodesProcessed = Harvest.NumNodesProcessed + 1
    if not Harvest.IsValidContainerOnImport(node[3]) then -- << Not a Container
        for _, items in pairs(node[4]) do
            if Harvest.CheckProfessionTypeOnImport(items[2], node[3]) then -- << If Valid Profession Type
                professionFound = Harvest.GetProfessionType(items[2], node[3])
                if professionFound >= 1 then
                    -- When import filter is false do NOT import the node
                    if Harvest.settings.importFilters[ professionFound ] then
                        Harvest.saveData( newMapName, node[1], node[2], professionFound, node[3], items[2] )
                    else
                        -- d("skipping Node : " .. node[4] .. " : ID : " .. tostring(node[5]))
                        Harvest.NumbersNodesFiltered = Harvest.NumbersNodesFiltered + 1
                    end
                end
            else -- << If Valid Profession Type
                Harvest.NumFalseNodes = Harvest.NumFalseNodes + 1
                -- if Harvest.settings.verbose then
                --     d("Node:" .. node[4] .. " ItemID " .. tostring(node[5]) .. " skipped")
                -- end
            end -- << If Valid Profession Type
        end
    else -- << Not a Container
        Harvest.NumContainerSkipped = Harvest.NumContainerSkipped + 1
        -- if Harvest.settings.verbose then
        --     d("Container :" .. node[4] .. " ItemID " .. tostring(node[5]) .. " skipped")
        -- end
    end -- << Not a Container
end

function Harvest.importFromEsohead()
    Harvest.NumbersNodesAdded = 0
    Harvest.NumFalseNodes = 0
    Harvest.NumContainerSkipped = 0
    Harvest.NumbersNodesFiltered = 0
    Harvest.NumNodesProcessed = 0

    if not EH then
        d("Please enable the Esohead addon to import data!")
        return
    end
    d("import data from Esohead")
    local newMapName
    if not Harvest.nodes.oldData then
        Harvest.nodes.oldData = {}
    end

    -- Esohead "harvest" Profession designations
    -- 1 Mining
    -- 2 Clothing
    -- 3 Enchanting
    -- 4 Alchemy
    -- 5 Was Provisioning, moved to separate section in Esohead
    -- 6 Wood

    -- Additional HarvestMap Catagories
    -- 6 = Chest, 7 = Solvent, 8 = Fish

    local professionFound
    d("Import Harvest Nodes:")
    for map, data in pairs(EH.savedVars["harvest"].data) do
        d("import data from "..map)
        newMapName = Harvest.GetNewMapName(map)
        if newMapName then
            for index, nodes in pairs(data) do
                for _, node in pairs(nodes) do
                    if EH.savedVars["harvest"]["version"] <= 4 then
                        ProcessVersionFourNode(newMapName, node)
                    elseif EH.savedVars["harvest"]["version"] >= 5 then
                        ProcessVersionFiveNode(newMapName, node)
                    end
                end
            end
        end
    end

    d("Import Chests:")
    for map, nodes in pairs(EH.savedVars["chest"].data) do
        d("import data from "..map)
        newMapName = Harvest.GetNewMapName(map)
        if newMapName then
            for _, node in pairs(nodes) do
                Harvest.NumNodesProcessed = Harvest.NumNodesProcessed + 1
                -- Esohead "chest" has nodes only, add appropriate data
                -- The 6 before "chest" refers to it's Profession ID
                -- When import filter is false do NOT import the node
                if Harvest.settings.importFilters[ 6 ] then
                    Harvest.saveData( newMapName, node[1], node[2], 6, "chest", nil )
                else
                    Harvest.NumbersNodesFiltered = Harvest.NumbersNodesFiltered + 1
                end
            end
        end
    end

    d("Import Fishing Holes:")
    for map, nodes in pairs(EH.savedVars["fish"].data) do
        d("import data from "..map)
        newMapName = Harvest.GetNewMapName(map)
        if newMapName then
            for _, node in pairs(nodes) do
                Harvest.NumNodesProcessed = Harvest.NumNodesProcessed + 1
                -- Esohead "fish" has nodes only, add appropriate data
                -- The 8 before "fish" refers to it's Profession ID
                -- When import filter is false do NOT import the node
                if Harvest.settings.importFilters[ 8 ] then
                    Harvest.saveData( newMapName, node[1], node[2], 8, "fish", nil )
                else
                    Harvest.NumbersNodesFiltered = Harvest.NumbersNodesFiltered + 1
                end
            end
        end
    end

    d("Number of nodes processed : " .. tostring(Harvest.NumNodesProcessed) )
    d("Number of nodes added : " .. tostring(Harvest.NumbersNodesAdded) )
    d("Number of nodes filtered : " .. tostring(Harvest.NumbersNodesFiltered) )
    d("Number of Containers skipped : " .. tostring(Harvest.NumContainerSkipped) )
    d("Number of False nodes skipped : " .. tostring(Harvest.NumFalseNodes) )
    d("Finished.")
    Harvest.RefreshPins()
end

SLASH_COMMANDS["/import"] = Harvest.importFromEsohead