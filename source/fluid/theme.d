module fluid.theme;

import std.meta;
import std.string;
import std.traits;

import fluid.node;
import fluid.style;


@safe:


//deprecated("Styles have been reworked and defineStyles is now a no-op. To be removed in 0.8.0.") {
    mixin template defineStyles(args...) { }
    mixin template DefineStyles(args...) { }
//}

/// Node theme.
struct Theme {

    Rule[][TypeInfo_Class] rules;

    /// Add rules to the theme.
    void add(Rule[] rules...) {

        foreach (rule; rules) {

            rules[rule.selector.type] ~= rule;

        }

    }

    void apply(Node node) {

        node.theme = this;

    }

    Theme dup() {

        return Theme(value.dup);

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

        return type.isBaseOf(typeid(node));

    }

}

/// Rules specify changes that are to be made to the node's style.
struct Rule {

    /// Selector to filter items that should match this rule.
    Selector selector;

    /// Fields affected by this rule and their values.
    StyleTemplate fields;

    /// Callback updating the node at runtime.
    StyleTemplate delegate(Node node) @safe dynamic;

    /// Define field values for each
    static foreach (field; StyleTemplate.fields) {

        mixin(format!q{
            alias %1$s = Field!("%1$s", typeof(field));
        }(__traits(identifier, field)));

    }

    alias field(string name) = __traits(getMember, StyleTemplate, name);
    alias FieldType(string name) = field!name.Type;

}

struct StyleTemplate {

    alias fields = NoDuplicates!(getSymbolsByUDA!(Style, Style.Themable));

    // Create fields for every themable item
    static foreach (field; fields) {

        mixin(q{ FieldValue!(typeof(field)) }, __traits(identifier, field), ";");

    }

    /// Update the given style using this template.
    void apply(ref Style style) {

        static foreach (field; fields) {

            __traits(child, style, field) = mixin("this.", __traits(identifier, field));

        }

    }

}

struct Field(string fieldName, T) {

    enum name = fieldName;

    FieldValue!T value;

    alias value this;

}

private struct FieldValue(T) {

    static if (isFunction!T)
        alias Type = ReturnType!T;
    else
        alias Type = T;

    Type value;
    bool isSet;

    alias value this;

}
