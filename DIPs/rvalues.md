# `ref T` Function Parameters Accept R-Values

| Field           | Value    |
|-----------------|-----------------------------------------------------------------|
| DIP:            | TBA |
| Review Count:   | 0 |
| Author:         | Manu Evans, Walter Bright, Andrei Alexandrescu |
| Status:         | Draft |

## Abstract

This is a reboot of
[DIP 1016](https://raw.githubusercontent.com/dlang/DIPs/master/DIPs/rejected/DIP1016.md)
by Manu Evans. Some of the material here has been adapted from it.

Currently, functions that receive arguments by reference in the form of `ref` parameters do not
accept rvalues. This is inconvenient, leading to workarounds (such as user-inserted named
variables) that interfere with straightforward expression of algorithms.

This DIP proposes automatic insertion of temporary lvalues by the compiler, which are initialized
with the rvalue, passed by reference to the function, and then destroyed.

## Rationale

Function `ref` parameters serve the following two main purposes, which are neither entirely disjoint nor entirely connected:

1. ***Side effects:*** The argument object needs to be updated by the called function. Related, returning a `ref` parameter by `ref` enables safe and efficient "pipelining" of function calls.

1. ***Efficient call and return protocol:*** For objects larger than 1-2 registers in size, passing by pointer may be more efficent than passing by value. Both `ref` parameters and pointer parameters effectively employ pass by pointer; however, safety and convenience considerations make `ref` more desirable than explicit pointers. Even relatively small objects may be expensive to copy. Postblits, the upcoming copy constructor ([DIP 1018](https://github.com/dlang/DIPs/blob/master/DIPs/accepted/DIP1018.md)), and destructors may cause arbitrarily complex code execution. For example, copying reference counted objects entails an indirect increment and an indirect decrement. At scale, these costs may become significant [[1](http://users.cecs.anu.edu.au/~steveb/pubs/papers/rc-ismm-2012.pdf)]. Passing by `ref` avoids these costs.

The core argument of this proposal is that a programmer may be often motivated to use `ref` on a parameter for efficiency purposes only (point 2 above), without necessarily having an interest in modifying the object to which the reference points (point 1).

Currently, only lvalues are allowed as arguments to `ref` parameters, which is appropriate for side effect considerations: modifying an rvalue as a side effect indicates more often a bug than a desirable intent. However, this same restriction is not useful to efficiency-minded programmers, who are forced to use awkward workarounds. A few common ones are listed below.

* Named temporaries effectively convert rvalues to lvalues, so they offer a simple workaround. However, these named temporaries increase code size and decrease its readability because they are not relevant to the problem domain. For example:

```d
struct Point {
  long x, y, z;
  ...
}
Point fun();
double norm(ref const Point);
...
// desired: auto n = norm(fun());
auto tmp = fun();
auto n = norm(tmp);
```

* Explicit pass by pointer may be used instead of pass by `ref`, with the advantage that the calling convention is visible at each call site. However, this convention has negative impact on code readability and safety [[8](https://dlang.org/blog/2016/09/28/how-to-write-trusted-code-in-d/)]. In addition, named temporaries are often still needed because it is illegal to take the address of an rvalue. Example:

```d
struct Point {
  long x, y, z;
  ...
}
Point fun();
double norm(const Point*);
...
// desired: auto n = norm(&(fun()));
auto tmp = fun();
auto n = norm(&tmp);
```

* It is possible to overload a given function on `ref` and value parameters, and arrange code to forward from one version to another. This technique is entirely transparent to the user. Example:

```d
struct Point {
  long x, y, z;
  ...
}
Point fun();
double norm(ref const Point);
double norm(const Point p) { return norm(p); }
...
// desired: auto n = norm(fun());
auto tmp = fun();
auto n = norm(tmp);
```

However, overloading on `ref` and value parameters requires boilerplate that scales combinatorially in the number of parameters. Consider an example with two parameters using the definition of `Point` above:

```d
struct Point {
  long x, y, z;
  ...
}
Point fun();
double distance(ref const Point p1, ref const Point p2); // used by all other overloads
double distance(const Point p1, ref const Point p2) { return distance(p1, p2); }
double distance(ref const Point p1, const Point p2) { return distance(p1, p2); }
double distance(const Point p1, const Point p2)  { return distance(p1, p2); }

```

The number of overloads doubles with each additional parameter that should bind to lvalues or rvalues.

More discussion on rationale and motivating examples can be found in the "Rationale" section of [DIP 1016](https://raw.githubusercontent.com/dlang/DIPs/master/DIPs/rejected/DIP1016.md).

This proposal sets out to relax the rules for binding values to `ref` parameters. The rules are changed so as to allow the use of `ref` parameters for efficiency purposes, yet without running the risk of unwitting errors for code that uses `ref` parameters for side effects.

## Related Work

The work on C++ reference types and binding arguments to reference parameters is closest in intent and semantics. C++ introduced references primarily to support efficient operator overloading. For a brief period of time, pre-standardization C++ allowed rvalues to bind to non-`const` reference parameters, decision described by Bjarne Stroustrup as "one serious mistake" [2, p. 86]. This problem was subsequently solved by restricting rvalues to bind to `const` reference parameters; that way, direct fields of the rvalue could not be modified, which eliminates a large class of bugs. However, this restriction does not carry to pointer fields, so unwitting change of shared state is still possible. This state of affairs is dubbed as "`const` is shallow" [[3](http://drops.dagstuhl.de/opus/volltexte/2016/6102/pdf/LIPIcs-ECOOP-2016-8.pdf)] (i.e. not transitive) within the C++ community. Transitivity of `const` can be emulated via careful encapsulation [4], technique used e.g. throughout the C++ standard library.

C++'s rule of binding rvalues to `const` references [5, 8.5.3] has the advantage that functions accepting `const` references can be called transparently with lvalues and rvalues. However the binding does not count as a conversion, so it is illegal to overload functions on `T` and `const T&` parameters, and consequently it is impossible to distinguish between lvalues and rvalues at the callee level. This state of affairs and the boilerplate required by library solutions [[9](http://www.drdobbs.com/move-constructors/184403855)] has led to the addition of rvalue references in C++11, a comprehensive approach that addresses binding of rvalues directly.

In the Rust language, the reference creation operators `&` and `&mut` may be applied to an rvalue ("value expression" in Rust terminology), and prolongs its lifetime appropriately [[6](https://doc.rust-lang.org/reference/expressions.html)]. The lifetime extension rules are carefully chosen so as to keep all uses of the resulting reference safe.

## Description

In brief, we propose allow an rvalue to be a valid argument for a `ref` parameter by constructing a temporary variable with that value, and passing that temporary as the argument. (The definitions of lvalue, rvalue, and full expression are in the D specification [[10](https://dlang.org/spec/expression.html)].)

### Binding Rules

**Definition:** We call an expression *expr* assignable if and only if there exists some expression *expr<sub>1</sub>* such that the syntactic form *(expr) = (expr<sub>1</sub>)* is a valid expression.

Consider the call *fun(e<sub>1</sub>, e<sub>2</sub>, ..., e<sub>n</sub>)*. For each parameter *ref P<sub>k</sub>* bound to expression *e<sub>k</sub>* of type *E<sub>k</sub>*, the checks below apply in sequence. A passing check short circuits all others.

**Rule 1 "Exact Lvalue Match":** If *e<sub>k</sub>* is an lvalue and *T<sub>k</sub>* is the same as *P<sub>k</sub>*, binding succeeds. (This is the case per the current language rules.) Example:

```d
void fun(ref int);
int x;
fun(x);
```

**Rule 2 "Qualified Lvalue Match":** If *e<sub>k</sub>* is an lvalue and *T<sub>k</sub>* and *P<sub>k</sub>* are qualified versions of the same underlying type *U<sub>k</sub>*, and if *T<sub>k</sub>* is a subtype of *P<sub>k</sub>* per the qualifier subtyping rules in [[7](https://dlang.org/spec/const3.html)], then binding succeeds. (This is the case per the current language rules.) Example:

```d
void fun(ref const int);
int x;
immutable int y;
fun(x);
fun(y);
```

**Rule 3 "Nonassignable Requirement":** If *e<sub>k</sub>* is assignable, then binding fails. This is to prevent a variety of bugs caused by the false expectation that the values passed to the function will be updated. The matter is further discussed in section "The Nonassignable Requirement".

**Rule 4 "Relaxed Binding":** If *T<sub>k</sub>* is implicitly convertible to *P<sub>k</sub>*, the binding succeeds. The binding is effected by inserting a hidden temporary of type *P<sub>k</sub>*, initialized with *e<sub>k</sub>*. The temporary is in turn passed to *fun* by reference, consistent with Rule 1. The exact insertion point of the variable and its lifetime are discussed in section "Lifetime". This rule is new (such code would fail to compile in the current language) and effects the change proposed in this DIP.

### The Nonassignable Requirement

The Nonassignable Requirement is a key constraint proposed in order to preempt a large class of bugs and code evolution issues.

The simplest instance of a potential problem is binding an lvalue of a type _T_ that is distinct, yet convertible to a parameter type *P*. Consider the following example, adapted from Stroustrup [2, p. 86]:

```d
void bump(ref long x) { ++x; }
int counter;
bump(counter);
```

The documentation of `bump` states that the function increments its parameter. The caller may therefore reasonably assume that `counter` will have been incremented after the call to `bump`. However, without the nonassignable requirement, the binding would succeed by inserting a hidden temporary of type `long` initialized with `counter`. The temporary would be incremented by `bump` and then immediately discarded, while `counter` would stay unchanged.

This is not only a bug outright, but also a fragility in code evolution. Even if initially `counter` and `x` have the same type (thus making the call correct), the types may become different during code evolution. The call still compiles and runs, but without effecting `counter`.

The nonassignable requirement filters this class of issues away. The type of `counter` is not the same as the parameter type, so the call does not pass by means of Rule 1 or Rule 2. Then if fails Rule 3 because `counter` is assignable.

A more subtle, but equally dangerous, potential bug prevented is the case of read/write properties. Consider:

```d
struct Widget
{
    public double price;
    ...
}
void applyDiscount(ref double p)
{
    p *= 0.9;
}
```

With this setup, a `Widget` `w` may be discounted by calling `applyDiscount(w.price)` (or `w.price.applyDiscount` by using UFCS). However, consider that code evolution changes `price` from a direct field to a property:

```d
struct Widget
{
    // Field "price" converted to a read/write property
    double price();
    void price(double);
    ...
}
```

Without the nonassignable requirement, all calls of the form `applyDiscount(w.price)` or `w.price.applyDiscount` would still pass semantic checking, yet silently change their meaning - they actually update a temporary that is discarded right after the call. With the nonassignable requirement in place, such calls will fail because `w.price` is assignable.

The proposal does not eliminate all calls of questionable utility. Consider another maintenance step that makes `price` a read-only property:

```d
struct Widget
{
    double price(); // not writeable
    ...
}
```

In such cases, `w.price` is not assignable and calls such as `applyDiscount(w.price)` or `w.price.applyDiscount` will succeed but not perform any meaningful update. A maintainer expecting such calls to fail may be surprised. We consider this is an inevitable price to pay for the gained flexibility.

A similar situation is created by types that use `opIndex` and `opIndexOpAssign` to offer read and write indexed access, i.e. `x = obj[i]` and `obj[i] = x`. The nonassignable requirement prevents calls such as `fun(obj[i])` to compile lest the caller expects the slot will be updated.

Note that D could adapt a strategy similar to C++'s by allowing rvalues of type `T` to bind to `ref const T` parameters, but not to `ref T` parameters. That approach would be correct (and would prevent the same classes of bugs described herein), but would be overly restrictive. This is because D's `const`, being transitive, is more restrictive than C++'s and consequently `const` type interfaces are more narrow in D than in C++.

### Code Generation

All binding of rvalues to `ref` parameters is done by inserting hidden named temporary values. 

The type of each inserted temporary value is the exact type as that of the `ref` parameter requiring it (i.e. not the same as the type of the rvalue bound to it).

In expressions containing rvalues bound to `ref` parameters, the order of evaluation of expressions and the lifetime of temporaries thus generated remain the same as if the `ref` parameters would be value parameters of the same type. Put another way, changing a function parameter from `T` to `ref T` or back should not change the order of evaluation and the lifetime of temporaries. This DIP simply increases the number of accepted function calls.

Given that the order of evaluation and lifetime of temporaries are currently underspecified, this DIP includes a specification thereof, based on existing practice in the reference front-end.

A function's arguments are evaluated left to right just before passing control flow to the function. Example:

```d
void fun(int, int, int);
int g();
int h();
int i();
fun(g(), h(), i()); // evaluates g() then h() then i()
                    // after which control is transferred to the callee
```

For each evaluation that yields a temporary value, the lifetime of each temporary value begins at the evaluation point, similarly to creation of a regular value initialized with an expression.

Evaluation is carried depth-first, i.e. if a function call includes other function calls that requires their own evaluation, those will be resolved transitively before the top function call is issued. Example:

```d
void function(int a, int b, int c) fun();
int g();
int h(int);
int i();
int j();
fun(g(), h(j()), i()); // evaluates g() then j() then h() then i()
                       // after which control is transferred to the callee
```

If getting the callee requires its own evaluation (e.g. a computed function pointer), that evaluation is carried after all temporaries have been evaluated and just before the callee is invoked. Example:

```d
void function(int, int) fun();
int g();
int h();
fun()(g(), h()); // evaluates g() then h() then fun()
                 // after which control is transferred to the callee
```

**Definition ("Smallest short-circuit expression"):** Given an expression _expr_ that is a subexpression of a full expression _fullexpr_, the smallest short-circuit expression, if any, is the shortest subexpression _scexpr_ of _fullexpr_ that is an _AndAndExpression_ (`&&`) or an _OrOrExpression_ (`||`) [[11](https://dlang.org/spec/grammar.html)], such that _expr_ is a subexpression of _scexpr_.

Example: in the expression `((f() * 2 && g()) + 1) || h()`, the smallest short-circuit expression of the subexpression `f() * 2` is `f() * 2 && g()`. In the expression `(f() && g()) + h()`, the subexpression `h()` has no smallest short-circuit expression.

We are now ready to define where destructors of temporary variables created during expression evaluation are inserted.

Destructors of temporaries created for the purpose of invoking a given function are inserted as follows:

* If the function call has a smallest short-circuit expression _expr_, and if the call is on the right-hand side of the `&&` or `||` operator, and if the right-hand side is evaluated, then temporary destructors are evaluated right after the right-hand side expression has been evaluated and converted to `bool`. The order of destruction for temporaries inserted for a given function call is the inverse order of construction.

* For all other cases, the temporaries generated for the purpose of invoking functions are deferred to the end of the full expression. The order of destruction is inverse to the order of construction.

An intuition behind these rules is that destructors of temporaries are deferred to the end of full expression and in reverse order of construction, with the exception that the right-hand side of `&&` and `||` are considered their own full expressions even when part of larger expressions.

One difficulty in implementing these rules is related to the ternary operator `?:`. In the expression _e<sub>1</sub> ? e<sub>2</sub> : e<sub>3</sub>_, if either or both _e<sub>2</sub>_ and _e<sub>3</sub>_ creates temporary variables, their destructors must be deferred to the end of the full expression and conditionally executed (only for the one expression that ended up being evaluated of _e<sub>2</sub>_ and _e<sub>3</sub>_). Practically this means the compiler must introduce and maintain additional Boolean state variables that track which destructors must run. This difficulty, however, is not related to this DIP and has already been addressed in the current front-end.

### Function Returns via Hidden Pointer

Depending on the ABI, functions that return an object may be constructing the return value
into a temporary in the caller's scope via a hidden parameter passed to the function by
the caller. In this case, that temporary is used as the argument, rather than copying it to
another temporary. Example:

```d
struct S { ... }
S fun();
void gun(ref S);
...
gun(fun()); 
```

It is up to the compiler whether the object created by the call to `fun()` is reused by `gun()`, or copied once into a temporary. In either case, destruction rules remain the same as discussed above.

### Default Parameters

Rvalues can be provided as defaults to `ref` parameters and are typechecked as if they were explicitly passed by caller code.

# Breaking Changes

This enables code that did not compile before to now compile. Code that relied on
it not compiling before (i.e. `if (__traits(compiles, ...)) ...`) will no longer work.

# References

[1] http://users.cecs.anu.edu.au/~steveb/pubs/papers/rc-ismm-2012.pdf

[2] Bjarne Stroustrup, "The design and evolution of C++", ACM Press/Addison-Wesley Publishing Co. New York, NY, USA ©1994, ISBN 0-201-54330-3

[3] http://drops.dagstuhl.de/opus/volltexte/2016/6102/pdf/LIPIcs-ECOOP-2016-8.pdf

[4] https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines#con2-by-default-make-member-functions-const

[5] International Standard ISO/IEC 14882, Programming Languages &mdash; C++

[6] https://doc.rust-lang.org/reference/expressions.html

[7] https://dlang.org/spec/const3.html

[8] https://dlang.org/blog/2016/09/28/how-to-write-trusted-code-in-d/

[9] http://www.drdobbs.com/move-constructors/184403855

[10] https://dlang.org/spec/expression.html

[11] https://dlang.org/spec/grammar.html
