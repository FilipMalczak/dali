module dali.wither.mixins;

template WitherScope(Self) {
    import dali.wither.annotations;
    import std.traits;
    import std.meta;
    import dali.utils.typedescriptor;

    enum descriptor = Descriptor!Self();
    enum options = descriptor.getOptions!WitherOptions;

    template withMethodName(string fieldName){
        import std.string;

        static if (empty(options.prefix)){
            enum withMethodName = fieldName;
        } else
            enum withMethodName = WitherScope!Self.options.prefix ~ capitalize(fieldName);
    }

    mixin template mixinField(alias descr, size_t ___i){
        import std.meta;
        import std.traits;
        static if (___i < descr.fieldNames.length) {

            mixin(
                fullyQualifiedName!(Self)~" "~WitherScope!Self.withMethodName!(descr.fieldNames[___i])~
                "("~fullyQualifiedName!(descr.fieldTypes[___i])~" val){ "~
                    fullyQualifiedName!(Self)~" result = copy(); "~
                    "result."~descr.fieldNames[___i]~" = val; "~
                    "return result; "~
                "}"
            );
            mixin WitherScope!Self.mixinField!(descr, ___i+1);
        }
    }

    mixin template impl(){
        mixin WitherScope!Self.mixinField!(WitherScope!Self.descriptor, 0);
    }
}

mixin template Wither() {
    import dali.copy.mixins;

    mixin Copy;

    alias Self = typeof(this);

    mixin WitherScope!Self.impl;

}

version(unittest){
    import dali.tostring.mixins;
    import dali.constructors.mixins;
    import std.stdio;

    struct A {
        mixin ToString;
        mixin Wither;
        mixin AllArgsConstructor;

        int a;
        string b;
    }
}

unittest {
    A a = A();
    A b = a.withA(2).withB("xyz");
    assert(b == A(2, "xyz"));
}