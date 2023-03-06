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
		t 	= "Default title",		--name of the track
		sp 	= -1,					--start position
		ep 	= -1,					--end position
		s 	= 1						--playback speed
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
	customFN = false,	--in developing
	customFV = false,	--in developing
	D = false,
	T = false,
	P = false,
	a = false,
}

--init options
local mOptions = {}
args, mOptions = shell.parse(...)
options = asvutils.correctTableStructure(mOptions, options)
mOptions = nil

local function saveTitlesTable()
	--prepairing
	local serialized = ser.serialize(tapeInfo.titlesTable)
	tapeInfo.titlesTableLength = #serialized

	--write titleLenghtIndicator
	tapeLib.seekAndWrite(asvutils.splitIntoBytes(tapeInfo.titlesTableLength, titleLenghtIndicatorLength), pointers.titleLenghtIndicatorLength, options.P)

	--write titlesTable
	tapeLib.seekAndWrite(serialized, pointers.titlesTable, options.P)
end


---@param newTitleItem table
local function addNewTitle(newTitleItem)
	newTitleItem = asvutils.correctTableStructure(newTitleItem, tapeInfo.titleItem)
	table.insert(tapeInfo.titlesTable, newTitleItem)
end

local function wipeTape(fullWipe)
	initPointers()
	--full wipe
	if fullWipe then
		tapeLib.fullWipe()
	end

	--format info
	tapeLib.seekAndWrite(formatName, pointers.formatName, options.P)
	tapeLib.seekAndWrite(formatVersion, pointers.formatVersion, options.P)

	--titles table
	tapeInfo.titlesTable = {}
	local toWirte = ser.serialize(tapeInfo.titlesTable)
	tapeInfo.titlesTableLength = toWirte:len()

	--write titles
	tapeLib.seekAndWrite(asvutils.splitIntoBytes(tapeInfo.titlesTableLength, 2), pointers.titleLenghtIndicatorLength, options.P)
	tapeLib.seekAndWrite(toWirte, pointers.titlesTable, options.P)
end

---@param dontCovert boolean
local function PrintTitlesTable(dontCovert)
	if not options.T then
		io.stdout:write("key\ttrack title\tstart position\tend position\tplayback speed\n")
		local function convert(bytes)
			return tapeLib.bytesToTime(bytes, true, dontCovert)
		end
		for key, val in pairs(tapeInfo.titlesTable) do
			val = asvutils.correctTableStructure(val, tapeInfo.titleItem)
			io.stdout:write(key.."\t"..val["t"].."\t"..convert(val["sp"]).."\t"..convert(val["ep"]).."\t"..val["s"].."\n")
		end
	end
end

local function checkKeyOnNumber(key)
	if not key or key <= 0 then
		io.stderr:write("parameter key is invalid\n")
		return true
	end
end

local function checkTitleKeyFromUserInput(key)
	--check input
	if checkKeyOnNumber(key) then
		return true
	end

	--check on exist
	if not tapeInfo.titlesTable[key] then
		io.stderr:write("title does not exist\n")
		return true
	end
end

local function initTape()
	initPointers()

	--read info data from tape
	tapeInfo["formatName"] = tapeLib.seekAndRead(#formatName, pointers.formatName, options.P)
	tapeInfo["formatVersion"] = tapeLib.seekAndRead(nil, pointers.formatVersion, options.P)
	tapeInfo.titlesTableLength = asvutils.concatinateBytes(tapeLib.readBytes(titleLenghtIndicatorLength, pointers.titleLenghtIndicatorLength))

	--check on valid tape
	if tapeInfo["formatName"] == formatName then
		if tapeInfo["formatVersion"] == formatVersion then
			--print base info about table
			if not options.hideBanner then
				io.stdout:write(tapeInfo["formatName"].." ver: "..tostring(tapeInfo["formatVersion"]).."\n")
			end
			if not options.hideHeader then
				io.stdout:write("Titles table length: "..tostring(tapeInfo.titlesTableLength).."\n")
			end

			--try to parse table
			local table, status = tapeLib.readTable(tapeInfo.titlesTableLength, pointers.titlesTable)
			if status then
				io.stderr:write("Error parse titles table: "..status)
				return
			end

			--correct table structure
			local newTable = {}
			for key, val in pairs(table) do
				newTable[key] = asvutils.correctTableStructure(val, tapeInfo.titleItem)
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
	"`goto <key>` jump to the beginning of the selected track\n"..
	"`gotoend <key>` jump to the end of the selected track\n"..
	"`goto -a <'time'>` jump to specified time\n"..
	"`help` this help\n"..
	"`print` print titles and exit\n"..
	"`wipe` rewrite service info on tape. Add `--full` option for full wipe\n"..
	"`speed <value>` set play speed\n"..
	"`play <key>` start playing from position\n"..
	"`-y` auto confirm\n"..
	"`--address=<address>` for specified tape drive\n"..
	"The 'time' parameter has format hh:mm:ss.ms\n"..
	"For additional options use `man mcmp`"
	)
