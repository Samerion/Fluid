///
module fluid.number_input;

import std.ascii;
import std.range;
import std.traits;
import std.algorithm;

import fluid.node;
import fluid.input;
import fluid.utils;
import fluid.style;
import fluid.backend;
import fluid.structs;
import fluid.text_input;

alias numberInput(T) = simpleConstructor!(NumberInput!T);
alias intInput = simpleConstructor!IntInput;
alias floatInput = simpleConstructor!FloatInput;

alias IntInput = NumberInput!int;
alias FloatInput = NumberInput!float;

alias numberInputSpinner = simpleConstructor!NumberInputSpinner;


@safe:

/// Number input field.
class NumberInput(T) : AbstractNumberInput {

    static assert(isNumeric!T, "NumberInput is only compatible with numeric types.");

    mixin enableInputActions;

    public {

        /// Value of the input.
        T value = 0;

        /// Step used by the increment/decrement button.
        T step = 1;

        /// Minimum and maximum value for the input, inclusive on both ends.
        static if (isFloatingPoint!T) {
            T minValue = -T.infinity;
            T maxValue = +T.infinity;
        }
        else {
            T minValue = T.min;
            T maxValue = T.max;
        }

    }

    private {

        /// If true, the expression passed to the input has been modified. The value will be updated as soon as the
        /// input is submitted or loses focus.
        bool isDirty;

    }

    this(void delegate() @safe changed = null) {

        super(changed);

    }

    override void drawImpl(Rectangle outer, Rectangle inner) {

        auto style = pickStyle();

        super.drawImpl(outer, inner);
        spinner.draw(inner);

        // Re-evaluate the expression if focus was lost
        if (!isFocused) evaluate();

    }

    /// Update the value.
    protected void evaluate() {

        // Ignore if clean, no changes were made
        if (!isDirty) return;

        // Evaluate the expression
        evaluateImpl();

        // Update the text
        update();

        // Call change callback
        if (changed) changed();

    }

    private void evaluateImpl() {

        // TODO handle failure properly, add a warning sign or something, preserve old value
        this.value = evaluateExpression!T(super.value).value.clamp(minValue, maxValue);

        // Mark as clean
        isDirty = false;

    }

    private void update() {

        import std.conv;

        super.value = this.value.to!(char[]);

        // Resize
        updateSize();

    }

    /// Increase the value by a step.
    @(FluidInputAction.scrollUp)
    override void increment() {

        evaluateImpl();
        value += step;
        update();
        focus();

        // Call change callback
        if (changed) changed();

    }

    /// Decrease the value by a step.
    @(FluidInputAction.scrollDown)
    override void decrement() {

        evaluateImpl();
        value -= step;
        update();
        focus();

        // Call change callback
        if (changed) changed();

    }

    override protected void _changed() {

        // Instead of calling the callback, simply mark the input as dirty
        isDirty = true;

    }

    @(FluidInputAction.submit)
    override protected void _submitted() {

        // Evaluate the expression
        evaluate();

        // Submit
        super._submitted();

    }

}

///
unittest {

    // intInput lets the user specify any integer value
    intInput();

    // Float input allows floating point values
    floatInput();

    // Specify a callback to update other components as the value of this input changes
    IntInput myInput;

    myInput = intInput(delegate {

        int result = myInput.value;

    });

}

unittest {

    int calls;

    auto io = new HeadlessBackend;
    auto root = intInput(delegate {

        calls++;

    });

    root.io = io;

    // First frame: initial state
    root.focus();
    root.draw();

    assert(root.value == 0);
    assert(root.TextInput.value == "0");

    // Second frame, type in "10"
    io.nextFrame();
    io.inputCharacter("10");
    root.draw();

    // Value should remain unchanged
    assert(calls == 0);
    assert(root.value == 0);
    assert(root.TextInput.value.among("010", "10"));

    // Hit enter to update
    io.nextFrame;
    io.press(KeyboardKey.enter);
    root.draw();

    assert(calls == 1);
    assert(root.value == 10);
    assert(root.TextInput.value == "10");

    // Test math equations
    io.nextFrame;
    io.inputCharacter("+20*5");
    io.release(KeyboardKey.enter);
    root.focus();
    root.draw();

    assert(calls == 1);
    assert(root.value == 10);
    assert(root.TextInput.value == "10+20*5");

    // Submit the expression
    io.nextFrame;
    io.press(KeyboardKey.enter);
    root.draw();

    assert(calls == 2);
    assert(root.value != (10+20)*5);
    assert(root.value == 110);
    assert(root.TextInput.value == "110");

    // Try incrementing
    io.nextFrame;
    io.mousePosition = start(root.spinner._lastRectangle);
    io.press;
    root.draw();

    io.nextFrame;
    io.release;
    root.draw();

    assert(calls == 3);
    assert(root.value == 111);
    assert(root.TextInput.value == "111");

    // Try decrementing
    io.nextFrame;
    io.mousePosition = end(root.spinner._lastRectangle) - Vector2(1, 1);
    io.press;
    root.draw();

    io.nextFrame;
    io.release;
    root.draw();

    assert(calls == 4);
    assert(root.value == 110);
    assert(root.TextInput.value == "110");

}

