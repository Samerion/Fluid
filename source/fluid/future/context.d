module fluid.future.context;

import std.meta;
import std.traits;

import fluid.types;
import fluid.future.stack;
import fluid.future.static_id;

@safe:

struct TreeContext {

    TreeContextData* ptr;

    alias ptr this;

    /// Create the context if it doesn't already exist.
    void prepare() {

        if (ptr is null) {
            ptr = new TreeContextData();
        }

    }

    bool opCast(T : bool)() const {

        return ptr !is null;

    }

}

struct TreeContextData {

    TreeIOContext io;

    private {
        int _lockTint;
        auto _tint = Color(0xff, 0xff, 0xff, 0xff);
    }

    /// Tint is a transitive styling property that can be used to reduce color intensity of everything 
    /// that a node draws. Tint applies per channel, which means it can be used to reduce opacity (by changing
    /// the alpha channel) and any of the three RGB colors.
    ///
    /// A tint of value `0` sets intensity to 0% (disable). A tint of value `255` sets intensity to 100% (no change).
    ///
    /// See_Also: 
    ///     `Style.tint`
    /// Returns: The current tint.
    Color tint() const nothrow {
        return _tint;
    }

    package (fluid)
    Color tint(Color newValue) nothrow {
        if (_lockTint > 0) {
            return _tint;
        }
        else {
            return _tint = newValue;
        }
    }

    /// Lock tint in place, preventing it from changing, or cancel a lock, making changes possible again.
    ///
    /// This function is needed for compatibility with the legacy `FluidBackend` system.
    /// Locks can be stacked, so if `lockTint()` is called twice, `unlockTint()` also has to be called twice 
    /// to unlock tinting.
    ///
    /// It is expected that this function will be deprecated as soon as `FluidBackend` is no longer a part
    /// of Fluid. It will then be deleted in the next minor release.
    void lockTint() {
        _lockTint++;
    }

    /// ditto
    void unlockTint() {
        if (_lockTint > 0) {
            _lockTint--;
        }
    }

} 

/// Active context for I/O operations. 
struct TreeIOContext {

    /// Map of I/O interface IDs to an index in the IO array.
    private IO[IOID] activeIOs;

    /// Returns: The active instance of the given IO interface.
    /// Params:
    ///     id = ID of the IO interface to load.
    IO get(IOID id) {

        return activeIOs.get(id, null);

    }

    /// ditto
    T get(T)() {

        const id = ioID!T;
        return cast(T) get(id);

    }

    /// Set currently active I/O instance for a set interface.
    /// Params:
    ///     id       = ID of the IO interface the instance implements.
    ///     instance = Instance to activate.
    /// Returns:
    ///     Returns *previously set* I/O instance.
    IO replace(IOID id, IO instance) {

        // Override the previous result
        if (auto result = id in activeIOs) {
            auto previous = *result;
            *result = instance;
            return previous;
        }

        // Nothing set, create a new value
        else {
            activeIOs[id] = instance;
            return null;
        }

    }

}

enum isIO(T) = is(T == interface) 
    && is(T : IO)
    && !is(T == IO);

/// Get all IOs implemented by the given type
alias allIOs(T) = Filter!(isIO, InterfacesTuple!T);

interface HasContext {

    /// Returns: The current tree context.
    inout(TreeContext) treeContext() inout nothrow;

}

interface IO : HasContext {

}

IOID ioID(T)()
if (isIO!T) {

    return IOID(staticID!T);

}

/// ID for an I/O interface.
struct IOID {

    StaticID id;

}
