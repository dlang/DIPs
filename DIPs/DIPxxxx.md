# (Your DIP title)

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Review Count:   | 0 (edited by DIP Manager)                                       |
| Author:         | (your name and contact data)                                    |
| Implementation: | (links to implementation PR if any)                             |
| Status:         | Will be set by the DIP manager (e.g. "Approved" or "Rejected")  |

## Abstract

Introducing the recursive modules and replacing the @property with the @get and @set attributes.

### Reference

Fourm threads:
[Sealed classes] (https://forum.dlang.org/thread/vpxoidaqfbfrnnsepzmn@forum.dlang.org?page=1)

Spec:
[Visibility Attribute] (https://dlang.org/spec/attribute.html#visibility_attributes)
## Contents
* [Rationale](#rationale)
* [Description](#description)
* [Additional Visibility Attribute](#Additional-Visibility-Attribute)
* [Acknowledgements](#acknowledgements)
* [Reviews](#reviews)

## Rationale

A reccuring complant among users is that the access modifiers for classes private and protected don't mean the same way that other langauges do such as C++/Java/C#.
In other languages private means private to this class and protected means private to this class and the dervied class. In which the encapsulation is defined by the class itself.
However in D encapsulation is defined by the module, not the and class itself. This have thrown some users from C++/Java/C# in a loop as they expected private to mean the same thing from the languages
that they used, which greatly discourage them from using the language. The solution is to put each class in it's own module in order to ensure encapsulation.
However this is not always ideal as:
* Creating a file for each class where the code size is considerable small or to be used internaly in a package is deemed as extra unwanted maintenance cost by the programmer.
* Using D as a scripting language becomes more complicated to use for one time scripts as you have to deal with multiple files if you design the classes/structs to be encapsulated by themselves. Where it would be idealy for the scripter to just to handle one file instead of mutiple files.
* Porting from C++ to D involves refactoring when it comes to nested namespaces, when the programmer should be avoiding refactoring as much as possible during the porting process, as refactoring during the port process can lead to unintended bugs.
 

## Description

```d
Module A; //The givin module name will be consider to be the base case or the file name.

Module B //A.B
{
  Module C //A.B.C etc
  {
    ...
  }
}
```


##Additional Visibility Attribute

Protected Package; //TODO explain rational behind this.

## Copyright & License

Copyright (c) 2018 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## Review

The DIP Manager will supplement this section with a summary of each review stage
of the DIP process beyond the Draft Review.
