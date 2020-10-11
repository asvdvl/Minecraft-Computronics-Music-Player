local asvutils = {}

---@param table table
---return reverse table
function asvutils.reverseTable(table)
	checkArg(1, table, "table")
	local newTable = {}
    for k, v in ipairs(table) do
        newTable[#table + 1 - k] = v
    end
    return newTable
end

---@param bytes table
---return integer
function asvutils.concatinateBytes(bytes)
	local concatNum = 0
	for _, val in pairs(bytes) do
		concatNum = val|(concatNum<<(8))
	end
	return concatNum
end

---@param strings table
---return string
function asvutils.concatinateStrings(strings)
	local concatStr = ""
	for _, val in pairs(strings) do
		concatStr = concatStr..val
	end
	return concatStr
end

---@param num integer
---@param length integer
---return table of bytes
function asvutils.splitIntoBytes(num, length)
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
	for i = 1, bytesCount do
		bytes[i] = num & 0xFF
		num = num >> 8
	end

	return asvutils.reverseTable(bytes)
end

---@param text string
---@param chunkSize integer
---return table of chunks
function asvutils.splitByChunk(text, chunkSize)
	local chunks = {}
	for i = 1, math.ceil(text:len() / chunkSize) do
		chunks[i] = text:sub(1, chunkSize)
		text = text:sub(chunkSize + 1, #text)
	end
	return chunks
end

---@param verifiableTable table
---@param templateTable table
---return table new table and boolean 
function asvutils.checkTableStructure(verifiableTable, templateTable)
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

---@param msg string
---@param yes boolean
function asvutils.confirmAction(msg, yes)
	if not yes then
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

return asvutils