module dali.builder.mixins;

mixin template Builder() {
    import std.traits;
    import std.meta;
    import std.array;
    import std.string;
    import std.algorithm.iteration;
    import std.algorithm.searching;
    import dali.builder.annotations;

    alias Self = typeof(this);

    //todo introduce class support
    static assert(is(Self == struct));

    alias ____Builder___fieldNames = FieldNameTuple!Self;
    alias ____Builder___fieldTypes = Fields!Self;
    alias ____Builder___singularized = getSymbolsByUDA!(Self, Singular);

    struct BuilderImpl {
        mixin template ___Builder___HandleField(int ___i){
            static if (__traits(compiles, ____Builder___fieldNames.length) && ___i < ____Builder___fieldNames.length){
                mixin(
                    "private "~fullyQualifiedName!(____Builder___fieldTypes[___i])~
                    " _dali_builder_"~____Builder___fieldNames[___i]~";"
                );
                mixin(fullyQualifiedName!(BuilderImpl)~" "~____Builder___fieldNames[___i]~"("~fullyQualifiedName!(____Builder___fieldTypes[___i])~" val){ this._dali_builder_"~____Builder___fieldNames[___i]~" = val; return this; }");
                mixin ___Builder___HandleField!(___i+1);
            }
        }

        mixin ___Builder___HandleField!0;

        mixin template ___Builder___HandleSingular(int ___j){
            static if (__traits(compiles, ____Builder___singularized.length) && ___j < ____Builder___singularized.length) {
                enum fieldName = ____Builder___singularized[___j].stringof;
                alias fieldType = typeof(____Builder___singularized[___j]);
                alias attr = getUDAs!(____Builder___singularized[___j], Singular);
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
                //todo support std.container
                //fixme isSomeString!... instead of is(...: string)
                static if (!is(fieldType: string) && isArray!(fieldType)){
                    mixin(
                        fullyQualifiedName!BuilderImpl~" "~singularName~"("~fullyQualifiedName!(ForeachType!fieldType)~" val){ "~
                            "this._dali_builder_"~fieldName~" ~= val; "~
                            "return this; "~
                        "}"
                    );
                } else static if (isAssociativeArray!(fieldType)) {
                    mixin(
                        fullyQualifiedName!BuilderImpl~" "~singularName~"("~fullyQualifiedName!(KeyType!fieldType)~" key, "~fullyQualifiedName!(ValueType!fieldType)~" val){ "~
                            "this._dali_builder_"~fieldName~"[key] = val; "~
                            "return this; "~
                        "}"
                    );
                } else {
                    static assert(false);
                }
                mixin ___Builder___HandleSingular!(___j+1);
            }
        }

        mixin ___Builder___HandleSingular!0;

        this(Self prototype){
            foreach (fieldName; ____Builder___fieldNames)
                mixin("this._dali_builder_"~fieldName~" = prototype."~fieldName~";");
        }

        Self build(){
            Self result = Self();
            foreach (fieldName; ____Builder___fieldNames)
                mixin("result."~fieldName~" = this._dali_builder_"~fieldName~";");
            return result;
        }
    }

    BuilderImpl toBuilder(){
        return BuilderImpl(this);
    }

    static BuilderImpl builder(){
        return Self().toBuilder();
    }
}

version(unittest){
    import dali.builder.annotations;

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

    struct C {
        mixin Builder;

        int a = 2;
        string b = "foobar";
    }
}

unittest {
    A a = A.builder().a(1).b("x").build();
    assert(a == A(1, "x"));

    assert(a.toBuilder().b("z").build() == A(1, "z"));

    B b = B.builder().b("y").cs([2, 3]).build();
    assert(b == B(int.init, "y", [2, 3]));

    B b2 = B.builder().a(1).b("z").c(5).c(6).property(true, "yep").property(false, "nope").build();
    assert(b2 == B(1, "z", [5, 6], [true: "yep", false: "nope"]));

    assert(C.builder().build() == C());
    assert(C.builder().build() == C(2, "foobar"));
}