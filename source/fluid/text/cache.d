/// This module provides a cache for text data, such as screen position and line numbers.
module fluid.text.cache;

import std.range;
import std.traits;
import std.format;
import std.algorithm;

import fluid.text.rope;
import fluid.text.ruler;
import fluid.text.typeface;

@safe:

/// Represents the distance between two points in in text.
struct TextInterval {

    /// Length of the interval in bytes.
    size_t length;

    /// Number of line breaks in this range; 0-indexed line number.
    size_t line;

    /// Number of characters since the last line break; 0-indexed column number.
    size_t column;

    this(size_t length, size_t line, size_t column) {

        this.length = length;
        this.line   = line;
        this.column = column;

    }

    /// Calculate the interval occupied by a range (rope or string).
    /// Params:
    ///     fragment = Fragment to measure.
    this(Range)(Range fragment) 
    if (isSomeChar!(ElementType!Range) && (hasLength!Range || isSomeString!Range))
    do {

        this.length = fragment.length;

        // Count lines in the string, find the length of the last line
        foreach (line; Typeface.lineSplitter(fragment)) {

            this.line++;
            this.column = line.length;

        }

        // Decrement line count
        if (this.line) this.line--;

    }

    @("An empty string creates an empty interval")
    unittest {

        assert(TextInterval("")       == TextInterval.init);
        assert(TextInterval(Rope("")) == TextInterval.init);

    }

    /// Sum the intervals. Order of operation matters — `other` should come later in text than `this`.
    /// Params:
    ///     other = Next interval; interval to merge with.
    /// Returns:
    ///     A new interval that is a sum of both intervals.
    TextInterval opBinary(string op : "+")(const TextInterval other) const {

        // If the other point has a line break, our column does not affect it
        // Add them only if there is no line break 
        const column = other.line
            ? other.column
            : other.column + column;

        return TextInterval(length + other.length, line + other.line, column);

    }

    ref TextInterval opOpAssign(string op : "+")(const TextInterval other) {

        return this = this + other;

    }

    /// Change the point of reference for this interval, as if skipping characters from the start of the string. This
    /// is the interval equivalent of `std.range.drop` or a `[n..$]` slice. 
    ///
    /// This function is an inverse of interval sum (+), where `head` is the left hand side argument, and the return 
    /// value is the right hand side argument.
    ///
    /// Returns:
    ///     This interval, but set relative to `head`.
    /// Params:
    ///     head = Point inside this interval to use as a reference.
    TextInterval dropHead(const TextInterval head) const
    in (this.length >= head.length, format!"`head` cannot be longer (%s) than `this` (%s)"(head.length, this.length))
    out (r; head + r == this)
    do {

        // If the head points to some line in the middle, the resulting column stays the same.
        //     [Lorem ipsum dolor sit amet, consectetur adipiscing 
        //     elit, sed do eiusmod tempor] incididunt ut labore et 
        //     dolore magna aliqua.
        //                        ^ this.column, return.column
        if (head.line != this.line) {
            return TextInterval(length - head.length, line - head.line, this.column);
        }

        // If the head points to the last line, however, the column will be a difference.
        //     [Lorem ipsum dolor sit amet, consectetur adipiscing 
        //     elit, sed do eiusmod tempor incididunt ut labore et 
        //     dolore magna] aliqua.
        //     head.column ^       ^ this.column
        else {
            return TextInterval(length - head.length, line - head.line, this.column - head.column);
        }

    }

}

/// Cache result matching a point in text to a `TextRuler`.
package struct CachedTextRuler {

    /// Point (interval from the start of the text) at which the measurement was made.
    TextInterval point;

    /// Ruler containing information about the current position in the text.
    TextRuler ruler;

    alias ruler this;

}

