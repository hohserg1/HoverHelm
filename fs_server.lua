return function(shared_filesystem)
    local component=require("component")
    local fs=component.proxy(shared_filesystem)

    local proxies={}

    local fs_server={}

    local function canonical(path)
        return ("/"..path):gsub("//+","/")
    end


    --specials
    local function bindSpecial(specials, value)
        local index=#specials+1
        specials[index]=value
        return index
    end

    local function unbindSpecial(specials, index)
        specials[index]=nil
    end

    local function specialByIndex(specials, index)
        return specials[index]
    end
    --

    local baseProxy={__index={}}
    function baseProxy.__index:write(handle, value)
        handle=specialByIndex(self.specials,handle)
        return fs.write(handle,value)
    end
    function baseProxy.__index:read(handle, count)
        handle=specialByIndex(self.specials,handle)
        return fs.read(handle,count)
    end
    function baseProxy.__index:open(path, mode)
        mode=mode or "r"
        local userLocated=self.senderAddress.."/"..path
        if mode=="w" or mode=="a" then--To do:separate logic of addition mode
            return bindSpecial(self.specials,fs.open(userLocated,mode))
        elseif mode=="r" then
            local coreLocated="/core/"..path
            if fs.exists(userLocated) then
                return bindSpecial(self.specials,fs.open(userLocated,mode))
            else
                return bindSpecial(self.specials,fs.open(coreLocated,mode))
            end
        end
    end
    function baseProxy.__index:seek(handle, whence, offset)
        handle=specialByIndex(self.specials,handle)
        return fs.seek(handle, whence, offset)
    end
    function baseProxy.__index:spaceUsed()
        return fs.spaceUsed()
    end
    function baseProxy.__index:close(handle)
        local h=specialByIndex(self.specials,handle)
        unbindSpecial(self.specials,handle)
        return fs.close(h)
    end
    function baseProxy.__index:size(path)
        return fs.size(path)
    end
    function baseProxy.__index:rename(from, to)
        local userLocated=self.senderAddress.."/"..from
        local coreLocated="/core/"..from
        if fs.exists(userLocated) then
            return fs.rename(userLocated,self.senderAddress.."/"..to)
        elseif fs.exists(coreLocated) then
            return false,"not have permission"
        end
    end
    function baseProxy.__index:remove(path)
        local userLocated=self.senderAddress.."/"..path
        local coreLocated="/core/"..path
        if fs.exists(userLocated) then
            return fs.remove(userLocated)
        elseif fs.exists(coreLocated) then
            return false,"not have permission"
        end
    end
    function baseProxy.__index:getLabel() return "HoverHelm OS" end
    function baseProxy.__index:lastModified(path)
        local userLocated=self.senderAddress.."/"..path
        local coreLocated="/core/"..path
        if fs.exists(userLocated) then
            return fs.lastModified(userLocated)
        elseif fs.exists(coreLocated) then
            return fs.lastModified(coreLocated)
        end
    end
    function baseProxy.__index:setLabel(value) return "HoverHelm OS" end
    function baseProxy.__index:isReadOnly() return false end
    function baseProxy.__index:isDirectory(path)
        local userLocated=self.senderAddress.."/"..path
        local coreLocated="/core/"..path
        return fs.isDirectory(userLocated) or fs.isDirectory(coreLocated)
    end
    function baseProxy.__index:exists(path)
        local userLocated=self.senderAddress.."/"..path
        local coreLocated="/core/"..path
        return fs.exists(userLocated) or fs.exists(coreLocated)
    end
    function baseProxy.__index:spaceTotal()
        return fs.spaceTotal()
    end
    function baseProxy.__index:makeDirectory(path)
        fs.makeDirectory(self.senderAddress.."/"..path)
    end
    function baseProxy.__index:list(path)
        local userLocated=self.senderAddress.."/"..path
        local coreLocated="/core/"..path
        local r=fs.list(coreLocated)
        for key, value in pairs(fs.list(userLocated)) do
            r[key]=value

        end
        return r
    end

    function fs_server.fs_connect(senderAddress,name)
        if proxies[senderAddress] then
            for _,v in pairs(proxies[senderAddress].specials) do
                fs.close(v)
            end
        end
        proxies[senderAddress]=setmetatable({senderAddress=senderAddress,specials={}},baseProxy)

    end


    local transformHandle={
        seek=true,
        write=true,
        close=true,
        read=true
    }

    function fs_server.fs_component_invoke(senderAddress,method,...)
        local proxy=proxies[senderAddress]
        local r=table.pack(pcall(proxy[method], proxy, ...))
        print("result",table.unpack(r))
        send(senderAddress, r[1] and "result" or "error", table.unpack(r,2))
    end

    return fs_server
end