/// Module handling low-level user preferences, like the double click interval.
module fluid.io.preference;

import core.time;

import fluid.types;
import fluid.future.context;

@safe:

/// I/O interface for loading low-level user preferences, such as the double click interval, from the system.
///
/// Right now, this interface only includes a few basic options. Other user-specific preference options
/// may be added in the future if they need to be handled at Fluid's level. When this happens, they will first
/// be added through a separate interface, and become merged on a major release.
///
/// Using values from the system, rather than guessing or supplying our own, has benefits for accessibility.
/// These preferences help people of varying age and reaction times, or with disabilities related to vision
/// and muscular function.
interface PreferenceIO : IO {

    /// Get the double click interval from the system
    ///
    /// This interval defines the maximum amount of time that can pass between two clicks for a double click event
    /// to trigger, or, between each individual click in a triple click sequence. Detecting double clicks has to be
    /// implemented at node level, and double clicks do not normally have a corresponding input action.
    ///
    /// If caching is necessary, it has to be done at I/O level. This way, the I/O system may support reloading
    /// preferences at runtime.
    ///
    /// Returns:
    ///     The double click interval.
    Duration doubleClickInterval() const nothrow;

    /// Get the maximum distance allowed between two clicks for them to count as a double click.
    ///
    /// Many systems do not provide this value, so it may be necessary to make a guess.
    /// This is typically a small value around 5 pixels.
    ///
    /// Returns:
    ///     Maximum distance a pointer can travel before dismissing a double click.
    float maximumDoubleClickDistance() const nothrow;

    /// Get the desired scroll speed (in pixels, or 1/96th of an inch) for every scroll unit. This value should
    /// be used by mouse devices to translate scroll in ticks to screen space.
    ///
    /// The way scroll values are specified may vary across systems, but scroll speed is usually separate.
    /// `PreferenceIO` should take care of normalizing this, ensuring that this behavior is consistent.
    ///
    /// Returns:
    ///     Desired scroll speed in pixels per unit for both movement axes.
    Vector2 scrollSpeed() const nothrow;

}

/// Helper struct to detect double clicks, triple clicks, or overall repeated clicks.
///
/// To make use of the sensor, you need to call its two methods — `hold` and `activate` — whenever the relevant
/// event occurs. `hold` should be called for every instance, whereas `activate` should only be called if the
/// event is active. For example, to implement double clicks via mouse using input actions, you'd need to implement
/// two input handlers:
///
/// ---
/// mixin enableInputActions;
/// TimeIO timeIO;
/// PreferenceIO preferenceIO;
/// DoubleClickSensor sensor;
///
/// override void resizeImpl(Vector2) {
///     require(timeIO);
///     require(preferenceIO);
/// }
///
/// @(FluidInputAction.press, WhileHeld)
/// override bool hold(HoverPointer pointer) {
///     sensor.hold(timeIO, preferenceIO, pointer);
/// }
///
/// @(FluidInputAction.press)
/// override bool press(HoverPointer) {
///     sensor.activate();
/// }
/// ---
struct MultipleClickSensor {

    import fluid.io.time;
    import fluid.io.action;
    import fluid.io.hover;

    /// Number of registered clicks.
    int clicks;

    /// Time the event has last triggered. Following an activated click event, this is only updated once.
    private MonoTime _lastClickTime;
    private Vector2 _lastPosition;
    private bool _down;

    /// Clear the counter, resetting click count to 0.
    void clear() {
        clicks = 0;
        _down = false;
    }

    /// Call this function every time the desired click event is emitted.
    ///
    /// This overload accepts `TimeIO` and `ActionIO` systems and reads their properties to determine
    /// the right values. If for some reason you cannot use these systems, use the other overload instead.
    ///
    /// Params:
    ///     timeIO          = Time I/O system.
    ///     preferenceIO    = User preferences I/O system.
    ///     pointer         = Pointer emitting the event.
    ///     pointerPosition = Alternatively to `pointer`, just the pointer's position.
    void hold(TimeIO timeIO, PreferenceIO preferenceIO, HoverPointer pointer) {
        return hold(
            timeIO.now,
            preferenceIO.doubleClickInterval,
            preferenceIO.maximumDoubleClickDistance,
            pointer.position
        );
    }

    /// ditto
    void hold(TimeIO timeIO, PreferenceIO preferenceIO, Vector2 pointerPosition) {
        return hold(
            timeIO.now,
            preferenceIO.doubleClickInterval,
            preferenceIO.maximumDoubleClickDistance,
            pointerPosition
        );
    }

