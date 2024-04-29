/// This tour is a set of examples and tutorials designed to illustrate core features of Fluid and provide a quick
/// start guide to developing applications using Fluid.
///
/// This module is the central piece of the tour, gluing it together. It loads and parses each module to display
/// it as a document. It's not trivial; other modules from this package are designed to offer better guidance on Fluid
/// usage, but it might also be useful to people intending to implement similar functionality.
///
/// To get started with the tour, use `dub run fluid:tour`, which should compile and run the tour. The program explains
/// different parts of the library and provides code examples, but you're free to browse through its files if you
/// like! introduction.d might be a good start. I hope this directory proves as a useful learning resource.
module fluid.tour;

import fluid;
import dparse.ast;

import std.string;
import std.traits;
import std.algorithm;


/// Maximum content width, used for code samples, since they require more space.
enum maxContentSize = .sizeLimitX(1000);

/// Reduced content width, used for document text.
enum contentSize = .sizeLimitX(800);

/// Sidebar width
enum sidebarSize = .sizeLimitX(220);

Theme mainTheme;
Theme exampleListTheme;
Theme codeTheme;
Theme previewWrapperTheme;
Theme highlightBoxTheme;

static this() {

    import fluid.theme;
    import std.file, std.path;

    enum warningColor = color!"#ffe186";
    enum warningAccentColor = color!"#ffc30f";

    auto monospace = Style.loadTypeface(thisExePath.dirName.buildPath("../tour/ibm-plex-mono.ttf"), 11);

    mainTheme = Theme(
        rule!Frame(
            margin.sideX = 12,
            margin.sideY = 16,
        ),
        rule!Label(
            margin.sideX = 12,
            margin.sideY = 7,
        ),
        rule!Button(
            margin.sideX = 12,
            margin.sideY = 7,
        ),
        rule!Grid(margin.sideY = 0),
        rule!GridRow(margin = 0),
        rule!ScrollFrame(margin = 0),
        rule!PopupFrame(
            padding.sideX = 2,
            padding.sideY = 4,
        ),

        /// Code input
        rule!CodeInput(
            margin = 0,
            typeface = monospace,
            backgroundColor = color!"#dedede",
            padding.sideX = 12,
            padding.sideY = 16,

            when!"a.isDisabled"(
                backgroundColor = color!"#dedede",
            ),

            // TODO These colors are "borrowed" from Tree-sitter CLI, how about making our own?
            when!`a.token.startsWith("keyword")`    (textColor = color("#5f00d7")),
            when!`a.token.startsWith("attribute")`  (textColor = color("#af0000")),
            when!`a.token.startsWith("property")`   (textColor = color("#af0000")),
            when!`a.token.startsWith("punctuation")`(textColor = color("#4e4e4e")),
            when!`a.token.startsWith("type")`       (textColor = color("#005f5f")),
            when!`a.token.startsWith("operator")`   (textColor = color("#50228a")),
            when!`a.token.startsWith("comment")`    (textColor = color("#8a8a8a")),
            when!`a.token.startsWith("number")`     (textColor = color("#875f00")),
            when!`a.token.startsWith("string")`     (textColor = color("#008700")),
            when!`a.token.startsWith("constant")`   (textColor = color("#875f00")),
            when!`a.token.startsWith("variable")`   (textColor = color("#875f00")),
            when!`a.token.startsWith("function")`   (textColor = color("#005fd7")),
            when!`a.token.startsWith("module")`     (textColor = color("#af8700")),
        ),

        // Heading
        rule!(Label, Tags.heading)(
            typeface = Style.loadTypeface(20),
            margin.sideTop = 20,
            margin.sideBottom = 10,
        ),
        rule!(Label, Tags.subheading)(
            typeface = Style.loadTypeface(16),
            margin.sideTop = 16,
            margin.sideBottom = 8,
        ),

        // Warning
        rule!(Label, Tags.warning)(
            padding.sideX = 16,
            padding.sideY = 6,
            border = 1,
            borderStyle = colorBorder(warningAccentColor),
            backgroundColor = warningColor,
            textColor = color!"#000",
        ),
    );

    exampleListTheme = mainTheme.derive(
        rule!Button(
            padding.sideX = 8,
            padding.sideY = 16,
            margin = 2,
        ),
    );

    highlightBoxTheme = Theme(
        rule!Node(
            border = 1,
            borderStyle = colorBorder(color!"#e62937"),
        ),
    );

    codeTheme = mainTheme.derive(

        rule!Node(
            typeface = monospace,
        ),
        rule!Frame(
            padding = 0,
        ),
        rule!Label(
            margin = 0,
            backgroundColor = color!"#dedede",
            padding.sideX = 12,
            padding.sideY = 16,
        ),
    );

    previewWrapperTheme = mainTheme.derive(
        rule!Frame(
            margin = 0,
            border = 1,
            padding = 0,
            borderStyle = colorBorder(color!"#dedede"),
        ),
    );

}

enum Chapter {
    @"Introduction" introduction,
    @"Frames" frames,
    @"Buttons & mutability" buttons,
    @"Node slots" slots,
    @"Themes" themes,
    @"Margin, padding and border" margins,
    @"Writing forms" forms,
    @"moduleView" module_view,
    // @"Popups" popups,
    // @"Drag and drop" drag_and_drop,
};

@NodeTag
enum Tags {
    heading,
    subheading,
    warning,
}

