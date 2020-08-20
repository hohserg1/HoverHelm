local component=require"component"
local term=require"term"
local event=require"event"
local gpu=component.gpu
--prepare screen
    local w, h = gpu.getResolution()
    
    local logWidth,logHeight = w,h-3
    local logYPos = 1
    local inputYPos = h-1
    

local function prepareText(lvl,message)
    return ("[%s][%s] %s"):format(timeMark(), lvl, message)
end


local log_level={
    msg=0xffffff,
    warn=0xffff00,
    error=0xff0000,
    debug=0x11ff11
}

foreach(log_level,function(name,color)log_level[color]=name end)

local baseRemoteTerminal = {__index = {
    addLine = function(self, color, message)
        self.card.send(self.terminalAddress, color, message)
    end
}}

local localTerminal = {
    terminalName = "local",
    addLine = function(self, color, message)
        if color~=log_level.debug or config.debugLog then
            if logYPos==logHeight then
                gpu.copy(1,2, logWidth, logHeight, 0, -1)
                gpu.fill(1,logHeight,logWidth,1," ")
            else
                logYPos=logYPos+1
            end
            
            gpu.setForeground(color)
            gpu.set(1,logYPos,message)
            gpu.setForeground(0xffffff)
        end
    end
}

local terminalByAddress = {} -- Map[terminalAddress, terminal]
local terminalsByDeviceAddress = {} -- Map[deviceAddress, Map[terminalAddress, terminal]]
local cardByDeviceName = {}

local function noticeLocalLog(color, message)
    localTerminal:addLine(color, prepareText(log_level[color],message))
end

local function noticeLog(deviceAddress, color, message)
    local l = collect(lines(message))
    foreach(terminalsByDeviceAddress[deviceAddress], function(_,terminal) 
        foreach(l, function(_,line)
            terminal:addLine(color, line)
        end)
    end)
end
local function inputOnDevice(deviceName, terminal, command)
    local deviceAddress = userdata.getDeviceAddress(deviceName)
    local card = cardByDeviceName[deviceName]
    if card then
        card.send(deviceAddress, "hh_input", command)
        noticeLog(deviceAddress, log_level.debug, terminal.terminalName..">>"..deviceName..">"..command)
    else
        noticeLocalLog(log_level.error, "Unable to send input for "..deviceName..". Is it valid device name?")
    end
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
        
        hh_log = function(card, sender, color, message)
            noticeLog(sender, color, message)
        end,
        
        hh_rt_connect = function(card, sender, terminalName)
            local devices = map(cardByDeviceName, function(deviceName) return deviceName end)
            card.send(sender, "hh_rt_device_list", (">s1"):rep(#devices):pack(table.unpack(devices)))
            terminalByAddress[sender] = setmetatable({terminalAddress = sender, terminalName = terminalName, attachedDevice = nil, card=card}, baseRemoteTerminal)
            terminal.noticeLocalLog(log_level.msg, "Connected remote terminal "..sender.."\\"..terminalName)
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
        end,
        
        hh_rt_execute = function(card, sender, command)
            local terminal = terminalByAddress[sender]
            if terminal and terminal.attachedDevice then                
                inputOnDevice(userdata.getDeviceName(terminal.attachedDevice), terminal, command)
            else
                card.send(sender,"hh_error","not attached")
            end
        end        
    },
    
    noticeLog = noticeLog,
    
    noticeLocalLog = noticeLocalLog,
    
    log_level = log_level,
    
    startLocalTerminal = function()
        logYPos = 1
        gpu.setForeground(0xaa00ff)
        gpu.fill(1, 1, w, h, " ")
        gpu.fill(1, h, w, 1, "=")
        gpu.fill(1, h - 2, w, 1, "-")
        
        local function removeLastNewLineSymbol(line)
            return line:sub(1, -2)
        end
        
        noticeLocalLog(log_level.msg, "HoverHelm launched!")
        
        while true do
            gpu.fill(1, inputYPos, w, 1, " ")
            term.setCursor(1, inputYPos)
            local success, line, description =
                pcall(term.read, { nowrap = true })
            if not success or description and description:find("interrupted") then
                hoverhelm.stop()
            end
            
            line = removeLastNewLineSymbol(line)
            
            if line:find(">") then
                local deviceName, command = split(line, ">")
                inputOnDevice(deviceName, localTerminal, command)
            elseif #line>0 then
                local localCommand = {split(line, " ")}
                local command = commands[localCommand[1]]
                if command then
                    command(table.unpack(localCommand,2))
                else
                    noticeLocalLog(log_level.error, "command not found: "..(localCommand[1] or "nil"))
                end
            end
        end
    end
}