local ser = require("serialization")
local shell = require("shell")
local asvutils = require("asv").utils
local tapeLib = require("tapeLib")

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

local args = {}
local options = {
	y = false,
	b = false,
	full = false,
	hideHeader = false,
	hideBanner = false,
	customFN = false,
	customFV = false,
	D = false,
	T = false,
	P = false,
}

--init options
local mOptions = {}
args, mOptions = shell.parse(...)
options = asvutils.checkTableStructure(mOptions, options)
mOptions = nil

local function preInit()
	local stringKeyList = {
		customFN = "",
		customFV = "",
	}

	for key, value in pairs(stringKeyList) do
		if type(options[key]) == "boolean" and options[key] then
			options[key] = value
		end
	end

	

	initPointers()
end

local function saveTitlesTable()
	--prepairing
	local serialized = ser.serialize(tapeInfo.titlesTable)
	tapeInfo.titlesTableLength = #serialized

	--write titleLenghtIndicator
	tapeLib.seekAndWrite(asvutils.splitIntoBytes(tapeInfo.titlesTableLength, titleLenghtIndicatorLength), pointers.titleLenghtIndicatorLength)

	--write titlesTable
	tapeLib.seekAndWrite(serialized, pointers.titlesTable)
end


---@param newTitleItem table
local function addNewTitle(newTitleItem)
	newTitleItem = asvutils.checkTableStructure(newTitleItem, tapeInfo.titleItem)
	table.insert(tapeInfo.titlesTable, newTitleItem)
end

local function wipeTape(fullWipe)
	preInit()
	--full wipe
	if fullWipe then
		tapeLib.fullWipe()
	end

	--format info
	tapeLib.seekAndWrite(formatName, pointers.formatName)
	tapeLib.seekAndWrite(formatVersion, pointers.formatVersion)

	--titles table
	tapeInfo.titlesTable = {}
	local toWirte = ser.serialize(tapeInfo.titlesTable)
	tapeInfo.titlesTableLength = toWirte:len()

	--write titles
	tapeLib.seekAndWrite(asvutils.splitIntoBytes(tapeInfo.titlesTableLength, 2), pointers.titleLenghtIndicatorLength)
	tapeLib.seekAndWrite(toWirte, pointers.titlesTable)
end

---@param dontCovert boolean
function PrintTitlesTable(dontCovert)
	io.stdout:write("key\ttrack title\tstart position\tend position\tplayback speed\n")
	local function convert(bytes)
		return tapeLib.bytesToTime(bytes, true, dontCovert)
	end
	for key, val in pairs(tapeInfo.titlesTable) do
		val = asvutils.checkTableStructure(val, tapeInfo.titleItem)
		io.stdout:write(key.."\t"..val["t"].."\t"..convert(val["sp"]).."\t"..convert(val["ep"]).."\t"..val["s"].."\n")
	end
end

function InitTape()
	preInit()

	--read info data from tape
	tapeInfo["formatName"] = tapeLib.seekAndRead(#formatName, pointers.formatName)
	tapeInfo["formatVersion"] = tapeLib.seekAndRead(nil, pointers.formatVersion)
	tapeInfo.titlesTableLength = asvutils.concatinateBytes(tapeLib.readBytes(titleLenghtIndicatorLength, pointers.titleLenghtIndicatorLength))

	--check on valid tape
	if tapeInfo["formatName"] == formatName then
		if tapeInfo["formatVersion"] == formatVersion then
			--print base info about table
			io.stdout:write(tapeInfo["formatName"].." ver: "..tostring(tapeInfo["formatVersion"]).."\n")
			io.stdout:write("Titles table length: "..tostring(tapeInfo.titlesTableLength).."\n")

			--try to parse table
			local table, status = tapeLib.readTable(tapeInfo.titlesTableLength, pointers.titlesTable)
			if status then
				io.stderr:write("Error parse titles table: "..status)
				return
			end

			--correct table structure
			local newTable = {}
			for key, val in pairs(table) do
				newTable[key] = asvutils.checkTableStructure(val, tapeInfo.titleItem)
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
	"`add <title name> <start pos 'time'> <end pos 'time'> <play speed>` add title to table\n"..
	"`del <key>` delete title from titles table\n"..
	"`goto <key>` go to point\n"..
	"`help` this help\n"..
	"`print` print titles and exit\n"..
	"`wipe` rewrite service info on tape. Add `--full` option for full wipe\n"..
	"`-y` auto confirm\n"..
	"The 'time' parameter has format hh:mm:ss.ms\n"..
	"For additional options use `man mcmp`"
	)
end

local function UIInputStart()
	if args[1] == "print" then
		InitTape()
		PrintTitlesTable(options.b)
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
		local sp = tapeLib.timeToBytes(args[3])
		local ep = tapeLib.timeToBytes(args[4])
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
		PrintTitlesTable(options.b)
		if not asvutils.confirmAction(nil, options.y) then
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

		if not asvutils.confirmAction("Delete: ".."key "..key.." name "..tapeInfo.titlesTable[key].t, options.y) then
			return
		end

		table.remove(tapeInfo.titlesTable, key)
		saveTitlesTable()
	elseif args[1] == "wipe" then
		preInit()

		if not asvutils.confirmAction(nil, options.y) then
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

		tapeLib.seekToAbsolutlyPosition(tapeInfo.titlesTable[key].sp)
	elseif args[1] == "help" then
		printUsage()
	else
		printUsage()
	end
end
UIInputStart()
