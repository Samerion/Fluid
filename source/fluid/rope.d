module fluid.rope;

import std.range;
import std.string;
import std.algorithm;
import std.exception;


@safe:


/// Rope implementation, providing more efficient modification if there's lots of text.
///
/// The `Rope` structure acts as a slice, a view into the rope's contents. If additional text is added to a node stored
/// inside, the change will not be reflected by the rope.
///
/// `rope.init` is guaranteed to be valid and empty.
///
/// See_Also: https://en.wikipedia.org/wiki/Rope_(data_structure)
struct Rope {

    static assert(isInputRange!Rope);
    static assert(isBidirectionalRange!Rope);
    static assert(isForwardRange!Rope);
    static assert(hasSlicing!Rope);

    /// Content of the rope.
    const(RopeNode)* node;

    /// Start and length of the rope, in UTF-8 bytes.
    size_t start, length;

    /// Create a rope holding given text.
    this(inout const(char)[] text) inout pure nothrow {

        // No text, stay with Rope.init
        if (text == "")
            this(null, 0, 0);
        else
            this(new inout RopeNode(text));

    }

    /// Create a rope concatenating two other ropes.
    ///
    /// Avoids gaps: If either node is empty, copies and becomes the other node.
    this(inout Rope left, inout Rope right) inout pure nothrow {

        // No need to create a new node there's empty space
        if (left.length == 0) {

            // Both empty, return .init
            if (right.length == 0)
                this(null, 0, 0);

            // Right node only, clone it
            else
                this(right);

        }

        // Only the left side is present
        else if (right.length == 0)
            this(left);

        // Neither is empty, create a new node
        else
            this(new inout RopeNode(left, right));

    }

    unittest {

        import std.stdio;

        auto bumpy = Rope(
            new RopeNode(
                Rope(""),
                Rope("foo"),
            ),
        );
        auto flattened = Rope(
            Rope(""),
            Rope("foo"),
        );

        assert(bumpy.byNode.equal(["", "foo"]));
        assert(flattened.byNode.equal(["foo"]));

        auto c = Rope(
            Rope("AAA"),
            Rope(
                Rope(""),
                Rope("BBB"),
            ),
        );
        assert(c.byNode.equal(["AAA", "BBB"]));

    }

    /// Create a rope from given node.
    this(const inout(RopeNode)* node) inout pure nothrow {

        // No node given, set all to init
        if (node is null) return;

        this.node = node;
        this.start = 0;
        this.length = node.length;

    }

    /// Copy a `Rope`.
    this(inout const Rope rope) inout pure nothrow {

        this(rope.node, rope.start, rope.length);

    }

    private this(inout(RopeNode)* node, size_t start, size_t length) inout pure nothrow {

        this.node = node;
        this.start = start;
        this.length = length;

    }

    unittest {

        auto rope = Rope(Rope.init, Rope("foo"));

        assert(rope == "foo");

    }

    /// Get a hash of the rope.
    size_t toHash() const nothrow {

        import std.digest.murmurhash;

        auto hash = MurmurHash3!32();

        // Hash each item
        foreach (item; byNode) {

            assert(item.isLeaf);

            hash.put(cast(const ubyte[]) item.value);

        }

        return hash.get();

    }

    unittest {

        auto rope = Rope("This is Fluid!");
        auto rope2 = Rope(
            Rope("This is "),
            Rope("Fluid!"),
        );

        assert(rope.toHash == rope.toHash);
        assert(rope.toHash == rope2.toHash);
        assert(rope2.toHash == rope2.toHash);
        assert(rope2.left.toHash == rope2.left.toHash);
        assert(rope2.right.toHash == rope2.right.toHash);

        assert(rope2.left.toHash != rope2.right.toHash);
        assert(rope2.left.toHash != rope2.toHash);
        assert(rope2.left.toHash != rope.toHash);
        assert(rope2.right.toHash != rope2.toHash);
        assert(rope2.right.toHash != rope.toHash);

    }

    /// Compare the text to a string.
    bool opEquals(const char[] str) const nothrow {

        return equal(this[], str[]);

    }

    /// Compare two ropes.
    bool opEquals(const Rope str) const nothrow {

        return equal(this[], str[]);

    }

    /// Assign a new value to the rope.
    ref opAssign(const char[] str) return nothrow {

        return opAssign(new RopeNode(str));

    }

    /// ditto
    ref opAssign(RopeNode* node) return nothrow {

        this.node = node;
        this.start = 0;
        this.length = node ? node.length : 0;
        return this;

    }

    /// Concatenate two ropes together.
    Rope opBinary(string op : "~")(const Rope that) const nothrow {

        return Rope(this, that);

    }