/// The entrypoint prepares themes and the window.
void main(string[] args) {

    import raylib;

    // Prepare the window
    SetConfigFlags(ConfigFlags.FLAG_WINDOW_RESIZABLE);
    SetTraceLogLevel(TraceLogLevel.LOG_WARNING);
    InitWindow(1000, 750, "Fluid tour");
    SetTargetFPS(60);
    SetExitKey(0);
    scope (exit) CloseWindow();

    // Create the UI — pass the first argument to load a chapter under the given name
    auto ui = args.length > 1
        ? createUI(args[1])
        : createUI();

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

Space createUI(string initialChapter = null) @safe {

    import std.conv;

    Chapter currentChapter;
    Frame root;
    ScrollFrame contentWrapper;
    Space navigationBar;
    Label titleLabel;
    Button leftButton, rightButton;

    auto content = nodeSlot!Space(.layout!(1, "fill"));
    auto outlineContent = vspace(.layout!"fill");
    auto outline = vframe(
        .layout!"fill",
        button(
            .layout!"fill",
            "Top",
            delegate {
                contentWrapper.scrollStart();
            }
        ),
        outlineContent,
    );
    auto sidebar = sizeLock!switchSlot(
        .layout!(1, "end", "start"),
        .sidebarSize,
        outline,
        null,
    );

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
        contentWrapper.scrollStart();

        // Collect all headings and build the outline
        content.queueAction(new BuildOutline(outlineContent));

    }

    // All content is scrollable
    root = onionFrame(
        .layout!"fill",

        // Content
        contentWrapper = vscrollFrame(
            .layout!"fill",
            .mainTheme,
            sizeLock!vspace(
                .layout!(1, "center", "start"),
                .maxContentSize,

                // Navigation
                navigationBar = sizeLock!hspace(
                    .layout!"center",
                    .contentSize,

                    // Back button
                    button("← Back to navigation", delegate {
                        content = exampleList(&changeChapter);
                        navigationBar.hide();
                        leftButton.hide();
                        rightButton.hide();
                        outlineContent.children = [];
                    }),
                    sidebar.retry(
                        popupButton("Outline", outline),
                    ),
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
            ),
        ),

        // Add sidebar on the left
        hspace(
            .layout!"fill",
            sidebar,

            // Reserve space for content
            sizeLock!vspace(.maxContentSize),

            // Balance the sidebar to center the content
            vspace(.layout!1),
        ),


    );

    if (initialChapter) {
        changeChapter(to!Chapter(initialChapter));
    }

    return root;

}

Space exampleList(void delegate(Chapter) @safe changeChapter) @safe {

    import std.meta;
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
            delegate { changeChapter(a); }
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
        label(.layout!"center", .tags!(Tags.heading), "Hello, World!"),
        label("Pick a chapter of the tutorial to get started. Start with the first one or browse the chapters that "
            ~ "interest you! Output previews are shown next to code samples to help you understand the content."),
        label(.layout!"fill", .tags!(Tags.warning), "While this tutorial covers the most important parts of Fluid, "
            ~ "it's still incomplete. Content will be added in further updates of Fluid. Contributions are welcome."),
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
Space showcaseCode(string code, Node node, Theme theme = Theme.init) {

    CodeInput editor;

    // Make the node inherit the default theme rather than the one we set
    if (!node.theme) {
        node.theme = either(theme, fluidDefaultTheme);
    }

    // Reset code editor text.
    void reset() {

        editor.value = code;

    }

    scope (success) reset();

    return hframe(
        .layout!"fill",

        editor = codeInput(
            .layout!(1, "fill"),
            .codeTheme,
        ),
        vframe(
            .layout!(1, "fill"),
            .previewWrapperTheme,
            nodeSlot!Node(
                .layout!(1, "fill"),
                node,
            ),
        )
    );

}

/// Get the title of the given chapter.
string title(Chapter query) @safe {

    import std.traits;

    switch (query) {

        static foreach (chapter; EnumMembers!Chapter) {

            case chapter:
                return getUDAs!(chapter, string)[0];

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
    mixin("import fluid.tour.", name, ";");
    alias mod = mixin("fluid.tour.", name);

    // Get the module filename
    const sourceDirectory = thisExePath.dirName.buildPath("../tour");
    const filename = buildPath(sourceDirectory, name ~ ".d");

    // Use moduleView for rendering its module
    if (chapter == Chapter.module_view) {

        import std.path;
        import fluid.theme;
        import fluid.module_view;

        auto compiler = DlangCompiler.findAny();
        compiler.importPaths ~= [
            "source",
            "../source",
            expandTilde("~/.dub/packages/bindbc-freetype/1.1.1/bindbc-freetype/source"),
            expandTilde("~/.dub/packages/bindbc-loader/1.1.5/bindbc-loader/source"),
        ];
        // TODO figure out the correct freetype path (or vendor)

        return moduleViewFile(
            .layout!"fill",
            mainTheme.derive(
                rule!Frame(
                    padding = 0,
                    margin = 0,
                    gap = 4,
                ),
                rule!Button(
                    margin = 0,
                ),
            ),
            compiler,
            filename,
        );

    }

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

class BuildOutline : TreeAction {

    Space outline;
    Children children;

    this(Space outline) @safe {

        this.outline = outline;
        outline.children = [];

    }

    override void beforeResize(Node node, Vector2) @safe {

        auto headingTags = .tags!(Tags.heading, Tags.subheading);
        const isHeading = !node.tags.intersect(headingTags).empty;

        // Headings only
        if (!isHeading) return;

        // Add a button to the outline
        if (auto label = cast(Label) node) {

            children ~= button(
                .layout!"fill",
                label.text,
                delegate {
                    label.scrollToTop();
                }
            );

        }

    }

    override void afterTree() @safe {

        super.afterTree();
        outline.children = children;
        outline.updateSize();

    }

}
