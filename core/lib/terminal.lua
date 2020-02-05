local event=require("event")

local terminal={}

local inputQueue={}

event.listen("os_server_message", function(_, request, input)
    if request=="terminal_input" then
        table.insert(inputQueue.input)
    elseif request=="terminal_cmd" then
        if input=="program_exit" then
            error("interrupted by user")
        else
            prn(input)
        end
    end
end)

function terminal.read()
    if #inputQueue==0 then
        event.pull("os_server_message","terminal_input")
    end
    local r=inputQueue[1]
    table.remove(inputQueue,1)
    return r
end

function terminal.tick()
    event.pull()
end

return terminal