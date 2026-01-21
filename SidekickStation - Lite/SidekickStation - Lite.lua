----------------------------------------------------------
-- Sidekick Station Lite: Mount and Pet Organization
----------------------------------------------------------

-- ✅ Ensure the database exists before anything runs
local function EnsureDatabaseExists()
    if not _G["SidekickStationDB_Lite"] then
        _G["SidekickStationDB_Lite"] = { iconData = { mounts = {}, pets = {} } }
    end
    SidekickStationDB_Lite = _G["SidekickStationDB_Lite"]
end

EnsureDatabaseExists()

----------------------------------------------------------
-- Create Sidekick Sockets (Drag-and-Drop Slots)
----------------------------------------------------------
local function CreateSidekickSocket(parent, slotType, xOffset, yOffset, index)
    EnsureDatabaseExists()

    local socket = CreateFrame("Button", nil, parent)
    socket:SetSize(36, 36)
    socket:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset)
    socket.slotType = slotType
    socket:SetID(index)

    socket:EnableMouse(true)
    socket:RegisterForClicks("AnyUp")
    socket:RegisterForDrag("LeftButton")

    -- ✅ Tooltip Logic
    socket:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")

        if self.assignedId then
            if self.slotType == "mounts" then
                local name = C_MountJournal.GetMountInfoByID(self.assignedId)
                GameTooltip:SetText(name or "Unknown Mount")
            elseif self.slotType == "pets" then
                local speciesID = C_PetJournal.GetPetInfoByPetID(self.assignedId)
                local petName = C_PetJournal.GetPetInfoBySpeciesID(speciesID)
                GameTooltip:SetText(petName or "Unknown Pet")
            else
                GameTooltip:SetText("Item not recognized")
            end
        else
            GameTooltip:SetText("Drag a Favorite here to Socket Them")
        end

        GameTooltip:Show()
    end)

    socket:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- ✅ Retrieve stored data for this socket
    local savedData = SidekickStationDB_Lite.iconData[slotType][index]
    if savedData and savedData.id then
        socket.assignedId = savedData.id
        socket.assignedName = savedData.name
        socket.assignedIcon = savedData.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
        socket:SetNormalTexture(socket.assignedIcon)
    else
        socket.assignedId = nil
        socket.assignedName = "Unknown"
        socket.assignedIcon = "Interface\\Icons\\INV_Misc_QuestionMark"
        socket:SetNormalTexture(socket.assignedIcon)
    end

    -- ✅ Click functionality
    socket:SetScript("OnClick", function(self, button)
        if IsShiftKeyDown() and button == "LeftButton" then
            -- ✅ Clear socket contents
            SidekickStationDB_Lite.iconData[self.slotType][self:GetID()] = nil
            self.assignedId = nil
            self.assignedName = "Unknown"
            self.assignedIcon = "Interface\\Icons\\INV_Misc_QuestionMark"
            self:SetNormalTexture(self.assignedIcon)
        else
            -- ✅ Normal behavior: Summon mount/pet if assigned
            local clickedData = SidekickStationDB_Lite.iconData[self.slotType] and SidekickStationDB_Lite.iconData[self.slotType][self:GetID()]

            if clickedData then
                self.assignedId = clickedData.id
                self.assignedName = clickedData.name
                self.assignedIcon = clickedData.icon
                
                if self.slotType == "mounts" then
                    C_MountJournal.SummonByID(self.assignedId)
                elseif self.slotType == "pets" then
                    C_PetJournal.SummonPetByGUID(self.assignedId)
                end
            end
        end
    end)

    -- ✅ Drag & drop functionality
    socket:SetScript("OnReceiveDrag", function(self)
        local cursorType, itemID, itemName, itemTexture = GetCursorInfo()

        if cursorType == "mount" then
            itemTexture = select(3, C_MountJournal.GetMountInfoByID(itemID))
        elseif cursorType == "battlepet" then
            local speciesID = C_PetJournal.GetPetInfoByPetID(itemID)
            itemName, itemTexture = C_PetJournal.GetPetInfoBySpeciesID(speciesID)
        else
            print("Unsupported item type dragged.")
            return
        end

        -- ✅ Assign item to the socket
        if itemID and itemTexture then
            self.assignedId = itemID
            self.assignedName = itemName or "Unknown"
            self.assignedIcon = itemTexture
            self:SetNormalTexture(self.assignedIcon)

            -- ✅ Store data in SidekickStationDB_Lite
            SidekickStationDB_Lite.iconData[self.slotType][self:GetID()] = {
                id = self.assignedId,
                name = self.assignedName,
                icon = self.assignedIcon
            }
            ClearCursor()
        end
    end)

    return socket
