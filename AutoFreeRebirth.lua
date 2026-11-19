--==================================================
-- AUTO FREE REBIRTH + FAST AUTO PET FUSE V10
-- Game: +1 Solo Tower Leveling
-- Platform: Roblox Windows / executor environment
--
-- Features:
-- Separate Auto Rebirth and Auto Fuse toggles
-- Draggable, resizable main UI
-- Round Yin-Yang minimize symbol with independent resizing
-- Faster Auto Fuse scans stacks of 5+ across all rarities and skips equipped pets
-- Fusion requires the selected pet to show FUSE 5/5; shorter waits and responsive idle checks
-- Never activates Delete or Delete All
-- No print/warn console output
--==================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")

--==================================================
-- GAME REFERENCES
--==================================================

local rebirthGui = gui:WaitForChild("RebirthPanel")
local rebirthPanel = rebirthGui.PanelFit.Panel
local freeButton = rebirthPanel.Rebirth
local gradient = freeButton.UIGradient
local openRebirthButton = gui.Hud.Tiles.Rebirth
local levelLabel = gui.Hud.StatStack.LevelBar.Left

local petsGui = gui:WaitForChild("PetsPanel")
local petsPanel = petsGui:WaitForChild("PanelFit"):WaitForChild("Panel")
local petGrid = petsPanel:WaitForChild("Grid")
local petDetail = petsPanel:WaitForChild("Detail")
local equipButton = petDetail:WaitForChild("TextButton")
local fuseButton = petDetail:WaitForChild("Fuse")

--==================================================
-- SETTINGS
--==================================================

-- Slightly slower rebirth pacing to give the game time to settle after each reset.
local CHECK_INTERVAL = 0.15
local REBIRTH_READY_TIMEOUT = 1.25
local CONFIRM_TIME = 3.5 -- maximum server-confirmation wait; exits immediately when Rebirths changes
local CONFIRM_POLL_INTERVAL = 0.05
local REBIRTH_RETRY_DELAY = 5 -- safety cooldown after an unconfirmed click
local REBIRTH_SUCCESS_DELAY = 2.0 -- recovery pause after a confirmed rebirth

local BASE_REBIRTH = 572
local BASE_LEVEL = 8600
local LEVEL_INCREMENT = 15

local READY = {
    R = 0.517647,
    G = 1,
    B = 0.0627451
}

-- Faster fusion timings; keep the tested V3 snapshot/verification logic intact.
local SCAN_INTERVAL = 0.05
local SELECT_TIMEOUT = 0.65
local SELECT_POLL_INTERVAL = 0.025
local INVENTORY_CONFIRM_TIMEOUT = 6.0 -- safety timeout; exits immediately when inventory changes
local INVENTORY_POLL_INTERVAL = 0.05
local AFTER_FUSE_DELAY = 0.15
local IDLE_POLL_INTERVAL = 0.35

local MAIN_WIDTH = 285
local MAIN_HEIGHT = 175
local SYMBOL_SIZE = 42

local MIN_MAIN_WIDTH = 250
local MAX_MAIN_WIDTH = 480
local MIN_MAIN_HEIGHT = 170
local MAX_MAIN_HEIGHT = 360

local MIN_SYMBOL_SIZE = 32
local MAX_SYMBOL_SIZE = 85

-- Both features start OFF so nothing runs until enabled in the UI.
local autoRebirthEnabled = false
local autoFuseEnabled = false
local rebirthBusy = false
local fuseBusy = false
local rescanRequested = false
local lastRebirthAttempt = 0

local rebirthStatusText = "Auto Rebirth is OFF."
local fuseStatusText = "Auto Fuse is OFF."

--==================================================
-- REMOVE OLD UI
--==================================================

for _, oldName in ipairs({"FreeRebirthControlV9", "FreeRebirthControlV10"}) do
    local oldUI = gui:FindFirstChild(oldName)
    if oldUI then
        oldUI:Destroy()
    end
end

--==================================================
-- CREATE SCREEN GUI
--==================================================

local screen = Instance.new("ScreenGui")
screen.Name = "FreeRebirthControlV10"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.DisplayOrder = 99999
screen.Parent = gui

