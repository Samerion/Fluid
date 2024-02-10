module fluid.grid;

import std.range;
import std.algorithm;

import fluid.node;
import fluid.tree;
import fluid.frame;
import fluid.style;
import fluid.utils;
import fluid.backend;
import fluid.structs;


@safe:


alias grid = simpleConstructor!Grid;
alias gridRow = simpleConstructor!GridRow;

// TODO rename segments to columns?

/// Segments is used to set the number of columns spanned by a grid item. When applied to a grid, it sets the number of
/// columns the grid will have.
struct Segments {

    /// Number of columns used by a grid item.
    uint amount = 1;

    /// Set the number of columns present in a grid.
    void apply(Grid grid) {

        grid.segmentCount = amount;

    }

    /// Set the number of columns used by this node.
    void apply(Node node) {

        node.layout.expand = amount;

    }

}

/// ditto
Segments segments(uint columns) {

    return Segments(columns);

}

/// ditto
Segments segments(uint columns)() {

    return Segments(columns);

}

/// The Grid node will align its children in a 2D grid.
class Grid : Frame {

    mixin DefineStyles;

    size_t segmentCount;

    private {

        /// Sizes for each segment.
        int[] segmentSizes;

        /// Last grid width given.
        float lastWidth;

    }

    this(Ts...)(Ts children) {

        this.children.length = children.length;

        // Check the other arguments
        static foreach (i, arg; children) {{

            // Grid row (via array)
            static if (is(typeof(arg) : U[], U)) {

                this.children[i] = gridRow(this, arg);

            }

            // Other stuff
            else {

                this.children[i] = arg;

            }

        }}

    }

    unittest {

        import std.math;
        import std.array;
        import std.typecons;
        import fluid.label;

        auto io = new HeadlessBackend;
        auto root = grid(
            nullTheme.derive(
                rule!Label(
                    Rule.textColor = color!"000",
                ),
            ),
            .layout!"fill",
            .segments!4,

            label("You can make tables and grids with Grid"),
            [
                label("This"),
                label("Is"),
                label("A"),
                label("Grid"),
            ],
            [
                label(.segments!2, "Multiple columns"),
                label(.segments!2, "For a single cell"),
            ]
        );

        root.io = io;
        root.draw();

        // Check layout parameters

        assert(root.layout == .layout!"fill");
        assert(root.segmentCount == 4);
        assert(root.children.length == 3);

        assert(cast(Label) root.children[0]);

        auto row1 = cast(GridRow) root.children[1];

        assert(row1);
        assert(row1.segmentCount == 4);
        assert(row1.children.all!"a.layout.expand == 0");

        auto row2 = cast(GridRow) root.children[2];

        assert(row2);
        assert(row2.segmentCount == 4);
        assert(row2.children.all!"a.layout.expand == 2");

        // Current implementation requires an extra frame to settle. This shouldn't be necessary.
        io.nextFrame;
        root.draw();

        // Each column should be 200px wide
        assert(root.segmentSizes == [200, 200, 200, 200]);

        const rowEnds = root.children.map!(a => a.minSize.y)
            .cumulativeFold!"a + b"
            .array;

        // Check if the drawing is correct
        // Row 0
        io.assertTexture(Rectangle(0, 0, root.children[0].minSize.tupleof), color!"000");

        // Row 1
        foreach (i; 0..4) {

            const start = Vector2(i * 200, rowEnds[0]);

            assert(io.textures.canFind!(tex => tex.isStartClose(start)));

        }

        // Row 2
        foreach (i; 0..2) {

            const start = Vector2(i * 400, rowEnds[1]);

            assert(io.textures.canFind!(tex => tex.isStartClose(start)));

        }

    }

    /// Add a new row to this grid.
    void addRow(Ts...)(Ts content) {

        children ~= gridRow(this, content);

    }

    /// Magic to extract return value of extractParams at compile time.
    private struct Number(size_t num) {

        enum value = num;

    }

    /// Evaluate special parameters and get the index of the first non-special parameter (not Segments, Layout nor
    /// Theme).
    /// Returns: An instance of `Number` with said index as parameter.
    private auto extractParams(Args...)(Args args) {

        enum maxInitialArgs = min(args.length, 3);

        static foreach (i, arg; args[0..maxInitialArgs]) {

            // Complete; wait to the end
            static if (__traits(compiles, endIndex)) { }

            // Segment count
            else static if (is(typeof(arg) : Segments)) {

                segmentCount = arg.expand;

            }

            // Layout
            else static if (is(typeof(arg) : Layout)) {

                layout = arg;

            }

            // Theme
            else static if (is(typeof(arg) : Theme)) {

                theme = arg;

            }

            // Mark this as the end
            else enum endIndex = i;

        }

        static if (!__traits(compiles, endIndex)) {

            enum endIndex = maxInitialArgs;

        }

        return Number!endIndex();

    }

    override protected void resizeImpl(Vector2 space) {

        import std.numeric;

        // Need to recalculate segments
        if (segmentCount == 0) {

            // Increase segment count
            segmentCount = 1;

            // Check children
            foreach (child; children) {

                // Only count rows
                if (auto row = cast(GridRow) child) {

                    // Recalculate the segments needed by the row
                    row.calculateSegments();

                    // Set the segment count to the lowest common multiple of the current segment count and the cell count
                    // of this row
                    segmentCount = lcm(segmentCount, row.segmentCount);

                }

            }

        }

        // Reserve the segments
        segmentSizes = new int[segmentCount];

        // Resize the children
        super.resizeImpl(space);

        // Reset width
        lastWidth = 0;

    }

