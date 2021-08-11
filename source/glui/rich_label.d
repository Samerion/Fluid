///
module glui.rich_label;

import raylib;

import std.conv;
import std.meta;
import std.array;
import std.typecons;
import std.algorithm;

import glui.node;
import glui.utils;
import glui.style;

alias richLabel = simpleConstructor!GluiRichLabel;

@safe:

/// Defines a part of the label text.
struct Part {

    /// Style to apply for this part. If null, uses default style instead.
    Style style;

    /// Text for this part.
    string text;

}

enum isPart(T) = is(T : Style) || is(T == string);

/// A rich label can display text on the screen and apply custom styling to parts of the text.
/// Warning, doesn't support wrapping as of yet.
/// Styles: $(UL
///     $(LI `style` = Default style for this node.)
/// )
class GluiRichLabel : GluiNode {

    mixin ImplHoveredRect;

    /// Parts defining label text.
    Part[] textParts;

    static foreach (index; 0 .. BasicNodeParamLength) {

        /// Initialize the label with given text.
        /// Params:
        ///     content = Style objects and strings to define parts of the text.
        this(T...)(BasicNodeParam!index sup, T content)
        if (allSatisfy!(isPart, T)) {

            super(sup);

            foreach (elem; content) {

                this ~= elem;

            }

        }

    }

    /// Change the style for next part of the text.
    void opOpAssign(string op : "~")(Style style) {

        textParts ~= Part(style, "");

    }

    /// Append new text.
    void opOpAssign(string op : "~", T : string)(T text)
    if (!is(T == typeof(null))) {

        // If there is a part to append to
        if (textParts.length) {

            textParts[$-1].text ~= text;

        }

        // Nope, make a new part
        else textParts ~= Part(null, text);

    }

    /// Push text to the label.
    /// Params:
    ///     style = Style of the text.
    ///     text  = Text to add.
    void push(Style style, string text) {

        textParts ~= Part(style, text);

    }

    /// Ditto.
    void push(string text) {

        this ~= text;

    }

    /// Get the current text of the label, as plain text.
    string text() const {

        return textParts
            .map!"a.text"
            .join;

    }

    /// Erase all label contents.
    void clear() {

        textParts = [];

    }

    protected override void resizeImpl(Vector2 available) {

        minSize = style.measureText(available, text);

    }

    protected override void drawImpl(Rectangle rect) {

        const style = pickStyle();
        style.drawBackground(rect);

        /// Current position on the screen to append to.
        auto cursor = Vector2(rect.x, rect.y);

        foreach (part; textParts) {

            auto text = part.text;

            while (text.length) {

                auto current = text.until("\n", No.openRight).to!string;
                text = text[current.length .. $];

                // Get area to draw in
                auto thisStyle = part.style is null ? style : part.style;
                auto area = thisStyle.measureText(
                    Rectangle(cursor.x, cursor.y, rect.w, rect.h),
                    current
                );
                // TODO: wrapping+indent

                thisStyle.drawBackground(area);
                thisStyle.drawText(area, current);

                // Move the cursor
                cursor.y += area.h - thisStyle.fontSize * thisStyle.lineHeight;

                // Ended with a newline
                if (current[$-1] == '\n') cursor.x = rect.x;
                else cursor.x += area.w;

            }

        }

    }

    protected override const(Style) pickStyle() const {

        return style;

    }

}
