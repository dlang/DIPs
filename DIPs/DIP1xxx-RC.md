# Named parameters

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | Richard Andrew Cattermole <firstname@lastname.co.nz>            |
| Implementation: | (links to implementation PR if any)                             |
| Status:         | Draft                                                           |

## Abstract

This DIP adds a new type of parameter to supplement function and template parameters. It encourages arguments being passed of publicly accessible information via named while discouraging passing internal information.
Separation of named versus unnamed is done for separation of concerns; implementation versus API, or what you should care about.

### Reference

There have been many conversations on D's NewsGroup attempting to promote named arguments. For example [1](https://forum.dlang.org/post/khcalesvxwdaqnzaqotb@forum.dlang.org), [2](https://forum.dlang.org/post/n8024o$dlj$1@digitalmars.com) and [3](https://forum.dlang.org/post/ikhjf7$1tga$2@digitalmars.com).

Multiple library solutions have been attempted [1](https://forum.dlang.org/post/awjuoemsnmxbfgzhgkgx@forum.dlang.org), [2](https://github.com/CyberShadow/ae/blob/master/utils/meta/args.d) and [3](https://forum.dlang.org/post/wtccivdgrgteyinqwtdr@forum.dlang.org). Each work for the author's purpose but they have been known to be less than desirable to work with e.g. [1](https://forum.dlang.org/post/xwghendahfjgceikuxvh@forum.dlang.org), [2](https://forum.dlang.org/post/ohrilhjbhddjkkqznlsn@forum.dlang.org) and [3](https://forum.dlang.org/post/n837bu$vam$5@digitalmars.com). However, because all of these are library based solutions they cannot solve the internal versus public API aspects that this DIP offers for named parameters.

The [DIP 88](https://wiki.dlang.org/DIP88) has been drafted, but was never PR'd. Further work has been done by Neia Neutuladh, but it has not been made public. At the time of writing Yuxuan Shui has a draft [DIP](https://github.com/yshui/DIPs/blob/master/DIPs/DIP1xxx-YS.md) in the review queue that is much more limited.

## Contents
* [Rationale](#rationale)
* [Description](#description)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)

## Rationale

Named parameters as a language feature are a fairly widespread language feature that has seen adoption in many popular languages as of 2019 according to the [TIOBE](https://www.tiobe.com/tiobe-index/) index. These languages include Ada, Kotlin, C#, Python, R, Ruby, and Scala [1](https://en.wikipedia.org/wiki/Named_parameter#Use_in_programming_languages). They have been used in system API's on OSX without the support of reordered arguments. These have been written in Objective-C which does offer named parameters but with the restriction of them having to be ordered [1](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ProgrammingWithObjectiveC/DefiningClasses/DefiningClasses.html#//apple_ref/doc/uid/TP40011210-CH3-SW5%7CiOS).

Of the many language behaviors that have been requested over the years has been named parameters [1](https://forum.dlang.org/post/eefptgwdqhsbxjqjjmpy@forum.dlang.org), [2](https://forum.dlang.org/post/mp9l9m$1cjt$2@digitalmars.com), but there have been caveats. Some people have disliked having arguments passed in any order [1](https://forum.dlang.org/post/bqyzgobnvrtrapcawguw@forum.dlang.org), [2](https://forum.dlang.org/post/m1h8if$223r$1@digitalmars.com). Unlike other languages, this DIP does not aid in having arguments in any order. The majority of arguments should remain ordered; this aids in readability and tooling.

## Description

This DIP proposes a second parameter type for use by ``extern(D)`` code in template and function arguments. This second type is a named variant that does not affect overload resolution or normal unnamed arguments to templates or functions. Instead, it provides an optional set of named parameters that can be passed and then retrieved from a type when used as a template argument.

When using a named parameter they must be passed in the same order relative to other named arguments but may exist in any order relative to unnamed arguments. For the prototype ``void func(int a, int b, <bool o=false>)`` the function calls ``func(1, 2, o:true)`` is the same as ``func(1, o:true, 2)`` or ``func(o:true, 1, 2)``.

In this proposal triangle brackets are used to donate the naming of parameters. They only exist on the declaration side and if there is only named parameters when used with a struct, class or union the curved brackets may be omitted. This has the intended side effect of encouraging types to be accessible outside of the type being initiated i.e. ``struct Foo<T> {}`` allows for ``T`` to be retrieved via ``Foo!(T: int).T``.

If a named parameter does not have a default value, it must have an argument giving it a value, making it non-optional. The values on named parameters at the declaration point must not refer to each other but may do so using existing rules against unnamed parameters.

To get a tuple of all named parameter names for (template instances or non-templated) functions, the trait ``__traits(getNamedParameters, T)`` can be used. For functions to be passed in, it must be the type of the function or delegate's type.

Named arguments may be specified on structs, classes, unions, template blocks, and mixin templates. As well as functions and methods. When used with structs, classes, unions or template blocks named arguments may be accessed by their identifier. I.e.

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

An issue of having named parameters not affected by overload resolution and ordering, in general, is how they behave with other language features. For template variadic and variadic function arguments in general, they are not affected by them. They are explicitly set breaking out of the run of values. This means that the following arguments if any will not be the prior one. In the example, this means that the following code is valid and you cannot continue passing integers after setting ``shouldFree``.

```D
func!(FreeFunc : someRandomFunc)(1, 2, 3, shouldFree : true);

void func(T..., <alias FreeFunc>)(T t, <bool shouldFree=false>) {
}
```

Conflicting definitions of functions is a major issue with overload resolution and named parameters can make this more problematic. By making named parameters not affect overload resolution it means you will get the same error as if ``c`` was not named in the following example. An example was courteously created by Adam D. Ruppe.

```D
void foo(int a, <int c = 0>) {}
void foo(int a, string b = "", <int c = 0>) {}
```

Named parameters may be combined into the same set of triangle brackets, or kept separate. It depends upon the stylistic choice or for the developer's convenience. The below example includes dropping of the curved brackets, ordering relative to other arguments and how they behave to non-named behavior.

```D
struct TheWorld<string Name, Type> {
}

alias YourWorld = TheWorld!(Name:"Here", Type:size_t);

void goodies(T, <U:class=Object>, <T t>)(string text) {
}

alias myGoodies = goodies!(int, t:8);
alias myOtherGoodies = goodies!(U:Exception, string, t : "hi!");
```

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

Removes the usage of ``ElementType`` and allow getting the ``Type`` without initializing any templates.

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

An example of a previously problematic (although compilable code) is a logging function that takes in the module name, function, and line number. This example already works today without unnamed arguments, it does make it clearer that you do not need to pass them and has very little to do with the user calling the function. Because it has been more explicitly stated that it should not be changed by default.

```D
void log(T...)(T args, <string moduleName = __MODULE__, string functionName = __FUNCTION__, uint lineNumber = __LINE__>) {
    writeln(moduleName, ":', functionName, "[", lineNumber, "] ", args);
}
```

## Future proposals

This DIP can be expanded upon to catch more use cases (but would make a much more complex initial one).
Here are some ideas for future DIP's.

### Restrictions

This DIP has a very loose definition of the parameters/arguments. In other languages, they have ordering and other restrictions in place.
While this is a point of contention, this DIP will not address them directly. Instead of adding artificial restrictions, it should be left to a future DIP after the community has had some experience in using them.

### API Alias parameters

Alias attribute to renamed parameters (templates and function ones).

```D
void func(int foo, string bar)
alias(foo=[food, foo2], bar=offset) {}
```

Multiple attributes could be applied but you must pick one set of identifiers used inside a single attribute e.g. either "foo", "food" or "foo2" and either "bar" or "offset" at call/initiation site.

Identifiers should note overlap between attributes so:

```D
void func(int foo, string bar)
alias(foo=baz, bar=har)
alias(foo=val, bar=baz)
```

Would not be valid. So that any combination can be used freely within its scope.

## Breaking Changes and Deprecations

No breaking changes are expected.
Angle brackets are not a valid start or end of a template parameter or function parameters.


## Copyright & License

Copyright (c) 2018 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews

The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
