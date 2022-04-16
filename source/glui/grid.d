module glui.grid;

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

    int segmentCount;

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

                children.getChildren[i] = gridRow(arg);

            }

            // Other stuff
            else children.getChildren[i] = arg;

        }}

    }

    /// Magic to extract return value of extractParams at compile time.
    private struct Number(int num) {

        enum value = num;

    }

    /// Evaluate special parameters and get the index of the first non-special parameter (not Segments, Layout nor
    /// Theme).
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

}

/// A single row in a `GluiGrid`.
class GluiGridRow : GluiFrame {

    mixin DefineStyles;

    static foreach (i; 0..BasicNodeParamLength) {

        this(T...)(BasicNodeParam!i params, T args)
        if (is(T[0] : GluiNode) || is(T[0] : U[], U)) {

            super(params);
            this.directionHorizontal = true;

            foreach (arg; args) {

                this.children ~= arg;

            }

        }

    }

}
