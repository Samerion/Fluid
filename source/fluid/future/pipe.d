/// Mechanism for asynchronously passing data from one place to another.
module fluid.future.pipe;

import std.meta;
import std.traits;
import std.typecons;

@safe:

/// Set up a pipe from a delegate.
/// Params:
///     dg = Function to transform the process data the pipe outputs.
/// Returns:
///     A pipe that processes data using the function.
auto pipe(Ret, Args...)(Ret delegate(Args) @safe dg) {

    return new Pipe!(Ret, Args)(dg);

}

/// Pass plain data between pipes.
@("`then() can accept plain data")
unittest {

    import std.conv;

    string result;

    auto myPipe = pipe(() => 1);
    myPipe
        .then(number => number + 2)
        .then(number => number.to!string)
        .then(text => text ~ ".0")
        .then(text => result = text);

    myPipe();
    assert(result == "3.0");


}

/// `then` will resolve pipes it returns.
@("`then` will resolve pipes it returns")
unittest {

    auto pipe1 = pipe({ });
    auto pipe2 = pipe((int number) => 1 + number);

    int result;

    pipe1
        .then(() => pipe2)
        .then(value => result = value);

    pipe1();
    assert(result == 0);
    pipe2(10);
    assert(result == 11);

}

/// Pipes can accept multiple arguments.
@("Pipes can accept multiple arguments")
unittest {

    int a, b, c;

    auto pipe = pipe((int newA, int newB, int newC) {
        a = newA;
        b = newB;
        c = newC;
    });
    pipe(1, 2, 3);

    assert(a == 1);
    assert(b == 2);
    assert(c == 3);

}

/// Pipes provide a callback system where functions can be chained. The result of one callback can be passed 
/// to another in a linear chain.
///
/// Pipes make it possible to write callback-based code that shows the underlying sequence of events:
///
/// ---
/// root.focusChild()
///     .then(child => child.scrollIntoView())
///     .then(a => node.flash(1.second))
/// ---
///
/// In Fluid, they are most often used to operate on `TreeAction`. A tree action callback will fire when
/// the action finishes.
///
/// This pattern resembles a [commandline pipelines](pipe), where a process "pipes" data into another. 
/// It may be a bit similar to [JavaScript Promises][Promise], but unlike Promises, pipes may trigger 
/// a callback multiple times, as opposed to just once.
///
/// [pipeline]: https://en.wikipedia.org/wiki/Pipeline_(Unix)#Pipelines_in_command_line_interfaces
/// [Promise]: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise
final class Pipe(Return, Args...) : Subscriber!Args, Publisher!Return {
    
    alias Output = ToParameter!Return;
    alias Input = Args;
    alias Delegate = Return delegate(Input) @safe;

    private {

        Delegate callback;
        Subscriber!Output next;

    }

    /// Set up a pipe, use a callback to process data that comes through.
    this(Delegate callback) {
        this.callback = callback;
    }

    /// Subscribe to the data sent by this publisher. Only one subscriber can be assigned to a pipe at once.
    ///
    /// For high-level API, use `then`.
    ///
    /// Params:
    ///     subscriber = Subscriber to register.
    override void subscribe(Subscriber!Output subscriber)
    in (this.next is null, "Pipe already has a subscriber. Cannot subscribe (then).")
    do {
        this.next = subscriber;
    }

    /// Push data down the pipe.
    /// Params:
    ///     input = Data to load into the pipe.
    override void opCall(Input input) {

        static if (is(Return == void)) {
            callback(input);
            if (next) next();
        }

        else {
            auto output = callback(input);
            if (next) next(output);
        }
        
    }

}

/// A publisher sends emits events that other objects can listen to.
alias Publisher(Output : void) = Publisher!();

