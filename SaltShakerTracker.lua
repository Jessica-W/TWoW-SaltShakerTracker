local COLOUR_CYAN = "|cff00ffff"

local function GetCooldownLeft(start, duration)
    -- Before restarting the GetTime() will always be greater than [start]
    -- After the restart, [start] is technically always bigger because of the 2^32 offset thing
    if start < GetTime() then
        local cdEndTime = start + duration
        local cdLeftDuration = cdEndTime - GetTime()

        return cdLeftDuration
    end

    local time = time()
    local startupTime = time - GetTime()
    -- just a simplification of: ((2^32) - (start * 1000)) / 1000
    local cdTime = (2 ^ 32) / 1000 - start
    local cdStartTime = startupTime - cdTime
    local cdEndTime = cdStartTime + duration
    local cdLeftDuration = cdEndTime - time

    return cdLeftDuration
end

local function FormatTime(time)
    local days = floor(time/86400)
    local hours = floor(mod(time, 86400)/3600)
    local minutes = ceil(mod(time,3600)/60)

    return format("%d days %d hours %d minutes",days,hours,minutes)
end

local function GetItemIdFromLink(link)
    local _,_,id = string.find(link, "^.*|Hitem:(%d*):.*%[.*%].*$")

    return tonumber(id)
end

local function find_item_in_bags(itemID)
    for i = 0, NUM_BAG_SLOTS do
        for z = 1, GetContainerNumSlots(i) do
            local link = GetContainerItemLink(i, z)
            if link then
                local containerItemId = GetItemIdFromLink(link)

                if containerItemId == itemID then
                    return i, z
                end
            end
        end
    end
end

local function GetSaltShakerTimeOffCooldown()
    local bagID, slot = find_item_in_bags(15846) -- 15846 is the item ID for the salt shaker
    if bagID then
        local startTime, duration, isEnabled = GetContainerItemCooldown(bagID, slot)
        local cdLeftDuration = GetCooldownLeft(startTime, duration)
        local offCd = cdLeftDuration + time()

        return offCd
    else
        local COLOUR_COPPER = "|cffeda55f"
        DEFAULT_CHAT_FRAME:AddMessage(COLOUR_COPPER.."No salt shaker detected")
        return nil
    end
end

local function ListSaltShakerCooldowns()
    local now = time()
    local sortedCooldowns = {}

    for char, offCd in pairs(SaltShakerCooldown) do
        table.insert(sortedCooldowns, {char, offCd})
    end

    table.sort(sortedCooldowns, function (a, b)
        return a[2] < b[2]
    end)

    for _, cooldown in ipairs(sortedCooldowns) do
        local char = cooldown[1]
        local offCd = cooldown[2]
        local cdLeftDuration = offCd - now

        if (cdLeftDuration <= 0) then
            DEFAULT_CHAT_FRAME:AddMessage(char.." has available Salt Shaker cooldown")
        else
            DEFAULT_CHAT_FRAME:AddMessage(char.." has available Salt Shaker cooldown in "..FormatTime(cdLeftDuration))
        end
    end
end

SLASH_SSCD1="/sscd"
SlashCmdList["SSCD"] = function(msg)
    ListSaltShakerCooldowns()
end

function SaltShakerTracker_OnLoad()
    DEFAULT_CHAT_FRAME:AddMessage("SS OnLoad")
    this:RegisterEvent("PLAYER_ENTERING_WORLD")
    this:RegisterEvent("BAG_UPDATE_COOLDOWN")
end

function SaltShakerCooldown_OnEvent(event)
	if event == "PLAYER_ENTERING_WORLD" then
		this:UnregisterEvent("ADDON_LOADED")
		SaltShakerCooldown_Load()
    elseif event == "BAG_UPDATE_COOLDOWN" then
        DEFAULT_CHAT_FRAME:AddMessage(COLOUR_CYAN.."item in bag changed cooldown")
        DelayedFunc_Add(0.5, SaltShakerCooldown_Load)
        DelayedFunc_Add(1, SaltShakerCooldown_Load)
	end
end

function SaltShakerCooldown_Load()
    if not SaltShakerCooldown then
        SaltShakerCooldown = {}
    end

    local cooldown = GetSaltShakerTimeOffCooldown()

    if cooldown then
        SaltShakerCooldown[UnitName("player")] = cooldown
    end
end

local period = 300
local initialDelay = 3
local lastTriggeredTime = GetTime()-(period-initialDelay)

function CheckSaltShakerDelay()
    local now = GetTime()

    if now - lastTriggeredTime > period then
        SaltShakerCooldown_CheckForAvailability()
        lastTriggeredTime = now
    end
end

local timeSinceLastTick = 0

function SaltShakerCooldown_OnUpdate()
    timeSinceLastTick = timeSinceLastTick + arg1

    while timeSinceLastTick > 0.1 do
        DelayedFunc_Tick(0.1)
        CheckSaltShakerDelay()

        timeSinceLastTick = timeSinceLastTick - 0.1
    end
end

function SaltShakerCooldown_CheckForAvailability()
    local now = time()

    for char, offCd in pairs(SaltShakerCooldown) do
        local cdLeftDuration = offCd - now
        --DEFAULT_CHAT_FRAME:AddMessage(cdLeftDuration)

        if (cdLeftDuration <= 0) then
            DEFAULT_CHAT_FRAME:AddMessage(COLOUR_CYAN..char.." has available Salt Shaker cooldown")
        end
    end
end

local delayedFuncs = {}

function DelayedFunc_Add(delay, func)
    table.insert(delayedFuncs, {delayRemaining = delay, func = func})
end

function DelayedFunc_Tick(elapsed)
    for i, delayedFunc in ipairs(delayedFuncs) do
        delayedFunc.delayRemaining = delayedFunc.delayRemaining - elapsed

        if delayedFunc.delayRemaining <= 0 then
            delayedFunc.func(0.1)
            table.remove(delayedFuncs, i)
        end
    end
end

SLASH_DDBG1="/ddbg"
SlashCmdList["DDBG"] = function(msg)
    for i, delayedFunc in ipairs(delayedFuncs) do
        DEFAULT_CHAT_FRAME:AddMessage(i.." remaining: "..delayedFunc.delayRemaining)
    end
end

SLASH_DADD1="/dadd"
SlashCmdList["DADD"] = function(msg)
    DelayedFunc_Add(5, function()
        DEFAULT_CHAT_FRAME:AddMessage("delayed")
    end)
end