local terminal=hh_module"terminal"

local logByDeviceAddress = {}

local level={
    msg="msg",
    warn="warn",
    error="error"
}

return {
    handlers = {
        hh_connect = function(card,sender,_)
        
            local actualDeviceName = userdata.getDeviceName(sender)
            if actualDeviceName then
                logByDeviceAddress[sender] = {}
            end
            
            
        end,
        
        hh_log = function(card,sender, lvl, ...)
        
            local entry = {lvl, table.concat(mapSeq(table.pack(...),tostring)," ")}
            table.insert(logByDeviceAddress[sender], entry)
            terminal.noticeLog(sender,entry)
            
            
        end
    },
    
    level=level
}