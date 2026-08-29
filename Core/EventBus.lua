local _, Cortex = ...

local EventBus = {
    subscribers = {},
    nextToken = 1,
}

function EventBus:Subscribe(eventName, owner, callback)
    if type(eventName) ~= "string" or eventName == "" or owner == nil or type(callback) ~= "function" then
        return nil
    end

    local token = self.nextToken
    self.nextToken = token + 1
    local subscribers = self.subscribers[eventName]
    if not subscribers then
        subscribers = {}
        self.subscribers[eventName] = subscribers
    end

    subscribers[#subscribers + 1] = {
        token = token,
        owner = owner,
        callback = callback,
    }
    return token
end

function EventBus:Unsubscribe(token)
    if type(token) ~= "number" then
        return false
    end

    for eventName, subscribers in pairs(self.subscribers) do
        for index = #subscribers, 1, -1 do
            if subscribers[index].token == token then
                table.remove(subscribers, index)
                if #subscribers == 0 then
                    self.subscribers[eventName] = nil
                end
                return true
            end
        end
    end
    return false
end

function EventBus:UnsubscribeOwner(owner)
    local removed = 0
    for eventName, subscribers in pairs(self.subscribers) do
        for index = #subscribers, 1, -1 do
            if subscribers[index].owner == owner then
                table.remove(subscribers, index)
                removed = removed + 1
            end
        end
        if #subscribers == 0 then
            self.subscribers[eventName] = nil
        end
    end
    return removed
end

function EventBus:Publish(eventName, ...)
    Cortex:GetService("Profiler"):RecordEvent("internal", eventName)
    local subscribers = self.subscribers[eventName]
    if not subscribers or #subscribers == 0 then
        return 0
    end

    local snapshot = {}
    for index = 1, #subscribers do
        snapshot[index] = subscribers[index]
    end

    local delivered = 0
    local logger = Cortex:GetService("Logger")
    for index = 1, #snapshot do
        local subscriber = snapshot[index]
        local ok = pcall(subscriber.callback, subscriber.owner, ...)
        if ok then
            delivered = delivered + 1
        elseif logger then
            logger:Error(Cortex:GetText("EVENT_HANDLER_ERROR", eventName))
        end
    end
    return delivered
end

Cortex.Events = EventBus
Cortex:RegisterService("Events", EventBus, { services = { "Logger", "Profiler" } })
