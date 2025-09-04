local robbing = false

local function notify(title, description, type_, duration)
    lib.notify({
        title = title,
        description = description,
        type = type_,
        duration = duration or 7000,
    })
end

local function resetRobbery(warehouseId)
    robbing = false
    TriggerServerEvent("warehouse_robbery:resetRobberyStatus", warehouseId)
    ClearPedTasks(cache.ped)
end

local function VyloupitSklad(warehouseId)
    if robbing then 
        notify("Varování", "Vloupání již probíhá, počkej prosím.", "error")
        return 
    end

    robbing = true

    local canRob, remainingMinutes = lib.callback.await("warehouse_robbery:checkCooldown", false, warehouseId)
    if not canRob then
        notify("Chyba", ("Tento objekt byl **nedávno vykraden!** Zkus to znovu za **%d minut.**"):format(remainingMinutes), "error")
        robbing = false
        return
    end

    local success, message = lib.callback.await("warehouse_robbery:start", false, warehouseId)
    if not success then
        notify("Chyba", message or "Chyba při zahájení vloupání.", "error")
        robbing = false
        return
    end

    ExecuteCommand("e mechanic4")

    local uspech = exports['lockpick']:startLockpick()

    if not uspech then
        resetRobbery(warehouseId)
        notify("Neúspěch", "Zlomil se ti lockpick!", "error")
        return
    end

    local progressSuccess = lib.progressBar({
        duration = Config.DobaAnimace,
        label = "Lockpickuješ...",
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true,
        },
    })

    ClearPedTasks(cache.ped)

    if not progressSuccess then
        resetRobbery(warehouseId)
        notify("Chyba", "Přerušil jsi vloupání!", "error")
        return
    end

    local result, finishMessage = lib.callback.await("warehouse_robbery:finished", false, warehouseId)
    
    robbing = false

    if result then
        notify("Úspěch", finishMessage or "Vloupání bylo úspěšné!", "success")
    else
        notify("Neúspěch", finishMessage or "Vloupání selhalo.", "error")
    end
end

for i, sklad in ipairs(Config.Sklady) do
    exports.ox_target:addBoxZone({
        coords = sklad.coords,
        size = vec3(sklad.length, sklad.width, 2.0),
        rotation = sklad.heading,
        debug = false,
        options = {
            {
                name = "vloupani_sklad_" .. i,
                label = "Vykrást objekt",
                icon = "fa-solid fa-warehouse",
                distance = 1.5,
                onSelect = function()
                    VyloupitSklad(i)
                end,
            }
        }
    })
end