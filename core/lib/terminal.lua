local event=require("event")

local terminal={}

local inputQueue={}

local function run_program(cmd)
    checkArg(cmd,"string")
    local quote=cmd:find('\"')
    local program_name,args
    if quote==1 then
        quote=cmd:find('\" ',2)
        if quote then
            program_name=cmd:sub(2,quote-1)
            args=cmd:sub(quote+2)
        else
            error("illegal command: "..cmd)
        end
    else
        program_name=cmd:match("[^ ]+")
        args=cmd:sub(#program_name+2)
    end
    os.run_program(findFileIn(program_name,"/","/bin/"),split(args," "))
end

event.listen("os_server_message", function(_, request, input)
    if request=="terminal_input" then
        table.insert(inputQueue.input)
    elseif request=="terminal_cmd" then
        if os.current_program then
            if input=="program_exit" then
                error("interrupted by user")
            end
        else
            run_program(input)
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