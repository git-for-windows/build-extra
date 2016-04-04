function findNotes(n)
    local r = n:gsub("{note%-%d}", function(s)
        local num = s:match("%d")
        return '<sup><a id="n' .. num .. '" href="#note-' .. num .. '" onMouseOver="showTooltip(n' .. num .. ', t' .. num .. ')" onMouseOut="hideTooltip(t' .. num .. ')">' .. num .. '</a></sup>'
    end)
    return r
end

function shortTitle(title)
    if title then
        return title:sub(1, title:find(",")-1)
    else 
        return nil
    end
end

function findLinks(t)
    local r = t:gsub("@%w+", function(s)
        local l = s:match("%w+")
        return '<a href="' .. (shortTitle(reference[l].title) or l) .. '.htm">' .. l .. '</a>'
    end)
    return r
end

function parseProto(proto)
    local function boldify(p, sep)
        if sep == nil then
            return p:gsub("%s[%a_]+", function(s)
                local name = s:match("[%a_]+")
                return " <b>" .. name .. "</b>"
            end)
        else
            return p:gsub("%s%a+%" .. sep, function(s)
                local name = s:match("%a+")
                return " <b>" .. name .. "</b>" .. sep
            end)
        end
    end
    
    if proto:sub(1, 7) == "#define" then
        local r, n = boldify(proto)
        return r
    end
    
    if proto:sub(1, 4) == "type" then
        local r, n = proto:gsub("type%s%a+%s", function(s)
            local name = s:match("%s%a+")
            return "type<b>" .. name .. "</b> "
        end)
        return r
    end
    
    local r, n = boldify(proto, "(")
    if n == 0 then r, n = boldify(proto, ":") end
    if n == 0 then r, n = boldify(proto, ";") end
    return r
end 

outfile = io.stdout

function prn(...)
    local args = {...}
    for k, v in pairs(args) do
        outfile:write(findNotes(v))
    end
end

function prnl(...)
    local args = {...}
    for k, v in pairs(args) do
        outfile:write(findLinks(findNotes(v)))
    end
end

function sortedpairs(t)
    local keys = {}
    local i = 1
    for key, val in pairs(t) do
        keys[i] = key
        i = i + 1
    end
    table.sort(keys)
    return coroutine.wrap(function()
        for i, key in ipairs(keys) do
            coroutine.yield(key, t[key])
        end
    end)
end

function htmlheader(title)
    prn([[
<html>
<head>
  <title>]], title, [[</title>
  <link rel="stylesheet" type="text/css" href="styles.css"/>
  <script type="text/javascript" src="tooltip.js"></script>
</head>
<body>
]])
end

function setout(filename)
    outfile = io.open(filename, "w")
end

function closeout()
    outfile:close()
end

function writePage(page, title)
    setout((shortTitle(page.title) or title) .. ".htm")
    htmlheader(page.title or title)

    prn("<pre class=\"proto\">", parseProto(page.proto), "</pre>\n")
    prnl("<p>", page.desc or "", "</p>\n<dl>\n")
    
    if page.params ~= nil then
        prn("<dt>Parameters:</dt><dd><p><table>\n");
        for i, param in ipairs(page.params) do
            if i == 1 then
                prn("  <tr><td><tt>", param[1], "</tt></td><td class=\"wide\">", param[2], "</td></tr>\n")
            else
                prn("  <tr><td><tt>", param[1], "</tt></td><td>", param[2], "</td></tr>\n")
            end
        end
        prn("</table></p></dd>\n")
    end
    
    if page.options ~= nil then
        prn("<dt>Options:</dt><dd><p><table>\n");
        prn("  <tr><th>Name</th><th class=\"wide\">Description</th><th>Default</th></tr>\n")
        for i, option in ipairs(page.options) do
            prnl("  <tr><td><tt>", option[1], "</tt></td><td>", option[2], "</td><td><tt>", option[3],"</tt></td></tr>\n")
        end
        prn("</table></p></dd>\n")
    end
    
    if page.returns ~= nil then
        prn("<dt>Returns:</dt><dd>\n")
        prn("  <p>", page.returns, "</p>\n")
        prn("</dd>\n")
    end;
    
    if page.example ~= nil then
        prn("<dt>Example:</dt><dd>\n")
        prn("<pre>", page.example, "</pre>\n")
        prn("</dd>\n")
    end;

    if page.notes ~= nil then
        prn("<dt>Notes:</dt><dd><p>\n")
        for i, note in ipairs(page.notes) do
            prnl("  <a id=\"note-" .. i .. "\"><sup>" .. i .. "</sup></a>", note, "<br/>\n")
        end
        prn("</p></dd>\n")
    end
    
    if page.seealso ~= nil then
        prn("<dt>See also:</dt><dd><p>\n")
        for i, sa in ipairs(page.seealso) do
            prn([[  <a href="]], shortTitle(reference[sa].title) or sa, [[.htm">]], sa, "</a><br/>\n")
        end
        prn("</p></dd>\n")
    end
    
    prn "</dl>\n"
    
    if page.notes ~= nil then
        for i, note in ipairs(page.notes) do
            prnl([[<div class="tooltip" id="t]] .. i .. [[">]], note, "</div>\n")
        end
    end

    prn "</body>\n</html>\n"
    closeout()
