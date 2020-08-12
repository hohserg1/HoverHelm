local filesystem=require"filesystem"

local fsProxyByAddress = {}

local function pathFunctionWrapper(f)
    return function(self, path, ...)
        local userLocated = ("%s/%s"):format(self.userFolder, path)
        local coreLocated = ("%s/%s"):format(config.coreRootFolder, path)
        return f(self, userLocated,coreLocated, ...)
    end
end

local function handleFunctionWrapper(f)
    return function(self, handle, ...)
        return f(self,specials.specialByIndex(self.specials,handle), ...)
    end
end

local baseProxy={__index={
    write = handleFunctionWrapper(function(self, handle, value)
        return handle:write(value)
    end),
    
    read = handleFunctionWrapper(function(self, handle, count)
        return handle:read(count)
    end),
    
    open = pathFunctionWrapper(function(self, userLocated, coreLocated, mode)
        mode = mode or "r"
        
        if mode=="a" and not filesystem.exists(userLocated) and filesystem.exists(coreLocated)then
            filesystem.copy(coreLocated, userLocated)
        end
        
        if mode=="w" or mode=="a" then
            return specials.bindSpecial(self.specials, filesystem.open(userLocated,mode))
        elseif mode=="r" then
            if fs.exists(userLocated) then
                return specials.bindSpecial(self.specials, filesystem.open(userLocated,"r"))
            else
                return specials.bindSpecial(self.specials, filesystem.open(coreLocated,"r"))
            end
        end
    end),
    
    seek = handleFunctionWrapper(function(self, handle, whence, offset)
        return handle:seek(whence, offset)
    end), 
    
    spaceUsed = function()
        return nil,"unsupported operation"
    end, 
    
    close = handleFunctionWrapper(function(self, handle)
        specials.unbindSpecial(self.specials,handle)
        return handle:close()
    end), 
    
    size = pathFunctionWrapper(function(self, userLocated, coreLocated)
        local userLocated=self.senderAddress.."/"..path
        local coreLocated="/core/"..path
        return filesystem.exists(userLocated) and filesystem.size(userLocated) or filesystem.size(coreLocated)
    end), 
    
    rename = pathFunctionWrapper(function(self, fromUserLocated, fromCoreLocated, to)        
        if filesystem.exists(userLocated) then
            return filesystem.rename(userLocated, self.userFolder.."/"..to)
        elseif filesystem.exists(coreLocated) then
            return nil,"not have permission"
        else
            return nil,"file not found"
        end
    end),
    
    remove = pathFunctionWrapper(function(self, userLocated, coreLocated)        
        if filesystem.exists(userLocated) then
            return filesystem.remove(userLocated)
        elseif filesystem.exists(coreLocated) then
            return nil,"not have permission"
        else
            return nil,"file not found"
        end
    end), 
    
    getLabel = function() return "HoverHelm OS" end, 
    
    lastModified = pathFunctionWrapper(function(self, userLocated, coreLocated)        
        if filesystem.exists(userLocated) then
            return filesystem.lastModified(userLocated)
        elseif filesystem.exists(coreLocated) then
            return filesystem.lastModified(coreLocated)
        else
            return 0
        end
    end),
    
    setLabel = function(self, value) return "HoverHelm OS" end, 
    
    isReadOnly = function() return false end, 
    
    isDirectory = pathFunctionWrapper(function(self, userLocated, coreLocated)
        return filesystem.isDirectory(userLocated) or filesystem.isDirectory(coreLocated)
    end), 
    
    exists = pathFunctionWrapper(function(self, userLocated, coreLocated)
        return filesystem.exists(userLocated) or filesystem.exists(coreLocated)
    end), 
    
    spaceTotal = function(self)
        return nil,"unsupported operation"
    end, 
    
    makeDirectory = pathFunctionWrapper(function(self, userLocated)
        filesystem.makeDirectory(userLocated)
    end),
    
    list = pathFunctionWrapper(function(self, userLocated, coreLocated)        
        local r=filesystem.list(coreLocated)
        foreach(filesystem.list(userLocated), function(key, value) r[key]=value end)
        return r
    end)
}}
    

return {
    handlers={
        hh_connect = function(card,sender,_)
            local actualDeviceName = userdata.getDeviceName(sender)
            if actualDeviceName then
                local userFolder = config.userRootFolder.."/"..actualDeviceName.."/"
                if not filesystem.exists(userFolder) then
                    filesystem.makeDirectory(userFolder)
                end
                fsProxyByAddress[sender] = setmetatable({userFolder=userFolder},baseProxy)        
            end
        end,
        
        hh_fs_invoke = function(card,sender, method, ...)
            local proxy = fsProxyByAddress[sender]
            if proxy then
                local r = table.pack(pcall(proxy[method], proxy, ...))
                card.send(sender, r[1] and "hh_result" or "hh_error", table.unpack(r,2))
            else
                card.send(sender,"hh_error","not connected")            
            end
        
        end
    
    }
}