/// This is a cache storing instances of `TextRuler` corresponding to different positions in the same text. This makes
/// it possible to find screen position of any character in text by its index. It also maps each of these points to a 
/// line and column number combo, making it possible to query characters by their position in the grid.
///
/// Entries into the cache are made in intervals. The cache will return the last found cache entry rather than one 
/// directly corresponding to the queried character. To get an exact position, the text ruler can be advanced by 
/// measuring all characters in between.
package struct TextRulerCache {

    /// Ruler at the start of this range.
    TextRuler startRuler;

    /// Interval covered by this range.
    TextInterval interval;

    /// Left and right branch of this cache entry.
    TextRulerCache* left, right;

    /// Depth of this node.
    int depth = 1;

    debug (Fluid_CacheInvariants)
    invariant {

        if (left) {


            assert(start, "Right branch is null, but the left isn't");
            assert(startRuler is left.startRuler);
            assert(interval == left.interval + right.interval, 
                format!"Cache interval %s is not the sum of its members %s + %s"(interval, left.interval, 
                    right.interval));
            assert(depth == max(left.depth, right.depth) + 1);

        }

        else {
            
            assert(right is null, "Left branch is null, but the right isn't");
            assert(depth == 1);

        }

    }

    /// Initialize the cache with the given `TextRuler` parameters.
    this(Typeface typeface, float lineWidth = float.nan) {

        this(TextRuler(typeface, lineWidth));

    }

    this(TextRuler ruler) {

        this.startRuler = ruler;

    }

    private this(TextRuler ruler, TextInterval interval) {

        this.startRuler = ruler;
        this.interval = interval;

    }

    private this(TextRulerCache* left, TextRulerCache* right) {

        this.startRuler = left.startRuler;
        this.interval = left.interval + right.interval;
        this.left = left;
        this.right = right;
        this.depth = max(left.depth, right.depth) + 1;

    }

    private void recalculateDepth() {

        // isLeaf inlined to avoid invariants
        if (left)
            depth = max(left.depth, right.depth) + 1;
        else
            depth = 1;

    }

    /// Returns: True if this cache contains exactly one entry. In such case, it will not have any children nodes.
    bool isLeaf() const {

        return left is null;

    }

    /// Resize a fragment of text, recalculating offsets of rulers.
    /// Params:
    ///     start       = Distance between start of the text and start of both intervals.
    ///     oldInterval = Interval (size) to be replaced.
    ///     newInterval = Interval to be inserted.
    void updateInterval(TextInterval start, TextInterval oldInterval, TextInterval newInterval) {

        // Nothing to do
        if (oldInterval.length == 0 && newInterval.length == 0) return;

        const absoluteStart = start;
        const absoluteEnd = start + oldInterval;

        scope cache = &this;

        // Delete all entries in the range
        // TODO this could be far more efficient
        for (auto range = query(&this, absoluteStart.length); !range.empty;) {

            // Skip the first entry, it is not affected
            if (range.front.point.length <= absoluteStart.length) {
                range.popFront;
                continue;
            }

            // Skip entires after the range
            if (range.front.point.length > absoluteEnd.length) break;

            range.removeFront;

        }

        // Find a relevant node, update intervals of all ancestors and itself
        // thus pushing or pulling subsequent nodes 
        if (absoluteEnd.length < cache.interval.length)
        while (true) {

            const oldEnd = start + oldInterval;
            const newEnd = start + newInterval;

            cache.interval = newEnd + cache.interval.dropHead(oldEnd);

            // Found the deepest relevant node
            // `isLeaf` is inlined to keep invariants from running
            if (cache.left is null) break; 

            // Search for a node that can control the start of the interval; either exactly at the start, 
            // or shortly before it, just like `query()`
            if (start.length <= cache.left.interval.length) {
                cache = cache.left;
            }
            else {
                start = start.dropHead(cache.left.interval);
                cache = cache.right;
            }

        }

    }

    /// Insert a ruler into the cache.
    /// Params:
    ///     point = Point to place the ruler at; text interval preceding the ruler.
    ///     ruler = Ruler to insert.
    void insert(TextInterval point, TextRuler ruler) {

        // Detect appending
        if (point.length > interval.length) {

            append(point, ruler);
            return;

        }

        // Find a point in this cache to enter
        auto range = query(&this, point.length);
        auto cache = range.stack.back;
        auto foundPoint = range.front.point;

        // Found an exact match, replace it
        if (point == foundPoint) {

            range.front = ruler;
            return;

        }

        // Inserting between two points
        else {

            assert(cache.interval.length != 0, "Cache data invalid, failed to detect append");

            const oldInterval = cache.interval;

            // We're inserting in between two points; `leftInterval` is distance from the left to our point, 
            // `rightInterval` is the distance from our point to the next point. Total distance is `cache.interval`.
            //
            //   ~~~~~~~~~~~~ cache.interval ~~~~~~~~~~~~
            //   |  leftInterval     |  rightInterval   |  (relative)
            //   ^ left.startRuler   ^ right.startRuler
            //   ^ foundPoint        ^ point               (absolute)
            const leftInterval = point.dropHead(foundPoint);
            const rightInterval = cache.interval.dropHead(leftInterval);

            assert(foundPoint   + leftInterval == point);
            assert(leftInterval + rightInterval == cache.interval);

            auto left = new TextRulerCache(cache.startRuler, leftInterval);
            auto right = new TextRulerCache(ruler, rightInterval);

            *range.stack.back = TextRulerCache(left, right);

            assert(range.stack.back.startRuler == left.startRuler);
            assert(range.stack.back.interval == oldInterval);
            assert(range.stack.back.interval == leftInterval + rightInterval);

            range.updateDepth();
            rebalance();

        }

    }

    /// Append a ruler to the cache.
    /// Params:
    ///     point = Point to place the ruler at; text interval preceding the ruler. This must point beyond interval
    ///         covered by the cache.
    ///     ruler = Ruler to insert.
    private void append(TextInterval point, TextRuler ruler)
    in (point.length > interval.length)
    do {

        scope cache = &this;
        auto relativePoint = point;

        // Descend (isLeaf inlined for debugging performance)
        while (cache.left !is null) {

            // Update interval and depth
            cache.interval = relativePoint;
            cache.depth++;

            // Descend towards the right side
            relativePoint = relativePoint.dropHead(cache.left.interval);
            cache = cache.right;

        }

        // Insert the node
        auto left  = new TextRulerCache(cache.startRuler, relativePoint);
        auto right = new TextRulerCache(ruler, TextInterval.init);

        *cache = TextRulerCache(left, right);        
        rebalance();

    }

    /// Returns: True if this cache node is out of balance. 
    /// See_Also: `rebalance` to rebalance a node to improve its performance.
    bool isBalanced() const {

        if (isLeaf) return true;

        const diff = left.depth - right.depth;
                
        return -10 < diff && diff < 10;

    }

    /// Recreate the cache to redistribute the nodes in a more optimal way.
    void rebalance() {

        if (!isBalanced) {

            auto nodes = appender!(TextRulerCache*[])();

            // Collect all nodes
            for (auto range = query(&this, 0); !range.empty; range.popFront) {

                assert(range.stack.back.isLeaf);
                nodes ~= range.stack.back;

            }

            this = *merge(nodes[]);

        }

    }

    /// Returns: A new cache node compromising multiple cache nodes.
    /// Params:
    ///     nodes = Leaf nodes the new cache can be made up of. They must be ordered, so that their intervals will 
    ///         specify their relations.
    static TextRulerCache* merge(scope TextRulerCache*[] nodes) {

        if (nodes.length == 0)
            assert(false, "Given node list is empty");
        else if (nodes.length == 1)
            return nodes[0];
        else if (nodes.length == 2)
            return new TextRulerCache(nodes[0], nodes[1]);
        else
            return new TextRulerCache(
                merge(nodes[0   .. $/2]),
                merge(nodes[$/2 .. $])
            );
        
        
    }
    
}

