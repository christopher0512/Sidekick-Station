----------------------------------------------------------
-- Side Kick station is for all your mount and pet needs
----------------------------------------------------------

-- ✅ Ensure the database exists before anything runs
	local function EnsureDatabaseExists()
		if not _G["SidekickStationDB"] then
			_G["SidekickStationDB"] = { iconData = { mounts = {}, pets = {} } }
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
    socket:SetSize(40, 40)
    socket:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset)
    socket.slotType = slotType
    socket:SetID(index)

    socket:EnableMouse(true)
    socket:RegisterForClicks("AnyUp")
    socket:RegisterForDrag("LeftButton")

-- ✅ Retrieve stored data for this socket
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

-- ✅ Click functionality
    socket:SetScript("OnClick", function(self)
        local clickedData = SidekickStationDB.iconData[self.slotType] and SidekickStationDB.iconData[self.slotType][self:GetID()]
        
        if clickedData then
            self.assignedId = clickedData.id
            self.assignedName = clickedData.name
            self.assignedIcon = clickedData.icon
            
            if self.slotType == "mounts" then
                C_MountJournal.SummonByID(self.assignedId)
            elseif self.slotType == "pets" then
                C_PetJournal.SummonPetByGUID(self.assignedId)
            else
                print("DEBUG: No valid action found for slotType: " .. tostring(self.slotType))
            end
        else
            print("DEBUG: No valid item found for this slotType: " .. tostring(self.slotType))
        end
    end)

-- ✅ Drag & drop functionality (Fixed)
    socket:SetScript("OnReceiveDrag", function(self)
        local cursorType, itemID, itemName, itemTexture = GetCursorInfo()

        if cursorType == "mount" then
            itemTexture = select(3, C_MountJournal.GetMountInfoByID(itemID))
        elseif cursorType == "battlepet" then
            local speciesID = C_PetJournal.GetPetInfoByPetID(itemID)
            itemName, itemTexture = C_PetJournal.GetPetInfoBySpeciesID(speciesID)
        else
            print("DEBUG: Unsupported item type dragged.")
            return
        end

        if itemID and itemTexture then
-- ✅ Assign item to the socket
            self.assignedId = itemID
            self.assignedName = itemName or "Unknown"
            self.assignedIcon = itemTexture

-- ✅ Update UI
            self:SetNormalTexture(self.assignedIcon)

-- ✅ Store data in SidekickStationDB
            SidekickStationDB.iconData[self.slotType][self:GetID()] = {
                id = self.assignedId,
                name = self.assignedName,
                icon = self.assignedIcon
            }

            print("DEBUG: Dragged item stored in SidekickStationDB. ID:", self.assignedId)
            ClearCursor()
        end
    end)

    return socket
end

----------------------------------------------------------
-- Create the main Sidekick Station UI
----------------------------------------------------------
	local SidekickStation = CreateFrame("Frame", "SidekickStationFrame", UIParent, "BackdropTemplate")
		SidekickStation:SetSize(230, 336)
		SidekickStation:SetPoint("CENTER")
		SidekickStation:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true, tileSize = 16, edgeSize = 16
		})
		SidekickStation:SetBackdropColor(0, 0, 0, 0.8)
		SidekickStation:Hide() -- ✅ UI no longer auto-opens

-- ✅ Make SidekickStation draggable
		SidekickStation:SetMovable(true)
		SidekickStation:EnableMouse(true)
		SidekickStation:RegisterForDrag("LeftButton")
		SidekickStation:SetScript("OnDragStart", function(self)
			self:StartMoving()
		end)
		SidekickStation:SetScript("OnDragStop", function(self)
			self:StopMovingOrSizing()
	end)
----------------------------------------------------------
-- Titles for Mounts & Pets sections
----------------------------------------------------------
local function CreateTitle(parent, text, xOffset)
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, -30)
    title:SetText("|cffFFD700" .. text .. "|r")
    return title
end

CreateTitle(SidekickStation, "Mounts", 30)
CreateTitle(SidekickStation, "Pets", 150)

----------------------------------------------------------
-- Title Bar
----------------------------------------------------------
	local titleBar = SidekickStation:CreateTexture(nil, "BACKGROUND")
	titleBar:SetSize(230, 30)
	titleBar:SetPoint("TOP", SidekickStation, "TOP", 0, 0)
	titleBar:SetColorTexture(0.5, 0, 0) -- Dark red background

	local titleText = SidekickStation:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	titleText:SetPoint("CENTER", titleBar, "CENTER", 0, -2)
	titleText:SetText("|cffffd700Sidekick Station|r") -- Yellow text

----------------------------------------------------------
-- Close Button
----------------------------------------------------------
	local closeButton = CreateFrame("Button", nil, SidekickStation, "UIPanelCloseButton")
	closeButton:SetPoint("TOPRIGHT", SidekickStation, "TOPRIGHT", -5, -5)
	closeButton:SetScript("OnClick", function() SidekickStation:Hide() end)

----------------------------------------------------------
-- Floating Button (Draggable)
----------------------------------------------------------
	local floatingButton = CreateFrame("Button", "SidekickFloatingButton", UIParent)
	floatingButton:SetSize(32, 32)
	floatingButton:SetPoint("CENTER", UIParent, "CENTER", 0, 200)

-- ✅ Circular icon with custom texture
	local buttonIcon = floatingButton:CreateTexture(nil, "ARTWORK")
	buttonIcon:SetTexture("Interface\\AddOns\\SidekickStation\\Textures\\SidekickStation.png")
	buttonIcon:SetSize(32, 32)
	buttonIcon:SetPoint("CENTER", floatingButton, "CENTER", 0, 0)
	buttonIcon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
	floatingButton:SetNormalTexture(buttonIcon)

-- ✅ Drag functionality - Freely moveable
	floatingButton:SetMovable(true)
	floatingButton:EnableMouse(true)
	floatingButton:RegisterForDrag("LeftButton")
	floatingButton:SetScript("OnDragStart", function(self)
		self:StartMoving()
	end)
	floatingButton:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
	end)

-- ✅ Tooltip
	floatingButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine("Sidekick Station - Mounts & Pets", 1, 1, 1)
		GameTooltip:Show()
	end)
	floatingButton:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

-- ✅ Click to toggle UI properly
	floatingButton:SetScript("OnClick", function()
		if SidekickStation:IsShown() then
			SidekickStation:Hide()
		else
			EnsureDatabaseExists()
			SidekickStationDB.iconData = SidekickStationDB.iconData or { mounts = {}, pets = {} }

			-- ✅ Maintain previous position
			local x, y = SidekickStation:GetLeft(), SidekickStation:GetTop()
			SidekickStation:ClearAllPoints()
			SidekickStation:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)

			-- ✅ Repopulate UI with stored mounts & pets
			for i = 0, 5 do
				CreateSidekickSocket(SidekickStation, "mounts", 20, -50 - (i * 45), i)
				CreateSidekickSocket(SidekickStation, "mounts", 64, -50 - (i * 45), i + 6)
				CreateSidekickSocket(SidekickStation, "pets", 126, -50 - (i * 45), i)
				CreateSidekickSocket(SidekickStation, "pets", 170, -50 - (i * 45), i + 6)
			end

			SidekickStation:Show()
		end
	end)