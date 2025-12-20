///
module fluid.io.io;

@safe:

import fluid.future.static_id;

enum isIO(T) = is(T == interface)
    && is(T : IO)
    && !is(T == IO);

/// Get all IOs implemented by the given type
alias allIOs(T) = Filter!(isIO, InterfacesTuple!T);

interface IO {

    bool opEquals(const Object) const;

    /// Load a resource by reference. This is the same as `Node.load`.
    /// Params:
    ///     resource = Resource to load. It will be updated with identifying information.
    void loadTo(this This, T)(ref T resource) {

        auto io = cast(This) this;

        // Load the resource
        const id = io.load(resource);

        // Pass data into the resource
        resource.load(io, id);

    }

    /// Load an upgrade to a newer version of this I/O system if one is available.
    ///
    /// To preserve backwards compatibility, when upgrading to a new version, you can keep loading
    /// old versions:
    ///
    /// ---
    /// ActionIOv1 actionIOv1;
    /// ActionIOv2 actionIOv2;
    /// override void resizeImpl(Vector2) {
    ///     use(actionIOv1).upgrade(actionIOv2);
    ///
    ///     if (actionIOv2) {
    ///         // v2 is available
    ///     }
    ///     else if (actionIOv1) {
    ///         // v1 is available
    ///     }
    ///     else {
    ///         // system unavailable
    ///     }
    /// }
    /// ---
    ///
    /// Using `upgrade` instead of just another `use` can help in situations where only some of
    /// the implementations have been updated:
    ///
    /// ---
    /// a = systemV2Chain(
    ///     systemUser(),  // uses a (v2)
    ///     b = systemV1Chain(
    ///         systemUser(),  // uses b (v1), even if v2 is available
    ///     )
    /// )
    /// ---
    ///
    /// Params:
    ///     newIO = Newer version of the system to upgrade to.
    ///         This is an out parameter; the variable will be assigned in place.
    /// Returns:
    ///     Instance of the newer system, if available.
    T upgrade(T, this This)()
    if (is(T : This))
    do {
        return cast(T) this;
    }

    /// ditto
    T upgrade(T, this This)(out T newIO)
    if (is(T : This))
    do {
        return newIO = upgrade!(T, This)();
    }

}

IOID ioID(T)()
if (isIO!T) {

    return IOID(staticID!T);

}

/// ID for an I/O interface.
struct IOID {

    StaticID id;

    int opCmp(const IOID rhs) const {
        return id.opCmp(rhs.id);
    }

}
