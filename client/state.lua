local state = {}

local isActive = false
local showVignette = GetConvarInt('ox_target:vignette', 1) == 1

---@return boolean
function state.isActive()
    return isActive
end

---@param value boolean
function state.setActive(value)
    isActive = value

    if value then
        SendNuiMessage(json.encode({
            event = 'visible',
            state = true,
            vignette = showVignette
        }))
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(true)
    else
        SetNuiFocus(false, false)
    end
end

local nuiFocus = false

---@return boolean
function state.isNuiFocused()
    return nuiFocus
end

---@param value boolean
function state.setNuiFocus(value, cursor)
    nuiFocus = value
    SetNuiFocus(value, cursor or false)
    SetNuiFocusKeepInput(value)
end

local isDisabled = false

---@return boolean
function state.isDisabled()
    return isDisabled
end

---@param value boolean
function state.setDisabled(value)
    isDisabled = value
end

return state
