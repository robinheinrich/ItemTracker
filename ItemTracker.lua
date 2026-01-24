-- Written by: Rob
-- Description: Ein einfaches Addon, um Items mit der Anzahl in einem Grid anzuzeigen
-- Version: v1.1 (Midnight Compatible)

-- Konstanten und Variablen
local GRID_SIZE_X = 10  -- Anzahl der Spalten
local GRID_SIZE_Y = 2   -- Anzahl der Zeilen
local ICON_SIZE = 35    -- Größe der Icons
local items = {}        -- Tabelle für die Items

-- Midnight Kompatibilität: Diese Konstanten wurden in 12.0.0 entfernt
local NUM_BAG_SLOTS = NUM_BAG_SLOTS or 4  -- Fallback: 4 normale Inventar-Taschen (0-4)
local NUM_BANKBAGSLOTS = 7  -- 7 Bank-Taschen (Bag IDs 5-11)


-- Qualitätsstufen für die Overlay-Icons
local atlasNames = {
    [1] = "Professions-Icon-Quality-Tier1",
    [2] = "Professions-Icon-Quality-Tier2",
    [3] = "Professions-Icon-Quality-Tier3"
}


-- SavedVariables erstellen, wenn sie noch nicht existieren
if not ItemTrackerGrid then
    ItemTrackerGrid = {}
end
if not ItemTrackerConfig then
    ItemTrackerConfig = {}
end

-- CharacterID und Realm für SavedVariables erstellen
local characterName, realm = UnitFullName("player")
if not realm then
    realm = GetRealmName()
end
realm = realm:gsub("%s+", "")  -- Leerzeichen entfernen, da der Server manchmal anders reagiert
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
ItemTracker:RegisterForDrag("RightButton")
-- OnDragStart: Verwende eine anonyme Funktion, die die Methode des Frames aufruft.
-- Direkter Verweis auf ItemTracker.StartMoving ist nicht zuverlässig, da StartMoving
-- als Methode über das Frame-Metatable bereitgestellt wird.
ItemTracker:SetScript("OnDragStart", function(self) self:StartMoving() end)
ItemTracker:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    -- Abfragen der aktuellen Position
    local point, relativeTo, relativePoint, xOffset, yOffset = self:GetPoint(1)
  
    -- Position des Frames in Config speichern
    ItemTrackerConfig[characterID].framePosition = {
        point = point,
        relativePoint = relativePoint,
        x = xOffset,
        y = yOffset
    }
end)

ItemTracker:Show()

--------------------------------------------------------------------
-- Funktion, um die Anzahl eines bestimmten Items anhand der itemID zu ermitteln
-- Diese lokale Funktion wird verwendet, um Items in den Bags zu zählen
local function GetItemCount(itemID, includeBank)
    -- Nutze die neue C_Container API
    local count = 0
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
            if itemInfo and itemInfo.hyperlink then
                local _, _, id = string.find(itemInfo.hyperlink, "item:(%d+):")
                if tonumber(id) == tonumber(itemID) then
                    count = count + itemInfo.stackCount
                end
            end
        end
    end
    
    -- Bank einbeziehen wenn includeBank true ist
    if includeBank then
        for bag = NUM_BAG_SLOTS + 1, NUM_BAG_SLOTS + NUM_BANKBAGSLOTS do
            for slot = 1, C_Container.GetContainerNumSlots(bag) do
                local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
                if itemInfo and itemInfo.hyperlink then
                    local _, _, id = string.find(itemInfo.hyperlink, "item:(%d+):")
                    if tonumber(id) == tonumber(itemID) then
                        count = count + itemInfo.stackCount
                    end
                end
            end
        end
    end
    
    return count
end

--------------------------------------------------------------------
local function setSlotContent(itemTexture, itemLink, slot, itemID)
    if itemTexture then
        slot.icon:SetTexture(itemTexture)
        local quality = itemLink and itemLink:match("Quality%-Tier(%d)")
        if quality then
            slot.qualityOverlay:SetAtlas(atlasNames[tonumber(quality)])
            slot.qualityOverlay:Show()
        else
            slot.qualityOverlay:SetTexture(nil) -- Kein Overlay wenn keine Qualität zurückgegeben wurde
            slot.qualityOverlay:Hide()
        end
    end
    slot.count:SetText(GetItemCount(itemID, true) or 0)
end


-- Die Items im Grid aktualisieren
local function UpdateItemCount()
    for slotName, itemID in pairs(ItemTrackerGrid[characterID]) do
        local slot = _G[slotName]  -- Hole den Slot über den globalen Namensraum
        if slot then
            local itemName, itemLink, _, _, _, _, _, _, _, itemTexture = C_Item.GetItemInfo(itemID)
            if itemName then
                setSlotContent(itemTexture, itemLink, slot, itemID) -- Textur, Text und Quali im Grid schreiben
            end
        end
    end
end

--------------------------------------------------------------------
-- Funktion, um die gespeicherten Daten zu laden
local function LoadSavedData()
    for slotName, itemID in pairs(ItemTrackerGrid[characterID]) do
        local slot = _G[slotName]  -- Hole den Slot über den globalen Namensraum
        if slot then
            local itemName, itemLink, _, _, _, _, _, _, _, itemTexture = C_Item.GetItemInfo(itemID)
            if itemName then
                setSlotContent(itemTexture, itemLink, slot, itemID) -- Textur, Text und Quali im Grid schreiben
                items[slot:GetName()] = itemID
            end
        end
    end
