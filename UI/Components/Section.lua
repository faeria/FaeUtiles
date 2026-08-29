local _, Cortex = ...
local UI = Cortex.UI

local Section = {}

function Section.Create(parent, title)
    local section = CreateFrame("Frame", nil, parent)
    section.title = UI.CreateText(section, "GameFontNormal", UI.Theme.colors.muted)
    section.title:SetPoint("TOPLEFT")
    section.title:SetText(title or "")
    section.content = CreateFrame("Frame", nil, section)
    section.content:SetPoint("TOPLEFT", 0, -24)
    section.content:SetPoint("BOTTOMRIGHT")
    function section:SetTitle(text) self.title:SetText(text or "") end
    return section
end

UI.Section = Section