/// ditto
interface Publisher(Outputs...)
if (!is(Output == void)) {

    // Bug workaround: manually unwrap Outputs
    static if (Outputs.length == 1)
        alias Output = Outputs[0];
    else 
        alias Output = Outputs;
    
    /// Low-level API to directly subscribe to the data sent by this publisher.
    ///
    /// Calling this multiple times is undefined behavior.
    ///
    /// Params:
    ///     subscriber = Subscriber to register.
    void subscribe(Subscriber!Output subscriber);

    /// Connect a listener to the publisher.
    /// Params:
    ///     listener = A function to execute when the publisher sends data. The listener can return another publisher
    ///         which can then be accessed by proxy from the return value.
    /// Returns:
    ///     A pipe that is loaded with the same data that is returned by the `listener`.
    auto then(T)(T delegate(Output) @safe next) {

        alias Publishers = AllPublishers!T;

        // Return value is a publisher
        static if (Publishers.length != 0) {
            //   this: Input  => Output
            //   next: Output => T : Pipe!(NextOutput, NextInput...)
            // return: Output => NextOutput
            auto result = new MultiPublisher!Publishers;
            subscribe(

                // When this publisher receives data
                pipe((Output output) { 

                    // Pass it to the listener
                    auto publisher = next(output);

                    // And connect the returned publisher to the multipublisher
                    static foreach (Publisher; Publishers) {
                        (cast(Publisher) publisher)
                            .subscribe(cast(SubscriberOf!Publisher) result);
                    }
                })
            );
            return result;
            
        }

        // Plain return value
        else {
            auto pipe = new Pipe!(T, Output)(next);
            subscribe(pipe);
            return pipe;
        }
    }

}

/// A subscriber is an object that receives data from a `Publisher`.
interface Subscriber(Ts...) {

    void opCall(Ts args); 

}

/// A basic publisher (and subscriber) implementation that will pipe data to subscribers of the matching type.
alias MultiPublisher(IPipes...) = MultiPublisherImpl!(staticMap!(AllPublishers, IPipes));

/// Setting up a publisher that separately produces two different types.
@("Setting up a publisher that separately produces two different types.")
unittest {

    auto multi = new MultiPublisher!(Publisher!int, Publisher!string);

    int resultInt;
    string resultString;
    multi.then((int a) => resultInt = a);
    multi.then((string a) => resultString = a);

    multi(1);
    assert(resultInt == 1);
    assert(resultString == "");

    multi("Hello!");
    assert(resultInt == 1);
    assert(resultString == "Hello!");

}

@("MultiPublisher can be returned from then()")
unittest {

    import std.stdio;

    auto multi = new MultiPublisher!(Publisher!int, Publisher!string);
    auto start = pipe(() => 1);
    auto chain = start.then(a => multi);

    int myInt;
    string myString;

    chain.then((int a) => myInt = a);
    chain.then((string a) => myString = a);

    start();
    multi(1);
    assert(myInt == 1);
    multi("Hi!");
    assert(myString == "Hi!");

}

class MultiPublisherImpl(IPipes...) : staticMap!(PublisherSubscriberPair, IPipes)
if (IPipes.length != 0) {

    // Tuple isn't strictly necessary here, but it fixes LDC builds
    private Tuple!(staticMap!(SubscriberOf, IPipes)) subscribers;

    static foreach (i, IPipe; IPipes) {

        alias then = Publisher!(PipeContent!IPipe).then;

        void subscribe(Subscriber!(PipeContent!IPipe) subscriber)
        in (subscribers[i] is null, "A subscriber for " ~ PipeContent!IPipe.stringof ~ " was already registered.")
        do {
            subscribers[i] = subscriber;
        }

        void opCall(PipeContent!IPipe content) {
            if (subscribers[i]) {
                subscribers[i](content);
            }
        }

    }

    override string toString() const {

        import std.conv;
        return text("MultiPublisher!", IPipes.stringof);

    }

}

private alias SubscriberOf(T) = Subscriber!(PipeContent!T);

/// List all publishers implemented by the given type (including, if the given type is a publisher).
alias AllPublishers(T) = Filter!(isPublisher, InterfacesTuple!T, Filter!(isInterface, T));

/// List all subscribers implemented by the given type (including, if the given type is a publisher).
alias AllSubscribers(T) = Filter!(isSubscriber, InterfacesTuple!T, Filter!(isInterface, T));

/// Check if the given type is a subscriber.
enum isSubscriber(T) = is(T : Subscriber!Ts, Ts...);

/// Check if the given type is a publisher.
enum isPublisher(T) = is(T : Publisher!Ts, Ts...);

private enum isInterface(T) = is(T == interface);

