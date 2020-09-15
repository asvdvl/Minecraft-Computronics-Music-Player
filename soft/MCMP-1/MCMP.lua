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
		t 	= "Title",		--name of the track
		sp 	= -1,				--start position
		ep 	= -1,				--end position
		s 	= 1				--playback speed
	}
}
local pointers = {
	formatName = 0,	--0
	formatVersion = 0, --4 
	titlesTableLength = 0, --5
	titlesTable = 0 --7
}

local function initPointers()
	pointers.formatVersion = pointers.formatName + string.len(formatName)
	pointers.titlesTableLength = pointers.formatVersion + 1
	pointers.titlesTable = pointers.titlesTableLength + 2
end

---@param bytes table
---return integer
local function concatinateBytes(bytes)
	local concatNum = 0
	local secondi = #bytes
	for _, val in pairs(bytes) do
		concatNum = concatNum|(val<<(secondi*8-8))
		secondi = secondi - 1
	end
	return concatNum
end

---@param num integer
---return table of bytes
local function splitIntoBytes(num)
	--Counting bytes
	local numCount = num
	local bytesCount = 0
	while numCount ~= 0 do
		numCount = numCount >> 8
		bytesCount = bytesCount + 1;
	end

	--Splitting
	local bytes = {}
	for i = bytesCount, 1, -1 do
		bytes[i] = num & 0xFF
		num = num >> 8
	end

	return bytes
end

---@param position integer
local function seekToAbsolutlyPosition(position)
	td.seek(position - td.getPosition())
end

---@param length integer
---@param absPos integer
---return string or integer
---note: if the value of the first parameter is nil then this is the same as TD.read() (without parameters)
local function seekAndRead(length, absPos)
	if absPos then
		checkArg(2, absPos, "number")
		seekToAbsolutlyPosition(absPos)
	end
	return td.read(length)
end

---@param text string
---@param chunkSize integer
---return table of chunks
local function splitByChunk(text, chunkSize)
	local chunks = {}
	for i = 1, math.ceil(text:len() / chunkSize) do
		chunks[i] = text:sub(1, chunkSize)
		text = text:sub(chunkSize + 1, #text)
	end
	return chunks
end

---@param textToWrite string
---@param absPos integer
local function tapeWriteString(textToWrite, absPos)
	if absPos then
		checkArg(2, absPos, "number")
		seekToAbsolutlyPosition(absPos)
	end

end

---@param length integer
---return table of bytes
local function readBytes(length, absPos)
	return {string.byte(seekAndRead(length, absPos), 1, length)}
end

---@param absPos integer
---return table
local function readTable(absPos)
	return ser.unserialize(seekAndRead(tapeInfo.titlesTableLength, absPos))
end

---@param verifiableTable table
---@param templateTable table
---return table new tables and boolean 
local function checkTableStructure(verifiableTable, templateTable)
	verifiableTable = setmetatable(verifiableTable, {__index = templateTable})
	local virTabNew = {}
	local wasChanged = false
	for key, val in pairs(templateTable) do
		if not rawget(verifiableTable, key) then
			wasChanged = true
		end
		virTabNew[key] = verifiableTable[key]
	end
	return virTabNew, wasChanged
end

function PrintTitlesTable()
	io.stdout:write("track title, start position, end position, playback speed\n")
	for key, val in pairs(tapeInfo.titlesTable) do
		val = checkTableStructure(val, tapeInfo.titleItem)
		io.stdout:write(val["t"]..","..val["sp"]..","..val["ep"]..","..val["s"].."\n")
	end
end

function InitTape()
	initPointers()

	--read info data from tape
	tapeInfo["formatName"] = seekAndRead(#formatName, pointers.formatName)
	tapeInfo["formatVersion"] = seekAndRead(nil, pointers.formatVersion)
	tapeInfo.titlesTableLength = concatinateBytes(readBytes(2, pointers.titlesTableLength))

	--check on valid tape
	if tapeInfo["formatName"] == formatName then
		if tapeInfo["formatVersion"] == formatVersion then
			--print base info about table
			io.stdout:write(tapeInfo["formatName"].." ver: "..tostring(tapeInfo["formatVersion"]).."\n")
			io.stdout:write("Titles table length: "..tostring(tapeInfo.titlesTableLength).."\n")

			--try to parse table
			local table, status = readTable(pointers.titlesTable)
			if status then
				io.stderr:write("Error parse titles table: "..status)
				return
			end

			--correct table structure
			local newTable = {}
			for key, val in pairs(table) do
				newTable[key] = checkTableStructure(val, tapeInfo.titleItem)
			end
			tapeInfo.titlesTable = newTable
		else
			io.stderr:write("Invalid tape: format vertion "..tostring(tapeInfo["formatVersion"]).." not support\n")
		end
	else
		io.stderr:write("Invalid tape: format "..tapeInfo["formatName"].." not support\n")
	end
end

InitTape()
PrintTitlesTable()