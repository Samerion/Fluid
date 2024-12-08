/// Mechanism for asynchronously passing data from one place to another.
module fluid.future.pipe;

import std.meta;

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

alias Publisher(Output : void) = Publisher!();

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

        // Listenable as a return value
        static if (is(T : Pipe!(NextOutput, NextInput), NextOutput, NextInput...)) {
            //   this: Input  => Output
            //   next: Output => T : Pipe!(NextOutput, NextInput...)
            // return: Output => NextOutput
            auto result = new ProxyPipe!(Subscriber!NextOutput);
            subscribe(
                pipe((Output output) { 
                    next(output)
                        .then(nextOutput => result(nextOutput));
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

interface Subscriber(Ts...) {

    void opCall(Ts args); 

}

/// 
class ProxyPipe(IPipes...) : PublisherSubscriberPair!IPipes {

    private staticMap!(SubscriberOf, IPipes) subscribers;

    static foreach (i, IPipe; IPipes) {

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

}

private alias SubscriberOf(T) = Subscriber!(PipeContent!T);

private template PipeContent(T) {

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

template ToParameter(T) {
    static if (is(T == void)) {
        alias ToParameter = AliasSeq!();
    }
    else {
        alias ToParameter = T;
    }
}
