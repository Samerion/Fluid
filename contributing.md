# Contributing to Fluid

Thank you for your interest in Fluid! Contributions are very welcome and highly appreciated.
Current issues are all tracked on the [Samerion Forgejo bugtracker][issues], and pull requests are
accepted both through [Forgejo][pulls] and [GitHub][gh-pulls].

[issues]: https://git.samerion.com/Samerion/Fluid/issues
[pulls]: https://git.samerion.com/Samerion/Fluid/pulls
[gh-pulls]: https://github.com/Samerion/Fluid/pulls

## Questions

Fluid does not currently have a dedicated space for questions, but you can direct them to
maintainers:

* [Send an e-mail to Artha][mail]
* [On the issue tracker][issues]
* [Ask on the D programming Discord](https://discord.gg/MZ9eB37Uta)
* [Ask on the Samerion Discord](https://discord.gg/cMbuRKxHP8)

[mail]: mailto:artha@samerion.com

## Reporting bugs

If you encountered a bug, you should report it [on the Forgejo bugtracker][issues]. Creating an
account is free. A valid e-mail address that you can verify is required.

When creating a bug report, please include the following information:

  * Your operating system, compiler, and compiler version. \
    Fluid supports **DMD 2.098 and newer**, and LDC 1.28 and newer.
    macOS users should use LDC only.

  * All error messages you're getting, if relevant.

  * A minimal reproducible example. \
    Send a minimal piece of code that works on its own. [It should be self-contained,
    so that it can be tested by anyone](https://sscce.org/).

Should you run into trouble while setting up your account, you can also [report your issue through
e-mail][mail].

## Finding issues to work on

Contributing to Fluid is a great way to get started with the library! Even if you came here
looking for specific issues you have that you'd like to fix, you can familiarize yourself with the
process by fixing another, smaller issue.

 1. Different issues target different version series, and only one series is worked on at a time. \
    Fluid is currently in [the 0.7.x series][0.7.x]. Working on issues for these milestones
    will be the most effective!
    
 2. The issue tracker uses the `difficulty/easy` label to mark issues that should require little
    additional knowledge. See if you can find any that would be of interest to you.

**Check out all issues for the current series** by [looking at the milestones][0.7.x].

[0.7.x]: https://git.samerion.com/Samerion/Fluid/milestones?state=open&q=0.7&fuzzy=

## Setting up development environment

To contribute to Fluid, you will need to fork the repository on [Forgejo][forgejo-fork] or
[GitHub][github-fork]. At this step, having basic knowledge of [git](https://git-scm.com/) will
be helpful.

After forking your repository, you have to clone it to your machine:

```sh
# For Forgejo
git clone git@git.samerion.com:YOUR-USERNAME/Fluid.git

# For GitHub
git clone git@github.com:YOUR-USERNAME/Fluid.git
```

Having entered the Fluid repository, you can check if you're able to run the tour:

```sh
cd Fluid
dub run :tour
```

[forgejo-fork]: https://git.samerion.com/Samerion/Fluid/fork
[github-fork]: https://github.com/Samerion/Fluid/fork

## General guidelines

Before submitting your pull request, make sure your changes pass tests:

```
dub test
```

When adding functions, make sure to keep them documented. *Always* document parameters and return
types. Cover your change by unit tests; add them to the `tests/` directory.

If updating documentation, use the `serve-docs` build type to verify it looks correctly. You can
then open the documentation on <https://localhost:8080>.

```
dub -b=serve-docs
```

To stay compatible with older compiler versions, Fluid does not use new language features.

* **Do not use arrow functions**, except for lambdas.

  ```d
  // Do not:
  int foo() => 1;

  // Do:
  int foo() {
      return 1;
  }
  ```

* **Do not use named arguments**. Keep parameter count minimal. If names are needed for clarity,
  use variables:

  ```d
  // Do not:
  foo(
      first: 1,
      second: 2)

  // Do:
  const first = 1;
  const second = 2;
  foo(first, second);
  ```

* **Do not perform object comparison with the `==` operator**. At the time of writing, there is no
  suitable alternative to handle `null` cases, but if you know the operands aren't null, you can
  use `opEquals` directly: `node1 !is null && node1.opEquals(node2)`.

## Style guidelines

Fluid adheres to [the D style guide](https://dlang.org/dstyle.html), with the additional
rules:

  * Brackets should be on the same line as the statement they're on. `else`, `catch` and similar
    statements should not be on the same line as the closing bracket.

    ```d
    void foo(bool condition) {
        if (condition) {
            writeln("Yes");
        }
        else {
            writeln("No");
        }
    }
    ```

  * Lines should be limited to **100 characters**. Some parts of Fluid use a 120 character limit,
    however new code should never exceed the new limit.

  * Keywords like `if`, `foreach` and `while` should be followed by a space:

    ```d
    if (...) { ... }
    while (...) { ... }
    foreach (...) { ... }
    ```

  * No space is allowed before or inside parentheses for function calls. Commas must be followed
    by a space or a line feed:

    ```d
    call("hello", "world");
    call("foo",
        "bar");
    ```

  * Fluid should be `@safe` wherever possible. A `@safe:` statement should follow every module
    declaration, surrounded by blank lines:

    ```d
    module fluid.my_node;

    @safe:
    
    import fluid.node;
    ```

  * Avoid reassigning variables. Use `const` where possible.

    ```d
    Vector2 localCenter(Rectangle space) {
        const withOffset = space.start + localOffset;
        return withOffset + space.size / 2;
    }
    ```

  * `nothrow` should be used in non-virtual calls, and I/O
    implementations, but not in templates.

  * Document every public symbol using triple slashes `///` and include `Params:` and `Returns:`
    sections. Avoid DDoc macros, and prefer Markdown `Plain text, *italic*, **bold**`.
    Refer to other symbols using *\[square brackets\]*.

    ```d
    /// Test if the specified point is the node's bounds.
    /// Params:
    ///     outer    = Padding box allocated for this node.
    ///     inner    = Content box allocated for this node.
    ///     position = Point to test.
    /// Returns:
    ///     [HitFilter.hit] if the point is in bounds of this node, or
    ///     [HitFilter.miss] if not.
    HitFilter inBounds(Rectangle outer, Rectangle inner, Vector2 position);
    ```

  * Fields should always be listed above any function. Private fields should be prefixed with an
    underscore.

    *Classes* should wrap fields in `public { }`, `protected { }` or `private { }` blocks.

    ```d
    struct Data {
        int publicField;
        private int _privateField;
        
    }
    class MyNode : Node {

        public {
            int publicField;
        }

        private {
            int _privateField;
        }

        this() { ... }
      
    }
    ```

## Structure and idiom guidelines

Fluid uses *node builders* and *node properties* which are patterns specific to this library.

  * Node builders and node properties should be listed in the module for the same node they apply
    to.

    > Note that in the `0.7.x` series, node properties for `Node` are instead located in the
    > `fluid.structs` module.

  * Node builders should precede any relevant node properties, and the properties should precede
    the node. Builders and properties for different nodes should not be intermixed.

    ```d
    // 1. node builder
    alias mainNode = nodeBuilder!MainNode;

    // 2. node property
    auto changeMainNode(...) { ... }

    // 3. node
    class MainNode {
        ...
    }

    alias subNode = nodeBuilder!SubNode;

    class SubNode {
        ...
    }
    ```

  * Include all node builders and node properties in the module documentation for the
    nodes they're relevant to.

  * Node properties should be avoided in favor of specific node builders and constructors. Provide
    `textInput` and `lineInput` instead of `.multiline`. Provide specific node builders only where
    useful.

  * In documentation and call-site examples, node properties should be prefixed with a dot, where
    possible:

    ```d
    /// The `.layout` property defines where a node will display in its container.
    auto layout() { ... }
    ```

    ```d
    run(
        vspace(
            label(
                .layout!1,
                "Hello, World!"
            ),
        ),
    );
    ```
