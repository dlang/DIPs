# Stackless Coroutines

| Field           | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| DIP:            | (number/id -- assigned by DIP Manager)                          |
| Author:         | Richard (Rikki) Andrew Cattermole <firstname@lastname.co.nz>                       |
| Implementation: | (links to implementation PR if any)                             |
| Status:         | Draft                                                           |

## Contents
* [Rationale](#rationale)
* [Prior Work](#prior-work)
* [Description](#description)
* [Breaking Changes and Deprecations](#breaking-changes-and-deprecations)
* [Reference](#reference)
* [Copyright & License](#copyright--license)
* [Reviews](#reviews)

## Abstract

Stackless coroutines simplify the development of concurrent, asynchronous applications, making it easier to leverage the power of event loops like IOCP. The state machine representation of coroutines facilitates the integration of memory safety analysis, enabling the detection of potential issues such as accessing an object after its lifetime has ended due to it being yielded from.

The ``@async`` attribute designates a function as a stackless coroutine, triggering a state machine transformation. This transformation enables the use of the ``await`` keyword, which allows the coroutine to yield control and suspend its execution at specific points. When the awaited operation is completed, the coroutine may be resumed from where it left off.

## Rationale

The stackless coroutines proposed presented here have a limited set of use cases in mind:

1. You are expecting waiting to occur between events.
2. You need to support moving between threads.
3. You have limited memory (potentially due to scale).
4. You have work that does not require suspension of a thread.
5. The target audience is not exclusively made up of highly experienced C programmers (or equivalent).

If you meet all of these criteria, then coroutines might be part of the solution to a situation you have. If you did not meet all of them, then coroutines may not be a language feature you need to meet your goals.

These criteria reflect both the event loop designs of kernels and the need for large-scale event handling of sockets. It is appropriate if you are trying to target 100k requests per second, but may not be if you are aiming for 350k or 5k.

An alternative solution that can support a low request per second count is a stackful coroutine, there is an implementation of one in druntime called a ``Fiber``.
This has a very different set of tradeoffs over a stackless coroutine.
They have a much more limited number possible due to needing multiple pages for their implementation (limits to around 32k of them due to the guard page).
They do not have a known call stack to the compiler, so without the use of a transitive attribute it would not be possible to protect thread-local storage variables and other such data races.
Due to the lack of temporal protection, they cannot be safely moved between threads making them unsuitable for the most advanced event loop types (such as IOCP) without introducing additional overhead, even if the quantity wasn't an issue.

## Prior Work

Many languages have varying levels of support for stackless coroutines. They typically come under the guise of the ``async`` and ``await`` keywords. The concept of using the ``await`` keyword to wait for a condition to be signalled before continuing dates back to the 1973 paper ``Concurrent Programming Concepts``.

In 1968 Dijkstra published ``Co-operating sequential processes`` which introduced the notion of parallel begin/end that later authors adopted by using the keywords ``cobegin`` and ``coend``. In the C family, the begin and end markers for a block of code in a function are well defined with the help of braces, for the languages of the time they did not have such clear delineations at the function level and were instead treated as a scope statement.

With Rust, the async keyword produces a state machine in the form of a stackless coroutine that must be moveable between threads. Each coroutine is represented by a library type that they define called ``Future`` (a trait). From there you explicitly pick how to wait for the ``Future`` to complete. Common options are to ``await``, or to ``block_on`` which is a library function provided by the executor. Executors are a library concept that provides a thread pool upon which to execute a coroutine. It performs user mode scheduling and may be part of a system event loop.

Not all designs are equal when a coroutine language feature interacts with an event loop. Rust uses polling to determine if a future has been completed. This works quite well on Posix-based systems which do have a polling methodology that does not depend upon direct uploads of event handles each time you poll. However, Windows does not expose this functionality. This leads to Rust using internal undocumented behavior that tends to break, to enable their ``await`` feature to work. This behavior can be implemented alternatively with a condition variable which is a known possible solution within the D language.

In some languages, the coroutine is heavily tied to their standard library, for C# it is tied to its runtime's ``Task`` class. This is the nominal representation of a coroutine object. It can be cancelled and will be automatically created for you as long as you are annotated appropriately. Multiple returns are not supported and awaiting upon a task will result in the return value. There is protection built into the language against escaping memory.

Another approach that can be taken is to hide the task at the variable level by utilizing a syntax upon a variable declaration like with Swift's ``async let`` binding feature which was introduced by Swift 5.5.

## Description

In addition to the previously mentioned usage requirements, there are a few more of the technical variety:

1. The language feature must not require a specific library to be used with it.
2. It must be easily implementable in dmd's frontend.
3. What exists must have low overhead.
4. If the compiler generates an error that a normal function would not have, the error is guaranteed to not be a false positive when considering a multithreaded context of a coroutine.
5. Framework applicability must be considered to minimize users' need to understand that a coroutine is in play if desired by the framework authors.

As a result of these requirements, this proposal does not offer any library features. It is focussed solely upon the language transformation aspect of it and can be used for any library to consume.

### State

To begin the design, the language produces a struct describing the state of the coroutine at any given point in time and it looks like the following:

```d
static struct __generatedName {
	alias ReturnType = ...;
	alias Parameters = ...;
	alias VarTypes = ...;

	// if sumtype is not in the language, it may be provided by a custom-tagged union
	sumtype ExceptionTypes = ...;
	sumtype WaitingOn = ...;

	// What stage are we executing next?
	int tag;

	// Inputs
	Parameters parameters;
	
	// If we finished due to an exception it is stored here
	ExceptionTypes exception;
	
	// If we yield on a coroutine, it'll be stored here
	WaitingOn waitingOnCoroutine;
	
	// If we have a value after returning, it'll be stored here
	bool haveValue;
	ReturnType value;

	// Everything that remains between function calls
	VarTypes vars;
	
	void execute() @safe nothrow;
}
```

Within the coroutine function, there is no access to ones state. Access is handled by the compiler automatically, or is done so externally as part of the library.

A coroutine does not have access to other contexts, see multiple contexts for closures as the problems this can cause.

#### The Tag

The tag field refers to the stage we are to next execute, the value in question is defined by the user-provided function except for the negatives.

The tag values of:

- ``0 .. int.max`` is reserved for stages in the state machine.
- ``-1`` is reserved for a completed coroutine.
- ``-2`` is reserved for an erroneously completed coroutine.

This is reflective of a coroutine being in one of three stages.
It may be able to execute and could have yielded to another coroutine as a dependency or returned a value.
It could have been completed with an optional value.
Otherwise, it could have encountered an error and cannot continue.

If the tag goes outside of the bounds of the stages, or the stated negative values, it is a compiler bug.

#### Constructing Library Representation

If you have the state descriptor struct as above, you have all the information available to you that you need to construct an instance, execute it until completion to get a result and handle any errors that have occurred.

But that alone isn't enough to use it, you need to be able to tie it into a library to get a library type that the library can understand.

In the following example, a new operator overload ``opConstructCo`` static method is used in an example definition of a library type that represents a coroutine. It is later used in the construction of the library type from the language representation of it.

```d
struct InstantiableCoroutine(Return, Args...) {
	static InstiableCoroutine opConstructCo(CoroutineDescriptor : __descriptorco)();
}
```

It would then be used as a parameter to a function:

```d
struct ListenSocket {
	static ListenSocket create(InstantiableCoroutine!(void, Socket) co);
}
```

From this, you can pass in the language's description of a coroutine function, into a library type:

```d
ListenSocket ls = ListenSocket.create((Socket socket) {
	...
});
```

This is automatic, you need not do anything for function literals. For free functions, there is some work required which will be presented later.

The above examples work as the AST would see something akin to:

```d
// The location of this struct is irrelevant, as long as compile time accessible things remain available
struct __generatedName {
}

ListenSocket ls = ListenSocket.create(
	InstantiableCoroutine!(__generatedName.ReturnType, __generatedName.Parameters)
		.opConstructCo!__generatedName);
);
```

Assignment to the library type works too:

```d
InstantiableCoroutine!(int, int) co = (int param) {
	return param;
};
```

Which lowers to:

```d
// The location of this struct is irrelevant, as long as compile time accessible things remain available
struct __generatedName {
}

InstantiableCoroutine!(int, int) co = InstantiableCoroutine!(int, int)
	.opConstructCo!__generatedName;
```

### Free-functions

Previously it was mentioned that free functions needed a bit of extra work to make them into a coroutine. It is done by looking at the user-defined attributes applied to it.

If it is marked as ``@async`` then it is a coroutine.

```d
int myCo(int param) @async {
	return param;
}
```

However, to accommodate ease of use by frameworks, the authors may not want the user to have to type the attribute ``@async`` or more importantly know that they are in a coroutine.

To do this, we apply an attribute ``@isasync`` from ``core.attributes``onto the struct ``Route`` that will be used by a web service framework:

```d
import core.attributes : isasync;

@isasync
struct Route {
	string path;
}

@Route("/")
void myRoute(Request, Response) {
	// This is a coroutine!
}
```

If a framework author chooses not to require it on every ``Route``, it is fair that it should be available only on a specific alias:

```d
struct Route {
	string path;
}

@isasync
alias AsyncRoute = Route;

@Route("/")
void myRoute1(Request, Response) {
	// This is a regular free-function and not a coroutine!
}

@AsyncRoute("/")
void myRoute2(Request, Response) {
	// This is a coroutine!
}
```

#### Methods

A method has an additional required parameter, a ``this`` pointer parameter that will be the first member of the parameter list.

```d
struct MyThing {
	void myCo(int param) @async {
	}
}
```

When it is a struct, not a class, the type will be a pointer to ``MyThing``, not ``MyThing``. Therefore the parameters in the above example would be:

``MyThing* this, int param``

This can be applied with introspection:

```d
Context theContext;

static foreach(m; __traits(allMembers, Context)) {
	static if (is(__traits(getMember, Context, m) : __descriptorco)) {
		pragma(msg, "Member ", m, " is a coroutine!");

		ListenSocket ls = ListenSocket.create(&__traits(getMember, theContext, m));
	}
}
```

This is a useful capability for registering a set of routes defined within a struct or class. That may or may not be static.

### Completion

A coroutine completes when one of three actions occurs:

1. An uncaught exception is thrown
	```d
	void myCo() @async {
		throw new Exception("uncaught!");
	}
	```
2. The function ends
	```d
	void myCo() @async {
		// some work
		int var;
		// some more work

		// reached here, and implicit return, so done!
	}
	```
3. A return without ``@async`` applied to it:
	```d
	int myCo() @async {
		// some work
		return 0;
	}
	```

### Yielding

A coroutine yields its current stage and changes the tag to the next stage when one of three things happens:

1. A return with ``@async`` is applied to it:

	```d
	int myCo() @async {
		@async return 0; // yield
		return 1; // return
	}
	```

	This is a return that does not complete the coroutine, to enable multiple value returns.
	
2. When an await statement occurs:

	```d
	int myCo() @async {
		ACoroutine co = ...;
		await co;
		return 0;
	}
	```
	
	The await statement establishes a dependency for the coroutine that called it to continue executing. The dependence does not require that dependency to be completed, but it does require that if it has not been completed, to have a value. It is stored in ``waitingOn`` field of the state struct.
	
3. If a method called has the ``@waitrequired`` attribute on it that is defined in ``core.attributes``, an ``await`` is injected before:

	```d
	struct AnotherCo {
		int result() @safe @waitrequired {
			return 2;
		}
	}

	int myCo() @async {
		AnotherCo co = ...;
		// await co;
		int v = co.result;
		return 0;
	}
	```

	If implementability is a concern, the implementation is allowed to error if an ``await`` did not occur explicitly. However, it is recommended if able to support this.
	It enables framework authors to target less knowledgeable users who should not need to know that a coroutine is in use.

### Safety

Coroutines are designed for a multithreaded environment where users may not be highly experienced, with the goal of getting them able to program highly efficient event-based code in a short amount of time without errors.

To assist in this, the language must prevent common problems from occurring:

1. Thread Local Storage cannot have references to it between states.
	```d
	int* tlsVar;
	
	void myCo() @async {
		ACo co = ...;
		int* var = tlsVar;
		await co;
		*var = 2; // Error: TLS variable `tlsVar` in `var` may not be accessed after a yield
	}
	```
2. All coroutine functions default to having ``@safe`` applied to them. You may explicitly change this to ``@trusted``, but not ``@system``. If it is ``@trusted`` protections that are described in this proposal such as not keeping thread-local storage memory around between stages are allowed.
3. All coroutine functions default to having ``nothrow`` applied to them. All exceptions will be caught by the compiler and put into the state object ``exception`` field automatically along with updating the tag.
4. Parameters into a coroutine cannot be ``scope`` (but may have an empty escape set), ``ref``, or ``out``.
5. Synchronized statements, cannot cross states. A yield inside one could result in deadlocks.

The intent is that if the code is working correctly a coroutine will not have access to thread-unsafe memory. However this does not eliminate boundary issues occuring for arguments in, or any object obtained during the execution of the coroutine with awareness of objects owned by the coroutine cannot also trigger this case from being returned asynchronously. This requires further proposals to solve.

### Synchronous Functions

When a synchronous function has a coroutine object, it may wish to do a blocking wait upon it. To facilitate this a library coroutine object, may offer methods that have ``@willwait`` attribute from ``core.attributes`` applied to it.

Internally this could be implemented using a system condition variable paired with a mutex. Which could block the thread.

Coroutines may not call functions marked as ``@willwait`` due to this being a blocking action. Use await on the object instead.

### Grammar

The syntax changes are the following:

```diff
AtAttribute:
+    '@' "async"

TypeSpecialization:
+    "__descriptorco"

TemplateTypeParmeterSpecialization:
+    ':' "__descriptorco"

ReturnStatement:
+    '@' "async" "return" Expression|opt ';'

Keyword:
+    "await"

NonEmptyStatementNoCaseNoDefault:
+    AwaitStatement

AwaitStatement:
+    "await" Expression ';'
```

In addition, three new attributes are introduced in ``core.attributes``:
- ``isasync``
- ``waitrequired``
- ``willwait``

These are meant for library and framework authors, and not for general users of coroutines. They assist in making coroutines more approachable to lesser experienced users of the D language. Whilst also helping experienced users from making mistakes by leaving out a needed ``await`` statement.

In addition to syntax changes there is a new operator overload ``opConstructCo``  which is a static method. This will flag the type it is within as an instanceable library coroutine type.

### Implementation

This design has been curated to be friendly to the implementation of a compiler. Editor developers, need not care about coroutines except for matching ``__descriptorco`` against functions.

For compiler implementation, if it is not possible to mutate to create additional stages during semantic analysis, you are allowed to make ``@waitrequired`` error rather than inject an appropriate position yield.

Otherwise, the slicing of a function into the coroutine object during the semantic analysis of the body need only concern itself with conversion to a method of a state struct, and producing a branch table-based switch statement for efficient execution. The benefit of only having one function is that a switch statement may have case statements added, and the integer may not be sequential due to its multi-threading nature.

### Examples

The following examples assume that the library type ``InstantiableCoroutine`` that is used throughout this proposal includes a method called ``makeInstance`` that constructs an executable instance of that coroutine on the heap typed as a ``Future!ReturnType``.
The future returned, is assumed to have a method called ``block``, that will block the thread until a value is returned or it has completed.

#### Prime Sieve

This example comes from a [programming benchmark repository](https://github.com/hanabi1224/Programming-Language-Benchmarks/tree/main/bench/algorithm/coro-prime-sieve).

```d
void main(string[] args) {
    int n = args.length < 2 ? 100 : to!int(args[1]);
    
    InstantiableCoroutine!(int) ico = &generate;
    Future!int ch = ico.makeInstance();
    ch.block; // await ch;
    
    foreach(i; 0 .. n) {
        int prime = ch.result;
        writeln(prime);
        
        filter(ch, prime);
    }
}

int generate() @async {
    int i = 2;
    
    for(;;) {
        @async return i;
        
        i++;
    }
}

void filter(ref Future!int ch, int prime) {
    ch.block;
    
    while(ch.result && ch.result % prime == 0) {
	    ch.block;
    }
}
```

#### Lowering

For completeness a potential lowering of the coroutine is presented here, limitations and improvements may be made to it by the implementor.

The example is a simple HTTP client, it is simplified down and ignores some types on the socket side for readability.

```d
void clientCO(Socket socket) @async {
	writeln("Connection has been made");

	socket.write("GET / HTTP/1.1\r\n");
	socket.write("Accept-Encoding: identity\r\n");
	socket.write("\r\n");

	while(Future!string readLine = socket.readUntil("\n")) {
		await readLine;
	
		if (!readLine.isComplete) {
			writeln("Not alive and did not get a result");
			return;
		}
		
		string result = readLine.result;
		writeln(result);

		if (result == "</html>") {
			writeln("Saw end of expected input");
			return;
		}
	}
}
```

The descriptor:

```d
static struct State {
	alias ReturnType = void;
	alias Parameters = (Socket);
	alias VarTypes = (readLine: Future!string);
	sumtype ExceptionTypes = :None;
	sumtype WaitingOn = Future!string;

	int tag;
	Parameters parameters;
	ExceptionTypes exception;
	
	WaitingOn waitingOnCoroutine;
	
	bool haveValue;
	ReturnType value;

	VarTypes vars;

	void execute() @safe nothrow {
		try {
			switch(this.tag) {
				case 0:
					writeln("Connection has been made");

					this.parameters.socket.write("GET / HTTP/1.1\r\n");
					this.parameters.socket.write("Accept-Encoding: identity\r\n");
					this.parameters.socket.write("\r\n");

					this.vars.readLine = this.parameters.socket.readUntil("\n");
					this.waitingOnCoroutine = this.vars.readLine;
					
					this.tag = 1;
					return;

				case 1:
					if (!this.vars.readLine.isComplete) {
						writeln("Not alive and did not get a result");
						this.tag = -1; // completed!
						return;
					}
					
					string result = this.vars.readLine.result;
					writeln(result);

					if (result == "</html>") {
						writeln("Saw end of expected input");
						this.tag = -1;
						return;
					}
					
					this.vars.readLine = this.parameters.socket.readUntil("\n");
					this.waitingOnCoroutine = this.vars.readLine;

					this.tag = 1;
					return;

				default:
					assert(0); // compiler bug!
			}
		} catch (Exception e) {
			this.exception = e;
			this.tag = -2;
		}
	}
}
```

## Breaking Changes and Deprecations

The attribute ``@async`` will break existing symbols that are called ``async``. It may be desirable to limit this breakage solely to UDA's or to make accessing it only available in a new edition.

The identifier ``await`` is a new keyword and will be required to only be available in a new edition due to the potential of breaking code.

Due to coroutines being a new declaration behaviour, limiting to a new edition would be appropriete. All behaviors that are suitable for usage from older editions are either library-related or are user-defined attributes that can be solved as problems occur by users.

## Reference

- [Fibers under the magnifying glass](http://www.open-std.org/JTC1/SC22/WG21/docs/papers/2018/p1364r0.pdf)
- [Fibers aren’t useful for much any more; there’s just one corner of it that remains useful for a reason unrelated to fibers](https://devblogs.microsoft.com/oldnewthing/20191011-00/?p=102989)
- [Concurrent Programming](https://www.amazon.com.au/Concurrent-Programming-C-R-Snow/dp/0521339936)
- [Concurrent Programming Concepts](https://dl.acm.org/doi/10.1145/356622.356624)
- [What color is your function](https://journal.stuffwithstuff.com/2015/02/01/what-color-is-your-function/)
- [\Device\Afd, or, the Deal with the Devil that makes async Rust work on Windows](https://notgull.net/device-afd/)
- Rust [async/.await Primer](https://rust-lang.github.io/async-book/01_getting_started/04_async_await_primer.html)
- C# [flow of async function suspension](https://learn.microsoft.com/en-us/dotnet/csharp/asynchronous-programming/task-asynchronous-programming-model#BKMK_WhatHappensUnderstandinganAsyncMethod)
- Swift [async let binding](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0317-async-let.md)
- C++ [C++ Coroutines: Understanding the Compiler Transform](https://lewissbaker.github.io/2022/08/27/understanding-the-compiler-transform)

## Copyright & License
Copyright (c) 2024 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)

## History
The DIP Manager will supplement this section with links to forum discussions and a summary of the formal assessment.