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

local function getPetRemoteCandidates()
    local remotes = {}
    local searchSources = {
        game:GetService("ReplicatedStorage"),
        game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
    }

    for _, source in ipairs(searchSources) do
        if source then
            for _, obj in ipairs(source:GetDescendants()) do
                if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                    local nameLower = obj.Name:lower()
                    if nameLower:find("pet") or nameLower:find("give") or nameLower:find("claim") or nameLower:find("reward") or nameLower:find("spawn") or nameLower:find("trade") or nameLower:find("place") or nameLower:find("garden") or nameLower:find("inventory") then
                        table.insert(remotes, obj)
                    end
                end
            end
        end
    end

    return remotes
end

local function findLocalPetTemplates()
    local player = game.Players.LocalPlayer
    local templates = {}
    local containers = {
        player:FindFirstChild("Backpack"),
        player.Character,
        player:FindFirstChild("Pets"),
        player.PlayerGui and player.PlayerGui:FindFirstChild("PetInventory")
    }

    for _, container in ipairs(containers) do
        if container then
            for _, item in ipairs(container:GetChildren()) do
                if item:IsA("Tool") or item.Name:lower():find("pet") or item.Name:lower():find("companion") then
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
    return pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(...)
        else
            remote:InvokeServer(...)
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
    local petTemplates = findLocalPetTemplates()
    local remotes = getPetRemoteCandidates()
    local statusText = "No valid pet remote or local pet found."
    local tried = false

    if #remotes > 0 then
        for _, remote in ipairs(remotes) do
            local args = buildRemoteArgs(remote, petTemplates[1])
            if attemptRemoteDuplication(remote, args) then
                statusText = "Attempted duplication via remote: " .. remote.Name
                tried = true
                break
            end
        end
    end

    if not tried and #petTemplates > 0 then
        local clone = clonePetToInventory(petTemplates[1])
        if clone then
            statusText = "Cloned pet locally to inventory: " .. clone.Name
            local backupNames = {"AddPet", "SavePet", "SyncPet", "PlacePet", "TradePet", "GardenPet", "UpdateInventory"}
            for _, name in ipairs(backupNames) do
                local backupRemote = game:GetService("ReplicatedStorage"):FindFirstChild(name)
                if backupRemote and (backupRemote:IsA("RemoteEvent") or backupRemote:IsA("RemoteFunction")) then
                    attemptRemoteDuplication(backupRemote, {clone.Name})
                    statusText = statusText .. " + " .. name
                end
            end
            tried = true
        end
    end

    DuplicateStatus:Set("Status: " .. statusText)
end

PetTab:CreateButton({
    Name = "⚠️ Duplicate Pet / Add to Inventory ⚠️",
    Callback = DuplicatePet
})

PetTab:CreateLabel("Note: Experimental duplication. Most games validate pets server-side.")
PetTab:CreateLabel("This attempt tries to clone locally and call inventory/garden remotes.")

InfoTab:CreateParagraph({
    Title = "How to use",
    Content = "Use Auto Harvest / Auto Water for standard garden interactions.\nPet duplication is experimental and depends on the game's implementation.\nNo remote exploit can guarantee being undetected.\nThe UI is built with Rayfield and saved under OpexHub settings."
})

Rayfield:Notify({
    Title = "OpexHub Loaded",
    Content = "Garden + Pet tool ready",
    Duration = 3
})