/// Get the last `TextRuler` at the given index, or preceding it.
/// Params:
///     index = Index to search for.
/// Returns:
///     A `TextRuler` struct wrapper with an extra `point` field to indicate the location in text the point 
///     corresponds to.
package auto query(return scope TextRulerCache* cache, size_t index)
out (r; !r.empty)
out (r) {
    static assert(is(ElementType!(typeof(r)) : const CachedTextRuler), ElementType!(typeof(r)).stringof);
}
do {

    import fluid.text.stack;

    static struct CacheStackFrame {

        TextRulerCache* cache;

        /// True if this is a parent node, and it has descended into the right side.
        bool isRight;

        alias cache this;

    }

    /// This range iterates the cache tree in order while skipping all but the last element that precedes the index. 
    /// It builds  a stack, the last item of which points to the current element of the range. Since the cache is 
    /// a binary tree in which each node either has one or two children, the stack can only have three possible 
    /// states:
    ///
    /// * It is empty, and so is this range
    /// * It points to a leaf (which is a valid state for `front`)
    /// * The last item has two children, so it needs to descend.
    ///
    /// During descend, left nodes are chosen, unless the first item — the needle — is on the right side. When 
    /// ascending (`popFront`), right nodes are chosen as left nodes have already been tested. To make sure the 
    /// right side is not visited again, nodes are not pushed to the stack when their right side is. For example,
    /// when iterating through a node `A` which has children `B` and `C`, the stack is initialized to `[A]`. 
    /// Descend is first done into `B`, resulting in `[A, B]`. First `popFront` removes `B` and descends the right
    /// side of `A` replacing it with `C`. The stack is `[C]`.
    static struct TextRulerCacheRange {

        Stack!CacheStackFrame stack;
        size_t needle;
        TextInterval offset;

        invariant(stack.empty || stack.back !is null);

        @safe:

        inout(CachedTextRuler) front() inout {
            return inout CachedTextRuler(
                offset,
                stack.back.startRuler
            );
        }

        /// Assign a new value to the front
        ref TextRuler front(TextRuler ruler) @trusted {

            stack.back.startRuler = ruler;

            // Update startRuler in all ancestors
            // @trusted: stack is not touched through other means
            foreach (ancestor; stack[].dropOne) {
                static assert(isPointer!(typeof(ancestor.cache)));

                // End as soon as an unaffected ancestor is reached
                if (ancestor.startRuler is ancestor.left.startRuler) break;
                
                ancestor.startRuler = ancestor.left.startRuler;

            }

            return stack.back.startRuler;

        }

        bool empty() const {
            return stack.empty;
        }

        void popFront() {

            assert(!empty);
            assert(stack.back.isLeaf);

            offset += stack.back.interval;

            // Remove the leaf (front)
            stack.removeBack();
            ascendAndDescend();

        }

        /// Move upwards in the stack to find any yet unvisited node.
        private void ascendAndDescend() {

            // Find any parent that has right right side unvisited
            // `isRight` means the parents has already descended into its right side
            while (!stack.empty && stack.back.isRight) {
                stack.removeBack();
            }
            if (stack.empty) return;

            auto ancestor = stack.back;

            assert(ancestor.right);

            // Remove the next node and descend into its right side
            stack.back.isRight = true;
            stack ~= CacheStackFrame(ancestor.right);
            descend();

        }

        /// Update depth of the current node. Iterates through all ancestors.
        void updateDepth() @trusted {

            // Update depth of every item in the stack
            // @trusted: ancestors ain't touched
            foreach (item; stack[]) {
                item.recalculateDepth();
            }

        }

        /// Remove the entry at the front of the range from the cache and advance to the next item.
        ///
        /// This cannot be used to remove the first entry in the cache.
        void removeFront() {

            // TODO tests for this

            assert(!empty);
            assert(stack.back.isLeaf);

            // Can't remove the root
            assert(offset.length != 0, "Cannot remove the first item in the cache.");

            const front = stack.back;
            
            // Ascend back to the parent
            stack.removeBack();
            auto parent = stack.back;

            // The node we're removing is on the right side, replace it with the left
            if (front is parent.right) {

                const interval = parent.interval;

                *parent = *parent.left;
                parent.interval = interval;
                updateDepth();
                ascendAndDescend();

            }

            // The node we're removing is on the left side
            else if (front is parent.left) {

                const offset = parent.left.interval;

                this.offset += offset;

                // Move the right side to replace it
                *parent = *parent.right;

                // Now to keep the right side in the correct place, the interval has to be added to whatever node 
                // precedes it. This means we must find an adjacent branch that goes leftwards. We will search our 
                // ancestors: one containing a preceding node will have `isRight` set to `true`, i.e. the current node
                // is in the right branch. 
                // @trusted: no stack.removeBack() calls
                () @trusted {

                    TextRulerCache* previous;
                    foreach (ancestor; stack[].dropOne) {

                        ancestor.recalculateDepth();

                        // Found the previous node already, just recalculate depth
                        if (previous) continue;

                        // Move the offset from the removed node to the previous leaf node
                        if (ancestor.isRight) {
                            previous = ancestor.left;
                            continue;
                        }
                
                        // Recalculate the start and interval
                        ancestor.startRuler = ancestor.left.startRuler;
                        ancestor.interval = ancestor.left.interval + ancestor.right.interval;

                    }

                    assert(previous);

                    // Descend into the preceding branch (always going right), expanding the interval of every node until 
                    // we hit a leaf. 
                    while (previous) {
                        previous.interval += offset;
                        previous = previous.right;
                    }

                }();

                descend();

                assert(stack.back.isLeaf);

            }

            else assert(false);

        }

        /// Advance the range to the next leaf
        private void descend() {

            while (!stack.back.isLeaf) {

                auto front = stack.back;

                // Enter the left side, unless we know the needle is in the right side
                if (needle < offset.length + front.left.interval.length) {

                    stack.back.isRight = false;
                    stack ~= CacheStackFrame(front.left);

                }

                // Enter the right side
                else {

                    stack.back.isRight = true;
                    stack ~= CacheStackFrame(front.right);
                    offset += front.left.interval;

                }

            }

        }

    }
    
    auto ruler = TextRulerCacheRange(
        Stack!CacheStackFrame(
            CacheStackFrame(cache)
        ),
        index
    );
    ruler.descend();

    return ruler;

}

