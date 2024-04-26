/// `moduleView` is a work-in-progress component used to display an overview of a module.
///
/// This module is not enabled, unless additonal dependencies, `fluid-tree-sitter` and `fluid-tree-sitter:d` are also
/// compiled in.
module fluid.module_view;

version (Fluid_ModuleView):
version (Have_fluid_tree_sitter):
version (Have_fluid_tree_sitter_d):

debug (Fluid_BuildMessages) {
    pragma(msg, "Fluid: Using moduleView");
}

import lib_tree_sitter;

import std.conv;
import std.range;
import std.format;
import std.string;
import std.algorithm;

import fluid.node;
import fluid.rope;
import fluid.label;
import fluid.space;
import fluid.frame;
import fluid.structs;
import fluid.code_input;
import fluid.tree_sitter;


@safe:


/// Temporary...
void run(Node node) {

    // Mock run callback is available
    if (mockRun) {

        mockRun()(node);

    }

    // TODO check which backend the node uses
    // TODO move this function elsewhere
    assert(false, "Default backend does not expose an event loop interface.");

}

alias RunCallback = void delegate(Node node) @safe;

/// Set a new function to use instead of `run`.
RunCallback mockRun(RunCallback callback) {

    // Assign the callback
    mockRun() = callback;
    return mockRun();

}

ref RunCallback mockRun() {

    static RunCallback callback;
    return callback;

}

private {

    TSQuery* documentationQuery;
    TSQuery* dlangQuery;

}

static this() @system {

    TSQueryError error;
    uint errorOffset;

    auto language = treeSitterLanguage!"d";
    auto query = q{
        (
            (comment)+ @comment
        )
    };

    documentationQuery = ts_query_new(language, query.ptr, cast(uint) query.length, &errorOffset, &error);
    assert(documentationQuery, format!"%s at offset %s"(error, errorOffset));

    dlangQuery = ts_query_new(language, dQuerySource.ptr, cast(uint) dQuerySource.length, &errorOffset, &error);
    assert(dlangQuery, format!"%s at offset %s"(error, errorOffset));

}

static ~this() @system {

    ts_query_delete(documentationQuery);
    ts_query_delete(dlangQuery);

}

/// Provides information about the companion D compiler to use for evaluating examples.
struct DlangCompiler {

    import std.regex;
    import std.process;

    enum Type {
        dmd,
        ldc,
    }

    /// Type (vendor) of the compiler. Either DMD or LDC.
    Type type;

    /// Executable name or path to the compiler executable. If null, no compiler is available.
    string executable;

    /// DMD frontend version of the compiler. Major version is assumed to be 2.
    int frontendMinor;

    /// ditto
    int frontendPatch;

    /// ditto
    enum frontendMajor = 2;

    /// Import paths to pass to the compiler.
    string[] importPaths;

    /// Returns true if this entry points to a valid compiler.
    bool opCast(T : bool)() const {

        return executable !is null
            && frontendMinor != 0;

    }

    /// Find any suitable in the system.
    static DlangCompiler findAny() {

        return either(
            findDMD,
            findLDC,
        );

    }

    /// Find DMD in the system.
    static DlangCompiler findDMD() {

        // According to run.dlang.io, this pattern has been used since at least 2.068.2
        auto pattern = regex(r"D Compiler v2.(\d+).(\d+)");
        auto explicitDMD = std.process.environment.get("DMD");
        auto candidates = explicitDMD.empty
            ? ["dmd"]
            : [explicitDMD];

        // Test the executables
        foreach (name; candidates) {

            auto process = execute([name, "--version"]);

            // Found a compatible compiler
            if (auto match = process.output.matchFirst(pattern)) {

                return DlangCompiler(Type.dmd, name, match[1].to!int, match[2].to!int);

            }

        }

        return DlangCompiler.init;

    }

    /// Find LDC in the system.
    static DlangCompiler findLDC() {

        // This pattern appears to be stable as, according to the blame, hasn't changed in at least 5 years
        auto pattern = regex(r"based on DMD v2\.(\d+)\.(\d+)");
        auto explicitLDC = std.process.environment.get("LDC");
        auto candidates = explicitLDC.empty
            ? ["ldc2", "ldc"]
            : [explicitLDC];

        // Test the executables
        foreach (name; candidates) {

            auto process = execute([name, "--version"]);

            // Found a compatible compiler
            if (auto match = process.output.matchFirst(pattern)) {

                return DlangCompiler(Type.ldc, name, match[1].to!int, match[2].to!int);

            }

        }

        return DlangCompiler.init;

    }

