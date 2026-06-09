-- OpexHub: Garden + Pet Duplicate UI (Rayfield)
-- Features:
--   - Auto harvest / auto water for garden objects
--   - Manual harvest / water actions
--   - Experimental pet duplication attempt
-- Note: Pet duplication is highly game-specific and usually fails on secure servers.

local Rayfield = nil
local success, RayfieldLib = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/shlexware/Rayfield/main/source.lua"))()
end)
if success and RayfieldLib then
    Rayfield = RayfieldLib
end

local GardenTab, PetTab, InfoTab
local DuplicateStatus
local AutoHarvest = false
local AutoWater = false
local DuplicationCooldown = 120
local lastDuplicateTime = 0
local HarvestAll, WaterAll, DuplicatePet

local function createCustomUI()
    local player = game.Players.LocalPlayer
    if not player then
        return
    end

    local playerGui = player:FindFirstChild("PlayerGui") or player:WaitForChild("PlayerGui")
    local gui = Instance.new("ScreenGui")
    gui.Name = "OpexHubCustomUI"
    gui.ResetOnSpawn = false
    gui.Parent = playerGui

    local frame = Instance.new("Frame")
    frame.Name = "MainFrame"
    frame.Size = UDim2.new(0, 280, 0, 360)
    frame.Position = UDim2.new(0.5, -140, 0.2, 0)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    frame.BorderSizePixel = 0
    frame.BackgroundTransparency = 0.1
    frame.Parent = gui

    local uiPadding = Instance.new("UIPadding")
    uiPadding.PaddingTop = UDim.new(0, 10)
    uiPadding.PaddingBottom = UDim.new(0, 10)
    uiPadding.PaddingLeft = UDim.new(0, 10)
    uiPadding.PaddingRight = UDim.new(0, 10)
    uiPadding.Parent = frame

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)
    layout.Parent = frame

    local UserInputService = game:GetService("UserInputService")
    local dragging = false
    local dragInput = nil
    local dragStart = nil
    local startPos = nil

    local function updateDrag(input)
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end

    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    frame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            updateDrag(input)
        end
    end)

    local function makeLabel(text, textSize)
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 0, textSize or 22)
        label.BackgroundTransparency = 1
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextScaled = false
        label.Font = Enum.Font.SourceSansSemibold
        label.Text = text
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = frame
        return label
    end

    local function makeButton(text, callback)
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(1, 0, 0, 34)
        button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        button.BorderSizePixel = 0
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.Font = Enum.Font.SourceSansSemibold
        button.Text = text
        button.TextScaled = false
        button.Parent = frame
        button.MouseButton1Click:Connect(callback)
        return button
    end

    local function makeToggle(text, getValue, setValue)
        local button = makeButton(text .. " [OFF]", function()
            local newValue = not getValue()
            setValue(newValue)
            button.Text = text .. " [" .. (newValue and "ON" or "OFF") .. "]"
        end)
        button.Text = text .. " [" .. (getValue() and "ON" or "OFF") .. "]"
        return button
    end

    makeLabel("OpexHub", 26).TextXAlignment = Enum.TextXAlignment.Center
    makeLabel("Small fallback UI", 18)

    makeToggle("Auto Harvest", function() return AutoHarvest end, function(value) AutoHarvest = value end)
    makeToggle("Auto Water", function() return AutoWater end, function(value) AutoWater = value end)

    makeButton("Harvest Once", function() HarvestAll() end)
    makeButton("Water Once", function() WaterAll() end)
    makeButton("Duplicate Pet", function() DuplicatePet() end)

    DuplicateStatus = makeLabel("Status: Idle", 20)
    DuplicateStatus.TextWrapped = true
    DuplicateStatus.TextXAlignment = Enum.TextXAlignment.Left

    makeLabel("Note: This UI is a simple fallback if Rayfield does not open.", 16)
    makeButton("Close UI", function() gui:Destroy() end)
end

local Window
if Rayfield then
    local ok, win = pcall(function()
        return Rayfield:CreateWindow({
            Name = "OpexHub",
            LoadingTitle = "OpexHub",
            LoadingSubtitle = "Garden + Pets AIO",
            ConfigurationSaving = {
                Enabled = true,
                FolderName = "OpexHubConfig",
                FileName = "Settings"
            },
            KeySystem = false
        })
    end)
    if ok then
        Window = win
    end
end

local GardenTab, PetTab, InfoTab
local DuplicateStatus
local AutoHarvest = false
local AutoWater = false

local function safeFindPlayerCharacter()
    local player = game.Players.LocalPlayer
    return player and player.Character
