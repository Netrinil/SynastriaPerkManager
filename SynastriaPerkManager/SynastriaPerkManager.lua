SynastriaPerkManager = SynastriaPerkManager or {}
SPMData = SPMData or {}

SynastriaPerkManager.frames = {}
SynastriaPerkManager.frames.master = nil

SynastriaPerkManager.frames.IODialog = nil

local perkMgrFrame = nil

local selectedPerkId = 0
local selectedPerkName = ""
local cachedPerkName = ""

local class1Id = 0
local class2Id = 0
local class1Name = nil
local class2Name = nil

local categories = {"Offensive", "Defensive", "Support", "Utility", "Class", "Dual Class", "Misc", "Build"}
local databaseCategories = {"Offensive", "Defensive", "Support", "Utility", "Class", "Misc", "Build"}
local buildCategories = {"Offensive", "Defensive", "Support", "Utility", "Class", "Dual Class", "Misc"}

SynastriaPerkManager.activePerks = {
    ["Offensive"] = {},
    ["Defensive"] = {},
    ["Support"] = {},
    ["Utility"] = {},
    ["Class"] = {},
    ["Dual Class"] = {},
    ["Misc"] = {},
}

local perkCategories = {
    [1] = 'Warrior', 
    [2] = 'Paladin', 
    [3] = 'Hunter', 
    [4] = 'Rogue',
    [5] = 'Priest', 
    [6] = 'Death Knight', 
    [7] = 'Shaman', 
    [8] = 'Mage',
    [9] = 'Warlock', 
    [11] = 'Druid',
    [15] = 'Offensive',
    [16] = 'Defensive', 
    [17] = 'Support',
    [18] = 'Utility', 
    [19] = 'Misc'
}

local perkWidgetMappings = {}

StaticPopupDialogs["SPM_RENAME_BUILD"] = {
    text = "Rename %s %s",
    button1 = "Accept",
    button2 = "Cancel",
    hasEditBox = true,
    maxLetters = 20, -- reasonable name length
    timeout = 0,
    whileDead = true,
    exclusive = true,
    hideOnEscape = true,
    OnShow = function(self)
        self.editBox:SetText(self.data.currentName or "")
        self.editBox:SetFocus()
        self.editBox:HighlightText()
    end,
    OnAccept = function(self)
        local newName = self.editBox:GetText()
        local category = self.data.category
        local slot     = self.data.slot

        if newName == "" then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000SPM: Rename failed, Name cannot be empty.|r")
            return
        end

        if SPMData.builds[category][newName] ~= nil then
            print("SPM: This name is already in use")
            return
        end

        if SPMData.builds[category][slot] == nil then
            SPMData.builds[category][slot] = {}
        end
        
        -- Save the new name
        --local oldName = SynastriaPerkManager.GetSlotName(category, SPMData.builds[category][slot])
        SPMData.builds[category][newName] = SPMData.builds[category][slot]
        if SPMData.builds[category][slot] ~= nil and slot ~= nil then 
            SPMData.builds[category][slot] = nil
        end
        print(string.format("SPM: Renamed %s %s to: %s", slot, category, newName))
    end
}

-- === INTERACTION FUNCTIONS ===

