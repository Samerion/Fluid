/// Raylib connection layer for Fluid. This makes it possible to render Fluid apps and user interfaces through Raylib.
///
/// Use `raylibStack` for a complete implementation, and `raylibChain` for a minimal one. The complete stack
/// is recommended for most usages, as it bundles full mouse and keyboard support, while the chain node may
/// be preferred for advanced usage and requires manual setup. See `RaylibChain`'s documentation for more
/// information.
///
/// Note that because Raylib introduces breaking changes in every version, the current version of Raylib should
/// be specified using `raylibStack.v5_5()`. Raylib 5.5 is currently the oldest version supported,
/// and is the default in case no version is chosen explicitly.
///
/// Unlike `fluid.backend.Raylib5Backend`, this uses the new I/O system introduced in Fluid 0.8.0. This layer
/// is recommended for new apps, but disabled by default.
module fluid.raylib_chain;

version (Have_raylib_d):

debug (Fluid_BuildMessages) {
    pragma(msg, "Fluid: Building with Raylib 5.5 support (RaylibChain)");
}

import fluid.node;
import fluid.utils;
import fluid.node_chain;

import fluid.io.hover;
import fluid.io.focus;
import fluid.io.action;
import fluid.io.file;

@safe:

/// `raylibStack` implements all I/O functionality needed for Fluid to function, using Raylib to read user input
/// and present visuals on the screen.
///
/// Specify Raylib version by using a member: `raylibStack.v5_5()` will create a stack for Raylib 5.5.
///
/// `raylibStack` provides a default implementation for `HoverIO`, `FocusIO`, `ActionIO` and `FileIO`, on top of all
/// the systems provided by Raylib itself: `CanvasIO`, `KeyboardIO`, `MouseIO`, `ClipboardIO` and `ImageLoadIO`.
enum raylibStack = RaylibChainBuilder!RaylibStack.init;

/// `raylibChain` implements some I/O functionality using the Raylib library, namely `CanvasIO`, `KeyboardIO`,
/// `MouseIO`, `ClipboardIO` and `ImageLoadIO`.
///
/// These systems are not enough for Fluid to function. Use `raylibStack` to also initialize all other necessary
/// systems.
///
/// Specify Raylib version by using a member: `raylibChain.v5_5()` will create a stack for Raylib 5.5.
enum raylibChain = RaylibChainBuilder!RaylibChain.init;

/// Use this enum to pick version of Raylib to use.
enum RaylibChainVersion {
    v5_5,
}

/// Wrapper over `NodeBuilder` which enables specifying Raylib version.
struct RaylibChainBuilder(alias T) {

    alias v5_5 this;
    enum v5_5 = nodeBuilder!(T!(RaylibChainVersion.v5_5));

}

/// Implements Raylib support through Fluid's I/O system. Use `raylibStack` or `raylibChain` to construct.
///
/// `RaylibChain` relies on a number of I/O systems that it does not implement, but must be provided for it
/// to function. Use `RaylibStack` to initialize the chain along with default choices for these systems,
/// suitable for most uses, or provide these systems as parent nodes:
///
/// * `HoverIO` for mouse support. Fluid does not presently support mobile devices through Raylib, and Raylib's
///   desktop version does not fully support touchscreens (as GLFW does not).
/// * `FocusIO` for keyboard and gamepad support. Gamepad support may currently be limited.
///
/// There is a few systems that `RaylibChain` does not require, but are included in `RaylibStack` to support
/// commonly needed functionality:
///
/// * `ActionIO` for translating user input into a format Fluid nodes can understand.
/// * `FileIO` for loading and writing files.
///
/// `RaylibChain` itself provides a number of I/O systems using functionality from the Raylib library:
///
/// * `CanvasIO` for drawing nodes and providing visual output.
/// * `MouseIO` to provide mouse support.
/// * `KeyboardIO` to provide keyboard support.
/// * `ClipboardIO` to access system keyboard.
/// * `ImageLoadIO` to load images using codecs available in Raylib.
class RaylibChain(RaylibChainVersion raylibVersion) : NodeChain {

}

/// A complete implementation of all systems Fluid needs to function, using Raylib as the base for communicating with
/// the operating system. Use `raylibStack` to construct.
///
/// For a minimal installation that only includes systems provided by Raylib use `RaylibChain`.
/// Note that `RaylibChain` does not provide all the systems Fluid needs to function. See its documentation for more
/// information.
///
/// On top of systems already provided by `RaylibChain`, `RaylibStack` also includes `HoverIO`, `FocusIO`, `ActionIO`
/// and `FileIO`. You can access them through fields named `hoverIO`, `focusIO`, `actionIO` and `fileIO` respectively.
class RaylibStack(RaylibChainVersion raylibVersion) : NodeChain {

    import fluid.hover_chain;
    import fluid.focus_chain;
    import fluid.input_map_chain;
    import fluid.file_chain;

    public {

        /// I/O implementations provided by the stack.
        HoverChain hoverIO;

        /// ditto
        FocusChain focusIO;

        /// ditto
        InputMapChain actionIO;

        /// ditto
        FileChain fileIO;

        /// ditto
        RaylibChain!raylibVersion raylibIO;

    }

    /// Initialize the stack.
    /// Params:
    ///     next = Node to draw using the stack.
    this(Node next) {

        super(chain(
            actionIO = inputMapChain(),
            hoverIO  = hoverChain(),
            focusIO  = focusChain(),
            fileIO   = fileChain(),
            raylibIO = raylibChain(),
            next,
        ));

    }

}
