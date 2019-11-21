--config
local netComponentName = "tunnel"
local address,port = "",0

--

println=prn

--vcomponent
local function vcomponentFactory()

	local proxylist = {}
	local typelist = {}
	local doclist = {}

	local oproxy = component.proxy
	function component.proxy(address)
		checkArg(1,address,"string")
		if proxylist[address] ~= nil then
			return proxylist[address]
		end
		return oproxy(address)
	end

	local olist = component.list
	function component.list(filter, exact)
		checkArg(1,filter,"string","nil")
		local result = {}
		local data = {}
		for k,v in olist(filter, exact) do
			data[#data + 1] = k
			data[#data + 1] = v
			result[k]=v
		end
		for k,v in pairs(typelist) do
			if filter == nil or (exact and v == filter) or (not exact and v:find(filter, nil, true)) then
				data[#data + 1] = k
				data[#data + 1] = v
				result[k]=v
			end
		end
		local place = 1
		return setmetatable(result, {__call=function()
			local addr,type = data[place], data[place + 1]
			place = place + 2
			return addr,type
		end})
	end

	local otype = component.type
	function component.type(address)
		checkArg(1,address,"string")
		if typelist[address] ~= nil then
			return typelist[address]
		end
		return otype(address)
	end

	local odoc = component.doc
	function component.doc(address, method)
		checkArg(1,address,"string")
		checkArg(2,method,"string")
		if proxylist[address] ~= nil then
			if proxylist[address][method] == nil then
				error("no such method",2)
			end
			if doclist[address] ~= nil then
				return doclist[address][method]
			end
			return nil
		end
		return odoc(address, method)
	end

	local oslot = component.slot
	function component.slot(address)
		checkArg(1,address,"string")
		if proxylist[address] ~= nil then
			return -1 -- vcomponents do not exist in a slot
		end
		return oslot(address)
	end

	local omethods = component.methods
	function component.methods(address)
		checkArg(1,address,"string")
		if proxylist[address] ~= nil then
			local methods = {}
			for k,v in pairs(proxylist[address]) do
				if type(v) == "function" then
					methods[k] = true -- All vcomponent methods are direct
				end
			end
			return methods
		end
		return omethods(address)
	end

	local oinvoke = component.invoke
	function component.invoke(address, method, ...)
		checkArg(1,address,"string")
		checkArg(2,method,"string")
		if proxylist[address] ~= nil then
			if proxylist[address][method] == nil then
				error("no such method",2)
			end
			return proxylist[address][method](...)
		end
		return oinvoke(address, method, ...)
	end

	local ofields = component.fields
	function component.fields(address)
		checkArg(1,address,"string")
		if proxylist[address] ~= nil then
			return {} -- What even is this?
		end
		return ofields(address)
	end

	local vcomponent = {}

	function vcomponent.register(address, ctype, proxy, doc)
		checkArg(1,address,"string")
		checkArg(2,ctype,"string")
		checkArg(3,proxy,"table")
		
		if proxylist[address] ~= nil then
			return nil, "component already at address"
		elseif component.type(address) ~= nil then
			return nil, "cannot register over real component"
		end
		
		local p = setmetatable({address = address,type = ctype},proxy)
		
		proxylist[address] = p
		typelist[address] = ctype
		doclist[address] = doc
		computer.pushSignal("component_added",address,ctype)
		return true
	end

	function vcomponent.unregister(address)
		checkArg(1,address,"string")
		if proxylist[address] == nil then
			if component.type(address) ~= nil then
				return nil, "cannot unregister real component"
			else
				return nil, "no component at address"
			end
		end
		local thetype = typelist[address]
		proxylist[address] = nil
		typelist[address] = nil
		doclist[address] = nil
		computer.pushSignal("component_removed",address,thetype)
		return true
	end

	function vcomponent.list()
		local list = {}
		for k,v in pairs(proxylist) do
			list[#list + 1] = {k,typelist[k],v}
		end
		return list
	end

	function vcomponent.resolve(address, componentType)
		checkArg(1, address, "string")
		checkArg(2, componentType, "string", "nil")
		for k,v in pairs(typelist) do
			if componentType == nil or v == componentType then
				if k:sub(1, #address) == address then
					return k
				end
			end
		end
		return nil, "no such component"
	end

	local r = math.random
	function vcomponent.uuid()
		return string.format("%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
		r(0,255),r(0,255),r(0,255),r(0,255),
		r(0,255),r(0,255),
		r(64,79),r(0,255),
		r(128,191),r(0,255),
		r(0,255),r(0,255),r(0,255),r(0,255),r(0,255),r(0,255))
	end

	return vcomponent
end
--

--serialization

-- delay loaded tables fail to deserialize cross [C] boundaries (such as when having to read files that cause yields)
local local_pairs = function(tbl)
  local mt = getmetatable(tbl)
  return (mt and mt.__pairs or pairs)(tbl)
end

--[[local function serialize(value, pretty)
	  local kw =  {["and"]=true, ["break"]=true, ["do"]=true, ["else"]=true,
				   ["elseif"]=true, ["end"]=true, ["false"]=true, ["for"]=true,
				   ["function"]=true, ["goto"]=true, ["if"]=true, ["in"]=true,
				   ["local"]=true, ["nil"]=true, ["not"]=true, ["or"]=true,
				   ["repeat"]=true, ["return"]=true, ["then"]=true, ["true"]=true,
				   ["until"]=true, ["while"]=true}
	  local id = "^[%a_][%w_]*$"
	  local ts = {}
	  local result_pack = {}
	  local function recurse(current_value, depth)
		local t = type(current_value)
		if t == "number" then
		  if current_value ~= current_value then
			table.insert(result_pack, "0/0")
		  elseif current_value == math.huge then
			table.insert(result_pack, "math.huge")
		  elseif current_value == -math.huge then
			table.insert(result_pack, "-math.huge")
		  else
			table.insert(result_pack, tostring(current_value))
		  end
		elseif t == "string" then
		  table.insert(result_pack, (string.format("%q", current_value):gsub("\\\n","\\n")))
		elseif
		  t == "nil" or
		  t == "boolean" or
		  pretty and (t ~= "table" or (getmetatable(current_value) or {}).__tostring) then
		  table.insert(result_pack, tostring(current_value))
		elseif t == "table" then
		  if ts[current_value] then
			if pretty then
			  table.insert(result_pack, "recursion")
			  return
			else
			  error("tables with cycles are not supported")
			end
		  end
		  ts[current_value] = true
		  local f
		  if pretty then
			local ks, sks, oks = {}, {}, {}
			for k in local_pairs(current_value) do
			  if type(k) == "number" then
				table.insert(ks, k)
			  elseif type(k) == "string" then
				table.insert(sks, k)
			  else
				table.insert(oks, k)
			  end
			end
			table.sort(ks)
			table.sort(sks)
			for _, k in ipairs(sks) do
			  table.insert(ks, k)
			end
			for _, k in ipairs(oks) do
			  table.insert(ks, k)
			end
			local n = 0
			f = table.pack(function()
			  n = n + 1
			  local k = ks[n]
			  if k ~= nil then
				return k, current_value[k]
			  else
				return nil
			  end
			end)
		  else
			f = table.pack(local_pairs(current_value))
		  end
		  local i = 1
		  local first = true
		  table.insert(result_pack, "{")
		  for k, v in table.unpack(f) do
			if not first then
			  table.insert(result_pack, ",")
			  if pretty then
				table.insert(result_pack, "\n" .. string.rep(" ", depth))
			  end
			end
			first = nil
			local tk = type(k)
			if tk == "number" and k == i then
			  i = i + 1
			  recurse(v, depth + 1)
			else
			  if tk == "string" and not kw[k] and string.match(k, id) then
				table.insert(result_pack, k)
			  else
				table.insert(result_pack, "[")
				recurse(k, depth + 1)
				table.insert(result_pack, "]")
			  end
			  table.insert(result_pack, "=")
			  recurse(v, depth + 1)
			end
		  end
		  ts[current_value] = nil -- allow writing same table more than once
		  table.insert(result_pack, "}")
		else
		  error("unsupported type: " .. t)
		end
	  end
	  recurse(value, 1)
	  local result = table.concat(result_pack)
	  if pretty then
		local limit = type(pretty) == "number" and pretty or 10
		local truncate = 0
		while limit > 0 and truncate do
		  truncate = string.find(result, "\n", truncate + 1, true)
		  limit = limit - 1
		end
		if truncate then
		  return result:sub(1, truncate) .. "..."
		end
	  end
	  return result
	end
	]]
	
function unserialize(data)
  checkArg(1, data, "string")
  local result, reason = load("return " .. data, "=data", nil, {math={huge=math.huge}})
  if not result then
	return nil, reason
  end
  local ok, output = pcall(result)
  if not ok then
	return nil, output
  end
  return output
end
--


local function primaryComponent(name)
	return component.proxy(component.list(name)())
end

local gpu = primaryComponent("gpu")

local computer=computer

--net
local net=primaryComponent(netComponentName)

local maxPacketSize=net.maxPacketSize()

local function send(...)
	net.send(...)
end
--

--event
local function pullFiltered(...)
  local args = table.pack(...)
  local seconds, filter = math.huge

  if type(args[1]) == "function" then
    filter = args[1]
  else
    checkArg(1, args[1], "number", "nil")
    checkArg(2, args[2], "function", "nil")
    seconds = args[1]
    filter = args[2]
  end

  repeat
    local signal = table.pack(computer.pullSignal(seconds))
    if signal.n > 0 then
      if not (seconds or filter) or filter == nil or filter(table.unpack(signal, 1, signal.n)) then
        return table.unpack(signal, 1, signal.n)
      end
    end
  until signal.n == 0
end

local function createPlainFilter(name, ...)
  local filter = table.pack(...)
  if name == nil and filter.n == 0 then
    return nil
  end

  return function(...)
    local signal = table.pack(...)
    if name and not (type(signal[1]) == "string" and signal[1]:match(name)) then
      return false
    end
    for i = 1, filter.n do
      if filter[i] ~= nil and filter[i] ~= signal[i + 1] then
        return false
      end
    end
    return true
  end
end

local function pull(...)
  local args = table.pack(...)
  if type(args[1]) == "string" then
    return pullFiltered(createPlainFilter(...))
  else
    checkArg(1, args[1], "number", "nil")
    checkArg(2, args[2], "string", "nil")
    return pullFiltered(args[1], createPlainFilter(select(2, ...)))
  end
end
--

local function prepareArgs(...)
	local args={...}
	
	for i=0,#args do
		if type(args[i])=="table" and args[i].special then
			args[i]="{special="..args[i].special.."}"	
		end
	end
	
	return table.unpack(args)
end

local function invokeNet(request, ...)
	send(request,prepareArgs(...))

	local invokeResult = table.pack(pull("modem_message"))
	--request=="invokeResult"
	for i=1,6 do
		table.remove(invokeResult,1)
	end
	
	for i =1,#invokeResult do
		if type(invokeResult[i])=="string" and string.sub(invokeResult[i],1,1)=="{" and string.sub(invokeResult[i],2,2)~=" " then 
			invokeResult[i]=unserialize(invokeResult[i])
		end
	end
	
	return table.unpack(invokeResult)
end


local vcomponent=vcomponentFactory()

local fs_address = invokeNet("component.primary","filesystem")

local proxy = {
	__index=function(t,k) 
		return function(...)
			return invokeNet("component.invoke", fs_address,k,...)
		end
	end
}

vcomponent.register(fs_address,"filesystem",proxy,{})

--lua bios

local init
do
  local component_invoke = component.invoke
  local function boot_invoke(address, method, ...)
    local result = table.pack(pcall(component_invoke, address, method, ...))
    if not result[1] then
      return nil, result[2]
    else
      return table.unpack(result, 2, result.n)
    end
  end

  -- backwards compatibility, may remove later
  local eeprom = component.list("eeprom")()
  computer.getBootAddress = function()
    return boot_invoke(eeprom, "getData")
  end
  computer.setBootAddress = function(address)
    return boot_invoke(eeprom, "setData", address)
  end
  computer.setBootAddress(fs_address)

  do
    local screen = component.list("screen")()
    local gpu = component.list("gpu")()
    if gpu and screen then
      boot_invoke(gpu, "bind", screen)
    end
  end
  local function tryLoadFrom(address)
    local handle, reason = boot_invoke(address, "open", "/init.lua")
    if not handle then
      return nil, reason
    end
    local buffer = ""
    repeat
      local data, reason = boot_invoke(address, "read", handle, math.huge)
      if not data and reason then
        return nil, reason
      end
	  
      buffer = buffer .. (data or "")
    until not data
    boot_invoke(address, "close", handle)
    return load(buffer, "=init")
  end
  local reason
  if computer.getBootAddress() then
    init, reason = tryLoadFrom(computer.getBootAddress())
  end
  if not init then
    computer.setBootAddress()
    for address in component.list("filesystem") do
      init, reason = tryLoadFrom(address)
      if init then
        computer.setBootAddress(address)
        break
      end
    end
  end
  if not init then
    error("no bootable medium found" .. (reason and (": " .. tostring(reason)) or ""), 0)
  end
  computer.beep(1000, 0.2)
end
init()