unittest {

    import std.math;

    auto io = new HeadlessBackend;
    auto root = floatInput();

    root.io = io;

    io.inputCharacter("10e8");
    root.focus();
    root.draw();

    io.nextFrame;
    io.press(KeyboardKey.enter);
    root.draw();

    assert(root.value.isClose(10e8));
    assert(root.TextInput.value.among("1e+9", "1e+09"));

}

abstract class AbstractNumberInput : TextInput {

    mixin enableInputActions;

    public {

        /// "Spinner" controlling the decrement and increment buttons.
        NumberInputSpinner spinner;

    }

    this(void delegate() @safe changed = null) {

        super("");
        super.changed = changed;
        super.value = ['0'];
        this.spinner = numberInputSpinner(.layout!"fill", &increment, &decrement);

    }

    override void resizeImpl(Vector2 space) {

        super.resizeImpl(space);
        spinner.resize(tree, theme, space);

    }

    abstract void increment();
    abstract void decrement();

}

/// Increment and decrement buttons that appear on the right of number inputs.
class NumberInputSpinner : Node, FluidHoverable {

    mixin enableInputActions;

    /// Additional features available for number input styling
    static class Extra : typeof(super).Extra {

        /// Image to use for the increment/decrement buttons.
        Image buttons;

        this(Image buttons) {

            this.buttons = buttons;

        }

    }

    public {

        void delegate() @safe incremented;
        void delegate() @safe decremented;

    }

    private {

        Rectangle _lastRectangle;

    }

    this(void delegate() @safe incremented, void delegate() @safe decremented) {

        this.incremented = incremented;
        this.decremented = decremented;

    }

    override ref inout(bool) isDisabled() inout {

        return super.isDisabled();

    }

    override bool isHovered() const {

        return super.isHovered();

    }

    override void resizeImpl(Vector2) {

        minSize = Vector2();

    }

    protected override bool hoveredImpl(Rectangle rect, Vector2 mousePosition) {

        import fluid.utils : contains;

        return buttonsRectangle(style, rect).contains(mousePosition);

    }

    override void drawImpl(Rectangle outer, Rectangle inner) {

        auto style = pickStyle();

        style.drawBackground(io, outer);

        // If there's a texture for buttons, display it
        if (auto texture = getTexture(style)) {

            _lastRectangle = buttonsRectangle(style, inner);

            texture.draw(_lastRectangle);

        }

    }

    /// Get rectangle for the buttons
    Rectangle buttonsRectangle(const Style style, Rectangle inner) {

        if (auto texture = getTexture(style)) {

            const scale = inner.height / texture.height;
            const size = Vector2(texture.width, texture.height) * scale;
            const position = end(inner) - size;

            return Rectangle(position.tupleof, size.tupleof);

        }

        return Rectangle.init;

    }

    @(FluidInputAction.press)
    void _pressed() {

        // Above center (increment)
        if (io.mousePosition.y < center(_lastRectangle).y) {

            if (incremented) incremented();

        }

        // Below center (decrement)
        else {

            if (decremented) decremented();

        }

    }

    void mouseImpl() {

    }

    /// Get texture used by the spinner.
    protected TextureGC* getTexture(const Style style) @trusted {

        auto extra = cast(Extra) style.extra;

        if (!extra) return null;

        // Check entries for this backend
        return extra.getTexture(io, extra.buttons);

    }

}

struct ExpressionResult(T) {

    T value = 0;
    bool success;

    alias value this;

    bool opCast(T : bool)() {

        return success;

    }

    ExpressionResult op(dchar operator, ExpressionResult rhs) {

        // Both sides must be successful
        if (success && rhs.success)
        switch (operator) {

            case '+':
                return ExpressionResult(value + rhs.value, true);
            case '-':
                return ExpressionResult(value - rhs.value, true);
            case '*':
                return ExpressionResult(value * rhs.value, true);
            case '/':
                return ExpressionResult(value / rhs.value, true);
            default: break;

        }

        // Failure
        return ExpressionResult.init;

    }

    string toString() const {

        import std.conv;

        if (success)
            return value.to!string;
        else
            return "failure";

    }

}

