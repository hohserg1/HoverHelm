local terminal = {
    read = function()
        while true do
            local msgType, command = bios.card.await()
            if msgType == "hh_input" then
                return command
            end
        end
    end
}

return terminal