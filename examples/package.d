/// The Glui showcase is a set of examples designed to illustrate core features of Glui and provide a quick start guide
/// to developing applications using Glui.
///
/// This module is the central piece of the showcase, gluing it together. It loads and parses each module to display
/// it as a document. It's not trivial; other modules from this package are designed to offer better guidance on Glui
/// usage, but it might also be useful to people intending to implement similar functionality.
///
/// To get started with the showcase, use `dub run glui:showcase`, which should compile and run the showcase. The
/// program explains different components of the library and provides code examples, but you're free to browse through
/// its files if you like! basics.d might be a good start. I hope this directory proves as a useful learning resource.
module glui.showcase;

import glui;
import raylib;
import std.string;
import dparse.ast;


/// Maximum content width, used for code samples, since they require more space.
enum maxContentSize = .sizeLimitX(800);

/// Reduced content width, used for document text.
enum contentSize = .sizeLimitX(700);

Theme mainTheme;
Theme headingTheme;
Theme subheadingTheme;
Theme codeTheme;

/// The entrypoint prepares the Raylib window. The UI is build in `createUI()`.
void main() {

    // Prepare themes
    mainTheme = makeTheme!q{
        GluiFrame.styleAdd!q{
            padding.sideX = 12;
            padding.sideY = 16;
            GluiGrid.styleAdd.padding = 0;
            GluiGridRow.styleAdd.padding = 0;
        };
        GluiLabel.styleAdd!q{
            margin.sideY = 7;
            GluiButton!().styleAdd;
        };
    };

    headingTheme = mainTheme.makeTheme!q{
        GluiLabel.styleAdd!q{
            typeface = Style.loadTypeface(20);
            margin.sideTop = 20;
            margin.sideBottom = 10;
        };
    };

    subheadingTheme = mainTheme.makeTheme!q{
        GluiLabel.styleAdd!q{
            typeface = Style.loadTypeface(16);
            margin.sideTop = 16;
            margin.sideBottom = 8;
        };
    };

    codeTheme = mainTheme.makeTheme!q{
        import std.file, std.path;

        typeface = Style.loadTypeface(thisExePath.dirName.buildPath("sometype-mono.ttf"), 13);
        backgroundColor = color!"dedede";

        GluiFrame.styleAdd.padding = 0;
        GluiLabel.styleAdd!q{
            padding.sideX = 12;
            padding.sideY = 16;
        };
    };

    // Prepare the window
    SetConfigFlags(ConfigFlags.FLAG_WINDOW_RESIZABLE);
    SetTraceLogLevel(TraceLogLevel.LOG_WARNING);
    InitWindow(800, 600, "Glui showcase");
    SetTargetFPS(60);
    scope (exit) CloseWindow();

    // Create the UI
    auto ui = createUI();

    // Event loop
    while (!WindowShouldClose) {

        BeginDrawing();
        scope (exit) EndDrawing();

        ClearBackground(color!"fff");

        // Glui is by default configured to work with Raylib, so all you need to make them work together is a single
        // call
        ui.draw();

    }

}

GluiSpace createUI() @safe {

    auto content = nodeSlot!GluiNode(.layout!(1, "fill"));

    // All content is scrollable
    return vscrollFrame(
        .layout!"fill",
        .mainTheme,
        sizeLock!vspace(
            .layout!(1, "center", "start"),
            .maxContentSize,

            // Back button
            sizeLock!hspace(
                .layout!"center",
                .contentSize,
                button("← Back to navigation", delegate { content = exampleList(content); }),
            ),

            // Content
            content = exampleList(content),
        )
    );

}

GluiSpace exampleList(GluiNodeSlot!GluiNode content) @safe {

    return sizeLock!vspace(
        .layout!"center",
        .contentSize,
        label(.layout!"center", "Hello, World!"),
        grid(
            .layout!"fill",
            .segments(3),
            [
                button(.layout!"fill", "Basics", { content = renderExample!"basics"; }),
            ],
        ),
    );

}

