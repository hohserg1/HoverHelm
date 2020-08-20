local filesystem=require"filesystem"
local serialization=require"serialization"
local internet=require"internet"

filesystem.makeDirectory("/home/lib/")
if not filesystem.exists("/home/lib/json.lua") then
    os.execute("wget -f https://raw.githubusercontent.com/rxi/json.lua/master/json.lua /home/lib/json.lua")
end
if not filesystem.exists("/home/lib/sha256.lua") then
    os.execute("wget -f https://raw.githubusercontent.com/IgorTimofeev/MineOS/master/Libraries/SHA-256.lua /home/lib/sha256.lua")
end

local json=require"json"
local sha256=require"sha256"

local function flatMapSeq(seq, f)
    local r = {}
    for k=1, seq.n or #seq do
        local c = f(seq[k])
        for i=1, c.n or #c do
            table.insert(r,c[i])
        end
    end
    return r
end

local baseUrl = "https://api.github.com/repos/hohserg1/HoverHelm/contents/"

local runPath = os.getenv("_")

local runPathList = filesystem.list(filesystem.path(runPath))
runPathList()

local isFirstInstall = runPath:sub(1,5) == "/tmp/" or runPathList()==nil

if not isFirstInstall and hoverhelm then
    print("HoverHelm server is runned. Stop HoverHelm server before update")
    os.exit()
end

print("isFirstInstall = "..tostring(isFirstInstall))

local hhConfig = not isFirstInstall and require"hoverhelm.config"

local serverInstallPath = "/home/hoverhelm/" 
local coreRootFolder = isFirstInstall and "/home/hoverhelm/device_core/" or hhConfig.coreRootFolder

local function recreateDirectory(path)
    filesystem.remove(path)
    filesystem.makeDirectory(path)
end

recreateDirectory(serverInstallPath)
recreateDirectory(coreRootFolder)
recreateDirectory("/home/lib/hoverhelm/")


local function getFilesInRepo(path, recursively)
    local reps = internet.request(baseUrl..path)
    local result = ""
    repeat
        local data = reps()
        result = result .. (data or "")
    until not data
    local j = json.decode(result)
    return flatMapSeq(j, function(entry)
        return entry.type == "file" 
                and {entry.path}
                or (recursively and getFilesInRepo(entry.path) or {})
    end)
end

local function download(path, destination)
    print("dowloading to "..destination)
    filesystem.makeDirectory(filesystem.path(destination))
    os.execute("wget -f https://raw.githubusercontent.com/hohserg1/HoverHelm/master/"..path.." "..destination)
    print(" ")
end

--print(serialization.serialize(getFilesInRepo("/device_core"),true))


print("Downloading device core")
for _,v in ipairs(getFilesInRepo("/device_core", true)) do
    download(v, coreRootFolder..(v:sub(#"/device_core")))
end

print("Downloading libs")
local libPath = "/server/home/lib/hoverhelm"
--print(serialization.serialize(getFilesInRepo(libPath),true))

for _,v in ipairs(getFilesInRepo(libPath, true)) do
    download(v,v:sub(#"/server"))
end

--https://api.github.com/repos/hohserg1/HoverHelm/contents/core/

-- print(serialization.serialize(getFilesInRepo("/server/home/hoverhelm", false),true))

print("Downloading server")
for _,v in ipairs(getFilesInRepo("/server/home/hoverhelm", false)) do
    download(v, serverInstallPath..filesystem.name(v))
end

filesystem.copy("/home/lib/hoverhelm/utils.lua", coreRootFolder.."/lib/utils.lua")