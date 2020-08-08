return {
	bindSpecial = function(specials, value)
		local index=#specials+1
		specials[index]=value
		specials.n = math.max(specials.n,index)
		return index
	end,

	unbindSpecial = function(specials, value)
		for i=1,specials.n do
			if specials[i]==value then
				specials[i]=nil
				return
			end
		end
	end,

	specialByIndex = function(specials, index)
		return specials[index]
	end
}