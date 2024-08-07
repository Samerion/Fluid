/// This module defines templates and structs used to build themes, including a set of special setters to use within
/// theme definitions. Because of the amount of general symbols defined by the module, it is not imported by default
/// and has to be imported explicitly. Do not import this globally, but within functions that define themes.
module fluid.theme;

import std.meta;
import std.range;
import std.string;
import std.traits;

import fluid.node;
import fluid.style;
import fluid.backend;
import fluid.structs;


@safe:


deprecated("Styles have been reworked and defineStyles is now a no-op. To be removed in 0.8.0.") {
    mixin template defineStyles(args...) { }
    mixin template DefineStyles(args...) { }
}

deprecated("makeTheme is now a no-op. Use `Theme()` and refer to the changelog for updates. To be removed in 0.8.0.")
Theme makeTheme(string s, Ts...)(Ts) {

    return Theme.init;

}

/// Node theme.
struct Theme {

    Rule[][TypeInfo_Class] rules;

    /// Create a new theme using the given rules.
    this(Rule[] rules...) {

        // Inherit from default theme
        this(fluidDefaultTheme.rules.dup);
        add(rules);

    }

    /// Create a theme using the given set of rules.
    this(Rule[][TypeInfo_Class] rules) {

        this.rules = rules;

    }

    /// Check if the theme was initialized.
    bool opCast(T : bool)() const {

        return rules !is null;

    }

    /// Create a new theme that derives from another.
    ///
    /// Note: This doesn't duplicate rules. If rules are changed or reassigned, they will may the parent theme. In a
    /// typical scenario you only add new rules.
    Theme derive(Rule[] rules...) {

        auto newTheme = this.dup;
        newTheme.add(rules);
        return newTheme;

    }

    /// Add rules to the theme.
    void add(Rule[] rules...) {

        foreach (rule; rules) {

            this.rules[rule.selector.type] ~= rule;

        }

    }

    /// Make the node use this theme.
    void apply(Node node) {

        node.theme = this;

    }

    /// Apply this theme on the given style.
    /// Returns: An array of delegates used to update the style at runtime.
    Rule.StyleDelegate[] apply(Node node, ref Style style) {

        Rule.StyleDelegate[] dgs;

        void applyFor(TypeInfo_Class ti) {

            // Inherit from parents
            if (ti.base) applyFor(ti.base);

            // Find matching rules
            if (auto rules = ti in rules) {

                // Test against every rule
                foreach (rule; *rules) {

                    // Run the rule, and add the callback if any
                    if (rule.applyStatic(node, style) && rule.styleDelegate) {

                        dgs ~= rule.styleDelegate;

                    }

                }

            }

        }

        applyFor(typeid(node));

        return dgs;

    }

    /// Duplicate the theme. This is not recursive; rules are not copied.
    Theme dup() {

        return Theme(rules.dup);

    }

}

unittest {

    import fluid.label;

    Theme theme;

    with (Rule)
    theme.add(
        rule!Label(
            textColor = color!"#abc",
        ),
    );

    auto io = new HeadlessBackend;
    auto root = label(theme, "placeholder");
    root.io = io;

    root.draw();
    io.assertTexture(root.text.texture.chunks[0], Vector2(0, 0), color!"#fff");
    assert(root.text.texture.chunks[0].palette[0] == color("#abc"));

}

unittest {

    import fluid.frame;

    auto frameRule = rule!Frame(
        Rule.margin.sideX = 8,
        Rule.margin.sideY = 4,
    );
    auto theme = nullTheme.derive(frameRule);

    // Test selector
    assert(frameRule.selector.type == typeid(Frame));
    assert(frameRule.selector.tags.empty);

    // Test fields
    auto style = Style.init;
    frameRule.apply(vframe(), style);
    assert(style.margin == [8, 8, 4, 4]);
    assert(style.padding == style.init.padding);
    assert(style.textColor == style.textColor.init);

    // No dynamic rules
    assert(rule.styleDelegate is null);

    auto io = new HeadlessBackend;
    auto root = vframe(theme);
    root.io = io;

    root.draw();

    assert(root.style == style);

}

