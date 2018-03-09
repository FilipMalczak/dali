module dali.utils.typedescriptor;

import std.traits;

template parameterTypeMatcher(Types...){
    template Impl(M...) if (M.length==1) {
        enum Impl = is(Parameters!M == Types);
    }
    alias parameterTypeMatcher = Impl;
};

alias noParametersMatcher = parameterTypeMatcher!();

template isInstance(V...) if (V.length == 2) {
    enum isInstance = is(typeof(V[0]): V[1]);
}

import std.traits: hasUDA;
alias hasAnnotation = hasUDA;

template getAnnotation(A...) if (A.length == 2){
    import std.traits;
    import std.meta;
    alias all = getUDAs!(A[0], A[1]);
    static if (!__traits(compiles, all.length) || all.length == 0){
        static assert(false);
    } else {
        static assert(all.length == 1);
        static if (isInstance!(all[0], A[1]) || is(all[0] == enum))
            alias getAnnotation = all[0];
        else
            enum getAnnotation = A[1]();
    }
}

template MethodsWithName(T, string name){
    static if (is(T==struct)){
        import std.meta;
        static if (__traits(compiles, __traits(getOverloads, T, name)))
            alias MethodsWithName = AliasSeq!(__traits(getOverloads, T, name));
        else
            alias MethodsWithName = AliasSeq!();
    } else static if (is(T==class) || is(T==interface)) {
        import std.traits;
        alias MethodsWithName = MemberFunctionsTuple!(T, name);
    } else
        static assert(false);
}

struct Descriptor(T){
    import std.traits;
    import std.meta;
    import dali.utils.daliconstants;

    enum allFieldNames = [ FieldNameTuple!T ];
    alias allFieldTypes = Fields!T;

    enum fieldNames = [ Filter!(templateNot!IsDaliInternalField, aliasSeqOf!(allFieldNames)) ];
    alias fieldTypes = staticMap!(Descriptor!T.fieldType, aliasSeqOf!fieldNames);

    enum name = fullyQualifiedName!T;
    enum shortName = __traits(identifier, T);

    template getOptions(Opt){
        alias allOptions = getUDAs!(T, Opt);
        static assert (__traits(compiles, allOptions.length) && allOptions.length < 2);
        static if (__traits(compiles, allOptions.length) && allOptions.length == 1 && isInstance!(allOptions[0], Opt)) {
            enum getOptions = allOptions[0];
        } else {
            enum getOptions = Opt();
        }
    }

    template annotatedFieldNames(Ann){
        enum matcher(string fieldName) = hasAnnotation!(mixin(fullyQualifiedName!T~"."~fieldName), Ann);
        alias annotatedFieldNames = Filter!(matcher, aliasSeqOf!fieldNames);
    }

    template annotatedFieldTypes(Ann){
        alias annotatedFieldTypes = staticMap!(Descriptor!T.fieldType, annotatedFieldNames!Ann);
    }

    template fieldType(string fieldName){
        template Impl(size_t i){
            static if (i < allFieldNames.length){
                static if (allFieldNames[i] == fieldName)
                    alias Impl = allFieldTypes[i];
                else
                    alias Impl = Impl!(i+1);
            } else
                static assert(false);
        }
        alias fieldType = Impl!0;
    }

    enum hasAnnotatedMethod(Ann) = __traits(compiles, getSymbolsByUDA!(T, Ann).length) && getSymbolsByUDA!(T, Ann).length > 0;

    template annotatedMethod(Ann){
        import std.traits;
        alias allAnnotated = getSymbolsByUDA!(T, Ann);
        static assert(__traits(compiles, allAnnotated.length));
        static assert(allAnnotated.length == 1);
        enum annotatedMethod = MethodDescriptor!(T, __traits(identifier, allAnnotated[0]), Parameters!(allAnnotated[0]))();
    }

    template methods(string name){
        import std.traits;
        //todo: map to MethodDescriptor
        alias methods = AliasSeq!(__traits(getOverloads, T, name));
    }

