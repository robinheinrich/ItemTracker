-- ToDo: Tooltip hinzufügen, um den Namen des Items anzuzeigen

-- Konstanten und Variablen
local GRID_SIZE_X = 10
local GRID_SIZE_Y = 2
local ICON_SIZE = 35
local items = {}

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


-- Die Anzahl aller Items im Grid aktualisieren
local function UpdateItemCount()
    for slotName, itemID in pairs(ItemTrackerGrid) do
        local slot = _G[slotName]  -- Hole den Slot über den globalen Namensraum
        if slot then
            slot.count:SetText(GetItemCount(itemID))
        end
    end
end

--------------------------------------------------------------------
-- 1. Funktion LoadSavedData definieren (vor ihrer Verwendung!)
local function LoadSavedData()
    for slotName, itemID in pairs(ItemTrackerGrid) do
        local slot = _G[slotName]  -- Hole den Slot über den globalen Namensraum
        if slot then
            local itemName, itemLink, _, _, _, _, _, _, _, itemTexture = GetItemInfo(itemID)
            if itemTexture then
                slot.icon:SetTexture(itemTexture)
            end
            slot.count:SetText(GetItemCount(itemID))
            -- items[self:GetName()] = itemLink
        end
    end
end

--------------------------------------------------------------------
-- ADDON_LOADED Event abfangen
ItemTracker:RegisterEvent("ADDON_LOADED")
ItemTracker:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "ItemTracker" then
        if ItemTrackerGrid == nil then
            ItemTrackerGrid = {}
        end
        if ItemTrackerConfig == nil then
            ItemTrackerConfig = {}
        end
        -- Jetzt wird LoadSavedData korrekt aufgerufen, da sie bereits definiert ist
        LoadSavedData()
    end
    -- Events für UpdateItemCount abfragen
    if event == "LOOT_OPENED" or "LOOT_CLOSED" or "MERCHANT_CLOSED" or "AUCTION_HOUSE_CLOSED" or "BANKFRAME_CLOSED" or "TRADE_CLOSED" then
        UpdateItemCount()
    end
end)

ItemTracker:RegisterEvent("LOOT_OPENED")
ItemTracker:RegisterEvent("LOOT_CLOSED")
ItemTracker:RegisterEvent("MERCHANT_CLOSED")
ItemTracker:RegisterEvent("AUCTION_HOUSE_CLOSED")
ItemTracker:RegisterEvent("BANKFRAME_CLOSED")
ItemTracker:RegisterEvent("TRADE_CLOSED")

--------------------------------------------------------------------
-- Funktion, um das Item und die Anzahl in das Grid einzufügen
local function FillButtonWithData(icon, itemLink, slot)
    slot.icon:SetTexture(icon)
    slot.count:SetText(GetItemCount(itemLink))
    -- Speichere den Slot-Eintrag in den SavedVariables
    ItemTrackerGrid[slot:GetName()] = itemLink
    items[slot:GetName()] = itemLink
end

--------------------------------------------------------------------
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
            
            -- Füge den Text hinzu
            slot.count = slot:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            slot.count:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", 0, 5)
            slot.count:SetTextColor(1, 1, 1, 1)
            
            slot:EnableMouse(true)
            slot:RegisterForDrag("LeftButton")
            slot:RegisterForClicks("AnyUp")
            
            -- Tooltip Handler onEnter und onLeave
            slot:SetScript("OnEnter", function(self)
                if items[self:GetName()] then  -- Prüfe, ob ein Item zugewiesen ist (oder alternativ ItemTrackerGrid)
                    local itemLink = items[self:GetName()]
                    local itemName = select(1, GetItemInfo(itemLink))
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(itemName or "Kein Item gefunden", 1, 1, 1)
                    GameTooltip:Show()
                end
            end)
            slot:SetScript("OnLeave", function(self)
                GameTooltip:Hide()
            end)

            -- OnClick zum Entfernen eines Items (Shift + Rechtsklick)
            slot:SetScript("OnClick", function(self, button)
                if button == "RightButton" and IsShiftKeyDown() then
                    self.icon:SetTexture(nil)
                    self.count:SetText("")
                    items[self:GetName()] = nil
                    ItemTrackerGrid[self:GetName()] = nil
                    
                end
            end)

            slot:SetScript("OnReceiveDrag", function(self)
                local cursorType, itemLink = GetCursorInfo()
                if cursorType == "item" and itemLink then
                    local itemName, _, _, _, _, _, _, _, _, itemTexture = GetItemInfo(itemLink)
                    if itemTexture then
                        FillButtonWithData(itemTexture, itemLink, self)
                    end
                    items[self:GetName()] = itemLink
                    ClearCursor()
                end
            end)
        end
    end
end
CreateGrid()

--------------------------------------------------------------------
-- Funktion, um die Anzahl eines bestimmten Items zu ermitteln
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
