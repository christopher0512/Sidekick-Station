----------------------------------------------------------
-- Sidekick Station: Mount and Pet Organizer
----------------------------------------------------------

----------------------------------------------------------
-- Database Initialization
----------------------------------------------------------
local function EnsureDatabaseExists()
    if not _G["SidekickStationDB"] then
        _G["SidekickStationDB"] = {
            iconData = { mounts = {}, pets = {} },
            windowOpen = true
        }
    end
    SidekickStationDB = _G["SidekickStationDB"]
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

    ------------------------------------------------------
    -- Tooltip
    ------------------------------------------------------
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
            end
        else
            GameTooltip:SetText("Drag a Favorite here to Socket Them")
        end

        GameTooltip:Show()
    end)

    socket:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    ------------------------------------------------------
    -- Load Saved Data
    ------------------------------------------------------
    local savedData = SidekickStationDB.iconData[slotType][index]
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

    ------------------------------------------------------
    -- Click Behavior
    ------------------------------------------------------
    socket:SetScript("OnClick", function(self, button)
        if IsShiftKeyDown() and button == "LeftButton" then
            -- Clear socket
            SidekickStationDB.iconData[self.slotType][self:GetID()] = nil
            self.assignedId = nil
            self.assignedName = "Unknown"
            self.assignedIcon = "Interface\\Icons\\INV_Misc_QuestionMark"
            self:SetNormalTexture(self.assignedIcon)
        else
            -- Summon assigned mount/pet
            local clickedData = SidekickStationDB.iconData[self.slotType][self:GetID()]
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

    ------------------------------------------------------
    -- Drag-and-Drop Assignment
    ------------------------------------------------------
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

        if itemID and itemTexture then
            self.assignedId = itemID
            self.assignedName = itemName or "Unknown"
            self.assignedIcon = itemTexture
            self:SetNormalTexture(self.assignedIcon)

            SidekickStationDB.iconData[self.slotType][self:GetID()] = {
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
-- Main UI Frame
----------------------------------------------------------
local SidekickStationFrame = CreateFrame("Frame", "SidekickStationFrame", UIParent, "BackdropTemplate")
SidekickStationFrame:SetSize(160, 216)
SidekickStationFrame:SetPoint("CENTER")
SidekickStationFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 16
})
SidekickStationFrame:SetBackdropColor(0, 0, 0, 0.8)
SidekickStationFrame:Hide()

SidekickStationFrame:SetMovable(true)
SidekickStationFrame:EnableMouse(true)
SidekickStationFrame:RegisterForDrag("LeftButton")
SidekickStationFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
SidekickStationFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

----------------------------------------------------------
-- Titles
----------------------------------------------------------
local function CreateTitle(parent, text, xOffset)
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, -30)
    title:SetText("|cffFFD700" .. text .. "|r")
    return title
end

CreateTitle(SidekickStationFrame, "Mounts", 20)
CreateTitle(SidekickStationFrame, "Pets", 110)

----------------------------------------------------------
-- Close Button (Saves State)
----------------------------------------------------------
local closeButton = CreateFrame("Button", nil, SidekickStationFrame, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", SidekickStationFrame, "TOPRIGHT", -5, -5)
closeButton:SetScript("OnClick", function()
    SidekickStationFrame:Hide()
    SidekickStationDB.windowOpen = false
end)

----------------------------------------------------------
-- Title Bar
----------------------------------------------------------
local titleBar = SidekickStationFrame:CreateTexture(nil, "BACKGROUND")
titleBar:SetSize(160, 30)
titleBar:SetPoint("TOP", SidekickStationFrame, "TOP", 0, 0)
titleBar:SetColorTexture(0.5, 0, 0)

local titleText = SidekickStationFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
titleText:SetPoint("CENTER", titleBar, "CENTER", -4, -2)
titleText:SetText("|cffffd700Sidekicks|r")

----------------------------------------------------------
-- Create Sockets Once
----------------------------------------------------------
local socketsCreated = false

local function CreateAllSockets()
    if socketsCreated then return end
    socketsCreated = true

    for i = 0, 3 do
        CreateSidekickSocket(SidekickStationFrame, "mounts", 16, -50 - (i * 40), i)
        CreateSidekickSocket(SidekickStationFrame, "mounts", 60, -50 - (i * 40), i + 5)
        CreateSidekickSocket(SidekickStationFrame, "pets", 110, -50 - (i * 40), i)
    end
end

----------------------------------------------------------
-- Floating Button
----------------------------------------------------------
local floatingButton = CreateFrame("Button", "SidekickFloatingButton", UIParent)
floatingButton:SetSize(32, 32)
floatingButton:SetPoint("CENTER", UIParent, "CENTER", 0, 200)

local buttonIcon = floatingButton:CreateTexture(nil, "ARTWORK")
buttonIcon:SetTexture("Interface\\AddOns\\SidekickStation\\Textures\\SidekickStation.png")
buttonIcon:SetSize(32, 32)
buttonIcon:SetPoint("CENTER", floatingButton, "CENTER", 0, 0)
buttonIcon:SetTexCoord(0.15, 0.85, 0.15, 0.85)
floatingButton:SetNormalTexture(buttonIcon)

floatingButton:SetMovable(true)
floatingButton:EnableMouse(true)
floatingButton:RegisterForDrag("LeftButton")
floatingButton:SetScript("OnDragStart", function(self) self:StartMoving() end)
floatingButton:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

floatingButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Sidekick Station - Mounts & Pets", 1, 1, 1)
    GameTooltip:Show()
end)
floatingButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

floatingButton:SetScript("OnClick", function()
    EnsureDatabaseExists()

    if SidekickStationFrame:IsShown() then
        SidekickStationFrame:Hide()
        SidekickStationDB.windowOpen = false
    else
        CreateAllSockets()
        SidekickStationFrame:Show()
        SidekickStationDB.windowOpen = true
    end
end)

----------------------------------------------------------
-- Auto-Open on Login
----------------------------------------------------------
local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:SetScript("OnEvent", function()
    EnsureDatabaseExists()
    CreateAllSockets()

    if SidekickStationDB.windowOpen then
        SidekickStationFrame:Show()
    end
end)