end

function writePages(ref)
    io.write "Generating reference...\n"
    for title, page in sortedpairs(ref) do
        io.write("    ", title, "\n")
        writePage(page, title)
    end
end

function writeRefPage(ref)
    io.write "Generating reference HTML contents...\n"
    setout "Reference.htm"
    htmlheader "Reference"
    prn[[<h3>Inno Download Plugin reference</h3>]]
    
    for title, group in sortedpairs(groups) do
        prn([[<a id="]], title, [[">]], title, [[:</a>
<ul class="clean">
]])
        
        for title, page in sortedpairs(group) do
            prn('  <li><a href="', (shortTitle(page.title) or title), '.htm">', title, "</a></li>\n")
        end
    prn[[</ul>]]
    end
    
    prn[[
</body>
</html>
]]
    closeout()
end

function writeHtmlTOC(ref)
    io.write "Generating HTML contents...\n"
    setout "Contents.htm"
    htmlheader "Contents"
    
    prn[[    
<ul>
  <li class="book"><a href="Overview.htm" target="doc">Overview</li>
  <ul>
    <li class="page"><a href="Overview.htm#installation" target="doc">Installation</a></li>
    <li class="page"><a href="Overview.htm#usage" target="doc">Usage</a></li>
    <li class="page"><a href="Overview.htm#links" target="doc">Links</a></li>
  </ul>
  <li class="book"><a href="Reference.htm" target="doc">Reference</li>
  <ul>
]]
    
    for title, group in sortedpairs(groups) do
        prn([[
    <li class="book"><a href="Reference.htm#]], title, [[" target="doc">]], title, [[</li>
    <ul>
]])
        for title, page in sortedpairs(group) do
            prn('      <li class="page"><a href="', (shortTitle(page.title) or title), '.htm" target="doc">', title, '</a></li>\n')
        end
        
        prn[[</ul>]]
    end
    
prn[[
  </ul>
  <li class="page"><a href="History.htm" target="doc">Version history</a></li>
  <li class="page"><a href="License.htm" target="doc">License</a></li>
</ul>
</body>
</html>
]]
    closeout()
    
    setout "Index.htm"
    prn[[
<html>
<head><title>Inno Download Plugin</title></head>
<frameset cols="20%, 80%">
  <frame name="toc" src="Contents.htm"/>
  <frame name="doc" src="Overview.htm"/>
</frameset>
</html>
]]
    
    closeout()
end

function writeTOC(ref)
    io.write "Generating HTMLHelp contents...\n"
    setout "Contents.hhc"
    prn[[
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">
<HTML>
<HEAD>
<!-- Sitemap 1.0 -->
</HEAD><BODY>
<UL>
    <LI> <OBJECT type="text/sitemap">
        <param name="Name" value="Overview">
        <param name="Local" value="Overview.htm">
        </OBJECT>
    <UL>
        <LI> <OBJECT type="text/sitemap">
            <param name="Name" value="Installation">
            <param name="Local" value="Overview.htm#installation">
            </OBJECT>
        <LI> <OBJECT type="text/sitemap">
            <param name="Name" value="Usage">
            <param name="Local" value="Overview.htm#usage">
            </OBJECT>
        <LI> <OBJECT type="text/sitemap">
            <param name="Name" value="Links">
            <param name="Local" value="Overview.htm#links">
            </OBJECT>
    </UL>
    <LI> <OBJECT type="text/sitemap">
        <param name="Name" value="Reference">
        <param name="Local" value="Reference.htm">
        </OBJECT>
    <UL>
]]
    for title, group in sortedpairs(groups) do
        prn([[
        <LI> <OBJECT type="text/sitemap">
            <param name="Name" value="]], title, [[">
            <param name="Local" value="Reference.htm#]], title, [[">
            </OBJECT>
        <UL>
]])
        for title, page in sortedpairs(group) do
            prn([[
            <LI> <OBJECT type="text/sitemap">
                <param name="Name" value="]], title, [[">
                <param name="Local" value="]], (shortTitle(page.title) or title), [[.htm">
                </OBJECT>
]])
        end
        
        prn [[
        </UL>]]
    end
    
    prn[[
    </UL>
    <LI> <OBJECT type="text/sitemap">
        <param name="Name" value="Version history">
        <param name="Local" value="History.htm">
        </OBJECT>
    <LI> <OBJECT type="text/sitemap">
        <param name="Name" value="License">
        <param name="Local" value="License.htm">
        </OBJECT>
</UL>
</BODY></HTML>
]]
    closeout()
