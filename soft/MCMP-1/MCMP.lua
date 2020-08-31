local cmp = require("component")
local td = cmp.tape_drive
local formatName = "MCMP"
local formatVersion = 1
local tapeInfo = {
	formatName = "",
	formatVersion = 0,
	titlesTableLength = 0,
	titlesTable = {},
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

function readBytes(length)
	return {string.byte(td.read(length), 1, length)}
end

function rewind()
	td.seek(-math.huge)
end

function initTape()
	rewind()
	
	--read info data from tape
	tapeInfo["formatName"] = td.read(#formatName)
	tapeInfo["formatVersion"] = td.read()
	titlesTableLength = concatinateBytes(readBytes(2))
	
	--check on valid tape
	if tapeInfo["formatName"] == formatName then
		if tapeInfo["formatVersion"] == formatVersion then
			io.stdout:write(tapeInfo["formatName"].." ver: "..tostring(tapeInfo["formatVersion"]).."\n")
			io.stdout:write("Titles table length: "..tostring(titlesTableLength).."\n")
			
		else
			io.stderr:write("Invalid tape: format vertion "..tostring(tapeInfo["formatVersion"]).." not support\n")
		end
	else
		io.stderr:write("Invalid tape: format "..tapeInfo["formatName"].." not support\n")
	end
end

initTape()