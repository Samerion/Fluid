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
unittest {

    run(
        label("Hello, World!"),
    );

}

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
        ;;[
        ;;    (module_declaration)
        ;;    (import_declaration)
        ;;    (mixin_declaration)
        ;;    (variable_declaration)
        ;;    (auto_declaration)
        ;;    (alias_declaration)
        ;;    (attribute_declaration)
        ;;    (pragma_declaration)
        ;;    (struct_declaration)
        ;;    (union_declaration)
        ;;    (invariant_declaration)
        ;;    (class_declaration)
        ;;    (interface_declaration)
        ;;    (enum_declaration)
        ;;    (anonymous_enum_declaration)
        ;;    (function_declaration)
        ;;    (template_declaration)
        ;;    (mixin_template_declaration)
        ;;    (unittest_declaration)
        ;;] @declaration
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

/// Create an overview display of the given module.
template moduleView(alias mod) {

    /// Load the module source from source code.
    Frame fromSource(Params...)(Params params, string source) @trusted {

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
        while (ts_query_cursor_next_match(cursor, &match)) {

            auto captures = match.captures[0 .. match.capture_count];

            // Load the comment
            result ~= readDocs(source, captures)
                .interpretDocs;

        }

        return result;

    }

    /// Load the module source from a file.
    Frame fromFile(Params...)(Params params, string filename) {

        import std.file : readText;

        return fromSource(params, filename.readText);

    }

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
    auto result = vspace(lastParagraph);

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
                result ~= lastCode = dlangInput();
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
                // TODO outdent the code
            }

            /// Append text to previous line
            else {
                lastCode.push(Rope(line, lineFeed));
            }

        }

    }

    return result;

}

private CodeInput dlangInput() @trusted {

    auto language = treeSitterLanguage!"d";
    auto highlighter = new TreeSitterHighlighter(language, dlangQuery);

    return codeInput(
        .layout!"fill",
        highlighter,
    );

}
