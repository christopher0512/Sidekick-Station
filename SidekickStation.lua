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
            windowOpen = true,
            minimapAngle = 0 -- default: right side
        }
    end
    SidekickStationDB = _G["SidekickStationDB"]
end

EnsureDatabaseExists()

----------------------------------------------------------
-- Fade-In Animation
----------------------------------------------------------
local function FadeInFrame(frame)
    if frame.fadeGroup then
        frame.fadeGroup:Stop()
    end

    local ag = frame:CreateAnimationGroup()
    frame.fadeGroup = ag

    local fade = ag:CreateAnimation("Alpha")
    fade:SetFromAlpha(0)
    fade:SetToAlpha(1)
    fade:SetDuration(0.25)
    fade:SetSmoothing("IN")

    ag:Play()
end

----------------------------------------------------------
-- Create Sidekick Sockets
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
            SidekickStationDB.iconData[self.slotType][self:GetID()] = nil
            self.assignedId = nil
            self.assignedName = "Unknown"
            self.assignedIcon = "Interface\\Icons\\INV_Misc_QuestionMark"
            self:SetNormalTexture(self.assignedIcon)
        else
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
-- Close Button
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
-- Minimap Button (Correct Blizzard-Style Implementation)
----------------------------------------------------------
local minimapButton = CreateFrame("Button", "SidekickStationMinimapButton", UIParent)
minimapButton:SetSize(32, 32)
minimapButton:SetFrameStrata("MEDIUM")

----------------------------------------------------------
-- Circular Mask (does NOT dim the icon)
----------------------------------------------------------
local mask = minimapButton:CreateMaskTexture()
mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
mask:SetAllPoints(minimapButton)

----------------------------------------------------------
-- Icon (your .webp texture)
----------------------------------------------------------
local icon = minimapButton:CreateTexture(nil, "ARTWORK")
icon:SetTexture("Interface\\AddOns\\SidekickStation\\Textures\\SidekickStation.png")
icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
icon:SetAllPoints(minimapButton)
icon:AddMaskTexture(mask)

----------------------------------------------------------
-- Border (Blizzard standard)
----------------------------------------------------------
local border = minimapButton:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetSize(58, 58)
border:SetPoint("CENTER", minimapButton, "CENTER", 11, -12)

----------------------------------------------------------
-- Positioning (radius increased so button is OUTSIDE)
----------------------------------------------------------
local function UpdateMinimapButtonPosition()
    EnsureDatabaseExists()

    if type(SidekickStationDB.minimapAngle) ~= "number" then
        SidekickStationDB.minimapAngle = 0
    end

    local angle = SidekickStationDB.minimapAngle
    local radius = 106  -- increased from 80 → pushes button OUTSIDE the minimap

    local x = math.cos(math.rad(angle)) * radius
    local y = math.sin(math.rad(angle)) * radius

    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

----------------------------------------------------------
-- Dragging (No Taint)
----------------------------------------------------------
minimapButton:RegisterForDrag("LeftButton")
minimapButton:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()

        px = px / scale
        py = py / scale

        local angle = math.deg(math.atan2(py - my, px - mx))
        SidekickStationDB.minimapAngle = angle

        UpdateMinimapButtonPosition()
    end)
end)

minimapButton:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
end)

----------------------------------------------------------
-- Click Behavior
----------------------------------------------------------
minimapButton:SetScript("OnClick", function()
    if SidekickStationFrame:IsShown() then
        SidekickStationFrame:Hide()
        SidekickStationDB.windowOpen = false
    else
        CreateAllSockets()
        SidekickStationFrame:Show()
        FadeInFrame(SidekickStationFrame)
        SidekickStationDB.windowOpen = true
    end
end)

----------------------------------------------------------
-- Tooltip
----------------------------------------------------------
minimapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Sidekick Station", 1, 1, 1)
    GameTooltip:AddLine("Left-Click: Toggle Window", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)

minimapButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)
minimapButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

----------------------------------------------------------
-- Auto-Open on Login
----------------------------------------------------------
local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:SetScript("OnEvent", function()
    EnsureDatabaseExists()

    if type(SidekickStationDB.minimapAngle) ~= "number" then
        SidekickStationDB.minimapAngle = 0
    end

    CreateAllSockets()
    UpdateMinimapButtonPosition()

    if SidekickStationDB.windowOpen then
        SidekickStationFrame:Show()
        FadeInFrame(SidekickStationFrame)
    end
end)