function SynastriaPerkManager.CreateIODialog()
    if SynastriaPerkManager.frames.IODialog then
        return SynastriaPerkManager.frames.IODialog
    end

    local dialogFrame = SynastriaPerkManager.frames.IODialog
    
    -- Main frame
    dialogFrame = CreateFrame("Frame", "SPM_IODialog", SynastriaPerkManager.frames.master)
    dialogFrame:SetSize(350, 160)
    dialogFrame:SetPoint("CENTER", perkMgrFrame:GetWidth()/2,0)
    dialogFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    dialogFrame:SetBackdropColor(0, 0, 0, 1)
    dialogFrame:Hide()
    dialogFrame:SetFrameStrata("DIALOG")
    
    -- Make it movable
    dialogFrame:SetMovable(true)
    dialogFrame:EnableMouse(true)
    dialogFrame:RegisterForDrag("LeftButton")
    dialogFrame:SetScript("OnDragStart", dialogFrame.StartMoving)
    dialogFrame:SetScript("OnDragStop", dialogFrame.StopMovingOrSizing)
    
    -- Import button
    local importBtn = CreateFrame("Button", nil, dialogFrame, "UIPanelButtonTemplate")
    importBtn:SetSize(70, 22)
    importBtn:SetPoint("BOTTOM", 0, 15)
    importBtn:SetText("Import")
    importBtn:SetScript("OnClick", function()
        local importName = dialogFrame.importName:GetText()
        if importName == nil or importName == "" then
            print("Please enter a name first")
            return
        end
        local importedPerkTable = SynastriaPerkManager.ParsePerkImport(dialogFrame.editBox:GetText(), dialogFrame.importCat)

        SynastriaPerkManager.ImportPerks(importedPerkTable, importName)
        dialogFrame:Hide()
    end)

    local importName = CreateFrame("EditBox", "SPM_BuildImportName", dialogFrame)
    importName:SetSize(120,16)
    importName:SetPoint("TOP", 0, -20)
    importName:SetMultiLine(false)
    importName:SetFontObject(ChatFontNormal)

    -- Add a border around the text area
    local importNameBorder = CreateFrame("Frame", nil, dialogFrame)
    importNameBorder:SetSize(124, 20)
    importNameBorder:SetPoint("CENTER", importName, "CENTER")
    importNameBorder:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    importNameBorder:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)

    -- Build Name
    local buildName = dialogFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    buildName:SetPoint("RIGHT", importName, "LEFT", -10, 0)
    buildName:SetText("Name:")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, dialogFrame, "UIPanelButtonTemplate")
    closeBtn:SetSize(70, 22)
    closeBtn:SetPoint("BOTTOMRIGHT", -25, 15)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function()
        dialogFrame.importCat = nil
        dialogFrame.importSlot = nil
        dialogFrame:Hide()
    end)
    
    -- Multi-line text area using ScrollFrame
    local scrollFrame = CreateFrame("ScrollFrame", nil, dialogFrame)
    scrollFrame:SetSize(300, 60)
    scrollFrame:SetPoint("TOP", importName, "BOTTOM", 0, -15)
    
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetSize(300, 60)
    editBox:SetPoint("TOPLEFT")
    editBox:SetMultiLine(true)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetAutoFocus(false)
    editBox:SetScript("OnEscapePressed", function() 
        editBox:ClearFocus()
        dialogFrame:Hide() 
    end)
    -- Add this new script to handle focus when the frame is shown
    editBox:SetScript("OnShow", function(self)
            self:SetFocus()
            self:SetCursorPosition(0) -- Position cursor at start
    end)
    
    scrollFrame:SetScrollChild(editBox)
    
    -- Add a border around the text area
    local border = CreateFrame("Frame", nil, dialogFrame)
    border:SetSize(304, 64)
    border:SetPoint("CENTER", scrollFrame, "CENTER")
    border:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    border:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    
    -- Store references
    dialogFrame.importBtn = importBtn
    dialogFrame.importName = importName
    dialogFrame.importNameBorder = importNameBorder
    dialogFrame.buildName = buildName
    dialogFrame.editBox = editBox
    dialogFrame.closeBtn = closeBtn
    dialogFrame.importName = importName

    dialogFrame.importCat = nil
    dialogFrame.importSlot = nil
    
    SynastriaPerkManager.frames.IODialog = dialogFrame
    return dialogFrame
end

function SynastriaPerkManager.SavePerks(category, slot)
    local dbCategory = category
    if dbCategory == "Dual Class" then
        dbCategory = "Class"
    end
    
    if category == "Build" then
        SPMData.builds[category][slot] = {}
        for _, buildCat in ipairs(buildCategories) do
            for perkId, perkOptions in pairs(SynastriaPerkManager.activePerks[buildCat]) do
                table.insert(SPMData.builds[category][slot], perkId, perkOptions)
            end
        end
    else
        SPMData.builds[dbCategory][slot] = SynastriaPerkManager.activePerks[category] or {}
    end
    local dd = _G["SynastriaPerkManagerDropdown_" .. category]
    if dd then
        UIDropDownMenu_SetText(dd, slot)
    end
    print(string.format("|cff00ff00Saved %s %s|r", category, slot))
