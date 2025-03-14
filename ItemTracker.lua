-- Konstanten und Variablen
local GRID_SIZE_X = 10
local GRID_SIZE_Y = 2
local ICON_SIZE = 35
local items = {}

-- SavedVariabels
ItemTrackerGrid = {}
ItemTrackerConfig = {}


-- Hauptframe erstellen
local ItemTracker = CreateFrame("Frame", "ItemTrackerFrame", UIParent, "BackdropTemplate")
ItemTracker:SetSize(ICON_SIZE * GRID_SIZE_X + 65, ICON_SIZE * GRID_SIZE_Y + 25)
ItemTracker:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

local backdrop = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
}
ItemTracker:SetBackdrop(backdrop)
ItemTracker:SetBackdropColor(0, 0, 0, 0.5)
ItemTracker:SetBackdropBorderColor(1, 1, 1, 1)

ItemTracker:EnableMouse(true)
ItemTracker:SetMovable(true)
ItemTracker:RegisterForDrag("LeftButton")
ItemTracker:SetScript("OnDragStart", ItemTracker.StartMoving)
ItemTracker:SetScript("OnDragStop", ItemTracker.StopMovingOrSizing)
ItemTracker:Show()




local function FillButtonWithData(icon, itemLink, slot)
    slot.icon:SetTexture(icon)
    slot.count:SetText(GetItemCount(itemLink))
    -- Item und Slot in SavedVariables speichern
    -- ItemTrackerGrid[slot:GetName()] = itemLink
end



-- Erstelle das Grid mit Drag & Drop Unterstützung pro Slot
local function CreateGrid()
    for row = 1, GRID_SIZE_Y do
        for col = 1, GRID_SIZE_X do
            local index = (row - 1) * GRID_SIZE_X + col
            local slot = CreateFrame("Button", "ItemSlot" .. index, ItemTracker, "BackdropTemplate")
            slot:SetSize(ICON_SIZE, ICON_SIZE)
            slot:SetPoint("TOPLEFT", (col - 1) * (ICON_SIZE + 5) + 10, -((row - 1) * (ICON_SIZE + 5) + 10))
            
            slot:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = false, edgeSize = 12,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
            slot:SetBackdropColor(0, 0, 0, 0.5)
            slot:SetBackdropBorderColor(1, 1, 1, 0.5)
            
            slot.icon = slot:CreateTexture(nil, "ARTWORK")
            slot.icon:SetAllPoints()
            slot.icon:SetTexture(nil)
            
            -- Hier wird der Text hinzugefügt
            slot.count = slot:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            slot.count:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", 0, 5)
            slot.count:SetTextColor(1, 1, 1, 1)
            
            -- Weitere Event-Registrierungen wie OnReceiveDrag etc.
            slot:EnableMouse(true)
            slot:RegisterForDrag("LeftButton")
            slot:SetScript("OnReceiveDrag", function(self)
                local cursorType, itemLink = GetCursorInfo()
                if cursorType == "item" and itemLink then
                    local itemName, _, _, _, _, _, _, _, _, itemTexture = GetItemInfo(itemLink)
                    if itemTexture then
                        -- self.icon:SetTexture(itemTexture)
                        FillButtonWithData(itemTexture, itemLink, self)
                    end
                    items[self:GetName()] = itemLink
                    -- print("Item '" .. (itemName or "Unbekannt") .. "' wurde in " .. self:GetName() .. " abgelegt!")
                    ClearCursor()
                end
            end)
        end
    end
    
end

print("CreateGrid wird aufgerufen")
CreateGrid()


-- Funktion, um die Anzahl eines bestimmten Items zu ermitteln (bleibt unverändert)
local function GetItemCount(itemID)
    local count = 0
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, GetContainerNumSlots(bag) do
            local _, itemCount, _, _, _, _, link = GetContainerItemInfo(bag, slot)
            if link then
                local _, _, id = string.find(link, "item:(%d+):")
                if tonumber(id) == itemID then
                    count = count + itemCount
                end
            end
        end
    end
    return count
end