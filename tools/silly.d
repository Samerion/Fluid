// Copyright (c) 2019, Anton Fediushin
//
// Permission to use, copy, modify, and/or distribute this software for any
// purpose with or without fee is hereby granted, provided that the above
// copyright notice and this permission notice appear in all copies.
//
// THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
// WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
// ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
// WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
// ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
// OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

/*
 * Silly is a test runner for the D programming language
 *
 * Patched for Fluid to address https://gitlab.com/AntonMeep/silly/-/issues/46
 *
 * Report bugs and propose new features in project's repository: https://gitlab.com/AntonMeep/silly
 */

/* SPDX-License-Identifier: ISC */
/* Copyright (c) 2018-2019, Anton Fediushin */

deprecated("Silly is not deprecated, in fact, but is marked as deprecated to silence such "
    ~ "warnings when testing.")
module silly;

version(unittest):

static if(!__traits(compiles, () {static import dub_test_root;})) {
	static assert(false, "Couldn't find 'dub_test_root'. Make sure you are running tests with `dub test`");
} else {
	static import dub_test_root;
}

import core.time : Duration, MonoTime;
import std.ascii : newline;
import std.stdio : stdout;

shared static this() {
	import core.runtime    : Runtime, UnitTestResult;
	import std.getopt      : getopt;
	import std.parallelism : TaskPool, totalCPUs;

	Runtime.extendedModuleUnitTester = function () {
		bool verbose;
		bool failFast;
		shared ulong passed, failed;
		uint threads;
		string include, exclude;

		auto args = Runtime.args;
		auto getoptResult = args.getopt(
			"no-colours",
				"Disable colours",
				&noColours,
			"t|threads",
				"Number of worker threads. 0 to auto-detect (default)",
				&threads,
			"i|include",
				"Run tests if their name matches specified regular expression",
				&include,
			"e|exclude",
				"Skip tests if their name matches specified regular expression",
				&exclude,
			"fail-fast",
				"Stop executing all tests when a test fails",
				&failFast,
			"v|verbose",
				"Show verbose output (full stack traces, location and durations)",
				&verbose,
		);

		if(getoptResult.helpWanted) {
			import std.string : leftJustifier;

			stdout.writefln("Usage:%1$s\tdub test -- <options>%1$s%1$sOptions:", newline);

			foreach(option; getoptResult.options)
				stdout.writefln("  %s\t%s\t%s", option.optShort, option.optLong.leftJustifier(20), option.help);

			return UnitTestResult(0, 0, false, false);
		}

		if(!threads)
			threads = totalCPUs;

		Console.init;


		auto started = MonoTime.currTime;

		with(new TaskPool(threads-1)) {
			import core.atomic : atomicOp;
			import std.regex   : matchFirst;

			try {
				foreach(test; parallel(getTests)) {
					if((!include && !exclude) ||
						(include && !(test.fullName ~ " " ~ test.testName).matchFirst(include).empty) ||
						(exclude &&  (test.fullName ~ " " ~ test.testName).matchFirst(exclude).empty)) {

							TestResult result;
							scope(exit) {
								result.writeResult(verbose);
								atomicOp!"+="(result.succeed ? passed : failed, 1UL);
							}
							test.executeTest(result, failFast);
					}
				}
				finish(true);
			} catch(Throwable t) {
				stop();
			}

		}

		stdout.writeln;
		stdout.writefln("%s: %s passed, %s failed in %d ms",
			Console.emphasis("Summary"),
			Console.colour(passed, Colour.ok),
			Console.colour(failed, failed ? Colour.achtung : Colour.none),
			(MonoTime.currTime - started).total!"msecs",
		);

		return UnitTestResult(passed + failed, passed, false, false);
	};
}

void writeResult(TestResult result, in bool verbose) {
	import std.format    : formattedWrite;
	import std.algorithm : canFind;
	import std.range     : drop;
	import std.string    : lastIndexOf, lineSplitter;

	auto writer = stdout.lockingTextWriter;

	writer.formattedWrite(" %s %s %s",
		result.succeed
			? Console.colour("✓", Colour.ok)
			: Console.colour("✗", Colour.achtung),
		Console.emphasis(result.test.fullName[0..result.test.fullName.lastIndexOf('.')].truncateName(verbose)),
		result.test.testName,
	);

	if(verbose) {
		writer.formattedWrite(" (%.3f ms)", (cast(real) result.duration.total!"usecs") / 10.0f ^^ 3);

		if(result.test.location != TestLocation.init) {
			writer.formattedWrite(" [%s:%d:%d]",
				result.test.location.file,
				result.test.location.line,
				result.test.location.column);
		}
	}

	writer.put(newline);

	foreach(th; result.thrown) {
		writer.formattedWrite("    %s thrown from %s on line %d: %s%s",
			th.type,
			th.file,
			th.line,
			th.message.lineSplitter.front,
			newline,
		);
		foreach(line; th.message.lineSplitter.drop(1))
			writer.formattedWrite("      %s%s", line, newline);

		writer.formattedWrite("    --- Stack trace ---%s", newline);
		if(verbose) {
			foreach(line; th.info)
				writer.formattedWrite("    %s%s", line, newline);
		} else {
			for(size_t i = 0; i < th.info.length && !th.info[i].canFind(__FILE__); ++i)
				writer.formattedWrite("    %s%s", th.info[i], newline);
		}
	}
}