end

HarvestAll = function()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ClickDetector") and obj.Name:lower():find("harvest") then
            pcall(fireclickdetector, obj)
        elseif obj:IsA("ProximityPrompt") and obj.Name:lower():find("harvest") then
            pcall(function() obj:InputHoldBegin() wait(0.1) obj:InputHoldEnd() end)
        elseif obj:IsA("Tool") and obj.Name:lower():find("harvest") then
            local char = safeFindPlayerCharacter()
            if char and char:FindFirstChild("Humanoid") then
                pcall(function()
                    char.Humanoid:EquipTool(obj)
                    wait(0.1)
                    obj:Activate()
                end)
            end
        end
    end
end

WaterAll = function()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ClickDetector") and obj.Name:lower():find("water") then
            pcall(fireclickdetector, obj)
        elseif obj:IsA("ProximityPrompt") and obj.Name:lower():find("water") then
            pcall(function() obj:InputHoldBegin() wait(0.1) obj:InputHoldEnd() end)
        elseif obj:IsA("Tool") and obj.Name:lower():find("water") then
            local char = safeFindPlayerCharacter()
            if char and char:FindFirstChild("Humanoid") then
                pcall(function()
                    char.Humanoid:EquipTool(obj)
                    wait(0.1)
                    obj:Activate()
                end)
            end
        end
    end
end

spawn(function()
    while wait(2) do
        if AutoHarvest then
            pcall(HarvestAll)
        end
        if AutoWater then
            pcall(WaterAll)
        end
    end
end)

if Window then
    GardenTab = Window:CreateTab("Garden")
    PetTab = Window:CreateTab("Pets")
    InfoTab = Window:CreateTab("Info")

    GardenTab:CreateToggle({
        Name = "Auto Harvest",
        CurrentValue = false,
        Flag = "AutoHarvest",
        Callback = function(Value)
            AutoHarvest = Value
        end
    })

    GardenTab:CreateToggle({
        Name = "Auto Water",
        CurrentValue = false,
        Flag = "AutoWater",
        Callback = function(Value)
            AutoWater = Value
        end
    })

    GardenTab:CreateButton({
        Name = "Harvest Once",
        Callback = function() HarvestAll() end
    })

    GardenTab:CreateButton({
        Name = "Water Once",
        Callback = function() WaterAll() end
    })

    DuplicateStatus = PetTab:CreateLabel("Status: Idle")

    PetTab:CreateButton({
        Name = "⚠️ Duplicate Pet & Create Clone Tool ⚠️",
        Callback = function() DuplicatePet() end
    })

    PetTab:CreateLabel("Note: Experimental duplication. Most games validate pets server-side.")
    PetTab:CreateLabel("If successful and two matching pets are detected, a Pet Clone Tool is created in Backpack.")
    PetTab:CreateLabel("The clone tool copies the held pet and has a 2-minute cooldown.")

    InfoTab:CreateParagraph({
        Title = "How to use",
        Content = "Use Auto Harvest / Auto Water for standard garden interactions.\nPet duplication is experimental and depends on the game's implementation.\nNo remote exploit can guarantee being undetected.\nThe UI is built with Rayfield and saved under OpexHub settings."
    })

    Rayfield:Notify({
        Title = "OpexHub Loaded",
        Content = "Garden + Pet tool ready",
        Duration = 3
    })
else
    createCustomUI()
end

local DuplicationCooldown = 120
local lastDuplicateTime = 0

local function setDuplicateStatus(text)
    local msg = "Status: " .. text
    if not DuplicateStatus then
        return
    end
    pcall(function()
        if type(DuplicateStatus.Set) == "function" then
            DuplicateStatus:Set(msg)
        else
            DuplicateStatus.Text = msg
        end
    end)
end

local function getCooldownRemaining()
    local remaining = DuplicationCooldown - (tick() - lastDuplicateTime)
    return remaining > 0 and remaining or 0
end

local function isDuplicateOnCooldown()
    return getCooldownRemaining() > 0
end

local function isPetName(name)
    if type(name) ~= "string" then
        return false
    end
    local lower = name:lower()
    return lower:find("pet") or lower:find("companion") or lower:find("buddy") or lower:find("farm") or lower:find("animal") or lower:find("dragon") or lower:find("fox") or lower:find("cat") or lower:find("dog")
end

local function getCurrentHeldPet()
    local player = game.Players.LocalPlayer
    local character = player and player.Character
    if not character then
        return nil
    end

    local tool = character:FindFirstChildOfClass("Tool")
    if tool and tool.Name ~= "Pet Clone Tool" then
        return tool
    end

    for _, item in ipairs(character:GetChildren()) do
        if item.Name ~= "Pet Clone Tool" and isPetCandidate(item) then
            return item
        end
    end

    return nil