ExpressionResult!T evaluateExpression(T, Range)(Range input) {

    static assert(is(typeof(input.front) == dchar), "Given expression is not a valid string");

    alias Result = ExpressionResult!T;

    // Skip whitespace
    auto expression = input.filter!(a => !a.isWhite);

    return evaluateExpressionImpl!T(expression);

}

unittest {

    assert(evaluateExpression!int("0") == 0);
    assert(evaluateExpression!int("10") == 10);
    assert(evaluateExpression!int("123") == 123);
    assert(evaluateExpression!int("-0") == -0);
    assert(evaluateExpression!int("-10") == -10);
    assert(evaluateExpression!int("-123") == -123);

    assert(evaluateExpression!int("2+2") == 4);
    assert(evaluateExpression!int("2+2-3") == 1);
    assert(evaluateExpression!int("1+1*10+3") == 14);
    assert(evaluateExpression!int("1+2*10+3") == 24);
    assert(evaluateExpression!int("10+-10") == 0);
    assert(evaluateExpression!int("4*8") == 32);
    assert(evaluateExpression!int("20/5") == 4);

    assert(evaluateExpression!int("3/4") == 0);
    assert(evaluateExpression!float("3/4") == 0.75);

    assert(evaluateExpression!int("(4+5)*2") == 18);
    assert(evaluateExpression!int("(4+5)+2*2") == 9+4);
    assert(evaluateExpression!int("(4+4*5)*10+7") == (4+4*5)*10+7);
    assert(evaluateExpression!int("102+(4+4*5)*10+7") == 102+(4+4*5)*10+7);

}

unittest {

    import std.math;
    import std.conv;

    assert(evaluateExpression!float("2.0+2.0").isClose(4.0));
    assert(evaluateExpression!float("2.4*4.2").to!string == "10.08");
    assert(evaluateExpression!float("3/4").isClose(0.75));
    assert(evaluateExpression!float("2 * 0.75").isClose(1.5));
    assert(evaluateExpression!float("-2 * 0.75 * 100").isClose(-150));

    assert(evaluateExpression!float("2e8").isClose(2e8));
    assert(evaluateExpression!float("-2e8").isClose(-2e8));
    assert(evaluateExpression!float("2e+8").isClose(2e+8));
    assert(evaluateExpression!float("2e-8").to!string == "2e-08");
    assert(evaluateExpression!float("-2e+8").isClose(-2e+8));

}

private {

    ExpressionResult!T evaluateExpressionImpl(T, Range)(ref Range input, int minPrecedence = 1) {

        // Reference: https://eli.thegreenplace.net/2012/08/02/parsing-expressions-by-precedence-climbing

        // Evaluate the left-hand side
        auto lhs = evaluateAtom!T(input);

        // Load binary operator chain
        while (!input.empty) {

            const operator = input.front;
            const precedence = .precedence(operator);
            const nextMinPrecedence = precedence + 1;

            // Precedence too low
            if (precedence < minPrecedence) break;

            input.popFront;

            auto rhs = evaluateExpressionImpl!T(input, nextMinPrecedence);

            lhs = lhs.op(operator, rhs);

        }

        return lhs;

    }

    int precedence(dchar operator) {

        if (operator.among('+', '-'))
            return 1;

        else if (operator.among('*', '/'))
            return 2;

        // Error
        else return 0;

    }

    ExpressionResult!T evaluateAtom(T, Range)(ref Range expression) {

        bool negative;
        ExpressionResult!T result;

        // Fail if there's nothing ahead
        if (expression.empty) return result.init;

        // Negate the value
        if (expression.front == '-') {

            negative = true;
            expression.popFront;

        }

        // Found paren
        if (expression.front == '(') {

            expression.popFront;

            // Load an expression
            result = evaluateExpressionImpl!T(expression);

            // Expect it to end
            if (expression.front != ')')
                return result.init;

            expression.popFront;

        }

        // Load the number
        else {

            import std.conv;

            bool exponent;

            // Parsing floats is hard! We'll just locate the end of the number and use std.conv.to.
            auto length = expression.countUntil!((a) {

                // Allow 'e+' and 'e-'
                if (a == 'e') {
                    exponent = true;
                    return false;
                }
                if (exponent && a.among('+', '-')) {
                    exponent = false;
                    return false;
                }

                // Take in digits and dots
                return !a.isDigit && a != '.';

            });

            // Parse the number
            try result.value = expression.take(length).to!T;
            catch (ConvException)
                return result.init;

            // Skip ahead
            expression.popFrontN(length);

        }

        if (negative) {
            result.value = -result.value;
        }

        result.success = true;

        return result;

    }

}
