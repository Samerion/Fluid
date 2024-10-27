/// General utilities for working with text.
module fluid.text.util;

import std.range;
import std.string;
import std.traits;
import std.typecons;
import std.algorithm;

@safe:

alias defaultWordChunks = breakWords;

deprecated("Use Rope.byLine instead. lineSplitter will be removed in 0.9.0") {

    package (fluid) alias lineSplitter = lineSplitterFix;

    /// Updated version of `std.string.lineSplitter` that includes trailing empty lines.
    ///
    /// `lineSplitterIndex` will produce a tuple with the index into the original text as the first element.
    static lineSplitterFix(KeepTerminator keepTerm = No.keepTerminator, Range)(Range text)
    if (isSomeChar!(ElementType!Range) && typeof(text).init.empty)
    do {

        enum dchar lineSep = '\u2028';  // Line separator.
        enum dchar paraSep = '\u2029';  // Paragraph separator.
        enum dchar nelSep  = '\u0085';  // Next line.

        import std.utf : byDchar;

        const hasEmptyLine = byDchar(text).endsWith('\r', '\n', '\v', '\f', "\r\n", lineSep, paraSep, nelSep) != 0;
        auto split = std.string.lineSplitter!keepTerm(text);

        // Include the empty line if present
        return hasEmptyLine.choose(
            split.chain(only(typeof(text).init)),
            split,
        );

    }

    /// ditto
    static lineSplitterIndex(Range)(Range text) {

        import std.typecons : tuple;

        auto initialValue = tuple(size_t.init, Range.init, size_t.init);

        return lineSplitter!(Yes.keepTerminator)(text)

            // Insert the index, remove the terminator
            // Position [2] is line end index
            .cumulativeFold!((a, line) => tuple(a[2], line.chomp, a[2] + line.length))(initialValue)

            // Remove item [2]
            .map!(a => tuple(a[0], a[1]));

    }

    unittest {

        import fluid.text.rope;
        import std.typecons : tuple;

        auto myLine = "One\nTwo\r\nThree\vStuff\nï\nö";
        auto result = [
            tuple(0, "One"),
            tuple(4, "Two"),
            tuple(9, "Three"),
            tuple(15, "Stuff"),
            tuple(21, "ï"),
            tuple(24, "ö"),
        ];

        assert(lineSplitterIndex(myLine).equal(result));
        assert(lineSplitterIndex(Rope(myLine)).equal(result));

    }

    unittest {

        import fluid.text.rope;

        assert(lineSplitter(Rope("ą")).equal(lineSplitter("ą")));

    }

}

/// Word breaking implementation that does not break words at all.
/// Params:
///     range = Text to break into words.
auto keepWords(Range)(Range range) {

    return only(range);

}

/// Break words on whitespace and punctuation. Splitter characters stick to the word that precedes them, e.g.
/// `foo!! bar.` is split as `["foo!! ", "bar."]`.
/// Params:
///     range = Text to break into words.
auto breakWords(Range)(Range range) {

    import fluid.text.rope : Rope;
    import std.uni : isAlphaNum, isWhite;
    import std.utf : decodeFront;

    /// Pick the group the character belongs to.
    static int pickGroup(dchar a) {

        return a.isAlphaNum ? 0
            : a.isWhite ? 1
            : 2;

    }

    /// Splitter function that splits in any case two
    static bool isSplit(dchar a, dchar b) {

        return !a.isAlphaNum && !b.isWhite && pickGroup(a) != pickGroup(b);

    }

    struct BreakWords {

        Range range;
        Range front = Range.init;

        bool empty() const {
            return front.empty;
        }

        void popFront() {

            dchar lastChar = 0;
            auto originalRange = range.save;

            while (!range.empty) {

                if (lastChar && isSplit(lastChar, range.front)) break;
                lastChar = range.decodeFront;

            }

            front = originalRange[0 .. $ - range.length];

        }

    }

    auto chunks = BreakWords(range);
    chunks.popFront;
    return chunks;

}

unittest {

    import fluid.text.rope;

    const test = "hellö world! 123 hellö123*hello -- hello -- - &&abcde!a!!?!@!@#3";
    const result = [
        "hellö ",
        "world! ",
        "123 ",
        "hellö123*",
        "hello ",
        "-- ",
        "hello ",
        "-- ",
        "- ",
        "&&",
        "abcde!",
        "a!!?!@!@#",
        "3"
    ];

    assert(breakWords(test).equal(result));
    assert(breakWords(Rope(test)).equal(result));

    const test2 = "Аа Бб Вв Гг Дд Ее Ëë Жж Зз Ии "
        ~ "Йй Кк Лл Мм Нн Оо Пп Рр Сс Тт "
        ~ "Уу Фф Хх Цц Чч Шш Щщ Ъъ Ыы Ьь "
        ~ "Ээ Юю Яя ";

    assert(breakWords(test2).equal(breakWords(Rope(test2))));

}

