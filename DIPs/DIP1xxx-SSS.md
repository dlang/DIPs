# Hooking D's struct move semantics

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | Shachar Shemesh                                                 |
| Implementation: | (links to implementation PR if any)                             |
| Status:         | Draft                                                           |

## Abstract

Allow implementation of structs with external/internal references maintained by the struct itself.
Such references are prohibited by the current language definition, as D might choose to move a struct
around in memory by a simple bit-copy operation.

The purpose of this DIP is to maintain this ability, while also allowing internal and external references
to the instance. The means by which this is achieved is by allowing the struct to define a postblit like
callback, called `opPostMove`, that will get called and allow the struct to update the references invalidated
by the move.

### Reference

* [Issue #17448](https://issues.dlang.org/show_bug.cgi?id=17448): Problems arising from lack of
such support, as well as discussions on why it is needed.
* [C++'s solution to the same problem](http://en.cppreference.com/w/cpp/language/move_constructor)

## Contents
* [Rationale](#rationale)
* [Terminology](#terminology)
* [Description](#description)
  * [Outline](#outline)
  * [`__move_post_blt`'s implementation](#move_post_blts-implementation)
  * [`opPostMove`](#opPostMove)
  * [Code emitted by the compiler on move](#code-emitted-by-the-compiler-on-move)
  * [`opPostMove` Decoration Considerations](#opmove-decoration-considerations)
* [Performance Considerations](#performance-considerations)
* [Effect on Phobos](#effect-on-phobos)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Reviews](#reviews)

## Rationale

D compilers are allowed to move (instead of destroying) stack allocated struct objects that reached their end of scope. While this
may be a very useful feature, it does mean certain programming patterns become more difficult.

The limitation is usually phrased as "D structs may not contain pointers to themselves". While that limitation is
correct, it is not the only one. For example, D structs may also not use the constructor/destructor to register themselves
with a global registry that keeps track of all instances in the system (e.g. - by a linked list). This also
severely limits the ability to store delegates that reference the struct from outside the struct.

While not all of those scenarios will be easily solved by this DIP, without it the programmer is left with *zero* tools to
tackle the problem, even if she was lucky enough to spot it before it caused memory corruption.

## Terminology

Whenever an upper case vowel is used (MAY, SHOULD, MUST NOT), their meaning should be taken as defined in
[RFC 2119](https://tools.ietf.org/html/rfc2119).

## Description

### Outline

The DIP suggests the following changes:

1. A new function, called `__move_post_blt`, will be added to druntime.
1. The user MAY create a member function, called `opPostMove`, in structs. If created, that function MUST follow a certain interface.
1. When deciding to move a struct, the compiler will emit a call to the struct's `__move_post_blt` after blitting the struct and
before releasing the old struct's memory. `__move_post_blt` will receive the old and new struct's pointers.

### `__move_post_blt`'s implementation

`__move_post_blt` SHOULD be defined in a manner that is compatible with the following code:

```D
void __move_post_blt(S)(ref S newLocation, ref S oldLocation) nothrow if( is(S==struct) ) {
    foreach(memberName; __traits(allMembers, S)) {
        static if( is( typeof(__traits(getMember, S, memberName))==struct ) ) {
            mixin("__move_post_blt( newLocation." ~ memberName ~ ", oldLocation." ~ memberName ~ " );");
        }
    }

    static if( __traits(hasMember, S, "opPostMove") ) {
        newLocation.opPostMove(oldLocation);
    }
}
```

Please note that `S` might also be shared, immutable or const.

### `opPostMove`

As should be obvious from the definition of `__move_post_blt`, `opPostMove`, if defined, MUST be a `nothrow` function
that updates the external/internal references after they have already been copied. Implementors SHOULD also make it `@nogc` and
either `@safe` or `@trusted`.

Implementors MAY define `opPostMove` for const and/or immutable instances. If they do, the implementation code MAY safely modify
the data in the destination location for the object, as that has no pointers pointing at it. Such modifications will require a
cast.

Whether it is safe to modify external data pointed to by pointers stored in the struct (such as the case for an intrusive linked
list), or the data in the source address of the move, heavily depends on the specifics of the implementation. The user
documentation for `opPostMove` MUST explain what is guaranteed to be safe and what is not.

Implementors may also choose to not define const/immutable versions of `opPostMove`. This will results in a compile-time error should
the compiler try to move such a struct.

The documentation for `opPostMove` MUST also emphasize that while manipulating the memory at the `opPostMove` source location is allowed,
the memory will be effectively freed with no destruction immediately after the function's return. Implementors SHOULD be
encouraged to define the argument to `opPostMove` to be `const ref` to gain some compiler protection against accidental manipulation.
This does not harm the implementor's access to the data, as she already has a copy at the destination location.

### Code emitted by the compiler on move

When moving a struct, the compiler should call `__move_post_blt` on the struct, giving it both new and old instances.

### `opPostMove` Decoration Considerations

Ideally, `opPostMove` should be `@nogc`, `nothrow` and either `@safe` or `@trusted`. If that doesn't happen, trying to compile
code that moves a struct from context that is `nothrow`, `@nogc` or `@safe` would result in a compilation error.

We could force these by decorating `__move_post_blt` itself as `nothrow @nogc @safe`, thus not allowing `opPostMove` to be defined
any other way (we cannot otherwise force `opPostMove` to be defined any specific way, as it is being defined by the user). I chose
not to do so because the user might opt not to use, e.g., `@safe` anywhere in her program. It would, therefor, not make sense
to force her to use it in `opPostMove`. Due to attribute inference on template functions, if all member `opPostMove`s are, e.g., `@nogc`,
D will automatically define `__move_post_blt` as `@nogc`.

We do force `nothrow` on `opPostMove`, because throwing would mean a change in the program flow from a place that does not seem to
run code, which might prove too confusing.

## Performance Considerations

Structs that do not define `opPostMove`, and that none of their members define `opPostMove`, will have their `__move_post_blt`
implementation be just a function calling a bunch of empty functions recursively. Hopefully, the compiler will be able to inline
this series of calls into oblivion, meaning the run time cost of this feature for structs that do not use it will be zero.

If the compiler implementers fear that inlining will not nullify these calls where not applicable, they MAY manually eliminate
no-op sub-trees. This may be done as simply as adding, at the beginning of `__move_post_blt`:

```D
static if( !hasElaborateMove!S )
    return;
```

Such an addition incures some compile-time cost in the case that an inner member does have `opPostMove` defined, as it performs
multiple scans of the subtrees during the recursive descent. It does, however, guarantee zero run time cost.

Structs that do define `opPostMove` manage their own costs.

## Effect on Phobos

For the most part, no effect should happen on Phobos. Even if `opPostMove` is defines for a struct, the compiler's handling should
make sure Phobos is not affected.

The exceptions are:

* The `move` family of functions defined in `std.algorithm` will have to be updated with a call to `__move_post_blt`.
* The `swap` functions may, also, need to be similarly updated (depending on precise implementation).
* A new template SHOULD be added to `std.traits`: `hasElaborateMove`, that returns whether a struct or any of its members have
an `opPostMove` defined.

## Breaking Changes and Deprecations

There are no breaking changes introduced by the proposal itself, as structs have to explicitly opt-in to this change to see
any change in behavior at all.

This proposal does add two functions with special meaning. One of them is in the reserved space, so should
not break anything. If an existing struct has a function called `opPostMove`, however, switching to an implementation that
supports this DIP will break the old code.

Since it is generally understood by D programmers that `op*` functions are for operator overloads, this problem should not
be common. We can further reduce this problem by calling the function `opPostMove`.

## Copyright & License

Copyright (c) 2018 by Weka.IO ltd.

Licensed under [This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
](http://creativecommons.org/licenses/by-sa/4.0/)

## Review

The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