end

function SynastriaPerkManager.LoadPerks(category, slot)
    SynastriaPerkManager.UpdatePerkList()

    local deactivateTable = SynastriaPerkManager.activePerks[category] or {}
    local activateTable = {}

    
    if SPMData.builds[category][slot] then
        -- we toggle perk options before filtering because the options shouldn't care if we already have it active or not
        SynastriaPerkManager.TogglePerkOptions(SPMData.builds[category][slot])

        for perkId, perkOptions in pairs(SPMData.builds[category][slot]) do
            -- if we currently have this perk active already, remove it from the deactivate table
            if deactivateTable[perkId] then
                deactivateTable[perkId] = nil
            else
                -- if it's not active, add it and its options to the activate table
                activateTable[perkId] = perkOptions
            end
        end
    end

    local catSuffixes = {"Off", "Def", "Sup", "Uti", "Cla", "Clb", "Mis"}

    -- switch to "All" filter if needed
    local selectedFilter = _G["PerkMgrFrame-Filter"].selectedValue
    if selectedFilter == "act" then
        _G["PerkMgrFrame-FilterButton"]:Click()
        _G["DropDownList1Button1"]:Click()
    end
    
    -- ensures that all categories are expanded so the toggle functions correctly
    local expandedCategories = SynastriaPerkManager.ExpandPerkCategories(catSuffixes)

    SynastriaPerkManager.TogglePerks(category, deactivateTable)
    SynastriaPerkManager.TogglePerks(category, activateTable)
    
    if selectedFilter == "act" then
        _G["PerkMgrFrame-FilterButton"]:Click()
        _G["DropDownList1Button2"]:Click()
    end

    SynastriaPerkManager.CollapsePerkCategories(expandedCategories)
    
    local dd = _G["SynastriaPerkManagerDropdown_" .. category]
    if dd then
        UIDropDownMenu_SetText(dd, slot)
    end
    print(string.format("|cff00ff00Loaded %s %s|r", category, slot))
end

function SynastriaPerkManager.ImportPerks(importedPerkTable, importName)
    print("Importing perks")
    for ptCat, perkTable in pairs(importedPerkTable) do
        print("Importing "..ptCat.." "..importName)
        if ptCat == "Dual Class" then
            SPMData.builds["Class"][importName.."Dual"] = perkTable
        else
            SPMData.builds[ptCat][importName] = perkTable
        end
    end
end

