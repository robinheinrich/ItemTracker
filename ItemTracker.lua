-- Written by: Rob
-- Description: Ein einfaches Addon, um Items mit der Anzahl in einem Grid anzuzeigen

-- Konstanten und Variablen
local GRID_SIZE_X = 10  -- Anzahl der Spalten
local GRID_SIZE_Y = 2   -- Anzahl der Zeilen
local ICON_SIZE = 35.0    -- Default Größe der Icons
local items = {}        -- Tabelle für die Items

-- Midnight Kompatibilität: Manche Konstanten und Methoden wurden in 12.0.0 entfernt
-- local NUM_BAG_SLOTS = NUM_BAG_SLOTS or 4  -- Fallback: 4 normale Inventar-Taschen (0-4)
-- local NUM_BANKBAGSLOTS = 7  -- 7 Bank-Taschen (Bag IDs 5-11)

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
local characterID = characterName .. "-" .. realm

local function EnsureCharacterStorage()
    ItemTrackerGrid[characterID] = ItemTrackerGrid[characterID] or {}
    ItemTrackerConfig[characterID] = ItemTrackerConfig[characterID] or {}
    return ItemTrackerGrid[characterID], ItemTrackerConfig[characterID]
end

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
    local _, config = EnsureCharacterStorage()
  
    -- Position des Frames in Config speichern
    config.framePosition = {
        point = point,
        relativePoint = relativePoint,
        x = xOffset,
        y = yOffset
    }
end)

ItemTracker:Show()

--------------------------------------------------------------------
local function ClearSlot(slot)
    if not slot then return end

    slot.icon:SetTexture(nil)
    slot.count:SetText("")
    slot.qualityOverlay:SetTexture(nil)
    slot.qualityOverlay:Hide()

    if not InCombatLockdown() then
        slot:SetAttribute("type", nil)
        slot:SetAttribute("item", nil)
    end
end

local function SetSlotContent(slot, itemLink)
    if not slot then return end

    if not itemLink then
        ClearSlot(slot)
        return
    end

    local itemName, _, _, _, _, _, _, _, _, itemTexture = C_Item.GetItemInfo(itemLink)
    if not itemName then
        ClearSlot(slot)
        return
    end

    slot.icon:SetTexture(itemTexture)
    slot.count:SetText(C_Item.GetItemCount(itemLink, true) or 0)

    if not InCombatLockdown() then
        local itemID = C_Item.GetItemInfoInstant(itemLink)
        slot:SetAttribute("type", itemID and "item" or nil)
        slot:SetAttribute("item", itemID and ("item:" .. itemID) or nil)
    end

    
    local quality = C_TradeSkillUI.GetItemReagentQualityInfo(itemLink)
    
    if quality then
        slot.qualityOverlay:SetAtlas(quality.icon)
        slot.qualityOverlay:Show()
    else
        slot.qualityOverlay:SetTexture(nil)
        slot.qualityOverlay:Hide()
    end
end

-- Die Items im Grid aktualisieren
local function UpdateItemCount()
    if InCombatLockdown() then -- nur ausführen, wenn der Spieler nicht im Kampf ist
        return
    end

    local grid = ItemTrackerGrid[characterID] or {}
    for slotName, itemLink in pairs(grid) do
        local slot = _G[slotName]
        if slot then
            SetSlotContent(slot, itemLink)
        end
    end
end

--------------------------------------------------------------------
-- Funktion, um die gespeicherten Daten zu laden
local function LoadSavedData()
    local grid = ItemTrackerGrid[characterID] or {}
    for slotName, itemLink in pairs(grid) do
        local slot = _G[slotName]
        if slot then
            SetSlotContent(slot, itemLink)
            items[slot:GetName()] = itemLink
        end
    end
end

