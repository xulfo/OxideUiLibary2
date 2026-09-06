local PLACE=83038462357724
if game.PlaceId~=PLACE then return end
local function B(s)
    local m,a={},"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    for i=1,#a do m[a:sub(i,i)]=i-1 end
    local o,n={},0
    for i=1,#s,4 do
        local A,C=m[s:sub(i,i)],m[s:sub(i+1,i+1)]
        local D,E=m[s:sub(i+2,i+2)],m[s:sub(i+3,i+3)]
        if A and C then
            n=n+1;o[n]=string.char(A*4+math.floor(C/16))
            if D then
                n=n+1;o[n]=string.char((C%16)*16+math.floor(D/4))
                if E then n=n+1;o[n]=string.char((D%4)*64+E)end
            end
        end
    end
    return table.concat(o)
end
local function X(d,k)
    local o={}
    for i=1,#d do o[i]=string.char(bit32.bxor(d:byte(i),k:byte(((i-1)%#k)+1)))end
    return table.concat(o)
end
local function F(u)
    local ok,s=pcall(game.HttpGet,game,u)
    if ok and type(s)=="string"and #s>=100 then return true,s end
    if type(request)=="function"then
        local ok2,r=pcall(request,{Url=u,Method="GET"})
        if ok2 and type(r)=="table"and r.StatusCode==200 and type(r.Body)=="string"and #r.Body>=100 then return true,r.Body end
    end
    return false,nil
end
local keyBytes={23,32,51,51,44,120,25,60,55,120,103,101,103,99,120,13,44,15,116}
local _k={}
for i=1,#keyBytes do _k[i]=string.char(bit32.bxor(keyBytes[i],85))end
_k=table.concat(_k)
local L="https://codeberg.org/leon232hie/OxideUiLibary/raw/branch/main/lib.enc"
local G="https://codeberg.org/leon232hie/OxideUiLibary/raw/branch/main/graben.enc"
local ok,b=F(L)if not ok then error("[Oxide] Library download failed",0)end
local src=X(B(b),_k)
local ch,err=loadstring(src)if not ch then error("[Oxide] Library compile",0)end
local o2,lib=pcall(ch)if not o2 or type(lib)~="table"or type(lib.CreateWindow)~="function"then error("[Oxide] Library load failed",0)end
_G.OxideLib=lib
local ok2,b2=F(G)if not ok2 then error("[Oxide] Script download failed",0)end
local gs=X(B(b2),_k)
local ch2,err2=loadstring("local Library = _G.OxideLib;\n"..gs)if not ch2 then error("[Oxide] Script compile",0)end
local o3,err3=pcall(ch2)if not o3 then error("[Oxide] Script error",0)end
