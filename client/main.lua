if not lib.checkDependency('ox_lib', '3.30.0', true) then return end

lib.locale()

local utils = require 'client.utils'
local state = require 'client.state'
local api = require 'client.api'
local options = api.getTargetOptions()

require 'client.debug'
require 'client.defaults'
require 'client.compat.qtarget'

local SendNuiMessage = SendNuiMessage
local GetEntityCoords = GetEntityCoords
local GetEntityType = GetEntityType
local HasEntityClearLosToEntity = HasEntityClearLosToEntity
local GetEntityBoneIndexByName = GetEntityBoneIndexByName
local GetEntityBonePosition_2 = GetEntityBonePosition_2
local GetEntityModel = GetEntityModel
local IsDisabledControlJustPressed = IsDisabledControlJustPressed
local DisableControlAction = DisableControlAction
local DisablePlayerFiring = DisablePlayerFiring
local GetModelDimensions = GetModelDimensions
local GetOffsetFromEntityInWorldCoords = GetOffsetFromEntityInWorldCoords
local currentTarget = {}
local currentMenu
local menuChanged
local menuHistory = {}
local nearbyZones

-- Toggle ox_target, instead of holding the hotkey
local toggleHotkey = GetConvarInt('ox_target:toggleHotkey', 0) == 1
local centerCursor = GetConvarInt('ox_target:centerCursor', 1) == 1
local targetingStartTime = 0
local lastStateChange = 0
local STATE_COOLDOWN = 300
local mouseButton = GetConvarInt('ox_target:leftClick', 1) == 1 and 24 or 25
local debug = GetConvarInt('ox_target:debug', 0) == 1
local drawOutline = GetConvarInt('ox_target:drawOutline', 1) == 1
local outlineDistance = GetConvarInt('ox_target:outlineDistance', 5)
local outlineUseTargetDistance = GetConvarInt('ox_target:outlineUseTargetDistance', 1) == 1
local outlineColor = {255, 255, 255, 255}
local outlineColorStr = GetConvar('ox_target:outlineColor', '255,255,255,255')
for i, v in ipairs({string.strsplit(',', outlineColorStr)}) do
    outlineColor[i] = tonumber(v) or 255
end
local vec0 = vec3(0, 0, 0)

---@param option OxTargetOption
---@param distance number
---@param endCoords vector3
---@param entityHit? number
---@param entityType? number
---@param entityModel? number | false
local function shouldHide(option, distance, endCoords, entityHit, entityType, entityModel)
    if option.menuName ~= currentMenu then
        return true
    end

    if distance > (option.distance or 7) then
        return true
    end

    if option.groups and not utils.hasPlayerGotGroup(option.groups) then
        return true
    end

    if option.items and not utils.hasPlayerGotItems(option.items, option.anyItem) then
        return true
    end

    local bone = entityModel and option.bones or nil

    if bone then
        ---@cast entityHit number
        ---@cast entityType number
        ---@cast entityModel number

        local _type = type(bone)

        if _type == 'string' then
            local boneId = GetEntityBoneIndexByName(entityHit, bone)

            if boneId ~= -1 and #(endCoords - GetEntityBonePosition_2(entityHit, boneId)) <= 2 then
                bone = boneId
            else
                return true
            end
        elseif _type == 'table' then
            local closestBone, boneDistance

            for j = 1, #bone do
                local boneId = GetEntityBoneIndexByName(entityHit, bone[j])

                if boneId ~= -1 then
                    local dist = #(endCoords - GetEntityBonePosition_2(entityHit, boneId))

                    if dist <= (boneDistance or 1) then
                        closestBone = boneId
                        boneDistance = dist
                    end
                end
            end

            if closestBone then
                bone = closestBone
            else
                return true
            end
        end
    end

    local offset = entityModel and option.offset or nil

    if offset then
        ---@cast entityHit number
        ---@cast entityType number
        ---@cast entityModel number

        if not option.absoluteOffset then
            local min, max = GetModelDimensions(entityModel)
            offset = (max - min) * offset + min
        end

        offset = GetOffsetFromEntityInWorldCoords(entityHit, offset.x, offset.y, offset.z)

        if #(endCoords - offset) > (option.offsetSize or 1) then
            return true
        end
    end

    if option.canInteract then
        local success, resp = pcall(option.canInteract, entityHit, distance, endCoords, option.name, bone)
        return not success or not resp
    end
