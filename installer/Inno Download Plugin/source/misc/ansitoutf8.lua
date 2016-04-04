--Converts ANSI file to UTF-8
--Usage: luajit ansitoutf8.lua inputfile.iss [encoding] > outputfile.iss
--Default encoding is 1252

local ffi = require("ffi")
ffi.cdef[[
    int MultiByteToWideChar(unsigned int CodePage, unsigned int dwFlags, const char* lpMultiByteStr, int cbMultiByte, wchar_t* lpWideCharStr, int cchWideChar);              
    int WideCharToMultiByte(unsigned int CodePage, unsigned int dwFlags, wchar_t* lpWideCharStr, int cchWideChar, char* lpMultiByteStr, int cbMultiByte, char* lpDefaultChar, int* lpUsedDefaultChar);
]]

CP_UTF8 = 65001

function ansitoutf8(str, codepage)
    local widestr = ffi.new("wchar_t[?]", 1024)
    local utf8str = ffi.new("char[?]",    1024)
    local useddc  = ffi.new("int[?]",        1)
    
    ffi.C.MultiByteToWideChar(codepage, 0, str, #str, widestr, 1024)
    ffi.C.WideCharToMultiByte(CP_UTF8, 0, widestr, -1, utf8str, 1024, nil, useddc)
    
    return ffi.string(utf8str)
end

function removeBOM(s)
	if s:sub(1, 3) == string.char(0xEF, 0xBB, 0xBF) then
		return s:sub(4)
	else
		return s
	end
end

args = {...}
filename = args[1]
encoding = tonumber(args[2]) or 1252

if filename == nil then 
	print "Usage: luajit ansitoutf8.lua filename [encoding]"
	os.exit()
end

f = io.open(filename, "r")

for l in f:lines() do
	io.write(ansitoutf8(removeBOM(l), encoding), "\n")
end
