return {
    handlers={
        hh_connect = function(card, sender, deviceName)
            local actualDeviceName = userdata.getOrRegisterDeviceName(sender, deviceName)
            terminal.noticeLocalLog(terminal.log_level.msg, sender.." try to connect with name "..deviceName)
            if actualDeviceName then
                hoverhelm.chechTime=require"computer".uptime()
                card.send(sender,"hh_ok", actualDeviceName)
                terminal.noticeLocalLog(terminal.log_level.msg, sender.."\\"..actualDeviceName.." successfuly connected")       
            else
                card.send(sender,"hh_error", "name is alredy busy")     
                terminal.noticeLocalLog(terminal.log_level.error, sender.." failure connected: name is alredy busy")        
            end
        end
    }
}