unittest {

    // Inheritance

    import fluid.label;
    import fluid.button;

    auto myTheme = nullTheme.derive(
        rule!Node(
            Rule.margin.sideX = 8,
        ),
        rule!Label(
            Rule.margin.sideTop = 6,
        ),
        rule!Button(
            Rule.margin.sideBottom = 4,
        ),
    );

    auto style = Style.init;
    myTheme.apply(button("", delegate { }), style);

    assert(style.margin == [8, 8, 6, 4]);

}

unittest {

    // Copying rules & dynamic rules

    import fluid.label;
    import fluid.button;

    auto myRule = rule!Label(
        Rule.textColor = color!"011",
        Rule.backgroundColor = color!"faf",
        (Label node) => node.isDisabled
            ? rule(Rule.tint = color!"000a")
            : rule()
    );

    auto myTheme = Theme(
        rule!Label(
            myRule,
        ),
        rule!Button(
            myRule,
            Rule.textColor = color!"012",
        ),
    );

    auto style = Style.init;
    auto myLabel = label("");

    // Apply the style, including dynamic rules
    auto cbs = myTheme.apply(myLabel, style);
    assert(cbs.length == 1);
    cbs[0](myLabel).apply(myLabel, style);

    assert(style.textColor == color!"011");
    assert(style.backgroundColor == color!"faf");
    assert(style.tint == Style.init.tint);

    // Disable the node and apply again, it should change nothing
    myLabel.disable();
    myTheme.apply(myLabel, style);
    assert(style.tint == Style.init.tint);

    // Apply the callback, tint should change
    cbs[0](myLabel).apply(myLabel, style);
    assert(style.tint == color!"000a");

}

unittest {

    import fluid.label;

    auto myLabel = label("");

    void testMargin(Rule rule, float[4] margin) {

        auto style = Style.init;

        rule.apply(myLabel, style);

        assert(style.margin == margin);

    }

    with (Rule) {

        testMargin(rule(margin = 2), [2, 2, 2, 2]);
        testMargin(rule(margin.sideX = 2), [2, 2, 0, 0]);
        testMargin(rule(margin.sideY = 2), [0, 0, 2, 2]);
        testMargin(rule(margin.sideTop = 2), [0, 0, 2, 0]);
        testMargin(rule(margin.sideBottom = 2), [0, 0, 0, 2]);
        testMargin(rule(margin.sideX = 2, margin.sideY = 4), [2, 2, 4, 4]);
        testMargin(rule(margin = [1, 2, 3, 4]), [1, 2, 3, 4]);
        testMargin(rule(margin.sideX = [1, 2]), [1, 2, 0, 0]);

    }

}

unittest {

    import std.math;
    import fluid.label;

    auto myRule = rule(
        Rule.opacity = 0.5,
    );
    auto style = Style.init;

    myRule.apply(label(""), style);

    assert(style.opacity.isClose(127/255f));
    assert(style.tint == color!"ffffff7f");

    auto secondRule = rule(
        Rule.tint = color!"abc",
        Rule.opacity = 0.6,
    );

    style = Style.init;
    secondRule.apply(label(""), style);

    assert(style.opacity.isClose(153/255f));
    assert(style.tint == color!"abc9");

}

// Define field setters for each field, to use by importing or through `Rule.property = value`
static foreach (field; StyleTemplate.fields) {

    mixin(
        `alias `,
        __traits(identifier, field),
        `= Field!("`,
        __traits(identifier, field),
        `", typeof(field)).make;`
    );

}

// Separately define opacity for convenience
auto opacity(float value) {

    import std.algorithm : clamp;

    return tint.a = cast(ubyte) clamp(value * ubyte.max, ubyte.min, ubyte.max);

}

/// Selector is used to pick a node based on its type and specified tags.
struct Selector {

    /// Type of the node to match.
    TypeInfo_Class type;

    /// Tags needed by the selector.
    TagList tags;

    /// If true, this selector will reject any match.
    bool rejectAll;

    /// Returns a selector that doesn't match anything
    static Selector none() {

        Selector result;
        result.rejectAll = true;
        return result;

    }

    /// Test if the selector matches given node.
    bool test(Node node) {

        return !rejectAll
            && testType(typeid(node))
            && testTags(node.tags);

    }

    /// Test if the given type matches the selector.
    bool testType(TypeInfo_Class type) {

        return !this.type || this.type.isBaseOf(type);

    }