    /// Concatenate with a string.
    Rope opBinary(string op : "~")(const(char)[] text) const nothrow {

        return Rope(this, Rope(text));

    }

    /// ditto
    Rope opBinaryRight(string op : "~")(const(char)[] text) const nothrow {

        return Rope(Rope(text), this);

    }

    /// True if the node is a leaf.
    bool isLeaf() const nothrow {

        return node is null
            || node.isLeaf;

    }

    Rope save() const nothrow {

        return this;

    }

    /// If true, the rope is empty.
    bool empty() const nothrow {

        return node is null
            || length == 0;

    }

    /// Get the first *byte* from the rope.
    char front() const nothrow {

        assert(!empty, "Cannot access `.front` in an empty rope");

        // Load nth character of the leaf
        if (node.isLeaf)
            return node.value[start];

        // Accessing the left node
        else if (!left.empty)
            return left.front;

        // Accessing the right node
        else
            return right.front;

    }

    /// Remove the first byte from the rope.
    void popFront() nothrow {

        assert(!empty, "Cannot `.popFront` in an empty rope");

        start++;
        length--;

    }

    /// Get the last *byte* from the rope.
    char back() const nothrow {

        assert(!empty, "Cannot access `.back` in an empty rope");

        // Decode the nth character of the leaf
        if (node.isLeaf)
            return node.value[start + length - 1];

        // Accessing the right node
        else if (!right.empty)
            return right.back;

        // Accessing the left node
        else
            return left.back;

    }

    /// Remove the last byte from the rope.
    void popBack() nothrow {

        length--;

    }

    /// Return a mutable slice.
    Rope opIndex() const nothrow {

        return this;

    }

    /// Get character at given index.
    char opIndex(size_t index) const nothrow {

        assert(index < length, format!"Given index [%s] exceeds rope length %s"(index, length).assumeWontThrow);

        // Access the nth byte of the leaf
        if (node.isLeaf)
            return node.value[start + index];

        // Accessing the left node
        else if (index < left.length)
            return left[index];

        // Accessing the right node
        else
            return right[index - left.length];

    }

    /// Get the rope's length.
    size_t opDollar() const nothrow {

        return length;

    }

    /// Slice the rope.
    Rope opIndex(size_t[2] slice, string caller = __PRETTY_FUNCTION__) const nothrow {

        assert(slice[0] <= length,
            format!"Left boundary of slice [%s .. %s] exceeds rope length %s"(slice[0], slice[1], length)
                .assumeWontThrow);
        assert(slice[1] <= length,
            format!"Right boundary of slice [%s .. %s] exceeds rope length %s"(slice[0], slice[1], length)
                .assumeWontThrow);
        assert(slice[0] <= slice[1],
            format!"Right boundary of slice [%s .. %s] is greater than left boundary"(slice[0], slice[1])
                .assumeWontThrow);

        // .init stays the same
        if (node is null) return Rope.init;

        slice[] += start;

        // Flatten if slicing into a specific side of the slice
        // e.g. Rope(Rope("foo"), Rope("bar"))[0..3] returns Rope("foo")
        if (!isLeaf) {

            const divide = node.left.length;

            // Slicing into the left node
            if (slice[1] <= divide)
                return node.left[slice];

            // Slicing into the right node
            else if (slice[0] >= divide)
                return node.right[slice[0] - divide .. slice[1] - divide];

        }

        // Overlap or a leaf: return both as they are
        return Rope(node, slice[0], slice[1] - slice[0]);

    }

    unittest {

        auto myRope = Rope(
            Rope("foo"),
            Rope("bar"),
        );

        assert(myRope[0..3].isLeaf);
        assert(myRope[0..3] == "foo");
        assert(myRope[3..6].isLeaf);
        assert(myRope[3..6] == "bar");
        assert(myRope[1..2].isLeaf);
        assert(myRope[1..2] == "o");
        assert(myRope[4..5].isLeaf);
        assert(myRope[4..5] == "a");

        auto secondRope = Rope(
            myRope,
            myRope,
        );

        assert(secondRope[1..$][0..2].isLeaf);
        assert(secondRope[1..$][0..2] == "oo");

    }

    size_t[2] opSlice(size_t dim : 0)(size_t left, size_t right) const nothrow {

        return [left, right];

    }

    /// Get the depth of the rope.
    size_t depth() const nothrow {

        // Leafs have depth of 1
        if (isLeaf) return 1;

        return max(node.left.depth, node.right.depth) + 1;

    }