    /// Call this function every time the desired click event is emitted.
    ///
    /// This overload accepts raw values for settings. You should use Fluid's I/O systems where possible,
    /// so the other overload is preferable over this one.
    ///
    /// Params:
    ///     currentTime         = Current time in the system.
    ///     doubleClickInterval = Maximum time allowed between two clicks.
    ///     maximumDistance     = Maximum distance the pointer can travel before.
    ///     pointerPosition     = Position of the pointer emitting the event.
    void hold(MonoTime currentTime, Duration doubleClickInterval, float maximumDistance, Vector2 pointerPosition) {

        import fluid.utils : distance2;

        if (_down) return;

        const shouldReset = currentTime - _lastClickTime > doubleClickInterval
            || distance2(pointerPosition, _lastPosition) > maximumDistance^^2
            || clicks == 0;

        // Reset clicks if enough time has passed, or if the cursor has gone too far
        if (shouldReset) {
            clicks = 1;
        }
        else {
            clicks++;
        }

        // Update values
        _down = true;
        _lastClickTime = currentTime;
        _lastPosition = pointerPosition;

    }

    /// Call this function every time the desired click event is active.
    void activate() {
        _down = false;
    }

}

@("MultipleClickSensor can detect double clicks")
unittest {

    MultipleClickSensor sensor;
    MonoTime start;
    const interval = 500.msecs;
    const maxDistance = 5;
    const position = Vector2();

    sensor.hold(start +  0.msecs, interval, maxDistance, position);
    assert(sensor.clicks == 1);
    sensor.activate();
    assert(sensor.clicks == 1);

    sensor.hold(start + 140.msecs, interval, maxDistance, position);
    assert(sensor.clicks == 2);
    sensor.activate();
    assert(sensor.clicks == 2);

}

@("MultipleClickSensor can detect triple clicks")
unittest {

    MultipleClickSensor sensor;
    MonoTime start;
    const interval = 500.msecs;
    const maxDistance = 5;
    const position = Vector2();

    sensor.hold(start +  0.msecs, interval, maxDistance, position);
    assert(sensor.clicks == 1);
    sensor.activate();
    assert(sensor.clicks == 1);

    sensor.hold(start + 300.msecs, interval, maxDistance, position);
    assert(sensor.clicks == 2);
    sensor.activate();
    assert(sensor.clicks == 2);

    sensor.hold(start + 600.msecs, interval, maxDistance, position);
    assert(sensor.clicks == 3);
    sensor.activate();
    assert(sensor.clicks == 3);

}

@("MultipleClickSensor checks doubleClickInterval")
unittest {

    MultipleClickSensor sensor;
    MonoTime start;
    const interval = 500.msecs;
    const maxDistance = 5;
    const position = Vector2();

    sensor.hold(start +  0.msecs, interval, maxDistance, position);
    assert(sensor.clicks == 1);
    sensor.activate();
    assert(sensor.clicks == 1);

    sensor.hold(start + 600.msecs, interval, maxDistance, position);
    assert(sensor.clicks == 1);
    sensor.activate();
    assert(sensor.clicks == 1);

}

@("MultipleClickSensor checks maxDistance")
unittest {

    MultipleClickSensor sensor;
    MonoTime start;
    const interval = 500.msecs;
    const maxDistance = 5;
    const position1 = Vector2(0, 0);
    const position2 = Vector2(5, 5);

    sensor.hold(start +  0.msecs, interval, maxDistance, position1);
    assert(sensor.clicks == 1);
    sensor.activate();
    assert(sensor.clicks == 1);

    sensor.hold(start + 200.msecs, interval, maxDistance, position2);
    assert(sensor.clicks == 1);
    sensor.activate();
    assert(sensor.clicks == 1);

}

@("MultipleClickSensor allows for dragging")
unittest {

    MultipleClickSensor sensor;
    MonoTime start;
    const interval = 500.msecs;
    const maxDistance = 5;
    const position1 = Vector2(0, 0);
    const position2 = Vector2(3, 0);
    const position3 = Vector2(5, 5);
    const position4 = Vector2(10, 11);

    sensor.hold(start +  0.msecs, interval, maxDistance, position1);
    assert(sensor.clicks == 1);
    sensor.activate();
    assert(sensor.clicks == 1);

    sensor.hold(start + 200.msecs, interval, maxDistance, position2);
    assert(sensor.clicks == 2);
    sensor.hold(start + 250.msecs, interval, maxDistance, position3);
    assert(sensor.clicks == 2);
    sensor.hold(start + 300.msecs, interval, maxDistance, position4);
    assert(sensor.clicks == 2);
    sensor.activate();

}
