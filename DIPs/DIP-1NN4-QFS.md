# Attributes for Higher-Order Functions

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | Quirin F. Schroll (@Bolpat)                                     |
| Implementation: | *none*                                                          |
| Status:         | Draft                                                           |

## Abstract

Functions that have function pointers or delegates as parameters cannot be integrated well in
`pure`, `nothrow`, `@safe`, and `@nogc` code.
This DIP proposes to adjust the constraints that the mentioned attributes impose.
It will only affect aforementioned functions with function pointers or delegates as `const` or `immutable` parameters.

The goal is to recognize more code as valid that factually behaves in accordance to the attributes.
<br/>
An example is this:
```D
struct Aggregate
{
    /// Executes sink(c) for every char c of the string representation in sequence.
    void toString(const void delegate(char) sink) @safe @nogc
    { ... }

    /// Returns the string representation in a GC allocated string.
    string toString() @safe
    {
        string result;
        void append(char c) { result ~= c; }
        toString(&append); // append is (inferred) @safe, but not @nogc
        return result;
    }
}
```
Notice how `sink` is not annotated `@safe` or `@nogc`, but it is declared `const`.
The key observations of this DIP are
that because it is `const`, any call like `sink('c')` can only execute the delegate passed to it
(`sink` cannot e.g. be reassigned),
and thus, the `toString()` function has full knowledge about whether the argument `&append`
that binds to `sink` is `@safe` and/or `@nogc`.

This DIP proposes that
* the first `toString` function is allowed to call `sink` even if not annotated `@safe` and/or `@nogc` — and
* that the call `toString(&append)` is only `@safe` and/or `@nogc` when *both*
  the called function `toString` and the argument `&append` are `@safe` and/or `@nogc`, respectively.

Calling `toString` with a function that may allocate is valid, but not a `@nogc` operation,
so `toString()` cannot be annotated `@nogc`. 
Calling `toString` with a `@system` sink is also valid, but the call will be considered `@system`
since the condition that the argument be `@safe` is violated.

## Contents

