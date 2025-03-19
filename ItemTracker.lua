-- Written by: Rob
-- Description: Ein einfaches Addon, um Items mit der Anzahl in einem Grid anzuzeigen
-- Version: v1.0

-- Konstanten und Variablen
local GRID_SIZE_X = 10  -- Anzahl der Spalten
local GRID_SIZE_Y = 2   -- Anzahl der Zeilen
local ICON_SIZE = 35    -- Größe der Icons
local items = {}        -- Tabelle für die Items

-- SavedVAriables erstellen, wenn sie noch nicht existieren
if not ItemTrackerGrid then
    ItemTrackerGrid = {}
end
if not ItemTrackerConfig then
    ItemTrackerConfig = {}
end

-- CharacerID und Realm für SavedVariables erstellen
local characterName, realm = UnitFullName("player")
if not realm then
    realm = GetRealmName()
end
characterID = characterName .. "-" .. realm

-- Hauptframe erstellen
local ItemTracker = CreateFrame("Frame", "ItemTrackerFrame", UIParent, "BackdropTemplate")
-- Größe und Position des Frames relativ zu der Größe der Buttons
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
ItemTracker:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    -- Abfragen der aktuellen Position
    local point, relativeTo, relativePoint, xOffset, yOffset = self:GetPoint(1)
  
    -- ToDo Config an andere Position setzen
    ItemTrackerConfig[characterID].framePosition = {
        point = point,
        relativePoint = relativePoint,
        x = xOffset,
        y = yOffset
    }
end)

ItemTracker:Show()

-- Die Items im Grid aktualisieren
local function UpdateItemCount()
    for slotName, itemID in pairs(ItemTrackerGrid[characterID]) do
        local slot = _G[slotName]  -- Hole den Slot über den globalen Namensraum
        if slot then
            local itemName, itemLink, _, _, _, _, _, _, _, itemTexture = GetItemInfo(itemID)
            if itemTexture then
                slot.icon:SetTexture(itemTexture)
            end
            slot.count:SetText(GetItemCount(itemID))
        end
    end
end

--------------------------------------------------------------------
-- Funktion, um die gespeicherten Daten zu laden
local function LoadSavedData()
    for slotName, itemID in pairs(ItemTrackerGrid[characterID]) do
        local slot = _G[slotName]  -- Hole den Slot über den globalen Namensraum
        if slot then
            local itemName, itemLink, _, _, _, _, _, _, _, itemTexture = GetItemInfo(itemID)
            if itemTexture then
                slot.icon:SetTexture(itemTexture)
            end
            slot.count:SetText(GetItemCount(itemID))
            items[slot:GetName()] = itemID
        end
    end
end

--------------------------------------------------------------------
-- Events abfangen und verarbeiten
ItemTracker:SetScript("OnEvent", function(self, event, addonName)
    -- Prüfe, ob das Addon "ItemTracker" geladen wurde
    if addonName == "ItemTracker" then
        -- Initialisiere die SavedVariables
        if ItemTrackerGrid[characterID] == nil then
            ItemTrackerGrid[characterID] = {}
        end
        if ItemTrackerConfig[characterID] == nil then
            ItemTrackerConfig[characterID] = {}
        end
        
        -- Icon Size laden
        if ItemTrackerConfig[characterID].iconSize then
            ICON_SIZE = ItemTrackerConfig[characterID].iconSize
        end

        -- Position des Frames laden
        if ItemTrackerConfig[characterID].framePosition then
            ItemTracker:ClearAllPoints()
            ItemTracker:SetPoint(ItemTrackerConfig[characterID].framePosition.point, UIParent, ItemTrackerConfig[characterID].framePosition.relativePoint, ItemTrackerConfig[characterID].framePosition.x, ItemTrackerConfig[characterID].framePosition.y)
        end

        -- Gespeicherte Daten laden
        LoadSavedData()

    end
    -- Events für UpdateItemCount abfragen
    if event == "LOOT_OPENED" or event == "LOOT_CLOSED" or event == "MERCHANT_CLOSED" or event == "AUCTION_HOUSE_CLOSED" or event == "BANKFRAME_CLOSED" or event == "TRADE_CLOSED" then
        UpdateItemCount()
    end
end)

