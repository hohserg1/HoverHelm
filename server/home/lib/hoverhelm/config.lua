local component=require"component"

local function prepareConfig(config)
    config.inUseNetworkCards = map(config.inUseNetworkCards, function(address, cfg) return component.get(address),cfg end)
end

return prepareConfig({
    userRootFolder="/home/hoverhelm/devices/",
    coreRootFolder="/home/hoverhelm/device_core/",
    inUseNetworkCards = {
        ["351625f3-fc85-4d75-abc1-ca77a7619101"] = {
            port = 0 -- 0 for tunnel
        }
    },
    timezone=0,
    debugLog=false
    
})