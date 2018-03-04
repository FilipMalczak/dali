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
        enum matcher(string fieldName) = hasAnnotation!(mixin("this."~fieldName), Ann);
        alias annotatedFieldNames = Filter!(matcher, fieldNames);
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

    template constructors(){
        //alias constructors = methods!"__ctor";
        alias constructors = methods!"this";
    }

    //enum allArgsConstructor = Select!(__traits(compiles, MethodDescriptor!(T, "__ctor", fieldTypes)), MethodDescriptor!(T, "__ctor", fieldTypes), void);
}

struct MethodDescriptor(T, string methodName, ArgTypes...) {
    import std.traits;
    import std.meta;

    alias targetMethod = MethodDescriptor!(T, methodName, ArgTypes).getTargetMethod!();

    template forObject(alias t){
        alias forObject = Filter!(parameterTypeMatcher!ArgTypes, __traits(getOverloads, t, methodName))[0];
    }

    alias returnType = ReturnType!targetMethod;

    template getTargetMethod(){
        alias allMethods = AliasSeq!(__traits(getOverloads, T, methodName));

        alias withSignature = Filter!(parameterTypeMatcher!ArgTypes, allMethods);
        static assert(withSignature.length == 1);
        alias getTargetMethod = withSignature[0];
    }

    enum argNames = [ ParameterIdentifierTuple!targetMethod ];
    alias argTypes = Parameters!targetMethod;
}