--==================================================
-- MAIN WINDOW
--==================================================

local frame = Instance.new("Frame")
frame.Name = "Main"
frame.Size = UDim2.fromOffset(MAIN_WIDTH, MAIN_HEIGHT)
frame.Position = UDim2.new(0, 25, 0.45, 0)
frame.BackgroundColor3 = Color3.fromRGB(27, 33, 43)
frame.BorderSizePixel = 0
frame.Active = true
frame.Parent = screen

local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 10)
frameCorner.Parent = frame

local frameStroke = Instance.new("UIStroke")
frameStroke.Color = Color3.fromRGB(75, 91, 110)
frameStroke.Thickness = 1.3
frameStroke.Parent = frame

--==================================================
-- HEADER / DRAG HANDLE
--==================================================

local header = Instance.new("TextButton")
header.Name = "DragHandle"
header.Size = UDim2.new(1, -42, 0, 34)
header.Position = UDim2.fromOffset(0, 0)
header.BackgroundColor3 = Color3.fromRGB(42, 54, 69)
header.BorderSizePixel = 0
header.Text = "  AUTO REBIRTH + PET FUSE"
header.TextColor3 = Color3.fromRGB(255, 255, 255)
header.Font = Enum.Font.GothamBold
header.TextSize = 12
header.TextXAlignment = Enum.TextXAlignment.Left
header.Parent = frame

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 10)
headerCorner.Parent = header

--==================================================
-- YIN-YANG MINIMIZE BUTTON
--==================================================

local minimizeButton = Instance.new("TextButton")
minimizeButton.Name = "Minimize"
minimizeButton.Size = UDim2.fromOffset(32, 28)
minimizeButton.Position = UDim2.new(1, -36, 0, 3)
minimizeButton.BackgroundColor3 = Color3.fromRGB(55, 68, 85)
minimizeButton.BorderSizePixel = 0
minimizeButton.Text = "☯"
minimizeButton.TextColor3 = Color3.new(1, 1, 1)
minimizeButton.Font = Enum.Font.GothamBold
minimizeButton.TextSize = 21
minimizeButton.Parent = frame

local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(0, 7)
minCorner.Parent = minimizeButton

--==================================================
-- AUTO REBIRTH TOGGLE
--==================================================

local rebirthToggle = Instance.new("TextButton")
rebirthToggle.Name = "AutoRebirthToggle"
rebirthToggle.Position = UDim2.new(0, 10, 0, 42)
rebirthToggle.Size = UDim2.new(1, -20, 0, 30)
rebirthToggle.BackgroundColor3 = Color3.fromRGB(190, 65, 65)
rebirthToggle.BorderSizePixel = 0
rebirthToggle.TextColor3 = Color3.new(1, 1, 1)
rebirthToggle.Font = Enum.Font.GothamBold
rebirthToggle.TextSize = 11
rebirthToggle.Parent = frame

local rebirthToggleCorner = Instance.new("UICorner")
rebirthToggleCorner.CornerRadius = UDim.new(0, 7)
rebirthToggleCorner.Parent = rebirthToggle

--==================================================
-- AUTO FUSE TOGGLE
--==================================================

local fuseToggle = Instance.new("TextButton")
fuseToggle.Name = "AutoFuseToggle"
fuseToggle.Position = UDim2.new(0, 10, 0, 76)
fuseToggle.Size = UDim2.new(1, -20, 0, 30)
fuseToggle.BackgroundColor3 = Color3.fromRGB(190, 65, 65)
fuseToggle.BorderSizePixel = 0
fuseToggle.TextColor3 = Color3.new(1, 1, 1)
fuseToggle.Font = Enum.Font.GothamBold
fuseToggle.TextSize = 11
fuseToggle.Parent = frame

local fuseToggleCorner = Instance.new("UICorner")
fuseToggleCorner.CornerRadius = UDim.new(0, 7)
fuseToggleCorner.Parent = fuseToggle

--==================================================
-- SEPARATE STATUS LABELS
--==================================================

