local tapeLib = {}

local td = require("component").tape_drive
local ser = require("serialization")
local asvutils = require("asv").utils

---@param position integer
function tapeLib.seekToAbsolutlyPosition(position)
	td.seek(position - td.getPosition())
end

---@param str string
---return time in bytes
function tapeLib.timeToBytes(str)
	checkArg(1, str, "string")
	--parse byte input
	if str:match("(%d+)b") then
		return tonumber(str:match("(%d+)b"))
	end

	--parse time input
	local gMatchS = ""
	if str:match("%d+%.%d+$") then
		gMatchS = str:match("%d+%.%d+$")
	elseif str:match("%d+$") then
		gMatchS = str:match("%d+$")
	else
		io.stderr:write("String "..str.." not recognized as time")
		return -1
	end
	
	local gMatchHM = str:gmatch("(%d+)%:+")
	local times = {}
	table.insert(times, tonumber(gMatchHM() or ""))	--H
	table.insert(times, tonumber(gMatchHM() or ""))	--M
	table.insert(times, tonumber(gMatchS or ""))		--S and ms
	times = asvutils.reverseTable(times)
	local timeInBytes = math.ceil((times[1]+((times[2] or 0)+(times[3] or 0)*60)*60)*4096)

	return timeInBytes
end


---@param bytes number
---@param concatToString boolean
---@param dontCovert boolean
---return h, m, s
---return bytes if dontCovert true.
---return string H:M:S if concatToString true.
function tapeLib.bytesToTime(bytes, concatToString, dontCovert)
	if dontCovert then
		return bytes
	end

	local s = math.ceil(bytes/4096)
	local h = math.floor(s/3600)
	local m = math.floor(s / 60) % 60
	s = math.ceil(bytes/4096*10000)/10000 % 60

	if concatToString then
		return h..":"..m..":"..s
	else
		return h, m, s
	end
end


---@param varToWrite string | number | table
---@param absPos integer
function tapeLib.seekAndWrite(varToWrite, absPos)
	--save current point
	local state = td.getState()
	if state ~= "STOPPED" then
		td.stop()
	end
	local pos = td.getPosition()

	checkArg(1, varToWrite, "string", "number", "table")
	if absPos then
		checkArg(2, absPos, "number")
		tapeLib.seekToAbsolutlyPosition(absPos)
	end

	local tapeWrite = {}
	if type(varToWrite) == "table" then
		tapeWrite = varToWrite
	elseif type(varToWrite) == "string" then
		tapeWrite = asvutils.splitByChunk(varToWrite, 8192)
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

	--restore old position
	tapeLib.seekToAbsolutlyPosition(pos)
	if state == "PLAYING" then
		td.play()
	end
end


---@param length integer
---@param absPos integer
---return string or integer
---note: if the value of the first parameter is nil then this is the same as TD.read() (without parameters)
function tapeLib.seekAndRead(length, absPos)
	--save current point
	local state = td.getState()
	if state ~= "STOPPED" then
		td.stop()
	end
	local pos = td.getPosition()

	if absPos then
		checkArg(2, absPos, "number")
		tapeLib.seekToAbsolutlyPosition(absPos)
	end

	local readV = td.read(length)

	--restore old position
	tapeLib.seekToAbsolutlyPosition(pos)
	if state == "PLAYING" then
		td.play()
	end
	return readV
end

---@param length integer
---return table of bytes
function tapeLib.readBytes(length, absPos)
	return {string.byte(tapeLib.seekAndRead(length, absPos), 1, length)}
end

---@param absPos integer
---return table
function tapeLib.readTable(length, absPos)
	return ser.unserialize(tapeLib.seekAndRead(length, absPos))
end

function tapeLib.fullWipe()
    tapeLib.seekToAbsolutlyPosition(0)
    local tapeSize = math.ceil(td.getSize()/8192)
    local filler = string.rep("\x00", 8192)
    for i = 1, tapeSize do
        tapeLib.seekAndWrite(filler)
    end
	os.sleep(0)
end

return tapeLib