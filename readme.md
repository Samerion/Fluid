<h1>
    <img src="./logo.png" alt="" height="50" />
    glui
</h1>

A simple high-level UI library designed for use in [IsodiTools](https://github.com/Samerion/IsodiTools) and Samerion.
I decided to write it because making one turns out to be faster and easier than trying to make raygui or imgui work
in D.

**Notes:**

* If HiDPI is on in the system, fonts will be blurry, unless you load them upscaled. Use Style.loadFont instead.
* Glui currently defaults to use bindings for Raylib 3.7.0, if you're using Raylib 4.0 or newer, you should use the
  `raylib4` configuration.
* Glui cannot reliably implement scrolling nodes on macOS, so their effect is currently disabled on the platform.

It implements a tree node structure, but doesn't provide an event loop and doesn't create a window, making it easier to
integrate in other projects.

It is guaranteed to work with Raylib, but might not work with other libraries or frameworks.

Glui has a decent feature set at the moment, but new features will still be added over time. It's mostly stable as of
now and ready to be used. What it's missing the most, is examples and documentation on design concepts behind it.
