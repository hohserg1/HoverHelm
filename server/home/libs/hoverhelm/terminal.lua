local config=hh_module"config"
local userdata=hh_module"userdata"
local log=hh_module"log"
local gpu=require"component".gpu
--prepare screen
    gpu.setForeground(0xaa00ff)
    local w, h = gpu.getResolution()
    gpu.fill(1, 1, w, h, " ")
    gpu.fill(1, h, w, 1, "=")
    gpu.fill(1, h - 2, w, 1, "-")
    
    local logWidth,logHeight = w,h-3
    local logYPos = 1
    local inputYPos = h-1
    

local tfs = component.proxy(require("computer").tmpAddress())

local function timeMark()
    local name = "time"
    local f = tfs.open(name, "w")
    tfs.close(f)

    local time = math.floor(tfs.lastModified(name) / 1000 + 3600 * config.timezone)

    return os.date("%Y-%m-%d %H:%M:%S", time)
end

local function prepareText(lvl,message)
    return ("[%s][%s] %s"):format(timeMark(), lvl, message)
end

local baseRemoteTerminal = {__index = {
    addLine = function(self, lvl, message)
        self.card.send(self.terminalAddress, lvl, message)        
    end
}}

local localTerminal = {
    terminalName = "local",
    addLine = function(self, lvl, message)
        if logYPos==logHeight then
            gpu.copy(1,2, logWidth, logHeight, 0, -1)
            gpu.fill(1,logHeight,logWidth,1," ")
        else
            logYPos=logYPos+1
        end
        
        gpu.setForeground(
            lvl==log.level.warn and 0xffff00 or
            lvl==log.level.error and 0xff0000 or
            0xffffff)
        gpu.set(1,gpuYPos,prepareText(lvl, message))
        gpu.setForeground(0xffffff)
    end
}

local terminalByAddress = {} -- Map[terminalAddress, terminal]
local terminalsByDeviceAddress = {} -- Map[deviceAddress, Map[terminalAddress, terminal]]
local cardByDeviceName = {}

local function executeOnDevice(deviceName, terminal, command)
    local deviceAddress = userdata.getDeviceAddress(deviceName)
    cardByDeviceName[deviceName].send(deviceAddress, "hh_execute", command)
    noticeLog(deviceAddress, {log.level.msg, terminal.terminalName..">>"..deviceName..">"..command})
end

return {
    handlers = {
        hh_connect = function(card, sender, _)
            local actualDeviceName = userdata.getDeviceName(sender)
            if actualDeviceName then
                cardByDeviceName[actualDeviceName] = card
                terminalsByDeviceAddress[sender]={localTerminal = localTerminal}
            end
        end,
        
        hh_rt_connect = function(card, sender, terminalName)
            local devices = map(cardByDeviceName, function(deviceName) return deviceName end)
            card.send(sender, "hh_rt_device_list", (">s1"):rep(#devices):pack(table.unpack(devices)))
            terminalByAddress[sender] = setmetatable({terminalAddress = sender, terminalName = terminalName, attachedDevice = nil, card=card}, baseRemoteTerminal)
        end,
        
        hh_rt_attach_to_device = function(card, sender, forDevice)
            local deviceCard = cardByDeviceName[forDevice]
            local deviceAddress = userdata.getDeviceAddress(forDevice)
            local terminal = terminalByAddress[sender]
            if terminal then
                if deviceCard then
                    if terminal.attachedDevice then
                        terminalsByDeviceAddress[terminal.attachedDevice][sender] = nil
                    end
                    terminal.attachedDevice = deviceAddress
                    terminalsByDeviceAddress[deviceAddress][sender] = terminal
                else
                    card.send(sender,"hh_error","device not found")
                end
            else
                card.send(sender,"hh_error","not connected")
            end
        end
        
        hh_rt_execute = function(card, sender, command)
            local terminal = terminalByAddress[sender]
            if terminal and terminal.attachedDevice then                
                executeOnDevice(userdata.getDeviceName(terminal.attachedDevice), terminal, command)
            else
                card.send(sender,"hh_error","not attached")
            end
        end        
    },
    
    noticeLog = function(deviceAddress, entry)
        foreach(terminalsByDeviceAddress[deviceAddress]. function(_,terminal) terminal:addLine(entry[1], entry[2]) end)
    end,
    
    startLocalTerminal = function()
        local function removeLastNewLineSymbol(line)
            return line:sub(1, -2)
        end
        
        while true do
            gpu.fill(1, inputYPos, w, 1, " ")
            term.setCursor(1, inputYPos)
            local success, line, description =
                pcall(term.read, { nowrap = true })
            if not success or description:find("interrupted") then
                event.cancel(hoverhelmModemMessageHandler)
                localTerminal:addLine(log.level.msg, "HoverHelm server finished")
                os.exit()
            end
            local deviceName, command = split(removeLastNewLineSymbol(line), ">")
            executeOnDevice(deviceName, localTerminal, command)
        end
    end
}