/// `wordFront` and `wordBack` get the word at the beginning or end of given string, respectively.
///
/// A word is a streak of consecutive characters — non-whitespace, either all alphanumeric or all not — followed by any
/// number of whitespace.
///
/// Params:
///     text = Text to scan for the word.
///     excludeWhite = If true, whitespace will not be included in the word.
T wordFront(T)(T text, bool excludeWhite = false) {

    import std.uni : isWhite, isAlphaNum;
    import std.utf : codeLength;

    size_t length;

    T result() { return text[0..length]; }
    T remaining() { return text[length..$]; }

    while (remaining != "") {

        // Get the first character
        const lastChar = remaining.decodeFrontStatic;

        // Exclude white characters if enabled
        if (excludeWhite && lastChar.isWhite) break;

        length += lastChar.codeLength!(typeof(text[0]));

        // Stop if empty
        if (remaining == "") break;

        const nextChar = remaining.decodeFrontStatic;

        // Stop if the next character is a line feed
        if (nextChar.only.chomp.empty && !only(lastChar, nextChar).equal("\r\n")) break;

        // Continue if the next character is whitespace
        // Includes any case where the previous character is followed by whitespace
        else if (nextChar.isWhite) continue;

        // Stop if whitespace follows a non-white character
        else if (lastChar.isWhite) break;

        // Stop if the next character has different type
        else if (lastChar.isAlphaNum != nextChar.isAlphaNum) break;

    }

    return result;

}

/// ditto
T wordBack(T)(T text, bool excludeWhite = false) {

    import std.utf : codeLength;
    import std.uni : isWhite, isAlphaNum;

    size_t length = text.length;

    T result() { return text[length..$]; }
    T remaining() { return text[0..length]; }

    while (remaining != "") {

        // Get the first character
        const lastChar = remaining.decodeBackStatic;

        // Exclude white characters if enabled
        if (excludeWhite && lastChar.isWhite) break;

        length -= lastChar.codeLength!(typeof(text[0]));

        // Stop if empty
        if (remaining == "") break;

        const nextChar = remaining.decodeBackStatic;

        // Stop if the character is a line feed
        if (lastChar.only.chomp.empty && !only(nextChar, lastChar).equal("\r\n")) break;

        // Continue if the current character is whitespace
        // Inverse to `wordFront`
        else if (lastChar.isWhite) continue;

        // Stop if whitespace follows a non-white character
        else if (nextChar.isWhite) break;

        // Stop if the next character has different type
        else if (lastChar.isAlphaNum != nextChar.isAlphaNum) break;

    }

    return result;

}

/// `std.utf.decodeFront` and `std.utf.decodeBack` variants that do not mutate the range
dchar decodeFrontStatic(T)(T range) @trusted {

    import std.utf : decodeFront;

    return range.decodeFront;

}

/// ditto
dchar decodeBackStatic(T)(T range) @trusted {

    import std.utf : decodeBack;

    return range.decodeBack;

}

unittest {

    assert("hello world!".wordFront == "hello ");
    assert("hello, world!".wordFront == "hello");
    assert("hello world!".wordBack == "!");
    assert("hello world".wordBack == "world");
    assert("hello ".wordBack == "hello ");

    assert("witaj świecie!".wordFront == "witaj ");
    assert(" świecie!".wordFront == " ");
    assert("świecie!".wordFront == "świecie");
    assert("witaj świecie!".wordBack == "!");
    assert("witaj świecie".wordBack == "świecie");
    assert("witaj ".wordBack == "witaj ");

    assert("Всем привет!".wordFront == "Всем ");
    assert("привет!".wordFront == "привет");
    assert("!".wordFront == "!");

    // dstring
    assert("Всем привет!"d.wordFront == "Всем "d);
    assert("привет!"d.wordFront == "привет"d);
    assert("!"d.wordFront == "!"d);

    assert("Всем привет!"d.wordBack == "!"d);
    assert("Всем привет"d.wordBack == "привет"d);
    assert("Всем "d.wordBack == "Всем "d);

    // Whitespace exclusion
    assert("witaj świecie!".wordFront(true) == "witaj");
    assert(" świecie!".wordFront(true) == "");
    assert("witaj świecie".wordBack(true) == "świecie");
    assert("witaj ".wordBack(true) == "");

}

unittest {

    assert("\nabc\n".wordFront == "\n");
    assert("\n  abc\n".wordFront == "\n  ");
    assert("abc\n".wordFront == "abc");
    assert("abc  \n".wordFront == "abc  ");
    assert("  \n".wordFront == "  ");
    assert("\n     abc".wordFront == "\n     ");

    assert("\nabc\n".wordBack == "\n");
    assert("\nabc".wordBack == "abc");
    assert("abc  \n".wordBack == "\n");
    assert("abc  ".wordFront == "abc  ");
    assert("\nabc\n  ".wordBack == "\n  ");
    assert("\nabc\n  a".wordBack == "a");

    assert("\r\nabc\r\n".wordFront == "\r\n");
    assert("\r\n  abc\r\n".wordFront == "\r\n  ");
    assert("abc\r\n".wordFront == "abc");
    assert("abc  \r\n".wordFront == "abc  ");
    assert("  \r\n".wordFront == "  ");
    assert("\r\n     abc".wordFront == "\r\n     ");

    assert("\r\nabc\r\n".wordBack == "\r\n");
    assert("\r\nabc".wordBack == "abc");
    assert("abc  \r\n".wordBack == "\r\n");
    assert("abc  ".wordFront == "abc  ");
    assert("\r\nabc\r\n  ".wordBack == "\r\n  ");
    assert("\r\nabc\r\n  a".wordBack == "a");

}
