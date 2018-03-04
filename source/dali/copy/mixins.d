module dali.copy.mixins;

mixin template Copy() {
    import dali.copy.api;

    alias Self = typeof(this);

    static if (is(Self == struct)) {
        private CopyableStruct!Self ___dali_Copy_supertype = CopyableStruct!Self();
        alias ___dali_Copy_supertype this;

        Self copy(){
            //structs have value semantics and are kept on stack - assigning to a new var effectively creates a copy
            return this;
        }
    } else static if (is(Self == class)) {
        import std.meta;
        import std.traits;
        import dali.copy.annotations;
        static if (!is(Self: Copyable!Self)) { //todo: look for already existing alias this
            private Copyable!Self ___dali_Copy_supertype = new CopyableClass!Self();
            alias ___dali_Copy_supertype this;

        }

        Self copy(){
            import dali.utils.daliconstants;
            import dali.utils.typedescriptor;
            import std.meta;
            static if (__traits(compiles, new Self())) {
                Self result = new Self();
            } else {
                alias factory = Descriptor!Self.annotatedMethod!CopyFactory;
                Self result = factory.targetMethod();
            }
            static foreach (name; Filter!(templateNot!IsDaliInternalField, FieldNameTuple!Self)) {
                mixin("result."~name~" = this."~name~";");
            }
            return result;
        }

    } else
        static assert(false); //todo: better exception



}

version (unittest){
    import dali.copy.api;
    import dali.copy.annotations;
    import dali.tostring.mixins;

    class A: Copyable!A {
        mixin Copy;
        mixin ToString;

        int x;
        string y;
        int[] arr;
    }

    class B: Copyable!B {
        mixin Copy;
        mixin ToString;

        int x;
        string y;
        int[] arr;

        this(){
            x = 2;
        }
    }

    class C: Copyable!C {
        mixin Copy;
        mixin ToString;

        int x;
        string y;
        int[] arr;

        this(int x){this.x = x;}

        @CopyFactory
        static C foo(){
            return new C(int.init);
        }
    }

}

unittest {
    import std.stdio;

    A a1 = new A();
    A b1 = a1.copy();
    a1.x = 3;
    assert(b1.x == 0);

    B a2 = new B();
    B b2 = a2.copy();
    a2.x = 3;
    assert(b2.x == 2);

    C a3 = new C(5);
    C b3 = a3.copy();
    a3.x = 3;
    assert(b3.x == 5);

}