end

local function getPetInventoryCount(petName)
    local player = game.Players.LocalPlayer
    local count = 0
    local containers = {
        player:FindFirstChild("Backpack"),
        player:FindFirstChild("Pets"),
        player:FindFirstChild("PetInventory"),
        player:FindFirstChild("Inventory"),
        player.Character
    }
    for _, container in ipairs(containers) do
        if container then
            for _, item in ipairs(container:GetChildren()) do
                if item.Name == petName and isPetCandidate(item) then
                    count = count + 1
                end
            end
        end
    end
    return count
end

local function createCloneToolForPet(pet)
    local player = game.Players.LocalPlayer
    if not pet or not player then
        return nil
    end

    local backpack = player:FindFirstChild("Backpack")
    if not backpack then
        return nil
    end

    local toolName = "Pet Clone Tool"
    local existing = backpack:FindFirstChild(toolName)
    if existing then
        return existing
    end

    local cloneTool = Instance.new("Tool")
    cloneTool.Name = toolName
    cloneTool.RequiresHandle = false
    cloneTool.CanBeDropped = false

    local petNameValue = Instance.new("StringValue")
    petNameValue.Name = "TemplatePetName"
    petNameValue.Value = pet.Name
    petNameValue.Parent = cloneTool

    local cooldownValue = Instance.new("NumberValue")
    cooldownValue.Name = "CooldownSeconds"
    cooldownValue.Value = DuplicationCooldown
    cooldownValue.Parent = cloneTool

    local cloneScript = Instance.new("LocalScript")
    cloneScript.Name = "CloneScript"
    cloneScript.Source = [[
local tool = script.Parent
local player = game.Players.LocalPlayer
local petNameValue = tool:WaitForChild("TemplatePetName")
local cooldownValue = tool:WaitForChild("CooldownSeconds")
local lastUse = 0

local function findTemplatePet()
    local character = player.Character
    if character then
        for _, item in ipairs(character:GetChildren()) do
            if item:IsA("Tool") and item.Name == petNameValue.Value and item ~= tool then
                return item
            end
        end
    end
    for _, item in ipairs(player.Backpack:GetChildren()) do
        if item:IsA("Tool") and item.Name == petNameValue.Value and item ~= tool then
            return item
        end
    end
    return nil
end

tool.Activated:Connect(function()
    local now = tick()
    if now - lastUse < cooldownValue.Value then
        return
    end

    local sourcePet = findTemplatePet()
    if not sourcePet then
        return
    end

    local clone = sourcePet:Clone()
    clone.Parent = player.Backpack
    lastUse = now
end)
]]
    cloneScript.Parent = cloneTool
    cloneTool.Parent = backpack
    return cloneTool
end

local function getPetRemoteCandidates()
    local remotes = {}
    local searchSources = {
        game:GetService("Workspace"),
        game:GetService("ReplicatedStorage"),
        game:GetService("ReplicatedFirst"),
        game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui"),
        game:GetService("Players").LocalPlayer:FindFirstChild("PlayerScripts")
    }
    local keywords = {"pet", "give", "claim", "reward", "spawn", "trade", "place", "garden", "inventory", "equip", "use", "buy", "shop", "crate", "purchase"}

    for _, source in ipairs(searchSources) do
        if source then
            for _, obj in ipairs(source:GetDescendants()) do
                if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                    local nameLower = obj.Name:lower()
                    for _, keyword in ipairs(keywords) do
                        if nameLower:find(keyword) then
                            table.insert(remotes, obj)
                            break
                        end
                    end
                end
            end
        end
    end

    return remotes
end

local function isPetCandidate(item)
    if not item or item.Name == "Pet Clone Tool" then
        return false
    end
    if item:IsA("Tool") then
        return true
    end
    if isPetName(item.Name) then
        return true
    end
    if item:IsA("Model") then
        for _, child in ipairs(item:GetChildren()) do
            if child:IsA("Tool") or child:IsA("Accessory") or child:IsA("Part") then
                return true
            end
        end
    end
    return false
end

local function findLocalPetTemplates()
    local player = game.Players.LocalPlayer
    local templates = {}
    local containers = {
        player:FindFirstChild("Backpack"),
        player.Character,
        player:FindFirstChild("Pets"),
        player:FindFirstChild("PetInventory"),
        player:FindFirstChild("Inventory"),
        player.PlayerGui and player.PlayerGui:FindFirstChild("PetInventory"),
        player.PlayerGui and player.PlayerGui:FindFirstChild("Inventory")
    }

    for _, container in ipairs(containers) do
        if container then
            for _, item in ipairs(container:GetChildren()) do
                if isPetCandidate(item) then
                    table.insert(templates, item)
                end
            end
        end
    end

    return templates
