# Sum Type by Struct

| Field           | Value                                                        |
|-----------------|--------------------------------------------------------------|
| DIP:            | TBD                                                          |
| Author:         | Richard (Rikki) Andrew Cattermole <firstname@lastname.co.nz> |
| Implementation: | https://github.com/dlang/dmd/pull/23540                      |
| Status:         | Draft                                                        |

## Abstract

Add `__sumtype` declarations and `.match` expressions to the D programming language, providing algebraic data types with exhaustive pattern matching support. Match expressions are lowered to `CondExp` (ternary) chains during semantic analysis, eliminating the need for special handling in the code generator or CTFE interpreter.

## Contents
* [Rationale](#rationale)
* [Prior Work](#prior-work)
* [Description](#description)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Reference](#reference)
* [Copyright & License](#copyright--license)
* [History](#history)

## Rationale

Sum types (also known as tagged unions, discriminated unions, or algebraic data types) are a fundamental building block in modern type-safe programming. They allow expressing that a value is one of several possible types, with compile-time guarantees that all cases are handled. This eliminates entire classes of bugs related to invalid state representations and missing error handling.

Languages like Rust, Swift, and Haskell demonstrate that first-class sum types with pattern matching are essential for writing safe, expressive code. D currently lacks this capability at the language level, forcing users to rely on library solutions that cannot provide the same safety guarantees or feature set.

### Safety: Compiler-Enforced Borrows

A language-level sumtype enables **compiler-enforced borrow checking** for by-reference match arms. When a match arm binds a variant by reference (`(ref int x) => ...`), the compiler can track that reference as a borrow of the sumtype's storage, preventing use-after-free, double-free, or invalidation while the borrow is active.

Library solutions like `std.sumtype` cannot provide this guarantee. A library match handler receives a reference to the variant data, but the compiler has no knowledge that this reference borrows the original sumtype. The library cannot prevent the user from:
- Storing the reference beyond the match expression's scope
- Modifying the sumtype while the reference is alive
- Creating multiple mutable references to the same storage

With compiler support, by-ref match arms participate in D's lifetime and safety system the same way `ref` parameters do, making pattern matching on sumtypes as safe as passing references to functions.

### Comparison with `std.sumtype`

`std.sumtype` is the primary existing way to express sum types in D. A language-level sumtype does not replace it; it provides a first-class syntax and semantics that the library template must work around:

| Capability | `std.sumtype` | `__sumtype` |
|------------|---------------|-------------|
| Declaration | `SumType!(int, string)` template instantiation | `__sumtype S = int \| string;` declaration |
| Exhaustiveness | `@safe` match requires explicit `default`, otherwise silently non-exhaustive | Enforced at compile time; guarded arms require a catch-all |
| Match syntax | `match!(Handler1, Handler2)(value)` with static-callable handlers | `value.match { (int i) => ..., (string s) => ... }` |
| Named variants | Not possible without breaking backwards compatibility | `__sumtype S = int x \| bool y;` with `.x`, `.y`, and auto-tag assignment |
| Tag access | `typeIndex` property (`size_t`) | `.tag` field, smallest power-of-2 unsigned type |
| Cross-sumtype conversion | Manual `match` to rebuild | Implicit widening when the target is a superset |
| Overlap with `Nullable`/`Option` | `Nullable` re-implements union edge cases itself | The `None` default-variant mechanism subsumes the "no value" case |
| Debugging | Template-instantiation error messages | Direct compiler diagnostics on the declaration |
| Borrow safety | No compiler enforcement; references escape match scope | Compiler-enforced borrow checking for `ref` arms |
| Multi-level matching | Not supported | Tuple matching for multi-value decision logic |

The library form remains fully supported and continues to serve code that needs template-computed variant sets or cannot migrate. The language form is additive.

## Prior Work

- **Rust enums**: Full algebraic data types with pattern matching via `match`
- **Haskell ADTs**: `data` declarations with `case` expressions
- **OCaml variants**: Polymorphic variants with pattern matching
- **Swift enums**: Associated values with `switch` pattern matching, `case`-based declaration syntax
- **TypeScript discriminated unions**: Structural pattern matching via switch
- **C++17 `std::variant`**: Library-level `std::visit` visitation and `std::get` access
- **Boost.Variant**: Earlier library-level variant with compile-time visitation
- **C11 `_Generic`**: Compile-time type selection (used as a reference for `GenericExp`)
- **D `std.sumtype`**: Library-level implementation using templates and `static foreach`
- **D `std.variant` / `Algebraic`**: The original library sum type, now largely superseded by `std.sumtype`
- **mir `algebraic`**: Third-party library sum type; mir's `nullable` is defined as `algebraic!(typeof(null), T)`
- **DIP 1048** (`match` statement/expression): The pattern-matching proposal this design's match lowering is compatible with
- **Prior D sum-type DIP drafts**: Multiple earlier proposals explored enum-based (Walter Bright), union-based (Paul Backus), and struct/member-based (Rikki Cattermole) designs; the declaration and semantics here draw on the union-based design's tag strategy while adopting the library-first syntax of `std.sumtype`

### Pattern Matching Syntax Approaches

Pattern matching has its roots in the ML family of languages (Meta Language, 1973), where `case` expressions over algebraic types were a foundational construct. This heritage influenced most modern languages with sum types and matching.

**Historical lineage:**

- **ML (1973)**: Introduced `case` expressions for pattern matching on algebraic types; the pattern-matching compiler techniques (decision trees, exhaustiveness checking) originate here
- **Standard ML (1990)**: Formalized pattern matching with `case ... of ...` syntax and ex checking
- **Haskell (1990)**: Adopted `case` expressions with pattern matching; added guards and `where` clauses
- **OCaml (1996)**: Extended ML with polymorphic variants and pattern matching; `match ... with` syntax
- **F# (2005)**: OCaml-like `match ... with` patterns on .NET
- **Scala (2011)**: `match` expression with case classes and extractor patterns
- **Rust (2015)**: `match` expression with irrefutable patterns and exhaustiveness checking
- **Swift (2014)**: `switch` statement with pattern matching and associated values

**Two primary syntax approaches** exist for pattern matching: **dot-call match expressions** (`.match { }`) and **switch expressions** (`switch (x) { case ... => ... }`).

**Dot-call match expressions** (`value.match { (Type x) => ... }`):
- Chains naturally via UFCS: `value.match { ... }.match { ... }`
- Each match is a self-contained expression; no separate keyword needed
- Pattern matching is an operation on the subject value
- Used in this DIP proposal

**Switch expressions** (`switch (value) { case Type x => ... }`):
- Familiar to C/Java programmers; extends existing `switch` semantics
- Requires `case` keywords for each arm (more verbose)
- Subject value is named once at the top, not at each call site
- Can be chained by nesting: `switch (x) { case A => switch (y) { case B => ... } }`
- Examples: Rust (`match`), Swift (`switch`), and PR #23744's `enum union` approach

**Concrete examples by language:**

```ocaml
(* OCaml: match with patterns *)
match expr with
| Pattern1 -> result1
| Pattern2 when guard -> result2
| _ -> default
```

```rust
// Rust: match expression
match value {
    Some(x) if x > 0 => x,
    Some(_) => 0,
    None => -1,
}
```

```swift
// Swift: switch with associated values
switch event {
    case .httpRequest(let method, let path):
        handle(method, path)
    case .ping:
        break
}
```

PR #23744 demonstrates an `enum union` approach: a Rust/Swift-style tagged union declared with `enum union Name { case Type1, case Type2(args) }` and matched via `switch` expressions with fat-arrow arms and comma separators. Variants can be bare types, unit variants, tuple-like variants, or named record variants with embedded methods.

The choice between `.match` and `switch` expressions affects:
- **Verbosity**: `switch` requires `case` keywords; `.match` uses parentheses only
- **Chaining**: `.match` chains naturally as if it were via UFCS; `switch` requires explicit nesting

This DIP uses `.match` for its chaining capabilities and cleaner syntax, while remaining compatible with `switch`-based lowering.

## Description

### Declaration Syntax

Three forms are supported:

```d
// Form 1: Block declaration form (most common)
__sumtype S = int | bool;

// Form 2: Named declaration form
__sumtype Named = int x | bool y;

// Form 3: Template declaration form
__sumtype S(Types...) = Types | bool;
```

`__sumtype` may **only** appear as a declaration keyword. An inline type-expression form (`__sumtype(int | string)`) is not part of the syntax; sumtype values are constructed via the lowered struct, which is exposed through the declared name.

### Template Declarations and Alias Sequences

A sumtype may be declared as a template. The template parameter list follows the identifier, and an alias sequence parameter auto-expands into its component variants:

```d
__sumtype S(Types...) = Types | bool;

__sumtype S2 = int | string; // separate declaration
```

When instantiated with `S!(int, string)`, the alias sequence `Types` expands into the variants `int` and `string`, and `bool` is appended, giving the three variants `int | string | bool`. An empty alias sequence (e.g. `S!()`) contributes no variants; a remaining single variant degenerates to a plain alias of that type.

Each instantiation is independent: the variant list is resolved per-instantiation, so `S!(long, double)` does not reuse the variants resolved for `S!(int, string)`.

The generated members are the same as the non-template form. For `S!(int, string)` — `int | string | bool` — the lowered struct has six members: `tag`, `__v0`, `__v1`, `__v2`, `toHash`, and `opCmp`:

```d
static assert(__traits(allMembers, S!(int, string)).length == 6);
static assert(__traits(hasMember, S!(int, string), "opCmp"));
static assert(__traits(hasMember, S!(int, string), "toHash"));
```

`opCmp` is generated because every variant is orderable — including `bool`, since `bool` is orderable in D (`false < true`). No copy constructor is generated for this instantiation because none of the variants require one for safe copying (all are POD); see [Copy Constructor](#copy-constructor).

### Variant Naming

Variants may optionally have names. Named variants enable:
- Named constructor syntax: `Named(x: 42)`
- Direct field access: `n.x`
- Auto-tag assignment: `n.x = 42` automatically sets `n.tag`
- Name-based match arm dispatch: `(int x) => ...` matches by name when variants are named

```d
__sumtype Named = int x | bool y;

Named n = Named(x: 42);  // Named constructor
n.x = 10;                // Auto-tag: sets tag = 0, x = 10
n.y = true;              // Auto-tag: sets tag = 1, y = true
```

### Internal Representation

Sumtypes are lowered to structs with the following layout:

| Field | Type | Description |
|-------|------|-------------|
| `tag` | dynamically sized | Index of the active variant. Type is the smallest power-of-2 unsigned integer that fits all variant indices: `ubyte` (≤256 variants), `ushort` (≤65536), `uint` (≤4294967296), `ulong` (larger). Default-initialized to the default variant index. |
| `<name>` or `__vN` | variant type | Variant fields, overlaid in an anonymous union. The default variant field is initialized to its type's `.init` in the struct's `.init`. |

Single-variant sumtypes degenerate to a simple alias — zero tag overhead, identical ABI.

#### Layout Examples

```d
// 2 variants: ubyte tag (1 byte)
__sumtype Small = byte | bool;
// struct { ubyte tag; union { byte __v0; bool __v1; } }
// sizeof == 2 (tag(1) + union(1))

// 3 variants: ubyte tag (1 byte)
__sumtype Med = int | bool | char;
// struct { ubyte tag; union { int __v0; bool __v1; char __v2; } }
// sizeof == 8 (tag(1) + pad(3) + union(4))

// Large variant: normal alignment
__sumtype Large = char | int;
// struct { ubyte tag; union { char __v0; int __v1; } }
// sizeof == 8 (tag(1) + pad(3) + union(4))

// Tag is always at offset 0
// Small.tag.offsetof == 0
// Small.__v0.offsetof == 1
```

### Match Expression Syntax

Match expressions use `.match { arms }` syntax with lambda-like arms:

```d
// Basic match
auto result = val.match {
    (int i)    => i * 2,
    (bool b)   => b ? 1 : 0,
    (string s) => s.length
};

// Catch-all arm (typeless parameter matches any variant)
auto fallback = val.match {
    (int i) => i,
    (other) => -1  // matches bool and string
};

// Guard expressions
auto filtered = val.match {
    (int i) if (i > 0)  => i,
    (int i)              => -i,
    (other)              => 0
};
```

#### Arm Syntax

```
arm := '(' [storageClass] [type] ident ')' [if '(' expr ')' ] '=>' expr
```

- **Typed arm**: `(int x) => x * 2` — matches only the `int` variant
- **Catch-all arm**: `(x) => 42` — matches any variant, parameter type inferred from variant
- **Ref arm**: `(ref int x) => x = 5` — binds by reference (for mutable access)
- **Guarded arm**: `(int x) if (x > 0) => x` — matches only when guard condition is true

Block bodies (`{ ... }`) are **not supported** — only expression bodies (`=> expr`).

### Match Expression Semantics

#### Exhaustiveness Checking

Match expressions **must** handle all variants. The compiler enforces:

1. Count variants covered by **unguarded** typed arms (by name or position)
2. Guarded arms do **not** count toward exhaustiveness (a guard may fail at runtime)
3. If all covered AND catch-all present → **error**: redundant catch-all
4. If not all covered AND no catch-all → **error**: non-exhaustive match
5. If all covered and no catch-all → OK
6. If not all covered and catch-all present → OK (catch-all covers remaining)

```d
// OK: unguarded arms cover all variants
val.match { (int i) => i, (bool b) => 1 }

// OK: catch-all covers remaining when guard may fail
val.match { (int i) if (i > 0) => i, (other) => 0 }

// Error: non-exhaustive — guarded arm alone doesn't cover int
val.match { (int i) if (i > 0) => i, (bool b) => 1 }
```

##### By-ref Parameters

If a match arm parameter is ``ref``, it is required to trigger a borrow checker in ``@safe`` code.

If no borrow checker is available, then it is an error.

The purpose of this is to prevent program corruption:

```d
void matchBorrow() @safe
{
    __sumtype ST = int* | int;

    int modify(ref ST st) => 2;    // I could modify the sumtype and corrupt memory!

    ST st;
    st.match {                     // Borrowed here
        (int v) => 0,
        (ref int* v) => modify(st) // Error: Cannot pass the owner of an active borrow to a function that may mutate it
                                   // Parameter `st` must be const or immutable
    };
}
```

The fast DFA engine produced the above error.

#### Return Type

When arms return different types, the match result is a sumtype. The compiler unifies the arm result types and, if necessary, produces a synthetic sumtype for the result:

- If all arms return the same type `T`, the match result is simply `T` — no sumtype wrapper is generated.
- If arms return different types, the match result is a sumtype whose variants are those types (after integer promotion, see below).

```d
__sumtype S = int | bool;

auto a = S(42).match { (int i) => i, (bool b) => 1 };
// a is of type int — both arms return int (bool promotes to int)

auto b = S(42).match { (int i) => "x", (bool b) => 1 };
// b is of type __sumtype(int | string) — different return types
// (the result sumtype is a compiler-generated struct, not a user-declared name)
```

##### Integer Promotion

When unifying arm result types, integer types are promoted to a common type using the usual D widening rules. `bool` is **not** treated as an integer for promotion purposes.

The promotion rules for two integer types `A` and `B` are:

| Condition | Result |
|-----------|--------|
| Same signedness | The wider of `A` and `B` |
| `A` is signed and strictly wider than `B` (unsigned) | `A` (signed, wider — holds all unsigned values) |
| Same width, different signedness | Promote to the next wider signed type (e.g. `int` + `uint` → `long`) |
| `long` + `ulong` (64-bit signed + 64-bit unsigned) | **Error**: no wider signed type is available |

```d
// int + uint → long
auto a = val.match { (int x) => x, (uint y) => y };
// a is of type long

// long + ulong → error: cannot unify integer types `long` and `ulong`
auto b = val.match { (long x) => x, (ulong y) => y };
// Error: cannot unify integer types `long` and `ulong` — no wider signed type available

// bool is NOT treated as an integer — it stays as a separate variant
auto c = val.match { (int x) => x, (bool b) => b };
// c is of type __sumtype(int | bool)
// (the result sumtype is a compiler-generated struct, not a user-declared name)
```

When a single integer type appears in multiple arms, the maximum needed width and signedness is computed. All integer arms are then represented by that single promoted type in the result sumtype, so the result is not littered with `int`, `uint`, and `long` variants when a single `long` suffices.

##### Result Sumtype Collation

When the compiler generates a synthetic sumtype for a match result, it checks whether an equivalent sumtype already exists. Two match expressions whose arm return types unify to the same set of types (after integer promotion) share a single sumtype definition. This avoids generating a new sumtype struct for every match site.

The collation key is computed by hashing the type and (if present) name of each variant using `mixHash` from `dmd.root.hash` on the pointer values of the type/name objects. Equality is tested pair-wise over the sorted variant list. Because the hash is order-independent, two match expressions with the same variants in different declaration order share a single sumtype.

The collation only applies to **match expression results** — `__sumtype` declarations are not collated against match results, even if they happen to have the same variant set.

#### Lowering Strategy

Match expressions are lowered to `CondExp` chains during semantic analysis:

```
s.match {
    (int x) => x * 2,
    (bool y) => y ? 1 : 0
}
→
s.tag == 0 ? (int __matchArm0 = s.__v0, __matchArm0 * 2)
             : (bool __matchArm1 = s.__v1, __matchArm1 ? 1 : 0)
```

Each branch:
1. Declares a uniquely-named variable initialized with the variant field
2. Substitutes the arm parameter references in the body expression
3. Produces the arm's result value

##### Guard Expression Lowering

Arms with guards are lowered using nested `CondExp` chains. Arms are sorted by variant index, with guarded arms placed before unguarded arms for the same variant. The expression tree is built inside-out: the last arm (unguarded) becomes the base, and earlier guarded arms wrap it.

```
s.match {
    (int v) if (v > 0)  => v,
    (int v)              => -v,
    (bool b)             => 1
}
→
s.tag == 0
    ? (int __matchArm0 = s.__v0,
       __matchArm0 > 0
           ? __matchArm0                                        // guard true
           : (int __matchArm1 = s.__v0, -__matchArm1))         // guard false → fallthrough
    : (bool __matchArm2 = s.__v1, 1)                            // bool arm
```

When all typed arms for a variant are guarded and a catch-all exists, the catch-all is appended as the final fallthrough:

```
s.match {
    (int v) if (v > 100) => v,
    (z) => -1
}
→
s.tag == 0
    ? (int __matchArm0 = s.__v0,
       __matchArm0 > 100
           ? __matchArm0
           : (z __matchArm1 = s.__v0, -1))    // catch-all as fallthrough
    : (bool __matchArm2 = s.__v1, -1)          // catch-all for bool
```

Since the lowering produces standard `CondExp` / `CommaExp` / `DeclarationExp` nodes, no special handling is needed in the code generator (e2ir) or CTFE interpreter (dinterpret).

### Cross-Sumtype Assignment and Widening

A sumtype value is implicitly convertible to a **wider** sumtype — one that contains every variant of the source type — in these contexts:

- **Assignment and initialization**: `S2 s2 = s1;` and `s2 = s1;`
- **Return values**: a function declared to return a wider sumtype can `return` a narrower sumtype value
- **Function call arguments**: a narrower sumtype value can be passed to a parameter whose type is a wider sumtype
- **Argument-to-parameter matching**: overload resolution accepts a sumtype argument for a wider sumtype parameter as a `MATCH.convert` (not an exact match), so such calls resolve normally

```d
__sumtype S1 = int | bool;
__sumtype S2 = int | bool | string;

S1 s1 = S1(42);

// Assignment / initialization
S2 s2 = s1;    // OK: S2 has all S1 variants
s2 = s1;       // OK: assignment also works

// Return value widening
S2 widenReturn() { return s1; }          // OK

// Function call argument widening
void takeWide(S2 s) { }
takeWide(s1);                            // OK

// Argument-to-parameter matching when widening is not an exact match
S2 combine(S2 a, S2 b) { return a; }
auto r = combine(s1, s2);                // OK: s1 matches S2 via widening
```

The lowering generates a `CondExp` chain that checks each source variant's tag and constructs the target sumtype:

```
s2 = s1.tag == 0 ? S2(s1.__v0)    // int case
                : (s1.tag == 1 ? S2(s1.__v1) : assert(0))  // bool case
```

Widening is only allowed when the source is a subset of the target. Narrowing (converting a wider sumtype to a narrower one) is **not** an implicit conversion.

Variant-to-variant mapping during widening prefers an **exact type match** over an implicit conversion. For example, widening `__sumtype S1 = int | bool;` to `__sumtype S2 = int | bool | string;` maps the `bool` variant to the `bool` variant, not to `int` (even though `bool` is implicitly convertible to `int`). This preserves the active variant across the widening.

#### Out of Scope: Overload Dispatch on the Active Variant

Overload resolution is **not** modified to dispatch a sumtype argument to an overload based on its active variant:

```d
int fun(int i)   { return 1; }
int fun(string s) { return 2; }

__sumtype S = int | string;
S s = S(42);
fun(s);  // Error: 'S' does not match either overload — use s.match { ... } instead
```

Dispatch must be expressed explicitly via `.match`. This keeps overload resolution unchanged (and its complexity bounded) while pattern matching provides the dispatch mechanism in one place.

### Variant Name Validation

The compiler enforces the following constraints on variant names:

1. **Duplicate names are rejected**: Two variants in the same sumtype cannot share the same name.
2. **The name `tag` is reserved**: It conflicts with the built-in `.tag` field and is rejected at declaration time.

```d
__sumtype E1 = int x | bool x;   // Error: duplicate variant name 'x'
__sumtype E2 = int tag | bool;    // Error: variant cannot be named 'tag'
```

#### Duplicate Variant Types

Unnamed variants must have **distinct types** — two unnamed variants of the same type are rejected because type-inferred construction (`S(42)`) could not tell them apart:

```d
__sumtype E3 = int | int;        // Error: duplicate type 'int'
```

Named variants may share a type, since names disambiguate construction and access:

```d
__sumtype Form = int phone | int work;  // OK: both are int, distinguished by name

Form f = Form(work: 5551234);           // select the 'work' variant by name
assert(f.work == 5551234);
```

This matches the behavior of `std.sumtype`, which likewise rejects duplicate types among its members.

### Struct Literal Initialization

When constructing a sumtype, the `StructLiteralExp` only initializes the `tag` field and the active variant field. Non-active variant fields are left uninitialized within the anonymous union — the union overlap provides the storage without explicit initialization.

#### Variant Selection for Type-Inferred Constructors

When a single unnamed argument is given, the compiler selects the variant to initialize. An **exact type match** is always preferred over an implicit conversion:

```d
__sumtype S = int | bool;

S s1 = S(true);   // exact match: bool variant (tag 1)
S s2 = S(42);     // exact match: int variant (tag 0)
S s3 = S(cast(byte)7); // no exact match: falls back to implicit conversion → int variant
```

Without this rule, `S(true)` would select the `int` variant because `bool` is implicitly convertible to `int`. Preferring the exact match keeps the number `1` (which represents both `true` and the `int` value `1`) from silently choosing the wrong variant.

If no variant exactly matches, the first variant that accepts an implicit conversion is chosen. If neither an exact match nor an implicit conversion exists, the compiler reports an error.

#### Integer Variant Restriction

To keep type-inferred construction unambiguous, a sumtype may contain **at most one integer type** among its variants. A `bool` variant may additionally be present, and the character types (`char`, `wchar`, `dchar`) do **not** count toward this limit.

```d
__sumtype A = int | bool;        // OK: one integer type (int), plus a bool
__sumtype B = char | int;        // OK: char is not counted, int is the single integer type
__sumtype C = char | int | bool; // OK: one integer (int), plus char and bool

__sumtype E1 = int | long;       // Error: two integer variants
__sumtype E2 = byte | short;     // Error: two integer variants
```

Without this restriction, an integer value such as `1` could match multiple integer variants via implicit conversion (for example, `1` could be stored as `int`, `long`, `uint`, or `bool`), making construction ambiguous.

### Tag Strategy

Tags are assigned by position (0-indexed) in the variant list. The first variant gets tag 0, the second gets tag 1, etc.

The tag type is dynamically sized based on the number of variants, using the smallest power-of-2 unsigned integer type that can represent all variant indices:

| Variants | Tag Type | Size |
|----------|----------|------|
| 1–256 | `ubyte` | 1 byte |
| 257–65536 | `ushort` | 2 bytes |
| 65537–4294967296 | `uint` | 4 bytes |
| >4294967296 | `ulong` | 8 bytes |

The tag is a real field of the lowered struct, so its size, alignment, and offset are observable through the ordinary reflection mechanisms:

```d
__sumtype S = int | bool | string;

static assert(S.tag.offsetof == 0);
static assert(S.tag.alignof == 1);       // ubyte tag
static assert(__traits(hasMember, S, "tag"));
```

#### Tag Safety

Reading `.tag` is `@safe`; it is simply an index of the active variant and exposes no more information than the type system already tracks. Writing `.tag` directly is `@system` — it can desynchronize the tag from the active variant field, so direct writes are restricted to compiler-generated code (match lowering, widening, assignment). User code should assign to the variant fields (which auto-sets the tag) or construct a new sumtype value instead.

#### Foreign-Language Interop

Because the tag is a concrete field of a concrete struct, the sumtype's `sizeof` and `alignof` are well-defined and stable for a given variant set. Foreign code that must interoperate with a sumtype by value only needs to know its size and alignment (available via `S.sizeof` / `S.alignof`); it does not need to know the internal arrangement of the tag and the anonymous union. The ABI of the lowered struct follows the ordinary D struct ABI rules.

### Default Variant

The `tag` field has a default initializer so that `.init` of a sumtype is well-defined:

- If any **unnamed** variant has a type whose identifier is `None` (e.g., `struct None {}`), that variant becomes the default. The tag is initialized to that variant's index, and the corresponding variant field is initialized to its type's `.init`.
- If more than one unnamed `None` variant exists, the compiler reports an error.
- If no unnamed `None` variant exists, the **first variant** is the default (tag = 0).

```d
struct None {}

__sumtype Opt = None | int;
// Opt.init has tag == 0 (None variant is first), __v0 is None.init

__sumtype Opt2 = int | None;
// Opt2.init has tag == 1 (None variant is second)

__sumtype Opt3 = int | bool | None;
// Opt3.init has tag == 2 (None variant is last)

__sumtype Always = int | bool;
// Always.init has tag == 0 (first variant), __v0 is int.init (0)
```

The `.init` and `__traits(initSymbol)` both reflect the correct default tag and variant field values. This ensures that a default-constructed sumtype is always in a valid state.

#### `None` as the basis for `Option` / `Nullable`

The `None` default-variant mechanism is the language-level analogue of the union-based `Option`/`Nullable` pattern: a sumtype with a `None`-like marker variant subsumes the "no value" case that `Nullable` and `std.sumtype`-based `Option` implement with hand-written union edge cases. Because the sumtype machinery already handles initialization, copy/move, and destruction of the active variant, a value of type `__sumtype(None | T)` is a drop-in `Option!T` with correct lifecycle behavior for any `T`, including types with copy constructors, postblits, and destructors — the same edge cases that motivate library `Option` implementations to be built on top of a sum type rather than a raw union.

```d
struct None {}
__sumtype MaybeInt = None | int;

MaybeInt m;              // tag == 0: the None variant
m = MaybeInt(42);        // now holds an int
```

### Sumtype Type Detection

The `is` expression supports the special keyword form `is(T == __sumtype)` to test whether a type is a sumtype:

```d
__sumtype S = int | string;

static assert(is(S == __sumtype));
static assert(!is(int == __sumtype));
```

This works whether `T` is referred to by its declared name or by the lowered struct form of the sumtype; both are recognized as a sumtype. As with other `is(... == Keyword)` forms, `__sumtype` here is a reserved keyword, not a type argument.

Note that a **single-variant** sumtype degenerates to a plain alias of the wrapped type and is therefore **not** detected as a sumtype:

```d
__sumtype Single = int;
static assert(!is(Single == __sumtype)); // Single is just `int`
```

### Value Semantics

Pattern match bindings copy values by default. Use `ref` for mutable access:

```d
val.match {
    (ref int x) => x = 10,  // modifies the variant field
    (bool y) => y ? 1 : 0
}
```

### Generated Functions

The lowered sumtype struct is generated with overlapped variant fields. The compiler generates custom member functions that dispatch to the active variant's hooks based on `tag`.

#### Copy Constructor

When any variant type has a copy constructor or postblit — and no variant disables copying — the compiler generates a copy constructor for the lowered struct. The generated copy constructor copies the `tag` field and triggers copy constructors or postblits on variant fields when needed. For non-struct variants (POD types), it performs a simple blit through the union overlap.

The copy constructor is generated only when required for correct copying — when some variant has a copy constructor or postblit whose invocation a plain union blit would skip, risking memory corruption. Variants with disabled copy constructors or postblits are rejected at declaration time (see [Variant Type Restrictions](#variant-type-restrictions)), and a sumtype whose variants are all POD (e.g. `int | string | bool`) needs no copy constructor at all. This ensures `S b = a;` correctly invokes the inner type's copy constructor or postblit when such a variant is active.

#### Destructor

When any variant type has a destructor, the compiler generates a destructor for the lowered struct that dispatches to the active variant's destructor based on `tag`.

This ensures `S s` going out of scope correctly destroys the active variant.

#### Lifecycle Behavior Summary

- **Copy construction** (`S b = a`): Invokes the generated copy constructor, which dispatches to the variant's copy constructor or postblit.
- **Assignment** (`a = b`): The compiler generates an implicit `opAssign` that calls the copy constructor (per D struct semantics for types with copy constructors).
- **Match arm copies**: Non-ref match arms copy the variant field, invoking the inner type's copy constructor, postblit, or move constructor as appropriate.
- **ref match arms**: Ref arms bind directly to the variant storage without copying. No postblit or copy constructor is invoked.
- **Cross-sumtype assignment**: The lowering constructs a new sumtype value via a match expression, which correctly invokes lifecycle hooks on the constructed value.
- **Destructors on scope exit**: The generated destructor dispatches to the active variant's destructor based on `tag`.

#### Variant Type Restrictions

Sumtypes reject variant types that would violate lifecycle safety:

- **Move-only types** (no copy constructor): Rejected at declaration time.
- **Disabled copy constructors** (`@disable this(ref ...)`): Rejected at declaration time.
- **Disabled postblits** (`@disable this(this)`): Rejected at declaration time.

Additionally, to keep type-inferred construction unambiguous, a sumtype may contain at most one integer type among its variants (see [Integer Variant Restriction](#integer-variant-restriction)).

#### opCmp

The lowered sumtype struct is generated with `opCmp` and `toHash` member functions so that sumtypes can be sorted and used as associative-array keys. The default compiler-generated structural comparison/hashing does **not** work for the anonymous union of variant fields (raw byte hashing of the inactive variant storage is non-deterministic), so these are generated explicitly and dispatch to the active variant based on `tag`.

```d
__sumtype S = int | string;

assert(S(1) < S(2));    // same tag (0): compares int fields
assert(S("a") < S("b")); // same tag (1): compares string fields
assert(S(0) < S("a"));   // different tags: int tag (0) < string tag (1)
```

The method takes its argument by value so it can be called with rvalue temporaries such as `S(1)`, enabling `S(1) < S(2)` and friends.

`bool` variants are orderable (`false < true`), so a sumtype with a `bool` variant still gets a generated `opCmp`; comparisons on a `bool` variant compare `false < true`. `opCmp` is only suppressed when an aggregate variant has an `@disable`d `opCmp` or lacks one (see [Suppression Rules](#suppression-rules)).

#### toHash

The lowered sumtype struct is generated with a `toHash` member function so that sumtypes can be used as associative-array keys. Only the active variant is hashed, so the result is deterministic and consistent with `opEquals`:

```d
__sumtype S = int | string;

int[S] aa;
aa[S(1)]   = 10;
aa[S("a")] = 30;
assert(aa[S(1)] == 10);
assert(aa[S("a")] == 30);
```

The implementation hashes the tag first, then combines the hash of the active variant's field using `hashOf`. This makes the sumtype usable as an associative-array key.

#### Suppression Rules

A generated function is **not** produced when any variant is an aggregate whose corresponding member is `@disable`d (hashes/comparisons on that variant would not compile):

- `toHash` is **not** generated if any aggregate variant has an `@disable`d `toHash`.
- `opCmp` is **not** generated if any aggregate variant has an `@disable`d `opCmp`, or lacks an `opCmp`. Note that `bool` variants are orderable (`false < true`), so they do **not** prevent generation.

```d
struct DisHash { int x; @disable size_t toHash() const; }
struct DisCmp  { int x; @disable int opCmp(ref const DisCmp) const; }

__sumtype S1 = int | DisHash;
__sumtype S2 = int | DisCmp;
__sumtype S3 = int | bool;

static assert(!__traits(hasMember, S1, "toHash"));
static assert(!__traits(hasMember, S2, "opCmp"));
static assert( __traits(hasMember, S3, "opCmp")); // bool is orderable
static assert( __traits(hasMember, S3, "toHash"));
```

### Grammar Changes

**Declaration grammar** (`spec/declaration.dd`):

```
$(GNAME Declaration):
    ...
    $(GLINK SumTypeDeclaration)

$(GNAME SumTypeDeclaration):
    $(D __sumtype) $(GLINK Identifier) $(D =) $(GLINK SumType) $(D ;)
    $(D __sumtype) $(GLINK Identifier) $(GLINK TemplateParameters) $(D =) $(GLINK SumType) $(D ;)

$(GNAME SumTypeVariant):
    $(GLINK Type) $(GLINK Identifier)$(OPT)
```

**Expression grammar** (`spec/expression.dd`):

```
$(GNAME MatchExpression):
    PostfixExpression $(D .) $(D match) $(D $(LBRACE)) $(GLINK MatchArmList) $(D $(RBRACE))

$(GNAME MatchArmList):
    $(GLINK MatchArm)
    $(GLINK MatchArm) $(D ,) $(GSELF MatchArmList)

$(GNAME MatchArm):
    $(D $(LPAREN)) $(GLINK StorageClass)$(OPT) $(GLINK Type)$(OPT) $(GLINK Identifier) $(D $(RPAREN))
    $(D if) $(D $(LPAREN)) $(GLINK AssignExpression) $(D $(RPAREN))$(OPT)
    $(D =>) $(GLINK AssignExpression)
```

### Examples

```d
// Basic sum type usage
__sumtype Result = int | string;

// Match expression with exhaustiveness checking
void process(Result r)
{
    int handleInt(int) => 0;
    int handleError(string) => -1;

    auto msg = r.match {
        (int val)    => handleInt(val),
        (string msg) => handleError(msg)
    };
}

// Catch-all for error handling
void handleAll(Result r)
{
    r.match {
        (int val) => printf("got int: %d\n", val),
        (other)   => printf("got other\n")
    };
}

// Named variants with auto-tag
__sumtype Command = int Move | bool Stop;

void execute(Command cmd)
{
    void move(int) {}
    void halt() => assert(0);
    void continue_() {}

    cmd.match {
        (int dist)  => move(dist),
        (bool stop) => stop ? halt() : continue_()
    };
}

// Guard expressions for conditional matching
__sumtype Signed = int | bool;

void classify(Signed s)
{
    s.match {
        (int v) if (v > 0)  => printf("positive: %d\n", v),
        (int v) if (v < 0)  => printf("negative: %d\n", v),
        (int v)              => printf("zero\n"),
        (bool b)             => printf("bool: %d\n", b)
    };
}

// Guard with catch-all fallback
int clampToHundred(Signed s)
{
    return s.match {
        (int v) if (v > 100) => 100,
        (int v) if (v < 0)   => 0,
        (other)              => cast(int)other  // catch-all
    };
}

// Cross-sumtype assignment and widening
__sumtype S1 = int | bool;
__sumtype S2 = int | bool | string;

S2 widen(S1 s) { return s; }  // implicit conversion (return value widening)

// Exact-match variant selection
__sumtype S = int | bool;
S s = S(true);                 // bool variant (exact match), not int

// Integer variant restriction
__sumtype R = int | bool | char;  // OK: one integer type (int)

// Template declaration with an alias sequence
__sumtype Result2(Types...) = Types | string;

Result2!(int, bool) ok = Result2!(int, bool)(true);   // variants: int | bool | string
Result2!(long, float) wider = Result2!(long, float)(3.5); // independent instantiation
```

## Future Work

Several ideas raised in earlier sum-type discussions are deliberately out of scope for this DIP but noted for possible follow-up:

- **Carry-flag tag elimination**: Walter Bright proposed using the CPU carry flag to store the tag for small sumtypes, avoiding a separate tag field entirely. This is a pure codegen optimization and is orthogonal to the semantics here.
- **Swift-style declaration body**: An alternative declaration form with a braced body (`` `case` ``-style members, conditional compilation via `version`, constructors, and member functions) was raised. The `__sumtype` type-expression form chosen here keeps the feature small and composable; a declarative form can be layered on later.
- **Stable hash-based tags**: An earlier draft keyed tags on a hash of the fully qualified variant name rather than position, making tags stable across variant reordering (and enabling cheaper `switch` over `.tag`). Position-based tags keep the ABI minimal; a `__tagValues`-style hash form can be added if reordering stability is ever needed.
- **`final switch` over `.tag`**: Since `.tag` is a plain unsigned integer, a `switch` over it could eventually get the same exhaustive-case checking as `match`. This would require compiler assistance for "this switch covers every possible tag" and is not part of this DIP.
- **Terminology**: The language community uses both "sumtype" and "sum type". This DIP uses "sumtype" (one word) to match the `__sumtype` keyword and `std.sumtype`; no standard is imposed elsewhere.

### Multi-Level Matching on Tuples

A tuple of values can be matched against patterns that destructure the tuple elements into variables. Each element is bound to a variable without recursive destructuring of nested sumtypes. This enables conditional logic based on multiple values simultaneously.

This is useful when decisions depend on the combination of several values rather than a single sumtype. Instead of nesting multiple match expressions or writing chained if-else conditions, tuple matching expresses the logic in a single, readable construct:

```d
__sumtype Status = Ok | Error | Warning;
__sumtype Priority = Low | Medium | High;

void handle(Status s, int code, Priority p) {
    auto action = tuple(s, code, p).match {
        (Ok,  _, _)         => "proceed",
        (Error, c, High) if (c > 500) => "critical failure",
        (Error, c, _)       => "recoverable error",
        (Warning, _, High)  => "investigate",
        (_, _, _)           => "ignore"
    };
}
```

Tuple matching generalizes the match expression beyond a single sumtype subject. It supports any combination of types — booleans, integers, sumtypes, or other values — making the match construct applicable to multi-value decision tables. Guards provide additional filtering when simple pattern binding is insufficient.

Compared to `switch` statements, tuple matching offers several advantages:

- **Multi-value dispatch**: `switch` operates on a single expression; tuple matching dispatches on multiple values simultaneously without nested switches or compound conditions
- **Chaining**: Match expressions can be chained naturally — the result of one match can feed into another match on a different tuple, keeping each decision step isolated and readable
- **Exhaustiveness**: Like sumtype matching, tuple matching can enforce that all combinations are handled (when no catch-all arm is present)
- **Result unification**: The match result is an expression that can be directly assigned or returned, unlike `switch` which requires separate variable assignment in each case

```d
// Chaining example: each match produces a tuple for the next match
auto step1 = tuple(input, state).match {
    (Valid, Idle)   => tuple(true, Processing),
    (_,     Idle)   => tuple(false, Error),
    (_,     _)      => tuple(false, Busy)
};

auto step2 = step1.match {
    (true,  Processing) => "started",
    (false, Error)      => "failed",
    (false, Busy)       => "retry"
};
```

The result type follows the same unification rules as sumtype match expressions — if arms return different types, the result is a synthetic sumtype.

## Breaking Changes and Deprecations

The `__sumtype` identifier uses the double-underscore prefix reserved for implementation features. The `match` keyword is accessed via `.match { }` syntax, which is unambiguous with the property access form `.match` (no braces). Existing `std.sumtype` library code remains unaffected.

Because `__sumtype` is a new reserved construct, sumtype declarations that would previously have been accepted now report new declaration-time errors: multiple integer variants, duplicate variant names, the reserved variant name `tag`, and variants with move-only or disabled-copy types. No existing D code uses `__sumtype`, so there are no compatibility concerns.

The double-underscore prefix allows immediate adoption without breaking existing code.
A future language edition will introduce ``sumtype`` as a standard keyword."

## Reference

- std.sumtype: https://dlang.org/phobos/std_sumtype.html
- std.variant / Algebraic: https://dlang.org/phobos/std_variant.html
- C++17 std::variant: https://en.cppreference.com/w/cpp/utility/variant
- Boost.Variant: https://www.boost.org/doc/libs/release/doc/html/variant.html
- mir `algebraic`: https://mir-stat.github.io/mir/
- Maranget, L. (2007). "Compiling pattern matching to good decision trees"
- Rust Reference: https://doc.rust-lang.org/reference/enums.html
- Zero-cost exceptions rationale: https://open-std.org/JTC1/SC22/WG21/docs/papers/2018/p0709r0.pdf
- DIP 1048 (`match`): https://github.com/dlang/DIPs/blob/master/DIPs/DIP-1048.md
- POC: Add language-level tagged unions (enum union) and pattern matching (switch expressions)- #23744: https://github.com/dlang/dmd/pull/23744

### Forum Discussions

- "Sum Types - first draft" (Walter Bright, 2022–2024): https://forum.dlang.org/post/kmldxvoatircjrltcoup@forum.dlang.org
- "Enumerated Unions (sum types)" (Paul Backus, 2024): https://forum.dlang.org/post/txpatkhdhwbjptjwviis@forum.dlang.org
- "Sum Type by Struct" (Rikki Cattermole, 2024): https://forum.dlang.org/post/vc14cr$2lbs$1@digitalmars.com
- "Inline sumtype" (Rikki Cattermole, 2025): https://forum.dlang.org/post/klmxpafeegtphanqmlse@forum.dlang.org
- "D3 sumtype api" (Paul Backus, 2025): https://forum.dlang.org/post/awsfgyvxuazbspdogeqb@forum.dlang.org

## Copyright & License
Copyright (c) 2026 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## History
The DIP Manager will supplement this section with links to forum discussions and a summary of the formal assessment.