    unittest {

        auto a = Rope();
        assert(a.depth == 1);

        auto b = Rope("foo");
        assert(b.depth == 1);

        auto c = Rope(
            Rope("foo"),
            Rope("bar"),
        );
        assert(c.depth == 2);

        auto d = Rope(b, c);
        assert(d.depth == 3);

        auto e = Rope(d, d);
        assert(e.depth == 4);

    }

    /// Get a leaf node that is a subrope starting with the given index. The length of the node may vary, and does not
    /// have to reach the end of the rope.
    Rope leafFrom(size_t start) const nothrow
    out (r; r.isLeaf)
    do {

        auto slice = this[start..$];

        // The slice is a leaf node, return it
        if (slice.isLeaf)
            return slice;

        // Not a leaf, get the chunk containing the node
        if (slice.left.empty)
            return slice.right.leafFrom(0);
        else
            return slice.left.leafFrom(0);

    }

    ///
    unittest {

        auto myRope = Rope(
            Rope("Hello, "),
            Rope(
                Rope("Flu"),
                Rope("id"),
            ),
        );

        assert(myRope.leafFrom(0) == Rope("Hello, "));
        assert(myRope.leafFrom(7) == Rope("Flu"));
        assert(myRope.leafFrom(10) == Rope("id"));

        assert(myRope.leafFrom(2) == Rope("llo, "));
        assert(myRope.leafFrom(7) == Rope("Flu"));
        assert(myRope.leafFrom(8) == Rope("lu"));
        assert(myRope.leafFrom(9) == Rope("u"));

        assert(myRope.leafFrom(myRope.length) == Rope.init);

    }

    /// Get the left side of the rope
    Rope left() const nothrow {

        if (node is null) return Rope.init;

        const start = min(node.left.length, start);
        const end = min(node.left.length, start + length);

        return node.left[start .. end];

    }

    unittest {

        auto a = Rope("ABC");
        auto b = Rope("DEF");
        auto ab = Rope(a, b);

        assert(ab.left.equal("ABC"));
        assert(ab[1..$].left.equal("BC"));
        assert(ab[3..$].left.equal(""));
        assert(ab[4..$].left.equal(""));
        assert(ab[0..4].left.equal("ABC"));
        assert(Rope(ab.node, 0, 3).left.equal("ABC"));
        assert(Rope(ab.node, 0, 2).left.equal("AB"));
        assert(Rope(ab.node, 0, 1).left.equal("A"));
        assert(ab[0..0].left.equal(""));
        assert(ab[1..1].left.equal(""));
        assert(ab[4..4].left.equal(""));

        assert(ab[0..3].equal("ABC"));
        assert(ab[0..2].equal("AB"));
        assert(ab[0..1].equal("A"));

    }

    unittest {

        auto a = Rope("ABC")[1..$];
        auto b = Rope("DEF")[1..$];
        auto ab = Rope(a, b);

        assert(ab.left.equal("BC"));
        assert(ab[1..$].left.equal("C"));
        assert(ab[3..$].left.equal(""));
        assert(ab[4..$].left.equal(""));
        assert(ab[0..4].left.equal("BC"));
        assert(ab[0..3].left.equal("BC"));
        assert(Rope(ab.node, 0, 2).left.equal("BC"));
        assert(Rope(ab.node, 0, 1).left.equal("B"));
        assert(ab[0..0].left.equal(""));
        assert(ab[1..1].left.equal(""));
        assert(ab[4..4].left.equal(""));

        assert(ab[0..2].equal("BC"));
        assert(ab[0..1].equal("B"));

    }

    /// Get the right side of the rope
    Rope right() const nothrow {

        if (node is null) return Rope.init;

        const leftStart = min(node.left.length, start);
        const leftEnd = min(node.left.length, start + length);

        const start = min(node.right.length, this.start - leftStart);
        const end = min(node.right.length, this.start + length - leftEnd);

        return node.right[start .. end];

    }

    unittest {

        auto a = Rope("ABC");
        auto b = Rope("DEF");
        auto ab = Rope(a, b);

        assert(ab.right.equal("DEF"));
        assert(ab[1..$].right.equal("DEF"));
        assert(Rope(ab.node, 3, 3).right.equal("DEF"));
        assert(Rope(ab.node, 4, 2).right.equal("EF"));
        assert(Rope(ab.node, 4, 1).right.equal("E"));
        assert(Rope(ab.node, 3, 2).right.equal("DE"));
        assert(ab[2..$-1].right.equal("DE"));
        assert(ab[1..1].right.equal(""));
        assert(ab[4..4].right.equal(""));

        assert(ab[3..$].equal("DEF"));
        assert(ab[4..$].equal("EF"));
        assert(ab[4..$-1].equal("E"));
        assert(ab[3..$-1].equal("DE"));

    }

