local cmp = require("component")
local ser = require("serialization")
local shell = require("shell")
local td = cmp.tape_drive
local formatName = "MCMP"
local formatVersion = 1
local titleLenghtIndicatorLength = 2
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
	titleLenghtIndicatorLength = 0, --5
	titlesTable = 0 --7
}

local function initPointers()
	pointers.formatVersion = pointers.formatName + string.len(formatName)
	pointers.titleLenghtIndicatorLength = pointers.formatVersion + 1
	pointers.titlesTable = pointers.titleLenghtIndicatorLength + 2
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

---@param strings table
---return string
local function concatinateStrings(strings)
	local concatStr = ""
	for _, val in pairs(strings) do
		concatStr = concatStr..val
	end
	return concatStr
end

local function reverseTable(table)
	checkArg(1, table, "table")
	local newTable = {}
    for k, v in ipairs(table) do
        newTable[#table + 1 - k] = v
    end
    return newTable
end

---@param num integer
---@param length integer
---return table of bytes
local function splitIntoBytes(num, length)
	--Counting bytes
	local bytesCount = 0
	if not length then
		local numCount = num
		while numCount ~= 0 do
			numCount = numCount >> 8
			bytesCount = bytesCount + 1;
		end
	else
		bytesCount = length
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

local function secondsToBytes()
	
end

---@param varToWrite string | number | table
---@param absPos integer
local function seekAndWrite(varToWrite, absPos)
	checkArg(1, varToWrite, "string", "number", "table")
	if absPos then
		checkArg(2, absPos, "number")
		seekToAbsolutlyPosition(absPos)
	end

	local tapeWrite = {}
	if type(varToWrite) == "table" then
		tapeWrite = varToWrite
	elseif type(varToWrite) == "string" then
		tapeWrite = splitByChunk(varToWrite, 8192)
	elseif type(varToWrite) == "number" then
		tapeWrite = {varToWrite}
	else
		io.stderr:write("I don't know what happened, but the universe may collapse soon. "..
			"Because this condition doesn't have to be true. "..
			"Don't blame yourself for the death of all living things. "..
			"Well, before you panic, I advise you to check your computer for problems. "..
			"I think your processor is not working properly.")
	end

	for _, val in pairs(tapeWrite) do
		td.write(val)
	end
end

local function saveTitlesTable()
	--prepairing
	local serialized = ser.serialize(tapeInfo.titlesTable)
	tapeInfo.titlesTableLength = #serialized

	--write titleLenghtIndicator
	seekAndWrite(splitIntoBytes(tapeInfo.titlesTableLength, titleLenghtIndicatorLength), pointers.titleLenghtIndicatorLength)

	--write titlesTable
	seekAndWrite(serialized, pointers.titlesTable)
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
---return table new table and boolean 
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

---@param newTitleItem table
local function addNewTitle(newTitleItem)
	newTitleItem = checkTableStructure(newTitleItem, tapeInfo.titleItem)
	table.insert(tapeInfo.titlesTable, newTitleItem)
end

local function wipeTape(fullWipe)
	initPointers()
	--full wipe
	if fullWipe then
		seekToAbsolutlyPosition(0)
		local tapeSize = math.ceil(td.getSize()/8192)
		local filler = string.rep("\x00", 8192)
		for i = 1, tapeSize do
			seekAndWrite(filler)
		end
	end

	--format info
	seekAndWrite(formatName, pointers.formatName)
	seekAndWrite(formatVersion, pointers.formatVersion)

	--titles table
	tapeInfo.titlesTable = {}
	local toWirte = ser.serialize(tapeInfo.titlesTable)
	tapeInfo.titlesTableLength = toWirte:len()

	--write titles
	seekAndWrite(splitIntoBytes(tapeInfo.titlesTableLength, 2), pointers.titleLenghtIndicatorLength)
	seekAndWrite(toWirte, pointers.titlesTable)
end

function PrintTitlesTable()
	io.stdout:write("key, track title, start position, end position, playback speed\n")
	for key, val in pairs(tapeInfo.titlesTable) do
		val = checkTableStructure(val, tapeInfo.titleItem)
		io.stdout:write(key..","..val["t"]..","..val["sp"]..","..val["ep"]..","..val["s"].."\n")
	end
end

function InitTape()
	initPointers()

	--read info data from tape
	tapeInfo["formatName"] = seekAndRead(#formatName, pointers.formatName)
	tapeInfo["formatVersion"] = seekAndRead(nil, pointers.formatVersion)
	tapeInfo.titlesTableLength = concatinateBytes(readBytes(titleLenghtIndicatorLength, pointers.titleLenghtIndicatorLength))

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

--user interface
local function printUsage()
	io.stdout:write(
	"Usage:\n"..
	"`print` print titles and exit\n"..
	"`add <title name> <start pos in bytes> <end pos in bytes> <play speed>` add title to table\n"..
	"`del <key>` delete title from titles table\n"..
	"`wipe` rewrite service info on tape. Use `--full` option for full wipe\n"..
	"`--full` full wipe a tape. Use with `wipe` key\n"..
	"`goto <key>` go to point\n"..
	"`-y` auto confirm"
	)
end

local args, options = shell.parse(...)

---@param msg string
local function confirmAction(msg)
	if not options.y then
		if not msg then
			msg = "Do you confirm this action?"
		end
		msg = msg.."\n"

		io.stdout:write(msg)
		io.stderr:write("[y/N]?")
		if io.stdin:read():lower() ~= "y" then
			io.stdout:write("Canceling.\n")
			return false
		end
	end
	return true
end

local function UIInputStart()
	if args[1] == "print" then
		InitTape()
		PrintTitlesTable()
	elseif args[1] == "add" then
		InitTape()
		--check args
		local param = {"title name", "start pos", "end pos", "play speed"}
		for i = 2, 5 do
			if not args[i] then
				io.stderr:write("parameter "..param[i-1].." does not exist\n")
				return
			end
		end
		
		--convert
		local sp = tonumber(args[3])
		local ep = tonumber(args[4])
		local s = tonumber(args[5])
		if not sp or sp <= 0 then
			io.stderr:write("parameter sp is invalid\n")
			return
		elseif not ep or ep <= 0 then
			io.stderr:write("parameter ep is invalid\n")
			return
		elseif not s or s < 0.3 or s >= 2.0 then
			io.stderr:write("parameter s is invalid\n")
			return
		end

		--add
		addNewTitle({t=args[2], sp=sp, ep=ep, s=s})
		PrintTitlesTable()
		if not confirmAction() then
			return
		end
		saveTitlesTable()
	elseif args[1] == "del" then
		InitTape()
		--parse input
		local key = tonumber(args[2])
		if not key or key <= 0 then
			io.stderr:write("parameter key is invalid\n")
			return
		end

		--check on exist
		if not tapeInfo.titlesTable[key] then
			io.stderr:write("title does not exist\n")
			return
		end

		if not confirmAction("Delete: ".."key "..key.." name "..tapeInfo.titlesTable[key].t) then
			return
		end

		table.remove(tapeInfo.titlesTable, key)
		saveTitlesTable()
	elseif args[1] == "wipe" then
		initPointers()

		if not confirmAction() then
			return
		end

		wipeTape(options.full)
	elseif args[1] == "goto" then
		InitTape()
		--parse input
		local key = tonumber(args[2])
		if not key or key <= 0 then
			io.stderr:write("parameter key is invalid\n")
			return
		end

		--check on exist
		if not tapeInfo.titlesTable[key] then
			io.stderr:write("title does not exist\n")
			return
		end

		seekToAbsolutlyPosition(tapeInfo.titlesTable[key].sp)
	else
		printUsage()
	end
end
UIInputStart()