@("Query on a leaf cache returns the first item")
unittest {

    import fluid.style;

    auto cache = new TextRulerCache();

    assert(cache.query(0).equal([TextRuler.init]));
    assert(cache.query(1).equal([TextRuler.init]));
    assert(cache.query(10).equal([TextRuler.init]));

    auto ruler = TextRuler(Style.defaultTypeface, 10);
    *cache = TextRulerCache(ruler);

    assert(cache.query(0).equal([ruler]));
    assert(cache.query(1).equal([ruler]));
    assert(cache.query(10).equal([ruler]));

}

@("TextRulerCache.insert works")
unittest {

    import fluid.style;

    auto cache = new TextRulerCache();
    auto typeface = Style.defaultTypeface;

    auto points = [
        CachedTextRuler(TextInterval( 0, 0,  0), TextRuler(typeface, 1)),
        CachedTextRuler(TextInterval( 5, 0,  5), TextRuler(typeface, 2)),
        CachedTextRuler(TextInterval(10, 0, 10), TextRuler(typeface, 3)),
        CachedTextRuler(TextInterval(15, 1,  3), TextRuler(typeface, 4)),
        CachedTextRuler(TextInterval(20, 1,  8), TextRuler(typeface, 5)),
        CachedTextRuler(TextInterval(25, 2,  1), TextRuler(typeface, 6)),
    ];

    // 12 character long lines, snapshots every 5 characters
    cache.insert(points[0].tupleof);
    cache.insert(points[1].tupleof);
    cache.insert(points[2].tupleof);
    cache.insert(points[3].tupleof);
    cache.insert(points[4].tupleof);
    cache.insert(points[5].tupleof);

    assert(cache.query( 0).equal(points));
    assert(cache.query( 1).equal(points));
    
    assert(cache.query( 7).equal(points[1..$]));
    assert(cache.query(30).equal(points[5..$]));
    assert(cache.query(18).equal(points[3..$]));
    assert(cache.query(15).equal(points[3..$]));

    auto newPoints = [
        CachedTextRuler(TextInterval( 0, 0,  0), TextRuler(typeface, 7)),
        CachedTextRuler(TextInterval(12, 1,  0), TextRuler(typeface, 8)),
        CachedTextRuler(TextInterval(24, 2,  0), TextRuler(typeface, 9)),
    ];

    points = points[1..$];
    points ~= newPoints;
    sort!"a.point.length < b.point.length"(points);

    // Insert a few more snapshots
    cache.insert(newPoints[2].tupleof);
    cache.insert(newPoints[0].tupleof);
    cache.insert(newPoints[1].tupleof);
    
    assert(cache.query(0).equal(points));

}