end

--------------------------------------------------------------------
-- Events abfangen und verarbeiten
ItemTracker:SetScript("OnEvent", function(self, event, addonName)
    -- Prüfe, ob das Addon "ItemTracker" geladen wurde
    if event == "ADDON_LOADED" and addonName == "ItemTracker" then
        -- Initialisiere die SavedVariables
        if not ItemTrackerGrid[characterID] then
            ItemTrackerGrid[characterID] = {}
        end
        if not ItemTrackerConfig[characterID] then
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

    -- Events für UpdateItemCount abfragen
    elseif event == "LOOT_OPENED" or event == "LOOT_CLOSED" or event == "MERCHANT_CLOSED" or event == "AUCTION_HOUSE_CLOSED" or event == "BANKFRAME_CLOSED" or event == "TRADE_CLOSED" or event == "BAG_UPDATE_DELAYED" then
        UpdateItemCount()
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        -- Item info wurde empfangen, update die Anzeige
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
ItemTracker:RegisterEvent("BAG_UPDATE_DELAYED")  -- Neues Event für Bag-Updates
ItemTracker:RegisterEvent("GET_ITEM_INFO_RECEIVED")  -- Für asynchrone Item-Info

--------------------------------------------------------------------
-- Funktion, um das Item und die Anzahl in das Grid einzufügen
local function FillButtonWithData(icon, itemLink, slot)
    slot.icon:SetTexture(icon)
    slot.count:SetText(C_Item.GetItemCount(itemLink, true) or 0)
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
            -- local slot = CreateFrame("Button", "ItemSlot" .. index, ItemTracker, "BackdropTemplate")
            local slot = CreateFrame("Button", "ItemSlot"..index, ItemTracker, "ItemButtonTemplate")
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
            
            slot:RegisterForDrag("LeftButton")
            slot:EnableMouse(true)
            slot:RegisterForClicks("AnyUp")

            slot.qualityOverlay = slot:CreateTexture(nil, "OVERLAY")
            slot.qualityOverlay:SetSize(20, 20) -- Todo: Größe abhängig von Icon machen
            slot.qualityOverlay:SetPoint("TOPLEFT", slot, "TOPLEFT", -5, 5)
            slot.qualityOverlay:SetAlpha(1) -- Transparenz des Overlays
            slot.qualityOverlay:SetTexture(nil) -- initial leer
            
            -- Tooltip Handler onEnter und onLeave
            slot:SetScript("OnEnter", function(self)
                -- Hol den gespeicherten Wert (kann Item-Link (string) oder Item-ID (number) sein)
                local stored = items[self:GetName()]
                -- Fallback auf SavedVariables, falls items noch nicht initialisiert ist
                if not stored and ItemTrackerGrid and ItemTrackerGrid[characterID] then
                    stored = ItemTrackerGrid[characterID][self:GetName()]
                end

                -- Versuche, aus dem gespeicherten Wert einen gültigen item-hyperlink zu ermitteln
                local link = nil
                if stored then
                    if type(stored) == "string" and string.find(stored, "item:") then
                        link = stored
                    else
                        -- GetItemInfo akzeptiert sowohl itemLink als auch itemID und liefert den hyperlink zurück
                        local _, gotLink = C_Item.GetItemInfo(stored)
                        if gotLink and type(gotLink) == "string" then
                            link = gotLink
                        end
                    end
                end

                if link then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetHyperlink(link)
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
                    self.qualityOverlay:SetTexture(nil)
                    self.qualityOverlay:Hide()
                end
            end)

            -- Receive Drag Event für die Buttons
            slot:SetScript("OnReceiveDrag", function(self)
                local cursorType, itemID, itemLink = GetCursorInfo()
                if cursorType == "item" and itemLink then
                    local itemName, _, _, _, _, _, _, _, _, itemTexture = C_Item.GetItemInfo(itemLink)
                    if itemTexture then
                        FillButtonWithData(itemTexture, itemLink, self)
                    end
                    items[self:GetName()] = itemLink
                    ClearCursor()
                end
            end)

            -- OnDragStart Event für die Buttons (Item vom Slot nehmen)
            slot:SetScript("OnDragStart", function(self)
                local itemLink = items[self:GetName()]
                if itemLink then
                    PickupItem(itemLink)              -- Item auf den Cursor legen
                    items[self:GetName()] = nil       -- Slot leeren
                    FillButtonWithData(nil, nil, self) -- Icon entfernen
                    end
            end)

        end
    end
end


local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    CreateGrid()
end)


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
        if ItemTrackerConfig[characterID].DefaultButtonSize then
            ItemTracker:SetSize(ItemTrackerConfig[characterID].DefaultButtonSize * GRID_SIZE_X + 65, ItemTrackerConfig[characterID].DefaultButtonSize * GRID_SIZE_Y + 25)
            print("Größe auf Standardgröße zurückgesetzt.")
            ItemTrackerConfig[characterID].iconSize = ItemTrackerConfig[characterID].DefaultButtonSize
        else
            print("Keine Standardgröße gespeichert.")
        end
    end
end