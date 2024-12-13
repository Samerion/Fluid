/// Provides an arena for keeping track of and periodically freeing unused resources.
module fluid.future.arena;

import optional;

import std.array;
import std.algorithm;

// mustuse is not available in LDC 1.28
static if (__traits(compiles, { import core.attribute : mustuse; }))
    import core.attribute : mustuse;
else
    private alias mustuse = AliasSeq!();

@safe:

/// A resource arena keeps track of resources in use, taking note of the time since the resource was last updated.
/// Time is tracked in terms of "cycles". Resources are expected to be updated every cycle, or be freed. The time
/// it takes to actually free resource can be adjusted.
///
/// The simplest way to understand the resource arena is by assuming all resources are freed every cycle:
///
/// ---
/// const resourceID = arena.load(...);  // Resource loaded
/// arena.startCycle();  // Unloaded
/// ---
///
/// In a practical scenario, resources will likely continue to be used across cycles. The `load` call will be repeated
/// next cycle with the same resource. The arena will therefore *not* free resources immediately, but keep them alive 
/// in the background for long enough they can be reused for another `load`. This means that on the outside
/// the resources appear freed, while they stay active until it can be confirmed they will not be reused.
///
/// The amount of cycles resources stay alive for can be adjusted by setting `arena.resourceLifetime`. The default is
/// to preserve resources for one cycle (1). Forcing immediate frees like in the example above can be achieved by
/// setting it to zero (0).
///
/// In Fluid, the resource arena is mostly used by I/O systems to manage resources that nodes will allocate.
/// A cycle starts when the I/O system begins resizing:
///
/// ---
/// ResourceArena!Image images;
/// override void resizeImpl(Vector2 space) {
///     images.startCycle();
///     super.resizeImpl(space);
/// }
/// override int load(DrawableImage image) {
///     return images.load(image);
/// }
/// ---
struct ResourceArena(T) {

    private struct Resource {

        /// The resource.
        T value;

        /// Number of the last cycle when the resource was used.
        int lastCycle;

    }

    public {

        /// Number of the current cycle. Cycles are used to determine the lifetimes stored in the arena.
        /// This field is incremented every time a new cycle starts.
        int cycleNumber;

        /// Number of cycles a resource stays alive for, beyond the cycle they were created during.
        ///
        /// If set to zero (0), resources are freed whenever `startCycle` is called. If set to one (1), the default,
        /// resources have to remain unused for a cycle to be freed.
        int resourceLifetime = 1;

    }

    private {

        /// Storage for currently allocated resources.
        Appender!(Resource[]) _resources;

    }

    /// Returns: Number of all resources, active or not.
    int resourceCount() const nothrow {

        return cast(int) _resources[].length;

    }

    /// List every resource in the arena.
    /// Returns: A range that lists every active resource.
    auto opIndex(this This)() nothrow {

        return _resources[]
            .filter!(a => a.lastCycle >= cycleNumber)
            .map!(a => a.value);

    }

    /// Only resources that were reloaded are included when using `[]`.
    @("ResourceArena only provides resources that have been reloaded.")
    unittest {

        ResourceArena!int arena;
        arena.load(0);
        arena.load(1);
        arena.load(2);
        assert(arena.opIndex.equal([0, 1, 2]));

        // Observe the results as we reload the resources during the next cycle
        arena.startCycle((_, __) { });
        assert(arena[].empty);
        arena.reload(0, 0);
        assert(arena[].equal([0]));
        arena.reload(2, 2);
        assert(arena[].equal([0, 2]));
        arena.reload(1, 1);
        assert(arena[].equal([0, 1, 2]));  // Order of insertion

    }

    /// Get a resource by its index.
    /// Params:
    ///     index = Index of the resource.
    /// Returns:
    ///     The resource, if active, or `none` if not.
    Optional!T opIndex(int index) {

        // Inactive
        if (!isActive(index)) return Optional!T();

        // Active
        return Optional!T(_resources[][index].value);

    }

    /// Check if resource at given index is active; A resource is active if it has been loaded during this cycle. 
    /// An active resource can be fetched using `opIndex`.
    ///
    /// For the looser variant, which would return true also if the resource is still loaded in arena,
    /// even if not recently loaded, see `isAlive`.
    ///
    /// Params:
    ///     index = Index to check.
    /// Returns: 
    ///     True if the resource is active: allocated, alive, ready to use.
    bool isActive(int index) {

        return isAlive(index)
            && cycleNumber <= _resources[][index].lastCycle;

    }

    /// Check if the resource is still loaded in the area.
    ///
    /// This will return true as long as the resource hasn't expired yet, even if it hasn't been loaded during
    /// this cycle. `isAlive` is intended for diagnostics and debugging, rather than practical usage. See `isActive`
    /// for the stricter variant that will not return `true` for unloaded resources.
    /// 
    /// Params:
    ///     index = Index to check.
    /// Returns:
    ///     True if the resource is alive, that is, hasn't expired, hasn't been unloaded, but also hasn't been
    ///     loaded/used during this cycle.
    bool isAlive(int index) {

        // Any resource in bounds is alive
        return index < _resources[].length;

    }

