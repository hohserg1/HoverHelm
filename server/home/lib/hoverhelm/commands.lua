local component=require"component"
local filesystem=require"filesystem"

local function compress(content)
    return lzss.getSXF(lzss.compress(content), true)
end

local function prepareContent(content, networkCardType)
    return content:gsub("%-%-%-%[%[%#if_def "..networkCardType, ""):gsub("%-%-%-%[%[%#if_def ","--[[")
end

local function loadPrimaryBIOS(networkCardType)
    local location = "/home/hoverhelm/eeprom-client/"
    local fileName = location.."primary-eeprom-"..networkCardType..".lua"
    if filesystem.exists(fileName) then
        local h = io.open(fileName, "r")
        local content = h:read("*a")
        h:close()
        return content
    else
        local h = io.open(location.."primary-eeprom.lua", "r")
        local content = compress(prepareContent(h:read("*a"), networkCardType))
        h:close()
        
        local h1 = io.open(fileName, "w")
        h1:write(content)
        h1:close()
        
        return content
    end
end

return {
    hide = function()
        hoverhelm.hide()
    end,
    stop = function()
        hoverhelm.stop()
    end,
    about = function()
        terminal.noticeLocalLog(0xaa00ff, "\nHoverHelm 3.0.3 \n"..
                                          "Network-based operation system. Useful for drones and microcontrollers \n"..
                                          "For more help - https://github.com/hohserg1/HoverHelm/issues \n"..
                                          " \n"..
                                          "Credits: \n"..
                                          "Thx to BrightYC for review and some discussion \n"..
                                          "Thx to swg2you for bibi.lua program - useful for testing \n"..
                                          "Thx to Fingercomp for help with marketing \n"..
                                          "Thx to everyone who uses it or gives any help \n"
        )
    end,
    prepare_eeprom  = function(newDeviceName, serverNetWorkCard, port, clientNetWorkCard)
        serverNetWorkCard = component.list(serverNetWorkCard)() or component.get(serverNetWorkCard)
        if userdata.getDeviceAddress(newDeviceName) then
            terminal.noticeLocalLog(terminal.log_level.error, "name", newDeviceName, "is alredy busy")
        elseif not config.inUseNetworkCards[serverNetWorkCard] then
            terminal.noticeLocalLog(terminal.log_level.error, "network card", serverNetWorkCard, "is not configured. need to add it to config")
        else
            local eeprom = component.eeprom
            eeprom.set(loadPrimaryBIOS(component.type(serverNetWorkCard)))
            eeprom.setLabel(newDeviceName)
            eeprom.setData(serverNetWorkCard..":"..tostring(port or 0)..":"..(clientNetWorkCard or ""))
            terminal.noticeLocalLog(terminal.log_level.msg, "successful to create new device eeprom!")
        end
    end
}