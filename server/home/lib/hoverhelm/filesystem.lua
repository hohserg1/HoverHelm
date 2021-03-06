local filesystem=require"filesystem"
local serialization=require"serialization"

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
            local handle,err
            
            if filesystem.exists(userLocated) then
                handle,err = filesystem.open(userLocated,"r")
            else
                handle,err = filesystem.open(coreLocated,"r")
            end
            
            if handle then
                return specials.bindSpecial(self.specials, handle)
            else
                return handle,err
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
        local coreIterator, coreErr = filesystem.list(coreLocated)
        local coreContent = coreIterator and collect(coreIterator) or {}
        local userIterator, userErr = filesystem.list(userLocated)
        local userContent = userIterator and collect(userIterator) or {}
        
        if coreIterator or userIterator then
            local r = {}
            foreach(coreContent, function(_,v) r[v]=true end)
            foreach(userContent, function(_,v) r[v]=true end)
            
            return r
        else
            return nil,userErr
        end
    end)
}}

local function size(object)
    if type(object)=="string" then
        return #object
    elseif type(object)=="number" then
        return 4
    else
        return 4
    end
end

local function freeAllHandles(prevProxy)
    if prevProxy then
        for i=1, prevProxy.specials.n do
            pcall(function()
                prevProxy.specials[i]:close()
            end)
        end                    
    end
end

local function presendFrequentlyReadedFiles(fsProxy, card, sender)
    local frequentlyReadedFilesPath = fsProxy.userFolder.."frequentlyReadedFiles.txt"
    if filesystem.exists(frequentlyReadedFilesPath) then
        for filename in io.lines(frequentlyReadedFilesPath) do
            if fsProxy:exists(filename) and not fsProxy:isDirectory(filename) then
                card.send(sender,"hh_fs_presend", filename)
                local h = fsProxy:open(filename)
                repeat
                    local data = fsProxy:read(h,math.huge)
                    if data then
                        card.send(sender,"hh_fs_presend_chunk", data)
                    end
                until not data
                fsProxy:close(h)
            end
        end
    end
    card.send(sender,"hh_fs_presend_finished")
end
    

return {
    handlers={
        hh_connect = function(card, sender, _, presendCacheSaved)
            local actualDeviceName = userdata.getDeviceName(sender)
            if actualDeviceName then
                local userFolder = config.userRootFolder.."/"..actualDeviceName.."/"
                if not filesystem.exists(userFolder) then
                    filesystem.makeDirectory(userFolder)
                end
                
                freeAllHandles(fsProxyByAddress[sender])                
                
                fsProxyByAddress[sender] = setmetatable({userFolder = userFolder, specials = specials.createNewSpecials()},baseProxy)
                
                terminal.noticeLocalLog(terminal.log_level.msg, "presendCacheSaved", presendCacheSaved)
                if not presendCacheSaved then
                    presendFrequentlyReadedFiles(fsProxyByAddress[sender], card, sender)
                end
                
            end
        end,
        
        hh_fs_invoke = function(card,sender, method, ...)
            local proxy = fsProxyByAddress[sender]
            if proxy then
                local r = table.pack(pcall(proxy[method], proxy, ...))
                terminal.noticeLocalLog(terminal.log_level.debug, method, ..., "||", table.concat(mapSeq(r,tostring)," "))
                local isBeenSended = card.send(sender, r[1] and "hh_result" or "hh_error", 
                    table.unpack(
                        mapSeq(r, function(v) return type(v)=="table" and serialization.serialize(v) or v end)
                    ,2)
                )
            else
                card.send(sender,"hh_error","not connected")            
            end
        
        end
    
    }
}