end

local function startTargeting()
    local now = GetGameTimer()
    if now - lastStateChange < STATE_COOLDOWN then return end
    if state.isDisabled() or state.isActive() or IsNuiFocused() or IsPauseMenuActive() then return end

    lastStateChange = now
    state.setActive(true)

    if centerCursor then
        SetCursorLocation(0.5, 0.5)
    end

    local flag = 511
    local hit, entityHit, endCoords, distance, entityType, entityModel, hasTarget, zonesChanged
    local lastEntity = -1
    local zones = {}
    local optionsLocked = false
    local lockTime = 0
    local lockedMaxDistance = 7
    local lockedTargetCoords = nil
    local outlinedEntity = nil

    CreateThread(function()
        local dict, texture = utils.getTexture()
        local lastCoords

        while state.isActive() do
            lastCoords = endCoords == vec0 and lastCoords or endCoords or vec0

            if debug then
                DrawMarker(28, lastCoords.x, lastCoords.y, lastCoords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.2, 0.2,
                    0.2,
                    ---@diagnostic disable-next-line: param-type-mismatch
                    255, 42, 24, 100, false, false, 0, true, false, false, false)
            end

            utils.drawZoneSprites(dict, texture)
            DisablePlayerFiring(cache.playerId, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)

            if optionsLocked then
                if IsDisabledControlJustPressed(0, 25) then
                    optionsLocked = false
                    lockTime = 0
                    lockedTargetCoords = nil
                    lastEntity = -1
                    SendNuiMessage('{"event": "unlockOptions"}')
                end
            elseif hasTarget and IsDisabledControlJustPressed(0, mouseButton) then
                optionsLocked = true
                lockTime = GetGameTimer()

                lockedMaxDistance = 7
                for _, v in pairs(options) do
                    for i = 1, #v do
                        local opt = v[i]
                        if not opt.hide then
                            local d = opt.distance or 7
                            if d > lockedMaxDistance then lockedMaxDistance = d end
                        end
                    end
                end
                if nearbyZones then
                    for i = 1, #nearbyZones do
                        local zoneOpts = nearbyZones[i].options
                        for j = 1, #zoneOpts do
                            local opt = zoneOpts[j]
                            if not opt.hide then
                                local d = opt.distance or 7
                                if d > lockedMaxDistance then lockedMaxDistance = d end
                            end
                        end
                    end
                end

                lockedTargetCoords = currentTarget.coords

                SendNuiMessage('{"event": "lockOptions"}')
            end

            Wait(0)
        end

        SetStreamedTextureDictAsNoLongerNeeded(dict)
    end)

    while state.isActive() do
        if not state.isNuiFocused() and lib.progressActive() then
            state.setActive(false)
            break
        end

        if optionsLocked then
            local playerCoords = GetEntityCoords(cache.ped)
            local _, _, raycastCoords = utils.raycastFromCursor(flag, 20)
            local playerDistToTarget = #(playerCoords - raycastCoords)

            if playerDistToTarget > lockedMaxDistance then
                optionsLocked = false
                lockTime = 0
                lockedTargetCoords = nil
                lastEntity = -1
                SendNuiMessage('{"event": "unlockOptions"}')
                SendNuiMessage('{"event": "leftTarget"}')
                hasTarget = false
                Wait(50)
                goto continue
            end

            if GetGameTimer() - lockTime < 500 then
                Wait(50)
                goto continue
            end

            local cursorDistFromTarget = #(raycastCoords - lockedTargetCoords)

            if cursorDistFromTarget > lockedMaxDistance then
                optionsLocked = false
                lockTime = 0
                lockedTargetCoords = nil
                lastEntity = -1
                SendNuiMessage('{"event": "unlockOptions"}')
                SendNuiMessage('{"event": "leftTarget"}')
                hasTarget = false
                Wait(50)
                goto continue
            end

            Wait(50)
            goto continue
        end

        local playerCoords = GetEntityCoords(cache.ped)
        hit, entityHit, endCoords = utils.raycastFromCursor(flag, 20)
        distance = #(playerCoords - endCoords)

        if entityHit ~= 0 and entityHit ~= lastEntity then
            local success, result = pcall(GetEntityType, entityHit)
            entityType = success and result or 0
        end

        if entityType == 0 then
            local _flag = flag == 511 and 26 or 511
            local _hit, _entityHit, _endCoords = utils.raycastFromCursor(_flag, 20)
            local _distance = #(playerCoords - _endCoords)

            if _distance < distance then
                flag, hit, entityHit, endCoords, distance = _flag, _hit, _entityHit, _endCoords, _distance

                if entityHit ~= 0 then
                    local success, result = pcall(GetEntityType, entityHit)
                    entityType = success and result or 0
                end
            end
        end

        nearbyZones, zonesChanged = utils.getNearbyZones(endCoords)

        local entityChanged = entityHit ~= lastEntity
        local newOptions = (zonesChanged or entityChanged or menuChanged) and true

        if entityHit > 0 and entityChanged then
            currentMenu = nil

            if flag ~= 511 then
                entityHit = HasEntityClearLosToEntity(entityHit, cache.ped, 7) and entityHit or 0
            end

            if entityHit > 0 then
                local success, result = pcall(GetEntityModel, entityHit)
                entityModel = success and result
            end

        end

        if drawOutline then
            local maxDist = api.getEntitySpecificTargetDistance(entityHit, entityModel)
            if maxDist == 0 then maxDist = outlineDistance end
            local shouldOutline = entityHit > 0 and entityType ~= 1 and distance <= maxDist and api.entityHasSpecificTargets(entityHit, entityModel)

            if shouldOutline and outlinedEntity ~= entityHit then
                if outlinedEntity then
                    SetEntityDrawOutline(outlinedEntity, false)
                end
                SetEntityDrawOutlineColor(outlineColor[1], outlineColor[2], outlineColor[3], outlineColor[4])
                SetEntityDrawOutline(entityHit, true)
                outlinedEntity = entityHit
            elseif not shouldOutline and outlinedEntity then
                SetEntityDrawOutline(outlinedEntity, false)
                outlinedEntity = nil
            end
        end

        if hasTarget and (zonesChanged or entityChanged and hasTarget > 1) then
            SendNuiMessage('{"event": "leftTarget"}')

            if entityChanged then options:wipe() end

            hasTarget = false
        end

        if newOptions and entityModel and entityHit > 0 then
            options:set(entityHit, entityType, entityModel)
        end

        lastEntity = entityHit
        currentTarget.entity = entityHit
        currentTarget.coords = endCoords
        currentTarget.distance = distance
        local hidden = 0
        local totalOptions = 0

        for k, v in pairs(options) do
            local optionCount = #v
            local dist = k == '__global' and 0 or distance
            totalOptions += optionCount

            for i = 1, optionCount do
                local option = v[i]
                local hide = shouldHide(option, dist, endCoords, entityHit, entityType, entityModel)

                if option.hide ~= hide then
                    option.hide = hide
                    newOptions = true
                end

                if hide then hidden += 1 end
            end
        end

        if zonesChanged then table.wipe(zones) end

        for i = 1, #nearbyZones do
            local zoneOptions = nearbyZones[i].options
            local optionCount = #zoneOptions
            totalOptions += optionCount
            zones[i] = zoneOptions

            for j = 1, optionCount do
                local option = zoneOptions[j]
                local hide = shouldHide(option, distance, endCoords, entityHit)

                if option.hide ~= hide then
                    option.hide = hide
                    newOptions = true
                end

                if hide then hidden += 1 end
            end
        end

        if newOptions then
            if hasTarget == 1 and (totalOptions - hidden) > 1 then
                hasTarget = true
            end

            if hasTarget and hidden == totalOptions then
                if hasTarget and hasTarget ~= 1 then
                    hasTarget = false
                    SendNuiMessage('{"event": "leftTarget"}')
                end
            elseif menuChanged or hasTarget ~= 1 and hidden ~= totalOptions then
                hasTarget = options.size

                if currentMenu and options.__global[1]?.name ~= 'builtin:goback' then
                    table.insert(options.__global, 1,
                        {
                            icon = 'fa-solid fa-circle-chevron-left',
                            label = locale('go_back'),
                            name = 'builtin:goback',
                            menuName = currentMenu,
                            openMenu = 'home'
                        })
                end

                SendNuiMessage(json.encode({
                    event = 'setTarget',
                    options = options,
                    zones = zones,
                }, { sort_keys = true }))
            end

            menuChanged = false
        end

        if toggleHotkey and IsPauseMenuActive() then
            state.setActive(false)
        end

        if not hasTarget or hasTarget == 1 then
            flag = flag == 511 and 26 or 511
        end

        Wait(hit and 50 or 100)
        ::continue::
    end

    if drawOutline and outlinedEntity then
        SetEntityDrawOutline(outlinedEntity, false)
    end

    state.setNuiFocus(false)
    SendNuiMessage('{"event": "visible", "state": false}')
    table.wipe(currentTarget)
    options:wipe()

    if nearbyZones then table.wipe(nearbyZones) end
    lastStateChange = GetGameTimer()