function SynastriaPerkManager.ExportPerks(category, slot)
    local dialogFrame = SynastriaPerkManager.CreateIODialog()
    dialogFrame:Show()
    if category == "Dual Class" then
        category = "Class"
    end
    
    dialogFrame.importBtn:Hide()
    dialogFrame.importName:Hide()
    dialogFrame.buildName:Hide()
    dialogFrame.importNameBorder:Hide()

    local exportLines = {}
    -- Get perk export
    if not SPMData.builds[category][slot] then
        return
    end

    local perks = SPMData.builds[category][slot]

    if perks ~= {} then
        local perkOptions = {}
        for p, o in pairs(perks) do
            table.insert(perkOptions, #perkOptions+1, p..':'..o)
        end
        local perkString = table.concat(perkOptions, ",")
        table.insert(exportLines, perkString)
    end

    -- Combine all lines with ,
    local finalExport = table.concat(exportLines, ",")

    -- Populate the text box
    dialogFrame.editBox:SetText(finalExport)
    dialogFrame.editBox:SetFocus()
    dialogFrame.editBox:HighlightText()
end

function SynastriaPerkManager.TogglePerkOptions(perks)
    for perkId, perkOptions in pairs(perks) do
        local perkOptionsTable = SynastriaPerkManager.ParseBinaryInteger(tonumber(perkOptions))
        for perkOptionIndex, perkOptionValue in ipairs(SynastriaPerkManager.ParseBinaryInteger(PerkMgrPerks[perkId]["options"])) do
            ChangePerkOption(perkId,perkOptionIndex, perkOptionsTable[perkOptionIndex]==1)
        end
    end
end

function SynastriaPerkManager.TogglePerks(category, targetPerks)
    if targetPerks then
        -- perkActive is equal to GetPerkOptions(perkId)
        for perkId, perkOptions in pairs(targetPerks) do
            -- make a local copy of the perkId
            local perk = PerkMgrPerks[perkId]
            -- if we're toggling a class perk, make sure it's for one of our classes
            if (category ~= "Class" or CMCGetClassAt(1) == perk.cat) or (category ~= "Dual Class" or CMCGetClassAt(2) == perk.cat) then
                -- check if non-class perk is allowed for our class, such as Improved Hand of Freedom or Fel Pact
                if perk.req == 0 or bit.band(CMCGetClassMask(), perk.req) ~= 0 then
                    -- get the widget number that corresponds to our perkId
                    local widgetNum = perkWidgetMappings[perkId]
                    if widgetNum ~= nil then
                        -- get a reference to the perkLine button
                        local perkLine = _G["PerkMgrFrame-PerkLine-"..widgetNum]
                        if not perkLine:IsVisible() then
                            print("SPM encountered an error loading perks")
                            return
                        end
                        -- click the button so it's the actively selected perk
                        perkLine:Click()
                        -- if togglable, then toggle
                        if _G["PerkMgrFrame-Toggle"]:IsEnabled() ~= 0 then
                            PerkMgrFrame.cele.toggleSel()
                        end
                    end
                end
            end
        end
    end
end

function SynastriaPerkManager.DeletePerks(category, slot)
    local dbCategory = category
    if dbCategory == "Dual Class" then
        dbCategory = "Class"
    end

    SPMData.builds[dbCategory][slot] = nil
end

-- === HELPER FUNCTIONS ===

function SynastriaPerkManager.ClearPerkCategory(category)
    SynastriaPerkManager.activePerks[category] = {}
end

function SynastriaPerkManager.ExpandPerkCategories(catSuffixes)
    local expandedCategories = {}
    for _, catSuffix in ipairs(catSuffixes) do
        if _G["PerkMgrFrame-Cat"..catSuffix] and _G["PerkMgrFrame-Cat"..catSuffix].isCollapsed then
            _G["PerkMgrFrame-Cat"..catSuffix]:Click()
            table.insert(expandedCategories, catSuffix)
        end
    end
    return expandedCategories
end

function SynastriaPerkManager.CollapsePerkCategories(catSuffixes)
    local collapsedCategories = {}
    for _, catSuffix in ipairs(catSuffixes) do
        if _G["PerkMgrFrame-Cat"..catSuffix] and _G["PerkMgrFrame-Cat"..catSuffix].isCollapsed == nil then
            _G["PerkMgrFrame-Cat"..catSuffix]:Click()
            table.insert(collapsedCategories, catSuffix)
        end
    end
    return collapsedCategories
end

function SynastriaPerkManager.GetClassFilteredBuilds(category)
    local filterClassId = class1Id
    if category == "Dual Class" then
        filterClassId = class2Id
    end

    local finalBuilds = {}
    local categoryBuilds = SPMData.builds[category]

    for buildName, buildPerks in pairs(categoryBuilds) do
        local isAllowedForClass = true
        for perkId, perkOptions in pairs(buildPerks) do
            local perk = PerkMgrPerks[perkId]

            -- if category == "Dual Class" use class2Id
            if category == "Class" then
                if class1Id ~= perk.cat then 
                    isAllowedForClass = false
                end
            elseif category == "Dual Class" then
                if class2Id ~= perk.cat then 
                    isAllowedForClass = false
                end
            elseif perk.req ~= 0 and bit.band(CMCGetClassMask(), perk.req) == 0 then
                isAllowedForClass = false
            end
        end
        if isAllowedForClass then
            finalBuilds[buildName] = buildPerks
        end
    end
    return finalBuilds
end

function SynastriaPerkManager.GetSlotName(category, slot) 
    for key, catSlot in pairs(SPMData.builds[category]) do
        if slot == catSlot then
            return key
        end
    end
    return nil
end

function SynastriaPerkManager.GetTableKeys(tbl)
    local keys = {}
    for key, value in pairs(tbl) do
        table.insert(keys, key)
    end

    return keys
end

function SynastriaPerkManager.ParseBinaryInteger(num)
    -- black magic via division
    local tbl = {}
    -- if num is nil or 0, return an empty table
    if not num or num == 0 then
        return tbl
    end
    -- 1024 inserts 0 and becomes 512
    --  512 inserts 0 and becomes 256
    --  256 inserts 0 and becomes 128
    --  128 inserts 0 and becomes  64
    --   64 inserts 0 and becomes  32
    --   32 inserts 0 and becomes  16
    --   16 inserts 0 and becomes   8
    --    8 inserts 0 and becomes   4
    --    4 inserts 0 and becomes   2
    --    2 inserts 0 and becomes   1
    --    1 inserts 1 and becomes   0
    while num > 0 do
        local rest = math.fmod(num, 2)
        table.insert(tbl, rest)
        num = (num - rest) / 2
    end
    return tbl
end

function SynastriaPerkManager.ParsePerkImport(importText, importCat)
    if not importText or importText == "" then
        print("Please paste a build string into the text box first.")
        return
    end
    
    -- Split the import text into lines and remove whitespace
    local lines = {}
    for line in importText:gmatch("[^\r\n]+") do
        local cleanLine = line:gsub("^%s*(.-)%s*$", "%1") -- Remove leading/trailing whitespace
        if cleanLine ~= "" then
            table.insert(lines, cleanLine)
        end
    end
    
    if lines == {} then
        print("No valid build data found.")
        return
    end
    
    -- First line should be perks (comma-separated numbers)
    -- can be formatted as:
    -- 1,2,3
    -- 1:1,2:1208512398,3
    local perkLine = lines[1]
    local hasPerkData = perkLine ~= nil and string.match(perkLine, "^%d+:?%d*") ~= nil

    local perkData = {}
    -- Import perks if we have perk data (this will print its own message with perk count)
    if hasPerkData then
        local tempClass1Id = 0
        local tempClass2Id = 0
        for perkId, perkOptions in string.gmatch(perkLine, "(%d+):?(%d*)") do

            perkOptions = perkOptions or 0
            perkId = tonumber(perkId)
            local perk = PerkMgrPerks[perkId]
            -- gets the category to assign the imported perks
            local cat = ""
            -- if it's a class perk
            if perk.cat < 15 then
                -- if the temp is empty, set the temp number to the category
                if tempClass1Id == 0 then
                    tempClass1Id = perk.cat
                -- if temp1 isn't empty, the perk's category we're checking isn't temp1, and temp2 is empty, then set temp2
                elseif tempClass1Id ~= 0 and tempClass1Id ~= perk.cat and tempClass2Id == 0 then
                    tempClass2Id = perk.cat
                end
                if perk.cat == tempClass1Id then
                    cat = "Class"
                elseif perk.cat == tempClass2Id then
                    cat = "Dual Class"
                else
                    -- if there's 3 classes in the import, just ingore anything other than 1 & 2
                end
            else
                cat = perkCategories[perk.cat]
            end
            
            if importCat == "Build" then
                perkData[importCat] = perkData[importCat] or {}
                perkData[importCat][perkId] = tonumber(perkOptions) or 0
            else
                perkData[cat] = perkData[cat] or {}
                perkData[cat][perkId] = tonumber(perkOptions) or 0
            end
        end
    end

    return perkData
end

function SynastriaPerkManager.UpdatePerkList()
    SynastriaPerkManager.activePerks = {}
    for perkId, perk in pairs(PerkMgrPerks) do
        if GetPerkActive(perkId) then
            local cat = ""
            if perk.cat == class1Id then
                cat = "Class"
            elseif perk.cat == class2Id then
                cat = "Dual Class"
            else
                cat = perkCategories[perk.cat]
            end
            SynastriaPerkManager.activePerks[cat] = SynastriaPerkManager.activePerks[cat] or {}
            if SynastriaPerkManager.activePerks[cat][perkId] == nil then
                --SynastriaPerkManager.activePerks[cat][perkId] = SynastriaPerkManager.activePerks[cat][perkId] or {}
                table.insert(SynastriaPerkManager.activePerks[cat], perkId, GetPerkOptions(perkId))
            end
        end
    end
end

function SynastriaPerkManager.StripColorCodes(text)
    if not text then return "" end
    -- Remove any |c followed by 8 hex chars, and any |r
    return text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end

function SPM_ShowPerkManagerFrame()
    if SynastriaPerkManager.frames.master == nil then
        SynastriaPerkManager.frames.master = CreateFrame('Frame', 'SynastriaPerkManagerMasterFrame', _G["PerkMgrFrame"])
        SynastriaPerkManager.BuildPerkManagerFrame()
    end
    SynastriaPerkManager.frames.master:Show()
end

function SPM_HidePerkManagerFrame()
    SynastriaPerkManager.frames.master:Hide()
end

-- === STARTUP FUNCTIONS ===

--[[
Table Structure example
SPMData = {
	["builds"] = {
		["Offensive"] = {
			["Custom Name"] = {
                1 = true,
                74 = true,
                1221 = true,
			},
        },
    }
}
--]]

local function InitializeDB()
    class1Id = CMCGetClassAt(1)
    class2Id = CMCGetClassAt(2)
    class1Name = CMCGetClassName(class1Id)
    class2Name = CMCGetClassName(class2Id)

    SPMData.builds = SPMData.builds or {}

    for _, cat in ipairs(databaseCategories) do
        SPMData.builds[cat] = SPMData.builds[cat] or {}

        for slotKey, slot in pairs(SPMData.builds[cat]) do
            if not SPMData.builds[cat][slotKey] then
                SPMData.builds[cat][cat.." "..slotKey] = {}
            end
        end
    end
end

function SynastriaPerkManager.MapWidgets()
    perkWidgetMappings = {}
    for i=1, 250 do -- probably a better way, but I know there's less than 250 perks at a time
        local widget = _G["PerkMgrFrame-PerkLine-"..i]
        if not widget then
            break
        end
        local widgetPerkId = widget.perk.id
        for perkId, perk in pairs(PerkMgrPerks) do
            if perkId == widgetPerkId then
                table.insert(perkWidgetMappings,perkId,i)
                break
            end
        end
    end
end

function SynastriaPerkManager.BuildPerkManagerFrame()
    -- Validation Checks
    if not _G["PerkMgrFrame"] then
        return
    end

    -- Set up variables
    local frameRef = _G["PerkMgrFrame"]
    perkMgrFrame = _G["PerkMgrFrame"]

    local masterFrame = SynastriaPerkManager.frames.master

    -- Master Frame

    masterFrame:SetHeight(frameRef:GetHeight()-19)
    masterFrame:SetWidth(200)
    --masterFrame:SetWidth(frameRef:GetWidth()-50)

    masterFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })

    masterFrame:ClearAllPoints()
    masterFrame:SetPoint('TOPRIGHT', frameRef, 'TOPLEFT', 9, -5)

    masterFrame:Show()      -- make sure it's visible
    masterFrame:SetAlpha(1) -- full opacity


    -- === 8 CATEGORY DROPDOWNS + SUBMENUS ===
    local dropdowns = {}

    local function PerkManagerDropdown_Initialize(self, level)
        level = level or 1
        local info = UIDropDownMenu_CreateInfo()

        if level == 1 then
            local count = 0
            local categoryBuilds = SynastriaPerkManager.GetClassFilteredBuilds(self.category)
            local categoryKeys = SynastriaPerkManager.GetTableKeys(categoryBuilds)
            table.sort(categoryKeys)
            -- add all of our saved slots
            for slotIndex, slotKey in pairs(categoryKeys) do
                count = count + 1
                info.defaultName = self.category .. " " .. count
                info.text         = slotKey or info.defaultName
                info.hasArrow     = true
                info.notCheckable = true
                info.menuList     = count
                UIDropDownMenu_AddButton(info, level)
            end
            -- if less than 9 saved slots, add empty slots such as Offensive 7
            if count < 9 then
                for i = count+1, 9 do
                    count = count + 1
                    info.defaultName = self.category .. " " .. i
                    info.text         = categoryKeys[i] or info.defaultName
                    info.hasArrow     = true
                    info.notCheckable = true
                    info.menuList     = i
                    UIDropDownMenu_AddButton(info, level)
                end
            end
            -- add 1 more empty slot so the user always has 1
            count = count + 1
            info.defaultName = self.category .. " " .. count
            info.text         = categoryKeys[count] or info.defaultName
            info.hasArrow     = true
            info.notCheckable = true
            info.menuList     = count
            UIDropDownMenu_AddButton(info, level)
        elseif level == 2 then
            local slot = UIDROPDOWNMENU_MENU_VALUE
            local cat  = self.category
            local build = SPMData.builds[cat][slot]

            for _, action in ipairs({"Save", "Load", "Import", "Export", "Rename", "", "", "Delete"}) do
                info.text         = action
                info.hasArrow     = false
                info.notCheckable = true

                if action == "Save" then
                    info.func = function()
                        SynastriaPerkManager.UpdatePerkList()
                        SynastriaPerkManager.SavePerks(cat, slot)
                    end
                elseif action == "Load" then
                    info.func = function()
                        SynastriaPerkManager.LoadPerks(cat, slot)
                        SynastriaPerkManager.UpdatePerkList()
                        end
                elseif action == "Rename" then
                    info.func = function()
                        -- Get current name if you already have one stored (otherwise empty)
                        local currentName = slot or ""
                        StaticPopup_Show("SPM_RENAME_BUILD", cat, slot, {
                            category    = cat,
                            slot        = slot,
                            currentName = currentName,
                        })
                    end
                elseif action == "Import" then
                    info.func = function()
                        local dialogFrame = SynastriaPerkManager.CreateIODialog()
                        dialogFrame.importBtn:Show()
                        dialogFrame.editBox:SetText("")
                        dialogFrame.importCat = cat
                        dialogFrame.importSlot = slot

                        
                        local currentName = slot or ""
                        dialogFrame.importName:Show()
                        dialogFrame.buildName:Show()
                        dialogFrame.importNameBorder:Show()
                        dialogFrame.importName:SetText(currentName)

                        dialogFrame:Show()
                    end
                elseif action == "Export" then
                    info.func = function()
                        if not build then
                            print("SPM: This is an empty build.")
                            return
                        end
                        SynastriaPerkManager.ExportPerks(cat, slot)
                    end
                elseif action == "" then
                    -- this is just a spacer for the delete button
                elseif action == "Delete" then
                    info.func = function()
                        SynastriaPerkManager.DeletePerks(cat, slot)
                        print("Deleted slot "..slot.." in category "..cat)
                    end
                else
                    print("WHAT DID YOU DO?! EVERYTHING'S ON FIRE!!!")
                end
                UIDropDownMenu_AddButton(info, level)
            end

            -- if build and build == SynastriaPerkManager.activePerks[cat] then
            --     UIDropDownMenu_SetText(self, SynastriaPerkManager.GetSlotName(cat,build))
            -- end
        end
    end

    for i, cat in ipairs(categories) do
        local dd = CreateFrame("Frame", "SynastriaPerkManagerDropdown_"..cat, masterFrame, "UIDropDownMenuTemplate")

        -- anchors the first dropdown slightly right of topleft of masterframe and the rest directly below the one above it
        local x = (i <= 1) and 15 or 0
        local y = (i <= 1) and -25 or -50
        local anchor = dropdowns[categories[i-1]] or masterFrame
        dd:SetPoint("TOPLEFT", anchor, "TOPLEFT", x, y)

        --UIDropDownMenu_SetWidth(dd, 160)
        dd.category = cat
        UIDropDownMenu_Initialize(dd, PerkManagerDropdown_Initialize)
        UIDropDownMenu_SetText(dd, cat)

        -- Label
        local label = dd:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("BOTTOMLEFT", dd, "TOPLEFT", 15, 3)
        label:SetText(cat)

        dropdowns[cat] = dd

        if cat == "Dual Class" then
            if CMCGetMultiClassEnabled() == 0 then
                dd:Hide()
                label:Hide()
            end
        end
    end

    -- Perk slider bar
    -- Create the slider
    local slider = CreateFrame("Slider", "SynastriaPerkManagerSlider", masterFrame, "OptionsSliderTemplate")

    -- Position it
    slider:ClearAllPoints()
    slider:SetPoint("BOTTOMLEFT", masterFrame, "BOTTOMLEFT", 20, 20)
    slider:SetPoint("BOTTOMRIGHT", masterFrame, "BOTTOMRIGHT", -20, 20)   -- stretches to full width with margins

    -- Configure the slider (1 to 10, step of 1)
    slider:SetMinMaxValues(1, 10)
    slider:SetValueStep(1)
    --slider:SetObeyStepOnDrag(true)

    -- Set a starting value
    slider:SetValue(5)

    -- Label above the slider
    slider.text = slider:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    slider.text:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 3)
    slider.text:SetText("Perk Preview Rank")   -- change to whatever you want

    -- Value text that shows current number ("5 / 10")
    slider.valueText = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    slider.valueText:SetPoint("BOTTOMRIGHT", slider, "TOPRIGHT", 0, 3)
    slider.valueText:SetText("5")

    -- Update the displayed value when the slider moves
    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)          -- ensure it's a clean integer
        self.valueText:SetText(tostring(value))

        local activePerk = PerkMgrPerks[selectedPerkId]
        local activePerkRank = 0
        local textToChange = frameRef.cele.abnexttext
        
        -- TODO: Do something with the value here
        selectedPerkName = SynastriaPerkManager.StripColorCodes(_G["PerkMgrFrameABName"]:GetText())
        if selectedPerkName ~= cachedPerkName then
            for perkId, perk in pairs(PerkMgrPerks) do
                if perk["name"] == selectedPerkName then
                    cachedPerkName = selectedPerkName
                    selectedPerkId = perkId
                    break
                end
            end
            activePerk = PerkMgrPerks[selectedPerkId]
        end
        if PerkMgrPerks[selectedPerkId].levels[10] then
            
            local subName = PerkMgrFrameABSubName:GetText()
            local _,_,rankText = string.find(subName, "Rank (%d+)")
            if rankText then
                activePerkRank = tonumber(rankText)
            end
            textToChange = frameRef.cele.abnexttext
            if activePerkRank == 10 then
                textToChange = frameRef.cele.abcurtext
            end
            
            textToChange:SetText(CustomGenerateDescription(activePerk.desc, activePerk.levels[value].amounts, nil))
        end
    end)
