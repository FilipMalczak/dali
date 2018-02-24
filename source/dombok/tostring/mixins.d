module dombok.tostring.mixins;



mixin template ToString() {
    import dombok.tostring.annotations;

    import std.traits;
    import std.meta;
    import std.array;

    alias Self = typeof(this);

    public string toString(){
        import std.conv: to;
        string result = "";
        alias allOptions = getUDAs!(Self, ToStringOptions);
        static assert (allOptions.length < 2);
        pragma(msg, Self, " #toString");
        static if (allOptions.length == 1) {
            alias options = Alias!(allOptions[0]);
            pragma(msg, "found ", options);
        } else {
            alias options = Alias!(ToStringOptions());
            pragma(msg, "default ", options);
        }
        static if (options.qualifiedName)
            result ~= fullyQualifiedName!Self;
        else
            result ~= __traits(identifier, Self);
        result ~= options.leftBracket;
        string[] fieldVals = [];
        foreach (fieldName; FieldNameTuple!(Self)){
            static if (!hasUDA!(mixin("this."~fieldName), ToStringIgnore)) {
                alias convertWith = getUDAs!(mixin("this."~fieldName), ToStringWith);
                static assert(convertWith.length < 2);
                string fieldPrefix = "";
                static if (options.fieldNames){
                    static if (options.fieldTypes){
                        static if (options.qualifiedFieldTypes)
                            fieldPrefix ~= fullyQualifiedName!(typeof(mixin("this."~fieldName)));
                        else
                            fieldPrefix ~= typeof(mixin("this."~fieldName)).stringof;
                        fieldPrefix ~= " ";
                    }
                    fieldPrefix ~= fieldName ~ options.fieldAssign;
                }
                static if (convertWith.length == 0)
                    string fieldValue = to!string(mixin("this."~fieldName));
                else
                    string fieldValue = convertWith[0].converter(mixin("this."~fieldName));
                static if (is(typeof(mixin("this."~fieldName)): string) && options.quoteStrings)
                    fieldValue = options.quote ~ fieldValue ~ options.quote;
                fieldVals ~= (fieldPrefix ~ fieldValue);
            }
        }
        result ~= join(fieldVals, options.fieldSeparator);
        result ~= options.rightBracket;
        return result;
    }
}

version(unittest){
    import dombok.tostring.annotations;

    struct A {
        mixin ToString;

        int a;
        string b;
    }

    string doubleToString(int x){
        import std.conv;
        return to!string(x*2);
    }

    struct B {
        mixin ToString;

        @ToStringWith!doubleToString
        int x;
    }

    struct C {
        mixin ToString;

        int a;
        @ToStringIgnore
        int b;
        int c;
    }

    @ToStringOptions(true)
    struct D {
        mixin ToString;
    }

    @ToStringOptions(false)
    struct E {
        mixin ToString;
    }

    @ToStringOptions(false)
    struct F {
        mixin ToString;

        A a;
        D d;
        bool b;
    }
}

unittest {
    import std.conv;
    assert(to!string(A(1, "b")) == "dombok.tostring.mixins.A(a=1, b=\"b\")");
    assert(to!string(B(1)) == "dombok.tostring.mixins.B(x=2)");
    assert(to!string(C(1, 2, 3)) == "dombok.tostring.mixins.C(a=1, c=3)");
    assert(to!string(D()) == "dombok.tostring.mixins.D()");
    assert(to!string(E()) == "E()");
    assert(to!string(F(A(5, "test"), D(), false)) == "F(a=dombok.tostring.mixins.A(a=5, b=\"test\"), d=dombok.tostring.mixins.D(), b=false)");
}