end
----------------------------------------------------------
-- Create the main Sidekick Station Lite UI
----------------------------------------------------------
local SidekickStationLite = CreateFrame("Frame", "SidekickStationLiteFrame", UIParent, "BackdropTemplate")
SidekickStationLite:SetSize(160, 216) -- ✅ Resized for new layout
SidekickStationLite:SetPoint("CENTER")
SidekickStationLite:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 16
})
SidekickStationLite:SetBackdropColor(0, 0, 0, 0.8)
SidekickStationLite:Hide() -- ✅ UI no longer auto-opens

-- ✅ Make SidekickStationLite draggable
SidekickStationLite:SetMovable(true)
SidekickStationLite:EnableMouse(true)
SidekickStationLite:RegisterForDrag("LeftButton")
SidekickStationLite:SetScript("OnDragStart", function(self) self:StartMoving() end)
SidekickStationLite:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

----------------------------------------------------------
-- Titles for Mounts & Pets sections
----------------------------------------------------------
local function CreateTitle(parent, text, xOffset)
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, -30)
    title:SetText("|cffFFD700" .. text .. "|r")
    return title
end

CreateTitle(SidekickStationLite, "Mounts", 20)
CreateTitle(SidekickStationLite, "Pets", 110)

----------------------------------------------------------
-- Close Button
----------------------------------------------------------
local closeButton = CreateFrame("Button", nil, SidekickStationLite, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", SidekickStationLite, "TOPRIGHT", -5, -5)
closeButton:SetScript("OnClick", function() SidekickStationLite:Hide() end)

----------------------------------------------------------
-- Title Bar
----------------------------------------------------------
local titleBar = SidekickStationLite:CreateTexture(nil, "BACKGROUND")
titleBar:SetSize(160, 30) -- Adjusted for Lite version
titleBar:SetPoint("TOP", SidekickStationLite, "TOP", 0, 0)
titleBar:SetColorTexture(0.5, 0, 0) -- Dark red background

local titleText = SidekickStationLite:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
titleText:SetPoint("CENTER", titleBar, "CENTER", -4, -2)
titleText:SetText("|cffffd700Sidekicks|r") -- Yellow text

----------------------------------------------------------
-- Floating Button (Draggable)
----------------------------------------------------------
local floatingButton = CreateFrame("Button", "SidekickFloatingButtonLite", UIParent)
floatingButton:SetSize(32, 32)
floatingButton:SetPoint("CENTER", UIParent, "CENTER", 0, 200)

-- ✅ Circular icon with custom texture
local buttonIcon = floatingButton:CreateTexture(nil, "ARTWORK")
buttonIcon:SetTexture("Interface\\AddOns\\SidekickStation - Lite\\Textures\\SidekickStation.png")
buttonIcon:SetSize(32, 32)
buttonIcon:SetPoint("CENTER", floatingButton, "CENTER", 0, 0)
-- buttonIcon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
	buttonIcon:SetTexCoord(0.15, 0.85, 0.15, 0.85) -- Crops edges for a rounded look
floatingButton:SetNormalTexture(buttonIcon)

-- ✅ Drag functionality - Freely movable
floatingButton:SetMovable(true)
floatingButton:EnableMouse(true)
floatingButton:RegisterForDrag("LeftButton")
floatingButton:SetScript("OnDragStart", function(self) self:StartMoving() end)
floatingButton:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

-- ✅ Tooltip
floatingButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Sidekick Station Lite - Streamlined Mounts & Pets", 1, 1, 1)
    GameTooltip:Show()
end)
floatingButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- ✅ Click to toggle UI properly
floatingButton:SetScript("OnClick", function()
    if SidekickStationLite:IsShown() then
        SidekickStationLite:Hide()
    else
        EnsureDatabaseExists()
        SidekickStationDB_Lite.iconData = SidekickStationDB_Lite.iconData or { mounts = {}, pets = {} }

        -- ✅ Maintain previous position
        local x, y = SidekickStationLite:GetLeft(), SidekickStationLite:GetTop()
        SidekickStationLite:ClearAllPoints()
        SidekickStationLite:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)

-- ✅ Create sockets (5 rows, 2 columns for mounts, 1 column for pets)
for i = 0, 3 do  -- Adjusted to exclude row 6
    CreateSidekickSocket(SidekickStationLite, "mounts", 16, -50 - (i * 40), i)  -- Column 1 (Mounts)
    CreateSidekickSocket(SidekickStationLite, "mounts", 60, -50 - (i * 40), i + 5)  -- Column 2 (Mounts)
    CreateSidekickSocket(SidekickStationLite, "pets", 110, -50 - (i * 40), i)  -- Column 3 (Pets)
end

        SidekickStationLite:Show()
    end
end)
