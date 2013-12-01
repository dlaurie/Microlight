-------------------
-- Microlight Extra
--
-- Augments Microlight by modules that did not make the cut, 
-- but which some people might like to have
--
-- Steve Donovan, 2012; Dirk Laurie, 2013; License MIT
-- @module ml-extra

local ml=require"ml"

ml.import(ml,debug.getregistry().microlight_extra)

local new=ml.new

--- map a function over a array.
-- The output must always be the same length as the input, so
-- any `nil` values are mapped to `false`.
-- @param f a function of one or more arguments
-- @param t the array
-- @param ... any extra arguments to the function
-- @return a array with elements `f(t[i],...)`
function ml.imap(f,t,...)
    f = ml.function_arg(f)
    local res = new(t)
    for i = 1,#t do
        res[i] = f(t[i],...) or false
    end
    return res
end

--- map a function over two arrays.
-- The output must always be the same length as the input, so
-- any `nil` values are mapped to `false`.
-- @param f a function of two or more arguments
-- @param t1 first array
-- @param t2 second array
-- @param ... any extra arguments to the function
-- @return a array with elements `f(t1[i],t2[i],...)`
function ml.imap2(f,t1,t2,...)
    f = ml.function_arg(f)
    local res = new(t1,t2)
    local n = math.min(#t1,#t2)
    for i = 1,n do
        res[i] = f(t1[i],t2[i],...) or false
    end
    return res
end

-----------------------
-- a simple Array class
-- @table Array

-- generic object initializer
local init = function(class,object)
   return setmetatable(object or {},class)    
end
   
local Array = {
    init = init,
    -- straight from the table library
    concat=table.concat,insert=table.insert,remove=table.remove,
    append=table.insert,
    -- straight from Microlight
    filter=ml.ifilter, sub=ml.sub, indexby=ml.indexby, apply=ml.apply,
    range = ml.range, indexof=ml.indexof, find=ml.ifind, extend=ml.extend,
    __tostring = ml.tstring
}

-- specific object finalizer
setmetatable(Array,{__call=Array.init}) 
Array.__index=Array

function Array:sort(f) table.sort(self,f); return self end
function Array:sorted(f) return extend(new(self),self):sort(f) end

function Array.__eq(l1,l2)
    if #l1 ~= #l2 then return false end
    for i = 1,#l1 do
        if l1[i] ~= l2[i] then return false end
    end
    return true
end

function Array.__concat (l1,l2)
    return ml.extend(new(l1,l2),l1,l2)
end

ml.Array = Array

return ml