    unittest {

        import std.stdio;

        auto dmd = findDMD();
        auto ldc = findLDC();

        // Output search results
        // Correctness of these tests has to be verified by the CI runner script or the programmer
        if (dmd) {
            writefln!"Found DMD (%s) 2.%s.%s"(dmd.executable, dmd.frontendMinor, dmd.frontendPatch);
            assert(dmd.type == Type.dmd);
        }
        else
            writefln!"DMD wasn't found";

        if (ldc) {
            writefln!"Found LDC (%s) compatible with DMD 2.%s.%s"(ldc.executable, ldc.frontendMinor, ldc.frontendPatch);
            assert(ldc.type == Type.ldc);
        }
        else
            writefln!"LDC wasn't found";

        // Leading zeros have to be ignored
        assert("068".to!int == 68);

        // Compare results of the compiler-agnostic and compiler-specific functions
        if (auto compiler = findAny()) {

            final switch (compiler.type) {

                case Type.dmd:
                    assert(dmd);
                    break;

                case Type.ldc:
                    assert(ldc);
                    break;

            }

        }

        // No compiler found
        else {

            assert(!dmd);
            assert(!ldc);

        }

    }

    /// Get the flag for importing from given directory.
    string importFlag(string directory) const {

        return "-I" ~ directory;

    }

    /// Get the flag for adding all import directories specified in compiler config.
    string[] importPathsFlag() const {

        return importPaths
            .map!(a => importFlag(a))
            .array;

    }

    /// Get the flag to generate a shared library for the given compiler.
    string sharedLibraryFlag() const {

        final switch (type) {

            case Type.dmd: return "-shared";
            case Type.ldc: return "--shared";

        }

    }

    /// Compile a shared library from given source file.
    void compileSharedLibrary(string source) const
    in (this)
    do {

        import fs = std.file;
        import random = std.random;
        import std.path : buildPath, setExtension;

        static string path;

        // Build a path to contain the program's source
        if (!path)
            path = fs.tempDir.buildPath("fluid_" ~ random.uniform!uint.to!string ~ ".d");

        // Write the source
        fs.write(path, source);

        // TODO use the correct extension
        const outputPath = path.setExtension(".so");

        import std.stdio;
        debug writefln!"compiling: %s %s %s -of=%s %(%s %)"
            (executable, sharedLibraryFlag, path, outputPath, importPathsFlag);

        // Compile the program (TODO: async)
        auto run = execute([executable, sharedLibraryFlag, path, "-of=" ~ outputPath] ~ importPathsFlag);

        debug writefln!"%s"(run.output);

    }

}

/// Create an overview display of the given module.
Frame moduleViewSource(Params...)(Params params, DlangCompiler compiler, string source) @trusted {

    auto language = treeSitterLanguage!"d";
    auto parser = ts_parser_new();
    scope (exit) ts_parser_delete(parser);

    ts_parser_set_language(parser, language);

    // Parse the source
    auto tree = ts_parser_parse_string(parser, null, source.ptr, cast(uint) source.length);
    scope (exit) ts_tree_delete(tree);
    auto root = ts_tree_root_node(tree);
    auto cursor = ts_query_cursor_new();
    scope (exit) ts_query_cursor_delete(cursor);

    auto result = vframe(params);

    // Perform a query to find possibly relevant comments
    ts_query_cursor_exec(cursor, documentationQuery, root);
    TSQueryMatch match;
    captures: while (ts_query_cursor_next_match(cursor, &match)) {

        auto captures = match.captures[0 .. match.capture_count];
        auto node = captures[$-1].node;

        // Load the comment
        auto docs = readDocs(source, captures)
            .interpretDocs;

        // Find the symbol the comment is attached to
        while (true) {

            node = ts_node_next_named_sibling(node);
            if (ts_node_is_null(node)) break;

            // Once found, annotate and append to result
            if (auto annotated = annotate(compiler, source, docs, node)) {
                result ~= annotated;
                continue captures;
            }

        }

        // Nothing relevant found, paste the documentation as-is
        result ~= docs;

    }

    return result;

}

/// Load the module source from a file.
Frame moduleViewFile(Params...)(Params params, DlangCompiler compiler, string filename) {

    import std.file : readText;

    return moduleViewSource(params, compiler, filename.readText);

}

