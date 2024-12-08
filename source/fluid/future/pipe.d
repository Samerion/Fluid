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
final class Pipe(Return, Args...) : EventCallback!Args {
    
    static if (is(Return == void)) {
        alias Output = AliasSeq!();
    }
    else {
        alias Output = Return;
    }
    alias Input = Args;
    alias Delegate = Return delegate(Input) @safe;

    private {

        Delegate callback;
        EventCallback!Output next;

    }

    /// Set up a pipe, use a callback to process data that comes through.
    this(Delegate callback) {
        this.callback = callback;
    }

    /// Connect a listener to the pipe.
    /// Params:
    ///     listener = A function to execute when the pipe receives data. The listener can return another pipe
    ///         which can then be accessed by proxy from the return value.
    /// Returns:
    ///     A pipe that is loaded with the same data that is returned by the `listener`.
    auto then(T)(T delegate(Output) @safe next)
    in (this.next is null, "The pipe has already been connected with then()")
    do {

        // Pipe as a return value
        static if (is(T : Pipe!(NextOutput, NextInput), NextOutput, NextInput...)) {
            //   this: Input  => Output
            //   next: Output => T : Pipe!(NextOutput, NextInput...)
            // return: Output => NextOutput
            auto result = new Pipe!(NextOutput, NextOutput)(a => a);
            this.next = pipe((Output output) { 
                next(output)
                    .then(nextOutput => result(nextOutput));
            });
            return result;
            
        }

        // Plain return value
        else {
            auto pipe = new Pipe!(T, Output)(next);
            this.next = pipe;
            return pipe;
        }
    }

    /// Push data down the pipe.
    /// Params:
    ///     input = Data to load into the pipe.
    void opCall(Input input) {

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

interface EventCallback(Ts...) {

    void opCall(Ts args); 

}
