local filesystem=require"filesystem"
local serialization=require"serialization"

local deviceNameByAddress={}
local addressByDeviceName={}

do
    local userdataPath = "/home/hoverhelm/userdata.txt"
    if filesystem.exists(userdataPath) then
        for line in io.lines(userdataPath) do
            local separator = line:find(":")
            local address = line:sub(1,separator-1)
            local name = line:sub(separator+1)
            
            deviceNameByAddress[address]=name
            addressByDeviceName[name]=address
        end
    end
end

return {
    getOrRegisterDeviceName = function(deviceNetworkCardAddress,deviceName)
    
        if not deviceNameByAddress[deviceNetworkCardAddress] and not addressByDeviceName[deviceName] then
            deviceNameByAddress[deviceNetworkCardAddress] = deviceName
            addressByDeviceName[deviceName] = deviceNetworkCardAddress
        end
        return deviceNameByAddress[deviceNetworkCardAddress]
        
        
    end,
    
    getDeviceName = function(deviceNetworkCardAddress)
        return deviceNameByAddress[deviceNetworkCardAddress]
    end,
    
    getDeviceAddress = function(deviceName)
        return addressByDeviceName[deviceName]
    end,
    
    saveUserdataList=function()
    
        local f = io.open("/home/hoverhelm/userdata.txt","w")
        local content = table.concat(
            map(deviceNameByAddress,function(address,deviceName)
                return address..":"..deviceName.."\n"
            end)
        )
        f:write(content)
        f:close()
        
        
    end
}