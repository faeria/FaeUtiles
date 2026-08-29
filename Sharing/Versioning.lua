local _, Cortex = ...

local Versioning = {}

function Versioning:BuildEnvelope(shareType, encodedPayload)
    return table.concat({ "CORTEX", Cortex.Constants.SHARE_CODE_FORMAT_VERSION, shareType, encodedPayload }, ":")
end

function Versioning:ParseEnvelope(code)
    if type(code) ~= "string" or not Cortex:IsAccessibleValue(code) or code == "" then
        return nil, "invalid-code"
    end
    if #code > Cortex.Constants.MAX_SHARE_CODE_BYTES then return nil, "code-too-large" end
    local versionText, shareType, encodedPayload = code:match("^CORTEX:(%d+):([A-Z_]+):([A-Za-z0-9%+/=]+)$")
    if not versionText then return nil, "invalid-code" end
    local version = tonumber(versionText)
    if version ~= Cortex.Constants.SHARE_CODE_FORMAT_VERSION then return nil, "incompatible-version" end
    return { formatVersion = version, type = shareType, encodedPayload = encodedPayload }
end

Cortex:RegisterService("ShareVersioning", Versioning)