@("Text automatically creates TextRulerCache entries")
unittest {

    import fluid.label;
    import fluid.default_theme;

    auto root = label(nullTheme, "Lorem ipsum dolor sit amet, consectetur " 
        ~ "adipiscing elit, sed do eiusmod tempor " 
        ~ "incididunt ut labore et dolore magna " 
        ~ "aliqua. Ut enim ad minim veniam, quis " 
        ~ "nostrud exercitation ullamco laboris " 
        ~ "nisi ut aliquip ex ea commodo consequat." 
        ~ "adipiscing elit, sed do eiusmod tempor " 
        ~ "incididunt ut labore et dolore magna " 
        ~ "aliqua. Ut enim ad minim veniam, quis " 
        ~ "nostrud exercitation ullamco laboris " 
        ~ "nisi ut aliquip ex ea commodo consequat.\n" 
        ~ "\n" 
        ~ "Duis aute irure dolor in reprehenderit " 
        ~ "in voluptate velit esse cillum dolore " 
        ~ "eu fugiat nulla pariatur. Excepteur " 
        ~ "sint occaecat cupidatat non proident, " 
        ~ "sunt in culpa qui officia deserunt " 
        ~ "Duis aute irure dolor in reprehenderit " 
        ~ "in voluptate velit esse cillum dolore " 
        ~ "eu fugiat nulla pariatur. Excepteur " 
        ~ "sint occaecat cupidatat non proident, " 
        ~ "sunt in culpa qui officia deserunt " 
        ~ "mollit anim id est laborum.\n");

    assert(root.text._updateRangeStart == 0);
    assert(root.text._updateRangeEnd == root.text.length);

    root.draw();

    auto typeface = root.style.getTypeface;
    auto space = root.io.windowSize;

    assert(root.text[422] == '\n');
    assert(query(&root.text._cache, 0).equal!"a.point == b"([
        TextInterval(  0, 0,   0),
        TextInterval(263, 0, 263),
        TextInterval(527, 2, 103),
        TextInterval(787, 2, 363),
        TextInterval(root.text.length, 3, 0),
    ]));

    version (none) {
        // Why isn't this equal?
        auto ruler = TextRuler(typeface, space.x);
        typeface.measure(ruler, "");
        assert(query(&root.text._cache,   0).front == ruler);
    }
    {
        auto ruler = TextRuler(typeface, space.x);
        typeface.measure(ruler, root.text[0..263]);
        assert(query(&root.text._cache, 263).front == ruler);
    }
    {
        auto ruler = TextRuler(typeface, space.x);
        typeface.measure(ruler, root.text[0..527]);
        assert(query(&root.text._cache, 527).front == ruler);
    }
    {
        auto ruler = TextRuler(typeface, space.x);
        typeface.measure(ruler, root.text[0..787]);
        assert(query(&root.text._cache, 787).front == ruler);
    }

}

