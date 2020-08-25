local component=require"component"

local function prepareConfig(config)
    config.inUseNetworkCards = map(config.inUseNetworkCards, function(address, cfg) return component.get(address),cfg end)
    return config
end

return prepareConfig({
    userRootFolder="/home/hoverhelm/devices/",
    coreRootFolder="/home/hoverhelm/device_core/",
    inUseNetworkCards = {
        ["address"] = {
            port = 0 -- 0 for tunnel
        }
    },
    timezone=0,
    debugLog=false
    
})