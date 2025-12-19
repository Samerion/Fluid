![Hello World from Fluid!](./resources/hello-fluid.png)

# Fluid

* [Documentation](https://libfluid.org)
* [Issues](https://git.samerion.com/Samerion/Fluid/issues)
* [DUB](https://code.dlang.org/packages/fluid)

A flexible, pluggable UI library for [the D programming language](https://dlang.org/). Minimal
setup. Declarative. Non-intrusive.

```d
auto root = vspace(
    .layout!"center",
    label(
        .layout!"center",
        "Hello World from"
    ),
    imageView("./logo.png"),
);
```

Fluid comes with [Raylib 5][raylib] support. Integration is seamless: one or two calls do the job.

```d
while (!WindowShouldClose) {
    BeginDrawing();
        ClearBackground(color!"#fff");
        root.draw();
    EndDrawing();
}
```

[raylib]: https://www.raylib.com/

Fluid is largely feature-complete and has successfully been used to produce complete programs like
[Samerion Studio](https://www.youtube.com/watch?v=9Yjw7KmGEFU). It is still receiving incremental
improvements to make it easier to use, more accessible, and more performant.

While in pre-release stage, breaking changes are reserved to *v0.x* version bumps and new features.

**Support Fluid development on Patreon: https://www.patreon.com/samerion**

* Straightforward, high-level API
* Responsive by design
* Massively extensible: add your own nodes, I/O systems, and backends
* Components form building blocks
* Reliable mouse and keyboard input
* Separate layout and styling
* Out-of-the-box Unicode support
* Code editor node included
* Full HiDPI support
* Partial gamepad support

## Get Fluid

For a quick start guide on Fluid, check out the tour:

```
dub run fluid:tour
```

Create a new [dub][dub] project based on Fluid:

```
dub init -t fluid
```

You can use [dub][dub] to include Fluid in your code:

```
dub add fluid
dub add raylib-d
dub run raylib-d:install
```

[dub]: https://code.dlang.org/

## Contribute to Fluid

Fluid welcomes contributions! You can review open issues and open pull requests to fix them.
If you need help, you'll receive it.

* [Open an issue](https://git.samerion.com/Samerion/Fluid/issues/new)
* [Review current goals](https://git.samerion.com/Samerion/Fluid/milestones?state=open&q=0.8&fuzzy=)

Read more about contributing to Fluid in our [contributing.md](contributing.md) file.