/// Returns:
///     Space to represent the node in the output, or `null` if the given TSNode doesn't correspond to any known valid
///     symbol.
private Space annotate(DlangCompiler compiler, string source, Space documentation, TSNode node) @trusted {

    const typeC = ts_node_type(node);
    const type = typeC[0 .. strlen(typeC)];

    const start = ts_node_start_byte(node);
    const end = ts_node_end_byte(node);
    const symbolSource = source[start .. end];

    switch (type) {

        // unittest
        case "unittest_declaration":

            // Create the code block
            auto input = dlangInput();

            // Find the surrounding context
            const exampleStart = start + symbolSource.countUntil("{") + 1;
            const exampleEnd = end - symbolSource.retro.countUntil("}") - 1;

            // Append code editor to the result
            documentation.children ~= exampleView(compiler, source, [exampleStart, exampleEnd]);
            return documentation;

        // Declarations that aren't implemented
        case "module_declaration":
        case "import_declaration":
        case "mixin_declaration":
        case "variable_declaration":
        case "auto_declaration":
        case "alias_declaration":
        case "attribute_declaration":
        case "pragma_declaration":
        case "struct_declaration":
        case "union_declaration":
        case "invariant_declaration":
        case "class_declaration":
        case "interface_declaration":
        case "enum_declaration":
        case "anonymous_enum_declaration":
        case "function_declaration":
        case "template_declaration":
        case "mixin_template_declaration":
            return documentation;

        // Unknown declaration, skip
        default:
            return null;

    }

}

/// Produce an example.
Frame exampleView(DlangCompiler compiler, CodeInput input) {

    // Disable edits if there's no compiler available
    if (!compiler) input.disable();

    // Compile the program
    compiler.compileSharedLibrary(input.sourceValue.to!string);

    // TODO Run the delegate on a separate thread to prevent locking up.
    return hframe(
        .layout!"fill",
        vspace(
            .layout!(1, "fill"),
            input,
        ),
        vspace(
            .layout!(1, "fill"),
            // TODO stdin/stdout
            //      Probably no way to do without running a compiler and explicitly starting a new process.
        ).hide(),
    );

}

/// ditto
Frame exampleView(DlangCompiler compiler, string source, size_t[2] slice) {

    const start = slice[0];
    const end = slice[1];

    CodeInput input;

    input = dlangInput(delegate {

        compiler.compileSharedLibrary(input.sourceValue.to!string);

    });

    input.prefix = source[0 .. start];
    input.suffix = source[end .. $];
    input.value = source[start .. end]
        .outdent
        .strip;

    return exampleView(compiler, input);

}

/// Creates a `CodeInput` with D syntax highlighting.
CodeInput dlangInput(void delegate() @safe submitted = null) @trusted {

    auto language = treeSitterLanguage!"d";
    auto highlighter = new TreeSitterHighlighter(language, dlangQuery);

    return codeInput(
        .layout!"fill",
        highlighter,
        submitted
    );

}

private Rope readDocs(string source, TSQueryCapture[] captures) @trusted {

    import std.stdio : writefln;

    const lineFeed = Rope("\n");

    Rope result;

    // Load all comments
    foreach (capture; captures) {

        auto start = ts_node_start_byte(capture.node);
        auto end = ts_node_end_byte(capture.node);
        auto commentSource = source[start .. end];

        // TODO multiline comments
        // Filter
        if (!commentSource.skipOver("///")) continue;

        result ~= Rope(Rope(commentSource), lineFeed);

    }

    return result;

}

private Space interpretDocs(Rope rope) {

    import std.conv : to;
    import fluid.typeface : Typeface;

    const space = Rope(" ");
    const lineFeed = Rope("\n");

    rope = rope.strip;

    // Empty comment, omit
    if (rope == "") return vspace();

    // Ditto comment, TODO
    if (rope == "ditto") return vspace();

    // TODO DDoc
    CodeInput lastCode;
    auto lastParagraph = label("");
    auto result = vspace(
        .layout!"fill",
        lastParagraph
    );

    string preformattedDelimiter;

    // Read line by line
    foreach (line; Typeface.lineSplitter(rope)) {

        // Regular documentation line
        if (preformattedDelimiter.empty) {

            line = line.strip();

            // Start a new paragraph if the line is blank
            if (line.empty) {
                if (!lastParagraph.text.empty)
                    result ~= lastParagraph = label("");
            }

            // Preformatted line
            // TODO other delimiters
            // TODO common space (prefix)
            else if (line == "---") {
                preformattedDelimiter = "---";
                result ~= lastCode = dlangInput().disable();
            }

            // Append text to previous line
            else {
                lastParagraph.text ~= Rope(line, space);
            }

        }

        // Preformatted fragments/code
        else {

            // Reached the other delimiter, turn preformatted lines off
            if (line.strip == preformattedDelimiter) {
                preformattedDelimiter = null;
                result ~= lastParagraph = label("");
                lastCode.value = lastCode.value.to!string.outdent;
            }

            /// Append text to previous line
            else {
                lastCode.push(Rope(line, lineFeed));
            }

        }

    }

    return result;

}

/// Outdent a rope.
///
/// A saner wrapper over `std.string.outdent` that actually does what it should do.
private string outdent(string rope) {

    import std.string : outdent;

    return rope.splitLines.outdent.join("\n");

}
