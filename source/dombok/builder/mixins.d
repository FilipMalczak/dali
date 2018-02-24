module dombok.builder.mixins;

mixin template Builder() {
    import std.traits;
    import std.meta;
    import std.array;
    import std.string;
    import std.algorithm.iteration;
    import std.algorithm.searching;
    import dombok.builder.annotations;

    alias Self = typeof(this);

    //todo introduce class support
    static assert(is(Self == struct));

    alias ____ToString___fieldNames = FieldNameTuple!Self;
    alias ____ToString___fieldTypes = Fields!Self;
    alias ____ToString___singularized = getSymbolsByUDA!(Self, Singular);

    struct BuilderImpl {
        pragma(msg, "Builder for ", Self);
        pragma(msg, ____ToString___fieldNames);
        mixin template HandleField(int handleField___i){
            static if (__traits(compiles, ____ToString___fieldNames.length) && handleField___i < ____ToString___fieldNames.length){
                mixin(
                    "private "~fullyQualifiedName!(____ToString___fieldTypes[handleField___i])~
                    " _dombok_builder_"~____ToString___fieldNames[handleField___i]~
                    " = "~fullyQualifiedName!(Self)~"()."~____ToString___fieldNames[handleField___i]~";"
                );
                mixin(fullyQualifiedName!(BuilderImpl)~" "~____ToString___fieldNames[handleField___i]~"("~fullyQualifiedName!(____ToString___fieldTypes[handleField___i])~" val){ this._dombok_builder_"~____ToString___fieldNames[handleField___i]~" = val; return this; }");
                mixin HandleField!(handleField___i+1);
            }
        }

        mixin HandleField!0;

        mixin template Handle____ToString___singularized(int handle____ToString___singularized___i){
            static if (__traits(compiles, ____ToString___singularized.length) && handle____ToString___singularized___i < ____ToString___singularized.length) {
                enum fieldName = ____ToString___singularized[handle____ToString___singularized___i].stringof;
                alias fieldType = typeof(____ToString___singularized[handle____ToString___singularized___i]);
                alias attr = getUDAs!(____ToString___singularized[handle____ToString___singularized___i], Singular);
                static assert(attr.length == 1);
                static if (!is(attr[0]: Singular))
                    enum declaredName = attr[0].singularName;
                else
                    enum declaredName = "";
                static if (empty(declaredName)) {
                    static  if (endsWith(fieldName, "ies")){
                        enum singularName = (fieldName[0..$-3] ~ "y");
                    } else static if (endsWith(fieldName, "s")) {
                        enum singularName = (fieldName[0..$-1]);
                    } else {
                        static assert(false);
                    }
                } else
                    enum singularName = declaredName;
                //fixme isSomeString!... instead of is(...: string)
                static if (!is(fieldType: string) && isArray!(fieldType)){
                    mixin(fullyQualifiedName!BuilderImpl~" "~singularName~"("~fullyQualifiedName!(ForeachType!fieldType)~" val){ this._dombok_builder_"~fieldName~" ~= val; return this; }");
                } else static if (isAssociativeArray!(fieldType)) {
                    mixin(fullyQualifiedName!BuilderImpl~" "~singularName~"("~fullyQualifiedName!(KeyType!fieldType)~" key, "~fullyQualifiedName!(ValueType!fieldType)~" val){ this._dombok_builder_"~fieldName~"[key] = val; return this; }");
                } else {
                    static assert(false);
                }
                mixin Handle____ToString___singularized!(handle____ToString___singularized___i+1);
            }
        }

        mixin Handle____ToString___singularized!0;

        Self build(){
            Self result = Self();
            foreach (fieldName; ____ToString___fieldNames)
                mixin("result."~fieldName~" = this._dombok_builder_"~fieldName~";");
            return result;
            //static if (__traits(compiles, ____ToString___fieldNames.length) && ____ToString___fieldNames.length > 0)
            //    enum constructorArgs = join(map!((string x) => "_dombok_builder_"~x)([____ToString___fieldNames]), ", ");
            //else
            //    enum constructorArgs = "";
            //mixin("return "~fullyQualifiedName!Self~"("~constructorArgs~");");
        }
    }

    static BuilderImpl builder(){
        return BuilderImpl();
    }
}

version(unittest){
    import dombok.builder.annotations;

    struct A {
        mixin Builder;

        int a;
        string b;
    }

    struct B {
        mixin Builder;

        int a;
        string b;
        @Singular
        int[] cs;
        @Singular
        string[bool] properties;
    }
}

unittest {
    A a = A.builder().a(1).b("x").build();
    assert(a == A(1, "x"));

    B b = B.builder().b("y").cs([2, 3]).build();
    assert(b == B(int.init, "y", [2, 3]));

    B b2 = B.builder().a(1).b("z").c(5).c(6).property(true, "yep").property(false, "nope").build();
    assert(b2 == B(1, "z", [5, 6], [true: "yep", false: "nope"]));
}