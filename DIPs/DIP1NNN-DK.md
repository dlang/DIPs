# Add a Bottom Type (reboot)

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0                                                               |
| Author:         | Dennis Korpel dkorpel@gmail.com                                 |
| Implementation: |                                                                 |
| Status:         | Draft                                                           |

## Abstract
It is proposed that certain holes and limitations in D's type system be addressed by introducing [a bottom type](https://en.wikipedia.org/wiki/Bottom_type).
A bottom type has 0 values and is useful for representing run-time errors and non-terminating functions.
[A previous proposal, DIP1017](https://github.com/dlang/DIPs/blob/master/DIPs/rejected/DIP1017.md), was rejected.
It is believed that the DIP focused too much on one specific use case (specifying a function will not return) and did not consider interactions with the rest of the language.

## Contents
* [Background theory](#background-theory)
* [Rationale](#rationale)
* [Prior work](#prior-work)
* [Other languages](#other-languages)
* [Description](#description)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Reference](#reference)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)

## Background theory
Pure functions in programming languages can often be thought of as mathematical functions, mapping elements from an input set (domain) to elements of an output set (co-domain).
A big problem with this comparison is that mathematical functions are defined to give an answer, while a computer has to perform computation [[1]](#reference).
It is possible that a procedure just loops forever; finding this out beforehand in general is impossible because of [the Halting Problem](https://en.wikipedia.org/wiki/Halting_problem).
One solution is to disallow programs that may not halt.
[Coq does this](https://en.wikipedia.org/wiki/Coq); consequently, it is not Turing complete.
The more common solution is to have one implicit extra member to every type: the bottom value, denoted by `⊥`.
This is not a traditional value that is stored in memory with a certain bit-pattern, it simply represents the possibility that the code never reaches the point where an actual value of that type would be returned or assigned.

For example:
```D
bool isPrime(int x);
bool foo(int x) {
    return isPrime(x);
}
```
While a `bool` is only 1-bit with two possible values, calling `foo` can actually result in three possible results: {`true`, `false`, `⊥`}
The bottom value `⊥` represents `isPrime` becoming stuck in an endless loop (in a bad implementation), crashing (e.g., because it's out of memory), or throwing an exception (e.g., `x` was negative).
In such cases, `foo` does not return a `true` or `false` value like a mathematical function always would.
Note that having a bottom *type* in a programming language does not *add* the bottom *value* or any run-time cost associated with it.
The bottom value is a concept that exists in any Turing complete language even without a bottom type.

The bottom type should not be confused with a unit type, such as `void`:
```D
void assertInBounds(int[] arr, int x);
void foo(int[] arr, int x) {
    return assertInBounds(arr, x);
}
```
A unit type has only one value, so 0 bits of storage are needed.
Calling `assertInBounds` can produce two things: {`()`, `⊥`}
Either it returns (represented by the unit value `()`) or it causes a crash (represented by the bottom value `⊥`).
Since the unit value carries no information, it is discarded and doesn't produce any code or use any memory.
Note that `void` currently has some restrictions and oddities making it not a proper unit type; [another DIP](https://github.com/dkorpel/DIPs/blob/fix-void/DIPs/DIP1NNN-DK.md) aims to fix that.

Finally, consider a function that always crashes:
```D
auto foo() {
    assert(0);
}
```
It can only result in a bottom value `⊥`, but the compiler infers this as a function returning `void`, thus believing it could also return a unit value `()`.
When the body is not known of foo there is no way of knowing that it can never actually return `()`.

## Rationale
In this section, several situations where a bottom type is useful in D are shown.
The bottom type is referred to as `noreturn` in code, in the last subsection this choice of name will be discussed.

### Flow analysis across functions
Currently, D recognizes code after a `throw` statement, an endless loop such as `for(;;){}`, or an `assert(0)` expression as dead code.
Therefore, a return statement can be ommitted.
```D
int main() {

    while(true) {}
    // no return necessary, this is dead code
}
```

This works well in statement-based code, but D also supports more expression-based coding styles where this flow analysis info is lost because functions act as a 'boundary'.
For example: ([courtesy of Paul Backus](https://forum.dlang.org/post/hdheyjpxiqanakwpisbf@forum.dlang.org)).
```D
struct Expected(T, E) {
    private SumType!(T, E) data;

    T value() {
        return data.match!(
            (T val) => val,
            (E err) { throw new Exception(err.to!string); }
        );
    }
}
```

This will not compile, because the second handler function is inferred to have a return type of `void`, and `void` is not implicitly convertible to `T`.
Even though an observer (and possibly an optimizing backend) can see that `value()` will never return when the `(E err)` handler is chosen, the compiler front end is forced to assign a return value to the function literal and ensure every expression and template instantiation is type sound.
If the return type of the handler function `(E err)` were inferred as a bottom type, this code would work.

Another limitation is that the lambda syntax (`(T val) => val`) cannot be used for the `(E err)` handler case because D only has the notion of a `throw` statement, not a `throw` expression.
This is because every expression needs to have a type, and currently there is no suitable return type for `throw` since it never returns a value.
This issue arose in the D newsgroup: [Throwing from a lambda isn't supported by the compiler](https://forum.dlang.org/post/efwqhlripiwklvecpxux@forum.dlang.org).
When a `throw` statement is seen as an expression returning the bottom type, the following example will work:
```D
void foo(int function() f) {}

void main() {
    foo(() => throw new Exception());
}
```

**Other examples:**

In a `switch` statement, it is possible to add a case `default: assert(0);`.
This is not possible when using lambda-handlers to simulate a `switch`, [like the sumtype](http://code.dlang.org/packages/sumtype) package does:
```D
alias Var = SumType!(int, double, string);
int round(Var v) {
    return v.match!(
        (int x) => return x;
        (double x) => return cast(int) x;
        other => assert(0); // currently does not compile
    );
}
```

With a bottom type it is possible to use `std.exception: handle` to turn exceptions into errors without surrounding the code in a try-catch block.
```D
auto s = "10,20,30"; // guaranteed well-formed integers
auto r = s.splitter(',').map!(a => to!int(a));
auto h = r.handle!(ConvException, RangePrimitive.front, (e, r) => assert(0));
```

A bottom type can also be used in a ternary operator: (example [courtesy of Andrei Alexandrescu](https://forum.dlang.org/post/ok5bcj$5d8$1@digitalmars.com))
```D
noreturn abort(const(char)[] message);

int fun() {
    int x;
    //...
    return x != 0 ? 1024 / x : abort(0, "calculation went awry.");
}
```

### The type of the empty array literal
Currently, a `void[]` is not implicitly convertible to an array of a different type, e.g., an `int[]`.
```D
int[] test() {
    return cast(void[]) [1, 2, 3];
}
```

```
Error: cannot implicitly convert expression `cast(void[])[1, 2, 3]` of type `void[]` to `int[]`
```

However, an empty array literal, which has type `void[]`, can actually be converted to an `int[]`.
```D
int[] test() {
    pragma(msg, typeof([])); // void[]
    return []; // no error
}
```

This is a special case the compiler allows, but this does not hold up when the programmer makes a custom type:

```D
import std;

struct CastToIntArray {
    int[] arr;
    void opAssign(T)(T[] other) {
        arr = other.map!(x => cast(int) x).array;
    }
}

void main() {
    CastToIntArray a;
    a = [2.1, 3.1, 4.1];
    writeln(a); // [2, 3, 4]
    a = []; // template instance `CastToIntArray.opAssign!void` error instantiating
    writeln(a);
}
```

When the element type of an empty array is a bottom type (referred to as `noreturn`), an empty array literal `[]` can be seen as an array literal that is guaranteed to be empty, therefore being implicitly convertible to an array of any type.
When opAssign is instantiated with `noreturn[]` instead of `void[]`, the function `map` will return a struct that looks something like this:

```D
struct MapResult {
    noreturn[] storage;

    int front() {
        return cast(int) storage[0];
    }

    void popFront() {
        storage = storage[1..$];
    }

    bool empty() {
        return (storage.length == 0);
    }
}
```

Since `storage[0]` is no longer `void` but now `noreturn`, which can be converted to any other type, it will automatically work.
Furthermore, the expression `storage.length == 0` can be constant folded to `true` in function `empty()`, even without optimizations, and if the return-type of `front()` were declared `auto` it could be statically inferred to always result in an error.

### The type of the null-pointer
Currently `typeof(null)` is a special type to the compiler.
It is a subtype of every pointer, array, and class, but it can't be resolved as a pointer type of anything.
```D
void foo(T)(T* ptr) {}

void main() {
    foo(new int); // okay, T = int
    static assert(is(typeof(null): int*)); // okay
    foo(null); // template foo cannot deduce function from argument types !()(typeof(null))
}
```

When asking the reference compiler what `typeof(*null)` is, it says, `Error: can only * a pointer, not a typeof(null)`.
It is proposed that `is(typeof(*null) == noreturn)` and `is(typeof(null) == noreturn*)`.

### Functions that cannot return
Currently, the reference D compiler keeps a list of internal functions that never return.
Being able to specify that a function does not return has advantages for optimization, but currently the internal list is not extensible.
The [C Standard function `exit()`](https://www.tutorialspoint.com/c_standard_library/c_function_exit.htm) does not return, but as the source is not available to the D compiler it is not recognized as such.
With a `noreturn` type, it could be expressed like this:

```D
extern(C) noreturn exit();
```

Now this will correctly interact with the type system and allow optimizations.

### Standard name
While any user can define their own alias to the bottom type, having a standard name prevents everyone from using a different name for the same thing.
This DIP proposes the name `noreturn` to make its semantics and purpose very clear in situations where the type name is spelled out.
[The Zig language](https://ziglang.org/) also uses this type name, and C++ uses this exact name for its `[[ noreturn ]]` attribute.

The name is not capitalized because it can be seen as a basic type like `int` or `string`, unlike a struct or class.

The name `never` is also a good contender, since it expresses how the type can 'never' be returned or instantiated.
`typeof([]) == never[]` than `typeof([]) == noreturn[]` makes a little more sense, but the typename of `[]` rarely needs to be written in code.
The return type of functions is commonly spelled out, so `noreturn` is favored.

One exceptional case is:
```D
auto x = [];
x ~= 3; // Error: cannot append type int to type void[]
```
Instead of mentioning `noreturn[]` here, the compiler could give a more informative message anyway, such as "element type could not be inferred from empty array".
In the remaining cases, `noreturn[]` can be called `typeof([])` and `noreturn*` can be called `typeof(null)`.

Appending a 't' to give `noreturn_t` or `never_t` is possible if "never" or "noreturn" can be ambiguous with values of the same name.
Unlike `size_t` where just `size` could clash with a variable name, it is deemed unnecessary for `never` or `noreturn` to have a `_t` postfix.
A text search through all registered Dub packages found that `noreturn` is rarely used as an identifier name in D code.
One notable exception is the reference D compiler itself, using it as a parameter / local variable name:
```
dmd/src/dmd/backend/cod2.d:        int noreturn = !el_returns(e2);
dmd/src/dmd/cppmanglewin.d:    const(char)* mangleFunctionType(TypeFunction type, bool needthis = false, bool noreturn = false
```
This can be changed of course, but adding the alias `noreturn` wouldn't even break this since overriding an alias is allowed (e.g., a variable may be named `string`).

While the name `TBottom` was proposed in DIP 1017, disagreement was high.
The rationale for `TBottom` is summarized [in a newsgroup post](https://forum.dlang.org/post/q1mjrd$2d0r$1@digitalmars.com):

> Inventing new jargon for established terms is worse.
> Established jargon gives the reader a certain level of
> confidence when established terms are used correctly in that
> the reader understands the text and that the writer understands
> the text.
>
> The "Bottom" type appears in books on type theory, like "Types
> and Programming Languages" by Pierce. "Never" does not, leaving
> the reader wondering what relation it might have to a bottom
> type.

Counter argmuments:
- The current type names are often not based on mathematical or "official" names.
`struct` and `union` are not named `product` and `sum`.
`void` is not called `TUnit`.
`char` is not called `UTF8CodeUnit`.
- When a user truly wants to learn about `noreturn` in D, he invariably needs to refer to the D documentation where it can be pointed out that it is indeed a bottom type.
- No other programming language uses "bottom" in their typename for the bottom type, and it is unreasonable to expect that most programmers are familiar with type theory.
- New users may not encounter explicit mentions of the bottom type for a long time, but when they do, `TBottom exit();` will be confusing, while `noreturn exit();` is immdediately obvious.

## Prior work

Bottom types first came up in the newsgroup on July 08, 2017:
[proposed @noreturn attribute](https://forum.dlang.org/thread/ojqbc5$gro$1@digitalmars.com?page=1)

Walter Bright later wrote DIP 1017:
[Add Bottom Type](https://github.com/dlang/DIPs/blob/master/DIPs/rejected/DIP1017.md)

[During Community Review](https://forum.dlang.org/post/bvyzkatgwlkiserqrcwk@forum.dlang.org), DIP 1017 was criticized for adding much language complexity without much benefit.
The only use case described was optimizing functions that don't return, which could also be achieved with a simple attribute.

[During Final Review](https://forum.dlang.org/post/qnrkfiqmtqzpyocxxtsk@forum.dlang.org), DIP 1017 was criticized for not having addressed the feedback from Community Review, and it ended up being withdrawn.

In [the Formal Assessment](https://forum.dlang.org/post/msohwtbfpiucioccbcnc@forum.dlang.org), it was mentioned that the DIP author "still believes there is a benefit to adding a bottom type to the language, but this proposal is not the way to go about it.".

## Other languages

### Rust
Rust has a bottom type denoted by `!` and called "never".
Functions (or macros) that do not return such as `panic!()` have this in their type signature.
While on the stable channel it still acts as a special type only found as a return type of functions, work is ongoing to make it a full-fledged type: see [Rust issue 35121](https://github.com/rust-lang/rust/issues/35121).

### TypeScript
TypeScript has a `never` type.
TypeScript is not a systems programming language, but a language that transpiles to JavaScript.
The bottom type is not used for optimization, but for catching dynamic type errors.

```TypeScript
function foo(value: string | number) {
    if (typeof value === "string") {
        value; // Type string
    } else if (typeof value === "number") {
        value; // Type number
    } else {
        value; // Type never, maybe this was called from faulty JavaScript code?
    }
}
```
Example code [from Marius Schulz](https://mariusschulz.com/blog/the-never-type-in-typescript).

### Zig
Zig has a keyword `unreachable` representing the bottom value with type `noreturn`.
Other expressions with this type are `break`, `continue`, `return`, `unreachable`, `while (true) {}`.
Since Zig is very expression based (in D the above expressions would be statements), the keyword often appears in idioms, for example try-expressions:
```
try parseInt("3") catch unreachable
```
This signals that the function is expected not to return an error code.
The closest D equivalent would be `std.exception: assumeNothrow`.

```Zig
switch(value) {
    case x => 0;
    case y => 1;
    case z => unreachable;
    else unreachable;
}
```
The D equivalent would be:
```D
switch(value) {
    case x: return 0;
    case y: return 1;
    case z: assert(0);
    default: assert(0);
}
```
Because Zig's switch is expression based and D is statement based, both can express the same thing.
However, as shown in the `SumType` example, D cannot do `assert(0)` in an expression-based switch.

See also: [Zig's documentation on `noreturn`](https://ziglang.org/documentation/0.6.0/#noreturn).

## Description
The following language changes are proposed based on the above rationale.
Some aspects of the new behavior are elaborated after this list.

**(0) A bottom type is added to the language**

It is used as the type of any expression that is guaranteed to terminate the program.
`null` becomes a pointer to the bottom type and `[]` becomes an array of the bottom type.
The type can be accessed in these ways:
```D
typeof(*null);
typeof([][0]);
typeof(assert(0));
typeof(throw new Exception()); // depends on (4)
```

**(1) A standard alias for the type is added and implicitly imported into every module, similar to `string` and `size_t`.**

The name of the alias is `noreturn`.
```D
alias noreturn = typeof(*null);
```

**(2) All built-in operators that have "overloads" act as if they have specialized versions for `noreturn`.**

E.g., the expression `assert(0) + assert(0)` would normally cause an ambiguity error: is it `int`, `long`, `float` or `double` addition?
With this rule, it holds that `is(typeof(assert(0) + assert(0)) == noreturn)`.
Another example: In `[1, 2, 3] ~ assert(0)`, is it concatenating an `int` or an `int[]`?
Since `noreturn` is the subtype of everything, it would technically be ambiguous.
In practice, it doesn't matter---the resulting expression has type `int[]` and compiles to:
```D
auto __tmp = [1, 2, 3];
assert(0);
```

**(3) Implicit conversions from `noreturn` to any other type are allowed.**

No type is implicitly convertible _to_ `noreturn`, but `noreturn` is implicitly convertible to every other type.
Additionally, new covariance rules are defined for `noreturn`.
For all types T, the following will hold:
```D
/* 0 */ is(noreturn : T)
/* 1 */ is(noreturn[] : T[])
/* 2 */ is(noreturn* : T*)
/* 3 */ is(noreturn function(S) : T function(S), S...)
/* 4 */ is(noreturn delegate(S) : T delegate(S), S...)
/* 5 */ is(noreturn* : noreturn[])
/* 6 */ !(is(T == function)) || is(noreturn* : T)
/* 7 */ !(is(T == delegate)) || is(noreturn* : T)
```
- 0 follows from the definition of a bottom type.
- 1 and 2 are so that the new types of `null` and `[]` implicitly convert to other pointers and arrays, respsectively.
- 3 and 4 ensure the function pointer may be used to `noreturn exit()` and passed to a `int function() callback` parameter without explicit cast (which disables *all* checking for matching parameter types).
- 5, 6 and 7 mean that `null` (which is of type `noreturn*`) may still be assigned to a function pointer or array.

Note that rules 1 to 4 don not naturally follow from rule 0 since pointers and arrays are currently not covariant in element types, and function pointers are not covariant in return types.
This means that one may define `class C : Object`, but that doesn't mean `is(C[] : Object[])`.
Also, `is(dchar* : int*) == false` and `is(char function() : ubyte function()) == false`.

**(4) Throw expressions are added to the language, replacing throw statements.**

The `throw` keyword acts as a unary operator with the same low operator precedence as `cast()`.
In practice most throw expressions will look like `throw new Exception()`, but there is a chance that disambiguation is needed when operator overloading is used:
```D
throw E0 + E1 => (throw E0) + E1
throw E0 = E1 => (throw E0) = E1
```

**(5) A function that returns `auto` may be inferred `noreturn` if every code path ends in an endless loop or expression of type `noreturn`.**

Control flow exiting the function counts as `void`, not `noreturn`, since users are used to implicit `return` statements at the end of a `void` function.
```D
// return type `void`
auto main() {
    import std;
    writeln("hello world");
}

// return type `noreturn`
auto foo(int x) {
    if (x > 0) {
        throw new Exception("");
    } else if (x < 0) {
        while(true) {}
    } else {
        cast(noreturn) main();
    }
}
```

### Properties of `noreturn`:

```D
noreturn.mangleof == "!";
```
This choice is mostly arbitrary, but using "!" is short and consistent with Rust's name.

Currently, `typeof(null).mangleof` == "n".
This will be changed to "p!" (pointer to bottom type).
This might cause linking errors with separate compilation when different translation units are compiled with different D versions.
However, actually using `typeof(null)` in a function signature is extremely uncommon outside of templates, so in practice this issue should not manifest.

```D
noreturn.sizeof == 0;
```
What is the size of the bottom type?
Some possibilities are:
- If something of type `A*` converts to something of type `B*` without issue, then one would expect `B.sizeof <= A.sizeof`. This would imply that `noreturn.sizeof >= size_t.max`. [(Argued by Timon Gehr)](https://forum.dlang.org/post/okfmt3$vdi$1@digitalmars.com)
- A boolean requires log2(2)=1 bits of storage, a unit type log2(1)=0 bits. Since the bottom type has 0 values, it requires log2(0) bits storage, which is undefined. It approaches -Infinity in the limit.
- There is no meaningful size, so the size is the bottom value `⊥`, which implicitly converts to a `size_t`. The expression `noreturn.sizeof` is lowered to `assert(0)`.
- A `union` has the size of the largest member. Adding a `noreturn` field to a `union` never increases the size, so its size is `0`.

The last definition seems the simplest and most useful, so it is the one proposed.

```D
noreturn.alignof == 0;
```
Every pointer to type `T` with alignof `n` must have an address `n*k` for some integer `k`.
Choosing `n = 0` forces every `T*` to be at address 0, which is the case for `typeof(null)`.

```D
noreturn.init == assert(0);
```
The type `noreturn` has no values, so there is no `init` value either (or the init value is the bottom value `⊥`).
Any time `noreturn.init` appears in code, it is lowered to `assert(0)`.

```D
noreturn*.sizeof == size_t.sizeof;
noreturn[].sizeof == size_t.sizeof * 2;
```
While a `noreturn*` can have only one value requiring 0 bits of storage, the size is still chosen to be the same as every other pointer.
This is consistent with the current `typeof(null).sizeof` which also equals `size_t.sizeof`.

Just like `typeof(null)`, `typeof([])` requires no storage since it has only one value.
However, the size of a `T[]` should be consistent with this `struct` definition:
```D
struct slice(T) {
    size_t length;
    T* ptr;
}
```

### Interaction with other language features

The previous DIP proposed allowing the bottom type to be used only as a return type, similar to `void`.
Such restrictions prevent the bottom type of being a useful degenerate case and instead introduces new edge cases.
It is proposed that usage of the bottom type is allowed, and that such usage results in the insertion of `assert(0)` expressions.

**Fields / members**

Using `noreturn` _at global scope_ results in a compilation error.
```D
int a = throw new Exception("nope");
```
The above is type-sound: the newly proposed throw expression has type `noreturn`, and `noreturn` is a subtype of `int`.
However, semantically it means that the program will never be able to reach `main`.
Therefore, an error is still raised, similar to errors during compile-time function evaluation:
```D
int a = () {throw new Exception(""); return int.init;}();
// Error: uncaught CTFE exception`
```
Defining a local variable as `noreturn` generates an `assert(0)` as soon as the variable is live.
Since D does not allow skipping over initializations with e.g., `goto`, this simply means at the point of declaration.

Using `void` initialization does not make a difference on a `noreturn` field; it can be seen as giving the type a random value with a biased distribution (based on garbage memory on the stack).
For a bottom type, this will always be the bottom value, generating an `assert(0)`.

Giving a `struct` a `noreturn` field ensures it contains the bottom value, so it collapses into a `noreturn` type (though properties such as `.sizeof` and `.alignof` are retained).
Defining a `struct` with a `noreturn` field is allowed, but as soon as it is used it generates an `assert(0)`.

Adding a `noreturn` field to a `union` does essentially nothing.
A `union` can be seen as a sum-type with possibly ambiguous bit-patterns, so the type-system leaves figuring out the correct type up to the programmer (e.g. by implementing a [tagged union](https://en.wikipedia.org/wiki/Tagged_union)).
Every type already implicitly includes the bottom value `⊥`, so adding the bottom type member to a `union` doesn't contribute to the set of possible values.
Accessing the `noreturn` field generates an `assert(0)` expression.

An `enum` can have type `noreturn`, but all members must be given an explicit initial value (which must be the bottom value).
Normally the compiler will automatically assign values to `enum` members for integral values (like `bool` and `int`) by counting from `0` up to the maximum, and give a compile-time overflow error afterwards.
The `noreturn` type immediately overflows on the first `enum` member by this reasoning.

A static array of `noreturn` with length `0` is a unit type.
A static array of `noreturn` with positive length `N` is equivalent to a struct with `N` fields with type `noreturn`: it can be defined, but using it results in `assert(0)`.

Both the D function `main` and `extern(C) main` are allowed to have the return type `noreturn`.

Some examples illustrating the above:

```D
noreturn x0; // compile error, must have bottom value
noreturn* x1 = null; // fine, unit type
noreturn[] x2 = []; // fine, unit type
noreturn[0] x3 = []; // fine, unit type
noreturn[1] x4; // compile error, init value is [assert(0)]
struct S {int x; noreturn y;} // definition is fine
S x5; // compile error, must have bottom value
union U {int x; noreturn y;} // U.init.y == assert(0)
U x6; // fine, programmer can assume U represents an int
enum E : noreturn {x = assert(0), y = assert(0)}
E e; // compile error, must have bottom value

int foo(U u) {
    import std;
    writeln("this will get printed");
    if (u.x > 0) {
        noreturn a; // assert(0)
        writeln("this is dead code");
    } else if (u.x < 0) {
        u.z = U.init.z; // assert(0)
        writeln("this is dead code");
    }
    writeln("x is 0");
    noreturn b = void; // = void doesn't make a difference
    writeln("this is dead code, no need to return an int");
}
```

**Expressions**

The [order of evaluation](https://dlang.org/spec/expression.html#order-of-evaluation) of operands in binary expressions / parameter lists is defined to be from left to right.
The use of bottom values adheres to this:
```D
int foo(int x, int y, string z);
int counter;

auto bar() {
    return foo(counter = 0, throw new Exception("left"), assert(0, "right"));
}
```
Function bar is equivalent to:
```D
noreturn bar() {
    counter = 0;
    throw new Exception("left");
}
```

Special cases to the order of evaluation are boolean or (`||`), boolean and (`&&`), the ternary operator, and assignExpressions.
These still behave as one would expect:
```D
a || assert(0); // crash if a is false, type bool
a && assert(0); // crash if a is true, type bool
a ? b : assert(0); // crash if a is false, typeof(b)
a ? assert(0) : b; // crash if a is true, typeof(b)

int[] arr;
arr[assert(0, "left")] = assert(0, "right"); // implementation defined whether assert message is "left" or "right"
```

**The cast operator**

Every type is allowed to be _explicitly_ cast to `noreturn`.
(Not to be confused with `noreturn` _implicitly_ casting to every type.)
It generates an `assert(0)`:
```D
int x;
int bar();
auto foo() {
    cast(noreturn) (x = bar()); // same as {x = bar(); assert(0);}
}
```

**Storage classes**

Storage classes may be added to a declaration with type `noreturn`.
Since these declarations do not generate any storage, they will not affect code generation.
They still feel the effects of storage classes, though, so that one cannot breach e.g., `scope` or `immutable` with `noreturn`.

```D
void foo(scope noreturn* ptr) {
    static noreturn* gPtr;
    immutable noreturn x;
    x = assert(0); // compilation error: assigning to immutable
    gPtr = ptr; // compilation error: ptr escapes function
}
```

**Classes**

A `class` may not inherit from `noreturn`.
While `noreturn` is a subtype of `Object`, defining a subtype of the bottom type is hard to reason about and adds compiler complexity.
If it turns out that inheriting from `noreturn` makes sense in generic code, this restriction may be lifted in the future.

Currently, an overriding method allows a covariant return type but not contravariant parameter types.
This means that when overriding a method that returns type `T`, a subtype of `T` is also allowed.
When overriding parameters, there needs to be an exact match however.

```D
class A {
    A foo(A param) {
        return param;
    }
}

class B {
    // return type B is allowed since B < A
    // parameter type Object is not allowed desipte A < Object
    override B foo(Object param) {
        assert(0);
    }
}
```

The addition of a bottom type does not change these rules; an override of a function returning a `T` may have return type `noreturn` (since `noreturn` is a subtype of every `T`), but a parameter of type `noreturn` may not be replaced by `T` (despite `T` being a supertype of `noreturn`).

### Grammar changes
Throw stratements become expressions so they may be used in lambda functions.

```diff
NonEmptyStatementNoCaseNoDefault:
- ThrowStatement

- ThrowStatement:
-    throw Expression ;

UnaryExpression:
+ ThrowExpression

+ ThrowExpression:
+    throw Expression
```

### Limitations
Though C functions may be declared using the `noreturn` type because of the implicit conversion and no name mangling, C++ function pointers have the return type in their mangling.
When interfacing with C++ functions, changing the return type to `noreturn` when it has the `[[ noreturn ]]` attribute is not always possible.
Since C++ has no type for it, `noreturn` in `extern(C++)` can be mangled as `void`, which is a common return type for `[[ noreturn ]]` functions in C++.
When the return type isn't void, it can still be worked around by either ignoring the `[[ noreturn ]]` or adding wrapper code:

```D
extern(C++) int cppExit(); // returns int for some reason

void main() {
    writeln("hello world");
    cppExit(); // won't return, but who cares?
}

// dExit can be used and it will interact with the type system correctly
noreturn dExit() {
    cast(noreturn) cppExit();
}

// the burden can also be put on the caller
auto f = () => cast(noreturn) cppExit();
```

### Alternatives
It has been proposed that an attribute such as `@noreturn` could be a simpler solution for specifying that a function does not return.
Many C compilers have a specific attribute like this, and C++11 even introduced a standard `[[noreturn]]` annotation.
Since the DMD, LDC, and GDC compilers each use a C-backend that supports the notion of "no return" functions, it could simply be unified in library code:
```D
version (LDC)
    enum noreturn = ldc.attributes.llvmAttr("noreturn"));
else version (GDC)
    enum noreturn = gcc.attribute.attribute("noreturn");
else version (DigitalMars)
    enum noreturn = pragma(noreturn); // example syntax

// usage:
@noreturn void exit();
```

It has been claimed that since functions that do not return are rare, the added compiler complexity from adding a bottom type is not worth the benefit.
However, an attribute does not solve the issues raised above such as the types of `[]` and `null`, or throwing exceptions in lambda functions.
It also becomes the burden of the programmer instead of the type system to handle the "no return" type information correctly.

```D
// with noreturn type
auto copyFunc(alias func, T...)(T params) {
    return func(params);
}

// with noreturn attribute
template copyFunc(alias func) {
    import std.traits: hasUDA;
    static if (hasUDA!(func, noreturn)) {
        @noreturn auto copyFunc(T...)(T params) {
            return func(params);
        }
    } else {
        auto copyFunc(T...)(T params) {
            return func(params);
        }
    }
}
```
Other proposals like `@disable(return)`, or out-contracts (`out(false)`), make it even harder to maintain this type information.

Even in C, sometimes the limitations of `noreturn` as an attribute show, and a comment is needed to explain what is happening:
[duktape public api](https://github.com/svaarala/duktape/blob/9fd93f16e85408cfa41bb5bbc12ac37c3d5ffe07/src-input/duktape.h.in#L416)
> The calls are noreturn but with a return value to allow the "return duk_error(...)" idiom.
> This may cause some compiler warnings, but without noreturn the generated code is often worse.

## Breaking Changes and Deprecations

Any code assuming `is(typeof([]) == void[])` will break.
It is unknown whether this is a common occurance, but it is suspected that `typeof([])` is rarely used since there is little reason for it.

## Reference

[1] [Category Theory for Programmers (Section 2.3 "What are types?" - Page 16)](http://static.latexstudio.net/wp-content/uploads/2017/12/category-theory-for-programmers.pdf)

## Copyright & License

Copyright (c) 2020 by the D Language Foundation

Licensed under Creative Commons Zero 1.0

## Reviews
