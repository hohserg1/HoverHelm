return function(timezone)
    local log_server={}

    local component=require("component")
    local gpu=component.gpu
    local logWidth,logHeight=gpu.getResolution()
    logHeight=logHeight-3

    local gpuYPos=1

    local tfs = component.proxy(require("computer").tmpAddress())

    local function timeMark()
        local name = "time"
        local f = tfs.open(name, "w")
        tfs.close(f)

        local time = math.floor(tfs.lastModified(name) / 1000 + 3600 *timezone)

        return os.date("%Y-%m-%d %H:%M:%S", time)
    end

    local function prepareText(lvl,...)
        return "["..timeMark().."]".."["..lvl.."] "..table.concat(table.map(table.pack(...),tostring)," ")
    end

    log_server.level={
        msg="msg",
        warn="warn",
        error="error"
    }

    function log_server.print(lvl,...)
        local text=prepareText(lvl,...)
        if gpuYPos==logHeight then
            gpu.copy(1,2, logWidth, logHeight, 0, -1)
            gpu.fill(1,logHeight,logWidth,1," ")
        else
            gpuYPos=gpuYPos+1
        end

        gpu.setForeground(
            lvl==log_server.level.warn and 0xffff00 or
            lvl==log_server.level.error and 0xff0000 or
            0xffffff)
        gpu.set(1,gpuYPos,text)
        gpu.setForeground(0xffffff)

    end

    local leveledPrint = function(lvl) return function(...) log_server.print(lvl,...) end end

    log_server.msg=leveledPrint(log_server.level.msg)
    log_server.warn=leveledPrint(log_server.level.warn)
    log_server.error=leveledPrint(log_server.level.error)

    return log_server
end