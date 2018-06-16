# Named parameters

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | Richard Andrew Cattermole <firstname@lastname.co.nz>            |
| Implementation: | (links to implementation PR if any)                             |
| Status:         | Will be set by the DIP manager (e.g. "Approved" or "Rejected")  |

## Abstract

Named arguments (otherwise known as unordered arguments) adds a new method to pass data to functions and initialize templates. It encourages passing of publically accesible information via named while discouraging passing internal information via it.
Seperation of named versus unnamed is done for seperation of concerns; implementation versus API.

### Reference

There have been many conversations on D's NewsGroup attempting to suggest named arguments. For example [1](https://forum.dlang.org/post/khcalesvxwdaqnzaqotb@forum.dlang.org) and [2](https://forum.dlang.org/post/n8024o$dlj$1@digitalmars.com).

Multiple library solutions have been attempted [1](https://forum.dlang.org/post/awjuoemsnmxbfgzhgkgx@forum.dlang.org) and [2](https://github.com/CyberShadow/ae/blob/master/utils/meta/args.d). Both of which do work but does not make the distinction between internal and public API arguments; which it cannot do without a lot more cruft.

A [DIP](https://wiki.dlang.org/DIP88) (88) has been drafted, but never PR'd. Further work was done by Neia Neutuladh, but it has not been made public. At the time of writing Yuxuan Shui has a draft [DIP](https://github.com/yshui/DIPs/blob/master/DIPs/DIP1xxx-YS.md) in the review queue that is much more limited.

## Contents
* [Rationale](#rationale)
* [Description](#description)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Reviews](#reviews)

## Rationale

Named arguments are a fairly popular language feature from dynamic languages which has been very highly requested on D's NewsGroup. It is available in Objective-C so it is also compatibility issue not just an enhancement for D.

Unlike other languages however, this DIP does not aid in having all or even most arguments to be in _any_ order. The majority of arguments should remain ordered; this aids in readability and tooling. This removes a lot of potential problems which has been discussed and highly disliked within the D community about this concept.

As a D only feature, it gives us more ways to describe interfaces in their usage but not what happens inside them. The decision to focus upon publically accessible aspects of an API using named arguments instead of their internals is to help make code clearer with preference of decreasing the number of template initations. A great example of this is ``max(a : 1, b : 3)`` is not more readable or understandable than ``max(1, 3)``. But ``MyInputRange!(Foo).Type`` is better than ``ElementType!(MyInputRange!(Foo))`` and describes that much more clearer that the type of the input range is clearly owned by ``MyInputRange`` not the mythical ``ElementType`` template.

## Description

This DIP adds a second kind of argument/parameter, named. Alternative names is ordered and unordered arguments. Ordered arguments is the current arrangement requiring that all argument be passed in the same order of the parameters defining them. But with unordered arguments, they can appear in any order or if specified to be optional at the parameter side, not at all.

Named arguments are not affected by the passing of unnamed arguments. It does not matter where they go. So ``func(1, 2, o:true)`` is the same as ``func(1, o:true, 2)`` or ``func(o:true, 1, 2)``.

At the template side, if it is not a function and the template parameters does not have any unnamed parameters you may omit the curved brackets. So ``struct Foo(<T>) {}`` is equivalent to ``struct Foo<T> {}``.

If a named argument does not have a default value, it must be assigned or it is an error.
Named arguments can be in any order, they cannot have values depending on each other, default or otherwise.

To get a tuple of all named parameter names for (template instances or non-templated) functions, the trait ``__traits(getNamedParameters, T)`` can be used.

Named arguments may be specified on structs, classes, unions, template blocks and mixin templates. As well as functions and methods. When used with structs, classes, unions or template blocks named arguments may be accessed by their identifier. E.g.

```D
struct MyWorld<string Name> {
}

static assert(MyWorld!(Name:"Earth").Name) == "Earth");

void hello(<string message="World!">) {
	import std.stdio;
	writeln("Hello ", message);
}

void main() {
	// Will print "Hello Walter"
	hello(message : "Walter");
}
```

This feature is quite convenient because it means that variadic template arguments and variadic function arguments can come before named arguments. So:

```D
void func(T..., <alias FreeFunc>)(T t, <bool shouldFree=false>) {
}

void abc() {
	func!(FreeFunc : someRandomFunc)(1, 2, 3, shouldFree : true);
}
```

Is in fact valid.

For convenience at the definition side, you may combine named arguments together or keep them seperate, it is up to you.

```D
struct TheWorld<string Name, Type> {
}

alias YourWorld = TheWorld!(Name:"Here", Type:size_t);

void goodies(T, <T t>, <U:class=Object>)(string text) {
}

alias myGoodies = goodies!(int, t:8);
alias myOtherGoodies = goodies!(U:Exception, string, t : "hi!");
```

Any symbol that has named arguments, the named arguments are not considered for overload resolution. This puts a requirement on the unnamed arguments being unique and easily resolved.

### Grammar changes

```diff
TemplateParameters:
+    < NamedTemplateParameterList|opt >

TemplateParameter:
+    < NamedTemplateParameterList|opt >

+ NamedTemplateParameterList:
+    NamedTemplateParameter
+    NamedTemplateParameter ,
+    NamedTemplateParameter , NamedTemplateParameterList

+ NamedTemplateParameter:
+    Identifier = TemplateParameter
+    alias Identifier

TemplateArgument:
+   NamedTemplateArgumentList

+ NamedTemplateArgumentList:
+     NamedTemplateArgument
+     NamedTemplateArgument ,
+     NamedTemplateArgument , NamedTemplateArgumentList

+ NamedTemplateArgument:
+     Identifier : TemplateArgument

Parameter:
+   < NamedParameterList|opt >

+ NamedParameterList:
+    Parameter
+    Parameter ,
+    Parameter , NamedParameterList

+ NamedArgument:
+    Identifier : ConditionalExpression

TraitsKeyword:
+    getNamedParameters
```

### Use cases

#### Ranges

Removes the usage of ``ElementType`` and initiations of it by making the type used a member.

```D
struct Adder<SourceType, Type=SourceType.Type> {
    SourceType source;
    Type toAdd;

    @property {
        Type front() {
            return source.front() + toAdd;
        }
        
        bool empty() {
            return source.empty();
        }
    }
    
    void popFront() {
        source.popFront();
    }
}

auto adder(Source)(Source source, Source.Type toAdd) {
    return Adder!(SourceType: Source, Type: Source.Type)(source, toAdd);
}
```

#### Logging

Overridable but no longer interacts poorly with other arguments. Requiring no smelly work arounds.

```D
void log(T...)(T args, <string moduleName = __MODULE__, uint lineNumber = __LINE__>) {
    writeln(moduleName, "[", lineNumber, "] ", args);
}
```

## Future proposals

This DIP can be expanded upon to catch more use cases (but would make a much more complex initial one).
Here are some ideas for future DIP's.

### Restrictions

This DIP has a very loose definition of the parameters/arguments. In other languages they have ordering and other restrictions in place.
While this is a point of contention, this DIP will not address them directly. Instead adding of artificial restrictions should be left to a future DIP after the community has had some experience in using them.

### API Alias parameters

Alias attribute to renamed parameters (templates and function ones).

```D
void func(int foo, string bar)
alias(foo=[food, foo2], bar=offset) {}
```

Multiple attributes could be applied but you must pick one set of identifiers used inside a single attribute e.g. either "foo", "food" or "foo2" and either "bar" or "offset" at call/initaition site.

Identifiers should note overlap between attributes so:

```D
void func(int foo, string bar)
alias(foo=baz, bar=har)
alias(foo=val, bar=baz)
```

Would not be valid. So that any combination can be used freely within its scope.

## Breaking Changes and Deprecations

No breaking changes are expected.
Angle brackets are not a valid start or end of template parameter or function argument.


## Copyright & License

Copyright (c) 2018 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews

The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.