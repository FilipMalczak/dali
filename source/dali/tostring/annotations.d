module dali.tostring.annotations;

import std.traits;
import dali.builder.mixins;

struct ToStringOptions{
    bool qualifiedName = true;
    bool fieldNames = true;
    bool fieldTypes = false;
    bool qualifiedFieldTypes = false;
    bool quoteStrings = true;
    string fieldAssign = "=";
    string fieldSeparator = ", ";
    string leftBracket = "(";
    string rightBracket = ")";
    string quote = "\"";

    mixin Builder;
}

enum ToStringIgnore;

struct ToStringWith(C...) if (C.length == 1 && isCallable!C && is(ReturnType!C: string)) {
    alias converter = C[0];
}