local _, Cortex = ...

local UI = {
    Theme = {
        colors = {
            window = { 0.035, 0.043, 0.059, 0.98 },
            sidebar = { 0.047, 0.055, 0.074, 1 },
            surface = { 0.065, 0.075, 0.098, 1 },
            surfaceHover = { 0.085, 0.098, 0.128, 1 },
            border = { 0.16, 0.18, 0.23, 0.9 },
            accent = { 0.31, 0.67, 0.96, 1 },
            accentSoft = { 0.12, 0.27, 0.40, 1 },
            text = { 0.92, 0.94, 0.98, 1 },
            muted = { 0.57, 0.62, 0.70, 1 },
            success = { 0.34, 0.78, 0.56, 1 },
            warning = { 0.95, 0.69, 0.31, 1 },
            danger = { 0.94, 0.38, 0.43, 1 },
        },
        spacing = { xs = 4, sm = 8, md = 12, lg = 16, xl = 24 },
    },
}

local function unpackColor(color) return color[1], color[2], color[3], color[4] end

function UI.SetColor(texture, color)
    texture:SetColorTexture(unpackColor(color))
end

function UI.CreateBackground(frame, color, layer)
    local texture = frame:CreateTexture(nil, layer or "BACKGROUND")
    texture:SetAllPoints()
    UI.SetColor(texture, color)
    return texture
end

function UI.CreateBorder(frame, color)
    local border = {}
    border.top = frame:CreateTexture(nil, "BORDER")
    border.top:SetPoint("TOPLEFT"); border.top:SetPoint("TOPRIGHT"); border.top:SetHeight(1)
    border.bottom = frame:CreateTexture(nil, "BORDER")
    border.bottom:SetPoint("BOTTOMLEFT"); border.bottom:SetPoint("BOTTOMRIGHT"); border.bottom:SetHeight(1)
    border.left = frame:CreateTexture(nil, "BORDER")
    border.left:SetPoint("TOPLEFT"); border.left:SetPoint("BOTTOMLEFT"); border.left:SetWidth(1)
    border.right = frame:CreateTexture(nil, "BORDER")
    border.right:SetPoint("TOPRIGHT"); border.right:SetPoint("BOTTOMRIGHT"); border.right:SetWidth(1)
    for _, texture in pairs(border) do UI.SetColor(texture, color) end
    return border
end

function UI.CreateText(parent, fontObject, color, justify)
    local text = parent:CreateFontString(nil, "OVERLAY", fontObject or "GameFontHighlight")
    text:SetTextColor(unpackColor(color or UI.Theme.colors.text))
    text:SetJustifyH(justify or "LEFT")
    text:SetWordWrap(true)
    return text
end

Cortex.UI = UI
