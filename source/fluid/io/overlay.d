/// Overlay I/O exists to provide nodes with the ability to add and control arbitrarily placed content, *laid over*
/// the remaining content.
///
/// Typical examples of overlay content are context and dropdown menus, such that list navigation options and controls
/// separately from the rest, but also popup and modal windows, which appear over other content. Overlay components
/// are also used to guide drag-and-drop interactions.
///
/// In Fluid, overlays may be limited to the window or canvas, as they are in [Raylib][fluid.raylib_view]. Other
/// setups may allow overlays to exceed window boundaries, which is common practice to give context menus more space.
///
/// To use Overlay I/O, an `OverlayIO` instance must be active in the tree (activated through `Node.implementIO`)
/// to provide space for overlay nodes. A child node can then create overlays by loading the system with `Node.use`
/// or `Node.require` and calling `OverlayIO.addOverlay`.
///
/// History:
///     * Introduced in Fluid 0.7.2 ([#319](https://git.samerion.com/Samerion/Fluid/issues/319))
module fluid.io.overlay;

import fluid.types;

import fluid.future.context;

@safe:

/// This interface defines a way to create and operate overlay content.
///
/// Instances of `OverlayIO` keep track of content as it is created and removed, and lay it out on the screen
/// using available methods.
interface OverlayIO : IO {

    /// Defines known types of overlays. To use a type from this list, use `types`, spelled lowercase.
    enum Types {

        /// A dialog window, often serving to ask for confirmation or warning the user.
        dialog,

        /// A context menu, usually invoked by pressing the secondary mouse button, or the keyboard "menu" key.
        context,

        /// Dropdown menu, often used to select one option from a list of many, or opened from the app's
        /// [menu bar](https://en.wikipedia.org/wiki/Menu_bar), if it has one.
        dropdown,

        /// A tooltip explaining the purpose or usage of a user interface component.
        tooltip,

        /// A drag-and-drop object.
        draggable,

        contextMenu = context,

    }

    /// Get an overlay type defined in `OverlayIO`.
    ///
    /// For example, to get an appropriate overlay type for a context menu, use `OverlayIO.types.context`.
    ///
    /// Returns:
    ///     A special struct that contains methods for creating instances of `OverlayType`
    ///     for types defined by `OverlayIO`.
    static types() {

        struct TypeDispatcher {

            static OverlayType opDispatch(string name)()
            if (__traits(hasMember, Types, name))
            do {
                const type = __traits(getMember, Types, name);
                return OverlayType(ioID!OverlayIO, type);
            }

        }

        return TypeDispatcher();

    }

    /// `types` is a shorthand that fills in the correct IO ID and type into `OverlayType`'s fields.
    @("OverlayIO.types returns valid overlays")
    unittest {

        assert(OverlayIO.types.context == OverlayType(ioID!OverlayIO, OverlayIO.Types.context));
        assert(OverlayIO.types.tooltip == OverlayType(ioID!OverlayIO, OverlayIO.Types.tooltip));
        assert(OverlayIO.types.contextMenu == OverlayType(ioID!OverlayIO, OverlayIO.Types.contextMenu));

    }

    /// Insert new overlay content.
    ///
    /// Overlay content should remain alive until the node specifies a `toRemove` status.
    /// Overlays should not be added if they're not already in the node tree.
    ///
    /// See_Also:
    ///     `addChildOverlay`
    /// Params:
    ///     node = Node containing the overlay content.
    ///         It must be a `Node` instance that implements the `Overlayable` interface.
    ///         Implementations should reject (through an `AssertError`) any objects that do not inherit from `Node`.
    ///     type = Type of the overlay node, as a fallback sequence.
    ///         This information that can be used to guide the overlay system by identifying the overlay's purpose.
    ///         See `OverlayIO.Types` and `OverlayIO.types` for commonly used types.
    ///
    ///         The system should choose the first type from the list that it supports.
    ///         If none of the types in the list are recognized, `OverlayType.init` should be assumed.
    ///         All overlay systems must support `OverlayType.init` as a general purpose overlay.
    void addOverlay(Overlayable node, OverlayType[] type...) nothrow;

    /// Insert overlay content as a child of another.
    ///
    /// A child overlay is bound to its parent overlay, so if the parent is removed, the child should be removed too.
    ///
    /// See_Also:
    ///     `addOverlay`
    /// Params:
    ///     parent = Parent node for the new overlay.
    ///     node   = Child node; overlay to add. Same restrictions apply as for `addOverlay`.
    ///     type   = Type of the overlay as a fallback sequence.
    void addChildOverlay(Overlayable parent, Overlayable node, OverlayType[] type...) nothrow;

}

/// Defines a node that can be used as an overlay through `OverlayIO`.
///
/// See_Also:
///     `fluid.io.overlay`, `OverlayIO`.
interface Overlayable {

    /// An anchor the node is bound to, used for positioning the overlay.
    ///
    /// The overlay should be aligned to one of the rectangle's corners or edges, so that a point in the node's
    /// rectangle should lie in the outline of the anchor. The node's `layout` property can be used for this:
    ///
    /// * For a `(start, start)` alignment, the point should be in the *top-left* corner of the overlay.
    /// * For an `(end, end)` alignment, the point should lie in the *bottom-right* corner.
    /// * An alignment value of `center` places the point in the *center* on the specified axis.
    /// * The special value *fill* can be used to mean automatic alignment; use an alignment that is the best fit
    ///   for the available space.
    ///
    /// Even for overlays that are outside of the window's boundary, the rectangle should be in window space,
    /// so that `(0,0)` is the window's top-left corner.
    ///
    /// Params:
    ///     space = Space available for the overlay, within which the anchor should be placed.
    ///         This may be the screen (relative to the window's position), the window itself,
    ///         or a fragment of the window.
    /// Returns:
    ///     The anchor rectangle to use for positioning the node.
    Rectangle getAnchor(Rectangle space) const nothrow;

    /// Memory safe and `const` object comparison.
    /// Returns:
    ///     True if this, and the other object, are the same object.
    /// Params:
    ///     other = Object to compare to.
    bool opEquals(const Object other) const;

}

/// Overlay type is used to specify the purpose of an overlay, and act as a guide for the overlay system's operations.
///
/// Windowing systems commonly accept a window type specification which can aid in window management.
/// For example, it can be used by the system to style the overlay appropriately.
///
/// Overlay types are extensible, and each I/O system can define their own set of types. Commonly used types such as
/// `dropdown` or `contextMenu` are defined as a part of `OverlayIO` and can be found in `OverlayIO.types`.
/// The `io` field specifies the I/O system, and the `number` field is used to distinguish between different types
/// that the system has defined.
///
/// The special overlay type `OverlayType.init` with `io` set to `null` and number set to `0` is used to specify
/// a general purpose overlay type with no extra specification.
struct OverlayType {

    /// ID of the I/O system defining the overlay type.
    IOID ioID;

    /// Number representing the type of the overlay. Meaning of this field is defined by the I/O system, but usually
    /// it corresponds to an enum member, as it does for `OverlayIO`.
    int number;

}
