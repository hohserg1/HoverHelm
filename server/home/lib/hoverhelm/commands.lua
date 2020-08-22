return {
    hide = function()
        hoverhelm.hide()
    end,
    stop = function()
        hoverhelm.stop()
    end,
    about = function()
        terminal.noticeLocalLog(0xaa00ff, "\nHoverHelm 3.0.3 \n"..
                                          "Network-based operation system. Useful for drones and microcontrollers \n"..
                                          "For more help - https://github.com/hohserg1/HoverHelm/issues \n"..
                                          " \n"..
                                          "Credits: \n"..
                                          "Thx to BrightYC for review and some discussion \n"..
                                          "Thx to swg2you or bibi.lua program - useful for testing \n"..
                                          "Thx to everyone who uses it or gives any help \n"
        )
    end
}