--------------------------------------------------------------------
-- Events abfangen und verarbeiten
ItemTracker:SetScript("OnEvent", function(self, event, addonName)
    -- Prüfe, ob das Addon "ItemTracker" geladen wurde
    if event == "ADDON_LOADED" and addonName == "ItemTracker" then
        local _, config = EnsureCharacterStorage()
        
        -- Icon Size laden
        if config.iconSize then
            ICON_SIZE = config.iconSize
        end

        -- Position des Frames laden
        if config.framePosition then
            ItemTracker:ClearAllPoints()
            ItemTracker:SetPoint(config.framePosition.point, UIParent, config.framePosition.relativePoint, config.framePosition.x, config.framePosition.y)
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
ItemTracker:RegisterEvent("LOOT_CLOSED")
ItemTracker:RegisterEvent("MERCHANT_CLOSED")
ItemTracker:RegisterEvent("TRADE_CLOSED")
ItemTracker:RegisterEvent("BAG_UPDATE_DELAYED")  -- Neues Event für Bag-Updates
ItemTracker:RegisterEvent("GET_ITEM_INFO_RECEIVED")  -- Für asynchrone Item-Info

--------------------------------------------------------------------
-- Item mit Anzahl in das Grid einfügen
local function FillButtonWithData(icon, itemLink, slot)
    local slotName = slot:GetName()

    -- Wenn keine Daten übergeben wurden, entferne den Eintrag
    if icon == nil or not itemLink then
        ItemTrackerGrid[characterID][slotName] = nil
        items[slotName] = nil
        ClearSlot(slot)
        return
    end

    SetSlotContent(slot, itemLink)

    -- Speichere den Slot-Eintrag in den SavedVariables
    ItemTrackerGrid[characterID][slotName] = itemLink
    items[slotName] = itemLink
end

--------------------------------------------------------------------
-- Erstelle das Grid mit Drag & Drop Unterstützung pro Slot
local function CreateGrid()
    for row = 1, GRID_SIZE_Y do
        for col = 1, GRID_SIZE_X do
            local index = (row - 1) * GRID_SIZE_X + col
            local slot = CreateFrame("Button", "ItemSlot" .. index, ItemTracker, "BackdropTemplate, SecureActionButtonTemplate")
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
            slot:RegisterForClicks("AnyUp", "AnyDown")
            slot:HookScript("OnClick", function(self, button, down)
 
            
end)

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

            slot:HookScript("OnClick", function(self, button, down)
                -- Entfernen eines Items (Shift + Rechtsklick)
                if down then return end -- nur beim Loslassen reagieren
                if button == "RightButton" and IsShiftKeyDown() then
                    FillButtonWithData(nil, nil, self) -- Daten entfernen
                end
            end)


            -- Receive Drag Event für die Buttons
            slot:SetScript("OnReceiveDrag", function(self)
                if InCombatLockdown() then
                    -- Wenn der Spieler im Kampf ist, kann das Drag & Drop nicht durchgeführt werden
                    print("Du kannst keine Items während des Kampfes ändern.")
                    return
                end
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
                    C_Item.PickupItem(itemLink)              -- Item auf den Cursor legen
                    FillButtonWithData(nil, nil, self) -- Daten entfernen
                end
            end)

        end
    end
end


local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()
    CreateGrid()
    LoadSavedData()
end)

-- Registriere den Slash-Befehl "/IT"
SLASH_ITEMTRACKER1 = "/IT"
SlashCmdList["ITEMTRACKER"] = function(msg)
    -- FrameSize Befehl
    local rawSize = string.match(msg, "-size:(%d+)")
    if rawSize then
        local newSize = tonumber(rawSize)
        if not newSize or newSize < 20 or newSize > 100 then
            print("Ungültiger Größenwert. Bitte einen Wert zwischen 20 und 100 angeben.")
            return
        end
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
    end

    -- Set to Default Size Befehl
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

    -- Alle Items aus dem Grid entfernen
    local deleteAllItems = string.match(msg, "-del")
    if deleteAllItems then
        for i = 1, (GRID_SIZE_X * GRID_SIZE_Y) do
            local btn = _G["ItemSlot" .. i]
            if btn then
                FillButtonWithData(nil, nil, btn)
            end
        end
        print("Alle Items wurden entfernt.")
    end
end