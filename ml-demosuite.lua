-- ml-demosuite.lua
-- Dirk Laurie (c) 2013; MIT license like that of Lua 5.2
-- Caveat: this has been designed with Lua 5.2 in mind.  The present
--    version works on Lua 5.1 too but backwards compatibility must 
--    not be taken for granted in future versions.

---- these items are global so that `load` can see them

ml=require"ml"
ml.import()
function near(x,y) return math.abs(x-y)<0.002 end
function sum(...)
   io.write("calling sum!\n")
   local s=0
   for k=1,select('#',...) do s=s+select(k,...) end
   return s
end
function serialize(...)
   local result = {}
   for k=1,select('#',...) do 
      result[k] = ml.tstring(select(k,'...'),{raw=1}) 
   end
   return table.concat(result,'|')
end
loadstring = loadstring or load

----

local lua51 = _VERSION:match '5%.1$'
local gothelp, help = pcall(require,"ihelp")
if not gothelp then
   print [[
Recommendation: install interactive Lua help.
This will print a function's interactive documentation before
performing its demonstration.
]]
   help = function() return end
end

local gmatch = string.gmatch 
local test
local _G_tostring = tostring

function demo(routine)
   print ("\n----- "..routine.." -----")
   help(ml[routine])
   local test = tests[routine]
   if type(test)=='string' then test={test} end
   for _,code in ipairs(test) do
      if not code:match"return" then 
         print('= '..code)
         code = 'return '..code 
      else print('> '..code)
      end
      tostring = tstring
      print(loadstring(code)())
      tostring = _G_tostring 
   end
end

    tests = {
apply = 'apply({1,4,9},math.sqrt)';
bag = 'bag{3,5,6,5,7,3,5}';
bind = {"interior = bind(string.sub,nil,2,-2); return interior'<remark>'"};
callable = {'callable(near)', 'callable(ml)', 'callable(_G)'};
collect = 'collect(("26 Nov 2013"):gmatch"%d+")';
compose = 'g=compose(sqrt,"X+1"); return g(8)';
contains = {"contains(coroutine,{resume=1,yield=2})",
   "contains({5,6,7,8,9},{1,2,3,4}) -- remember the test is on keys!"};
count= 'count(ml)';
equalkeys = "equalkeys({create=1,resume=2,running=3,status=4,wrap=5,yield=6},coroutine)";
escape = "s='%w+'; return s:match('^'..escape(s)..'$') == s";
exists = 'exists"ml.lua"';
expand = "expand('$x $y ${z}',{x=1,y=2,z=3})";
extend = "extend({1,2,3},{4,5,6})";
ifilter = "ifilter({1,3,5,7},'X>=4')";
ifind = "ifind({{1,2},{4,5}},'X[1]==Y',4)";
import= "import(nil,math); return floor(pi)";
indexby = {"indexby({one=1,two=2},{'one','three'})",
   "indexby({10,20,30,40},{2,4})"};
indexof = 'indexof({1.9, 1.99, 1.999, 1.9999, 2},2,near)';
invert = "invert{A='a',B='b'}";
keys = "keys(ml)";
makemap = "makemap({'power','glory'},{20,30})";
memoize = {"f=memoize(sum,serialize); return f(1,2,3,4,5,6,7)",
   "f(1,2,3,4,5,6,7)"};
range = {"range(5)","range(2,10)"};
readfile= 'writefile("tmp.txt",tstring{1,2,3}); return readfile"tmp.txt"';
removerange = {'t={1,2,3,4,5,6}; removerange(t,2,5); return t'};
split = {'split" the quick brown fox "', 'split(",a,,b,c,,",",")'};
splitext = 'splitext"/usr/local/share/lua/5.2/ml.lua"';
splitpath = 'splitpath"/usr/local/share/lua/5.2/ml.lua"';
sub = "sub({1,2,3,4,5,6,7,8,9,10},-7)";
throw = {}; 
tstring = {'tstring({{1,2},{3,4}},{sep="; ",tsep=",  "})',
   'tstring({{1,2},{3,4}},{wrap=72})'};
update = {'update({A=1,B=2},{Z=26})'};
writefile= 'writefile("tmp.txt",tstring{1,2,3}); return readfile"tmp.txt"'
}

----------------------------------------------------------------------------

print ("Demo of Microlight "..ml.ML_VERSION.." under ".._VERSION)
if gothelp then print [[

In the documentation, Boolean constants are written `true` and `false`.
Without the backquotes, the words refer to Lua truth values, i.e. false
is `false` or `nil`, and true is anything else except not-a-number.]]
end 

print [[

In all Microlight functions that expect a function parameter (except 
those expecting an iterator), the actual parameter may be anything 
callable or a string containing an expression involving X,Y,Z.

The function `near` appearing in some examples tests whether two
numbers are equal to a tolerance of 0.002.]]

print "\nMicrolight information utilities"

for routine in gmatch("callable,count,indexof,tstring","%w+") do
   demo(routine)
end

print "\nMicrolight string utilities. The first parameter is a string."
for routine in gmatch("escape,expand,split","%w+") do
   demo(routine)
end

print "\nMicrolight file utilities. The first parameter is a filename."
for routine in gmatch("exists,readfile,splitext,splitpath,writefile","%w+") do
   demo(routine)
end

print "\nMicrolight mutating table utilities. The first parameter is a table."
for routine in gmatch("apply,extend,import,removerange,update","%w+") do
   demo(routine)
end

print "\nMicrolight table-creating utilities. The return value is a table."
for routine in gmatch(
"collect,ifilter,ifind,indexby,invert,keys,makemap,range,sub",
"%w+") do
   demo(routine)
end

print [[

Microlight set manipulation utilities. The first parameter is a table.
A set consists of the keys of a table.]]

for routine in gmatch("bag,contains,equalkeys","%w+") do
   demo(routine)
end
 
print [[

Microlight function utilities. The first parameter is anything callable,
or an expression involving X,Y,Z, taken to be the first three parameters 
supplied later. ]]

for routine in gmatch("bind,compose,memoize,throw","%w+") do
   demo(routine) 
end
 
pcall(require,"ml-extra")

if ml.class then
   print "\nMicrolight class creation utilities"
   help(ml.class)
end

if ml.Array then
   print "\nMicrolight Array type"
   help(ml.Array)
   print[[

   x = ml.Array{1,2,3}
   y = ml.Array{4,5,6}
   z = y..x
   print(z,z:sorted())
]]
   x = ml.Array{1,2,3}
   y = ml.Array{4,5,6}
   z = y..x
   print(z,z:sorted())
end 

