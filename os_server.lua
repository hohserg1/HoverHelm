--config
local netComponentName = "modem"
local validPort = 1
local shared_filesystem="e6d4e5c6-4f33-41c8-ae2c-e317a826714a"
local installDir="/home/hoverhelm_server/"
--

--libs
local event=require("event")
local component=require("component")
local serialization=require("serialization")
local fs_server=require("fs_server")(shared_filesystem)
--

--log
function server_log(...)
    print(table.concat(table.pack(...)," "))
end
--

local connectedClients={}

local function loadClientData(address)
    local f=io.open(installDir.."users/"..address..".cfg")
    if f then
        local buffer = ""
        repeat
            local data = f:read(f.bufferSize)
            buffer = buffer .. (data or "")
        until not data
        f:close()
        local ok,err=load("return "..data)
        if ok then
            ok,err=pcall(ok)
            if not ok then
                server_log("error when loading config for ",address)
                server_log("    ",err)
            end
            return ok
        else
            server_log("error when loading config for ",address)
            server_log("    ",err)
        end
    end
    return nil

end

local function createSenderData(address,name)
    return {address=address,name=name or address}
end

local reactions=setmetatable({
    fs_connect=function(senderAddress,name)
        connectedClients[senderAddress] = connectedClients[senderAddress] or loadClientData(senderAddress) or createSenderData(senderAddress,name)
        connectedClients[senderAddress].name=name
        fs_server.fs_connect(senderAddress,name)
        send(senderAddress,"resultOk")
    end,
    fs_component_invoke=function(senderAddress,method,...)
        fs_server.fs_component_invoke(senderAddress,method,...)
    end
},{__index=function(_,key)
    return function(senderAddress)
        send(senderAddress,"error","not exists reaction for "..key)
    end
end})


local function net_handler(_,receiverAddress, senderAddress, port, distance, msg, ...)
    if port==validPort then
        server_log("by",senderAddress,"received message",msg,...)
        reactions[msg](senderAddress,...)
    end
end

if netComponentName=="modem" then
    local modem=component.modem
    modem.open(validPort)
    if modem.isWireless() then
        modem.setStrength(math.huge)
    end
    send=function(address,...)
        server_log("send to",address,...)
        modem.send(address,validPort,...)
    end
    --event.listen("modem_message",net_handler)
    while true do
        net_handler(event.pull("modem_message"))
    end
elseif netComponentName=="tunnel" then
    event.listen("modem_message",net_handler)
elseif netComponentName=="stem" then
    --To do
end