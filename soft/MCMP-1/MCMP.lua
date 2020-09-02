local cmp = require("component")
local ser = require("serialization")
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

function ConcatinateBytes(bytes)
	local concatNum = 1
	local secondi = #bytes
	for _, val in pairs(bytes) do
		concatNum = concatNum|(val<<(secondi*8-8))
		secondi = secondi - 1
	end
	return concatNum
end

function ReadBytes(length)
	return {string.byte(td.read(length), 1, length)}
end

function ReadStrig(length)
	return td.read(length)
end

function Rewind()
	td.seek(-math.huge)
end

function ReadTable()
	return ser.unserialize(ReadStrig(tapeInfo.titlesTableLength))
end

function SeekToAbsolutlyPosition(position)
	td.seek(position - td.getPotsition())
end

function InitTape()
	Rewind()
	
	--read info data from tape
	tapeInfo["formatName"] = td.read(#formatName)
	tapeInfo["formatVersion"] = td.read()
	tapeInfo.titlesTableLength = ConcatinateBytes(ReadBytes(2))
	
	--check on valid tape
	if tapeInfo["formatName"] == formatName then
		if tapeInfo["formatVersion"] == formatVersion then
			--print base info about table
			io.stdout:write(tapeInfo["formatName"].." ver: "..tostring(tapeInfo["formatVersion"]).."\n")
			io.stdout:write("Titles table length: "..tostring(tapeInfo.titlesTableLength).."\n")
			
			--try to parse table
			local table, status = ReadTable()
			if status then
				io.stderr:write("Error parse titles table: "..status)
				return
			end
			tapeInfo.titlesTable = table
			--print title table
			io.stdout:write("track title, start position, end position, playback speed\n")
			for key, val in pairs(tapeInfo.titlesTable) do
				io.stdout:write(val[1]..","..val[2]..","..val[3]..","..val[4].."\n")
			end
		else
			io.stderr:write("Invalid tape: format vertion "..tostring(tapeInfo["formatVersion"]).." not support\n")
		end
	else
		io.stderr:write("Invalid tape: format "..tapeInfo["formatName"].." not support\n")
	end
end

InitTape()