-----------------
-- Microlight - a very compact Lua utilities module
--
-- Steve Donovan, 2012; Dirk Laurie, 2013; License MIT
-- @module ml

local lua51 = _VERSION:match '5%.1$'
local ml = {ML_VERSION='1.1-1+experimental'}
local rawget,select,pairs,tostring = 
      rawget,select,pairs,tostring
local S,T = string, table
local find, sub, match = S.find, S.sub, S.match
local append,  pack,  unpack,  concat,  sort = 
    T.insert,T.pack,T.unpack,T.concat,T.sort
local function_arg

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

---------------------------------------------------
-- File and Path functions
-- @section file
---------------------------------------------------

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
-- Extended table functions.
-- 'array' here is shorthand for 'array-like table'; these functions
-- only operate over the numeric `1..#t` range of a table and are
-- particularly efficient for this purpose.
-- @section table
---------------------------------------------------

local function quote (v)
    if type(v) == 'string' then
        return ('%q'):format(v)
    else
        return tostring(v)
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


local tbuff
function tbuff (t,level,buff,indent,sep,tsep,wrap)
    local indentation = (indent or ''):rep(level)
    local tables = buff.tables
    local len=0
    local function append (v,wrap)
        if not v then return end
        buff[#buff+1] = v
        len = len+#v
        if wrap and len>=wrap then 
            buff[#buff+1]='\n'; len=0 
        end
    end
    local function put_item(value)
        if type(value) == 'table' then
            if not tables[value] then
                tables[value] = true
                tbuff(value,level+1,buff,indent,sep,tsep)
            else
                append("<cycle>")
            end
            append(tsep,wrap)
        else
            value = quote(value)
            append(value)
            append(sep,wrap)
        end
        if indent then append ('\n'..indent) end
    end
    append "{"
    if indent then append ('\n'..indent) end
    -- array part -------
    local array = {}
    for i,value in ipairs(t) do
        append(indentation)
        put_item(value)
        array[i] = true
    end
    -- 'map' part ------
    for key,value in pairs(t) do if not array[key] then
        append(indent)
        -- non-identifiers need ["key"]
        if type(key)~='string' or not is_iden(key) then
            if type(key)=='table' then
                key = ml.tstring(key,false)
            else
                key = quote(key)
            end
            key = "["..key.."]"
        end
        append(key..'=')
        put_item(value)
    end end
    -- remove trailing separator if any unless `indent` supplied
    while buff[#buff]==sep or buff[#buff]==tsep do buff[#buff]=nil end
    if indent then append(indent) end
    append "}"
end

--- return a new empty object of the same type as the first object-valued 
-- argument
local new = function(...)
    local t
    for k=1,select('#',...) do 
        t = getmetatable(select(k,...))
        if t then break end
    end
    return setmetatable({},t)
end

--- return specified metafield, if any
local metafield = function(t,field)
    local mt = getmetatable(t)
    return mt and mt[field]
end

local default_how={}
--- return a string representation of a Lua value.
-- Cycles are detected, and the appearance of the result can be customized.
-- @param t the value to be represented
-- @param how (optional) a table or string containing customization info,
--    ignored unless t is a table; stays in effect until overridden
--    how.sep: separator appearing after scalar item
--    how.tsep: separator appearing after table-valued item
--    how.wrap: length of lines to aim for
--    how.indent: indentation string (implies one item to a line)
--    If `how` is a string, it is used as indentation string.
-- @return a string
function ml.tstring (t,how)
    local tostring = metafield(t,__tostring)
    if tostring then return tostring(t) end
    if type(t) == 'table' then
        local buff = {tables={[t]=true}}
        if type(how) == 'string' then how = {indent = how} end
        if how then default_how=how else how=default_how end
        pcall(tbuff,t,0,buff,how.indent,how.sep or ',',how.tsep or ';',how.wrap)
        return concat(buff)
    else
        return quote(t)
    end
end

--- collect a series of values from an iterator.
-- @param ... iterator
-- @return array-like table
-- @usage collect(pairs(t)) gives an unsorted version of keylist(t)
function ml.collect (...)
    local res = {}
    for k in ... do append(res,k) end
    return res
end

--- extend a table by mapping a function over another table.
-- @param dest destination table
-- @param j start index in destination
-- @param nilv default value to use if function returns `nil`
-- @param f the function
-- @param t source table
-- @param ... extra arguments to function
local function mapextend (dest,j,nilv,f,t,...)
    f = function_arg(f)
    if j == -1 then j = #dest + 1 end
    for i = 1,#t do
        local val = f(t[i],...)
        val = val~=nil and val or nilv
        if val ~= nil then
            dest[j] = val
            j = j + 1
        end
    end
    return dest
end

--- map a function over an array.
-- The output must always be the same length as the input, so
-- any `nil` values are mapped to `false`.
-- @param f a function of one or more arguments
-- @param t the array
-- @param ... any extra arguments to the function
-- @return a new array with elements `f(t[i],...)`
function ml.imap(f,t,...)
    return mapextend(new(t),1,false,f,t,...)
end

--- apply a function to each element of an array.
-- @param t the array
-- @param f a function of one or more arguments
-- @param ... any extra arguments to the function
-- @return the transformed array
function ml.apply (t,f,...)
    return mapextend(t,1,false,f,t,...)
end

--- map a function over values from two arrays.
-- Length of output is the size of the smallest array.
-- @param f a function of two or more arguments
-- @param t1 first array
-- @param t2 second array
-- @param ... any extra arguments to the function
-- @return a new array with elements `f(t1[i],t2[i],...)`
function ml.imap2(f,t1,t2,...)
    f = function_arg(f)
    local res = new(t1,t2)
    local n = math.min(#t1,#t2)
    for i = 1,n do
        res[i] = f(t1[i],t2[i],...) or false
    end
    return res
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
-- @usage ifind({{1,2},{4,5}},'X[1]==Y',4) is {4,5}
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

local function upper (t,i2)
    if not i2 or i2 > #t then
        return #t
    elseif i2 < 0 then
        return #t + i2 + 1
    else
        return i2
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
-- Like `string.sub`, the end index may be negative.
-- @param t the array
-- @param i1 the start index, default 1
-- @param i2 the end index, default #t (like `string.sub`)
-- @return a new array containing `t[i]` in the specified range
function ml.sub(t,i1,i2)
    i1, i2 = i1 or 1, upper(t,i2)
    return copy_range(new(t),1,t,i1,i2)
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

--- copy values from `src` into `dest` starting at `index`.
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
-- @{readme.md.Extracting_and_Mapping}
-- @param t the array to be extended
-- @param ... the other arrays
-- @return the extended array
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
-- @usage indexby({one=1,two=2},{'one','three'}) is {1}
-- @usage indexby({10,20,30,40},{2,4}) is {20,40}
function ml.indexby(t,keys)
    local res = new(t)
    for _,v in pairs(keys) do
        if t[v] ~= nil then
            append(res,t[v])
        end
    end
    return res
end

--- create an array of numbers from start to end.
-- With one argument it goes `1..x1`. `d` may be a
-- floating-point fraction
-- @param x1 start value
-- @param x2 end value
-- @param d increment (default 1)
-- @return array of numbers
-- @usage range(2,10) is {2,3,4,5,6,7,8,9,10}
-- @usage range(5) is {1,2,3,4,5}
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

-- Bring modules or tables into 't`.
-- If `lib` is a string, then it becomes the result of `require`
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

--- add the key/value pairs of arrays to the first array.
-- For sets, this is their union. For the same keys,
-- the values from the first table will be overwritten.
-- @param t table to be updated
-- @param ... tables containg more pairs to be added
-- @return the updated table
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
-- @usage makemap({'power','glory'},{20,30}) is {power=20,glory=30}
function ml.makemap(t,tv)
    local res = {}
    for i = 1,#t do
        res[t[i]] = tv and tv[i] or i
    end
    return res
end

--- make a bag (multiset) from a table; can be used as a set
-- @param t a table
-- @return a table of the number of times each key appears as a value in t
-- @usage bag{3,5,6,5,7,3,5} is {[7]=1,[5]=3,[3]=2,[6]=1}
function ml.bag(t)
    local res=new(t)
    for k,v in pairs(t) do res[v]=(res[v] or 0)+1 end
    return res
end

--- Invert keys and values in a table.
-- @param t a table
-- @return a table where keys and values swap places
-- @usage invert{'one','two'} is {one=1,two=2}
function ml.invert(t)
    local res=new(t)
    for k,v in pairs(t) do res[v]=k end
    return res
end

--- extract the keys of a table as an array.
-- @param t a table
-- @return an array of keys (sorted)
function ml.keylist(t)
    local keys = ml.collect(pairs(t))
    sort(keys)
    return keys
end

--- are all the keys of `other` in `t`?
-- @param t a set (i.e. a table whose keys are the set elements)
-- @param other a possible subset
-- @treturn bool
function ml.issubset(t,other)
    for k,v in pairs(other) do
        if t[k] == nil then return false end
    end
    return true
end

--- return the number of keys in this table, or members in this set.
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
    return ml.issubset(t,other) and ml.issubset(other,t)
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

--- defines how we convert something to a callable.
--
-- Currently, anything that matches @{callable} or is a _string lambda_.
-- These are expressions with any of the placeholders, `X`,`Y` or `Z`
-- corresponding to the first, second or third argument to the function.
--
-- This can be overriden by people
-- wishing to extend the idea of 'callable' in this library.
-- @param f a callable or a string lambda.
-- @return a function
-- @raise error if `f` is not callable in any way, or errors in string lambda.
-- @usage function_arg('X+Y')(1,2) == 3
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

--- 'memoize' a function (cache returned value for next call).
-- This is useful if you have a function which is relatively expensive,
-- but you don't know in advance what values will be required, so
-- building a table upfront is wasteful/impossible.
-- @param func a function of at least one argument
-- @return a function with at least one argument, which is used as the key.
function ml.memoize(func)
    return setmetatable({}, {
        __index = function(self, k, ...)
            local v = func(k,...)
            self[k] = v
            return v
        end,
        __call = function(self, k) return self[k] end
    })
end

--- make the module table callable; returns its first argument after
-- (if a table) setting its __index metafield to the module table
setmetatable(ml,{__call=
  function(ml,tbl) 
    if type(tbl)=='table' then setmetatable(tbl,{__index=ml}) end
    return tbl 
  end })

return ml
