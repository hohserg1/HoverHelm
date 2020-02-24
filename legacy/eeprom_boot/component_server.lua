--config
local netComponentName = "modem"
local validPort = 1
local shared_filesystem="e6d4e5c6-4f33-41c8-ae2c-e317a826714a"

local viewers={}
--

local function findLast(haystack, needle)
    local i=haystack:match(".*"..needle.."()")
    if i==nil then return nil else return i-1 end
end

local currentProgrammName=os.getenv("_")
local localPath=currentProgrammName:sub(1,findLast(currentProgrammName,"/"))

local event=require("event")
local component=require("component")
local serialization=require("serialization")

local sfs=component.proxy(shared_filesystem)


--net
local net=component[netComponentName]
net.open(validPort)
net.setStrength(math.huge)

local function send(address, ...)
	net.send(address,validPort, ...)
end
--

local function loadPart(name)
	local r,err = loadfile(localPath..name)
	if r then
		return r(sfs,send)
	else
		print("error when loading "..name)
		error(err)
	end
end

local terminal=loadPart("terminal_server.lua")
local usernamecache=loadPart("usernamecache.lua")

--specials
local specials={}

local function bindSpecial(value)
	local index=#specials+1
	specials[index]=value
	return index
end

local function unbindSpecial(index)
	specials[index]=nil
end

local function specialByIndex(index)
	return specials[index]
end
--

local function accessGranted(sender, address, path, mode)
	if mode=="r" then
		return true
	else
		local username=usernamecache[sender]

		if path:sub(1,1)~="/" then path="/"..path end

		return path:find("/users/"..username.."/")==1
	end
end

local function checkAccess(sender, address, ...)
	local path_mode={...}
	for i=1,#path_mode,2 do
		local path=path_mode[i]
		local mode=path_mode[i+1]
		if not accessGranted(sender, address, path, mode) then
			send(sender,"invokeError", "unable to access to protected file "..path)
			return false
		end
	end
	return true
end

local transformHandle={
	seek=true,
	write=true,
	close=true,
	read=true
}

local needForAccess={
	open=function(args)return args[1], args[2] or "r" end,
	makeDirectory=function(args)return args[1], "w" end,
	remove=function(args)return args[1], "w" end,
	rename=function(args)return args[1], "w", args[2], "w" end,
}

local function home(login)
	return "/users/"..login.."/"
end

local work=true

local reactions={
	["component.primary"] =
		function(sender, ctype, login)
			local actualName=usernamecache[sender]
			if not actualName then
				local home1=home(login)
				if sfs.exists(home1) then
					actualName=sender
					home1=home(sender)
				else
					actualName=login
				end
				sfs.makeDirectory(home1)
				usernamecache[sender]=actualName
			end
			terminal.init(sender,actualName)
			print("actualName",actualName)
			send(sender,"primaryResult", shared_filesystem,actualName)
		end,
	["component.invoke"] =
		function(sender, address, method, ...)
			local args={...}

			if method=="close" then
				unbindSpecial(args[1])
			else
				local forCheck = needForAccess[method]
				if forCheck and not checkAccess(sender, address, forCheck(args)) then
					return
				end
			end

			if transformHandle[method] then
				local specialIndex=args[1]
				args[1]=specialByIndex(specialIndex)
			end

			local r = {xpcall(component.invoke,debug.traceback,address,method,table.unpack(args))}
			local ok = r[1]
			local answer = ok and "invokeResult" or "invokeError"
			table.remove(r,1)

			if ok then
				for i=0,#r do
					if type(r[i])=="table" then
						local nr=serialization.serialize(r[i])
						if nr=="{type=\"userdata\"}" then
							nr=bindSpecial(r[i])
						end
						r[i]=nr
					end
				end
			end

			os.sleep(0.05)
			print(answer, table.unpack(r))
			send(sender, answer,table.unpack(r))

		end,
	["specials.unbind"]=
		function(sender, index)
			unbindSpecial(index)
		end,
	["log.log"]=
		function(sender, timeMark,lvl,msg)
			terminal.log(sender, timeMark,lvl,msg)
		end,
	["terminal.attach_view"]=
		function(sender,deviceName)
			if viewers[sender] then
				terminal.attach_view(sender,deviceName)
			else
				send(sender,"not whitelisted")
			end
		end,
	["terminal.execute"]=
		function(sender,cmd)
			if viewers[sender] then
				terminal.execute(sender,cmd)
			else
				send(sender,"not whitelisted")
			end
		end
}

local function eventHandler(_, _, from, port, _, request, ...)
	print("received message", request, ...)
	if port==validPort then
		reactions[request](from, ...)
	end
end

event.listen("modem_message",eventHandler)