end

do
    ---@type KeybindProps
    local keybind = {
        name = 'ox_target',
        defaultKey = GetConvar('ox_target:defaultHotkey', 'LMENU'),
        defaultMapper = 'keyboard',
        description = locale('toggle_targeting'),
    }

    if toggleHotkey then
        function keybind:onPressed()
            local now = GetGameTimer()
            if now - lastStateChange < STATE_COOLDOWN then return end

            if state.isActive() then
                return state.setActive(false)
            end

            return startTargeting()
        end
    else
        function keybind:onPressed()
            startTargeting()
            if state.isActive() then
                targetingStartTime = GetGameTimer()
            end
        end

        function keybind:onReleased()
            if not state.isActive() then return end

            -- Grace period to prevent instant close from spurious releases
            if GetGameTimer() - targetingStartTime < 200 then return end

            state.setActive(false)
        end
    end

    lib.addKeybind(keybind)
end

---@generic T
---@param option T
---@param server? boolean
---@return T
local function getResponse(option, server)
    local response = table.clone(option)
    response.entity = currentTarget.entity
    response.zone = currentTarget.zone
    response.coords = currentTarget.coords
    response.distance = currentTarget.distance

    if server then
        response.entity = response.entity ~= 0 and NetworkGetEntityIsNetworked(response.entity) and
            NetworkGetNetworkIdFromEntity(response.entity) or 0
    end

    response.icon = nil
    response.groups = nil
    response.items = nil
    response.canInteract = nil
    response.onSelect = nil
    response.export = nil
    response.event = nil
    response.serverEvent = nil
    response.command = nil

    return response
