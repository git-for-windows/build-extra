function showTooltip(a, div)
{
    var r = a.getBoundingClientRect();
    var w = document.body.clientWidth;
    
    if(r.left + 125 > w)
        div.style.left = w - 250;
    if(r.left - 125 < 0)
        div.style.left = 1;
    else
        div.style.left = r.left - 125 + document.body.scrollLeft;
        
    div.style.top     = r.bottom + 1 + document.body.scrollTop;
    div.style.display = 'inline';
}
 
function hideTooltip(div)
{
    div.style.display = 'none';
}