/// For an instance of either `Publisher` or `Subscriber`, get the type trasmitted by the interface. This function
/// only operates on the two interfaces directly, and will not work with subclasses.
template PipeContent(T) {

    // Publisher
    static if (is(T == Publisher!Ts, Ts...)) {
        alias PipeContent = Ts;
    }

    // Subscriber
    else static if (is(T == Subscriber!Ts, Ts...)) {
        alias PipeContent = Ts;
    }

    // Neither
    else static assert(false, T.stringof ~ " is not a subscriber nor a publisher");

}

private template PublisherSubscriberPair(T) {

    // Publisher
    static if (is(T == Publisher!Ts, Ts...)) {
        alias PublisherSubscriberPair = AliasSeq!(Publisher!Ts, Subscriber!Ts);
    }

    // Subscriber
    else static if (is(T == Subscriber!Ts, Ts...)) {
        alias PublisherSubscriberPair = AliasSeq!(Publisher!Ts, Subscriber!Ts);
    }

    // Neither
    else static assert(false, T.stringof ~ " is not a subscriber nor a publisher");

}

/// Converts `void` to `()` (an empty tuple), leaves remaining types unchanged.
template ToParameter(T) {
    static if (is(T == void)) {
        alias ToParameter = AliasSeq!();
    }
    else {
        alias ToParameter = T;
    }
}

struct Event(T...) {

    import std.array;

    private Appender!(Subscriber!T[]) subscribers;

    size_t length() const {
        return subscribers[].length;
    }

    void clearSubscribers() {
        subscribers.clear();
    }

    void subscribe(Subscriber!T subscriber) {
        this.subscribers ~= subscriber;
    }

    void opOpAssign(string op : "~")(Subscriber!T subscriber) {
        this.subscribers ~= subscriber;
    }

    void opOpAssign(string op : "~")(Subscriber!T[] subscribers) {
        this.subscribers ~= subscribers;
    }

    void opCall(T arguments) {
        foreach (subscriber; subscribers[]) {
            subscriber(arguments);
        }
    }

    string toString() const {

        import std.conv;
        return text("Event!", T.stringof, "(", length, " events)");

    }

}

/// Get the Publisher interfaces that can output a value that shares a common type with `Inputs`.
template PublisherType(Publisher, Inputs...) {

    alias Result = AliasSeq!();

    // Check each publisher
    static foreach (P; AllPublishers!Publisher) {

        // See if its type can cast to the inputs
        static if (is(Inputs : PipeContent!P) || is(PipeContent!P : Inputs)) {
            Result = AliasSeq!(Result, P);
        }

    }

    alias PublisherType = Result;

}

/// Connect to a publisher and assert the values it sends equal the one attached.
AssertPipe!(PipeContent!(PublisherType!(T, Inputs)[0])) thenAssertEquals(T, Inputs...)(T publisher, Inputs value,
    string file = __FILE__, size_t lineNumber = __LINE__)
if (PublisherType!(T, Inputs).length != 0) {

    auto pipe = new typeof(return)(value, file, lineNumber);
    publisher.subscribe(pipe);
    return pipe;

}

class AssertPipe(Ts...) : Subscriber!Ts, Publisher!(), Publisher!Ts
if (Ts.length != 0) {

    public {

        /// Value this pipe expects to receive.
        Tuple!Ts expected;
        string file;
        size_t lineNumber;

    }

    private {

        Event!() _eventEmpty;
        Event!Ts _event;

    }

    this(Ts expected, string file = __FILE__, size_t lineNumber = __LINE__) {
        this.expected = expected;
        this.file = file;
        this.lineNumber = lineNumber;
    }

    override void subscribe(Subscriber!() subscriber) {
        _eventEmpty ~= subscriber;
    }

    override void subscribe(Subscriber!Ts subscriber) {
        _event ~= subscriber;
    }

    override void opCall(Ts received) {

        import std.conv;
        import std.exception;
        import core.exception;
        import fluid.node;

        // Direct comparison for nodes to ensure safety on older compilers
        static if (is(Ts == AliasSeq!Node)) {
            const bothNull = expected[0] is null && received[0] is null;
            enforce!AssertError(bothNull || expected[0].opEquals(received), 
                text("Expected ", expected.expand, ", but received ", received),
                file,
                lineNumber);
        }
        else {
            enforce!AssertError(expected == tuple(received), 
                text("Expected ", expected.expand, ", but received ", received),
                file,
                lineNumber);
        }

        _event(received);
        _eventEmpty();

    }
    
    
}