end

RegisterNUICallback('select', function(data, cb)
    cb(1)

    local zone = data[3] and nearbyZones[data[3]]

    ---@type OxTargetOption?
    local option = zone and zone.options[data[2]] or options[data[1]][data[2]]

    if option then
        if option.openMenu then
            local menuDepth = #menuHistory

            if option.name == 'builtin:goback' then
                option.menuName = option.openMenu
                option.openMenu = menuHistory[menuDepth]

                if menuDepth > 0 then
                    menuHistory[menuDepth] = nil
                end
            else
                menuHistory[menuDepth + 1] = currentMenu
            end

            menuChanged = true
            currentMenu = option.openMenu ~= 'home' and option.openMenu or nil

            options:wipe()
        else
            state.setNuiFocus(false)
        end

        currentTarget.zone = zone?.id

        if option.onSelect then
            option.onSelect(option.qtarget and currentTarget.entity or getResponse(option))
        elseif option.export then
            exports[option.resource or zone.resource][option.export](nil, getResponse(option))
        elseif option.event then
            TriggerEvent(option.event, getResponse(option))
        elseif option.serverEvent then
            TriggerServerEvent(option.serverEvent, getResponse(option, true))
        elseif option.command then
            ExecuteCommand(option.command)
        end

        if option.menuName == 'home' then return end
    end

    if not option?.openMenu and IsNuiFocused() then
        state.setActive(false)
    end
end)