    unittest {

        import fluid.input;
        import fluid.label;
        import fluid.button;

        auto myLabel = label("my label");
        auto myButton = button("my button", delegate { });

        auto selector = Selector(typeid(Node));

        assert(selector.test(myLabel));
        assert(selector.test(myButton));

        auto anotherSelector = Selector(typeid(Button));

        assert(!anotherSelector.test(myLabel));
        assert(anotherSelector.test(myButton));

        auto noSelector = Selector();

        assert(noSelector.test(myLabel));
        assert(noSelector.test(myButton));

    }

    /// True if all tags in this selector are present on the given node.
    bool testTags(TagList tags) {

        // TODO linear search if there's only one tag
        return this.tags.intersect(tags).walkLength == this.tags.length;

    }

    unittest {

        import fluid.label;

        @NodeTag enum good;
        @NodeTag enum bad;

        auto selector = Selector(typeid(Label)).addTags!good;

        assert(selector.test(label(.tags!good, "")));
        assert(!selector.test(label(.tags!bad, "")));
        assert(!selector.test(label("")));

    }

    /// Create a new selector requiring the given set of tags.
    Selector addTags(tags...)() {

        return Selector(type, this.tags.add!tags);

    }

}

/// Create a style rule for the given node.
///
/// Template parameters are used to select the node the rule applies to, based on its type and the tags it has. Regular
/// parameters define the changes made by the rule. These are created by using automatically defined members of `Rule`,
/// which match names of `Style` fields. For example, to change the property `Style.textColor`, one would assign
/// `Rule.textColor` inside this parameter list.
///
/// ---
/// rule!Label(
///     Rule.textColor = color("#fff"),
///     Rule.backgroundColor = color("#000"),
/// )
/// ---
///
/// It is also possible to pass a `when` subrule to apply changes based on runtime conditions:
///
/// ---
/// rule!Button(
///     Rule.backgroundColor = color("#fff"),
///     when!"a.isHovered"(
///         Rule.backgroundColor = color("#ccc"),
///     )
/// )
/// ---
///
/// If some directives are repeated across different rules, they can be reused:
///
/// ---
/// myRule = rule(
///     Rule.textColor = color("#000"),
/// ),
/// rule!Button(
///     myRule,
///     Rule.backgroundColor = color("#fff"),
/// )
/// ---
///
/// Moreover, rules respect inheritance. Since `Button` derives from `Label` and `Node`, `rule!Label` will also apply
/// to buttons, and so will `rule!Node`.
///
/// For more advanced use-cases, it is possible to directly pass a delegate that accepts a node and returns a
/// subrule.
///
/// ---
/// rule!Button(
///     a => rule(
///         Rule.backgroundColor = pickColor(),
///     )
/// )
/// ---
///
/// It is recommended to use the `with (Rule)` statement to make rule definitions clearer.
template rule(T : Node = Node, tags...) {

    Rule rule(Ts...)(Ts fields) {

        enum isWhenRule(alias field) = is(typeof(field) : WhenRule!dg, alias dg);
        enum isDynamicRule(alias field) = isCallable!field || isWhenRule!field || is(typeof(field) : Rule);

        Rule result;

        // Create the selector
        result.selector = Selector(typeid(T)).addTags!tags;

        // Load fields
        static foreach (i, field; fields) {{

            // Directly assigned field
            static if (is(typeof(field) : Field!(fieldName, T), string fieldName, T)) {

                // Add to the result
                field.apply(result.fields);

            }

            // Copy from another rule
            else static if (is(typeof(field) : Rule)) {

                assert(field.selector.testType(typeid(T)),
                    format!"Cannot paste rule for %s into a rule for %s"(field.selector.type, typeid(T)));

                // Copy fields
                field.fields.apply(result.fields);
                // Also add delegates below...


            }

            // Dynamic rule
            else static if (isDynamicRule!field) { }

            else static assert(false, format!"Unrecognized type %s (argument index %s)"(typeof(field).stringof, i));

        }}

        // Load delegates
        alias delegates = Filter!(isDynamicRule, fields);

        // Build the dynamic rule delegate
        static if (delegates.length)
        result.styleDelegate = (Node node) {

            Rule dynamicResult;

            // Cast the node into proper type
            auto castNode = cast(T) node;
            assert(castNode, "styleDelegate was passed an invalid node");

            static foreach (dg; delegates) {

                // A "when" rule
                static if (isWhenRule!dg) {

                    // Test the predicate before applying the result
                    if (dg.predicate(castNode)) {

                        dg.rule.apply(node, dynamicResult);

                    }

                    // Apply the alternative if predicate fails
                    else dg.alternativeRule.apply(node, dynamicResult);

                }

                // Regular rule, forward to its delegate
                else static if (is(typeof(dg) : Rule)) {

                    if (dg.styleDelegate)
                    dynamicResult = dg.styleDelegate(node);

                }

                // Use the delegate and apply the result on the template of choice
                else dg(castNode).apply(node, dynamicResult);

            }

            return dynamicResult;

        };

        return result;

    }

}

