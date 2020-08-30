local cmp = require("comconent")
local td = cmp.tape_drive
local formatName = "MCMP"
local formatVersion = 1
local tapeInfo = {
formatName = "",
formatVersion = 0,
titlesTableLength = 0,
titlesTable = {}
titleItem = {
"Title",		--name of the track
0,				--start position
0,				--end position
1				--playback speed
}
}

function concatinateBytes(bytes)
	local concatNum = 1
	local secondi = #bytes
	for _, val in pairs(bytes) do
		concatNum = concatNum|(val<<(secondi*8-8))
		secondi = secondi - 1
	end
	return concatNum
end

function rewind()
	td.seek(-math.huge)
end

function initTape()
	td.seek(-math.huge)
	
	tapeInfo["formatName"] = td.read(#formatName)
	tapeInfo["formatVersion"] = td.read()
	titlesTableLength = 0
	
	
	if td.read(#formatName) == formatName then
		if td.read(#formatVersion)
		
		end
	else
		io.stderr:write("Invalid tape: format not support")
	end
end