/// Create a code block
GluiSpace showcaseCode(string code) {

    return vframe(
        .layout!"fill",
        .codeTheme,
        sizeLock!label(
            .layout!"center",
            .contentSize,
            code,
        ),
    );

}

/// Showcase code and its result.
GluiSpace showcaseCode(string code, GluiNode node) {

    // Make the node inherit the default theme rather than the one we set
    if (node.theme is null) {
        node.theme = gluiDefaultTheme;
    }

    return hspace(
        .layout!"fill",

        label(
            .layout!(1, "fill"),
            .codeTheme,
            code,
        ),
        vframe(
            .layout!(1, "fill"),
            node
        ),
    );

}

GluiSpace renderExample(string name)() @trusted {

    import std.traits;
    import dparse.lexer;
    import dparse.parser : parseModule;
    import dparse.rollback_allocator : RollbackAllocator;

    LexerConfig config;
    RollbackAllocator rba;

    // Import the module
    mixin("import glui.showcase.", name, ";");
    alias mod = mixin("glui.showcase.", name);

    // Get the module filename
    const filename = name ~ ".d";

    // Load the file
    auto sourceCode = import(filename);
    auto cache = StringCache(StringCache.defaultBucketCount);
    auto tokens = getTokensForParser(sourceCode, config, &cache);

    // Parse it
    auto m = parseModule(tokens, filename, &rba);
    auto visitor = new FunctionVisitor(sourceCode.splitLines);
    visitor.visit(m);

    // Begin creating the document
    auto document = vspace(.layout!"fill");

    // Check each member
    static foreach (member; __traits(allMembers, mod)) {{

        // Limit to functions that end with "Example"
        static if (member.endsWith("Example"))

        // Filter to functions only
        // Note we cannot properly support overload since ordering gets lost at this point
        static foreach (overload; __traits(getOverloads, mod, member)) {

            auto documentation = sizeLock!vspace(.layout!"center", .contentSize);
            auto code = visitor.functions[member];

            // Load documentation attributes
            static foreach (uda; __traits(getAttributes, overload)) {

                static if (isCallable!uda) {

                    documentation ~= uda();

                }

            }

            // Insert the documentation
            document ~= documentation;

            // Add and run a code example if it returns a node
            static if (is(ReturnType!overload : GluiNode))
                document ~= showcaseCode(code, overload());

            // Otherwise, show just the code
            else if (code != "")
                document ~= showcaseCode(code);

        }

    }}

    return document;

}

class FunctionVisitor : ASTVisitor {

    int indentLevel;

    /// Source code divided by lines.
    string[] sourceLines;

    /// Mapping of function names to their bodies.
    string[string] functions;

    this(string[] sourceLines) {

        this.sourceLines = sourceLines;

    }

    alias visit = ASTVisitor.visit;

    override void visit(const FunctionDeclaration decl) {

        import std.array;
        import std.range;
        import std.string;
        import std.algorithm;
        import dparse.lexer;
        import dparse.formatter;

        static struct Location {
            size_t line;
            size_t column;

            this(T)(T t) {
                this.line = t.line - 1;
                this.column = t.column - 1;
            }
        }

        // Get function boundaries
        auto content = decl.functionBody.specifiedFunctionBody.blockStatement;
        auto tokens = content.tokens;

        // Convert to 0-indexing
        auto start = Location(content.tokens[0]);
        auto end = Location(content.tokens[$-1]);
        auto rangeLines = sourceLines[start.line..end.line+1];

        // Extract the text from original source code to preserve original formatting and comments
        auto output = rangeLines
            .enumerate
            .map!((value) {

                auto i = value[0], line = value[1];

                // One line code
                if (rangeLines.length == 1) return line[start.column+1..end.column];

                // First line, skip past "{"
                if (i == 0) return line[start.column+1..$];

                // Middle line, write whole
                else if (i+1 != rangeLines.length) return line;

                // Last line, end before "}"
                else return line[0..end.column];

            })
            .join("\n");

        // Save the result
        functions[decl.name.text] = output[].outdent.strip;
        decl.accept(this);

    }

}
