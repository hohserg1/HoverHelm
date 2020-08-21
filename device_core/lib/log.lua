local log = {
    level = {
        msg=0xffffff,
        warn=0xffff00,
        error=0xff0000,
        debug=0x11ff11
    }
}

foreach(log.level,function(name,color)log.level[color]=name end)

if config.log.enabled then

    local fs = component.filesystem
    fs.makeDirectory("/logs/")
    local logHandle = fs.open("/logs/latest.log","a")

    local function prepareText(lvl,message)
        return ("[%s][%s] %s"):format(timeMark(), lvl, message)
    end

    function log.printLeveled(lvl, ...)
        local message = prepareText(log.level[lvl], table.concat(mapSeq(table.pack(...),tostring)," "))
        fs.write(logHandle, message.."\n")
        bios.card.send("hh_log",lvl,message)
    end
    
    function log.close()
        fs.close(logHandle)
    end

else
    function log.printLeveled() end
    function log.close()end
end

foreach(log.level,function(name,color) 
    log[name]=function(...) log.printLeveled(color, ...) end
end)

log.print=log.msg
print=log.msg

return log