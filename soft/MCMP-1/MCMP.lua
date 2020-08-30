local cmp = require("comconent")
local td = cmp.tape_drive
local formatName = "MCMP"
local formatVersion = 1
local tapeInfo = {
formatName = "",
formatVersion = 0,
titlesTable = {}
titleItem = {
}
}

function rewind()
	td.seek(-math.huge)
end`

function initTape()
	td.seek(-math.huge)
	
	if td.read(#formatName) == formatName then
		
	else
		io.stderr:write("Invalid tape: format not support")
	end
end

