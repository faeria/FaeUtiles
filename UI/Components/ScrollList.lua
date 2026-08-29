local _, Cortex = ...
local UI = Cortex.UI

local ScrollList = {}

function ScrollList.Create(parent, options)
    options = options or {}
    local list = CreateFrame("Frame", nil, parent)
    list.rows = {}
    list.capacity = options.capacity or 3
    list.rowHeight = options.rowHeight or 66
    list.updateRow = options.updateRow
    for index = 1, list.capacity do
        local row = options.createRow(list, index)
        row:SetPoint("TOPLEFT", 0, -((index - 1) * (list.rowHeight + 8)))
        row:SetPoint("RIGHT")
        row:SetHeight(list.rowHeight)
        row:Hide()
        list.rows[index] = row
    end
    function list:SetItems(items)
        items = type(items) == "table" and items or {}
        for index = 1, self.capacity do
            local row, item = self.rows[index], items[index]
            if item then
                self.updateRow(row, item, index)
                row:Show()
            else
                row:Hide()
            end
        end
    end
    return list
end

UI.ScrollList = ScrollList