@trusted
unittest {

    // Rule copying semantics

    import fluid.label;
    import fluid.button;
    import std.exception;
    import core.exception : AssertError;

    auto generalRule = rule(
        Rule.textColor = color!"#001",
    );
    auto buttonRule = rule!Button(
        Rule.backgroundColor = color!"#002",
        generalRule,
    );
    assertThrown!AssertError(
        rule!Label(buttonRule),
        "Label rule cannot inherit from a Button rule."
    );

    assertNotThrown(rule!Button(buttonRule));
    assertNotThrown(rule!Button(rule!Label()));

}

/// Rules specify changes that are to be made to the node's style.
struct Rule {

    alias StyleDelegate = Rule delegate(Node node) @safe;
    alias loadTypeface = Style.loadTypeface;

    public import fluid.theme;

    /// Selector to filter items that should match this rule.
    Selector selector;

    /// Fields affected by this rule and their values.
    StyleTemplate fields;

    /// Callback for updating the style dynamically. May be null.
    StyleDelegate styleDelegate;

    alias field(string name) = __traits(getMember, StyleTemplate, name);
    alias FieldType(string name) = field!name.Type;

    /// Combine with another rule. Applies dynamic rules immediately.
    bool apply(Node node, ref Rule rule) {

        // Test against the selector
        if (!selector.test(node)) return false;

        // Apply changes
        fields.apply(rule.fields);

        // Check for delegates
        if (styleDelegate) {

            // Run and apply the delegate
            styleDelegate(node).apply(node, rule);

        }

        return true;

    }

    /// Apply this rule on the given style.
    /// Returns: True if applied, false if not.
    bool apply(Node node, ref Style style) {

        // Apply the rule
        if (!applyStatic(node, style)) return false;

        // Check for delegates
        if (styleDelegate) {

            // Run and apply the delegate
            styleDelegate(node).apply(node, style);

        }

        return true;

    }

    /// Apply this rule on the given style. Ignores dynamic styles.
    /// Returns: True if applied, false if not.
    bool applyStatic(Node node, ref Style style) {

        // Test against the selector
        if (!selector.test(node)) return false;

        // Apply changes
        fields.apply(style);

        // TODO dynamic rules

        return true;

    }

}

/// Branch out in a rule to apply styling based on a runtime condition.
WhenRule!predicate when(alias predicate, Args...)(Args args) {

    return WhenRule!predicate(rule(args));

}

struct WhenRule(alias dg) {

    import std.functional;

    /// Function to evaluate to test if the rule should be applied.
    alias predicate = unaryFun!dg;

    /// Rule to apply.
    Rule rule;

    /// Rule to apply when the predicate fails.
    Rule alternativeRule;

    /// Specify rule to apply in case the predicate fails. An `else` branch.
    WhenRule otherwise(Args...)(Args args) {

        // TODO else if?

        auto result = this;
        result.alternativeRule = .rule(args);
        return result;

    }


}

unittest {

    import fluid.label;

    auto myTheme = Theme(
        rule!Label(
            Rule.textColor = color!"100",
            Rule.backgroundColor = color!"aaa",

            when!"a.isEmpty"(Rule.textColor = color!"200"),
            when!"a.text == `two`"(Rule.backgroundColor = color!"010")
                .otherwise(Rule.backgroundColor = color!"020"),
        ),
    );

    auto io = new HeadlessBackend;
    auto myLabel = label(myTheme, "one");

    myLabel.io = io;
    myLabel.draw();

    assert(myLabel.pickStyle().textColor == color!"100");
    assert(myLabel.pickStyle().backgroundColor == color!"020");
    assert(myLabel.style.backgroundColor == color!"aaa");

    myLabel.text = "";

    assert(myLabel.pickStyle().textColor == color!"200");
    assert(myLabel.pickStyle().backgroundColor == color!"020");
    assert(myLabel.style.backgroundColor == color!"aaa");

    myLabel.text = "two";

    assert(myLabel.pickStyle().textColor == color!"100");
    assert(myLabel.pickStyle().backgroundColor == color!"010");
    assert(myLabel.style.backgroundColor == color!"aaa");

}

