-----------------
-- Microlight - a very compact Lua utilities module
--
-- Some local functions used in the Microlight code also show up in the
-- HTML documentation made by LDoc. You can use them from Microlight by 
-- `require"ml-extra"` either instead or after requiring `ml`.
--
-- Caveat: this has been designed with Lua 5.2 in mind.  The present
--    version works on Lua 5.1 too but backwards compatibility must 
--    not be taken for granted in future versions.
--
-- Steve Donovan, 2012; Dirk Laurie, 2013; License MIT
-- @module ml

local lua51 = _VERSION:match '5%.1$'
local ml = {ML_VERSION='1.2-rc1'}
local rawget,select,pairs,tostring = 
      rawget,select,pairs,tostring
local S,T = string, table
local find, sub, match = S.find, S.sub, S.match
local append,  pack,  unpack,            concat,  sort,  remove = 
    T.insert,T.pack,unpack or T.unpack,T.concat,T.sort,T.remove
local function_arg, metafield, tstring

pack = pack or function(...)
   return {n=select('#',...),...}
end

---------------------------------------------------
-- String utilties.
-- @section string
---------------------------------------------------

--- split a delimited string into an array of strings.
-- @param s The input string
-- @param re A Lua string pattern; defaults to '%s+'. Patterns with 
--    magic `+` at the end do not produce empty pieces.
-- @param n optional maximum number of splits, tail returned unsplit
-- @return an array of strings
function ml.split(s,re,n)
    local i1,ls = 1,{}
    if not re then re = '%s+' end
    if match('',re) then return {s} end
    local allow_empty = match(re,'%%%+') or not match(re,'%+')
    while true do
        local i2,i3 = find(s,re,i1)
        if not i2 then
            local last = sub(s,i1)
            if (last ~= '' or allow_empty) then append(ls,last) end
            return ls
        end
        if allow_empty or i2>i1 then append(ls,sub(s,i1,i2-1)) end
        if n and #ls == n then
            ls[#ls] = sub(s,i1)
            return ls
        end
        i1 = i3+1
    end
end

--- escape any 'magic' pattern characters in a string.
-- Useful for functions like `string.gsub` and `string.match` which
-- always work with Lua string patterns.
-- For any s, `s:match('^'..escape(s)..'$') == s` is `true`.
-- @param s The input string
-- @return an escaped string
function ml.escape(s)
    local res = s:gsub('[%-%.%+%[%]%(%)%$%^%%%?%*]','%%%1')
    if lua51 then
        res = res:gsub('%z','%%z')
    end
    return res
end

--- expand a string containing any `${var}` or `$var`.
-- If the former form is found, the latter is not looked for, so
--   pick _either one_ of these forms consistently!
-- Substitution values should be only numbers or strings.
-- @param s the string
-- @param subst either a table or a function (as in `string.gsub`)
-- @return expanded string
function ml.expand (s,subst)
    local res,k = s:gsub('%${([%w_]+)}',subst)
    if k > 0 then return res end
    return (res:gsub('%$([%w_]+)',subst))
end

--- quoted string or raw tostring (local)
-- @param v a value  
-- @param raw for non-strings, ignore the object's __tostring metafield
-- @return the quoted string (a result of `tstring` is not requoted) 
-- or raw tostring for other values
local function quote (v,raw)
    if type(v) == 'string' and not (v:match'^"' and v:match'"$') 
        and not (v:match'^{' and v:match'}$') then        
        return ('%q'):format(v)
    else
        local tostr=metafield(v,__tostring)
        if tostr and raw then getmetatable(v).__tostring=nil end
        local q = tostring(v)
        if tostr and raw then getmetatable(v).__tostring=tostr end
        return q
    end
end

local lua_keyword = {
    ["and"] = true, ["break"] = true,  ["do"] = true,
    ["else"] = true, ["elseif"] = true, ["end"] = true,
    ["false"] = true, ["for"] = true, ["function"] = true,
    ["if"] = true, ["in"] = true,  ["local"] = true, ["nil"] = true,
    ["not"] = true, ["or"] = true, ["repeat"] = true,
    ["return"] = true, ["then"] = true, ["true"] = true,
    ["until"] = true,  ["while"] = true, ["goto"] = true,
}

local function is_iden (key)
    return key:match '^[%a_][%w_]*$' and not lua_keyword[key]
end

local function istable (t) 
   if type(t)=="table" then return 1 else return 0 end 
end

local tbuff
function tbuff (t,level,buff,how)
    local indent,     sep,            tsep,            wrap,     raw = 
      how.indent, how.sep or ',', how.tsep or ';', how.wrap, how.raw
    local maxlen = how.len or math.huge
    if buff.len>maxlen then return end

    local function append (...)
        if indent then
            local lead=select(1,...)
            if lead=='{' then if level>0 then
               buff[#buff+1] = '\n'..(' '):rep(indent*level)
               end
            elseif lead=='}' then
            elseif lead==tsep then
            else
               if buff[#buff] == '{' then
                  buff[#buff+1] = (' '):rep(indent-1)  
               else  
                  buff[#buff+1] = '\n'..(' '):rep(indent*(level+1))
               end
            end
        end
        for k=1,select('#',...) do
            local v=select(k,...)
            if not v or buff.len>maxlen then return end
            buff.len = buff.len+#v
            if buff.len>maxlen then v="!! too long !!" end
            buff[#buff+1] = v
            buff.linelen = buff.linelen+#v
        end
        if wrap and buff.linelen>=wrap then 
            buff[#buff+1]='\n'; buff.linelen=0 
        end
    end

    local function removetrailer()
        if buff[#buff]==sep or buff[#buff]==tsep then buff[#buff]=nil
        elseif buff[#buff]:match"^\n" and
            buff[#buff-1]==sep or buff[#buff-1]==tsep then 
            remove(buff,#buff-1)
        end
    end

    if type(t)~='table' then append(quote(t,raw),sep) return end
    local tostr = metafield(t,'__tostring')
    if tostr and not raw then append(tostr(t)) return end
    local tables = buff.tables
    if tables[t] then append("<cycle "..quote(t).." >",sep); return end    
    tables[t]=true
    append('{')

    local old=#buff
    local done={}
    -- array part -------
    for k=1,#t do
        if not t[k] then break end
        tbuff(t[k],level+istable(t[k]),buff,how)
        done[k]=true
    end
    -- 'map' part ------
    for key,value in pairs(t) do if not done[key] then
        if type(key)~='string' or not is_iden(key) then
            if type(key)=='table' then
                key = tstring(key,how)
            else
                key = quote(key,how.raw)
            end
            key = "["..key.."]"
        end
        append(key..'=')
        tbuff(value,level+istable(t[k]),buff,how)
     end end
     removetrailer()
     append"}"
     if level>0 then append(tsep) end
end   
    
local default_how={}
--- return a string representation of a Lua value.
-- Cycles are detected, and the appearance of the result can be customized.
-- @param t the value to be represented
-- @param how (optional) a table or string containing customization info,
--    stays in effect until overridden
--    how.sep: separator appearing after scalar item (default `,`)
--    how.tsep: separator appearing after table-valued item (default `;`)  
--    how.wrap: length of lines to aim for
--    how.indent: number of spaces to indent (implies one item to a line)      
--    how.raw: override item's own __tostring
--    how.limit: bail out when string length passes `limit`
--    If `how` is a number, it is used as how.indent
-- @return a string
function ml.tstring (t,how)
    if type(how) == 'number' then how = {indent = how} end
    if how then default_how=ml.update({},how) 
           else how=ml.update({},default_how) 
    end    
    if type(t) == 'table' then
        local buff = {tables={},len=0,linelen=0}
        if metafield(t,'__tostring')==ml.tstring then how.raw=true end
        tbuff(t,0,buff,how)
        return concat(buff)     
    else
        return quote(t,how.raw)
    end
end
tstring = ml.tstring

---------------------------------------------------
-- File and Path functions
-- @section file
---------------------------------------------------

--- return the contents of a file as a string
-- @param filename The file path
-- @param is_bin open in binary mode, default false
-- @return file contents, or nil,error
function ml.readfile(filename,is_bin)
    local mode = is_bin and 'b' or ''
    local f,err = io.open(filename,'r'..mode)
    if not f then return nil,err end
    local res,err = f:read('*a')
    f:close()
    if not res then return nil,err end
    return res
end

--- write a string to a file,
-- @param filename The file path
-- @param str The string
-- @param is_bin open in binary mode, default false
-- @return true or nil,error
function ml.writefile(filename,str,is_bin)
    local f,err = io.open(filename,'w'..(is_bin or ''))
    if not f then return nil,err end
    f:write(str)
    f:close()
    return true
end

--- Does a file exist?
-- @param filename a file path
-- @return the file path, otherwise nil
-- @usage file = exists 'readme' or exists 'readme.txt' or exists 'readme.md'
function ml.exists (filename)
    local f = io.open(filename)
    if not f then
        return nil
    else
        f:close()
        return filename
    end
end

local sep, other_sep = package.config:sub(1,1),'/'

--- split a path into directory and file part.
-- if there's no directory part, the first value will be the empty string.
-- Handles both forward and back-slashes on Windows.
-- @param P A file path
-- @return the directory part
-- @return the file part
function ml.splitpath(P)
    local i = #P
    local ch = P:sub(i,i)
    while i > 0 and ch ~= sep and ch ~= other_sep do
        i = i - 1
        ch = P:sub(i,i)
    end
    if i == 0 then
        return '',P
    else
        return P:sub(1,i-1), P:sub(i+1)
    end
end

--- split a path into root and extension part.
-- if there's no extension part, the second value will be empty
-- @param P A file path
-- @return the name part
-- @return the extension
function ml.splitext(P)
    local i = #P
    local ch = P:sub(i,i)
    while i > 0 and ch ~= '.' do
        if ch == sep or ch == other_sep then
            return P,''
        end
        i = i - 1
        ch = P:sub(i,i)
    end
    if i == 0 then
        return P,''
    else
        return P:sub(1,i-1),P:sub(i)
    end
end

---------------------------------------------------
-- Table utilities.
--
-- @section table
---------------------------------------------------

--- new empty object of same type as argument (local)
-- @param ... values to be examined one by one until a table that has
-- a metatable is found
-- @return an empty table having the same metatable as the found object
local new = function(...)
    local mt
    for k=1,select('#',...) do 
        local t=select(k,...)
        if type(t)=='table' then mt = getmetatable(t) end
        if mt then break end
    end
    return setmetatable({},mt)
end

--- metafield of an object (local)
-- @param t a table
-- @param key a field name
-- @return value of that field in the metatable of t, if any
metafield = function(t,key)
    local mt = getmetatable(t)
    return mt and mt[key]
end

--- collect a series of values from an iterator.
-- @param count (optional) a number, the maximum number of items to collect
-- @param ... iterator
-- @return array-like table
-- @usage collect(pairs(t)) -- gives an unsorted version of keys(t)
function ml.collect (count,...)
    local res = {}
    if type(count)=='number' then
        local n=0
        for k in ... do 
            if n>=count then break end
            append(res,k)
            n = n+1 
        end
    else for k in count,... do append(res,k) end
    end
    return res
end

--- create an array of numbers from start to end.
-- With one argument it goes `1..x1`. `d` may be a
-- floating-point fraction
-- @param x1 start value if x2 given, otherwise end value (starting from 1)
-- @param x2 end value
-- @param d increment (default 1)
-- @return array of numbers
-- @usage range(2,10,2) --> {2,4,6,8,10}
-- @usage range(5) --> {1,2,3,4,5}
function ml.range (x1,x2,d)
    if not x2 then
        x2 = x1
        x1 = 1
    end
    d = d or 1
    local res,k = {},1
    for x = x1,x2,d do
        res[k] = x
        k = k + 1
    end
    return res
end

---------------------------------------------------
-- Object-like array functions.
-- 'array' here is shorthand for 'array-like table'; these functions
-- only operate over the numeric `1..#t` range of a table and are
-- particularly efficient for this purpose. If these functions are
-- added to the __index table of an object, they can be called in an
-- object-oriented way, and the ones that created new tables will
-- replicate the metatable an object given as first parameter.
--
-- @section array
---------------------------------------------------

--- apply a function to each element of an array.
-- The output must always be the same length as the input, so
-- any `nil` values are mapped to `false`.
-- @param t the array
-- @param f a function of one or more arguments
-- @param ... any extra arguments to the function
-- @return the transformed array
function ml.apply (t,f,...)
   for i=1,#t do 
      if t[i] then t[i]=f(t[i],...) or false 
      else t[i]=false
      end
   end 
   return t
end

--- filter an array using a predicate.
-- @param t a table
-- @param pred a function that must return `nil` or `false`
-- to exclude a value
-- @param ... any extra arguments to the predicate
-- @return a new array such that `pred(t[i])` evaluates as true
function ml.ifilter(t,pred,...)
    local res,k = new(t),1
    pred = function_arg(pred)
    for i = 1,#t do
        if pred(t[i],...) then
            res[k] = t[i]
            k = k + 1
        end
    end
    return res
end

--- find an item in an array using a predicate.
-- @param t the array
-- @param pred a function of at least one argument
-- @param ... any extra arguments
-- @return the item value, or `nil`
-- @usage ifind({{1,2},{4,5}},'X[1]==Y',4) --> {4,5}
function ml.ifind(t,pred,...)
    pred = function_arg(pred)
    for i = 1,#t do
        if pred(t[i],...) then
            return t[i]
        end
    end
end

--- return the first index of an item in an array.
-- @param t the array
-- @param value item value
-- @param cmp optional comparison function (default is `X==Y`)
-- @return index, otherwise `nil`
function ml.indexof (t,value,cmp)
    if cmp then cmp = function_arg(cmp) end
    for i = 1,#t do
        local v = t[i]
        if cmp and cmp(v,value) or v == value then
            return i
        end
    end
end

local function copy_range (dest,index,src,i1,i2)
    local k = index
    for i = i1,i2 do
        dest[k] = src[i]
        k = k + 1
    end
    return dest
end

--- return a slice of an array.
-- Like `string.sub`, negative indices count from the end.
-- @param t the array
-- @param i1 the start index, default 1
-- @param i2 the end index, default #t (like `string.sub`)
-- @return a new array containing `t[i]` in the specified range
function ml.sub(t,i1,i2)
    i1, i2 = i1 or 1, i2 or #t
    if i1<0 then i1=#t+i1+1 end
    if i2<0 then i2=#t+i2+1 end
    return copy_range(new(t),1,t,i1,i2)
end

local function upper (t,i2)
    if not i2 or i2 > #t then
        return #t
    elseif i2 < 0 then
        return #t + i2 + 1
    else
        return i2
    end
end

--- delete a range of values from an array.
-- @param tbl the array
-- @param start start index
-- @param finish end index (like `ml.sub`)
-- NB Like table.remove, does not return `tbl`
function ml.removerange(tbl,start,finish)
    finish = upper(tbl,finish)
    local count = finish - start + 1
    for k=start+count,#tbl do tbl[k-count]=tbl[k] end
    for k=#tbl,#tbl-count+1,-1 do tbl[k]=nil end
end

--- copy values from `src` into `dest` starting at `index` (local).
-- By default, it moves up elements of `dest` to make room.
-- @param dest destination array
-- @param index start index in destination
-- @param src source array
-- @param overwrite write over values
local function insertinto(dest,index,src,overwrite)
    local sz = #src
    if not overwrite then
        for i = #dest,index,-1 do dest[i+sz] = dest[i] end
    end
    copy_range(dest,index,src,1,sz)
end

--- extend an array using values from other tables.
-- @param t the array to be extended
-- @param ... the other arrays
-- @return the extended array
-- @usage `extend({},t)` --> a shallow copy of the array part of t
-- @usage `extend(t,u1,u2)` -- replaces t by the "concatenation" of t,u1,u2
function ml.extend(t,...)
    for i = 1,select('#',...) do
        insertinto(t,#t+1,select(i,...),true)
    end
    return t
end

--- make an array of indexed values.
-- Generalized table indexing. Result will only contain
-- values for keys that exist.
-- @param t a table
-- @param keys an array of keys or indices
-- @return an array `L` such that `L[keys[i]]`
-- @usage indexby({one=1,two=2},{'one','three'}) --> {1}
-- @usage indexby({10,20,30,40},{2,4}) --> {20,40}
function ml.indexby(t,keys)
    local res = new(t)
    for _,v in pairs(keys) do
        if t[v] ~= nil then
            append(res,t[v])
        end
    end
    return res
end

-- Bring modules or tables into 't`.
-- If `lib` is a string, then it becomes the result of `require(lib)`
-- With only one argument, the second argument is assumed to be
-- the `ml` table itself.
-- @param t table to be updated, or current environment
-- @param lib table, module name or `nil` for importing 'ml'
-- @return the updated table
function ml.import(t,...)
    local other
    -- explicit table, or current environment
    -- this isn't quite right - we won't get the calling module's _ENV
    -- this way. But it does prevent execution of the not-implemented setfenv.
    t = t or _ENV or getfenv(2)
    local libs = {}
    if select('#',...)==0 then -- default is to pull in this library!
        libs[1] = ml
    else
        for i = 1,select('#',...) do
            local lib = select(i,...)
            if type(lib) == 'string' then
                local value = _G[lib]
                if not value then -- lazy require!
                    value = require (lib)
                    -- and use the module part of package for the key
                    lib = lib:match '[%w_]+$'
                end
                lib = {[lib]=value}
            end
            libs[i] = lib
        end
    end
    return ml.update(t,unpack(libs))
end

--- add the key/value pairs of the other tables to the first table.
-- For sets, this is their union. For the same keys, values found in
-- earlier tables are overwritten.
-- @param t table to be updated
-- @param ... tables containg more pairs to be added
-- @return the updated table
-- @usage update({},tbl) --> a shallow copy of t
function ml.update (t,...)
    for i = 1,select('#',...) do
        for k,v in pairs(select(i,...)) do
            t[k] = v
        end
    end
    return t
end

--- make a table from an array of keys and an array of values.
-- @param t an array of keys
-- @param tv an array of values
-- @return a table where `{[t[i]]=tv[i]}`
-- @usage makemap({'power','glory'},{20,30}) --> {power=20,glory=30}
function ml.makemap(t,tv)
    local res = {}
    for i = 1,#t do
        res[t[i]] = tv and tv[i] or i
    end
    return res
end

---------------------------------------------------
-- Set functions.
-- A set consists of the keys of table, no matter what the values are.
--
-- @section set
---------------------------------------------------

--- make a bag (multiset) from a table; can be used as a set
-- @param t a table
-- @return a table of the number of times each key appears as a value in t
-- @usage bag{3,5,6,5,7,3,5} --> {[7]=1,[5]=3,[3]=2,[6]=1}
function ml.bag(t)
    local res=new(t)
    for k,v in pairs(t) do res[v]=(res[v] or 0)+1 end
    return res
end

--- Invert keys and values in a table.
-- @param t a table
-- @return a table where keys and values swap places
-- @usage invert{'one','two'} --> {one=1,two=2}
function ml.invert(t)
    local res=new(t)
    for k,v in pairs(t) do res[v]=k end
    return res
end

--- extract the keys of a table as an array.
-- @param t a table
-- @return an array of keys (sorted)
function ml.keys(t)
    local keys = ml.collect(pairs(t))
    sort(keys)
    return keys
end

--- are all the keys of `other` in `t`?
-- @param t a set (i.e. a table whose keys are the set elements)
-- @param other a possible subset
-- @treturn bool
function ml.contains(t,other)
    for k,v in pairs(other) do
        if t[k] == nil then return false end
    end
    return true
end

--- return the number of keys in this table, i.e. the cardinality of this set.
-- @param t a table
-- @treturn int key count
function ml.count (t)
    local count = 0
    for k in pairs(t) do count = count + 1 end
    return count
end

--- set equality: do these tables have the same keys?
-- @param t a table
-- @param other a table
-- @return true or false
function ml.equalkeys(t,other)
    return ml.contains(t,other) and ml.contains(other,t)
end

---------------------------------------------------
-- Functional helpers.
-- @section function
---------------------------------------------------

--- create a function which will throw an error on failure.
-- @param f a function that returns nil,err if it fails
-- @return an equivalent function that raises an error
-- @usage openfile=throw(io.open); myfile=openfile'junk.txt'
function ml.throw(f)
    f = function_arg(f)
    return function(...)
        local r1,r2,r3 = f(...)
        if not r1 then error(r2,2) end
        return r1,r2,r3
    end
end

--- bind values to the arguments of function `f`.
-- @param f a function of at least one argument
-- @param ... values to bind (nil leaves an argument free)
-- @return a function of fewer arguments (by the number of bound values)
-- @usage interior = bind(string.sub,nil,2,-2)
function ml.bind(f,...)
    f = function_arg(f)
    local bindings = pack(...)
    return function(...)
        local args = {}
        local n=1
        for k=1,bindings.n do 
            if bindings[k]==nil then
                args[k]=select(n,...)
                n=n+1
            else args[k]=bindings[k]
            end
        end
        return f(unpack(args))
    end
end

--- compose two functions.
-- For instance, `printf` can be defined as `compose(io.write,string.format)`
-- @param f1 a function
-- @param f2 a function
-- @return `f1(f2(...))`
function ml.compose(f1,f2)
    f1 = function_arg(f1)
    f2 = function_arg(f2)
    return function(...)
        return f1(f2(...))
    end
end

--- is the object either a function or a callable object?.
-- @param obj Object to check.
-- @return true if callable
function ml.callable (obj)
    return type(obj) == 'function' or metafield(obj,"__call")
end

local function _string_lambda (f)
    local code = 'return function(X,Y,Z) return '..f..' end'
    local chunk = assert(loadstring(code,'tmp'))
    return chunk()
end

local string_lambda

--- make a value callable (local)
-- @param f a callable or a string lambda.
-- @return a function
-- @raise error if `f` is not callable in any way, or errors in string lambda.
-- @usage function_arg('X+Y')(1,2) --> 3
function_arg = function(f)
    if type(f) == 'string' then
        if not string_lambda then
            string_lambda = ml.memoize(_string_lambda)
        end
        f = string_lambda(f)
    else
        assert(ml.callable(f),"expecting a function or callable object")
    end
    return f
end
-- The first step for Microlight routines that need a function f is
-- `f = function_arg(f)`. The default version of `function_arg` accepts
-- anything that matches @{callable} or is a _string lambda_.
-- Anyone wishing to extend the idea of 'callable' in this library
-- can replace `callable` in the module table at runtime.

--- 'memoize' a function (cache returned value for next call).
-- This is useful if you have a function which is relatively expensive,
-- but you don't know in advance what values will be required, so
-- building a table upfront is wasteful/impossible.
-- @param func a function of at least one argument
-- @param serialize optional routine to convert arguments to a table key
--   (default: first argument to `func`) 
-- @return a function that does the same as `func` 
function ml.memoize(func,serialize)
   local cache = {}
   return function(...)
      local key = ...
      if serialize then key=serialize(...) end
      local val = cache[key] 
      if val then return val end
      val = func(...)
      cache[key] = val
      return val
   end
end

--- make the module table callable; `ml(t)` sets `ml` as a place to
-- look for methods when `t` is used in object-oriented calls.
-- This is an semi-undocumented feature: i.e. `readme.md`, 
-- `ml-demosuite.lua` and `ldoc ml.lua` do not mention it.
setmetatable(ml,{__call=
  function(ml,tbl) 
    if type(tbl)=='table' then setmetatable(tbl,{__index=ml}) end
    return tbl 
  end })

debug.getregistry().microlight_extra = {new=new, metafield=metafield, 
   insertinto=insertinto, function_arg=function_arg, quote=quote,
   default_how = function() return default_how end}

return ml
