local ESX = exports["es_extended"]:getSharedObject()
local ox_inventory = exports["ox_inventory"]
local WarehouseCooldowns = {}
local ActiveRobberies = {}

local DISCORD_WEBHOOK = "https://discord.com/api/webhooksnKqG3Avo8C8_EvBGNIlYNL1t5BSs0PuJsSTNBP8m3uRVQrZMMsO5gDFRFlaqNM"
local DISCORD_AVATAR_URL = ""
local DISCORD_USERNAME = "skap_wrob"

local function ZiskejNahodnyLoot()
    if math.random() > Config.GlobalLootChance then
        return nil
    end

    local possibleLoot = {}
    for _, item in ipairs(Config.Loot) do
        local chance = item.chance or 100
        if math.random(100) <= chance then
            table.insert(possibleLoot, item)
        end
    end

    if #possibleLoot > 0 then
        return possibleLoot[math.random(#possibleLoot)]
    end

    return nil
end

local function checkAndGetInfo(source, warehouseId)
    local warehouseData = Config.Sklady[warehouseId]
    if not warehouseData then return false end

    local playerPed = GetPlayerPed(source)
    local playerCoords = GetEntityCoords(playerPed)
    if #(playerCoords - warehouseData.coords) > 10 then
        return false
    end

    return warehouseData
end

local function removeRequiredItem(source)
    local count = ox_inventory:GetItemCount(source, Config.RequiredItem)
    if count > 0 then
        ox_inventory:RemoveItem(source, Config.RequiredItem, 1)
        return true
    end
    return false
end

local function SendDiscordLog(source, warehouseId, lootItems, cooldownTime)
    local player = ESX.GetPlayerFromId(source)
    if not player then return end

    local playerName = GetPlayerName(source)
    local characterName = player.getName()
    local identifier = player.getIdentifier()
    local warehouseName = "Objekt č. " .. warehouseId
    local cooldownText = (cooldownTime / 60) .. " minut"

    local lootText = "Žádný loot"
    if lootItems and #lootItems > 0 then
        lootText = table.concat(lootItems, ", ")
    end

    local embed = {
        {
            ["color"] = 16777215,
            ["title"] = "Vykrádání objektů - Cayo Perico 📦",
            ["description"] = "Hráč vykradl objekt **na Cayu**",
            ["fields"] = {
                {
                    ["name"] = "Hráč:",
                    ["value"] = ("`Uživatelské jméno:` %s\n`Postava:` %s\n`ID:` %d\n`Identifier:` %s"):format(playerName, characterName, source, identifier),
                    ["inline"] = false
                },
                {
                    ["name"] = "Objekt:",
                    ["value"] = warehouseName,
                    ["inline"] = true
                },
                {
                    ["name"] = "Cooldown:",
                    ["value"] = cooldownText,
                    ["inline"] = true
                },
                {
                    ["name"] = "Získané předměty:",
                    ["value"] = lootText,
                    ["inline"] = false
                }
            },
            ["footer"] = {
                ["text"] = os.date("%d.%m.%Y %H:%M:%S")
            }
        }
    }

    PerformHttpRequest(DISCORD_WEBHOOK, function(err, text, headers) end, 'POST', json.encode({
        username = DISCORD_USERNAME,
        avatar_url = DISCORD_AVATAR_URL,
        embeds = embed
    }), { ['Content-Type'] = 'application/json' })
end

lib.callback.register("warehouse_robbery:checkCooldown", function(source, warehouseId)
    local currentTime = os.time()

    if WarehouseCooldowns[warehouseId] then
        local elapsed = currentTime - WarehouseCooldowns[warehouseId]
        if elapsed < Config.Cooldown then
            local remaining = math.ceil((Config.Cooldown - elapsed) / 60)
            return false, remaining
        end
    end

    if ActiveRobberies[warehouseId] then
        return false, 0, "Někdo **již vykrádá** tento objekt!"
    end

    return true, 0
end)

lib.callback.register("warehouse_robbery:start", function(source, warehouseId)
    if ActiveRobberies[warehouseId] then
        return false, "Někdo **již vykrádá** tento objekt!"
    end

    if not removeRequiredItem(source) then
        return false, "Nemáš u sebe **lockpick!**"
    end

    ActiveRobberies[warehouseId] = true
    return true
end)

lib.callback.register("warehouse_robbery:finished", function(source, warehouseId)
    local player = ESX.GetPlayerFromId(source)
    if not player then
        ActiveRobberies[warehouseId] = nil
        return false, "Hráč nenalezen."
    end

    local warehouseData = checkAndGetInfo(source, warehouseId)
    if not warehouseData then
        ActiveRobberies[warehouseId] = nil
        return false, "Tento objekt neexistuje nebo jsi příliš daleko."
    end

    WarehouseCooldowns[warehouseId] = os.time()
    ActiveRobberies[warehouseId] = nil

    if math.random(100) <= Config.DispatchChance then
        TriggerClientEvent("cd_dispatch:AddNotification", -1, {
            job_table = {"usa"},
            coords = warehouseData.coords,
            title = "Vykrádání skladů",
            message = "Někdo vykrádá sklady na ostrově Cayo Perico!",
            flash = 0,
            unique_id = tostring(math.random(0, 9999999)),
            sound = 1,
            blip = {
                sprite = 473,
                scale = 0.5,
                colour = 1,
                flashes = false,
                text = "Vykrádání skladů",
                time = 5,
                radius = 0,
            }
        })

        lib.notify({
            title = "Alarm",
            description = "Spustil se alarm!",
            type = "error",
            duration = 5000
        })
    end

    local lootCount = math.random(2, 4)
    local foundItems = {}
    local foundAny = false

    for _ = 1, lootCount do
        local lootData = ZiskejNahodnyLoot()
        if lootData then
            foundAny = true
            local metadata = lootData.metadata and lib.utils.deepCopy(lootData.metadata) or {}

            if lootData.randomDurability then
                metadata.durability = math.random(lootData.randomDurability.min, lootData.randomDurability.max)
            end

            local success, itemData = ox_inventory:AddItem(source, lootData.name, 1, metadata)
            if success and itemData and itemData.label then
                table.insert(foundItems, itemData.label)
            end
        end
    end

    SendDiscordLog(source, warehouseId, foundItems, Config.Cooldown)

    if not foundAny then
        return false, "Nic jsi **nenašel.**"
    end

    if #foundItems > 0 then
        return true, ("Našel jsi: **%s!**"):format(table.concat(foundItems, ", "))
    else
        return false, "Našel jsi předměty, ale nastala chyba v přidávání do inventáře."
    end
end)

RegisterNetEvent("warehouse_robbery:resetRobberyStatus", function(warehouseId)
    ActiveRobberies[warehouseId] = nil
end)

AddEventHandler('playerDropped', function()
    for warehouseId in pairs(ActiveRobberies) do
        ActiveRobberies[warehouseId] = nil
    end
end)