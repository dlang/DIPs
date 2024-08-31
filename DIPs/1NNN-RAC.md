# Callback For Matching Type

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Author:         | Richard (Rikki) Andrew Cattermole <firstname@lastname.co.nz> |
| Implementation: | (links to implementation PR if any)                             |
| Status:         | Draft                                                           |

## Abstract

Callback for matching type is a quality of life feature that enables safer access and mutation of tagged union like data representations. It adds syntax sugar on top of a switch statement to give convenient access to the union members without sacrificing safety.

## Contents
* [Rationale](#rationale)
* [Prior Work](#prior-work)
* [Description](#description)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Reference](#reference)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)

## Rationale

As a feature pattern matching goes hand and hand with sum types. While D has got library sum types, the desire to have them in the language introduces the need for a way to express the matching upon types. This proposal offers a solution to this, that works with existing library types.

## Prior Work

This proposal is to give callbacks to types using pattern matching. It does not introduce pattern matching as a whole. In other languages such as the ML family, pattern synonyms, pattern guards, values and literals, and nested type matching are possible.

By limiting this proposal to what is currently in use in the ecosystem (using less desirable means), this proposal can be kept simplified to only what has been proven to be needed today.

In the D ecosystem pattern matching can be seen in some library tagged union types such as ``std.sumtype``'s match free function. This offers multiple dispatch and uses lambdas as callbacks.

## Description

A matching type is any type that includes the members ``__tag``, ``__tagTypes`` and a templated function ``__tagValue`` which takes in the type.

A ``__tag`` member must evaluate to an integer that may not be sequential, although it may take the form of an ``enum``, or pointer.

The ranges of a ``__tag`` is determined by its evaluated type. If it is an ``enum``, then its members provide the range of possible results. Otherwise it is provided by a fourth member ``__tagValues``.

When the compiler sees a match, it will map the match type to a set of tags that match it. If no type is provided, it will match all possible values and will act as a default. If a type is provided it should be matched against overload resolution rules, try to find an exact match otherwise use (the single) implicit conversion.

Each match contains multiple patterns. Only one pattern may be inferred per matching type, using similarly means to lambda parameter type inference. However instead of inferring, each possible type that has not had a pattern will be instantiated as a fallback.

If a tag type is void, the parameter will be considered unreachable and cannot be loaded or stored into, but may be named.

It is an expression not a statement, to enable future work of returning values.

```diff
PostfixExpression:
+    PostfixExpression '.' "match" DeclarationBlock

DeclDef:
+    MatchPattern ';'
+    MatchPatterns MatchPattern ';'

+ MatchPattern:
+    Identifier FunctionLiteralBody
+    ParameterWithAttributes FunctionLiteralBody
```

Inside of a match ``DeclarationBlock`` only the rules ``MatchPattern``, ``ConditionalDeclaration``, ``DebugSpecification``, ``VersionSpecification``, ``MixinDeclaration``, ``AttributeSpecifier``, ``ImportDeclaration``, ``StaticForeachDeclaration``, and ``StaticAssert`` are valid. Outside of a match the rule ``MatchPattern`` is not valid.

Visibility and safety is ignored for the ``__tag``, ``__tagValue`` members. The members ``__tagValues`` and ``__tagTypes`` must be accessible.

When decomposed a pattern match is syntax sugar surrounding a switch statement. With the callbacks expected to be inlined. Decomposing to a switch statement enables existing optimizations for switch statements to enable faster execution without the need for a new class of optimizations.

```d
switch(tag) {
	case Context.__tagValues[2]:
		Callback();
		break;
	default:
		FallbackCallback();
		break;
}
```

The type to match upon may not be matchable, in the case of a tuple this will employ a mutiple dispatch strategy. Nested switch statements will be used to evaluate out each level of the possible patterns. If a fallback pattern is applied to a nesting, only one given the preceeding patterns may be a fallback and has a higher precendence over all being fallback in a pattern.

```d
switch(tag[0]) {
	case Context1.__tagValues[2]:
		switch(tag[1]) {
		case Context2.__tagValues[9]:
			Callback();
			break;
		default:
			FallbackCallback1();
			break;
		}
		break;
	default:
		switch(tag[1]) {
		default:
			FallbackCallback2();
			break;
		}
		break;
}
```

With syntax:

```d
tuple(first, second).match {
	(Type1 v1, Type2 v2) {
	};
	
	(Type1 v1, v2) {
	};
	
	(v1, v2) {
	};
}
```

## Example: Tagged Unions

Given a tag union type:

```d
import std.conv : text;

struct MyTaggedUnion(Types...) {
	alias __tagTypes = Types;

	private {
		size_t __tag;

		union {
			static foreach(i; 0 .. Types.length) {
				mixin("Types[i] " ~ i.text ~ ";");
			}
		}

		ref Type __tagValue(Type)() {
			return *cast(Type*)&this;
		}
	}
}
```

It can be used like this:

```d
alias MTU = MyTaggedUnion!(int, float, string);

MTU mtu1 = MTU(1.5);
MTU mtu2 = MTU("Rikki");

mtu1.match {
	(float v) => writeln("a float! ", v);
	v => writeln("catch all! ", v);
};

mtu2.match {
	(string name) => writeln("Who is awesome? ", name);
	_ => assert(0);
};
```

It is an error to not have a handler for all possible types. Either provide a catch all pattern or handle all possible types.

```d
mtu1.match {
	(float v) => writeln("a float! ", v);
}; // Error: Pattern matching must handle all types `int`, `string`, were not handled.
```

## Example: Tagged Union AST

Abstract Syntax Trees can be represented by tagged unions with many benefits and some compiler authors prefer them over classes along with using a visitor pattern.

These are a different variant of tagged unions as they have a fixed set of possible values.

```d
import std.meta : AliasSeq;

struct Expression {
	alias __tagTypes = AliasSeq!(void, BinaryExpression, UnaryExpression);
	alias __tagValues = Type;

	private {
		Type type;
		alias __tag = type;

		ref BinaryExpression __tagValue(Type:BinaryExpression)() => binary;
		ref UnaryExpression __tagValue(Type:UnaryExpression)() => unary;

		union {
			BinaryExpression binary;
			UnaryExpression unary;
		}

		enum Type {
			Error,
			Binary,
			Unary
		}
	}
}

struct BinaryExpression {
}

struct UnaryExpression {
}
```

Its usage:

```d
Expression expr = ...;
expr.match {
	(ref BinaryExpression be) {
	};
	
	(ref UnaryExpression ue) {
	};
	
	_ => assert(0);
};
```

## Breaking Changes and Deprecations

Existing members of a type may be called ``match``. Unfortunately this results in the possibility of a breakage. However this doesn't have to be the case.

Using a lookahead of one token, if ``match`` is followed by ``{`` then it is this feature, otherwise it should be treated as currently.

## Reference

Overview of all the different pattern matching capabilities that mainstream languages offer can be found on [Wikipedia].(https://en.wikipedia.org/wiki/Pattern_matching)

Haskell's pattern synonyms: [link](https://ghc.gitlab.haskell.org/ghc/doc/users_guide/exts/pattern_synonyms.html).

## Copyright & License
Copyright (c) 2024 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## History
The DIP Manager will supplement this section with links to forum discsusionss and a summary of the formal assessment.