end

SynastriaPerkManager.frames.event = CreateFrame('Frame', 'SynastriaPerkManagerEventFrame', UIParent)

local delay = 0.5
local lastTime = 0

-- If it's stupid, but it works...
SynastriaPerkManager.frames.event:SetScript("OnUpdate", function(self, elapsed)
    lastTime = lastTime + elapsed

    if lastTime >= delay then
        lastTime = 0 
        if _G["PerkMgrFrame"] then
            SynastriaPerkManager.UpdatePerkList()
			_G["PerkMgrFrame"]:HookScript("OnShow", SPM_ShowPerkManagerFrame)
			_G["PerkMgrFrame"]:HookScript("OnHide", SPM_HidePerkManagerFrame)
            

            OpenPerkMgr()
            UpdatePerkMgr()
            SynastriaPerkManager.MapWidgets()
            ClosePerkMgr()

			SynastriaPerkManager.frames.event:SetScript("OnUpdate", nil)
			SynastriaPerkManager.frames.event:SetParent(nil)
			SynastriaPerkManager.frames.event:Hide()
			return
        end
    end
end)

SynastriaPerkManager.frames.event:RegisterEvent('ADDON_LOADED')
SynastriaPerkManager.frames.event:SetScript('OnEvent', function(self, event, arg1)
    if event == 'ADDON_LOADED' and arg1 == 'SynastriaPerkManager' then
        InitializeDB()
    end
end)