    unittest {

        auto a = Rope("ABC")[1..$];  // BC
        auto b = Rope("DEF")[1..$];  // EF
        auto ab = Rope(a, b);

        assert(ab.right.equal("EF"));
        assert(ab[1..$].right.equal("EF"));
        assert(Rope(ab.node, 3, 1).right.equal("F"));
        assert(Rope(ab.node, 4, 0).right.equal(""));
        assert(Rope(ab.node, 1, 2).right.equal("E"));
        assert(Rope(ab.node, 2, 1).right.equal("E"));
        assert(Rope(ab.node, 3, 0).right.equal(""));
        assert(ab[1..1].right.equal(""));
        assert(ab[4..4].right.equal(""));

        assert(ab[3..$].equal("F"));
        assert(ab[4..$].equal(""));
        assert(ab[1..$-1].right.equal("E"));
        assert(ab[2..$-1].equal("E"));
        assert(ab[3..$-1].equal(""));

    }

    /// Get the value of this rope. Only works for leaf nodes.
    const(char)[] value() const nothrow {

        // Null node → null string
        if (node is null) return null;

        return node.value[start .. start + length];

    }

    /// Split the rope, creating a new root node that connects the left and right side of the split.
    ///
    /// This functions never returns leaf nodes, but either side of the node may be empty.
    Rope split(size_t index) const nothrow
    out (r; !r.node.isLeaf)
    do {

        assert(index <= length, format!"Split index (%s) exceeds rope length %s"(index, length).assumeWontThrow);

        auto left = this.left;
        auto right = this.right;

        const(RopeNode)* result;

        // Leaf node, split by slicing
        if (node.isLeaf)
            result = new RopeNode(this[0..index], this[index..$]);

        // Already split
        else if (index == left.length)
            return this;

        // Splitting inside left node
        else if (index < left.length) {

            auto div = left.split(index);

            result = new RopeNode(
                div.left,
                Rope(div.right, right),
            );

        }

        // Splitting inside right node
        else {

            auto div = right.split(index - left.length);

            result = new RopeNode(
                Rope(left, div.left),
                div.right,
            );

        }

        return Rope(result);

    }

    unittest {

        auto a = Rope("Hello, World!");
        auto b = a.split(7);

        assert(b.node.left == "Hello, ");
        assert(b.node.right == "World!");

        auto startSplit = a.split(0);

        assert(startSplit.node.left == "");
        assert(startSplit.node.right == a);

        auto endSplit = a.split(a.length);

        assert(endSplit.node.left == a);
        assert(endSplit.node.right == "");

        auto c = a[1..$-4].split(6);

        assert(c.node.left == "ello, ");
        assert(c.node.right == "Wo");

    }

    unittest {

        auto myRope = Rope(
            Rope(
                Rope("HËl"),
                Rope("lo"),
            ),
            Rope(
                Rope(", "),
                Rope(
                    Rope("Wor"),
                    Rope("ld!"),
                ),
            )
        );

        assert(myRope.equal("HËllo, World!"));
        assert(myRope[1..$].equal("Ëllo, World!"));

        {
            auto split = myRope[1..$].split(6);

            assert(split.equal("Ëllo, World!"));
            assert(split.left.equal("Ëllo,"));
            assert(split.right.equal(" World!"));
        }
        {
            auto split = myRope[5..$-3].split(4);

            assert(split.equal("o, Wor"));
            assert(split.left.equal("o, W"));
            assert(split.right.equal("or"));
        }
        {
            auto split = myRope.split(6);
            assert(split == myRope);
            assert(split.left.equal("HËllo"));
        }
        {
            auto split = myRope[1..$].split(5);
            assert(split == myRope[1..$]);
            assert(split.left.equal("Ëllo"));
        }
        {
            auto split = myRope.split(0);
            assert(split.left.equal(""));
            assert(split.right.equal(myRope));
        }
        {
            auto split = myRope.split(myRope.length);
            assert(split.left.equal(myRope));
            assert(split.right.equal(""));
        }
        {
            auto split = myRope[1..$].split(0);

            assert(split.left.equal(""));
            assert(split.right.equal("Ëllo, World!"));
        }
        {
            auto split = myRope[1..$-1].split(myRope.length-2);
            assert(split.left.equal("Ëllo, World"));
            assert(split.right.equal(""));
        }

    }

    /// Insert a new node into the rope.
    Rope insert(size_t index, Rope value) const nothrow {

        // Perform a split
        auto split = split(index);

        // Insert the element
        return Rope(split.left, Rope(value, split.right));

    }

