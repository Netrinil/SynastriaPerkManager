SynastriaPerkManager = SynastriaPerkManager or {}
SPMData = SPMData or {}

SynastriaPerkManager.frames = {}
SynastriaPerkManager.frames.master = nil

local selectedPerkId = 0
local selectedPerkName = ""
local cachedPerkName = ""

local class1Id = 0
local class2Id = 0
local class1Name = nil
local class2Name = nil

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

        if newName == "" then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Rename failed: Name cannot be empty.|r")
            return
        end

        local category = self.data.category
        local slot     = self.data.slot

        -- Save the new name
        if SPMData.builds[category][slot] == nil then
            print("You are attempting to rename an empty slot. Please save here first")
            return
        end
        local oldName = SynastriaPerkManager.GetSlotName(category, SPMData.builds[category][slot])
        print(string.format("Renamed %s %s to: %s", category, slot, newName))
        SPMData.builds[category][newName] = SPMData.builds[category][slot]
        if SPMData.builds[category][oldName] ~= nil and oldName ~= nil then 
            SPMData.builds[category][oldName] = nil
        end
    end
}

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

-- Helper to ensure the table structure exists
local function InitializeDB()
    class1Id = CMCGetClassAt(1)
    class2Id = CMCGetClassAt(2)
    class1Name = CMCGetClassName(class1Id)
    class2Name = CMCGetClassName(class2Id)

    SPMData.builds = SPMData.builds or {}

    local categories = {"Offensive", "Defensive", "Support", "Utility", "Class", "Dual Class", "Misc", "Build"}

    for _, cat in ipairs(categories) do
        SPMData.builds[cat] = SPMData.builds[cat] or {}

        for slotKey, slot in pairs(SPMData.builds[cat]) do
            if not SPMData.builds[cat][slotKey] then
                SPMData.builds[cat][cat.." "..slotKey] = {}
            end
        end
    end
    --print("SPM Database Initialized")
end

function SynastriaPerkManager.MapWidgets()
    perkWidgetMappings = {}
    for i=1, 200 do -- probably a better way, but I know there's less than 200 perks at a time
        local widget = _G["PerkMgrFrame-PerkLine-"..i]
        if not widget then
            break
        end
        local widgetPerkId = widget.perk.id
        for perkId, perk in pairs(PerkMgrPerks) do
            if perkId == widgetPerkId then
                table.insert(perkWidgetMappings,perkId,i)
                --print("Widget "..i.." is perkId "..widgetPerkId)
                break
            end
        end
    end
end
--[[
    ["Custom Name"] = {
        1 = true,
        74 = true,
        1221 = true,
    } = {
        6 = true,
        4 = true,
        21 = true,
    }
--]]

function SynastriaPerkManager.SavePerks(category, slot)
    SynastriaPerkManager.UpdatePerkList()
    SPMData.builds[category][slot] = SynastriaPerkManager.activePerks[category]
end

function SynastriaPerkManager.LoadPerks(category, slot)
    SynastriaPerkManager.UpdatePerkList()
    SynastriaPerkManager.TogglePerks(category, false)
    SynastriaPerkManager.ClearPerkCategory(category)

    SynastriaPerkManager.activePerks[category] = SPMData.builds[category][slot]
    local dd = _G["SynastriaPerkManagerDropdown_" .. category]
    if dd then
        local textToSet = SynastriaPerkManager.GetSlotName(category, slot)
        UIDropDownMenu_SetText(dd, slot)
    end

    SynastriaPerkManager.TogglePerks(category, true)
    SynastriaPerkManager.UpdatePerkList()
end

function SynastriaPerkManager.GetSlotName(category, slot) 
    for key, catSlot in pairs(SPMData.builds[category]) do
        if slot == catSlot then
            return key
        end
    end
    return nil
end

function SynastriaPerkManager.ImportPerks(category, perkTable)

end

function SynastriaPerkManager.ExportPerks(category, perkTable)

end

function SynastriaPerkManager.TogglePerks(category, load)
    local toggleTable = SynastriaPerkManager.activePerks[category]
    if toggleTable then
        for perkId, perkActive in pairs(toggleTable) do
            -- check if perk is allowed for our class
            local perk = PerkMgrPerks[perkId]
            if (category ~= "Class" or CMCGetClassAt(1) == perk.cat) or (category ~= "Dual Class" or CMCGetClassAt(2) == perk.cat) then
                if perk.req == 0 or bit.band(CMCGetClassMask(), perk.req) ~= 0 then 
                    local widgetNum = perkWidgetMappings[perkId]
                    if widgetNum ~= nil then
                        local perkLine = _G["PerkMgrFrame-PerkLine-"..widgetNum]
                        if not perkLine:IsVisible() then
                            print("encountered error loading perks")
                            return
                        end
                        perkLine:Click()
                        if _G["PerkMgrFrame-Toggle"]:IsEnabled() ~= 0 then
                            PerkMgrFrame.cele.toggleSel()
                        end
                        print()
                        for perkOptionIndex, perkOptionValue in ipairs(SynastriaPerkManager.ParseBinaryInteger(tonumber(perkActive))) do
                            print(perkId..", "..perkOptionIndex..", "..perkOptionValue)
                            ChangePerkOption(perkId,perkOptionIndex,(perkOptionValue==1 and load))
                        end
                    end
                end
            end
        end
    end
end

