/// This showcase is a set of examples and tutorials designed to illustrate core features of Fluid and provide a quick
/// start guide to developing applications using Fluid.
///
/// This module is the central piece of the showcase, gluing it together. It loads and parses each module to display
/// it as a document. It's not trivial; other modules from this package are designed to offer better guidance on Fluid
/// usage, but it might also be useful to people intending to implement similar functionality.
///
/// To get started with the showcase, use `dub run fluid:showcase`, which should compile and run the showcase. The
/// program explains different components of the library and provides code examples, but you're free to browse through
/// its files if you like! introduction.d might be a good start. I hope this directory proves as a useful learning
/// resource.
module fluid.showcase;

import fluid;
import dparse.ast;

import std.string;
import std.traits;
import std.algorithm;


/// Maximum content width, used for code samples, since they require more space.
enum maxContentSize = .sizeLimitX(1000);

/// Reduced content width, used for document text.
enum contentSize = .sizeLimitX(800);

Theme mainTheme;
Theme headingTheme;
Theme subheadingTheme;
Theme exampleListTheme;
Theme codeTheme;
Theme previewWrapperTheme;
Theme highlightBoxTheme;
Theme warningTheme;

enum Chapter {
    @"Introduction" introduction,
    @"Frames" frames,
    @"Buttons & mutability" buttons,
    @"Node slots" slots,
    @"Themes" themes,
};

/// The entrypoint prepares themes and the window. The UI is build in `createUI()`.
void main(string[] args) {

    // Prepare themes
    mainTheme = makeTheme!q{
        Frame.styleAdd!q{
            margin.sideX = 12;
            margin.sideY = 16;
            Grid.styleAdd.margin = 0;
            GridRow.styleAdd.margin = 0;
            ScrollFrame.styleAdd.margin = 0;
        };
        Label.styleAdd!q{
            margin.sideY = 7;
            Button!().styleAdd.margin.sideX = 2;
        };
    };

    headingTheme = mainTheme.makeTheme!q{
        Label.styleAdd!q{
            typeface = Style.loadTypeface(20);
            margin.sideTop = 20;
            margin.sideBottom = 10;
        };
    };

    subheadingTheme = mainTheme.makeTheme!q{
        Label.styleAdd!q{
            typeface = Style.loadTypeface(16);
            margin.sideTop = 16;
            margin.sideBottom = 8;
        };
    };

    exampleListTheme = mainTheme.makeTheme!q{
        Button!().styleAdd!q{
            padding.sideX = 8;
            padding.sideY = 16;
            margin = 2;
        };
    };

    highlightBoxTheme = makeTheme!q{
        border = 1;
        borderStyle = colorBorder(color!"#e62937");
    };

    codeTheme = mainTheme.makeTheme!q{
        import std.file, std.path;

        typeface = Style.loadTypeface(thisExePath.dirName.buildPath("../examples/ibm-plex-mono.ttf"), 12);
        backgroundColor = color!"#dedede";

        Frame.styleAdd!q{
            padding = 0;
        };
        Label.styleAdd!q{
            margin = 0;
            padding.sideX = 12;
            padding.sideY = 16;
        };
    };

    previewWrapperTheme = mainTheme.makeTheme!q{
        NodeSlot!Node.styleAdd!q{
            border = 1;
            borderStyle = colorBorder(color!"#dedede");
        };
    };

    warningTheme = mainTheme.makeTheme!q{
        Label.styleAdd!q{
            padding.sideX = 16;
            padding.sideY = 6;
            border = 1;
            borderStyle = colorBorder(color!"#ffc30f");
            backgroundColor = color!"#ffe186";
            textColor = color!"#000";
        };
    };

    // Create the UI — pass the first argument to load a chapter under the given name
    auto ui = args.length > 1
        ? createUI(args[1])
        : createUI();

    /// Start the window.
    startWindow(ui);

}

/// Raylib entrypoint.
version (Have_raylib_d)
void startWindow(Node ui) {

    import raylib;

    // Prepare the window
    SetConfigFlags(ConfigFlags.FLAG_WINDOW_RESIZABLE);
    SetTraceLogLevel(TraceLogLevel.LOG_WARNING);
    InitWindow(1000, 750, "Fluid showcase");
    SetTargetFPS(60);
    scope (exit) CloseWindow();

    // Event loop
    while (!WindowShouldClose) {

        BeginDrawing();
        scope (exit) EndDrawing();

        ClearBackground(color!"fff");

        // Fluid is by default configured to work with Raylib, so all you need to make them work together is a single
        // call
        ui.draw();

    }

}

else version (Have_arsd_official_simpledisplay)
void startWindow(Node ui) {

    import arsd.simpledisplay;

    SimpledisplayBackend backend;

    // Create the window
    auto window = new SimpleWindow(1000, 750, "Fluid showcase",
        OpenGlOptions.yes,
        Resizeability.allowResizing);

    // Setup the backend
    ui.backend = backend = new SimpledisplayBackend(window);

    // Simpledisplay's design is more sophisticated and requires more config than Raylib
    window.redrawOpenGlScene = {
        ui.draw();
        backend.poll();
    };

    // 1 frame every 16 ms ≈ 60 FPS
    window.eventLoop(16, {
        window.redrawOpenGlSceneSoon();
    });

}

