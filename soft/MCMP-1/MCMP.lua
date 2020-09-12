local Cmp = require("component")
local Ser = require("serialization")
local TD = Cmp.tape_drive
local FormatName = "MCMP"
local FormatVersion = 1
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
local Pointers = {
	formatName = 0,	--0
	formatVersion = 0, --4 
	titlesTableLength = 0, --5
	titlesTable = 0 --7
}

local function InitPointers()
	Pointers.formatVersion = Pointers.formatName + string.len(FormatName)
	Pointers.titlesTableLength = Pointers.formatVersion + 1
	Pointers.titlesTable = Pointers.titlesTableLength + 2
end

---@param bytes table
local function ConcatinateBytes(bytes)
	local concatNum = 0
	local secondi = #bytes
	for _, val in pairs(bytes) do
		concatNum = concatNum|(val<<(secondi*8-8))
		secondi = secondi - 1
	end
	return concatNum
end

---@param position integer
local function SeekToAbsolutlyPosition(position)
	TD.seek(position - TD.getPosition())
end

---@param length integer
---@param AbsPos integer
---note: if the value of the first parameter is nil then this is the same as TD.read() (without parameters)
local function SeekAndRead(length, AbsPos)
	if AbsPos then
		checkArg(2, AbsPos, "number")
		SeekToAbsolutlyPosition(AbsPos)
	end
	return TD.read(length)
end

---@param length integer
local function ReadBytes(length, AbsPos)
	return {string.byte(SeekAndRead(length, AbsPos), 1, length)}
end

---@param length integer
local function ReadStrig(length, AbsPos)
	return SeekAndRead(length, AbsPos)
end

local function ReadTable(AbsPos)
	return Ser.unserialize(ReadStrig(tapeInfo.titlesTableLength, AbsPos))
end

---@param verifiableTable table
---@param templateTable table
local function CheckTableStructure(verifiableTable, templateTable)
	verifiableTable = setmetatable(verifiableTable, {__index = templateTable})
	local VTNew = {}
	local wasChanged = false
	for key, val in pairs(templateTable) do
		if not rawget(verifiableTable, key) then
			wasChanged = true
		end
		VTNew[key] = verifiableTable[key]
	end
	return VTNew, wasChanged
end

local function PrintTitlesTable()
	io.stdout:write("track title, start position, end position, playback speed\n")
	for key, val in pairs(tapeInfo.titlesTable) do
		val = CheckTableStructure(val, tapeInfo.titleItem)
		io.stdout:write(val["t"]..","..val["sp"]..","..val["ep"]..","..val["s"].."\n")
	end
end

local function InitTape()
	InitPointers()

	--read info data from tape
	tapeInfo["formatName"] = SeekAndRead(#FormatName, Pointers.formatName)
	tapeInfo["formatVersion"] = SeekAndRead(nil, Pointers.formatVersion)
	tapeInfo.titlesTableLength = ConcatinateBytes(ReadBytes(2, Pointers.titlesTableLength))
	
	--check on valid tape
	if tapeInfo["formatName"] == FormatName then
		if tapeInfo["formatVersion"] == FormatVersion then
			--print base info about table
			io.stdout:write(tapeInfo["formatName"].." ver: "..tostring(tapeInfo["formatVersion"]).."\n")
			io.stdout:write("Titles table length: "..tostring(tapeInfo.titlesTableLength).."\n")
			
			--try to parse table
			local table, status = ReadTable(Pointers.titlesTable)
			if status then
				io.stderr:write("Error parse titles table: "..status)
				return
			end

			--correct table structure
			local newTable = {}
			for key, val in pairs(table) do
				newTable[key] = CheckTableStructure(val, tapeInfo.titleItem)
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