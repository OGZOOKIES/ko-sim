--!strict
-- Number formatting for the UI: 1234 -> "1.23K", 5e9 -> "5B".

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local Format = {}

local function trimZeros(text: string): string
	if string.find(text, ".", 1, true) then
		text = string.gsub(text, "0+$", "")
		text = string.gsub(text, "%.$", "")
	end
	return text
end

function Format.Number(n: number): string
	if n ~= n then
		return "0"
	end
	if n == math.huge then
		return "∞"
	end
	local sign = if n < 0 then "-" else ""
	n = math.abs(n)

	if n < 1000 then
		if n == math.floor(n) then
			return sign .. string.format("%d", n)
		end
		return sign .. trimZeros(string.format("%.1f", math.floor(n * 10) / 10))
	end

	local index = 0
	while index < #SUFFIXES - 1 and n >= 10 ^ ((index + 1) * 3) do
		index += 1
	end
	local scaled = n / 10 ^ (index * 3)
	local text
	if scaled >= 100 then
		text = string.format("%d", math.floor(scaled))
	elseif scaled >= 10 then
		text = trimZeros(string.format("%.1f", math.floor(scaled * 10) / 10))
	else
		text = trimZeros(string.format("%.2f", math.floor(scaled * 100) / 100))
	end
	return sign .. text .. SUFFIXES[index + 1]
end

-- 1.5 -> "x1.5", 2 -> "x2"
function Format.Multiplier(n: number): string
	if n >= 1000 then
		return "x" .. Format.Number(n)
	end
	return "x" .. trimZeros(string.format("%.2f", n))
end

-- 0.0001 -> "0.01%", 45 -> "45%"
function Format.Percent(n: number): string
	if n >= 10 then
		return trimZeros(string.format("%.1f", n)) .. "%"
	end
	return trimZeros(string.format("%.2f", n)) .. "%"
end

return Format