    unittest {

        auto a = Rope("Hello, !");
        auto b = a.insert(7, Rope("World"));

        assert(a.equal("Hello, !"));
        assert(b.equal("Hello, World!"));

        assert(Rope("World!")
            .insert(0, Rope("Hello, "))
            .equal("Hello, World!"));
        assert(Rope("Hellø, ")
            .insert(8, Rope("Fluid!"))
            .equal("Hellø, Fluid!"));

    }

    unittest {

        auto a = Rope("Hello, !");
        auto b = a.insert(7, Rope("rl"));

        assert(b.equal("Hello, rl!"));

        auto c = b.insert(7, Rope("Wo"));

        assert(c.equal("Hello, Worl!"));

        auto d = c.insert(11, Rope("d"));

        assert(d.equal("Hello, World!"));

    }

    /// Replace value between two indexes with a new one.
    ///
    /// Params:
    ///     low   = Low index, inclusive; First index to delete.
    ///     high  = High index, exclusive; First index after the newly inserted fragment to keep.
    ///     value = Value to insert.
    Rope replace(size_t low, size_t high, Rope value) const nothrow {

        assert(low <= high,
            format!"Low boundary of replace slice [%s .. %s] is greater than the high boundary"(low, high)
                .assumeWontThrow);
        assert(high <= length,
            format!"Replace slice [%s .. %s] exceeds Rope length %s"(low, high, length)
                .assumeWontThrow);

        // Return the value as-is if the node is empty
        if (length == 0)
            return value;

        // Split the rope in both points
        const leftSplit = split(low);
        const rightSplit = split(high);

        return Rope(
            leftSplit.left,
            Rope(
                value,
                rightSplit.right,
            ),
        );

    }

    unittest {

        auto a = Rope("Hello, World!");
        auto b = a.replace(7, 12, Rope("Fluid"));

        assert(b == "Hello, Fluid!");

        auto c = Rope("Foo Bar Baz Ban");
        auto d = c.replace(4, 12, Rope.init);

        assert(d == "Foo Ban");

    }

    unittest {

        auto a = Rope(
            Rope("Hello"),
            Rope("Fluid"),
        );
        auto b = a.replace(3, 6, Rope("LOf"));

        assert(b == "HelLOfluid");
        assert(b.byNode.equal(["Hel", "LOf", "luid"]));

        auto c = b.replace(3, 6, Rope("~~~"));

        assert(c.byNode.equal(["Hel", "~~~", "luid"]));

        auto d = c.replace(0, 3, Rope("***"));

        assert(d.byNode.equal(["***", "~~~", "luid"]));

        auto e = d.replace(3, 10, Rope("###"));

        assert(e.byNode.equal(["***", "###"]));

    }

    unittest {

        auto a = Rope("Hello, World!");

        // Replacing with an empty node should effectively split
        a = a.replace(7, 12, Rope(""));
        assert(a.byNode.equal(["Hello, ", "!"]));

        // Insert characters into the text by replacing a whole node
        a = a.replace(7, 7, Rope("a"));
        assert(a.byNode.equal(["Hello, ", "a", "!"]));

        a = a.replace(7, 8, Rope("ab"));
        assert(a.byNode.equal(["Hello, ", "ab", "!"]));

        a = a.replace(7, 9, Rope("abc"));
        assert(a.byNode.equal(["Hello, ", "abc", "!"]));

        // Now, reuse the same node
        auto node = new RopeNode("abcd");

        a = a.replace(7, 10, Rope(node));
        assert(a.byNode.equal(["Hello, ", "abcd", "!"]));
        assert(a == "Hello, abcd!");

        // Adding the node should have no effect since slices weren't updated
        node.value = "abcde";
        assert(a == "Hello, abcd!");

        // Update the slices
        a = a.replace(7, 11, Rope(node));
        assert(a.byNode.equal(["Hello, ", "abcde", "!"]));
        assert(a == "Hello, abcde!");

    }

    unittest {

        auto a = Rope("Rope");

        a = a.replace(0, 2, Rope("Car"));

        assert(a.byNode.equal(["Car", "pe"]));

        a = a.replace(5, 5, Rope(" diem"));

        assert(a.byNode.equal(["Car", "pe", " diem"]));

    }

    unittest {

        auto a = Rope();

        a = a.replace(0, 0, Rope("foo"));

        assert(a.byNode.equal(["foo"]));
        assert(a.isLeaf);

    }

    /// Replace given substring with a new value
    Rope replace(String)(String oldValue, Rope value) const nothrow {

        const start = this[].indexOf(oldValue);
        const end = start + oldValue.length;

        // Substring not found, do nothing
        if (start == -1) return this;

        return replace(start, end, value);

    }

