Brief description
-----------------

Microlight is a small but useful library of Lua functions originally
selected by Steve Donovan from his comprehensive Penlight set of
uitilities.

This version has been forked from Microlight 1.1 by Dirk Laurie.

This `readme.md` is much less exhaustive than its predecessor, since
`ml-demosuite.txt` supplies most of what is needed. You can still
make official-looking documentation by `ldoc ml.lua`.

Getting started
---------------

Fire up an interactive Lua session.

    Lua 5.2.2  Copyright (C) 1994-2013 Lua.org, PUC-Rio
    > ml = require'ml'
    > ml.import()
    > orig_tostring = tostring; tostring = tstring

You've just done two things you should not normally do, but for live
experimentation they are nice to have.

- `ml.import()` loads all of Microlight into the global namespace so
that you can omit the `ml.` you would otherwise need.
- `tostring = tstring` causes Microlight's `tstring` to be used
whenever anything needs to be converted to a string, in particular
when results are printed out. The original `tostring` is saved; you
don't want it gone forever.

    > =keylist(ml)
    {"ML_VERSION","apply","bag","bind","callable","collect","compose","count",
    "equalkeys","escape","exists","expand","extend","ifilter","ifind","imap",
    "imap2","import","indexby","indexof","invert","issubset","keylist","makemap",
    "memoize","range","readfile","removerange","split","splitext","splitpath",
    "sub","throw","tstring","update","writefile"}

These are all in described in `ml-demosuite.txt`, but let's have a few highlights.

    > =ifilter(range(2,48),"X%2~=0 and X%3~=0 and X%5~=0")
    {7,11,13,17,19,23,29,31,37,41,43,47}

This demonstrates three Microlight features:

- The `range` function to give integers in arithmetic progression.
- Arithmetic expression functions, also known as "string lambdas". You are
  allowed up to three implied parameters: `X,Y,Z`. Any Microlight function
  that expects a function parameter also accepts a string lambda.
- The `ifilter` function to select array elements.

An array is a table `t` in which only the values matter, the keys being taken
as `1` to `#t`. As usual, if you do not provide your own `__len` metamethod,
you have in effect signed an agreement that you have read and understand the 
description of the `#` operator as given in the Lua reference manual. 

A set, on the other hand, is a table `s` in which only the keys matter.

    > s=bag(split"the quick brown fox jumps over the lazy dog")
    {lazy=1,dog=1,jumps=1,the=2,brown=1,fox=1,quick=1,over=1}
    > =issubset(s,{the=true,lazy=0,fox="hunted"})
    true

The module table is callable. When called, it sets itself as the `__index`
metafield of its first argument. This allows routines whose first parameter 
is a table to be called in an object-oriented way.

    > A=ml{1,2,3,4}
    > =A:extend{5,6,7,8}
    {1,2,3,4,5,6,7,8}

There is some support for functional programming.

    > log2 = bind(math.log,nil,2)
    > =log2(1024)
    10

That's the appetizer. Now go and read `ml-demosuite.txt`.