    template method(string name){
        alias allNamed = methods!name;
        static assert(allNamed.length == 1);
        enum annotatedMethod = MethodDescriptor!(T, __traits(identifier, allNamed[0]), Parameters!(allNamed[0]))();
    }



}

struct ConstructorDescriptor(T, ArgTypes...){
    template exists(){
        ArgTypes a;
        static if (is(T == class)){
            enum exists = __traits(compiles, new T(a));
        } else static if (is(T == struct)) {
            enum exists = __traits(compiles, T(a));
        } else
            static assert(false);
    }

    static T call(ArgTypes args){
        static if (is(T==class)){
            return new T(args);
        } else {
            return T(args);
        }
    }

    alias argTypes = ArgTypes;
    alias returnType = T;
}

struct MethodDescriptor(T, string methodName, ArgTypes...) {
    import std.traits;
    import std.meta;
    import std.range;
    import std.array;

    alias targetMethod = MethodDescriptor!(T, methodName, ArgTypes).getTargetMethod!();

    enum name = methodName;
    enum mangledName = std.traits.mangledName!(targetMethod);

    template forObject(alias t){
        alias filtered = Filter!(parameterTypeMatcher!ArgTypes, __traits(getOverloads, t, methodName));
        //alias filtered = Filter!(parameterTypeMatcher!ArgTypes, __traits(getOverloads, t, methodName));
        static assert(__traits(compiles, filtered.length) && filtered.length == 1);
        alias forObject = filtered[0];
    }

    alias returnType = ReturnType!targetMethod;

    template getTargetMethod(){
        import std.meta;
        alias allMethods = NoDuplicates!(AliasSeq!(AliasSeq!(__traits(getOverloads, T, methodName)), MethodsWithName!(T, methodName)));
        alias withSignature = Filter!(parameterTypeMatcher!ArgTypes, allMethods);
        static if (withSignature.length == 1)
            alias getTargetMethod = withSignature[0];
        else
            static assert(false);
    }

    enum argNames = [ ParameterIdentifierTuple!targetMethod ];
    alias argTypes = AliasSeq!(ArgTypes);

    enum declaration = fullyQualifiedName!(returnType)~" "~methodName~"("~typedParameterList~")";

    enum typedParam(size_t i) = fullyQualifiedName!(argTypes[i])~" "~argNames[i];

    enum typedParameterList = join(cast(string[]) [staticMap!(typedParam, aliasSeqOf!(iota(argNames.length)))], ", ");

    enum paramNameList = join(cast(string[]) argNames, ", ");
    enum paramTypeList = join(cast(string[]) [staticMap!(fullyQualifiedName, argTypes)], ", ");

    enum isProperty = functionAttributes!targetMethod & FunctionAttribute.property;
}

mixin template forEachMethodMixin(T, alias ToMixinWithDescriptor) {
    import std.traits;
    import std.meta;
    static if (is(T == struct) || is(T == class)){
        enum allMembers = [__traits(allMembers, T)];
        mixin template _forEachImpl(size_t ___i){
            static if (___i < allMembers.length){
                enum member = allMembers[___i];
                static if (__traits(compiles, __traits(getOverloads, T, member))){
                    import std.traits;
                    import std.meta;
                    alias overloads = MethodsWithName!(T, member);
                    //alias overloads = AliasSeq!(__traits(getOverloads, T, member));
                    mixin template _iterOverloads(size_t ___j){
                        static if (___j < overloads.length){
                            alias desc = MethodDescriptor!(T, member, Parameters!(overloads[___j]));
                            //alias desc = MethodDescriptor!(T, __traits(identifier, overloads[___j]), Parameters!(overloads[___j]));
                            static if (!desc.isProperty)
                                mixin ToMixinWithDescriptor!(desc);
                            mixin _iterOverloads!(___j+1);
                        }
                    }
                    mixin _iterOverloads!0;
                }
                mixin _forEachImpl!(___i+1);
            }
        }
        mixin _forEachImpl!(0);
    } else
        static assert(false);
}


