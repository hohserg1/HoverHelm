println=println or function()end -- for bibi

function split(str, separator)
    local r = {}
    for ri in string.gmatch(str, "([^" .. separator .. "]+)") do
        table.insert(r, ri)
    end
    return table.unpack(r)
end

local function createPlainFilter(...)
    local pattern=table.pack(...)
    return function(...)
        local signal = table.pack(...)
            for i=1,pattern.n do
                if pattern[i] and signal[i]~=pattern[i] then
                    return false
                end
            end
        return true
    end
end

setmetatable(component,
    {
        __index=function(_,key)
            local a = component.list(key)()
            local r = a and component.proxy(a)
            component[key]=r
            return r
        end
    }
)

local eeprom=component.eeprom

local serverAddress, port, networkCardAddress = split(eeprom.getData(),":")
port = port and tonumber(port)
println(serverAddress, port, networkCardAddress)


bios={}
bios.serverAddress=serverAddress
bios.port=port

local namedDevice=component.drone or component.robot
bios.name = namedDevice and namedDevice.name() or eeprom.getLabel()
eeprom.setLabel(bios.name)


-- Insensibility filtered pull
local pullInsensibly do
    local originalPullSignal = computer.pullSignal
    local prevSignalQueue = {}

    computer.pullSignal = function(timeout)
        if #prevSignalQueue>0 then
            local signal = prevSignalQueue[1]
            table.remove(prevSignalQueue, 1)
            return table.unpack(signal)
        else
            return originalPullSignal(timeout)
        end
    end

    pullInsensibly = function(filter, timeout)
        timeout = timeout or math.huge
        local startTime=computer.uptime()
        local queue={}
        local signal
        repeat
            signal = table.pack(computer.pullSignal(timeout))
            table.insert(queue,signal)
            --println(table.unpack(signal))
        until filter(table.unpack(signal, 1, signal.n)) or computer.uptime()-startTime>timeout

        if computer.uptime()-startTime>timeout and not filter(table.unpack(signal, 1, signal.n))then
            return nil
        end
        
        if #prevSignalQueue==0 then
            queue[#queue] = nil -- remove found signal
            prevSignalQueue = queue
        else
            for i=1,#queue-1 do
                local signal=queue[i]
                table.insert(prevSignalQueue, 1, signal)
            end
        end

        return table.unpack(signal, 1, signal.n)
    end
end


---[[#if_def modem

local networkCard = networkCardAddress and component.proxy(networkCardAddress) or component.modem
local hhServerEventFilter = createPlainFilter("modem_message",networkCard.address, serverAddress, port)

bios.card = {
    send = function(...)
        networkCard.send(serverAddress, port, ...)
    end
}

networkCard.open(port)

--#end_if]]


---[[#if_def tunnel

local networkCard = networkCardAddress and component.proxy(networkCardAddress) or component.tunnel
local hhServerEventFilter = createPlainFilter("modem_message",networkCard.address)

bios.card = {
    send = networkCard.send
}

--#end_if]]

local function unserialize(tableString)
    return assert(load("return "..tableString,"tableString","t",{}))()
end


bios.card.await = function()
    local invokeResult = table.pack(pullInsensibly(hhServerEventFilter))
    
    -- remove formal values
    for i=1,5 do
        table.remove(invokeResult,1)
    end
    
    -- prepare values, find potential tables and unserialize
    for i=1,invokeResult.n do
        if type(invokeResult[i])=="string" and string.sub(invokeResult[i],1,1)=="{" and string.sub(invokeResult[i],-1,-1)=="}" then
            invokeResult[i]=unserialize(invokeResult[i])
        end
    end
        
    return table.unpack(invokeResult)
end

bios.card.sendAwait = function(...)

    bios.card.send(...)
    println("          send",...)
    
    local invokeResult = table.pack(bios.card.await())
    
    println("test",table.unpack(invokeResult))
    
    local ok = invokeResult[1] ~= "hh_error"
    if ok then
        return table.unpack(invokeResult, 2)
    else
        error(tostring(invokeResult[2]))
    end
    
    
end

local function loadFile(file,api)
    local handle, reason = api("open",file)
    if not handle then
        error(reason)
    end
    local buffer = ""
    repeat
        local data = api("read",handle,math.huge)
        buffer = buffer .. (data or "")
    until not data
    api("close",handle)
    local ok,err = load(buffer, file)
    if not ok then
        error(err)
    end
    return ok()
end

do
    local function segments(path)
        local parts = {}
        for part in path:gmatch("[^\\/]+") do
            local current, up = part:find("^%.?%.$")
            if current then
                if up == 2 then
                    table.remove(parts)
                end
            else
                table.insert(parts, part)
            end
        end
        return parts
    end
    function canonical(path)
        local result = table.concat(segments(path), "/")
        if unicode.sub(path, 1, 1) == "/" then
            return "/" .. result
        else
            return result
        end
    end

    local tmpFs = component.proxy(computer.tmpAddress())

    local presendPath = "/presend/"

    local presendCacheSaved = tmpFs.exists(presendPath) and tmpFs.isDirectory(presendPath)

    bios.name = bios.card.sendAwait("hh_connect", bios.name, presendCacheSaved)

    bios.presendCache = {}

    local function loadPresendFromTempFs()
    
        local function readFile(path)
            local f, err = tmpFs.open(path,"r")
            if f then
                local r=""
                local chunk=tmpFs.read(f,math.huge)
                while chunk do
                    r=r..chunk
                    chunk=tmpFs.read(f,math.huge)
                end

                return r
            else
                return nil, err
            end    
        end
        
        for _,filename in ipairs(tmpFs.list(presendPath)) do
            if not tmpFs.isDirectory(filename) then
                local canonicalPath = canonical(filename:gsub("%$","/"))
                println("loaded presend from tmp", canonicalPath)
                bios.presendCache[canonicalPath] = readFile(presendPath..filename)
            end            
        end
        
        
    end

    local function awaitPresend()
    
        local currentFileName
        
        local h
        while true do
            local invokeResult = table.pack(bios.card.await())
            if invokeResult[1]=="hh_fs_presend" then
                currentFileName = canonical(invokeResult[2])
                bios.presendCache[currentFileName] = ""
            elseif invokeResult[1]=="hh_fs_presend_chunk" then
                bios.presendCache[currentFileName] = bios.presendCache[currentFileName]..invokeResult[2]
            elseif invokeResult[1]=="hh_fs_presend_finished" then
                break
            end    
        end
        
        
    end

    local start = computer.uptime()

    if presendCacheSaved then
        loadPresendFromTempFs()
    else
        awaitPresend()
    end

    println("presend time: ",computer.uptime()-start)


end
    
    --println("memory1",computer.freeMemory(), computer.totalMemory())

println("test1",bios.name)
bios.fsAddress=loadFile("/secondary-eeprom.lua",function(...)return bios.card.sendAwait("hh_fs_invoke",...)end)
println("test2")

component.filesystem=component.proxy(bios.fsAddress)
println("test3")

loadFile("/init.lua",function(method,...)return component.filesystem[method](...)end)
println("test4")