struct StyleTemplate {

    alias fields = NoDuplicates!(getSymbolsByUDA!(Style, Style.Themable));

    // Create fields for every themable item
    static foreach (field; fields) {

        static if (!isFunction!(typeof(field)))
            mixin(q{ FieldValue!(typeof(field)) }, __traits(identifier, field), ";");

    }

    /// Update the given style using this template.
    void apply(ref Style style) {

        // TODO only iterate on fields that have changed
        static foreach (field; fields) {{

            auto newValue = mixin("this.", __traits(identifier, field));

            newValue.apply(__traits(child, style, field));

        }}

    }

    /// Combine with another style template, applying all local rules on the other template.
    void apply(ref StyleTemplate style) {

        static foreach (i, field; fields) {

            this.tupleof[i].apply(style.tupleof[i]);

        }

    }

    string toString()() const @trusted {

        string[] items;

        static foreach (field; fields) {{

            enum name = __traits(identifier, field);
            auto value = mixin("this.", name);

            if (value.isSet)
                items ~= format("%s: %s", name, value);

        }}

        return format("StyleTemplate(%-(%s, %))", items);

    }

}

/// `Field` allows defining and performing partial changes to members of Style.
struct Field(string fieldName, T) {

    enum name = fieldName;
    alias Type = T;

    FieldValue!T value;

    static Field make(Item, size_t n)(Item[n] value) {

        Field field;
        field.value = value;
        return field;

    }

    static Field make(T)(T value)
    if (!isStaticArray!T)
    do {

        Field field;
        field.value = value;
        return field;

    }

    static Field make() {

        return Field();

    }

    /// Apply on a style template.
    void apply(ref StyleTemplate style) {

        value.apply(__traits(child, style, Rule.field!fieldName));

    }

    // Operators for structs
    static if (is(T == struct)) {

        template opDispatch(string field)
        if (__traits(hasMember, T, field))
        {

            Field opDispatch(Input)(Input input) return {

                __traits(getMember, value, field) = input;
                return this;

            }

        }

    }

    // Operators for arrays
    static if (isStaticArray!T) {

        private size_t[2] slice;

        Field opAssign(Input, size_t n)(Input[n] input) return {

            value[slice] = input;
            return this;

        }

        Field opAssign(Input)(Input input) return
        if (!isStaticArray!Input)
        do {

            value[slice] = input;
            return this;

        }

        inout(Field) opIndex(size_t i) return inout {

            return inout Field(value, [i, i+1]);

        }

        inout(Field) opIndex(return inout Field slice) const {

            return slice;

        }

        inout(Field) opSlice(size_t dimension : 0)(size_t i, size_t j) return inout {

            return Field(value, [i, j]);

        }

    }

}

unittest {

    auto typeface = Style.loadTypeface(4);
    auto sample = Rule.typeface = typeface;

    const originalTypeface = typeface;

    assert(sample.name == "typeface");

    auto target = Style.loadTypeface(3);
    sample.value.apply(target);

    assert(target is typeface);
    assert(typeface is originalTypeface);

}

unittest {

    auto sampleField = Rule.margin = 4;

    assert(sampleField.name == "margin");
    assert(sampleField.slice == [0, 0]);

    float[4] field = [1, 1, 1, 1];
    sampleField.value.apply(field);

    assert(field == [4, 4, 4, 4]);

}

unittest {

    auto sampleField = Rule.margin.sideX = 8;

    assert(sampleField.name == "margin");
    assert(sampleField.slice == [0, 2]);

    float[4] field = [1, 1, 1, 1];
    sampleField.value.apply(field);

    assert(field == [8, 8, 1, 1]);

}

