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

    mixin template forEachMethod(alias ToMixinWithDescriptor) {
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
                        alias overloads = AliasSeq!(__traits(getOverloads, T, member));
                        mixin template _iterOverloads(size_t ___j){
                            static if (___j < overloads.length){
                                alias desc = MethodDescriptor!(T, __traits(identifier, overloads[___j]), Parameters!(overloads[___j]));
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
}


struct MethodDescriptor(T, string methodName, ArgTypes...) {
    import std.traits;
    import std.meta;
    import std.range;
    import std.array;

    alias name = methodName;

    alias targetMethod = MethodDescriptor!(T, methodName, ArgTypes).getTargetMethod!();

    template forObject(alias t){
        alias filtered = Filter!(parameterTypeMatcher!ArgTypes, __traits(getOverloads, t, methodName));
        static assert(__traits(compiles, filtered.length) && filtered.length == 1);
        alias forObject = filtered[0];
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

    enum declaration = fullyQualifiedName!(returnType)~" "~methodName~"("~typedParameterList~")";

    enum _typedParam(size_t i) = fullyQualifiedName!(argTypes[i])~" "~argNames[i];

    enum typedParameterList = join(cast(string[]) [staticMap!(_typedParam, aliasSeqOf!(iota(argNames.length)))], ", ");

    enum paramNameList = join(cast(string[]) argNames, ", ");
    enum paramTypeList = join(cast(string[]) [staticMap!(fullyQualifiedName, argTypes)], ", ");
}