--Reading "user agent" string from internetoptions.h
function userAgent()
    local f = io.open("../idp/internetoptions.h")

    for l in f:lines() do
        local s = l:match("InnoDownloadPlugin/%d%.%d")
        if s then
            f:close()
            return s
        end
    end
    
    io.write("Error parsing internetoptions.h\n")
    return '<font color="#ff0000">Error building docs</font>'
end

function parseVer()
    local f = io.open("../idp/idp.rc")

    for l in f:lines() do
        local s = l:match("PRODUCTVERSION %d,%d,%d,%d")
        if s then
            f:close()
            return string.gsub(s:match("%d,%d,%d,%d"), ",", ".")
        end
    end
    
    io.write("Error parsing idp.rc\n")
    return "0.0.0.0"
end

verStr = parseVer()
verMajor = verStr:sub(1, 1)
verMinor = verStr:sub(3, 3)
verRev   = verStr:sub(5, 5)
verBuild = verStr:sub(7, 7)
verDword = string.format("0x%02X%02X%02X%02X", verMajor, verMinor, verRev, verBuild)