template FieldValue(T) {

    // Struct
    static if (is(T == struct))
        alias FieldValue = FieldValueStruct!T;

    // Static array
    else static if (is(T : E[n], E, size_t n))
        alias FieldValue = FieldValueStaticArray!(E, n);

    // Others
    else alias FieldValue = FieldValueOther!T;

}

private struct FieldValueStruct(T) {

    alias Type = T;
    alias ExpandedType = staticMap!(FieldValue, typeof(Type.tupleof));

    ExpandedType value;
    bool isSet;

    FieldValueStruct opAssign(FieldValueStruct value) {

        this.value = value.value;
        this.isSet = value.isSet;

        return this;

    }

    Type opAssign(Type value) {

        // Mark as set
        isSet = true;

        // Assign each field
        foreach (i, ref field; this.value) {

            field = value.tupleof[i];

        }

        return value;

    }

    template opDispatch(string name)
    if (__traits(hasMember, Type, name))
    {

        T opDispatch(T)(T value) {

            enum i = staticIndexOf!(name, FieldNameTuple!Type);

            // Mark as set
            isSet = true;

            // Assign the field
            this.value[i] = value;

            return value;

        }

    }

    /// Change the given value to match the requested change.
    void apply(ref Type value) {

        if (!isSet) return;

        foreach (i, field; this.value) {
            field.apply(value.tupleof[i]);
        }

    }

    /// Change the given value to match the requested change.
    void apply(ref FieldValueStruct value) {

        if (!isSet) return;

        value.isSet = true;

        foreach (i, field; this.value) {
            field.apply(value.value[i]);
        }

    }

}

private struct FieldValueStaticArray(E, size_t n) {

    alias Type = E[n];
    alias ExpandedType = FieldValue!E[n];

    ExpandedType value;
    bool isSet;

    FieldValueStaticArray opAssign(FieldValueStaticArray value) {

        this.value = value.value;
        this.isSet = value.isSet;
        return this;

    }

    Item[n] opAssign(Item, size_t n)(Item[n] value) {

        // Mark as changed
        isSet = true;

        // Assign each field
        foreach (i, ref field; this.value.tupleof) {

            field = value.tupleof[i];

        }

        return value;

    }

    Input opAssign(Input)(Input value)
    if (!isStaticArray!Input)
    do {

        // Implicit cast
        Type newValue = value;

        opAssign(newValue);

        return value;

    }

    Input opIndexAssign(Input)(Input input, size_t index) {

        isSet = true;
        value[index] = input;
        return input;

    }

    Input[n] opIndexAssign(Input, size_t n)(Input[n] input, size_t[2] indices) {

        assert(indices[1] - indices[0] == n, "Invalid slice");

        isSet = true;
        foreach (i, ref field; value[indices[0] .. indices[1]]) {
            field = input[i];
        }

        return input;

    }

    auto opIndexAssign(Input)(Input input, size_t[2] indices)
    if (!isStaticArray!Input)
    do {

        isSet = true;
        return value[indices[0] .. indices[1]] = FieldValue!E(input, true);

    }

    size_t[2] opSlice(size_t i, size_t j) const {

        return [i, j];

    }

    /// Change the given value to match the requested change.
    void apply(ref Type value) {

        if (!isSet) return;

        foreach (i, field; this.value.tupleof) {
            field.apply(value.tupleof[i]);
        }

    }

    /// Change the given value to match the requested change.
    void apply(ref FieldValueStaticArray value) {

        if (!isSet) return;

        value.isSet = true;

        foreach (i, field; this.value.tupleof) {
            field.apply(value.value[i]);
        }

    }

    string toString() {

        Type output;
        apply(output);
        return format!"%s"(output);

    }

}

private struct FieldValueOther(T) {

    alias Type = T;

    Type value;
    bool isSet;

    FieldValueOther opAssign(FieldValueOther value) {

        this.value = value.value;
        this.isSet = value.isSet;

        return this;

    }

    Type opAssign(Input)(Input value) {

        // Mark as set
        isSet = true;

        return this.value = value;

    }

    /// Change the given value to match the requested change.
    void apply(ref Type value) {

        if (!isSet) return;

        value = this.value;

    }

    /// Apply another modification to a field.
    void apply(ref FieldValueOther value) {

        if (!isSet) return;

        value.value = this.value;
        value.isSet = true;

    }

    string toString() const @trusted {

        return format!"%s"(value);

    }

}