void executeTest(Test test, out TestResult result, bool failFast) {
	import core.exception : AssertError, OutOfMemoryError;
	result.test = test;
	const started = MonoTime.currTime;

	try {
		scope(exit) result.duration = MonoTime.currTime - started;
		test.ptr();
		result.succeed = true;

	} catch(Throwable t) {
		foreach(th; t) {
			immutable(string)[] trace;
			try {
				foreach(i; th.info)
					trace ~= i.idup;
			} catch(OutOfMemoryError) { // TODO: Actually fix a bug instead of this workaround
				trace ~= "<silly error> Failed to get stack trace, see https://gitlab.com/AntonMeep/silly/issues/31";
			}

			result.thrown ~= Thrown(typeid(th).name, th.message.idup, th.file, th.line, trace);
		}
		if (failFast && (!(cast(Exception) t || cast(AssertError) t))) {
			throw t;
		}
	}
}

struct TestLocation {
	string file;
	size_t line, column;
}

struct Test {
	string fullName,
	       testName;

	TestLocation location;

	void function() ptr;
}

struct TestResult {
	Test test;
	bool succeed;
	Duration duration;

	immutable(Thrown)[] thrown;
}

struct Thrown {
	string type,
		   message,
		   file;
	size_t line;
	immutable(string)[] info;
}

__gshared bool noColours;

enum Colour {
	none,
	ok = 32,
	achtung = 31,
}

static struct Console {
	static void init() {
		if(noColours) {
			return;
		} else {
			version(Posix) {
				import core.sys.posix.unistd;
				noColours = isatty(STDOUT_FILENO) == 0;
			} else version(Windows) {
				import core.sys.windows.winbase : GetStdHandle, STD_OUTPUT_HANDLE, INVALID_HANDLE_VALUE;
				import core.sys.windows.wincon  : SetConsoleOutputCP, GetConsoleMode, SetConsoleMode;
				import core.sys.windows.windef  : DWORD;
				import core.sys.windows.winnls  : CP_UTF8;

				SetConsoleOutputCP(CP_UTF8);

				auto hOut = GetStdHandle(STD_OUTPUT_HANDLE);
				DWORD originalMode;

				// TODO: 4 stands for ENABLE_VIRTUAL_TERMINAL_PROCESSING which should be
				// in druntime v2.082.0
				noColours = hOut == INVALID_HANDLE_VALUE           ||
							!GetConsoleMode(hOut, &originalMode)   ||
							!SetConsoleMode(hOut, originalMode | 4);
			}
		}
	}

	static string colour(T)(T t, Colour c = Colour.none) {
		import std.conv : text;

		return noColours ? text(t) : text("\033[", cast(int) c, "m", t, "\033[m");
	}

	static string emphasis(string s) {
		return noColours ? s : "\033[1m" ~ s ~ "\033[m";
	}
}

string getTestName(alias test)() {
	string name = __traits(identifier, test);

	foreach(attribute; __traits(getAttributes, test)) {
		static if(is(typeof(attribute) : string)) {
			name = attribute;
			break;
		}
	}

	return name;
}

string truncateName(string s, bool verbose = false) {
	import std.algorithm : max;
	import std.string    : indexOf;
	return s.length > 30 && !verbose
		? s[max(s.indexOf('.', s.length - 30), s.length - 30) .. $]
		: s;
}

TestLocation getTestLocation(alias test)() {
	// test if compiler is new enough for getLocation (since 2.088.0)
	static if(is(typeof(__traits(getLocation, test))))
		return TestLocation(__traits(getLocation, test));
	else
		return TestLocation.init;
}

Test[] getTests(){
	Test[] tests;

	foreach(m; dub_test_root.allModules) {
		import std.meta : Alias;
		import std.traits : fullyQualifiedName;
		static if(__traits(isModule, m)) {
			alias module_ = m;
		} else {
			// For cases when module contains member of the same name
			alias module_ = Alias!(__traits(parent, m));
		}

		// Unittests in the module
		foreach(test; __traits(getUnitTests, module_)) {
			tests ~= Test(fullyQualifiedName!test, getTestName!test, getTestLocation!test, &test);
		}

		// Unittests in structs and classes
		foreach(member; __traits(derivedMembers, module_)) {
			static if(__traits(compiles, __traits(getMember, module_, member)) &&
				__traits(compiles, __traits(isTemplate,  __traits(getMember, module_, member))) &&
				!__traits(isTemplate,  __traits(getMember, module_, member)) &&
				__traits(compiles, __traits(parent, __traits(getMember, module_, member))) &&
				__traits(isSame, __traits(parent, __traits(getMember, module_, member)), module_) ){

				alias member_ = Alias!(__traits(getMember, module_, member));
				// unittest in root structs and classes
				static if(__traits(compiles, __traits(getUnitTests, member_))) {
					foreach(test; __traits(getUnitTests, member_)) {
						tests ~= Test(fullyQualifiedName!test, getTestName!test, getTestLocation!test, &test);
					}
				}

				// unittests in nested structs and classes
				static if ( __traits(compiles, __traits(derivedMembers, member_)) ) {
					foreach(nestedMember; __traits(derivedMembers, member_)) {
						static if (__traits(compiles, __traits(getMember, member_ , nestedMember)) &&
								__traits(compiles, __traits(getUnitTests, __traits(getMember, member_ , nestedMember)))) {
							foreach(test; __traits(getUnitTests, __traits(getMember, member_ , nestedMember) )) {
								tests ~= Test(fullyQualifiedName!test, getTestName!test, getTestLocation!test, &test);
							}
						}
					}

				}
			}
		}
	}
	return tests;
}

