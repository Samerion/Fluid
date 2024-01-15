<img src="./resources/hello-fluid.png" alt="Hello World from Fluid!" align="right"/>

A flexible UI library for [the D programming language](https://dlang.org/). Minimal setup. Declarative. Non-intrusive.

```d
auto root = vspace(
    .layout!"center",
    label(.layout!"center", "Hello World from"),
    imageView("./logo.png", Vector2(499, 240)),
);
```

Fluid comes with [Raylib 5][raylib] and [arsd.simpledisplay][sdpy] support. Integration is seamless: one or two calls do
the job.

```d
while (!WindowShouldClose) {

    BeginDrawing();

        ClearBackground(color!"#fff");
        root.draw();

    EndDrawing();

}
```

[raylib]: https://www.raylib.com/
[sdpy]: https://arsd-official.dpldocs.info/arsd.simpledisplay.html

Fluid has a decent feature set at the moment and new features will still be added over time. Fluid is already mostly
stable and ready for use, but is still likely to receive multiple breaking changes before leaving its pre-release stage.

**Support Fluid development on Patreon: https://www.patreon.com/samerion**

* Straightforward, high-level API
* Responsive layout
* Extensible
* Components easily combined together
* Reliable mouse and keyboard input
* Separate layout and styling
* Scrolling support
* Out-of-the-box Unicode support
* Full HiDPI support
* Partial gamepad support