Space createUI(string initialChapter = null) @safe {

    import std.conv;

    Chapter currentChapter;
    ScrollFrame root;
    Space navigationBar;
    Label titleLabel;
    Button!() leftButton, rightButton;

    auto content = nodeSlot!Node(.layout!(1, "fill"));

    void changeChapter(Chapter chapter) {

        // Change the content root and show the back button
        currentChapter = chapter;
        content = render(chapter);
        titleLabel.text = title(chapter);

        // Show navigation
        navigationBar.show();
        leftButton.isHidden = chapter == 0;
        rightButton.isHidden = chapter == Chapter.max;

        // Scroll back to top
        root.scrollStart();

    }

    // All content is scrollable
    root = vscrollFrame(
        .layout!"fill",
        .mainTheme,
        sizeLock!vspace(
            .layout!(1, "center", "start"),
            .maxContentSize,

            // Back button
            navigationBar = sizeLock!hspace(
                .layout!"center",
                .contentSize,
                button("← Back to navigation", delegate {
                    content = exampleList(&changeChapter);
                    navigationBar.hide();
                    leftButton.hide();
                    rightButton.hide();
                }),
                titleLabel = label(""),
            ).hide(),

            // Content
            content = exampleList(&changeChapter),

            sizeLock!hframe(
                .layout!"center",
                .contentSize,

                // Left button
                leftButton = button("Previous chapter", delegate {
                    changeChapter(to!Chapter(currentChapter-1));
                }).hide(),

                // Right button
                rightButton = button(.layout!(1, "end"), "Next chapter", delegate {
                    changeChapter(to!Chapter(currentChapter+1));
                }).hide(),
            ),
        )
    );

    if (initialChapter) {
        changeChapter(to!Chapter(initialChapter));
    }

    return root;

}

Space exampleList(void delegate(Chapter) @safe changeChapter) @safe {

    import std.array;
    import std.range;

    auto chapterGrid = grid(
        .layout!"fill",
        .segments(3),
    );

    // TODO This should be easier
    auto rows = only(EnumMembers!Chapter)

        // Create a button for each chapter
        .map!(a => button(
            .layout!"fill",
            title(a),
            () => changeChapter(a)
        ))

        // Split them into chunks of three
        .chunks(3);

    foreach (row; rows) {
        chapterGrid.addRow(row.array);
    }

    return sizeLock!vspace(
        .layout!"center",
        .exampleListTheme,
        .contentSize,
        label(.layout!"center", .headingTheme, "Hello, World!"),
        label("Pick a chapter of the tutorial to get started. Start with the first one or browse the chapters that "
            ~ "interest you! Output previews are shown next to code samples to help you understand the content."),
        label(.warningTheme, "While this tutorial covers the most important parts of Fluid, it's still incomplete. "
            ~ "Content will be added in further updates of Fluid. Contributions are welcome."),
        chapterGrid,
    );

}

/// Create a code block
Space showcaseCode(string code) {

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
Space showcaseCode(string code, Node node, Theme theme = null) {

    // Make the node inherit the default theme rather than the one we set
    if (node.theme is null) {
        node.theme = either(theme, fluidDefaultTheme);
    }

    return hframe(
        .layout!"fill",

        hscrollable!label(
            .layout!(1, "fill"),
            .codeTheme,
            code,
        ).disableWrap(),
        nodeSlot!Node(
            .layout!(1, "fill"),
            .previewWrapperTheme,
            node,
        ),
    );

}

/// Get the title of the given chapter.
string title(Chapter query) @safe {

    import std.traits;

    switch (query) {

        static foreach (chapter; EnumMembers!Chapter) {

            case chapter:
                return __traits(getAttributes, chapter)[0];

        }

        default: return null;

    }

}

/// Render the given chapter.
Space render(Chapter query) @safe {

    switch (query) {

        static foreach (chapter; EnumMembers!Chapter) {

            case chapter:
                return render!chapter;

        }

        default: return null;

    }

}

/// ditto
Space render(Chapter chapter)() @trusted {

    import std.file;
    import std.path;
    import std.conv;
    import std.meta;
    import std.traits;
    import dparse.lexer;
    import dparse.parser : parseModule;
    import dparse.rollback_allocator : RollbackAllocator;

    LexerConfig config;
    RollbackAllocator rba;

    enum name = chapter.to!string;

    // Import the module
    mixin("import fluid.showcase.", name, ";");
    alias mod = mixin("fluid.showcase.", name);

    // Get the module filename
    const sourceDirectory = thisExePath.dirName.buildPath("../examples");
    const filename = buildPath(sourceDirectory, name ~ ".d");

    // Load the file
    auto sourceCode = readText(filename);
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

        // Limit to memberrs that end with "Example"
        // Note we cannot properly support overloads
        static if (member.endsWith("Example")) {

            alias memberSymbol = __traits(getMember, mod, member);

            auto documentation = sizeLock!vspace(.layout!"center", .contentSize);
            auto code = visitor.functions[member];
            auto theme = fluidDefaultTheme;

            // Load documentation attributes
            static foreach (uda; __traits(getAttributes, memberSymbol)) {

                // Node
                static if (is(typeof(uda()) : Node))
                    documentation ~= uda();

                // Theme
                else static if (is(typeof(uda()) : Theme))
                    theme = uda();

            }

            // Insert the documentation
            document ~= documentation;

            // Add and run a code example if it returns a node
            static if (is(ReturnType!memberSymbol : Node))
                document ~= showcaseCode(code, memberSymbol(), theme);

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