@("Text can update TextRulerCache entries")
unittest {

    import fluid.label;
    import fluid.default_theme;

    auto root = label(nullTheme, "Lorem ipsum dolor sit amet, consectetur " 
        ~ "adipiscing elit, sed do eiusmod tempor " 
        ~ "incididunt ut labore et dolore magna " 
        ~ "aliqua. Ut enim ad minim veniam, quis " 
        ~ "nostrud exercitation ullamco laboris " 
        ~ "adipiscing elit, sed do eiusmod tempor " 
        ~ "incididunt ut labore et dolore magna " 
        ~ "aliqua. Ut enim ad minim veniam, quis " 
        ~ "nostrud exercitation ullamco laboris " 
        ~ "nisi ut aliquip ex ea commodo consequat.\n" 
        ~ "\n" 
        ~ "Duis aute irure dolor in reprehenderit " 
        ~ "in voluptate velit esse cillum dolore " 
        ~ "eu fugiat nulla pariatur. Excepteur " 
        ~ "sint occaecat cupidatat non proident, " 
        ~ "sunt in culpa qui officia deserunt " 
        ~ "mollit anim id est laborum.\n");

    root.draw();

    // Same data as in the last test
    debug assert(query(&root.text._cache, 0).equal!"a.point == b"([
        TextInterval(  0, 0,   0),
        TextInterval(261, 0, 261),
        TextInterval(521, 2, 137),
        TextInterval(root.text.length, 3, 0),
    ]));

    // Replace enough text to destroy two intervals
    root.text[260..530] = 'a'.repeat(270).array;

    assert(root.tree.resizePending);
    
    root.draw();

    assert(query(&root.text._cache, 0).equal!"a.point == b"([
        TextInterval(  0, 0,   0),
        TextInterval(535, 0, 535),  // intervals are gone, line breaks are gone
        TextInterval(root.text.length, 1, 0),
    ]));

    assert(root.text[534..539] == " sunt");

}

