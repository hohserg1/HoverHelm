function map(t, f)
    local r = {}
    for k,v in pairs(t) do
        local nk,nv = f(k,v)
        if not nv then
            table.insert(r,nk)
        else
            r[nk]=nv
        end
    end
    return r
end
function foreach(t, f)
    for k,v in pairs(t) do
        f(k,v)
    end
end

function mapSeq(seq, f)
    local r = {}
    for k=1, seq.n or #seq do
        r[k]=f(seq[k])
    end
    return r
end

function split(str, separator)
    local r = {}
    for ri in string.gmatch(str, "([^" .. separator .. "]+)") do
        table.insert(r, ri)
    end
    return table.unpack(r)
end

function lines(s)
    if s:sub(-1)~="\n" then s=s.."\n" end
    return s:gmatch("(.-)\n")
end

function collect(iterator)
    local r = {}
    for k,v in iterator do
        if v then
            r[k] = v
        else
            table.insert(r,k)
        end
    end
    return r
end

local component=require"component"
local tfs = component.proxy(require"computer".tmpAddress())

function timeMark()
    local name = "time"
    local f = tfs.open(name, "w")
    tfs.close(f)

    local time = math.floor(tfs.lastModified(name) / 1000 + 3600 * config.timezone)

    return os.date("%Y-%m-%d %H:%M:%S", time)
end

return {}