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
        foreach (line; Rope(fragment).byLine) {

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
struct CachedTextRuler {

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
///
/// See_Also:
///     `query`
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

            const index = range.front.point.length;

            // Skip preceding entires, they're not affected
            // However, an equal entry can affect word breaking, so it should be deleted
            if (index < absoluteStart.length || index == 0) {
                range.popFront;
                continue;
            }

            // Skip entries after the range
            if (index > absoluteEnd.length) break;

            range.removeFront;

        }

        // Find a relevant node, update intervals of all ancestors and itself
        // thus pushing or pulling subsequent nodes 
        if (absoluteEnd.length < cache.interval.length)
        while (true) {

            const oldEnd = start + oldInterval;
            const newEnd = start + newInterval;

            debug assert (cache.interval.length >= oldEnd.length, 
                format!"`head` cannot be longer (%s) than `this` (%s)\n%s"(
                    oldEnd.length, cache.interval.length, diagnose));

            cache.interval = newEnd + cache.interval.dropHead(oldEnd);

            // Found the deepest relevant node
            // `isLeaf` is inlined to keep invariants from running
            if (cache.left is null) break; 

            // Search for a node that can control the start of the interval; either exactly at the start, 
            // or shortly before it, just like `query()`
            if (start.length < cache.left.interval.length) {
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

            debug scope (failure) {
                import std.stdio;
                stderr.writeln("Insert failure detected, dumping cache:");
                stderr.writeln(toRope);
            }

            assert(cache.interval.length != 0, 
                "Failed to detect append; Cache data is inconsistent");
            assert(point.length > foundPoint.length, 
                "Failed to detect append; Last item in the cache must be of length 0");
            assert(point.length < foundPoint.length + cache.interval.length, 
                "Cache data is inconsistent; missed an insert point.");

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

    /// Find and report issues in the cache's storage.
    ///
    /// This function is intended for debugging crashes caused by issues in the `TextCache` data 
    /// and isn't normally needed during program flow.
    ///
    /// The way the cache is structured is prone to bugs that may be difficult to locate. These will usually
    /// manifest in the form of a broken state. This function will walk the cache, searching for inconsistencies
    /// in its data, and reporting them in the form of a rope.
    ///
    /// Returns:
    ///     An empty rope if no flaws were found, or a rope presenting the tree, highlighting flawed nodes.
    Rope diagnose() const @system {

        import fluid.text.stack;
        import std.conv : to;

        struct StackFrame {
            const(TextRulerCache)* cache;
            bool isLeftVisited;
            bool isRightVisited;
        }

        auto stack = Stack!StackFrame(StackFrame(&this));
        auto info = Rope("Cache fault: ");

        // Navigate the stack
        while (!stack.empty) {

            const node = stack.top.cache;

            // Leaf node, nothing to do
            if (node.isLeaf) {
                stack.pop();
            }

            // Flawed node, quit
            else if (node.left.interval + node.right.interval != node.interval) {
                info ~= Rope("Children intervals ") ~ node.left.interval.length.to!string
                    ~ Rope(" + ") ~ node.right.interval.length.to!string
                    ~ Rope(" don't match parent interval ") ~ node.interval.length.to!string
                    ~ Rope("\n");
                break;
            }

            // A parent node that has already been visited, ascend
            else if (stack.top.isRightVisited) {
                stack.pop();
            }

            // Descend into the first unvisited side
            else if (stack.top.isLeftVisited) {
                stack.top.isRightVisited = true;
                stack ~= StackFrame(node.right);
            }
            else {
                stack.top.isLeftVisited = true;
                stack ~= StackFrame(node.left);
            }

        }

        // Stack empty, no issues were found
        if (stack.empty) return Rope.init;

        info ~= "--- Ruler cache trace ---\n";

        auto result = Rope.init;
        auto stackArray = stack[].array;
        TextInterval offset;

        // Output the stack trace
        foreach_reverse (frame; stackArray) {

            const node = frame.cache;

            result = Rope(offset.to!string) ~ ": TextRulerCache(" 
                ~ Rope(node.interval.to!string) ~ ", " 
                ~ Rope(node.startRuler.to!string) 
                ~ Rope(frame.isRightVisited ? " -> right"
                    : frame.isLeftVisited ? " -> left"
                    : "") ~ ")\n"
                ~ result;

            if (node.isLeaf) continue;

            if (frame.isRightVisited) {
                offset += node.left.interval;
            }

        }

        return info ~ result;

    }
    
    /// Dump data in the cache into a rope.
    /// 
    /// This function is @system because stringifying a Typeface is.
    ///
    /// Params:
    ///     indentLevel = Indent to use for each line of the rope. At the moment indent is created using four spaces 
    ///         per level.
    /// Returns: A rope representation of the cache.
    Rope toRope(int indentLevel = 0) @system {

        import std.conv : to;

        const indent = Rope(repeat(". ", indentLevel).join);
        const here = indent ~ "TextRulerCache(" ~ Rope(interval.to!string) ~ ", " ~ Rope(startRuler.to!string) ~ ")\n";

        if (isLeaf) {
            return here;
        }

        else {
            return here 
                ~ Rope(left.interval + right.interval != this.interval 
                    ? repeat("# ", indentLevel).join ~ "! Mismatched interval\n" 
                    : "")
                ~ left.toRope(indentLevel + 1) 
                ~ right.toRope(indentLevel + 1);
        }

    }

}

/// Query the cache to find the last ruler before the requested point.
///
/// The cache can be used to find position of a character in text, or reverse, to find a character based on its screen
/// position. Because storing data for every character in text would be very costly, the cache instead contains
/// "checkpoints" created every few hundred characters or so — position of each character can be found by measuring
/// text between the checkpoint and the target, which can be done with `Text.rulerAt`.
///
/// `query` will find a ruler based on text index, which can be used for finding visual position of a character,
/// and `queryPosition` will find a ruler based on screen position, effectively doing the reverse.
///
/// Note that `queryPosition` only accepts position on the Y axis as the argument. Position on the X axis varies 
/// unpredictably on bidirectional layouts.
///
/// Params:
///     cache = Cache to query.
///     index = Index to search for.
///     y     = Position (in dots) to search for.
/// Returns:
///     A range with the requested `TextRuler` — either matching the query exactly or placed before — as the first item.
///     All subsequent saved rulers will follow, so they can be updated while the text is being measured.
/// 
///     The text ruler will be wrapped with an extra `point` field to indicate the location in text the point 
///     corresponds to.
/// See_Also:
///     `Text.rulerAt` for high level API over the cache.
package auto query(return scope TextRulerCache* cache, size_t index) {

    // The predicate is used to decide if the left branch is entered (true), or skipped (false).
    // We must pick the last item that matches the index. If the right side cache is placed before the index,
    // the left side must be skipped. A.K.A. We only go left if the index is before the right node's index.
    //
    //           ↓ target                          ↓ target               
    // left |----o---|-------| right     left |--------|-------| right    
    //      ^^^^^^^^^                                  ^^^^^^^^ 
    //      selected cache                       selected cache
    //
    // (b.offset.length + b.front.left.interval.length) is the interval between the start of text and the beginning
    // of the right side interval. It is the index where left ends, and right starts.
    return queryImpl!((a, b) => a < b.offset.length + b.front.left.interval.length)(cache, index);

}

/// ditto
package auto queryPosition(return scope TextRulerCache* cache, float y) {

    import fluid.utils : end;

    // Just like in `cache()`, the middle point is used to determine the side the query descends into.
    // In this case, the Y position of the middle point is the position of the right side's `startRuler`.
    return queryImpl!((a, b) {
        
        return a < b.front.right.startRuler.caret.end.y;
            
    })(cache, y);

}

@("Cache can be queried by position")
unittest {

    import fluid.style : Style;
    import fluid.types : Vector2;

    const lineHeight = 20;

    auto typeface = Style.defaultTypeface;
    typeface.setSize(Vector2(96, 96), 0);

    auto cache = new TextRulerCache(typeface);
    auto ruler = TextRuler(typeface);

    ruler.penPosition.y = 0;

    foreach (i; 0..10) {
        cache.insert(TextInterval(i, i, 0), ruler);
        ruler.penPosition += lineHeight;
    }

    assert(cache.queryPosition(  0).front.point == TextInterval(0, 0, 0));
    assert(cache.queryPosition( 20).front.point == TextInterval(0, 0, 0));
    assert(cache.queryPosition( 21).front.point == TextInterval(1, 1, 0));
    assert(cache.queryPosition( 25).front.point == TextInterval(1, 1, 0));
    assert(cache.queryPosition(161).front.point == TextInterval(8, 8, 0));
    assert(cache.queryPosition(180).front.point == TextInterval(8, 8, 0));
    assert(cache.queryPosition(200).front.point == TextInterval(9, 9, 0));

}

private auto queryImpl(alias predicate, T)(return scope TextRulerCache* cache, T needle)
out (r; !r.empty)
out (r) {
    static assert(is(ElementType!(typeof(r)) : const CachedTextRuler), ElementType!(typeof(r)).stringof);
}
do {

    import std.functional;
    import fluid.text.stack;

    // see query()'s contents for description of this field
    alias pred = binaryFun!predicate;

    static struct CacheStackFrame {

        TextRulerCache* cache;

        /// True if this is a parent node, and it has descended into the right side.
        bool isRight;

        alias cache this;

    }

    /// This range iterates the cache tree in order while skipping all but the last element that precedes the index. 
    /// It builds a stack so that its last item points to the current element of the range. Since the cache is 
    /// a binary tree in which each node either has one or two children, the stack can only have three possible 
    /// states:
    ///
    /// * It is empty, and so is this range
    /// * It points to a leaf (which is a valid state for `front`)
    /// * The last item has two children, so it needs to descend into one to find a leaf.
    ///
    /// During descend, left nodes are chosen, unless the range's first item — the needle — is on the right side. When 
    /// ascending (`popFront`), right nodes are chosen as left nodes have already been visited.
    static struct TextRulerCacheRange {

        Stack!CacheStackFrame stack;
        T needle;
        TextInterval offset;

        invariant(stack.empty || stack.back !is null);

        @safe:

        @disable this(this);

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

        /// Similar to `updateDepth` but also adjusts the intervals of all ancestors.
        void updateDepthAndInterval() @trusted {

            foreach (item; stack[]) {
                item.recalculateDepth();
                item.interval = item.left.interval + item.right.interval;
            }

        }

        /// Remove the entry at the front of the range from the cache and advance to the next item.
        ///
        /// This cannot be used to remove the first entry in the cache.
        void removeFront() {

            assert(!empty);
            assert(stack.back.isLeaf);

            // Can't remove the root
            assert(offset.length != 0, "Cannot remove the first item in the cache.");

            const front = stack.back;
            
            // Ascend back to the parent
            stack.removeBack();
            auto parent = stack.back;

            // Apply offset to skip the current node
            offset += front.interval;

            // Removing the last node, merge with the left, remove the interval in between
            if (front is parent.right && front.interval.length == 0) {

                *parent = *parent.left;

                // The node that replaced us was either the previous leaf, or a branch containing the previous leaf.
                // The interval of the last node must be set to 0.
                collapse();

            }

            // The node we're removing is on the right side, replace it with the left
            else if (front is parent.right) {

                assert(front.isLeaf);

                auto interval = parent.interval;

                *parent = *parent.left;

                auto successor = parent.cache;

                // The node that replaced us (successor) takes over the parent's interval
                //     parent.interval == parent.left.interval + parent.right.interval
                //     parent.right.interval = parent.interval
                // This must happen recursively
                while (successor) {

                    successor.interval = interval;

                    if (successor.left) {
                        interval = interval.dropHead(successor.left.interval);
                    }
                    successor = successor.right;

                }
                
                updateDepth();
                ascendAndDescend();

            }

            // The node we're removing is on the left side
            else if (front is parent.left) {

                const offset = parent.left.interval;

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

                    // Descend into the preceding branch (always going right), expanding the interval of every node 
                    // until we hit a leaf. 
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

        /// Zero the interval of the rightmost node in the current branch. This is used to reset the length of the last
        /// node when it is removed. Clears the stack when done.
        private void collapse() 
        out (; empty)
        do {

            // Descend into the rightmost node first
            while (!stack.back.isLeaf) {

                stack.back.isRight = true;
                stack ~= CacheStackFrame(stack.back.right);

            }

            // Found a leaf, nullify its interval
            stack.back.interval = TextInterval();
            stack.pop();

            // Update intervals in the parent
            updateDepthAndInterval();

            stack.clear();

        }

        /// Advance the range to the next leaf
        private void descend() {

            while (!stack.back.isLeaf) {

                struct PredicateArgs {

                    TextInterval offset;
                    TextRulerCache* front;

                }

                auto args = PredicateArgs(offset, stack.back);

                // Enter the left side, unless we know the needle is in the right side
                if (pred(needle, args)) {

                    stack.back.isRight = false;
                    stack ~= CacheStackFrame(args.front.left);

                }

                // Enter the right side
                else {

                    stack.back.isRight = true;
                    stack ~= CacheStackFrame(args.front.right);
                    offset += args.front.left.interval;

                }

            }

        }

    }
    
    auto ruler = TextRulerCacheRange(
        Stack!CacheStackFrame(
            CacheStackFrame(cache)
        ),
        needle
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

    TextRulerCache* makeOne() {
        return new TextRulerCache(TextRuler(typeface, 3), TextInterval(10, 1, 0));
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

    // Removing the last node
    {
        TextRulerCache[4] nodes;
        foreach (ref node; nodes) node = make();
        auto root = new TextRulerCache( 
            new TextRulerCache(
                &nodes[0],
                &nodes[1],
            ),
            new TextRulerCache(
                &nodes[2],
                new TextRulerCache(
                    &nodes[3],
                    new TextRulerCache(TextRuler(typeface, 10), TextInterval(0, 0, 0))
                ),
            ),
        );

        assert(root.interval.length == 40);

        root.query(50).removeFront;

        assert(root.interval.length == 36);
        assert(root.query(0).equal([
            CachedTextRuler(TextInterval( 0,  0, 0), TextRuler(typeface, 1)),
            CachedTextRuler(TextInterval( 6,  1, 0), TextRuler(typeface, 2)),
            CachedTextRuler(TextInterval(10,  2, 0), TextRuler(typeface, 1)),
            CachedTextRuler(TextInterval(16,  3, 0), TextRuler(typeface, 2)),
            CachedTextRuler(TextInterval(20,  4, 0), TextRuler(typeface, 1)),
            CachedTextRuler(TextInterval(26,  5, 0), TextRuler(typeface, 2)),
            CachedTextRuler(TextInterval(30,  6, 0), TextRuler(typeface, 1)),
            CachedTextRuler(TextInterval(36,  7, 0), TextRuler(typeface, 2)),
        ]));
    }

    // Remove a right node with a branch on its left
    {
        auto root = new TextRulerCache(
            makeOne(),
            new TextRulerCache(
                new TextRulerCache(
                    new TextRulerCache(
                        makeOne(),
                        makeOne(),
                    ),
                    makeOne(),
                ),
                makeOne(),
            ),
        );
        auto range = root.query(0);
        range.popFrontN(3);
        range.removeFront();
        assert(root.diagnose == Rope.init, root.diagnose.toString);
        
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

@("Removing the last cache node collapses the its interval — merging with leaf")
unittest {

    import fluid.style;

    auto typeface = Style.defaultTypeface;
    auto cache = new TextRulerCache(
        new TextRulerCache(
            new TextRulerCache(TextRuler(typeface, 1), TextInterval( 6, 0, 6)),
            new TextRulerCache(TextRuler(typeface, 2), TextInterval( 4, 1, 0)),
        ),
        new TextRulerCache(
            new TextRulerCache(TextRuler(typeface, 1), TextInterval( 6, 0, 6)),
            new TextRulerCache(TextRuler(typeface, 2), TextInterval( 0, 0, 0)),
        ),
    );

    assert(cache.interval == TextInterval(16, 1, 6));
    assert(cache.right.interval == TextInterval(6, 0, 6));
    
    cache.query(20).removeFront;

    assert(cache.interval == TextInterval(10, 1, 0));
    assert(cache.right.interval == TextInterval(0, 0, 0));

}

@("TextCache integrity test & benchmark")
unittest {

    // This test may appear pretty stupid but it was used to diagnose a dumb bug
    // and a performance problem.
    // It should work in any case so it should stay anyway.

    import std.file;
    import std.datetime.stopwatch;
    import fluid.code_input;
    import fluid.backend.headless;

    const source = readText("source/fluid/text_input.d");

    auto io = new HeadlessBackend;
    auto root = codeInput();
    root.io = io;
    io.clipboard = source;

    root.draw();
    root.focus();

    root.paste();
    root.draw();

    const runCount = 3;
    const results = benchmark!({

        const target1 = root.value.length - root.value.byCharReverse.countUntil(";");
        const target = target1 - 1 - root.value[0..target1 - 1].byCharReverse.countUntil(";");

        root.caretIndex = target;
        root.paste();

    })(runCount);
    const average = results[0] / runCount;

    // Even if this is just a single paste, reformatting is bound to take a while.
    // I hope it could be faster in the future, but the current performance seems to be good enough;
    // I tried the same in IntelliJ and on my machine it's just about the same ~3 seconds, 
    // Fluid might even be slightly faster.
    assert(average <= 5.seconds, format!"Too slow: average %s"(average));
    if (average > 1.seconds) {
        import std.stdio;
        writefln!"Warning: TextCache integrity test & benchmark runs slowly, %s"(average);
    }

}
