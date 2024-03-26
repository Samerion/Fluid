///
module fluid.label;

import fluid.node;
import fluid.text;
import fluid.utils;
import fluid.style;
import fluid.backend;

@safe:

/// A label can be used to display text on the screen.
alias label = simpleConstructor!Label;

/// ditto
class Label : Node {

    public {

        /// Text of this label.
        Text!Label text;

        /// If true, the content of the label should not be wrapped into new lines if it's too long to fit into one.
        bool isWrapDisabled;

    }

    this(Rope text) {

        this.text = Text!Label(this, text);

    }

    this(const(char)[] text) {

        this.text = Text!Label(this, text);

    }

    /// Set wrap on for this node.
    This disableWrap(this This = Label)() return {

        isWrapDisabled = true;
        return cast(This) this;

    }

    /// Set wrap off for this node
    This enableWrap(this This = Label)() return {

        isWrapDisabled = false;
        return cast(This) this;

    }

    bool isEmpty() const {

        return text.length == 0;

    }

    protected override void resizeImpl(Vector2 available) {

        import std.math;

        text.resize(available, !isWrapDisabled);
        minSize = text.size;

    }

    protected override void drawImpl(Rectangle outer, Rectangle inner) {

        const style = pickStyle();
        style.drawBackground(tree.io, outer);
        text.draw(style, inner.start);

    }

    unittest {

        auto io = new HeadlessBackend;
        auto root = label("Hello, World!");

        with (Rule)
        root.theme = nullTheme.derive(
            rule!Label(textColor = color!"000"),
        );
        root.io = io;
        root.draw();

        const initialTextArea = root.text.size.x * root.text.size.y;

        io.assertTexture(root.text.texture.chunks[0], Vector2(0, 0), color!"fff");
        io.nextFrame;

        root.text ~= " It's a nice day today!";
        root.draw();

        io.assertTexture(root.text.texture.chunks[0], Vector2(0, 0), color!"fff");

        const newTextArea = root.text.size.x * root.text.size.y;

        assert(newTextArea > initialTextArea);

    }

    override string toString() const {

        import std.range;
        import std.format;

        return format!"Label(%(%s%))"(only(text.toString));

    }

}

///
unittest {

    // Label takes just a single argument: the text to display
    auto myLabel = label("Hello, World!");

    // You can access and change label text
    myLabel.text ~= " It's a nice day today!";

    // Text will automatically wrap if it's too long to fit, but you can toggle it off
    myLabel.isWrapDisabled = true;

}
