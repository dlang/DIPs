# Importing Packages as if They Were Modules

| Section         | Value            |
|-----------------|------------------|
| DIP:            | 37               |
| Status:         | Implemented      |
| Author:         | Jonathan M Davis |

## Abstract

Provide a way to import a package. This is a variation on [DIP15](http://wiki.dlang.org/DIP15).

### Links

* [Enhancement Request in Bugzilla](http://d.puremagic.com/issues/show_bug.cgi?id=10022)
* [Pull Request with the necessary changes to the compiler](https://github.com/D-Programming-Language/dmd/pull/1961)
* [Implement DIP37 Importing Packages as if They Were Modules](https://github.com/D-Programming-Language/dmd/pull/2139)

## Description

If a package has a *package.d* file in it, then an import statement which
imports the package will import that file.

So, if there's a *foo/bar/package.d* and code imports *foo.bar*, then the
compiler will import *foo.bar.package*, and all aspects of importing will
function as they normally do except that instead of typing *foo.bar.package*,
*foo.bar* is typed by itself. And by using the file *package.d*, we completely
avoid the risk of breaking existing code as package is a keyword and therefore
is normally illegal as a module name.

If there is no *package.d* file in a package, then importing the package will
be an error as it has been (though the error message will probably indicate
something about *package.d*). Also, having a package and module with the same
name will result in an ambiguity error when you try and import them (e.g.
*foo/bar/package.d* and *foo/bar.d*).

### Rationale

Currently, it's impossible to split up a module into a package in place without
breaking code, and we'd like to be able to do that. There are also people who
want the ability import packages as a whole (as evidenced by the `all.d` idiom
which some people have been using).

### Examples

This will allow us to do something like take std/datetime.d and split into
something like

```
std/datetime/common.d
std/datetime/interval.d
std/datetime/package.d
std/datetime/timepoint.d
std/datetime/timezone.d
```

and `std/datetime/package.d` could then look something like

``` D
/++ Package documentation here +/
module std.datetime;`

public import std.datetime.common;
public import std.datetime.interval;
public import std.datetime.timepoint;
public import std.datetime.timezone;
```

Code which imports `std.datetime` would then be unaffected by the change, and
new code could choose either to import `std.datetime` or to directly import the
new sub-modules.

This is identical to what some projects have been doing with `all.d`, where
they have a `foo/bar/all.d` which publicly imports all of the `bar` package,
except that this provides additional syntactic sugar for it.

Another benefit is that this then gives us a way to document an entire package.
By putting a ddoc comment on the module declaration at the top of the package.d
file, a ddoc page for the package as a whole can be created.

Also, because `package.d` simply takes advantage of what the module and import
system can already do (the only major new thing being that importing the
package would then import its `package.d` file instead of getting an error),
this change is incredibly straightforward and allows us to have full control
over what gets imported when importing the package (e.g. only publicly
importing modules which are intended to be part of its public API and not
importing modules which are intended for internal use).

## Copyright & License

Copyright (c) 2016 by the D Language Foundation
Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)