function SynastriaPerkManager.ParseBinaryInteger(num)
    local tbl = {}
    if not num or num == 0 then
        return tbl
    end
    while num > 0 do
        local rest = math.fmod(num, 2)
        table.insert(tbl, rest)
        num = (num - rest) / 2
    end
    return tbl
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
                table.insert(SynastriaPerkManager.activePerks[cat],perkId,GetPerkOptions(perkId))
            end
        end
    end
end

function SynastriaPerkManager.ClearPerkCategory(category)
    SynastriaPerkManager.activePerks[category] = {}
end

function SynastriaPerkManager.GetTableKeys(tbl)
    local keys = {}
    for key, value in pairs(tbl) do
        table.insert(keys, key)
    end

    return keys
end

function SynastriaPerkManager.BuildPerkManagerFrame()
    -- Validation Checks
    if not _G["PerkMgrFrame"] then
        return
    end

    -- Set up variables
    local frameRef = _G["PerkMgrFrame"]

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
    local categories = {"Offensive", "Defensive", "Support", "Utility", "Class", "Dual Class", "Misc", "Build"}
    local dropdowns = {}

    local function PerkManagerDropdown_Initialize(self, level)
        level = level or 1
        local info = UIDropDownMenu_CreateInfo()

        if level == 1 then
            local count = 0
            local categoryBuilds = SPMData.builds[self.category]
            local categoryKeys = SynastriaPerkManager.GetTableKeys(categoryBuilds)
            table.sort(categoryKeys)
            for slotIndex, slotKey in pairs(categoryKeys) do
                count = count + 1
                info.text         = slotKey or self.category .. " " .. count
                info.hasArrow     = true
                info.notCheckable = true
                info.menuList     = count
                UIDropDownMenu_AddButton(info, level)
            end
            if count < 10 then
                for i = count+1, 10 do
                    info.text         = SynastriaPerkManager.GetTableKeys(categoryBuilds)[i] or self.category .. " " .. i
                    info.hasArrow     = true
                    info.notCheckable = true
                    info.menuList     = i
                    UIDropDownMenu_AddButton(info, level)
                end
            end
        elseif level == 2 then
            local slot = UIDROPDOWNMENU_MENU_VALUE
            --print(slot)
            local cat  = self.category
            local build = SPMData.builds[cat][slot]

            for _, action in ipairs({"Save", "Load", "Import", "Export", "Rename"}) do
                info.text         = action
                info.hasArrow     = false
                info.notCheckable = true
                --print(action .. " " .. cat .. " " .. slot)

                if action == "Save" then
                    info.func = function()
                        SynastriaPerkManager.SavePerks(cat, slot)
                        print(string.format("|cff00ff00Saved %s %s|r", cat, slot))
                    end
                elseif action == "Load" then
                    info.func = function()
                        SynastriaPerkManager.LoadPerks(cat, slot)
                        print(string.format("|cff00ff00Loaded %s %s|r", cat, slot))
                        end
                elseif action == "Rename" then
                    info.func = function()
                        -- Get current name if you already have one stored (otherwise empty)
                        local currentName = SPMData.builds[cat] and SPMData.builds[cat][slot] and SynastriaPerkManager.GetSlotName(cat, slot) or ""
                        StaticPopup_Show("SPM_RENAME_BUILD", cat, slot, {
                            category    = cat,
                            slot        = slot,
                            currentName = currentName,
                        })
                    end
                elseif action == "Import" then
                    info.func = function()
                        print("This isn't done yet")
                    end
                elseif action == "Export" then
                    info.func = function()
                        print("This isn't done yet")
                    end
                else
                    print("WHAT DID YOU DO?! EVERYTHING'S ON FIRE!!!")
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end
    end

    for i, cat in ipairs(categories) do
        local dd = CreateFrame("Frame", "SynastriaPerkManagerDropdown_"..cat, masterFrame, "UIDropDownMenuTemplate")

        local x = (i <= 1) and 15 or 0
        local y = (i <= 1) and -25 or -50
        local anchor = dropdowns[categories[i-1]] or masterFrame
        --print(categories[i-1])
        --print(anchor)
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

        if cat == "Dual Class" or cat == "Build" then
            if CMCGetMultiClassEnabled() == 0 or cat == "Build" then
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
            --print(activePerkRank)
            textToChange = frameRef.cele.abnexttext
            if activePerkRank == 10 then
                textToChange = frameRef.cele.abcurtext
            end
            
            textToChange:SetText(CustomGenerateDescription(activePerk.desc, activePerk.levels[value].amounts, nil))
            
            --print(selectedPerkName..", ID: "..selectedPerkId)
            --print("Slider changed to:", value)
        end
    end)

    --print("SynastriaPerkManager width "..masterFrame:GetWidth())
    --print("SynastriaPerkManager width "..masterFrame:GetWidth())
end

function SynastriaPerkManager.StripColorCodes(text)
    if not text then return "" end
    -- Remove any |c followed by 8 hex chars, and any |r
    return text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end

function SPM_ShowPerkManagerFrame()
    if SynastriaPerkManager.frames.master == nil then
        SynastriaPerkManager.frames.master = CreateFrame('Frame', 'SynastriaPerkManagerMasterFrame', UIParent)
        SynastriaPerkManager.BuildPerkManagerFrame()
    end
    SynastriaPerkManager.frames.master:Show()
end

function SPM_HidePerkManagerFrame()
    SynastriaPerkManager.frames.master:Hide()
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
			_G["PerkMgrFrame"]:HookScript("OnShow", SPM_ShowPerkManagerFrame)
			_G["PerkMgrFrame"]:HookScript("OnHide", SPM_HidePerkManagerFrame)
            
            SynastriaPerkManager.UpdatePerkList()

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