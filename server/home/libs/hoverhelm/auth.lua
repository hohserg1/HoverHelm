return {
    handlers={
        hh_connect = function(card,sender,deviceName)
            local actualDeviceName = userdata.getOrRegisterDeviceName(sender,deviceName)
            if actualDeviceName then
                card.send(sender,"hh_ok",actualDeviceName)            
            else
                card.send(sender,"hh_error","name is alredy busy")            
            end
        end
    }
}