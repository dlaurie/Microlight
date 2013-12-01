Brief description
-----------------

Microlight is a small but useful library of functions written in Lua,
originally selected by Steve Donovan from his comprehensive Penlight 
set of utilities.

This version has been forked from Microlight 1.1 by Dirk Laurie.
Compatibility with the original Penlight routines is not aimed at, since
Microlight is for people that will not be using Penlight. The functions
`imap, imap2, class, Array, List` have been dropped. `imap, imap2, Array`
can be found together with some others in `ml-extra`. `List` is a simple
alias for `Array`, do it yourself if you need it. `class` has not been
included even there becasue Dirk does not understand it.

The routines included can be classified broadly as follows:

1. Information: `callable count indexof tstring`
2. Strings: `escape expand split`
3. Files: `exists readfile splitext splitpath writefile`
4. Mutating tables: `apply extend import removerange update`
5. Table creation: `collect ifilter ifind indexby invert keys makemap range sub`
6. Set manipulation: `bag equalkeys issubset`
7. Functions: `bind compose memoize throw`

Detailed documentation is available in the `doc` directory (made by running 
`ldoc .` in the module diectory). The program `ml-demosuite.lua`, which has 
been designed to take advantage of interactive help (`require"help"`) when 
available, produces the output `ml-demosuite.txt`.

Getting started
---------------

Fire up an interactive Lua session.
    Lua 5.2.2  Copyright (C) 1994-2013 Lua.org, PUC-Rio
    > ml = require'ml'
    > ml.import()
    > orig_tostring = tostring; tostring = tstring

You've just done two things you should not normally do, but for live
experimentation they are nice to have.

-   `ml.import()` loads all of Microlight into the global namespace so
    that you can omit the `ml.` you would otherwise need.
-   `tostring = tstring` causes Microlight's `tstring` to be used
    whenever anything needs to be converted to a string, in particular
    when `print` is called. The original `tostring` is saved as
    `orig_tostring`, and you can as always bypass `tostring` by calling
    `io.write` instead of `print`.

For example, strings are quoted, and tables are shown item by item.
A string that is suspected to be the result of a call to `tstring` will 
not be re-quoted.

    > io.write(orig_tostring(ml),'\n') -- this style is not gone forever
    table: 0x82c3740
    > =tstring(keys(ml),{wrap=72})
    {"ML_VERSION","apply","bag","bind","callable","collect","compose","count",
    "equalkeys","escape","exists","expand","extend","ifilter","ifind","imap",
    "imap2","import","indexby","indexof","invert","issubset","keys","makemap",
    "memoize","range","readfile","removerange","split","splitext","splitpath",
    "sub","throw","tstring","update","writefile"}

The optional second argument does customization: in this case, it puts
in linebreaks as soon as a line gets too long. The customization is
sticky, i.e. it stays in effect even for implicit calls to `tstring` via
`print` and `=`, until overridden by another explicit call.

The routines are fully described in `ml-demosuite.txt`, but let's
have a few highlights.

Function arguments
------------------

Any Microlight function that expects a function parameter will actually
accept any of:

- a function
- any value that has a metafield `__call`.
- a string lambda, i.e. a valid Lua expression involving the names
  `X,Y,Z`, for which the first three arguments will be substituted.

For example:

    > =ifilter(range(2,48),"X%2~=0 and X%3~=0 and X%5~=0")
    {7,11,13,17,19,23,29,31,37,41,43,47}

This demonstrates three Microlight features:

- The `range` function to give integers in arithmetic progression.
- Arithmetic expression functions, also known as "string lambdas". 
- The `ifilter` function to select array elements.

However, if a Microlight function expects an iterator, string lambdas
are not allowed. You must then stick to the rules of the generic `for`.

There is some support for functional programming.

    > log2 = bind(math.log,nil,2)
    > =log2(1024)
    10

Array arguments
---------------

An array is a table `t` in which only the values corresponding to the 
keys being from `1` to `#t` are operated on. As usual, if you do not 
provide your own `__len` metamethod, you have in effect signed an 
agreement that you have read and understood the description of the 
`#` operator as given in the Lua reference manual.

Functions that have an array argument and return an array replicate 
a metatable if available.

    > mt = {__index={type=function() return 'object' end}}
    > t = setmetatable({1,2,3},mt)
    > u = sub(t,2)
    > =u:type()
    object

Sets
----

A set is a table `s` in which only the keys matter. Even the value
`false` does not disqualify the key. A bag is a set in which the
values indicate the number of available identical copies. Bags can
be used as sets, but only come into their own in `ml-extra`.

    > s=bag(split"the quick brown fox jumps over the lazy dog")
    > =s
    {lazy=1,dog=1,jumps=1,the=2,brown=1,fox=1,quick=1,over=1}
    > =issubset(s,{the=falsee,lazy=0,fox="hunted"})
    true

String functions
----------------

Microlight has a `split` function, which differs from `string.gmatch`
in two ways:

1. It returns a table of pieces, not an iterator.
2. It operates on the separators, not the matching strings.

There are two common situations where you might prefer `split`:
whitespace-separated words (the default case) and CSV lists, when
an explicit separator pattern is provided as second argument.

In the first case we do not want an empty space between a separator
and one of the ends of the string to count as a piece; in the second 
we do. 

    >  = split(' hello dolly ')
    {"hello","dolly"}
    > = split(',one,two,,',',')
    {",","one","two","",""}


[Splitting](http://lua-users.org/wiki/SplitJoin) is a subtle topic.
Microlight does not attempt to cover all conceivable scenarios, but
applies heuristics which give the correct behaviour in the two common
cases.

- If the empty string matches the separator, all of the first argument 
is returned as the only piece.
- If the pattern ends with a magic `+` (i.e. not `%+`), only pieces of 
length greater than 0 are inserted into the table.
- Otherwise length-zero strings are allowed and the endpoints count as 
delimiters.