@("Text updates cache intervals on write")
unittest {

    import fluid.label;
    import fluid.default_theme;

    auto root = label(nullTheme, "import fluid;\n"
        ~ "void main() {\n"
        ~ "    run(\n"
        ~ "        label(\"Hello, World!\")\n"
        ~ "    );\n"
        ~ "}\n");

    auto typeface = root.pickStyle.getTypeface;

    // Clear cache
    root.text.reload();
    root.text._cache.insert(TextInterval( 0, 0,  0), TextRuler(typeface, 0));
    root.text._cache.insert(TextInterval(14, 1,  0), TextRuler(typeface, 1));
    root.text._cache.insert(TextInterval(28, 2,  0), TextRuler(typeface, 2));
    root.text._cache.insert(TextInterval(37, 3,  0), TextRuler(typeface, 3));
    root.text._cache.insert(TextInterval(67, 3, 30), TextRuler(typeface, 4));
    root.text._cache.insert(TextInterval(68, 4,  0), TextRuler(typeface, 5));
    root.text._cache.insert(TextInterval(75, 5,  0), TextRuler(typeface, 6));

    const start = 37 + `        label("Hello, `.length;

    root.text[start .. start + "World".length] = "everyone!\nHave a nice day";

    assert(query(&root.text._cache, 0).equal([
         CachedTextRuler(TextInterval( 0, 0,  0), TextRuler(typeface, 0)),
         CachedTextRuler(TextInterval(14, 1,  0), TextRuler(typeface, 1)),
         CachedTextRuler(TextInterval(28, 2,  0), TextRuler(typeface, 2)),
         CachedTextRuler(TextInterval(37, 3,  0), TextRuler(typeface, 3)),
         CachedTextRuler(TextInterval(87, 4, 18), TextRuler(typeface, 4)),
         CachedTextRuler(TextInterval(88, 5,  0), TextRuler(typeface, 5)),
         CachedTextRuler(TextInterval(95, 6,  0), TextRuler(typeface, 6)),
    ]));
    
}

