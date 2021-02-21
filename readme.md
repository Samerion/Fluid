# glui

A simple high-level UI library designed for use in [IsodiTools](https://github.com/Samerion/IsodiTools) and Samerion.
I decided to write it because making one comes out to be faster and easier than trying to make raygui or imgui work
in D.

It implements a tree node structure, but doesn't provide an event loop and doesn't create a window, making it easier to
integrate in other projects.

It is guaranteed to work with Raylib, but might not work with other libraries or frameworks.

glui has a poor feature set at the moment and new features will be added as needed.