end

local function UIInputStart()
	if args[1] == "print" then
		initTape()
		PrintTitlesTable(options.b)
		
	elseif args[1] == "add" then
		initTape()
		--check args
		if options.D then
			if not args[2] then
				args[2] = tapeInfo.titleItem.t
			end
			if not args[3] then
				args[3] = tostring(tapeInfo.titleItem.sp)
			end
			if not args[4] then
				args[4] = tostring(tapeInfo.titleItem.ep)
			end
			if not args[5] then
				args[5] = tapeInfo.titleItem.s
			end
		end

		--convert
		local sp = tapeLib.timeToBytes(args[3])
		local ep = tapeLib.timeToBytes(args[4])
		local s = tonumber(args[5])

		if not sp or sp < 0 then
			io.stderr:write("parameter sp is invalid\n")
			return
		elseif not ep or ep <= 0 then
			io.stderr:write("parameter ep is invalid\n")
			return
		elseif not s or s < 0.3 or s >= 2.0 then
			io.stderr:write("parameter s is invalid\n")
			return
		end

		if ep - sp < 1 then
			io.stderr:write("track length cannot be less than 1b(~0.0001)\n")
			return
		end

		--check on collision
		for _, item in pairs(tapeInfo.titlesTable) do
			if (item.sp < sp and sp < item.ep) or (item.sp < ep and ep < item.ep) then
				io.stderr:write("New title has collision with exist `"..item.t.."`")
				return
			end
		end

		--add
		addNewTitle({t=args[2], sp=sp, ep=ep, s=s})
		PrintTitlesTable(options.b)
		if not asvutils.confirmAction(nil, options.y) then
			return
		end
		saveTitlesTable()
	elseif args[1] == "del" then
		initTape()
		--parse input
		local key = tonumber(args[2])
		if checkTitleKeyFromUserInput(key) then
			return
		end

		if not asvutils.confirmAction("Delete: ".."key `"..key.."` name `"..tapeInfo.titlesTable[key].t.."`", options.y) then
			return
		end

		table.remove(tapeInfo.titlesTable, key)
		saveTitlesTable()
	elseif args[1] == "wipe" then
		initPointers()

		if not asvutils.confirmAction(nil, options.y) then
			return
		end

		wipeTape(options.full)
	elseif args[1] == "goto" or (args[1] == "gotoend" and not options.a) then
		if options.a then
			local time = tapeLib.timeToBytes(args[2])
			if not time or time < 0 then
				io.stderr:write("time is invalid\n")
				return
			end
			tapeLib.seekToAbsolutlyPosition(time)
			return
		end
		initTape()

		local key = tonumber(args[2])
		if checkTitleKeyFromUserInput(key) then
			return
		end

		if args[1] == "goto" then
			tapeLib.seekToAbsolutlyPosition(tapeInfo.titlesTable[key].sp)
		else
			tapeLib.seekToAbsolutlyPosition(tapeInfo.titlesTable[key].ep)
		end
	elseif args[1] == "speed" then
		local value = tonumber(args[2])
		if checkKeyOnNumber(value) then
			return
		end

		tapeLib.setSpeed(value)
	elseif args[1] == "play" then
		initTape()

		local key = tonumber(args[2])

		if not checkTitleKeyFromUserInput(key) then
			local currentTitle = tapeInfo.titlesTable[key]
			tapeLib.play(currentTitle.sp, currentTitle.s)
			print("Start playing. Track: "..currentTitle.t.." duration: "..tapeLib.bytesToTime(currentTitle.ep - currentTitle.sp, true))
		end
	elseif args[1] == "help" then
		printUsage()
	else
		printUsage()
	end
end
UIInputStart()
