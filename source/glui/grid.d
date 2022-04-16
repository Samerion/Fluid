module glui.grid;

import raylib;
import std.algorithm;

import glui.node;
import glui.frame;
import glui.style;
import glui.utils;
import glui.structs;


@safe:


alias grid = simpleConstructor!GluiGrid;
alias gridRow = simpleConstructor!GluiGridRow;

/// A special version of Layout, see `segments`.
struct Segments {

    Layout layout;
    alias layout this;

}

template segments(T...) {

    Segments segments(Args...)(Args args) {

        return Segments(.layout!T(args));

    }

}

/// The GluiGrid node will align its children in a 2D grid.
class GluiGrid : GluiFrame {

    ulong segmentCount;

    private {

        int[] segmentSizes;
        int[] expandedSegments;

    }

    this(T...)(T args) {

        // First arguments
        const params = extractParams(args);
        const initialArgs = params.value;

        // Prepare children
        children.length = args.length - initialArgs;

        // Check the other arguments
        static foreach (i, arg; args[initialArgs..$]) {{

            // Grid row (via array)
            static if (is(typeof(arg) : U[], U)) {

                children.getChildren[i] = gridRow(this, arg);

            }

            // Other stuff
            else children.getChildren[i] = arg;

        }}

    }

    /// Magic to extract return value of extractParams at compile time.
    private struct Number(ulong num) {

        enum value = num;

    }

    /// Evaluate special parameters and get the index of the first non-special parameter (not Segments, Layout nor
    /// Theme).
    /// Returns: An instance of `Number` with said index as parameter.
    private auto extractParams(Args...)(Args args) {

        static foreach (i, arg; args[0..min(args.length, 3)]) {

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

            enum endIndex = 0;

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
                if (auto row = cast(GluiGridRow) child) {

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
        expandedSegments = segmentSizes.dup;

        // Resize the children
        super.resizeImpl(space);

    }

    override void drawImpl(Rectangle outer, Rectangle inner) {

        // Reset segment size
        copy(segmentSizes, expandedSegments);

        // Expand the segments to match the box size
        redistributeSpace(expandedSegments, inner.width);

        // Draw the row
        super.drawImpl(outer, inner);

    }

    unittest {

        import glui.label;

        // Nodes are to span segments in order:
        // 1. One label to span 6 segments
        // 2. Each 3 segments
        // 3. Each 2 segments
        auto g = grid(
            [ label() ],
            [ label(), label() ],
            [ label(), label(), label() ],
        );

        g.tree = new LayoutTree(g);
        g.resize(g.tree, makeTheme!q{ }, Vector2());

        assert(g.segmentCount == 6);

    }

}

/// A single row in a `GluiGrid`.
class GluiGridRow : GluiFrame {

    mixin DefineStyles;

    GluiGrid parent;
    ulong segmentCount;

    static foreach (i; 0..BasicNodeParamLength) {

        /// Params:
        ///     params = Standard Glui constructor parameters.
        ///     parent = Grid this row will be placed in.
        ///     args = Children to be placed in the row.
        this(T...)(BasicNodeParam!i params, GluiGrid parent, T args)
        if (is(T[0] : GluiNode) || is(T[0] : U[], U)) {

            super(params);
            this.parent = parent;
            this.directionHorizontal = true;

            foreach (arg; args) {

                this.children ~= arg;

            }

        }

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

        ulong segment;

        // Resize the children
        foreach (child; children) {

            // First step: size the child to match available space

            const segments = either(child.layout.expand, 1);
            const childSpace = Vector2(
                space.x * segments / segmentCount,
                minSize.y,
            );

            scope (exit) segment += segments;

            // Resize the child
            child.resize(tree, theme, childSpace);

            // We need more vertical space
            if (child.minSize.y > minSize.y) {

                minSize.y = child.minSize.y;

            }

            auto range = parent.segmentSizes[segment..segment+segments];

            // Second step: Expand the segments to give some space for the child
            range.redistributeSpace(child.minSize.x);

        }

    }

    override protected void drawImpl(Rectangle outer, Rectangle inner) {

        auto position = Vector2(inner.x, inner.y);
        ulong segment;

        drawChildren((child) {

            const segments = either(child.layout.expand, 1);
            const width = parent.expandedSegments[segment..segment+segments].sum;

            // Draw the child
            child.draw(Rectangle(
                position.x, position.y,
                width, inner.height,
            ));

            // Proceed to the next segment
            segment += segments;
            position.x += width;

        });

    }

}

private void redistributeSpace(Range, Numeric)(ref Range range, Numeric space) {

    import std.math, std.range;

    alias RangeNumeric = ElementType!Range;

    // Get a sorted copy of the range
    auto sortedCopy = range.save.sort!"a > b";

    /// Extra space to give
    auto extra = cast(double) space - range.save.sum;

    // Do nothing if there's no eextra space
    if (extra <= 0) return;

    /// Smallest item in the range
    auto min = range.save.minElement;

    /// Space to give per segment
    RangeNumeric perElement;

    // Largest segment to apply to
    auto largest = RangeNumeric.min;

    // Assign the segments
    foreach (i, segment; sortedCopy.enumerate) {

        // Split the size over all segments, except for those exceeding our target
        perElement = min + cast(RangeNumeric) ceil(extra / (range.length - i));

        // This number can be assigned, stop
        if (perElement > segment) break;

    }

    // Assign the size
    foreach (ref item; range)  {

        // Grow this one
        item = max(item, perElement);

    }

}
