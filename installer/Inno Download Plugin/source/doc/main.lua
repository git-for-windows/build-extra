groups = {}
reference = {
    group = function(title)
        groups[title] = {}
        
        setmetatable(reference, {
            __index = _G,
            __newindex = function(t, k, v)
                rawset(reference, k, v)
                groups[title][k] = v
            end})
    end
}

if tonumber(_VERSION:match("%d%.%d")) >= 5.2 then
    buildRef = loadfile("reference.lua", "bt", reference)
else
    buildRef = loadfile("reference.lua")
    setfenv(buildRef, reference);
end

buildRef()

for k, v in pairs(reference) do
    if type(v) ~= "table" then
        reference[k] = nil
    end
end

dofile "mainpage.lua"
dofile "history.lua"
dofile "generator.lua"

index = buildIndex(reference)

writePages(reference)
writeRefPage(reference)
writeHtmlTOC(reference)
writeTOC(reference)
writeHHP(reference)
writeHHK(index)
writeMainPage(mainpage)
writeHistory(history)
writeLicense("../COPYING.txt")