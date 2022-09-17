const char * GlobalLua = R"FQLuaScript(

    function CharToHex(c)
        return string.format("%%%02X", string.byte(c))
    end

    function UrlEncode(url)
        if url == nil then
            return
        end
        url = url:gsub("\n", "\r\n")
        url = url:gsub("([^%w ])", CharToHex)
        url = url:gsub(" ", "+")
        return url
    end

    function HexToChar(x)
        return string.char(tonumber(x, 16))
    end

    function UrlDecode(url)
        if url == nil then
            return
        end
        url = url:gsub("+", " ")
        url = url:gsub("%%(%x%x)", HexToChar)
        return url
    end

    function SafeCall(TargetFunction, ...)
        local function MakeOptional(ok, ...)
            if (ok) then
                return true, {...}
            end
            return false, ...
        end
        local ok,result = MakeOptional(xpcall(
                TargetFunction,
                function (Message)
                    return tostring(Message).."\n\t".. debug.traceback()
                end,
                ...
            ))
        return ok, result
    end

    function SplitString(str, delimiter)
        local dLen = string.len(delimiter)
        local newDeli = ''
        for i=1,dLen,1 do
            newDeli = newDeli .. "["..string.sub(delimiter,i,i).."]"
        end

        local locaStart,locaEnd = string.find(str,newDeli)
        local arr = {}
        local n = 1
        while locaStart ~= nil
        do
            if locaStart>0 then
                arr[n] = string.sub(str,1,locaStart-1)
                n = n + 1
            end
            str = string.sub(str,locaEnd+1,string.len(str))
            locaStart,locaEnd = string.find(str,newDeli)
        end
        if str ~= nil then
            arr[n] = str
        end
        return arr
    end

    function Grep(str, sub)
        local lines = SplitString(str, "\n")
        local arr = {}
        local n = 1
        for _,line in ipairs(lines) do -- or or file:lines() if you have a different file
            if line:find(sub) then -- Only lines containing the IP we care about
                arr[n] = line
                n = n + 1
            end
        end
        return arr
    end

    function UriEncode (str)
        str = string.gsub (str, "([^0-9a-zA-Z !'()*._~-])", -- locale independent
            function (c) return string.format ("%%%02X", string.byte(c)) end)
        str = string.gsub (str, " ", "+")
        return str
    end

    function UriDecode (str)
        str = string.gsub (str, "+", " ")
        str = string.gsub (str, "%%(%x%x)", function(h) return string.char(tonumber(h,16)) end)
        return str
    end

)FQLuaScript";