--wget instance
local wget = loadfile("/bin/wget.lua")
local fs = require("filesystem")
local baseURL = "https://raw.githubusercontent.com/asvdvl/Minecraft-Computronics-Music-Player/master/soft/MCMP-1"
local filesTable = {
    "/bin/MCMP.lua",
    "/lib/tapeLib.lua",
    "/usr/man/mcmp"
}

--check exsisting files
local exists = {}
for _, file in pairs(filesTable) do
    if fs.exists(file) then
        table.insert(exists, file)
    end
end

print("Warning: "..#exists.." exiting file has been found. They will be deleted, continue the installation?")
if #exists < 5 then
    for _, file in pairs(exists) do
        print(file)
    end
end
print("[y/N]?")
if io.stdin:read():lower() ~= "y" then
	print("Canceling.")
	os.exit()
end