local rebirthStatus = Instance.new("TextLabel")
rebirthStatus.Name = "RebirthStatus"
rebirthStatus.Position = UDim2.new(0, 8, 0, 111)
rebirthStatus.Size = UDim2.new(1, -16, 0, 18)
rebirthStatus.BackgroundTransparency = 1
rebirthStatus.TextColor3 = Color3.fromRGB(190, 205, 220)
rebirthStatus.Font = Enum.Font.Gotham
rebirthStatus.TextSize = 9
rebirthStatus.TextTruncate = Enum.TextTruncate.AtEnd
rebirthStatus.Parent = frame

local fuseStatus = Instance.new("TextLabel")
fuseStatus.Name = "FuseStatus"
fuseStatus.Position = UDim2.new(0, 8, 0, 131)
fuseStatus.Size = UDim2.new(1, -16, 0, 18)
fuseStatus.BackgroundTransparency = 1
fuseStatus.TextColor3 = Color3.fromRGB(190, 205, 220)
fuseStatus.Font = Enum.Font.Gotham
fuseStatus.TextSize = 9
fuseStatus.TextTruncate = Enum.TextTruncate.AtEnd
fuseStatus.Parent = frame

--==================================================
-- MAIN WINDOW RESIZE HANDLE
--==================================================

local mainResize = Instance.new("TextButton")
mainResize.Name = "ResizeMain"
mainResize.Size = UDim2.fromOffset(17, 17)
mainResize.AnchorPoint = Vector2.new(1, 1)
mainResize.Position = UDim2.new(1, -2, 1, -2)
mainResize.BackgroundColor3 = Color3.fromRGB(55, 68, 85)
mainResize.BorderSizePixel = 0
mainResize.Text = "◢"
mainResize.TextColor3 = Color3.new(1, 1, 1)
mainResize.TextSize = 12
mainResize.Parent = frame

local mainResizeCorner = Instance.new("UICorner")
mainResizeCorner.CornerRadius = UDim.new(0, 4)
mainResizeCorner.Parent = mainResize

--==================================================
-- ROUND FLOATING YIN-YANG SYMBOL
--==================================================

local miniButton = Instance.new("TextButton")
miniButton.Name = "MiniSymbol"
miniButton.Size = UDim2.fromOffset(SYMBOL_SIZE, SYMBOL_SIZE)
miniButton.Position = frame.Position
miniButton.BackgroundColor3 = Color3.fromRGB(27, 33, 43)
miniButton.BorderSizePixel = 0
miniButton.Text = "☯"
miniButton.TextColor3 = Color3.new(1, 1, 1)
miniButton.Font = Enum.Font.GothamBold
miniButton.TextSize = 25
miniButton.Visible = false
miniButton.ClipsDescendants = true
miniButton.Parent = screen

local miniCorner = Instance.new("UICorner")
miniCorner.CornerRadius = UDim.new(1, 0)
miniCorner.Parent = miniButton

local miniStroke = Instance.new("UIStroke")
miniStroke.Color = Color3.fromRGB(100, 125, 150)
miniStroke.Thickness = 1.5
miniStroke.Parent = miniButton

--==================================================
-- SEPARATE MINI SYMBOL RESIZE HANDLE
--==================================================

local miniResize = Instance.new("TextButton")
miniResize.Name = "ResizeSymbol"
miniResize.Size = UDim2.fromOffset(12, 12)
miniResize.AnchorPoint = Vector2.new(0.5, 0.5)
miniResize.BackgroundColor3 = Color3.fromRGB(85, 105, 130)
miniResize.BorderSizePixel = 0
miniResize.Text = "↘"
miniResize.TextColor3 = Color3.new(1, 1, 1)
miniResize.TextSize = 8
miniResize.Visible = false
miniResize.Parent = screen

local miniResizeCorner = Instance.new("UICorner")
miniResizeCorner.CornerRadius = UDim.new(1, 0)
miniResizeCorner.Parent = miniResize

local function updateMiniGrip()
    miniResize.Position = UDim2.fromOffset(
        miniButton.AbsolutePosition.X + SYMBOL_SIZE - 1,
        miniButton.AbsolutePosition.Y + SYMBOL_SIZE - 1
    )
end

--==================================================
-- UI STATUS / TOGGLES
--==================================================

