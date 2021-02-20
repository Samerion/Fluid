module glui.utils;

import std.meta;

import glui.style;
import glui.structs;

/// Create a function to easily construct nodes.
template simpleConstructor(T) {

    T simpleConstructor(Args...)(Args args) {

        return new T(args);

    }

}

// lmao
// AliasSeq!(AliasSeq!(T...)) won't work, this is a workaround
alias BasicNodeParamLength = Alias!5;
template BasicNodeParam(int index) {

    static if (index == 0) alias BasicNodeParam = AliasSeq!(Layout, Style);
    static if (index == 1) alias BasicNodeParam = AliasSeq!(Style, Layout);
    static if (index == 2) alias BasicNodeParam = AliasSeq!(Layout);
    static if (index == 3) alias BasicNodeParam = AliasSeq!(Style);
    static if (index == 4) alias BasicNodeParam = AliasSeq!();

}
