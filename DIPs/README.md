# DIP Status

## DIPs in review
|                  ID|                                          Title|
|--------------------|-----------------------------------------------|
|[1053](./DIP1053.md)|                         Tuple Unpacking Syntax|
|[1049](./DIP1049.md)|                            Primary Type Syntax|
|[1048](./DIP1048.md)|                   Callbacks For Matching Types|

## Accepted DIPs
|                           ID|                                 Title| DMD version  |
|-----------------------------|--------------------------------------|--------------|
|[1003](./accepted/DIP1003.md)|            Remove `body` as a Keyword| 2.075.1      |
|[1007](./accepted/DIP1007.md)|      "future symbol" Compiler Concept| 2.076.1      |
|[1009](./accepted/DIP1009.md)|  Add Expression-Based Contract Syntax| 2.081.0      |
|[1010](./accepted/DIP1010.md)|                      `static foreach`| 2.076.0      |
|[1013](./accepted/DIP1013.md)|               The Deprecation Process| &mdash;      |
|[1014](./accepted/DIP1014.md)|     Hooking D's struct move semantics| &mdash;      |
|[1018](./accepted/DIP1018.md)|                  The Copy Constructor| 2.086.0      |
|[1021](./accepted/DIP1021.md)| Argument Ownership and Function Calls| 2.092.0      |
|[1024](./accepted/DIP1024.md)|                        Shared Atomics| 2.080.1      |
|[1029](./accepted/DIP1029.md)|     Add `throw` as Function Attribute| 2.100.0      |
|[1030](./accepted/DIP1030.md)|                       Named Arguments| 2.103.1†     |
|[1034](./accepted/DIP1034.md)|            Add a Bottom Type (reboot)| 2.096.1      |
|[1035](./accepted/DIP1035.md)|                   `@system` Variables| 2.102.0*     |
|[1038](./accepted/DIP1038.md)|                            `@mustuse`| 2.099.1†     |
|[1043](./accepted/DIP1043.md)|               Shortened Method Syntax| 2.096.1*<br/>2.101.2 |
|[1046](./accepted/DIP1046.md)|       `ref` For Variable Declarations| 2.111.0      |
|[1051](./accepted/DIP1051.md)|                    Add Bitfields to D| 2.101.2*     |
|[1052](./accepted/DIP1052.md)|                              Editions|              |

(* The feature is not enabled by default, but can be enabled by a preview switch.) \
(† The feature is implemented partially and a significant part of the proposed changes are missing.)

## Rejected DIPs
|                           ID|                                 Title|
|-----------------------------|--------------------------------------|
|[1001](./rejected/DIP1001.md)|                          DoExpression|
|[1002](./rejected/DIP1002.md)|                     TryElseExpression|
|[1015](./rejected/DIP1015.md)| Deprecation and removal of implicit conversion from integer and character literals to `bool` |
|[1016](./rejected/DIP1016.md)|              `ref T` accepts r-values|
|[1017](./rejected/DIP1017.md)|                       Add Bottom Type|
|[1027](./rejected/DIP1027.md)|                  String Interpolation|
|[1028](./rejected/DIP1028.md)|                Make @safe the Default|
|[1044](./rejected/DIP1044.md)|                   Enum Type Inference|
|[1047](./rejected/DIP1047.md)|     Add `@gc` as a Function Attribute|

## Postponed DIPs
|                           ID|                                 Title|
|-----------------------------|--------------------------------------|
|[1008](./other/DIP1008.md)   |                  Exceptions and @nogc|
|[1022](./other/DIP1022.md)   |                      foreach auto ref|
|[1023](./other/DIP1023.md)   |Resolution of Template Alias Formal Parameters in Template Functions|
|[1033](./other/DIP1033.md)   |Implicit Conversion of Expressions to Delegates|
|[1041](./other/DIP1041.md)   | Attributes for Higher-Order Functions|
|[1045](./other/DIP1045.md)   |                 Symbol Representation|

## Superseded DIPs
|                           ID|                                 Title|
|-----------------------------|--------------------------------------|
|[1000](./other/DIP1000.md)   |                       Scoped Pointers|
|[1006](./other/DIP1006.md)   |Providing More Selective Control Over Contracts|
|[1019](./other/DIP1019.md)   |                  Named Arguments Lite|
|[1020](./other/DIP1020.md)   |                      Named Parameters|
|[1040](./other/DIP1040.md)   |       Copying, Moving, and Forwarding|

## Abandoned DIPS
|                           ID|                                 Title|
|-----------------------------|--------------------------------------|
|[1004](./other/DIP1004.md)   |                Inherited Constructors|
|[1011](./other/DIP1011.md)   |                      extern(delegate)|
|[1012](./other/DIP1012.md)   |                            Attributes|
|[1037](./other/DIP1037.md)   |              Add Unary Operator `...`|

## Withdrawn DIPS
|                           ID|                                 Title|
|-----------------------------|--------------------------------------|
|[1005](./other/DIP1005.md)   |      Dependency-Carrying Declarations|
|[1025](./other/DIP1025.md)   |Dynamic Arrays Only Shrink, Never Grow|
|[1026](./other/DIP1026.md)   |Deprecate Context-Sensitive String Literals|
|[1031](./other/DIP1031.md)   |Deprecate Brace-Style Struct Initializers|
|[1032](./other/DIP1032.md)   |Function Pointer and Delegate Parameters Inherit Attributes from Function|
|[1036](./other/DIP1036.md)   |   String Interpolation Tuple Literals|
|[1039](./other/DIP1039.md)   |    Static Arrays with Inferred Length|
|[1042](./other/DIP1042.md)   |                           ProtoObject|
