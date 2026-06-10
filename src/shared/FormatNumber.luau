--!strict
-- Shared number/time formatting utilities used across client UI modules.

local FormatNumber = {}

-- Formats a large number into a short readable string (1500 → "1.50K", 2000000 → "2.00M", etc.)
function FormatNumber.format(n: number): string
    if n >= 1e15 then
        return string.format("%.2fQa", n / 1e15)
    elseif n >= 1e12 then
        return string.format("%.2fT", n / 1e12)
    elseif n >= 1e9 then
        return string.format("%.2fB", n / 1e9)
    elseif n >= 1e6 then
        return string.format("%.2fM", n / 1e6)
    elseif n >= 1e3 then
        return string.format("%.2fK", n / 1e3)
    else
        return tostring(math.floor(n))
    end
end

-- Formats seconds into a human-readable duration ("2h 34m", "5m 12s", "45s")
function FormatNumber.formatTime(seconds: number): string
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    if h > 0 then
        return string.format("%dh %dm", h, m)
    elseif m > 0 then
        return string.format("%dm %ds", m, s)
    else
        return string.format("%ds", s)
    end
end

return FormatNumber
