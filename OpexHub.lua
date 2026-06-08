-- OpexHub: Garden + Pet Duplicate UI (Rayfield)
-- Features:
--   - Auto harvest / auto water for garden objects
--   - Manual harvest / water actions
--   - Experimental pet duplication attempt
-- Note: Pet duplication is highly game-specific and usually fails on secure servers.

local Rayfield = loadstring(game:HttpGet("https://raw.githubusercontent.com/shlexware/Rayfield/main/source.lua"))()

local Window = Rayfield:CreateWindow({
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

local GardenTab = Window:CreateTab("Garden")
local PetTab = Window:CreateTab("Pets")
local InfoTab = Window:CreateTab("Info")

local AutoHarvest = false
local AutoWater = false

local function safeFindPlayerCharacter()
    local player = game.Players.LocalPlayer
    return player and player.Character
end

local function HarvestAll()
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

local function WaterAll()
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
    Callback = HarvestAll
})

GardenTab:CreateButton({
    Name = "Water Once",
    Callback = WaterAll
})

local DuplicateStatus = PetTab:CreateLabel("Status: Idle")
local DuplicationCooldown = 120
local lastDuplicateTime = 0

local function setDuplicateStatus(text)
    DuplicateStatus:Set("Status: " .. text)
end

local function getCooldownRemaining()
    local remaining = DuplicationCooldown - (tick() - lastDuplicateTime)
    return remaining > 0 and remaining or 0
end

local function isDuplicateOnCooldown()
    return getCooldownRemaining() > 0
end

local function isPetName(name)
    local lower = name:lower()
    return lower:find("pet") or lower:find("companion") or lower:find("buddy") or lower:find("farm") or lower:find("animal")
end

local function getCurrentHeldPet()
    local player = game.Players.LocalPlayer
    local character = player and player.Character
    if not character then
        return nil
    end
    local tool = character:FindFirstChildOfClass("Tool")
    if tool and tool.Name ~= "Pet Clone Tool" and isPetName(tool.Name) then
        return tool
    end
    for _, item in ipairs(character:GetChildren()) do
        if item.Name ~= "Pet Clone Tool" and isPetName(item.Name) then
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
                if item:IsA("Tool") and item.Name == petName then
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
    local dest = player:FindFirstChild("Backpack") or player:FindFirstChild("Pets") or player.Character
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

local function DuplicatePet()
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