    override void drawImpl(Rectangle outer, Rectangle inner) {

        // TODO WHY is this done here and not in resizeImpl?
        void expand(Node child) {

            // Given more grid space than we allocated
            if (lastWidth >= inner.width + 1) return;

            // Only proceed if the given node is a row
            if (!cast(GridRow) child) return;

            // Update the width
            lastWidth = inner.width;

            // Get margin for the row
            const rowMargin = child.style.totalMargin;
            // Note: We're assuming all rows have the same margin. This might not hold true with the introduction of
            // tags.

            // Expand the segments to match box size
            redistributeSpace(segmentSizes, inner.width - rowMargin.sideLeft - rowMargin.sideRight);

        }

        // Draw the background
        pickStyle.drawBackground(tree.io, outer);

        // Get the position
        auto position = inner.y;

        // Draw the rows
        foreach (child; filterChildren) {

            // Get params
            const rect = Rectangle(
                inner.x, position,
                inner.width, child.minSize.y
            );

            // Try to expand grid segments
            expand(child);

            // Draw the child
            child.draw(rect);

            // Offset position
            position += child.minSize.y;

        }

    }

    unittest {

        import fluid.label;

        // Nodes are to span segments in order:
        // 1. One label to span 6 segments
        // 2. Each 3 segments
        // 3. Each 2 segments
        auto g = grid(
            [ label("") ],
            [ label(""), label("") ],
            [ label(""), label(""), label("") ],
        );

        g.backend = new HeadlessBackend;
        g.draw();

        assert(g.segmentCount == 6);

    }

}

/// A single row in a `Grid`.
class GridRow : Frame {

    mixin DefineStyles;

    Grid parent;
    size_t segmentCount;

    /// Params:
    ///     params = Standard Fluid constructor parameters.
    ///     parent = Grid this row will be placed in.
    ///     nodes = Children to be placed in the row.
    this(T...)(Grid parent, T nodes) {

        super(nodes);
        this.layout.nodeAlign = NodeAlign.fill;
        this.parent = parent;
        this.directionHorizontal = true;

    }

    void calculateSegments() {

        segmentCount = 0;

        // Count segments used by each child
        foreach (child; children) {

            segmentCount += either(child.layout.expand, 1);

        }

    }

    override void resizeImpl(Vector2 space) {

        // Reset the size
        minSize = Vector2();

        // Empty row; do nothing
        if (children.length == 0) return;

        // No segments calculated, run now
        if (segmentCount == 0) {

            calculateSegments();

        }

        size_t segment;

        // Resize the children
        foreach (child; children) {

            const segments = either(child.layout.expand, 1);
            const childSpace = Vector2(
                space.x * segments / segmentCount,
                minSize.y,
            );

            scope (exit) segment += segments;

            // Resize the child
            child.resize(tree, theme, childSpace);

            auto range = parent.segmentSizes[segment..segment+segments];

            // Second step: Expand the segments to give some space for the child
            minSize.x += range.redistributeSpace(child.minSize.x);

            // Increase vertical space, if needed
            if (child.minSize.y > minSize.y) {

                minSize.y = child.minSize.y;

            }

        }

    }

    override protected void drawImpl(Rectangle outer, Rectangle inner) {

        size_t segment;

        pickStyle.drawBackground(tree.io, outer);

        /// Child position.
        auto position = Vector2(inner.x, inner.y);

        foreach (child; filterChildren) {

            const segments = either(child.layout.expand, 1);
            const width = parent.segmentSizes[segment..segment+segments].sum;

            // Draw the child
            child.draw(Rectangle(
                position.x, position.y,
                width, inner.height,
            ));

            // Proceed to the next segment
            segment += segments;
            position.x += width;

        }

    }

}

/// Redistribute space for the given row spacing range. It will increase the size of as many cells as possible as long
/// as they can stay even.
///
/// Does nothing if amount of space was reduced.
///
/// Params:
///     range = Range to work on and modify.
///     space = New amount of space to apply. The resulting sum of range items will be equal or greater (if it was
///         already greater) to this number.
/// Returns:
///     Newly acquired amount of space, the resulting sum of range size.
private ElementType!Range redistributeSpace(Range, Numeric)(ref Range range, Numeric space, string caller = __FUNCTION__) {

    import std.math;

    alias RangeNumeric = ElementType!Range;

    // Get a sorted copy of the range
    auto sortedCopy = range.dup.sort!"a > b";

    // Find smallest item & current size of the range
    RangeNumeric currentSize;
    RangeNumeric smallestItem;

    // Check current data from the range
    foreach (item; sortedCopy.save) {

        currentSize += item;
        smallestItem = item;

    }

    /// Extra space to give
    auto extra = cast(double) space - currentSize;

    // Do nothing if there's no extra space
    if (extra < 0 || extra.isClose(0)) return currentSize;

    /// Space to give per segment
    RangeNumeric perElement;

    // Check all segments
    foreach (i, segment; sortedCopy.enumerate) {

        // Split the available over all remaining segments
        perElement = smallestItem + cast(RangeNumeric) ceil(extra / (range.length - i));

        // Skip segments if the resulting size isn't big enough
        if (perElement > segment) break;

    }

    RangeNumeric total;

    // Assign the size
    foreach (ref item; range)  {

        // Grow this one
        item = max(item, perElement);
        total += item;

    }

    return total;

}
