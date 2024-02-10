module fluid.theme;

import std.meta;
import std.range;
import std.string;
import std.traits;

import fluid.node;
import fluid.style;


@safe:


//deprecated("Styles have been reworked and defineStyles is now a no-op. To be removed in 0.8.0.") {
    mixin template defineStyles(args...) { }
    mixin template DefineStyles(args...) { }
//}

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

///
unittest {

    import fluid.text_input;

    Theme theme;

    with (Rule)
    theme.add(
        rule!TextInput(
            textColor = color!"#303030",
        ),
    );

}

/// Selector is used to pick a node based on its type and specified tags.
struct Selector {

    /// Type of the node to match.
    TypeInfo_Class type;

    /// Test if the selector matches given node.
    bool test(Node node) {

        return !type || type.isBaseOf(typeid(node));

    }

}

/// Create a style rule for the given node.
Rule rule(T : Node = Node, Ts...)(Ts fields) {

    enum isWhenRule(alias field) = is(typeof(field) : WhenRule!dg, alias dg);
    enum isDynamicRule(alias field) = isCallable!field || isWhenRule!field;

    Rule result;

    // Create the selector
    result.selector = Selector(typeid(T));

    // Load fields
    static foreach (i, field; fields) {{

        // Directly assigned field
        static if (is(typeof(field) : Field!(fieldName, T), string fieldName, T)) {

            // Add to the result
            field.apply(result.fields);

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

            }

            // Use the delegate and apply the result on the template of choice
            else dg(node).apply(node, dynamicResult);

        }

        return dynamicResult;

    };

    return result;

}

/// Rules specify changes that are to be made to the node's style.
struct Rule {

    alias StyleDelegate = Rule delegate(Node node) @safe;
    alias loadTypeface = Style.loadTypeface;

    /// Selector to filter items that should match this rule.
    Selector selector;

    /// Fields affected by this rule and their values.
    StyleTemplate fields;

    /// Callback for updating the style dynamically. May be null.
    StyleDelegate styleDelegate;

    /// Define field setters for each field, to use as `Rule.property = value`
    static foreach (field; StyleTemplate.fields) {

        mixin(format!q{
            alias %1$s = Field!("%1$s", typeof(field)).make;
        }(__traits(identifier, field)));

    }

    alias field(string name) = __traits(getMember, StyleTemplate, name);
    alias FieldType(string name) = field!name.Type;

    /// Combine with another rule.
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

    string toString() const @trusted {

        string[] items;

        static foreach (field; fields) {{

            enum name = __traits(identifier, field);
            auto value = mixin("this.", name);

            if (value.isSet)
                items ~= format!"%s: %s"(name, value.value);

        }}

        return format!"StyleTemplate(%-(%s, %))"(items);

    }

}

struct Field(string fieldName, T) {

    enum name = fieldName;
    alias Type = T;

    FieldValue!T value;

    static Field make(T)(T value) {

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

    // Operators for arrays
    static if (isStaticArray!T) {

        private size_t[2] slice;

        Field opAssign(Input)(Input input) return {

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

template FieldValue(T) {

    // Static array
    static if (is(T : E[n], E, size_t n))
    struct FieldValue {

        alias Type = T;
        alias ExpandedType = FieldValueImpl!E[n];

        ExpandedType value;
        bool isSet;

        FieldValue opAssign(FieldValue value) {

            this.value = value.value;
            this.isSet = value.isSet;
            return this;

        }

        Type opAssign(Input)(Input value) {

            // Implicit cast
            Type newValue = value;

            // Mark as changed
            isSet = true;

            // Assign each field
            foreach (i, ref field; this.value.tupleof) {

                field = newValue.tupleof[i];

            }

            return newValue;

        }

        auto opIndexAssign(Input)(Input input, size_t index) {

            isSet = true;
            return value[index] = input;

        }

        auto opIndexAssign(Input)(Input input, size_t[2] indices) {

            isSet = true;
            return value[indices[0] .. indices[1]] = FieldValueImpl!E(input, true);

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
        void apply(ref FieldValue value) {

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

    // Others
    else alias FieldValue = FieldValueImpl!T;

}

private struct FieldValueImpl(T) {

    alias Type = T;

    Type value;
    bool isSet;

    FieldValueImpl opAssign(FieldValueImpl value) {

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
    void apply(ref FieldValueImpl value) {

        if (!isSet) return;

        value.value = this.value;
        value.isSet = true;

    }

    string toString() const @trusted {

        return format!"%s"(value);

    }

}

unittest {

    import fluid.frame;

    auto frameRule = rule!Frame(
        Rule.margin.sideX = 8,
        Rule.margin.sideY = 4,
    );
    auto theme = nullTheme.derive(frameRule);

    // TODO test
    //import std.stdio;
    //writeln(Rule.margin.sideX = 8);
    //writeln(frameRule);
    //writeln(theme);

}