@("Cache node removal works")
@trusted 
unittest {

    import fluid.style;

    auto typeface = Style.defaultTypeface;

    // Cache with entries at 0 and 10
    TextRulerCache make() {
        auto left  = new TextRulerCache(TextRuler(typeface, 1), TextInterval( 6, 1, 0));
        auto right = new TextRulerCache(TextRuler(typeface, 2), TextInterval( 4, 1, 0));
        return TextRulerCache(left, right);
    }

    {
        // Remove entry at 10
        auto root = make();
        query(&root, 10).removeFront;

        // Only the first entry should survive
        assert(query(&root, 0).equal([
            CachedTextRuler(TextInterval(0, 0, 0), TextRuler(typeface, 1)),
        ]));
    }

    // Removing a node in the middle
    {
        auto left = make();
        auto right = make();
        auto root = TextRulerCache(&left, &right);

        // Remove a right side node ((0, 6), (10, 16)) -> (0, (10, 16))
        query(&root, 6).removeFront;

        assert(query(&root, 0).equal([
            CachedTextRuler(TextInterval(0,  0, 0), TextRuler(typeface, 1)),
            CachedTextRuler(TextInterval(10, 2, 0), TextRuler(typeface, 1)),
            CachedTextRuler(TextInterval(16, 3, 0), TextRuler(typeface, 2)),
        ]));

        // Remove a left side node (0, (10, 16)) -> (0, 16)
        query(&root, 10).removeFront;

        assert(query(&root, 0).equal([
            CachedTextRuler(TextInterval(0,  0, 0), TextRuler(typeface, 1)),
            CachedTextRuler(TextInterval(16, 3, 0), TextRuler(typeface, 2)),
        ]));
        
    }

    // Clearing it out
    {
        TextRulerCache[6] nodes = make();
        auto root = TextRulerCache(&nodes[0], 
            new TextRulerCache(
                new TextRulerCache(
                    &nodes[1],
                    &nodes[2],
                ),
                new TextRulerCache(
                    &nodes[3],
                    new TextRulerCache(
                        &nodes[4],
                        &nodes[5],
                    )
                )
            )
        );

        assert(query(&root, 0).equal([
            CachedTextRuler(TextInterval( 0,  0, 0), TextRuler(typeface, 1)),
            CachedTextRuler(TextInterval( 6,  1, 0), TextRuler(typeface, 2)),
            CachedTextRuler(TextInterval(10,  2, 0), TextRuler(typeface, 1)),
            CachedTextRuler(TextInterval(16,  3, 0), TextRuler(typeface, 2)),
            CachedTextRuler(TextInterval(20,  4, 0), TextRuler(typeface, 1)),
            CachedTextRuler(TextInterval(26,  5, 0), TextRuler(typeface, 2)),
            CachedTextRuler(TextInterval(30,  6, 0), TextRuler(typeface, 1)),
            CachedTextRuler(TextInterval(36,  7, 0), TextRuler(typeface, 2)),
            CachedTextRuler(TextInterval(40,  8, 0), TextRuler(typeface, 1)),
            CachedTextRuler(TextInterval(46,  9, 0), TextRuler(typeface, 2)),
            CachedTextRuler(TextInterval(50, 10, 0), TextRuler(typeface, 1)),
            CachedTextRuler(TextInterval(56, 11, 0), TextRuler(typeface, 2)),
        ]));

        for (auto range = query(&root, 10); !range.empty; range.removeFront) { }

        assert(query(&root, 0).equal([
            CachedTextRuler(TextInterval( 0, 0, 0), TextRuler(typeface, 1)),
            CachedTextRuler(TextInterval( 6, 1, 0), TextRuler(typeface, 2)),
        ]));
    }

}

@("Text can be filled and cleared in a loop")
unittest {

    import fluid.label;

    auto word = 'a'.repeat(256);
    const text = Rope(word.repeat(2).join(" "));

    auto root = label("");

    foreach (i; 0..100) {

        root.text = text;
        root.draw();
        assert(query(&root.text._cache, 0).walkLength > 1);

        root.text = "";
        root.draw();
        assert(query(&root.text._cache, 0).walkLength == 1);

    }

}
