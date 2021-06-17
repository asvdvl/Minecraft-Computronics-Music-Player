--wget instance
local wget = loadfile("/bin/wget.lua")
local fs = require("filesystem")
local baseURL = "https://raw.githubusercontent.com/asvdvl/Minecraft-Computronics-Music-Player/master/soft/MCMP-1"
local filesTable = {
    "/bin/MCMP.lua",
    "/lib/tapeLib.lua",
    "/usr/man/mcmp"
}

--Download files
for _, file in pairs(filesTable) do
    local success, message = wget("-f", baseURL..file, file)
    if not success then
        io.stderr:write("Download error: "..file.." by reason: "..message)
    end
end

print("Setup complete!")