-- Events registrieren
ItemTracker:RegisterEvent("ADDON_LOADED")
ItemTracker:RegisterEvent("AUCTION_HOUSE_CLOSED")
ItemTracker:RegisterEvent("BANKFRAME_CLOSED")
ItemTracker:RegisterEvent("LOOT_CLOSED")
ItemTracker:RegisterEvent("LOOT_OPENED")
ItemTracker:RegisterEvent("MERCHANT_CLOSED")
ItemTracker:RegisterEvent("TRADE_CLOSED")

--------------------------------------------------------------------
-- Funktion, um das Item und die Anzahl in das Grid einzufügen
local function FillButtonWithData(icon, itemLink, slot)
    slot.icon:SetTexture(icon)
    slot.count:SetText(GetItemCount(itemLink))
    -- Speichere den Slot-Eintrag in den SavedVariables
    ItemTrackerGrid[characterID][slot:GetName()] = itemLink
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
            -- OnLeave Event Handler (Frame)
            slot:SetScript("OnLeave", function(self)
                GameTooltip:Hide()
            end)

            -- OnClick Handler: Entfernen eines Items (Shift + Rechtsklick)
            slot:SetScript("OnClick", function(self, button)
                if button == "RightButton" and IsShiftKeyDown() then
                    self.icon:SetTexture(nil)
                    self.count:SetText("")
                    items[self:GetName()] = nil
                    ItemTrackerGrid[characterID][self:GetName()] = nil
                    
                end
            end)

            -- Receive Drag Event für die Buttons
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
-- Funktion, um die Anzahl eines bestimmten Items anhand der itemID zu ermitteln
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


-- Registriere den Slash-Befehl "/IT"
SLASH_ITEMTRACKER1 = "/IT"
SlashCmdList["ITEMTRACKER"] = function(msg)
    -- ButtonSize Befehl
    local newSize = string.match(msg, "-size:(%d+)")
    if newSize then
        newSize = tonumber(newSize)
        ItemTracker:SetSize(newSize * GRID_SIZE_X + 65, newSize * GRID_SIZE_Y + 25)
        local oldSize = ICON_SIZE
        ICON_SIZE = newSize
        print("Size-Wert auf " .. newSize .. " geändert. (War " .. oldSize .. ")")
        ItemTrackerConfig[characterID].iconSize = newSize

        -- Alle Buttons an Größe sowie Position anpassen:
        for i = 1, (GRID_SIZE_X * GRID_SIZE_Y) do
            local btn = _G["ItemSlot" .. i]
            if btn then
                btn:SetSize(newSize, newSize)
                -- Berechne die neue Position: Bestimme Zeile und Spalte
                local row = math.floor((i - 1) / GRID_SIZE_X) + 1
                local col = ((i - 1) % GRID_SIZE_X) + 1
                btn:ClearAllPoints()
                btn:SetPoint("TOPLEFT", ItemTracker, "TOPLEFT", (col - 1) * (newSize + 5) + 10, -((row - 1) * (newSize + 5) + 10))
            end
        end
        
    else
        print("Ungültiger Befehl. Beispiel: /IT -size:44")
    end

    local settoDefaultSize = string.match(msg, "-ds")
    if settoDefaultSize then
        ItemTracker:SetSize(ItemTrackerConfig[characterID].DefaultButtonSize * GRID_SIZE_X + 65, ItemTrackerConfig[characterID].DefaultButtonSize * GRID_SIZE_Y + 25)
        print("Größe auf Standardgröße zurückgesetzt.")
        ItemTrackerConfig[characterID].iconSize = ItemTrackerConfig[characterID].DefaultButtonSize
    end
end