/**
 * Callable both compile- and runtime. Compile-time is supported as long as Callback is callable in compile time.
 * T - type to "browse"
 * Acc - accumulator type
 * Callback - template that takes 1 template parameter - MethodDescriptor type and 1 function parameter of type Acc, returning Acc;
 *
 * In pseudocode this methods works as:
 * result = emptyAccumulator;
 * for each method in T:
 *      result = Callback!(MethodDescriptor!(method))(result);
 * return result;
 */
Acc foldMethods(T, alias Callback, Acc)(Acc emptyAccumulator) if (is(T == struct) || is(T == class)) {
    enum allMembers = [__traits(allMembers, T)];

    import std.traits;
    import std.meta;
    Acc result = emptyAccumulator;
    enum limit = 0;

    static foreach (member; allMembers) {
        static if (__traits(compiles, __traits(getOverloads, T, member))){
            import std.traits;
            import std.meta;
            //static foreach (i; 0..AliasSeq!(__traits(getOverloads, T, member)).length) {
            static foreach (i; 0..MethodsWithName!(T, member).length) {
                //static if (!MethodDescriptor!(T, __traits(identifier, AliasSeq!(__traits(getOverloads, T, member))[i]), Parameters!(AliasSeq!(__traits(getOverloads, T, member))[i])).isProperty) {
                static if (!MethodDescriptor!(T, member, Parameters!(MethodsWithName!(T, member)[i])).isProperty) {
                    result = Callback!(
                        //MethodDescriptor!(T, __traits(identifier, AliasSeq!(__traits(getOverloads, T, member))[i]), Parameters!(AliasSeq!(__traits(getOverloads, T, member))[i]))
                        MethodDescriptor!(T, member, Parameters!(MethodsWithName!(T, member)[i]))
                    )(result);
                }
            }
        }
    }
    return result;
}

/**
 * This covers both property methods and public fields.
 */
mixin template forEachPropertyMixin(T, alias ToMixinWithTypeNameSetterGetter) if (is(T == struct) || is(T == class)){
    import std.traits;
    import std.meta;

    enum allMembers = [__traits(allMembers, T)];

    mixin template _forEachPropertyImpl(size_t ___i){
        static if (___i < allMembers.length){
            enum member = allMembers[___i];
            static if (__traits(compiles, __traits(getOverloads, T, member))){
                import std.traits;
                import std.meta;
                alias overloads = AliasSeq!(__traits(getOverloads, T, member));
                mixin template _iterOverloads(size_t ___j){
                    static if (___j < overloads.length){
                        alias desc = MethodDescriptor!(T, __traits(identifier, overloads[___j]), Parameters!(overloads[___j]));
                        static if (desc.isProperty) {
                            static if (desc.argNames.length == 0)
                                mixin ToMixinWithTypeNameSetterGetter!(desc.returnType, desc.name, false, true);
                            else {
                                static assert(desc.argNames.length == 1);
                                mixin ToMixinWithTypeNameSetterGetter!(desc.argTypes[0], desc.name, true, false);
                            }
                        }
                        mixin _iterOverloads!(___j+1);
                    }
                }
                mixin _iterOverloads!0;
            }
            mixin _forEachPropertyImpl!(___i+1);
        }
    }

    mixin template _forEachFieldImpl(size_t ___i){
        static if (___i < allMembers.length){
            enum member = allMembers[___i];
            static if (!__traits(compiles, __traits(getOverloads, T, member))){
                import std.traits;
                import std.meta;

                mixin ToMixinWithTypeNameSetterGetter!(desc.argTypes[0], member, true, true);
            }
            mixin _forEachFieldImpl!(___i+1);
        }
    }

    mixin _forEachPropertyImpl!(0);
    mixin _forEachFieldImpl!(0);
}