end

local function clonePetToInventory(source)
    local player = game.Players.LocalPlayer
    if not source then
        return nil
    end

    local clone = source:Clone()
    local dest = player:FindFirstChild("Backpack") or player:FindFirstChild("Pets") or player:FindFirstChild("PetInventory") or player:FindFirstChild("Inventory") or player.Character
    clone.Parent = dest or source.Parent
    return clone
end

local function safeSendRemote(remote, ...)
    local args = {...}
    return pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(table.unpack(args))
        else
            remote:InvokeServer(table.unpack(args))
        end
    end)
end

local function buildRemoteArgs(remote, template)
    local nameLower = remote.Name:lower()
    if template then
        if nameLower:find("buy") or nameLower:find("purchase") or nameLower:find("shop") or nameLower:find("crate") then
            return {template.Name, 1}
        end

        if nameLower:find("give") or nameLower:find("add") or nameLower:find("spawn") or nameLower:find("place") or nameLower:find("trade") or nameLower:find("inventory") or nameLower:find("pet") then
            return {template.Name}
        end
    end

    if nameLower:find("claim") or nameLower:find("reward") or nameLower:find("open") then
        return {}
    end

    if template then
        return {template.Name}
    end

    return {}
end

local function attemptRemoteDuplication(remote, args)
    if not remote then
        return false
    end
    if safeSendRemote(remote, table.unpack(args)) then
        task.wait(math.random(12, 30) / 100)
        safeSendRemote(remote, table.unpack(args))
        return true
    end
    return false
end

DuplicatePet = function()
    if isDuplicateOnCooldown() then
        setDuplicateStatus("Cooldown active: " .. math.ceil(getCooldownRemaining()) .. "s left")
        return
    end

    local currentPet = getCurrentHeldPet()
    local petTemplates = findLocalPetTemplates()
    local targetPet = currentPet or petTemplates[1]
    if not targetPet then
        setDuplicateStatus("No held or local pet tool found.")
        return
    end

    local remotes = getPetRemoteCandidates()
    local statusText = "No valid pet remote found. Attempting local clone."
    local tried = false
    local success = false

    if #remotes > 0 then
        for _, remote in ipairs(remotes) do
            local args = buildRemoteArgs(remote, targetPet)
            if attemptRemoteDuplication(remote, args) then
                statusText = "Attempted duplication via remote: " .. remote.Name
                tried = true
                success = true
                break
            end
        end
    end

    if not tried then
        local clone = clonePetToInventory(targetPet)
        if clone then
            statusText = "Cloned pet locally to inventory: " .. clone.Name
            success = true
            tried = true
        end
    end

    if success then
        local count = getPetInventoryCount(targetPet.Name)
        if count >= 2 then
            createCloneToolForPet(targetPet)
            lastDuplicateTime = tick()
            statusText = statusText .. " | Detected " .. tostring(count) .. " matching pets. Clone tool created. 2 min cooldown."
        else
            statusText = statusText .. " | Inventory count: " .. tostring(count)
        end
    else
        statusText = "Duplication attempt failed for " .. targetPet.Name
    end

    setDuplicateStatus(statusText)
end

spawn(function()
    while wait(1) do
        if isDuplicateOnCooldown() then
            setDuplicateStatus("Cooldown active: " .. math.ceil(getCooldownRemaining()) .. "s left")
        end
    end
end)

PetTab:CreateButton({
    Name = "⚠️ Duplicate Pet & Create Clone Tool ⚠️",
    Callback = DuplicatePet
})

PetTab:CreateLabel("Note: Experimental duplication. Most games validate pets server-side.")
PetTab:CreateLabel("If successful and two matching pets are detected, a Pet Clone Tool is created in Backpack.")
PetTab:CreateLabel("The clone tool copies the held pet and has a 2-minute cooldown.")

InfoTab:CreateParagraph({
    Title = "How to use",
    Content = "Use Auto Harvest / Auto Water for standard garden interactions.\nPet duplication is experimental and depends on the game's implementation.\nNo remote exploit can guarantee being undetected.\nThe UI is built with Rayfield and saved under OpexHub settings."
})

Rayfield:Notify({
    Title = "OpexHub Loaded",
    Content = "Garden + Pet tool ready",
    Duration = 3
})