    unittest {

        assert(Rope("foo baz baz").replace("baz", Rope("bar")) == "foo bar baz");

    }

    /// Append text to the rope.
    ref Rope opOpAssign(string op : "~")(const(char)[] value) return nothrow {

        auto left = this;

        return this = Rope(left, Rope(value));

    }

    /// Append another rope to the rope.
    ref Rope opOpAssign(string op : "~")(const Rope value) return nothrow {

        auto left = this;

        return this = Rope(left, value);

    }

    /// Iterate the rope by characters.
    auto byDchar() const {

        import std.utf : byDchar;

        return byDchar(this[]);

    }

    /// Count characters in the string. Iterates the whole rope.
    size_t countCharacters() const {

        return byDchar.walkLength;

    }

    /// Perform deep-first search through nodes of the rope.
    auto byNode() inout {

        import std.container.dlist;

        struct ByNode {

            DList!Rope ancestors;
            Rope front;
            bool empty;

            /// Switch to the next sibling or ascend.
            void popFront() @safe nothrow {

                assert(!empty);

                // No ancestors remain, stop
                if (ancestors.empty) {
                    empty = true;
                    return;
                }

                // Get the last ancestor; remove it so we don't return to it
                auto parent = ancestors.back;
                ancestors.removeBack;

                // Switch to its right sibling
                descend(parent.right);

            }

            /// Descend into given node.
            void descend(Rope node) @safe nothrow {

                // Leaf node, set as front
                if (node.isLeaf) {
                    front = node;
                    return;
                }

                // Descend
                ancestors.insertBack(node);

                // Start from the left side
                descend(node.left);

            }

        }

        auto result = ByNode();
        result.descend(this);
        return result;

    }

    unittest {

        auto mr = Rope(
            Rope("a"),
            Rope(
                Rope(
                    Rope(
                        Rope("b"),
                        Rope(
                            Rope("c"),
                            Rope("d"),
                        ),
                    ),
                    Rope(
                        Rope("e"),
                        Rope("f"),
                    ),
                ),
                Rope("g")
            ),
        );

        assert(mr.byNode.equal([
            Rope("a"),
            Rope("b"),
            Rope("c"),
            Rope("d"),
            Rope("e"),
            Rope("f"),
            Rope("g"),
        ]));

    }

    /// Get line in the rope by a byte index.
    /// Returns: A rope slice with the line containing the given index.
    Rope lineByIndex(KeepTerminator keepTerminator = No.keepTerminator)(size_t index) const
    in (index >= 0 && index <= length, format!"Index %s is out of bounds of Rope of length %s"(index, length))
    do {

        import fluid.typeface : Typeface;

        auto back  = Typeface.lineSplitter(this[0..index].retro).front;
        auto front = Typeface.lineSplitter!keepTerminator(this[index..$]).front;

        static assert(is(ElementType!(typeof(back)) == char));
        static assert(is(ElementType!(typeof(front)) == char));

        const backLength  = back.walkLength;
        const frontLength = front.walkLength;

        // Combine everything on the same line, before and after the cursor
        return this[index - backLength .. index + frontLength];

    }

    unittest {

        Rope root;
        assert(root.lineByIndex(0) == "");

        root = root ~ "aaą\nbbČb\n c \r\n\n **Ą\n";
        assert(root.lineByIndex(0) == "aaą");
        assert(root.lineByIndex(1) == "aaą");
        assert(root.lineByIndex(4) == "aaą");
        assert(root.lineByIndex(5) == "bbČb");
        assert(root.lineByIndex(7) == "bbČb");
        assert(root.lineByIndex(10) == "bbČb");
        assert(root.lineByIndex(11) == " c ");
        assert(root.lineByIndex!(Yes.keepTerminator)(11) == " c \r\n");
        assert(root.lineByIndex(16) == "");
        assert(root.lineByIndex!(Yes.keepTerminator)(16) == "\n");
        assert(root.lineByIndex(17) == " **Ą");
        assert(root.lineByIndex(root.value.length) == "");
        assert(root.lineByIndex!(Yes.keepTerminator)(root.value.length) == "");

    }

    /// Get the column the given index is on.
    /// Returns:
    ///     Return value depends on the type fed into the function. `column!dchar` will use characters and `column!char`
    ///     will use bytes. The type does not have effect on the input index.
    ptrdiff_t column(Chartype)(size_t index) const {

        import std.utf : byUTF;
        import fluid.typeface : Typeface;

        // Get last line
        return Typeface.lineSplitter(this[0..index].retro).front

            // Count characters
            .byUTF!Chartype.walkLength;

    }