* [Terms and Definitions](#terms-and-definitions)
* [Rationale](#rationale)
* [Prior Work](#prior-work)
* [Description](#description)
  * [Attribute Checking inside Functionals](#attribute-checking-inside-functionals)
  * [Attribute Inference for Functional Templates](#attribute-inference-for-functional-templates)
  * [Attribute Checking inside Contexts](#attribute-checking-inside-contexts)
  * [Overloading, Mangling and Overriding](#overloading-mangling-and-overriding)
* [Examples](#examples)
  * [Lazy as a Lowering](#lazy-as-a-lowering)
  * [Lockstep Iteration](#lockstep-iteration)
  * [String Representations](#string-representations)
  * [Functions with Typesafe Variadic Lazy Parameters](#functions-with-typesafe-variadic-lazy-parameters)
  * [Mutable Parameters](#mutable-parameters)
  * [Const and Aliasing](#const-and-aliasing)
  * [Overriding Methods](#overriding-methods)
* [Alternatives](#alternatives)
  * [The Current State](#the-current-state)
  * [New Attributes](#new-attributes)
    * [Weak Clones](#weak-clones)
    * [Indicate not Calling a Parameter](#indicate-not-calling-a-parameter)
    * [Indicate Calling a Parameter](#indicate-calling-a-parameter)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)

## Terms and Definitions

The attributes `pure`, `nothrow`, `@safe`, and `@nogc` will be called *warrant attributes* in this DIP.
Notably absent are `@system` and `@trusted` as they do not warrant any compiler-side checks.
Also absent is `@live` because `@live` functions may call non-`@live` functions.

In this document, *FP/D (type)* will be an abbreviation for *function pointer (type) or delegate (type)*.
A type is *essentially an FP/D type* if it is
* a possibly qualified version of an FP/D type — or
* a possibly qualified pointer to essentially FP/D type — or
* a possibly qualified slice of essentially FP/D type — or
* a possibly qualified static array of essentially FP/D type — or
* a possibly qualified associative array with value type an essentially FP/D type.

> **Example**<br/>The type `void function(int) pure` is an FP/D type, and<br/>
> thus, `const(immutable(void function(int) pure)*)[]` is essentially an FP/D type.

An *essential call* of an eFP/D means an expression that is: In case of the eFP/D being
* a possibly qualified FP/D: A call (in the regular sense) to that object.
* a pointer `p` to an eFP/D: An essential call to `*p`.
* a slice or a static or associative array `arr` to an eFP/D: An essential call to `arr[i]` for a suitable index `i`.

> **Example**<br/>Let `fpps` be of the essential FP/D type in the previous example.
> An essential call to `fpps` is `(*(fpps[i]))(arg)`,
> where `i` is a `size_t` and `arg` an `int`.

This document makes use of the terms *parameter* and *argument* in a very precise manner
as the [D Language Specification](https://dlang.org/spec/function.html#param-storage) points out:
> When talking about function *parameters*, the parameter is what the function prototype defines,
> and the *argument* is the value that will *bind* to it.

A *higher-order function*, or *functional* for short, is anything that can be called
that takes one or more eFP/D types as arguments.

When a higher-order function is called, there are three notable entities to commonly refer to:
* The *context function,* or *context* for short, is the function that contains the call expresion.
  When the document refers to e.g. a `@safe` context, it is meant that the context function is annotated `@safe`.
* The *functional* is the higher-order function that is called.
* The *parameter functions* are the variables declared by the functional's parameter list.
* The *argument functions* or *callbacks* are the values plugged-in in the call expression.

Although not an entity in the above sense, the functional's *parameter types* will be commonly referred to as such.

> **Example**<br/>An illustration of the last terms given in this code snippet using telling identifiers.
> ```D
> alias ParameterType = void function();
> void functional(ParameterType parameterFunction)
> {
>     parameterFunction();
> }
>
> void context()
> {
>     alias callback = { };
>     functional(callback);
> }
> ```

A *warrant attribute context* is a context function
that is annotated with one or more of the warrant attributes defined above.

## Rationale

Higher-order functions are cumbersome to use in a warrant attribute context.
The execution of a context function may provably satisfy the conditions of a warrant attribute,
but is considered invalid because the formal conditions of the warrant attribute are not met.

Warrant attributes on a functional (or, in fact, on any function) and on a functional's parameter
mean very different things:
* On a function, they give rise to a *guarantee* the function makes that callers may rely upon.
* Only on a functional's parameter type, warrant attributes give rise to a *requirement*
  that the functional potentially *needs* to work properly.

As an example, consider a functional taking a `pure` delegate parameter.
In its internal logic, the functional might make use of memoization, or the fact that the parameter's return values are
[unique](https://dlang.org/spec/const3.html#implicit_qualifier_conversions).
In the case of uniqueness, omitting the requirement will result in invalid code,
since return values of impure functions generally cannot be assumed unique.
In the case of memoization, omitting the requirement will not result in a compile error,
but unexpected behavior, when used improperly.
In most cases, however, the requirement is merely there to match the functionals own guarantees.

In the current state of the language,
a functional cannot have strong guarantees and weak requirements at the same time.
Having strong guarantees means
that the functional provably behaves in accordance to warrant attributes,
meaning it can be annotated with them.
Having weak requirements means
that the functional does not need the guarantees of a warrant attribute on a parameter function
for its internal logic to be sound.
Most programmers opt against warrant attributes, i.e. for weak requirements,
and therefore needlessly weaken the guarantees.

The DIP solves this problem by always allowing calls to `const` and `immutable` parameters
when checking a functional for satisfying the conditions of a warrant attribute.

In a context where a functional is called, the type system has all the necessary information available
to determine if the execution of it will comply with the warrant attributes of the context.

This entails that not all calls to a functional annotated with a warrant attribute will result in call expressions
that is considered in compliance with that warrant attribute.
This is, however, less of a problem than it seems at first glance:
* Consider a `@system` or `@trusted` context calling a `@safe` functional with a `@system` argument.
  The context does not expect an execution satisfying the formal `@safe` constraints, therefore
  the fact that *the call* to the `@safe` annotated function is not formally considered `@safe` can be mostly ignored.
* Consider a `@safe` context calling a `@safe` functional with a `@system` argument.
  This is invalid, since a `@safe` functional makes guarantees for its internal logic.
  What the `@system` callback does, is among the responsibility of the context,
  and in a `@safe` context, calling a  `@system` function is invalid.

Especially in meta-programming, it might not be clear at all whether a callback's type has a warrant attribute or not.
For `@safe` and `@nogc`, this is mostly unproblematic, since these are only interesting from a safety or resource perspective,
but no program's logic depends on the guarantees these attributes make: A memory unsafe program is broken in itself and
GC allocating may at worst slow down a program unexpectedly due to the GC issuing a collection cycle.
[Author's note: I'm not completely sure. Please have a think whether these claims are really true.]

However, the attributes `pure` and `nothrow` are of interest, even in an impure context,
or a context where throwing exceptions is allowed.
* The return value of a `pure` operation can be unique, allowing for implicit casts that are not possible otherwise.
  In this case, if the call to the functional is impure due to calling it with an impure callback, the code is invalid.
  The context may expect a `pure` execution for memoization.
* A `nothrow` operation cannot fail recoverably.
  It fails irrecoverably or succeeds; in either case, no rollback operation is necessary.
  This fact may be used by the context.

Since outside of templates, the context must be annotated manually; this is unproblematic:
The call becomes invalid, and a compiler error is presented to the programmer.

With the changes proposed by this DIP, in templated contexts, except uniqueness,
it is necessary to manually ensure the execution is `pure` or `nothrow`.
Usually, this can be achieved by properly annotating the callback where it is defined:
Instead of `x => x + 1` one has to write `(x) pure nothrow => x + 1`.
This ensures that
even when the type of the object plugged in for `x` depends on factors outside the control of the context,
if `typeof(x)` happens to have an impure or possibly throwing `opBinary!"+"(int)`
that will lead to a compilation error.

In the opinion of the author,
a context should not rely on the annotations of the functional to check its requirements implicitly,
but instead make those requirements explicit in its statements.

The benefits and drawbacks of making this or another warrant attribute the default,
is discussed regularly on the forums.
This change is necessary to alleviate breakage by any sane way such a default would be implemented.

For example, consider making `@safe` the default.
Without this change, a suitable unannotated `void functional(void function() f)` would either become
* `void functional(void function()       f) @safe` — or
* `void functional(void function() @safe f) @safe`.

(Here, *suitable* means that `functional` contains `@safe` operations only apart from the call to `f`.
One way to test that is annotating the parameter and the functional.)

The first option can be excluded immediately:
When `functional` calls its parameter `f`, it will no longer compile.
This breaking change is obvious and would affect almost all unannotated functionals.

So it must be the second option, which entails that
most `@system` annotated contexts can no longer make use of `functional`
because its signature *requires* any argument be `@safe`.
That is overly restrictive from the viewpoint of a `@system` context:
There is probably no reason why `functional` should not be used by a `@system` context.

With this change, however, the first option is the way to go:
A `@safe` context must supply a `@safe` argument for the call to `functional` to be considered `@safe`.
A `@system` context may supply a `@system` argument, rendering the call to `functional` a `@system` operation
which is not a problem, since this is exactly what was happening before making `@safe` the default.

One could argue that changing defaults is inherently a breaking change.
Still, breakage should be minimized and have a transition path.

With this DIP, the transition path is the first option together with qualifying the parameter `const` or `immutable`.

## Prior Work

There is no prior work in other languages known to the author.
The proposed changes are very specific to the D programming language.
Yet they bear some similarity to the relaxation of `pure` allowing `pure` functions to modify
any mutable value reachable through its parameters.
Those `pure` functions are called *weakly pure* in contrast to *strongly pure* ones
that cannot possibly modify values except their local variables.
The same way letting weakly pure functions be annotated `pure` allowed for more *strongly pure* functions,
the changes proposed by this DIP allow more functions carrying a warrant attribute.

The example in the [Abstract](#abstract) shows how the second `toString` overload is truly `@safe`
because the first overload is `@safe` depending on its argument.

## Description

The changes proposed by this DIP affect
* when warrant attributes are satisfied by functions annotated with them,
* how warrant attributes are inferred for function templates.

The first bullet point can be split into:
* when warrant attributes are satisfied by functionals themselves, and
* when warrant attributes are satisfied when calling a functional.

### Attribute Checking inside Functionals

When a function is annotated with a warrant attribute, each statement must satisfy certain conditions.
Among those conditions is, for any warrant attribute, that the function may only call functions
(*function* again referring to anything callable here)
that are annotated with the same attribute or have it inferred.
Exceptions to this are statements in `debug` blocks and that `@safe` functions may also call `@trusted` functions.

This DIP proposes that
1. essential calls to `const` or `immutable` eFP/D type parameters are not to be subjected to this condition, as well as
2. essential calls to local `const` or `immutable` eFP/D type variables declared in the functional,
   that are initialized by dereferencing and/or indexing a parameter without conversion, become valid, too.

In the case of checking `@safe` for a functional,
if the parameter's underlying FP/D type is explicitly annotated `@system`,
an essential call to the eFP/D object is considered invalid.
This is to avoid confusion.
Removing the unnecessary `@system` annotation fixes this error.

The second clause concerning local variables allows for iterating over eFP/D type parameters
that are slices or static or associative arrays
using a `foreach` loop.

Note that it is necessary that the full parameter's type is `const` or `immutable`.
If the uppermost level is mutable, the parameter can be reassigned in the functionals body before being called,
invalidating the assumption
that the context has full control over the eFP/D object and its type.
You may want to take a look at [the respective example](#mutable-parameters).

Only requiring `const` as a qualifier in fact does suffice.
One could conjecture that [aliasing](https://en.wikipedia.org/wiki/Pointer_aliasing)
could lead to problems, but it does not.
You may want to take a look at [the respective example](#const-and-aliasing).

However, this document does not contain a proof (or a proof sketch) that aliasing really is impossible.
If the Language Maintainers find it too dangerous to risk,
the author suggests going forth with `immutable` alone instead of `const` or `immutable`.
Because pointer, slice, and array types with more than one level of indirection are hard to use with `immutable`,
applicability of them is greatly reduced.
On the other hand, wide usage of them otherwise would probably not have happened either.

This change entails that a parameter's `const` and `immutable` on the first level of indirection
must be distinguished from a qualifier on the second level of indirection.
This is relevant for [overriding methods](#overloading-mangling-and-overriding).

Note that this only applies to parameters to the functional;
any other essential calls to eFP/Ds will be checked as is currently the case.

Note especially that if the eFP/D parameter not only takes plain values but eFP/D types themselves,
calls might not end up satisfying the attributes' conditions.
You may want to take a look at [the respective example](#third-order-and-even-higher-order-functionals).

Also note that type-checking parameters as if they were annotated `pure`, `@safe`, `nothrow`, and `@nogc`
only affects the validity of the call expression itself.
For example, uniqueness is unaffected:
If the parameter is not annotated `pure`, the call will be considered `pure` when it comes to checking whether
the functional is `pure`, but the parameters return value is not considered unique.
For that, an explicit `pure` annotation to the parameter's underlying FP/D type is required.
The same goes for other guarantees warrant attributes make.

### Attribute Inference for Functional Templates

By the proposal of this DIP,
when inferring attributes for function templates that have runtime parameters of a `const` or `immutable` eFP/D type,
essential calls are considered to not invalidate any warrant attribute.

That way, attribute inference follows the rules non-template functions are checked.

### Attribute Checking inside Contexts

When calling a functional, the types of the eFP/D arguments are known.

By the proposal of this DIP,
in a warrant attribute context, a call to a functional is valid with respect to the warrant attribute
if, and only if,
1. the functional is annotated with that warrant attribute — and
2. all arguments that bind to `const` or `immutable` type parameters are annotated with that warrant attribute.

(As in the current state of the language, if a parameter type to the functional is annotated with a warrant attribute,
i.e. stating a requirement, and the supplied argument fails to have this warrant attribute, it is a type mismatch;
akin to supplying a `const` typed pointer as an argument to a mutable parameter.)

### Overloading, Mangling and Overriding

The difference between  `const` and `immutable` on first and second layer of indirection that this DIP introduces
if the parameter's type is an eFP/D type,
seem to affect overloading (and overload resolution), mangling, and overriding.

Overloading is taken care of by proposing that no change is made.
In the current state of the language,
overload resolution considers by-copy binding of a value a conversion
if first layer qualifiers of the argument type and the parameter type disagree.
Still, these functions are considered different in type and mangling.

However, when a class overrides a method defined in a base class or an interface,
by the current rules of the language,
`const` and `immutable` qualifiers can be dropped from the first layer of indirection of a parameter's type
if a second layer is present:
```D
interface I
{
    void f(int x);
    void g(const int x);
    void h(const int* x);
    void j(const(int)* x);
}

class C : I
{
    void f(const int x); // invalid: did you mean to override I.f(int x)?
    void g(int x); // invalid, did you mean to override void I.g(const(int) x)?
    void h(const(int)* x); // valid
    void j(const int* x); // valid
}
```
For some reason, a function pointer or delegate type is not akin to `int` but `int*`,
allowing one to add and remove `const` and attributes while still qualifying as override.

There are no changes proposed concerning overriding specifically,
but you may want to have a look at the [respective example](#overriding-methods)
demonstrating the consequences of this DIP.

### Error Messages

When a functional essentially calls a mutable parameter
and that parameter's type lacks warrant attributes that the functional has,
the compile error message will hint that making the parameter `const` (or `immutable`) will solve this problem.

When a call to a functional in a warrant attribute context violates that attribute
because a eFP/D argument is passed to it,
but the functional itself is annotated or inferred compliant to that attribute,
a specific compile error message should be issued.
The author suggests a message akin to:
> `@safe` function `context` cannot call `@safe` function `functional`
> because the argument `&callback` is `@system`.

Only stating that the call is a violation of the attribute might confuse the programmer into thinking
that the annotation of the functional is defective or attribute inference did not lead to the expected attributes.

## Examples

### Lazy as a Lowering

With the changes proposed by this DIP, `lazy` can become a shortcut similar to the storage class `in`.
([Since version 2.094.0](https://dlang.org/changelog/2.094.0.html#preview-in),
`in` as a storage class means `const scope` and maybe `ref` that binds r-values.)
Similarly, `lazy T` could mean `in T delegate()` that also binds `T` arguments by lambda abstraction.
The second clause makes DIP&nbsp;1033 mostly redundant.

As an example:
```D
T orDefaultLazy(T)(T* ptr, lazy T alternative)
{
    if (ptr != null) return *ptr;
    else return alternative();
}

void context() @safe
{
    int* p = returns!(int*)();
    int v = p.orDefaultLazy(returns!int() + 1);
}
```
The internal logic can equivalently be implemented like this:
```D
T orDefaultDG(T)(T* ptr, const scope T delegate() alternative)
{
    if (ptr != null) return *ptr;
    else return alternative();
}
```

The only difference would be
that a context could call `orDefaultLazy` using an expression of type `T` in the second parameter,
but for `orDefaultDG`, the delegate must be explicit using `() => expression` or `{ return expression; }`.

In both cases, attributes are inferred depending on the attributes of `T`'s copy constructor.
For `T` being `int`, all warrant attributes are inferred.
An impure context can bind an impure expresion to the delegate, resulting in an impure operation.
A `pure` context can bind a `pure` expression to the delegate, resulting in a pure operation.

### Lockstep Iteration

Iterating multiple ranges in lockstep with `ref` access cannot be achieved (not easily, at least)
by the usual range interface (`empty`, `front`, `popFront`);
it requires `opApply`.
Here we will observe how the naïve approach fairs with respect to warrant attributes
and how to make `opApply` admit warrant attributes properly.

The naïve approach (less interesting parts hidden):
```d
struct SimpleLockstep(Ranges...)
{
    Ranges ranges;
    alias ElementTypes = ...;

    int opApply(const scope int delegate(ref ElementTypes) foreachBody)
    {
        import std.range.primitives : front; // needed for slices to work as ranges
        for (; !anyEmpty; popFronts)
        {
            if (auto result = mixin("foreachBody(", frontCalls, ")"))
                return result;
        }
        return 0;
    }

    bool anyEmpty() { ... }
    static string frontCalls() in (__ctfe) { ... }
    void popFronts() { ... }
}
```

In principle, being member of an aggregate template, `opApply` has its warrant attributes inferred.
Using `anyEmpty` and `popFronts` is unproblematic as they have their warrant attributes inferred, too.
When `opApply` calling its parameter `foreachBody` that has a delegate type
that is not annotated with any warrant attribute,
attribute inference will yield no warrant attribute for `opApply`, too.

This means that in a context annotated with any warrant attribute,
`SimpleLockstep` cannot be used.
(It can be constructed, but `foreach` through its lowering to `opApply` cannot be called.)
For example, a `@safe` context plugging in ranges with `@safe` (or `@trusted`) interfaces
cannot make use of `SimpleLockstep` because `opApply` is not annotated / inferred `@safe`,
even though all operations being performed are `@safe`.

With this DIP, `opApply` has warrant attributes inferred
based on what the range interfaces of the supplied ranges can guarantee.
(This is the best it can theoretically do.)
In the aforementioned case, `opApply` will be inferred `@safe`.
Whether a call to `opApply` is valid in a `@safe` context is determined by the particular argument.

For how to implement `SimpleLockstep` in a way that properly takes attributes into account
using the current state of the language, see the [Alternatives](#alternatives) section.

### String Representations

Many objects have an at least somewhat human-readable `string` representation.
In quick-and-dirty programs, a function returning GC allocated `string` representations suffices.
In libraries, however, one strives for more generality.
The usual way to give the context first-class control over how the `string` representation is handled
is replacing the return value by a sink.
A sink is an [output range](https://dlang.org/library/std/range/primitives/is_output_range.html)
that the individual characters are fed into.
The context controls the sink.

A typical `toString` as part of an aggregate type uses a templated `toString`
taking the sink type as a template type parameter akin to this:
```D
void toString(Sink)(const scope Sink sink) const { ... }
```
This solves the attribute inference problem perfectly.

However, the author of a class or interface usually wants the `toString` member function to be virtual,
but then, it cannot be a template anymore; the sink type usually becomes a delegate.

```D
// For quick and easy usage:
string toString() const @safe pure /*maybe*/nothrow { ... }

// For elaborate uses:
private final void toStringImpl(Char)(const scope void delegate(Char) sink) { ... }
static foreach (Char; aliasSeq!(char, wchar, dchar))
    void toString(const scope void delegate(Char) sink) const { toStringImpl!Char(sink); }
```

In the current state of the language, those `toString`s cannot be used in warrant attribute contexts.
Authors who want to support warrant attribute contexts have to implement up to 16 overloads like this:
```D
private final void toStringImpl(DG)(const scope DG sink) { ... } // inferres attributes
static foreach (Char; aliasSeq!(char, wchar, dchar))
{
    void toString(const scope void delegate(Char)       sink) const       { toStringImpl(sink); }
    void toString(const scope void delegate(Char) @safe sink) const @safe { toStringImpl(sink); }
    ... // 13 more
    void toString(const scope void delegate(Char) pure nothrow @safe @nogc sink) const pure nothrow @safe @nogc
    { toStringImpl(sink); }
}
```
All instantiations of `toStringImpl` are different, so there are 3&nbsp;×&nbsp;16&nbsp;=&nbsp;48 template instances
and virtual `toString` functions per class.
If the class is templated, there are 48 per instantiation.

Worse than the template and virtual-table bloat is that users of the class
who naïvely override the `toString` method in a derived class will only override the version without attributes.
```D
override void toString(const scope void delegate(Char) sink) const { ... }
```
They get a hint that there were other overloads to override available:
An error message pointing out that the derived class' `toString` hides base class `toString` functions.
The suggestion by the compiler to "introduce base class overload set" is wrong.
It makes the code compile, but for any sink that has any warrant attribute, it calls the base class `toString`.

Nonetheless, correctly overriding `toString` means implementing the 48 overloads again.

All in all, a library author who publishes a class that uses warrant attributes with maximized flexibility
makes it unnecessarily hard to override functional methods correctly and unnecessarily tedious to do so correctly.

With the changes proposed by this DIP, only one `toString` method is needed per character type.
(This is the best one can theoretically do.)
Which attributes the `toString` can be given has to evaluated once by the class author.
The class author may intentionally not annotate any method with a warrant attribute
to allow overriding with an implementation that violates that attribute.
The fact that guarantees given by a base class cannot be reduced by a derived class are part of the
Liskov substitution principle and cannot be addressed by this DIP.
Whether a method (not only a functional) should carry warrant attribute,
is a discretionary decision to be made by the class author.

### Functions with Typesafe Variadic Lazy Parameters

A function taking a variable number of lazy parameters has, as its last parameter, a static array or slice type
whose underlying type is a possibly qualified delegate type taking no parameters.

The reason behind *essential* FP/D objects, types and calls is mainly this use-case, generalized accordingly.
A standard application of taking a variable number of lazy parameters is `coalesce`,
a function that returns the first value that is not `null` or `null` if none is.
```D
T coalesce(T)(const scope T delegate()[] paramDGs...)
{
    foreach (paramDG; paramDGs)
    {
        static assert(is(typeof(paramDG) == const));
        if (auto result = paramDG()) return result;
    }
    return cast(T) null;
}
```

Here, `paramDG` is a `const` qualified local variable initialized from `paramDGs`.
Because of the second clause

### Mutable Parameters

Mutable parameters are not subject to the reduced conditions.
Consider `coalesce` from the example above, but with a differently typed parameter:
```D
T coalesce(T)(scope const(T delegate())[] paramDGs...);
```
In contrast to the above implementation, the outermost layer of `paramDGs` type is mutable.
Since the context has no control over what `coalesce` does internally,
`coalesce` could append the slice and call the appended delegate object:
```D
paramDGs ~= () => returns!T();
paramDGs[$ - 1]();
```
In this case, `coalesce` will not have any warrant attribute inferred,
because the parameter `paramDGs` does not get any special treatment.

Changes to the outermost layer of indirection of a parameter are invisible to the caller,
and thus the above code could be rewritten so that `paramDGs` is not appended
allowing for it to be `const` on the outermost layer, too.

### Const and Aliasing

Here, we will look at an example why requiring `const` does in fact guarantee
that the context has control over the type of parameters in the functional.

First, we will have a look at regular pointer aliasing:
```D
void proneToAliasing(ref int x, const(int)* p)
{
    assert(*p == 0);
    x = 1;
    assert(*p == 1);
}
void resistsAliasing(ref int x, immutable(int)* p) { ... }
void context()
{
    int x = 0;
    proneToAliasing(x, &x); // okay
    resistsAliasing(x, &x); // error
}
```
Aliasing can happen in the first function because a `int*` can be assigned to a `const(int)*`.
It cannot happen in the second because `int*` cannot be assigned to an `immutable(int)*`.

For trying to trick the type-system into considering a call to a `@system` function a `@safe` operation,
aliases of function pointers will be used the same way as above with `int`s.
This is our setup:
```D
alias sysFunc = function int() @system
    { int* p; int x; p = &x; return *p; };

alias SysFP = int function();
int aliasingProneFunctional(ref SysFP fp, const(int function()/*@safe*/)* fpp) @safe
{
    fp = sysFunc; // assign a @system function ptr to a @system fp variable, okay
    return (*fpp)(); // essentially call a parameter
}
```
Next, we look at a `@safe` context that tries calling `aliasingProneFunctional` with mutable function pointers.
```D
void context() @safe
{
    int function() @safe mutableSafeFP = () => 1;
    aliasingProneFunctional(mutableSafeFP, &mutableSafeFP);
}
```
The last call does not compile.
Regardless of commenting-in the `/*@safe*/` above, that code will not compile,
since the second argument is not the problem. It is the first one:
A `@safe` function pointer cannot be bound to a `ref` function pointer parameter (implicitly) annotated `@system`.
Assigning a `@safe` FP/D to a `@system` variable uses an implicit conversion that is not allowed for binding to `ref`.
It's `ref` that needs an exact match for mutable types.
Because `fpp` is a pointer to a `const`, some implicit conversions may take place,
and dropping warrant attributes is among them.

For completeness, if `mutableSafeFP` were to be replaced by a `@system` function pointer like this
```D
int function() @system mutableSysFP = () => 1;
aliasingProneFunctional(mutableSysFP, &mutableSysFP);
```
by the proposal of this DIP, the bindings work fine.
Since the `@safe` functional's `const` parameter is not bound by a `@safe` function pointer,
the call to `aliasingProneFunctional` is not considered `@safe`, leading to a compiler error in the `@safe` context.

### Overriding Methods

This example demonstrates what changes when base class or interface methods are overridden.
```D
class Base
{
    void functional(const void function()[] paramFunctions) @safe
    { foreach (fp; paramFunctions) fp(); } // becomes valid
    abstract void gunctional(const void function(int) paramFunction) @safe
    { paramFunction(1); } // becomes valid
    abstract void hunctional(int function(int) pure @safe paramFunction) pure @safe;
}

interface Interface
{
    int junctional(const int function(int) pure @safe paramFunction) @safe;
    int kunctional(const int function(int) pure paramFunction) pure @safe;
    int lunctional(int function(int) pure @safe paramFunction) pure @safe;
}
```
Both implementations of the methods in `Base` become valid by the changes this DIP proposes.

*Weakening the overload* means that the implementation may not do things the base class implementation could do.
Primarily this means (essentially) calling a parameter.
```D
class Derived : Base, Interface
{
    // Dropping const on the first layer of indirection weakens the override:
    override void functional(const(void function())[] paramFunctions) @safe
    { foreach (fp; paramFunctions) fp(); } // stays invalid: cannot call @system fp
    override void gunctional(void function(int) paramFunction) @safe
    { paramFunction(1); } // stays invalid: cannot call @system paramFunction

    // Dropping attributes on a const parameter type makes sense with this DIP:
    override void hunctional(const int function(int) pure fp) pure @safe
    { return paramFunction(1); } // becomes valid

    // Dropping const is fine, as long as the functional's attributes are carried over:
    override int junctional(int function(int) pure @safe paramFunction) @safe
    { return paramFunction(1); } // stays valid
    // (Keeping the pure requriement, a further derived implementation's logic can make use of it.)

    // Dropping const on a parameter with lower attributes weakens the override:
    override int kunctional(int function(int) pure paramFunction) pure @safe;
    { return paramFunction(1); } // stays invalid: cannot call @system paramFunction

    // Adding const and dropping attributes on a parameter is okay.
    override int lunctional(const int function(int) pure paramFunction) pure @safe
    { return paramFunction(1); } // becomes valid
}
```
The overrides of `Base` methods become invalid by the proposed changes of this DIP,
but can easily be made valid again by declaring the parameters `const` on the first layer of indirection.

The override of `hunctional` dropping `pure` on its parameter's type is valid
and stays valid by the proposed changes of this DIP.
However, by the current state of the language, `Derived.hunctional` cannot call its parameter,
but by the proposed changes of this DIP, it can.
Calls to `Interface.hunctional` with a `pure` argument stay well-behaved.
(With an impure argument, they stay invalid.)
Calls to `Derived.hunctional` with an impure argument become meaningful although impure themselves.

The example of `junctional` shows that
if the parameter's type has the same or more warrant attributes as the functional,
`const` is not necessary on `Interface.junctional` and can be dropped.
However, dropping `const` on a parameter with a type that has lower attributes than the functional
like `kunctional` does, has consequences.
On the other hand, adding `const` allows the functional to make use of its parameter with lower attributes.

### Third-order and Even-Higher-Order Functionals

All the functionals presented in illustrations and examples were of second order,
i.e. the FP/D types in functionals' parameter lists themselves took no eFP/Ds as parameters.

The easiest example of a non-trivial third-order functional is this:
```D
void doNothing() /*pure*/ { }
void justCall(const void function() f) pure { f(); }

void thirdOrderFunctional(const void function(void function()) secondOrderParameter) pure/*?*/
{
    // Here, secondOrderParameter is assumed to be pure by the rules of this DIP.
    // This does not mean that the following call expression is immediately valid in a pure function.
    // Being a functional, calling secondOrderParameter is pure iff its argument is typed pure.
    secondOrderParameter(&doNothing);
}

void context() pure
{
    thirdOrderFunctional(&justCall);
}
```

Say we wanted to annotate `thirdOrderFunctional` with `pure` for it to be callable from the to-be-pure `context`.
That means that, given a `secondOrderParameter` that is `pure`, it will act in accordance to the attribute.
For `secondOrderParameter` to be `pure` means that it, too, acts in accordance to the attribute
when fed with a `pure` argument.
If we annotate `doNothing` with `pure`, this is the case.
If we forget to annotate `doNothing` properly,
the call expression `secondOrderParameter(&doNothing)` is considered impure.
While the relaxed rules assume that `secondOrderParameter` is `pure`, it being a functional
means it only acts in accordance to that attribute if its arguments are typed accordingly.

We finish this example with a fourth-order functional.

```D
...

void fourthOrderFunctional(const void function(void function(void function())) thirdOrderParameter) pure
{
    // Due to the rules of this DIP, thirdOrderParameter is assumed to be pure.
    // Because justCall is annotated pure, the call really is pure and the constraints are satisfied.
    thirdOrderParameter(&justCall)
}

void context() pure
{
    // Because fourthOrderFunctional and thirdOrderFunctional are annotated pure,
    // this call is pure.
    fourthOrderFunctional(&thirdOrderFunctional);
}
```

### Functions returning Function Pointers or Delegates

Since attributes do not impose any restrictions on returning FP/Ds,
the rules remain completely unchanged.

```D
alias R = int function() nothrow;
R returnsNothrowFP(int x) pure
{
    if (x < 0) throw new Exception("");
    else return { static int counter; return counter++; };
}
```

Here, `returnsNothrowFP` is a `pure` function that may throw, retuning a pointer to an impure `nothrow` function.
This is to demonstrate that attributes on functions do not interact in any way with attributes on their return values
if those return values happen to be of FP/D type.

## Alternatives

### The Current State

As this DIP does not introduce new possibilities,
there is a way to mimic the behavior of the changes introduced by this DIP.

We take a look at `SimpleLockstep` again from the [Lockstep Iteration](#Lockstep-Iteration) example.

First, we observe that none of the operations in `opApply` directly violate any warrant attribute.
So, in the best case scenario with respect to `Ranges`, `opApply` should be able to carry all warrant attributes.

Making `opApply` a template takes away the possibility to infer the `foreach` loop variables' types,
so this is not an option.

However, one can move the code inside `opApply` into a template taking the delegate type as a template parameter
and creating aliases named `opApply` to instances of that implementation template:

```D
SimpleLockstep(Ranges...)
{
    Ranges ranges;

    ...
    alias ElementTypes = ...;

    private int opApplyImpl(DG : const int delegate(ref ElementTypes))(const scope DG foreachBody) { ... }

    alias opApply = opApplyImpl!(int delegate(ref ElementTypes) pure nothrow @safe @nogc);
    alias opApply = opApplyImpl!(int delegate(ref ElementTypes)      nothrow @safe @nogc);
    alias opApply = opApplyImpl!(int delegate(ref ElementTypes) pure         @safe @nogc);
    alias opApply = opApplyImpl!(int delegate(ref ElementTypes)              @safe @nogc);
    alias opApply = opApplyImpl!(int delegate(ref ElementTypes) pure nothrow       @nogc);
    alias opApply = opApplyImpl!(int delegate(ref ElementTypes)      nothrow       @nogc);
    alias opApply = opApplyImpl!(int delegate(ref ElementTypes) pure               @nogc);
    alias opApply = opApplyImpl!(int delegate(ref ElementTypes)                    @nogc);
    alias opApply = opApplyImpl!(int delegate(ref ElementTypes) pure nothrow @safe      );
    alias opApply = opApplyImpl!(int delegate(ref ElementTypes)      nothrow @safe      );
    alias opApply = opApplyImpl!(int delegate(ref ElementTypes) pure         @safe      );
    alias opApply = opApplyImpl!(int delegate(ref ElementTypes)              @safe      );
    alias opApply = opApplyImpl!(int delegate(ref ElementTypes) pure nothrow            );
    alias opApply = opApplyImpl!(int delegate(ref ElementTypes)      nothrow            );
    alias opApply = opApplyImpl!(int delegate(ref ElementTypes) pure                    );
    alias opApply = opApplyImpl!(int delegate(ref ElementTypes)                         );

    bool anyEmpty() { ... }
    static string frontCalls() in (__ctfe) { ... }
    void popFronts() { ... }
}
```

This solution has some drawbacks:
* DRY violation.
* Unnecessary template bloat.
* The 16 combinations of attributes have to spelled out; avoiding spelling them out requires string mixins which,
  from a maintainability standpoint, is clearly worse than this.

If one of the `Ranges` happens to have a primitive that fails some attributes,
the corresponding `opApply`s will be identical.
As an example, if `popFront` is impure, all `opApply` overloads created by instantiating
the implementation template with a `pure` delegate type lead to identical impure `opApply`s regardless.
Depending on what overloads are called, it might lead to binary bloat.

If a warrant attribute is to be added to the language, the number of overloads to spell out increases to 32.
In general, this does not scale well.
Also, from a maintainability standpoint, templates should have no problems with the addition of another attribute.
However, since they need to be spelled out, the code has to be adapted to the new circumstance.
From the perspective of working with all attributes, adding a warrant attribute breaks code.

In meta-programming, one tends to care little about attributes, since they are inferred,
unless of course the details of one becomes part of the function's logic.

If the functional in question is part of an interface or otherwise part of an inheritance hierarchy,
templates cannot (easily) be customized, e.g. by overriding them.

### New Attributes

Attribute bloat is already a concern raised in the forums.
Any of these solutions would increase it.

#### Weak Clones

Breakage could be avoided by introducing weak clones of the current warrant attributes
with the described meaning of conserving.
They would mean the same as the current (strong) warrant attributes for non-higher-order functions.
The DIP author considers this option to be less desirable because the weak attributes
* need new syntax,
* have an overly specific use-case, therefore
* fear to have almost no adoption by developers.

One should mention that `pure`, when it meant strongly pure,
did not get a weak counterpart for weak purity,
but was redefined because strong and weak purity can be distinguished by the type system.

The DIP (at the time of this writing) called *Argument-dependent Attributes* follows this approach.

#### Indicate not Calling a Parameter

Another possibility is breaking code, but at least giving programmers the ability to state explicitly
that a parameter is not (essentially) called, probably using an attribute like `@nocall`.
The call of a functional with an argument binds to a parameter annotated `@nocall`, will not water down its guarantees.
The new attribute would be inferred for parameters of function templates.

This solution is undesirable because a functional not calling its parameter is incredibly rare.
Even rarer is the case where attributes of the argument passed to the functional and the attributes of the context
are incompatible in the sense that the argument has strictly weaker guarantees than the context.
Even then, this situation can be handled with the changes proposed by this DIP:
When one makes the first layer of indirection mutable, it is handled the way it is in the current state of the language.

#### Indicate Calling a Parameter

Conversely, an attribute `@calls` could be introduced that indicates that a functional indeed calls its parameter.
Feeding an argument with lower guarantees than the functional then waters down the functional's guarantees
only if it is passed to a parameter annotated with `@calls`.
The new attribute would be inferred for function templates.

This solution is undesirable because the attribute would be on almost every functional.
Forgetting leads to compile errors that, depending on the error message, might be confusing.

The same way as the alternative above, it could be handled by making the parameter const.

## Breaking Changes and Deprecations

Functionals that don't essentially call one of their `const` or `immutable` qualified eFP/D parameters
may suffer from breakage.

An example of an affected functional could be the following.
(Note that, depending on the state of the language, `in` means `const` or `const scope`.)
```D
int delegate() toDelegate(in int function() func) nothrow pure @safe
{
    alias toDG(alias f) = delegate() { return f(); };
    return toDG!func;
}
```
A `@safe` context can call `toDelegate` with a `@system` argument.

With the changes proposed by this DIP, the call in the context will become invalid.
However, one must wonder what the `@safe` context would do with that `@system` return value,
since it cannot call it directly.
To make use of it, it must find its way to a point where calling a `@system` delegate is valid.
However, this could be in a `@trusted` pseudo-block (a lambda immediately called) in the context.

Because the proposed change only affects parameters qualified on the highest level of indirection,
this problem can be solved by pushing down the `const` qualifier one level of indirection.
In the example above, `in` has to be removed or replaced by `scope`.

### Reference

1. [Wikipedia: Higher-order function](https://en.wikipedia.org/wiki/Higher-order_function)
1. [D Language Specification: `opApply`](https://dlang.org/spec/statement.html#foreach_over_struct_and_classes)
1. [D Language Specification: Lazy Parameters](https://dlang.org/spec/function.html#lazy-params)
1. [D Language Specification: Lazy Variadic Functions](https://dlang.org/spec/function.html#lazy_variadic_functions)
1. [Discussion: `opApply` with Type Inference and Templates?](https://forum.dlang.org/post/zkovjshfktznepertjay@forum.dlang.org)
1. [Discussion: Parameterized delegate attributes](https://forum.dlang.org/post/ovitindvwuxkmbxufzvi@forum.dlang.org)
1. [Discussion: `@nogc` with `opApply`](https://forum.dlang.org/thread/erznqknpyxzxqivawnix@forum.dlang.org)
1. [Issue: `opApply` and nothrow don't play along](https://issues.dlang.org/show_bug.cgi?id=14196)

## Copyright & License

Copyright © 2020 by Quirin F. Schroll and the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Reviews

The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
