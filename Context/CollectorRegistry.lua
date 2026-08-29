local _, Cortex = ...
local collectors, order = {}, {}

function Cortex:RegisterCollector(name, collector)
    if type(name) ~= "string" or name == "" or type(collector) ~= "table" or collectors[name]
        or type(collector.Collect) ~= "function" then return false end
    collector.name = name
    collectors[name] = collector
    order[#order + 1] = name
    return true
end

function Cortex:GetCollector(name) return collectors[name] end
function Cortex:GetCollectors() return collectors, order end