version(unittest){
    // foldMethods and forEachMethodMixin are tested by declaring several prepared types to analyse
    // then few usages of these methods.
    // foldMethods is used to implement collectDeclarations which returns list of method declarations as string
    // forEachMethodMixin is used to prepare <typeName>Methods structs (like StructToAnalyseMethods) which have fields
    //      with random-ish names and methods declarations as values

    struct StructToAnalyse {
        int x;
        string y;

        @property
        int foo(){return 2*x;}
        @property
        void bar(double x){}

        @property
        string baz(){return y;}
        @property
        void baz(string y){
            this.y = y;
        }

        void voidNoArgs(){}
        void voidInt(int x){}
        void voidIntString(int x, string y){}

        int intNoArgs(){ return 1; }
        string stringInt(int x){return "";}
        double doubleStringInt(string x, int y){ return 0; }

        int overloaded(){return 0;}
        string overloaded(int x){return "";}
    }

    class ClassToAnalyse {
        int x;
        string y;

        @property
        int foo(){return 2*x;}
        @property
        void bar(double x){}

        @property
        string baz(){return y;}
        @property
        void baz(string y){
            this.y = y;
        }

        void voidNoArgs(){}
        void voidInt(int x){}
        void voidIntString(int x, string y){}

        int intNoArgs(){ return 1; }
        string stringInt(int x){return "";}
        double doubleStringInt(string x, int y){ return 0; }

        int overloaded(){return 0;}
        string overloaded(int x){return "";}
    }

    //todo: see what happens when we do inheritance
    class EmptySubClassToAnalyse: ClassToAnalyse {}

    class OverridingSubClassToAnalyse: ClassToAnalyse {
        override int overloaded() { return 1; }
    }

    class OverloadingSubClassToAnalyse: ClassToAnalyse {
        double overloaded(string y){return 0;}
    }

    class IntroducingSubClassToAnalyse: ClassToAnalyse {
        string[] stringArrNoArgs(){return [];}
    }

    string[] pushDeclaration(alias desc)(string[] acc){
        acc ~= desc.declaration;
        return acc;
    }

    string[] collectDeclarations(T)(){
        return foldMethods!(T, pushDeclaration, string[])([]);
    }

    enum GeneratedForTesting;

    mixin template ToStringField(alias desc){
        import std.conv;
        mixin("@GeneratedForTesting string "~desc.name~to!string(hashOf(desc.declaration))~" = \""~desc.declaration~"\";");
    }

    struct StructToAnalyseMethods {
        mixin forEachMethodMixin!(StructToAnalyse, ToStringField);
    }

    struct ClassToAnalyseMethods {
        mixin forEachMethodMixin!(ClassToAnalyse, ToStringField);
    }

    struct EmptySubClassToAnalyseMethods {
        mixin forEachMethodMixin!(EmptySubClassToAnalyse, ToStringField);
    }

    struct OverridingSubClassToAnalyseMethods {
        mixin forEachMethodMixin!(OverridingSubClassToAnalyse, ToStringField);
    }

    struct OverloadingSubClassToAnalyseMethods {
        mixin forEachMethodMixin!(OverloadingSubClassToAnalyse, ToStringField);
    }

    struct IntroducingSubClassToAnalyseMethods {
        mixin forEachMethodMixin!(IntroducingSubClassToAnalyse, ToStringField);
    }

    enum StructToAnalyseMethodsInstance = StructToAnalyseMethods();
    enum ClassToAnalyseMethodsInstance = ClassToAnalyseMethods();
    enum EmptySubClassToAnalyseMethodsInstance = EmptySubClassToAnalyseMethods();
    enum OverridingSubClassToAnalyseMethodsInstance = OverridingSubClassToAnalyseMethods();
    enum OverloadingSubClassToAnalyseMethodsInstance = OverloadingSubClassToAnalyseMethods();
    enum IntroducingSubClassToAnalyseMethodsInstance = IntroducingSubClassToAnalyseMethods();

    enum expectedStructDeclarations = [
         "void voidNoArgs()", "void voidInt(int x)", "void voidIntString(int x, string y)",
         "int intNoArgs()", "string stringInt(int x)", "double doubleStringInt(string x, int y)",
         "int overloaded()", "string overloaded(int x)"
    ];

    enum expectedClassDeclarations = [
         "void voidNoArgs()", "void voidInt(int x)", "void voidIntString(int x, string y)",
         "int intNoArgs()", "string stringInt(int x)", "double doubleStringInt(string x, int y)",
         "int overloaded()", "string overloaded(int x)",
         "string toString()",
         fullyQualifiedName!size_t~" toHash()", "int opCmp(object.Object o)", "bool opEquals(object.Object o)"
    ];
}
//
unittest {
    import std.algorithm.comparison;
    string[] fieldVals;

    // for struct:

    // check collected declarations to see if foldMethod works
    static assert(isPermutation(collectDeclarations!StructToAnalyse(), expectedStructDeclarations));

    // check values of generated fields to see if forEachMethodMixin works
    fieldVals = [];
    static foreach (fieldName; Descriptor!StructToAnalyseMethods.annotatedFieldNames!(GeneratedForTesting)){
        fieldVals ~= mixin("StructToAnalyseMethodsInstance."~fieldName);
    }
    assert(isPermutation(fieldVals, expectedStructDeclarations));

    // for base class:
    // check collected declarations to see if foldMethod works
    static assert(isPermutation(collectDeclarations!ClassToAnalyse(), expectedClassDeclarations));
    fieldVals = [];
    static foreach (fieldName; Descriptor!ClassToAnalyseMethods.annotatedFieldNames!(GeneratedForTesting)){
        fieldVals ~= mixin("ClassToAnalyseMethodsInstance."~fieldName);
    }
    assert(isPermutation(fieldVals, expectedClassDeclarations));

    // for empty subclass everything should work the same way as for superclass
    static assert(isPermutation(collectDeclarations!EmptySubClassToAnalyse(), expectedClassDeclarations));
    fieldVals = [];
    static foreach (fieldName; Descriptor!EmptySubClassToAnalyseMethods.annotatedFieldNames!(GeneratedForTesting)){
        fieldVals ~= mixin("EmptySubClassToAnalyseMethodsInstance."~fieldName);
    }
    assert(isPermutation(fieldVals, expectedClassDeclarations));

    // for override-only subclass everything should work the same way as for superclass
    static assert(isPermutation(collectDeclarations!OverridingSubClassToAnalyse(), expectedClassDeclarations));
    fieldVals = [];
    static foreach (fieldName; Descriptor!OverridingSubClassToAnalyseMethods.annotatedFieldNames!(GeneratedForTesting)){
        fieldVals ~= mixin("OverridingSubClassToAnalyseMethodsInstance."~fieldName);
    }
    assert(isPermutation(fieldVals, expectedClassDeclarations));

    // overloading should introudce new method
    static assert(isPermutation(collectDeclarations!OverloadingSubClassToAnalyse(), expectedClassDeclarations ~ [ "double overloaded(string y)" ]));
    fieldVals = [];
    static foreach (fieldName; Descriptor!OverloadingSubClassToAnalyseMethods.annotatedFieldNames!(GeneratedForTesting)){
        fieldVals ~= mixin("OverloadingSubClassToAnalyseMethodsInstance."~fieldName);
    }
    assert(isPermutation(fieldVals, expectedClassDeclarations ~ [ "double overloaded(string y)" ]));

    // introducing should introudce new method
    static assert(isPermutation(collectDeclarations!IntroducingSubClassToAnalyse(), expectedClassDeclarations ~ [ "string[] stringArrNoArgs()" ]));
    fieldVals = [];
    static foreach (fieldName; Descriptor!IntroducingSubClassToAnalyseMethods.annotatedFieldNames!(GeneratedForTesting)){
        fieldVals ~= mixin("IntroducingSubClassToAnalyseMethodsInstance."~fieldName);
    }
    assert(isPermutation(fieldVals, expectedClassDeclarations ~ [ "string[] stringArrNoArgs()" ]));
}