local function updateButtons()
    if autoRebirthEnabled then
        rebirthToggle.Text = "AUTO REBIRTH: ON  |  CLICK TO STOP"
        rebirthToggle.BackgroundColor3 = Color3.fromRGB(30, 155, 85)
    else
        rebirthToggle.Text = "AUTO REBIRTH: OFF  |  CLICK TO START"
        rebirthToggle.BackgroundColor3 = Color3.fromRGB(190, 65, 65)
    end

    if autoFuseEnabled then
        fuseToggle.Text = "AUTO FUSE: ON  |  CLICK TO STOP"
        fuseToggle.BackgroundColor3 = Color3.fromRGB(30, 155, 85)
    else
        fuseToggle.Text = "AUTO FUSE: OFF  |  CLICK TO START"
        fuseToggle.BackgroundColor3 = Color3.fromRGB(190, 65, 65)
    end

    rebirthStatus.Text = rebirthStatusText
    fuseStatus.Text = fuseStatusText
end

rebirthToggle.Activated:Connect(function()
    autoRebirthEnabled = not autoRebirthEnabled
    if autoRebirthEnabled then
        rebirthStatusText = "Rebirth: Monitoring level."
    else
        rebirthStatusText = "Rebirth: Stopped."
    end
    updateButtons()
end)

fuseToggle.Activated:Connect(function()
    autoFuseEnabled = not autoFuseEnabled
    rescanRequested = true
    if autoFuseEnabled then
        if petsGui.Enabled and petsPanel.Visible and petGrid.Visible then
            fuseStatusText = "Fuse: ON; scanning eligible stacks."
        else
            fuseStatusText = "Fuse: ON; open Pets to scan."
        end
    else
        fuseStatusText = "Fuse: Stopped."
    end
    updateButtons()
end)

updateButtons()

--==================================================
-- MINIMIZE / RESTORE
--==================================================

minimizeButton.Activated:Connect(function()
    frame.Visible = false
    miniButton.Position = UDim2.fromOffset(
        frame.AbsolutePosition.X,
        frame.AbsolutePosition.Y
    )
    miniButton.Visible = true
    miniResize.Visible = true
    updateMiniGrip()
end)

local miniMoved = false

miniButton.Activated:Connect(function()
    if miniMoved then
        miniMoved = false
        return
    end

    frame.Position = miniButton.Position
    frame.Visible = true
    miniButton.Visible = false
    miniResize.Visible = false
end)

--==================================================
-- DRAG AND RESIZE SYSTEM
--==================================================

local interaction = nil