    unittest {

        Rope root;
        assert(root.column!dchar(0) == 0);

        root = Rope(" aąąą");
        assert(root.column!dchar(8) == 5);
        assert(root.column!char(8) == 8);

        root = Rope(" aąąąO\n");
        assert(root.column!dchar(10) == 0);
        assert(root.column!char(10) == 0);

        root = Rope(" aąąąO\n ");
        assert(root.column!dchar(11) == 1);

        root = Rope(" aąąąO\n Ω = 1+2");
        assert(root.column!dchar(14) == 3);
        assert(root.column!char(14) == 4);

    }

    /// Get the index of the start or end of the line — from index of any character on the same line.
    size_t lineStartByIndex(size_t index) {

        return index - column!char(index);

    }

    /// ditto
    size_t lineEndByIndex(size_t index) {

        return lineStartByIndex(index) + lineByIndex(index).length;

    }

    ///
    unittest {

        auto rope = Rope("Hello, World!\nHello, Fluid!");

        assert(rope.lineStartByIndex(5) == 0);
        assert(rope.lineEndByIndex(5) == 13);
        assert(rope.lineStartByIndex(18) == 14);
        assert(rope.lineEndByIndex(18) == rope.length);

    }

    struct DiffRegion {

        size_t start;
        Rope first;
        Rope second;

        alias asArray this;

        /// Returns true if the two compared ropes are identical.
        bool isSame() const {

            return first.empty && second.empty;

        }

        inout(Rope)[2] asArray() inout {

            return [first, second];

        }

    }

    /// Find the difference between the two ropes, in terms of a single contiguous region.
    /// Params:
    ///     other = Rope to compare this rope to.
    /// Returns:
    ///     The region containing the change, in terms of two subropes. The first rope is a subrope exclusive to this
    ///     rope, and the second is a subrope exclusive to the other.
    ///
    ///     The return value includes a `start` field which indicates the exact index the resulting range starts with.
    DiffRegion diff(const Rope other) const {

        if (!isLeaf) {

            // Left side is identical, compare right side only
            if (left is other.left) {

                auto result = right.diff(other.right);

                return DiffRegion(left.length + result.start, result.first, result.second);

            }

            // Or, right side is identical
            else if (right is other.right) {

                return left.diff(other.left);

            }

        }

        Rope result;

        // Perform string comparison
        const prefix = commonPrefix(this[], other[]).length;
        const suffix = commonPrefix(this[prefix..$].retro, other[prefix..$].retro).length;

        const start = prefix;
        const thisEnd = this.length - suffix;
        const otherEnd = other.length - suffix;

        return DiffRegion(start,
            thisEnd == 0
                ? Rope()
                : this[start .. thisEnd],
            otherEnd == 0
                ? Rope()
                : other[start .. otherEnd]);

    }

    unittest {

        auto rope1 = Rope("Hello, World!");
        auto rope2 = Rope("Hello, Fluid!");
        auto diff = rope1.diff(rope2);

        assert(diff.start == 7);
        assert(diff[].equal(["Worl", "Flui"]));

    }

    unittest {

        auto rope1 = Rope("Hello!");
        auto rope2 = Rope("Hello!");

        assert(rope1.diff(rope2)[] == [Rope(), Rope()]);

    }

    unittest {

        auto rope1 = Rope(
            Rope("Hello, "),
            Rope("World!"));
        auto rope2 = Rope("Hello, Fluid!");
        auto diff = rope1.diff(rope2);

        assert(diff.start == 7);
        assert(diff[].equal([
            "Worl",
            "Flui",
        ]));

    }

    unittest {

        auto rope = Rope(
            Rope(
                Rope("auto rope"),
                Rope(
                    Rope("1"),
                    Rope(" = Rope();"),
                )
            ),
            Rope(
                Rope(
                    Rope("auto rope2 = Rope(\""),
                    Rope("Hello, Fluid!")
                ),
                Rope(
                    Rope("\");"),
                    Rope("auto diff = rope1.diff(rope2);"),
                ),
            )
        );

        assert(
            rope.replace(0, 4, Rope("Rope"))
                .diff(rope)
            == DiffRegion(0, Rope("Rope"), Rope("auto"))
        );

        auto tmp = rope;

        auto findRope1() {

            return tmp.indexOf("rope1");

        }

        assert(
            rope
                .replace("rope1", Rope("rope"))
                .replace("rope1", Rope("rope"))
                .diff(rope)
            == DiffRegion(
                9,
                Rope(` = Rope();auto rope2 = Rope("Hello, Fluid!");auto diff = rope`),
                Rope(`1 = Rope();auto rope2 = Rope("Hello, Fluid!");auto diff = rope1`))
        );

    }

