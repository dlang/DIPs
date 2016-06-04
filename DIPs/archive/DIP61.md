# Add namespace scopes to support referencing external C++ symbols in C++ namespaces

| Section         | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | 61                                                              |
| Status:         | Implemented                                                     |
| Author:         | Walter Bright                                                   |
| Implementation: | <https://github.com/D-Programming-Language/dmd/pull/3517>       |

## Abstract

Add ability to reference from D C++ symbols that are in C++ namespaces.

### Links

* [NG discussion that triggered the DIP](http://forum.dlang.org/post/lhi1lt$269h$1@digitalmars.com)
* [NG announcement and discussion](http://forum.dlang.org/post/ljfue4$11dk$1@digitalmars.com)
* [more NG discussion](http://forum.dlang.org/post/ljjnaa$187r$1@digitalmars.com)

## Description

A namespace scope creates a scope with a name, and inside that scope all
declarations become part of the namespace scope. This involves the addition of
a small amount of new grammar. Compiler changes are expected to be minor. The
change is additive and should not impact any existing code.

The namespace is identified by an identifier following the C++ in extern(C++).
Nested namespaces can be specified using . to separate them.

### Rationale

Best practices in C++ code increasingly means putting functions and
declarations in namespaces. Currently, there is no support in D to call C++
functions in namespaces. The primary issue is that the name mangling doesn't
match. Need a simple and straightforward method of indicating namespaces.

### Examples

``` d
extern (C++, MyNamespace) { int foo(); }
```

creates a namespace named "MyNamespace". As is currently the case,

``` d
extern (C++) { int foo(); }
```

does not create a namespace.

The following declarations are all equivalent:

``` d
extern (C++) { extern (C++, N) { extern (C++, M) { int foo(); }}}
extern (C++, N.M) { int foo(); }
extern (C++, N) { extern (C++) { extern (C++, M) { int foo(); }}}
```

Namespaces can be nested. Declarations in the namespace can be accessed without
qualification in the enclosing scope if there is no ambiguity. Ambiguity issues
can be resolved by adding the namespace qualifier:

``` d
extern (C++, N) { int foo(); int bar(); }
extern (C++, M) { long foo(); }

bar(); // ok
foo(); // error, ambiguous
N.foo(); // ok
N.bar(); // ok
```

Name lookup rules are the same as for mixin templates.

Unlike C++, namespaces in D will be 'closed' meaning that new declarations
cannot be inserted into a namespace after the closing }. C++ Argument Dependent
Lookup (aka "Koenig Lookup") will not be supported.

### Grammar Change

<pre>
LinkageAttribute:
    <b>extern</b> ( <i>identifier</i> )
    <b>extern</b> ( <i>identifier</i>++ )
    <b>extern</b> ( <i>identifier</i>++ , <i>identifier</i> ( . <i>identifier</i> )* )
</pre>

## Copyright & License

Copyright (c) 2016 by the D Language Foundation
Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)
