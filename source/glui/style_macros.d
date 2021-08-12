module glui.style_macros;

import std.range;
import std.traits;
import std.string;

import glui.style;

@safe:

private static {

    Theme currentTheme;
    Style[] styleStack;

}

/// Create a new theme defined from D code given through a template argument. The code will define the default style
/// for each node, and can use `Node.(...)Add` calls to define other styles within the theme.
///
/// Params:
///     init = D code to initialize the Node style with.
///     parent = Inherit styles from a parent theme.
/// Returns: The created theme.
Theme makeTheme(string init)(Theme parent = Theme.init) {

    import glui.node;

    // Create the theme
    currentTheme = parent.dup;

    // Add the node style
    nestStyle!(init, GluiNode.styleKey);

    assert(styleStack.length == 0, "The style stack has not been emptied");

    return currentTheme;

}

// Internal, public because required in mixins
Style nestStyle(string init, alias styleKey)() {

    Style style;

    //assert(&styleKey !in currentTheme, fullyQualifiedName!styleKey.format!"The theme already defines style key %s");

    // Inherit from the parent style
    if (styleStack.length) {

        style = styleStack[$-1].dup;

    }

    // Create a new style otherwise
    else style = new Style;

    styleStack ~= style;
    scope (exit) styleStack.popBack();

    // Update the style
    style.update!init;

    // Add the result to the theme
    return currentTheme[&styleKey] = style;

}

/// Define style fields for a node and let them be affected by themes.
///
/// Note: This should be used in *every* node, even if empty, to ensure keys are inherited properly.
///
/// Params:
///     names = A list of styles to define.
mixin template DefineStyles(names...) {

    import std.meta : Filter;
    import std.format : format;
    import std.traits : BaseClassesTuple;

    import glui.utils : StaticFieldNames;

    private alias Parent = BaseClassesTuple!(typeof(this))[0];
    private alias MemberType(alias member) = typeof(__traits(getMember, Parent, member));

    private enum isStyleKey(alias member) = is(MemberType!member == immutable(StyleKey));
    private alias StyleKeys = Filter!(isStyleKey, StaticFieldNames!Parent);

    // Inherit style keys
    static foreach (name; StyleKeys) {

        // Inherit default value
        mixin("static immutable StyleKey " ~ name ~ ";");

        // Helper function to declare nested styles
        mixin(name[0 .. $-3].format!q{

            static Style %sAdd(string content)() {

                return nestStyle!(content, %1$sKey);

            }

        });

    }

    // Local styles
    static foreach(i, name; names) {

        // Only check even names
        static if (i % 2 == 0) {

            // Define the key
            mixin(name.format!q{ static immutable StyleKey %sKey; });

            // Define the value
            mixin(name.format!q{ protected Style %s; });

            // Helper function to declare nested styles
            mixin(name.format!q{

                static Style %sAdd(string content)() {

                    return nestStyle!(content, %1$sKey);

                }

            });

        }

    }

    private enum inherits = !is(typeof(super) == Object);

    override protected void reloadStyles() {

        // First load what we're given
        reloadStylesImpl();

        // Then load the defaults
        loadDefaultStyles();

    }

    // Load styles
    override protected void reloadStylesImpl() {

        // Inherit styles
        static if (inherits) super.reloadStylesImpl();

        // Load inherited keys (so class A:B will load both B.styleKey and A.styleKey)
        static foreach (name; StyleKeys) {{

            if (auto style = &mixin(name) in theme) {

                mixin("this." ~ name[0 .. $-3]) = *style;

            }

            // No default value, the parent has already handled it

        }}

        // Load local keys and load defaults if none are set
        static foreach (i, name; names) {

            static if (i % 2 == 0) {

                // We're deferring the default for later to make sure it uses up-to-date values
                mixin("this." ~ name) = theme.get(&mixin(name ~ "Key"), null);

            }

        }

    }

    override void loadDefaultStyles() {

        // Inherit
        static if (inherits) super.loadDefaultStyles();

        // Load defaults for each unset style
        static foreach (i, name; names) {

            static if (i % 2 == 0) {

                // Found an unset value
                if (mixin("this." ~ name) is null) {

                    // Set the default
                    mixin("this." ~ name) = mixin(names[i+1]);

                }

            }

        }

    }

}