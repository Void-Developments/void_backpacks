local Config = require 'config'
local existingStashes = {}

local ox_inventory = exports.ox_inventory

local function useBackpack(event, _, inventory, slot, _)
    if event ~= 'usingItem' then return end

    local progressBar = lib.callback.await('openingBackpack', inventory.id)
    if not progressBar then return end

    local backpack = ox_inventory:GetSlot(inventory.id, slot)
    if not backpack.metadata.bagId then return end

    if not existingStashes[backpack.metadata.bagId] then
        local bag = Config.Bags[backpack.name]

        ox_inventory:RegisterStash(backpack.metadata.bagId, 'Bag', bag.slots, bag.maxWeight)
        existingStashes[backpack.metadata.bagId] = true
    end

    TriggerClientEvent('ox_inventory:openInventory', inventory.id, 'stash', backpack.metadata.bagId)
end
exports('useBackpack', useBackpack)

local backpacks, itemFilter = {}, {}
AddEventHandler('onServerResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    for bag, _ in pairs(Config.Bags) do
        backpacks[#backpacks + 1] = bag
        itemFilter[bag] = true
    end

    ox_inventory:registerHook('createItem', function(payload)
        local metadata = payload.metadata

        local uniqueId = GetGameTimer() .. math.random(1000, 9999)
        metadata.bagId = uniqueId

        local bag = Config.Bags[payload.item.name]

        ox_inventory:RegisterStash(uniqueId, 'Bag', bag.slots, bag.maxWeight)
        existingStashes[uniqueId] = true

        if tonumber(payload.inventoryId) then
            Player(payload.inventoryId).state.carryBag = payload.item.name
        end

        return metadata
    end, {
        itemFilter = itemFilter
    })

    ox_inventory:registerHook('swapItems', function(payload)
        local source = payload.fromInventory
        local targetSource = payload.toInventory

        if source == targetSource then return true end

        if payload.action ~= 'move' then return end

        if payload.fromType == 'player' then
            local bagCount = ox_inventory:Search(source, 'count', backpacks) - 1
            if bagCount < 1 then Player(source).state.carryBag = false end
        end

        if payload.toType == 'player' then
            local targetBagCount = ox_inventory:Search(targetSource, 'count', backpacks)
            if not Config.AllowMultipleBags and targetBagCount > 0 then return false end

            Player(targetSource).state.carryBag = payload.fromSlot.name
        end

        return true
    end, {
        itemFilter = itemFilter
    })
end)


local framework = GetConvar('inventory:framework', 'ox')

local function initItemCheck(source)
    if not source then return end

    local bags = ox_inventory:Search(source, 'slots', backpacks)
    Player(source).state.carryBag = bags[1]?.name or false
end

local function resetState(source)
    if not source then return end
    Player(source).state.carryBag = false
end

if framework == 'qb' then
    RegisterNetEvent('QBCore:Server:OnPlayerLoaded', initItemCheck)
    RegisterNetEvent('QBCore:Server:OnPlayerUnload', resetState)
end

if framework == 'ox' then
    AddEventHandler('ox:playerLoaded', initItemCheck)
    AddEventHandler('ox:playerLogout', resetState)
end

if framework == 'esx' then
    RegisterNetEvent('ox:playerLoaded', initItemCheck)
    RegisterNetEvent('esx:playerDropped', resetState)
end

AddEventHandler('onServerResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    ox_inventory:removeHooks()
end)