    unittest {

        auto core = Rope("foobar");
        auto rope1 = core[0..5];
        auto rope2 = rope1.replace(0, 5, core);

        assert(rope1 == "fooba");
        assert(rope2 == "foobar");
        assert(rope1.diff(rope2) == DiffRegion(5, Rope(""), Rope("r")));

    }

    unittest {

        auto core = Rope("foobar");
        auto rope1 = Rope(core[0..5], Rope(";"));
        auto rope2 = rope1.replace(0, 5, core);

        assert(rope1 == "fooba;");
        assert(rope2 == "foobar;");
        assert(rope1.diff(rope2) == DiffRegion(5, Rope(""), Rope("r")));

    }

    unittest {

        auto core = Rope("foobar");
        auto rope1 = Rope(
            Rope("return "),
            Rope(
                core[0..5],
                Rope(`("Hello, World!");`)
            ),
        );
        auto rope2 = rope1.replace(7, 7+5, core);

        assert(rope1 == `return fooba("Hello, World!");`);
        assert(rope2 == `return foobar("Hello, World!");`);
        assert(rope1.diff(rope2) == DiffRegion(12, Rope(""), Rope("r")));

    }

    /// Put the rope's contents inside given output range.
    void toString(Writer)(ref Writer w) const {

        foreach (node; byNode) {

            put(w, node.value);

        }

    }

    unittest {

        auto rope1 = Rope("bar");
        const rope2 = Rope(
            Rope("b"),
            Rope(
                Rope("a"),
                Rope("r"),
            ),
        );

        assert(format!"Foo, %s, baz"(rope1) == "Foo, bar, baz");
        assert(format!"Foo, %s, baz"(rope2) == "Foo, bar, baz");

    }

    string toString() const @trusted {

        // Allocate space for the string
        auto buffer = new char[length];

        // Write all characters
        foreach (i, char ch; this[].enumerate) {

            buffer[i] = ch;

        }

        return cast(string) buffer;

    }

    unittest {

        auto rope1 = Rope("bar");
        const rope2 = Rope(
            Rope("b"),
            Rope(
                Rope("a"),
                Rope("r"),
            ),
        );

        assert(rope1.toString == "bar");
        assert(rope2.toString == "bar");

    }

    immutable(char)* toStringz() const @trusted {

        return cast(immutable) toStringzMutable;

    }

    char* toStringzMutable() const {

        // Allocate space for the whole string and a null terminator
        auto buffer = new char[length + 1];

        // Write all characters
        foreach (i, char ch; this[].enumerate) {

            buffer[i] = ch;

        }

        // Add a terminator null byte
        buffer[$-1] = '\0';

        return &buffer[0];

    }

    @system
    unittest {

        import core.stdc.string;
        
        auto input = Rope("Hello, World!");

        assert(strlen(input.toStringzMutable) == input.length);

    }


}

struct RopeNode {

    public {

        /// Left child of this node.
        Rope left;

        /// Right child of this node.
        Rope right;

        /// Direct content of the node, if a leaf node.
        ///
        /// This must be a fully valid string. Content may not be split in the middle of a codepoint.
        const(char)[] value;

    }

    /// Create a leaf node from a slice
    this(inout const(char)[] text) inout pure nothrow {

        this.value = text;

    }

    /// Create a node from two other node; Concatenate the two other nodes. Both must not be null.
    this(inout Rope left, inout Rope right) inout pure nothrow {

        this.left = left;
        this.right = right;

    }

    /// Get length of this node.
    size_t length() const pure nothrow {

        return isLeaf
            ? value.length
            : left.length + right.length;

    }

    /// True if this is a leaf node and contains text rather than child nodes.
    bool isLeaf() const pure nothrow {

        return left.node is null
            && right.node is null;

    }

}

unittest {

    auto a = Rope("Hello, ");
    auto b = Rope("World! ");

    auto combined = Rope(a, b);

    assert(combined.equal("Hello, World! "));
    assert(combined[1..$].equal("ello, World! "));
    assert(combined[1..5].equal("ello"));

}

unittest {

    assert(Rope.init.empty);
    assert(Rope("  Hello, World! ").strip == "Hello, World!");
    assert(Rope("  Hello, World! ").stripLeft == "Hello, World! ");
    assert(Rope("  Hello, World! ").stripRight == "  Hello, World!");

}

/// `std.utf.codeLength` implementation for Rope.
alias codeLength(T : Rope) = imported!"std.utf".codeLength!char;