    /// Start a new cycle.
    /// 
    /// Each time a cycle is started, all expired resources are freed, making space for new resources.
    /// Resources that are kept alive, are moved to the start of the array, effectively changing their indices.
    /// Iterate on the return value to safely update your resources to use the new indices.
    ///
    /// Params:
    ///     moved = A function that handles freeing and moving resources.
    ///         It is called with a pair (index, resource) for every item that was freed or moved. 
    ///         For freed resources, the index is set to `-1`. 
    /// See_Also:
    ///     `resourceLifetime`
    auto startCycle(scope void delegate(int index, ref T resource) @safe moved) {

        int newIndex;

        foreach (oldIndex, ref resource; _resources[]) {

            // Free the resource if it has expired
            if (cycleNumber >= resource.lastCycle + resourceLifetime) {
                moved(-1, resource.value);
                continue;
            }

            // Still alive, but moved
            else if (oldIndex != newIndex) {
                _resources[][newIndex] = resource;
                moved(newIndex, _resources[][newIndex].value);
            }

            // Still alive, keep the index up
            newIndex++;

        }

        // Truncate the array and advance to the next cycle
        _resources.shrinkTo(newIndex);
        cycleNumber++;

    }

    /// Example: Maintaining a hash map of resource IDs to indices.
    @("ResourceArena: Maintaining a hash map of resource IDs to indices.")
    unittest {

        ResourceArena!string arena;
        int[string] indices;
        indices["One"]   = arena.load("One");
        indices["Two"]   = arena.load("Two");
        indices["Three"] = arena.load("Three");

        void nextCycle() {

            arena.startCycle((newIndex, ref resource) {

                // Freed
                if (newIndex == -1) {
                    indices.remove(resource);
                }
                // Moved
                else {
                    indices[resource] = newIndex;
                }

            });

        }
        
        // Start a cycle and remove "Two" from the arena
        nextCycle();
        arena.reload(indices["One"], "One");
        arena.reload(indices["Three"], "Three");
        assert(indices["One"]   == 0);
        assert(indices["Two"]   == 1);
        assert(indices["Three"] == 2);

        // Next cycle the resource should be freed
        nextCycle();
        assert(indices["One"]   == 0);
        assert(indices["Three"] == 1);

    }

    /// Load a resource into the arena.
    ///
    /// The resource must be new; the arena will not compare it against existing
    /// resources, nor will it attempt reuse. If the resource is already loaded,
    /// use `reload`.
    ///
    /// Params:
    ///     resource = Resource to load. 
    /// Returns:
    ///     Index associated with the resource.
    int load(T resource) {

        const index = cast(int) _resources[].length;
        _resources ~= Resource(resource, cycleNumber);
        return index;

    }

    /// Reload a resource.
    /// Params:
    ///     index    = Index the resource is stored under.
    ///     resource = Stored resource.
    void reload(int index, T resource) {

        _resources[][index] = Resource(resource, cycleNumber);

    }

}

/// Check if a resource has been using during this cycle with `isActive`.
@("ResourceArena.isActive and isAlive can be used to inspect activity")
unittest {

    ResourceArena!string arena;
    auto zero = arena.load("Zero");
    auto one  = arena.load("One");
    auto two  = 2;
    assert( arena.isActive(zero));
    assert( arena.isActive(one));
    assert(!arena.isActive(two));

    // Resources are marked inactive when a new cycle starts
    arena.startCycle((_, __) { });
    assert(!arena.isActive(zero));  // The resource isn't active now
    assert( arena.isAlive(zero));   // but it remains loaded

    // Loading a resource turns it active
    arena.reload(zero, "Zero");
    assert( arena.isActive(zero));
    assert( arena.isAlive(zero));
    assert(!arena.isActive(one));
    assert( arena.isAlive(one));
    assert(!arena.isActive(two));
    assert(!arena.isAlive(two));

    // "Two" hasn't been used on the last cycle, so it will be freed
    arena.startCycle((_, __) { });
    assert( arena.isAlive(zero));
    assert(!arena.isAlive(one));
    assert(!arena.isAlive(two));

}

/// Disable keeping objects alive by setting `resourceLifetime` to zero.
@("ResourceArena frees everything if `resourceLifetime` is set to zero")
unittest {

    ResourceArena!int arena;
    arena.resourceLifetime = 0;
    arena.load(0);
    assert( arena.isActive(0));
    assert( arena.isAlive(0));

    // 0 will be freed on a new cycle
    arena.startCycle((_, __) { });
    assert(!arena.isActive(0));
    assert(!arena.isAlive(0));

}