local function startInteraction(mode, object, input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        interaction = {
            mode = mode,
            object = object,
            input = input,
            startPosition = input.Position,
            startUDimPosition = object.Position,
            startSize = object.AbsoluteSize
        }
    end
end

header.InputBegan:Connect(function(input)
    startInteraction("moveMain", frame, input)
end)

mainResize.InputBegan:Connect(function(input)
    startInteraction("resizeMain", frame, input)
end)

miniButton.InputBegan:Connect(function(input)
    miniMoved = false
    startInteraction("moveMini", miniButton, input)
end)

miniResize.InputBegan:Connect(function(input)
    startInteraction("resizeMini", miniButton, input)
end)

UserInputService.InputChanged:Connect(function(input)
    if not interaction then
        return
    end

    if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end

    local delta = input.Position - interaction.startPosition
    local mode = interaction.mode
    local object = interaction.object

    if mode == "moveMain" or mode == "moveMini" then
        object.Position = UDim2.new(
            interaction.startUDimPosition.X.Scale,
            interaction.startUDimPosition.X.Offset + delta.X,
            interaction.startUDimPosition.Y.Scale,
            interaction.startUDimPosition.Y.Offset + delta.Y
        )

        if mode == "moveMini" then
            if math.abs(delta.X) + math.abs(delta.Y) > 5 then
                miniMoved = true
            end
            updateMiniGrip()
        end

    elseif mode == "resizeMain" then
        local newWidth = math.clamp(
            interaction.startSize.X + delta.X,
            MIN_MAIN_WIDTH,
            MAX_MAIN_WIDTH
        )
        local newHeight = math.clamp(
            interaction.startSize.Y + delta.Y,
            MIN_MAIN_HEIGHT,
            MAX_MAIN_HEIGHT
        )
        frame.Size = UDim2.fromOffset(newWidth, newHeight)

    elseif mode == "resizeMini" then
        local change = math.max(delta.X, delta.Y)
        SYMBOL_SIZE = math.clamp(
            interaction.startSize.X + change,
            MIN_SYMBOL_SIZE,
            MAX_SYMBOL_SIZE
        )
        miniButton.Size = UDim2.fromOffset(SYMBOL_SIZE, SYMBOL_SIZE)
        miniButton.TextSize = math.floor(SYMBOL_SIZE * 0.55)
        updateMiniGrip()
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if interaction then
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or (input.UserInputType == Enum.UserInputType.Touch
            and input == interaction.input) then
            interaction = nil
            updateMiniGrip()
        end
    end
end)

--==================================================
-- AUTO REBIRTH HELPERS
--==================================================

local function getLevel()
    return tonumber(levelLabel.Text:match("%d+"))
end

local function getRebirthCount()
    local value = player:GetAttribute("Rebirths")
    if typeof(value) == "number" then
        return value
    end
    return nil
end

local function getRequiredLevel(rebirths)
    return BASE_LEVEL + LEVEL_INCREMENT * (rebirths - BASE_REBIRTH)
end

local function isRebirthReady()
    local color = gradient.Color.Keypoints[1].Value
    return math.abs(color.R - READY.R) < 0.015
        and math.abs(color.G - READY.G) < 0.015
        and math.abs(color.B - READY.B) < 0.015
end

local function openRebirthPanel()
    if not rebirthGui.Enabled then
        firesignal(openRebirthButton.Activated)
    end

    -- Wait only as long as needed for the panel and FREE button to become ready.
    -- When the panel is already open and ready, this returns immediately.
    local deadline = os.clock() + REBIRTH_READY_TIMEOUT
    repeat
        if rebirthGui.Enabled
            and freeButton.Visible
            and freeButton.Active
            and freeButton.Interactable
            and isRebirthReady() then
            return true
        end
        task.wait(CONFIRM_POLL_INTERVAL)
    until os.clock() >= deadline

    return rebirthGui.Enabled
        and freeButton.Visible
        and freeButton.Active
        and freeButton.Interactable
        and isRebirthReady()
end

local function closeRebirthPanel()
    if rebirthGui.Enabled then
        firesignal(openRebirthButton.Activated)
    end
end

--==================================================
-- AUTO REBIRTH LOOP
--==================================================

task.spawn(function()
    while screen.Parent and player.Parent do
        task.wait(CHECK_INTERVAL)

        if autoRebirthEnabled and not rebirthBusy then
            local level = getLevel()
            local rebirths = getRebirthCount()

            if level and rebirths then
                local target = getRequiredLevel(rebirths)

                if level >= target
                    and os.clock() - lastRebirthAttempt >= REBIRTH_RETRY_DELAY then

                    rebirthBusy = true
                    lastRebirthAttempt = os.clock()

                    local wasOpen = rebirthGui.Enabled
                    local beforeCount = getRebirthCount()

                    rebirthStatusText = "Rebirth: Target reached."
                    updateButtons()

                    local success = pcall(function()
                        if not autoRebirthEnabled then
                            return
                        end

                        -- This returns immediately if the panel/button are already ready.
                        if openRebirthPanel() and autoRebirthEnabled then
                            rebirthStatusText = "Rebirth: Activating FREE rebirth."
                            updateButtons()

                            -- Listen for the server-side rebirth count before clicking,
                            -- so fast confirmations do not incur an artificial wait.
                            local confirmed = false
                            local countConnection = player:GetAttributeChangedSignal("Rebirths"):Connect(function()
                                local afterCount = getRebirthCount()
                                if beforeCount and afterCount and afterCount > beforeCount then
                                    confirmed = true
                                end
                            end)

                            local clickOK, clickError = pcall(function()
                                firesignal(freeButton.Activated)
                            end)
                            if not clickOK then
                                countConnection:Disconnect()
                                error(clickError)
                            end

                            local deadline = os.clock() + CONFIRM_TIME
                            repeat
                                local afterCount = getRebirthCount()
                                if beforeCount and afterCount and afterCount > beforeCount then
                                    confirmed = true
                                    break
                                end
                                if confirmed then
                                    break
                                end
                                task.wait(CONFIRM_POLL_INTERVAL)
                            until os.clock() >= deadline

                            countConnection:Disconnect()

                            if confirmed then
                                rebirthStatusText = "Rebirth: Confirmed."
                                -- Give the game's level/UI reset a short moment to settle
                                -- before attempting another eligible rebirth.
                                lastRebirthAttempt = os.clock() - REBIRTH_RETRY_DELAY + REBIRTH_SUCCESS_DELAY
                            else
                                rebirthStatusText = "Rebirth: Confirmation not detected."
                            end
                        else
                            rebirthStatusText = "Rebirth: Waiting for FREE readiness."
                        end
                    end)

                    if not wasOpen and rebirthGui.Enabled then
                        pcall(closeRebirthPanel)
                    end

                    if not success then
                        rebirthStatusText = "Rebirth: Error occurred."
                    end

                    rebirthBusy = false
                    updateButtons()
                end
            end
        end
    end
end)

--==================================================
-- AUTO FUSE HELPERS (FAST V3 CORE)
--==================================================

local function updateFuseStatus(message)
    if message then
        fuseStatusText = message
    end
    updateButtons()
end

local function isPetsPanelOpen()
    return petsGui.Enabled and petsPanel.Visible and petGrid.Visible
end

local function getLabelText(button)
    local label = button and button:FindFirstChild("Label")
    if label and label:IsA("TextLabel") then
        return label.Text
    end
    return ""
end

local function getFuseText()
    return getLabelText(fuseButton)
end

local function isFusionReady(text)
    local current, required = text:match("^FUSE%s+(%d+)/(%d+)$")
    return tonumber(current) == 5 and tonumber(required) == 5
end

local function getVisiblePetCards()
    local cards = {}

    for _, child in ipairs(petGrid:GetChildren()) do
        if child:IsA("TextButton") and child.Visible then
            table.insert(cards, child)
        end
    end

    table.sort(cards, function(a, b)
        return a.LayoutOrder < b.LayoutOrder
    end)

    return cards
end

local function getCardData(card)
    local rarity = nil
    local mana = nil
    local quantity = 1

    for _, child in ipairs(card:GetDescendants()) do
        if child:IsA("TextLabel") then
            local text = child.Text

            if text:match("^%+%d+%%$") then
                mana = text
            elseif text == "RAINBOW" or text == "VOID"
                or text == "DIAMOND" or text == "GOLDEN"
                or text == "LEGENDARY" then
                rarity = text
            else
                local amount = text:match("^x(%d+)$")
                if amount then
                    quantity = tonumber(amount) or 1
                end
            end
        end
    end

    return rarity, mana, quantity
end

local function getSelectedPetData()
    local petName = nil
    local detailRarity = ""
    local detailMana = nil

    for _, child in ipairs(petDetail:GetChildren()) do
        if child:IsA("TextLabel") then
            local text = child.Text
            local upper = string.upper(text)

            -- Ignore the fusion preview (for example, "5x = Diamond Reborn Tiger").
            if text ~= "Tap a pet"
                and not text:match("^%d+x%s*=")
                and not text:match("^%+%d+%% Mana$")
                and text ~= "" then
                if string.find(string.lower(text), "reborn", 1, true) then
                    petName = text
                end
            end

            if text:match("^%+%d+%% Mana$") then
                detailMana = text:match("^([+%-]?%d+%%)")
            end

            -- The previous parser only recognized RARE / EPIC / LEGENDARY.
            -- That silently rejected several tiers such as DIAMOND, VOID, and RAINBOW.
            if upper == "RAINBOW" or upper == "VOID" or upper == "DIAMOND"
                or upper == "GOLDEN" or upper == "LEGENDARY"
                or upper:find("RARE", 1, true) or upper:find("EPIC", 1, true) then
                detailRarity = upper
            end
        end
    end

    return petName, detailRarity, detailMana
end

-- Save card data BEFORE selection. In this game, activating a card removes
-- the original instance from Grid and clears its descendants. Reading that
-- old instance afterward returns no labels, so all later checks use snapshots.
local function makeCardSnapshot(card)
    local rarity, mana, quantity = getCardData(card)
    if not mana then
        return nil
    end

    return {
        layoutOrder = card.LayoutOrder,
        rarity = rarity,
        mana = mana,
        quantity = quantity,
    }
end

local function findCurrentCard(snapshot)
    -- Selection can destroy/reparent the original card and the game may
    -- rebuild or reorder the Grid. Prefer the old LayoutOrder when it still
    -- identifies the same card, then fall back to the saved visible metadata.
    local cards = getVisiblePetCards()

    local function matches(card)
        local rarity, mana, quantity = getCardData(card)
        return mana == snapshot.mana
            and rarity == snapshot.rarity
            and quantity == snapshot.quantity
    end

    for _, card in ipairs(cards) do
        if card.LayoutOrder == snapshot.layoutOrder and matches(card) then
            return card
        end
    end

    for _, card in ipairs(cards) do
        if matches(card) then
            return card
        end
    end

    return nil
end

local function selectedPetMatchesSnapshot(snapshot)
    local petName, detailRarity, detailMana = getSelectedPetData()

    -- The game sometimes omits the pet title or tier label from Detail while
    -- still updating the Mana text correctly. A clicked card is separately
    -- confirmed by its original instance leaving Grid in selectAndVerifyCard.
    if not detailMana or detailMana ~= snapshot.mana then
        return false, petName, detailRarity, detailMana
    end

    -- If the game supplies a tier label, reject a conflicting tier. If it
    -- omits the label (seen on some Diamond cards), don't reject the selection.
    if snapshot.rarity and detailRarity ~= ""
        and not detailRarity:find(snapshot.rarity, 1, true) then
        return false, petName, detailRarity, detailMana
    end

    return true, petName, detailRarity, detailMana
end

local function selectAndVerifyCard(snapshot)
    local card = findCurrentCard(snapshot)
    if not card then
        return false
    end

    local fired = pcall(function()
        firesignal(card.Activated)
    end)

    if not fired then
        return false
    end

    local deadline = os.clock() + SELECT_TIMEOUT
    repeat
        task.wait(SELECT_POLL_INTERVAL)
        local cardWasSelected = card.Parent ~= petGrid
        local matches, petName = selectedPetMatchesSnapshot(snapshot)
        if cardWasSelected and matches then
            if not petName or petName == "" then
                petName = string.format("%s pet (%s)", snapshot.rarity or "Normal", snapshot.mana)
            end
            return true, petName
        end
    until os.clock() >= deadline or not autoFuseEnabled

    local selectedName, selectedRarity, selectedMana = getSelectedPetData()
    return false
end

local function getInventorySignature()
    local parts = {}

    for _, card in ipairs(getVisiblePetCards()) do
        table.insert(parts, tostring(card.LayoutOrder))
        local texts = {}
        for _, child in ipairs(card:GetDescendants()) do
            if child:IsA("TextLabel") then
                table.insert(texts, child.Text)
            end
        end
        table.sort(texts)
        for _, text in ipairs(texts) do
            table.insert(parts, text)
        end
    end

    return table.concat(parts, "|")
end

local function fuseButtonIsUsable()
    return fuseButton.Visible
        and fuseButton.Active
        and fuseButton.Interactable
        and fuseButton:IsDescendantOf(petDetail)
end

local function tryOneFusion()
    if not isPetsPanelOpen() then
        updateFuseStatus("Open the Pets menu first.")
        return false
    end

    -- Only cards with five or more copies can possibly fuse. Do not spend
    -- time selecting x1-x4 cards; they cannot satisfy the game's 5/5 rule.
    local snapshots = {}
    for _, card in ipairs(getVisiblePetCards()) do
        local snapshot = makeCardSnapshot(card)
        if snapshot and snapshot.quantity >= 5 then
            table.insert(snapshots, snapshot)
        end
    end

    if #snapshots == 0 then
        updateFuseStatus("No pet stacks with 5+ copies. Waiting for inventory changes.")
        return false
    end

    for index, snapshot in ipairs(snapshots) do
        if not autoFuseEnabled then
            return false
        end

        updateFuseStatus("Checking fusion-ready stack " .. tostring(index) .. "/" .. tostring(#snapshots) .. "...")

        local matched, petName = selectAndVerifyCard(snapshot)
        if matched and autoFuseEnabled then
            local equipState = getLabelText(equipButton)
            local fuseText = getFuseText()

            -- EQUIP means unequipped. Never touch an equipped pet.
            local skipReason = nil
            if equipState ~= "EQUIP" then
                skipReason = "pet is equipped"
            elseif not isFusionReady(fuseText) then
                skipReason = "fusion says " .. tostring(fuseText)
            elseif not fuseButtonIsUsable() then
                skipReason = "Fuse button is not usable"
            end

            if not skipReason then
                -- Final checks immediately before the only action performed.
                local stillMatches = selectedPetMatchesSnapshot(snapshot)
                if stillMatches
                    and getLabelText(equipButton) == "EQUIP"
                    and isFusionReady(getFuseText())
                    and fuseButtonIsUsable()
                    and autoFuseEnabled then

                    local beforeSignature = getInventorySignature()
                    updateFuseStatus("Fusing " .. petName .. "...")

                    local fired = pcall(function()
                        firesignal(fuseButton.Activated)
                    end)

                    if not fired then
                        autoFuseEnabled = false
                        updateFuseStatus("Fuse activation failed. Paused.")
                        return false
                    end

                    -- The selection resets after fusion. Confirm a real inventory
                    -- change, then return so the next pass takes fresh snapshots.
                    local changed = false
                    local deadline = os.clock() + INVENTORY_CONFIRM_TIMEOUT
                    repeat
                        task.wait(INVENTORY_POLL_INTERVAL)
                        if getInventorySignature() ~= beforeSignature then
                            changed = true
                            break
                        end
                    until os.clock() >= deadline or not autoFuseEnabled

                    if changed then
                        updateFuseStatus("Fused " .. petName .. ". Updating inventory...")
                        task.wait(AFTER_FUSE_DELAY)
                        return true
                    else
                        autoFuseEnabled = false
                        updateFuseStatus("No inventory change detected. Paused for safety.")
                        return false
                    end
                end
            end
        end
    end

    updateFuseStatus("Scan complete. Waiting for inventory changes.")
    return false
end

-- Once a full scan finds no eligible unequipped pet, stay idle. A lightweight
-- inventory signature check wakes the scanner when quantities/cards change.
-- Clicking the toggle OFF then ON also explicitly requests a fresh scan.
local function waitForInventoryChange()
    local baseline = getInventorySignature()
    local wasOpen = isPetsPanelOpen()

    while screen.Parent and player.Parent and autoFuseEnabled do
        if rescanRequested then
            rescanRequested = false
            return
        end

        task.wait(IDLE_POLL_INTERVAL)

        if not autoFuseEnabled then
            return
        end
        if isPetsPanelOpen() ~= wasOpen then
            return
        end
        if getInventorySignature() ~= baseline then
            return
        end
    end
end

--==================================================
-- AUTO FUSE LOOP (SCAN ONCE, THEN WAIT FOR CHANGES)
--==================================================

-- This preserves the tested V3 behavior: snapshot cards before selection,
-- select only stacks with 5+ copies, verify the selected detail data, skip
-- equipped pets, require FUSE 5/5, and rescan after a confirmed fusion.
-- Delete and DeleteAll are never referenced or activated.

task.spawn(function()
    while screen.Parent and player.Parent do
        if autoFuseEnabled and not fuseBusy then
            fuseBusy = true
            rescanRequested = false

            local ok, didFuse = pcall(tryOneFusion)
            if not ok then
                autoFuseEnabled = false
                fuseStatusText = "Fuse: Script error; paused for safety."
                updateButtons()
            elseif autoFuseEnabled and not didFuse then
                waitForInventoryChange()
            end

            fuseBusy = false
            updateButtons()
        end
        task.wait(SCAN_INTERVAL)
    end
end)
