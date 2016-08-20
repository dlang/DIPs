# Private symbol (in)visibility

| Section        | Value                                                                                       |
|----------------|---------------------------------------------------------------------------------------------|
| DIP:           | 22                                                                                          |
| Status:        | Implemented                                                                                 |
| Author:        | Михаил Страшун (Dicebot) and Martin Nowak                                                   |
| Implementation:| <https://github.com/dlang/dmd/pull/5472>                                                    |
| Links:         | [Access specifiers and visibility](https://wiki.dlang.org/Access_specifiers_and_visibility) |

Abstract
--------

This proposal attempts to solve one of important issues with current protection attribute design: senseless name clashes between **private** and **public** symbols. So change of **private** related name resolution rules is proposed.

Rationale
---------

**private** is an encapsulation tool. If it is not intended to be used by "outsiders", it should not interfere with them at all. It creates no new limitations and reduces amount of code breakage by changes in other modules.

Description
-----------

-   Private restricts the visibility of a symbol.

` A `**`private`**` symbol will not interact with other modules.`
` In case look-up for a symbol fails the compiler might suggest `**`private`**` symbols similar to how spell checking works.`

-   The least protected symbol determines the visibility for overloads.

` After overload resolution an additional access check will be performed. Thereby overload resolution remains independent of look-up origin.`

-   Meta programming tools like `__traits` and .tupleof can access **private** symbols.

` This is necessary for some generic code, e.g. serialization.`

-   All changes apply for modules as well as for classes.

` Protection has module granularity so looking up `**`private`**
` members of a base class from a different module follows`
` the same rules as accessing other `**`private`**` symbols from`
` a different module.`
` Additionally `**`protected`**` allows access from derived classes`
` but not from other modules.`

-   Alias protection overrides the protection of the aliased symbol.

` A `**`public`**` alias to a `**`private`**` symbol makes the symbol`
` accessibly through the alias. The alias itself needs to be`
` in the same module, so this doesn't impair protection control.`

### other protection attribute changes

-   **public** stays the same
-   **package** matches **private** changes from the point of view of other packages
-   **extern** stays the same
-   **protected** matches **private** changes, descendants still treat protected symbols as **public** ones.

Possible code breakage and solutions
------------------------------------

No previously valid code will become illegal in normal use cases, as this proposal is more permissive than current behavior. As \_\_traits and .tupleof will still work for **private** as before, any library that relies on them should not break.

Walter's concerns
-----------------

[original comment](http://forum.dlang.org/post/kb86il$1u9v$1@digitalmars.com)

1. *what access means at module scope*

"Does this symbol is ignored when doing symbol name look-up?". All protection attributes boil down to simple answer (Yes/No) depending on symbol origins and place look-up is made from. In example:

    Symbol origin:               module a;
    Look-up origin:              not module a;
    Symbol protection attribute: private
    Answer:                      No

2. *at class scope*

D minimal encapsulation unit is a module. **Private** class members are, technically, **private** module members and thus have the same behavior. Same for **package** and **public**. **Protected** is only special case that takes additional parameter into consideration.

3. *at template mixin scope*

No changes here. For templates look-up origin is definition module. For mixin templates - instantiation module. Other than that, usual rules apply.

4. *backwards compatibility*

See "Possible code breakage and solutions"

5. overloading at each scope level and the interactions with access

See "Description".

6. *I'd also throw in getting rid of the "protected" access attribute completely, as I've seen debate over that being a useless idea*

I have found no harm in keeping it. This will break code for sure and is irrelevant to this DIP topic.

7. *there's also some debate about what "package" should mean*

This is also irrelevant to this DIP. While there may be debates on meaning of package concept, meaning of **package** protection attribute is solid: encapsulation within set of modules belonging to same package, whatever they are.

Copyright
---------

This document has been placed in the Public Domain.