end

function buildIndex(ref)
    local idx = {}
    for title, page in pairs(ref) do
        idx[title] = (shortTitle(page.title) or title)
        
        if page.options ~= nil then
            for i, option in ipairs(page.options) do
                idx[option[1]] = (page.title or title)
            end
        end
        
        if page.keywords ~= nil then
            for i, keyword in pairs(page.keywords) do
                idx[keyword] = (shortTitle(page.title) or title)
            end
        end
    end
    
    return idx
end

function idxEntry(key, page)
    prn([[
    <LI> <OBJECT type="text/sitemap">
        <param name="Name" value="]],  key, [[">
        <param name="Name" value="]],  page, [[">
        <param name="Local" value="]], page, [[.htm">
        </OBJECT>
]])
end

function writeHHK(idx)
    io.write "Generating HTMLHelp index...\n"
    setout "Index.hhk"
    prn[[
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">
<HTML>
<HEAD>
<!-- Sitemap 1.0 -->
</HEAD><BODY>
<UL>
]]
    for key, page in sortedpairs(idx) do
        idxEntry(key, page)
    end
    
    idxEntry("License",                "License")
    idxEntry("History",                "History")
    idxEntry("Changes",                "History")
    idxEntry("Reference",              "Reference")
    idxEntry("Function list",          "Reference")
    idxEntry("Types",                  "Reference")
    idxEntry("Macros",                 "Reference");
    idxEntry("Overview",               "Overview")
    idxEntry("Installation",           "Overview")
    idxEntry("Usage",                  "Overview")
    idxEntry("Links",                  "Overview")

    prn[[
</UL>
</BODY></HTML>
]]
    closeout()
end

function writeHHP(ref)
    io.write "Generating HTMLHelp project file...\n"
    setout "idp.hhp"
    prn[[
[OPTIONS]
Compatibility=1.1 or later
Compiled file=idp.chm
Contents file=Contents.hhc
Default Window=main
Default topic=Overview.htm
Display compile progress=Yes
Full-text search=Yes
Index file=Index.hhk
Language=0x409 Английский (США)
Title=Inno Download Plugin

[WINDOWS]
main=,"Contents.hhc","Index.hhk","Overview.htm","Overview.htm",,,,,0x42520,,0x10304e,[88,80,869,673],,,,,,,0

[FILES]
Overview.htm
Reference.htm
License.htm
History.htm
]]
    --removing duplicates to avoid warnings
    local files = {}
    
    for title, page in pairs(ref) do
        files[shortTitle(page.title) or title] = 1
    end
    
    for title, unused in sortedpairs(files) do
        prn(title, ".htm\n")
    end
    
    closeout()
end

function writeLicense(filename)
    setout "License.htm"
    htmlheader "License"
    prn "<h3>Inno Download Plugin license</h3>\n"
    
    local f = io.open(filename, "r")
    
    for l in f:lines() do
        if l ~= "" then
            prn("<p>", l:gsub("%(c%)", "&copy;"), "</p>\n")
        end
    end
    
    prn "</body>\n</html>"
    f:close()
    closeout()
end

function writeHistory(hist)
    setout "History.htm"
    htmlheader "Version History"
    prn[[
<h3>Inno Download Plugin version history</h3>
<dl>
]]
    
    for i = #hist, 1, -1 do
        prn("  <dt>", hist[i][1], "</dt><dd>", hist[i][3], "</dd><br/>\n")
    end
    
    prn[[
</dl>
</body>
</html>
]]
    closeout()
end

function writeMainPage(page)
    setout "Overview.htm"
    htmlheader "Inno Download Plugin"
    prn(page)
    prn[[
</body>
</html>
]]
    closeout()
end
