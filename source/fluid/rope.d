module fluid.rope;

import std.range;
import std.string;
import std.algorithm;


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
    this(const(char)[] text) {

        // No text, stay with Rope.init
        if (text == "")
            this(null, 0, 0);
        else
            this(new RopeNode(text));

    }

    /// Create a rope concatenating two other ropes.
    ///
    /// Avoids gaps: If either node is empty, copies and becomes the other node.
    this(inout Rope left, inout Rope right) inout {

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
    this(inout const(RopeNode)* node) inout {

        // No node given, set all to init
        if (node is null) return;

        this.node = node;
        this.start = 0;
        this.length = node.length;

    }

    /// Copy a `Rope`.
    this(inout const Rope rope) inout {

        this(rope.node, rope.start, rope.length);

    }

    private this(inout(RopeNode)* node, size_t start, size_t length) inout {

        this.node = node;
        this.start = start;
        this.length = length;

    }

    unittest {

        auto rope = Rope(Rope.init, Rope("foo"));

        assert(rope == "foo");

    }

    /// Compare the text to a string.
    bool opEquals(const char[] str) const {

        return equal(this[], str[]);

    }

    /// Compare two ropes.
    bool opEquals(const Rope str) const {

        return equal(this[], str[]);

    }

    /// Assign a new value to the rope.
    ref opAssign(const char[] str) return {

        return opAssign(new RopeNode(str));

    }

    /// ditto
    ref opAssign(RopeNode* node) return {

        this.node = node;
        this.start = 0;
        this.length = node ? node.length : 0;
        return this;

    }

    /// Concatenate two ropes together.
    Rope opBinary(string op : "~")(Rope that) {

        return Rope(this, that);

    }

    /// Concatenate with a string.
    Rope opBinary(string op : "~")(const(char)[] text) {

        return Rope(this, Rope(text));

    }

    /// ditto
    Rope opBinaryRight(string op : "~")(const(char)[] text) {

        return Rope(Rope(text), this);

    }

    /// True if the node is a leaf.
    bool isLeaf() const {

        return node is null
            || node.isLeaf;

    }

    Rope save() const {

        return this;

    }

    /// If true, the rope is empty.
    bool empty() const {

        return node is null
            || length == 0;

    }

    /// Get the first *byte* from the rope.
    char front() const {

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
    void popFront() {

        assert(!empty, "Cannot `.popFront` in an empty rope");

        start++;
        length--;

    }

    /// Get the last *byte* from the rope.
    char back() const {

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
    void popBack() {

        length--;

    }

    /// Return a mutable slice.
    Rope opIndex() const {

        return this;

    }

    /// Get character at given index.
    char opIndex(size_t index) const {

        assert(index < length, format!"Given index [%s] exceeds rope length %s"(index, length));

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
    size_t opDollar() const {

        return length;

    }

    /// Slice the rope.
    Rope opIndex(size_t[2] slice, string caller = __PRETTY_FUNCTION__) const {

        assert(slice[0] <= length,
            format!"Left boundary of slice [%s .. %s] exceeds rope length %s"(slice[0], slice[1], length));
        assert(slice[1] <= length,
            format!"Right boundary of slice [%s .. %s] exceeds rope length %s"(slice[0], slice[1], length));
        assert(slice[0] <= slice[1],
            format!"Right boundary of slice [%s .. %s] is greater than left boundary"(slice[0], slice[1]));

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

    size_t[2] opSlice(size_t dim : 0)(size_t left, size_t right) const {

        return [left, right];

    }

    /// Get the left side of the rope
    Rope left() const {

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
    Rope right() const {

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
    const(char)[] value() const {

        // Null node → null string
        if (node is null) return null;

        return node.value[start .. start + length];

    }

    /// Split the rope, creating a new root node that connects the left and right side of the split.
    ///
    /// This functions never returns leaf nodes, but either side of the node may be empty.
    Rope split(size_t index) const
    out (r; !r.node.isLeaf)
    do {

        assert(index <= length, format!"Split index (%s) exceeds rope length %s"(index, length));

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
    Rope insert(size_t index, Rope value) const {

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
    Rope replace(size_t low, size_t high, Rope value) const {

        assert(low <= high,
            format!"Low boundary of replace slice [%s .. %s] is greater than the high boundary"(low, high));

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

    /// Append text to the rope.
    ref Rope opOpAssign(string op : "~")(ref const(char)[] value) return {

        auto left = this;

        return this = Rope(left, Rope(value));

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
    auto byNode() {

        import std.container.dlist;

        struct ByNode {

            DList!Rope ancestors;
            Rope front;
            bool empty;

            /// Switch to the next sibling or ascend.
            void popFront() @safe {

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
            void descend(Rope node) @safe {

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
    this(const(char)[] text) {

        this.value = text;

    }

    /// Create a node from two other node; Concatenate the two other nodes. Both must not be null.
    this(inout Rope left, inout Rope right) inout {

        this.left = left;
        this.right = right;

    }

    /// Get length of this node.
    size_t length() const {

        return isLeaf
            ? value.length
            : left.length + right.length;

    }

    /// True if this is a leaf node and contains text rather than child nodes.
    bool isLeaf() const {

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
