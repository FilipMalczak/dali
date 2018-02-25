module dali.proxy.impl;

import std.string;

template method(alias Scope, string methodName, ArgTypes...){
    import std.meta: AliasSeq;
    import std.traits: Parameters, ParameterIdentifierTuple, ReturnType;

    alias allMethodsWithThatName = AliasSeq!(__traits(getOverloads, Scope, methodName));

    template chooseMethod(int chooseMethod___i){
        static if (chooseMethod___i<allMethodsWithThatName.length){
            pragma(msg, "i ", chooseMethod___i);
            pragma(msg, "args ", ArgTypes);
            pragma(msg, "current ", Parameters!(allMethodsWithThatName[chooseMethod___i]));
            static if (is(Parameters!(allMethodsWithThatName[chooseMethod___i]) == AliasSeq!ArgTypes)){
                alias chooseMethod = allMethodsWithThatName[chooseMethod___i];
            } else {
                alias chooseMethod = chooseMethod!(chooseMethod___i+1);
            }
        } else {
            static assert(false);
        }
    }

    alias impl = chooseMethod!0;
    alias argNames = AliasSeq!(ParameterIdentifierTuple!impl);
    alias argTypes = AliasSeq!(Parameters!impl);

    mixin template assertNonEmptyNames() {
        mixin template assertNonEmptyNamesImpl(int i){
            static if (i < argNames.length){
                static assert(!empty(argNames[i]));
                mixin assertNonEmptyNamesImpl!(i+1);
            }
        }

        mixin assertNonEmptyNamesImpl!0;
    }

    alias returnType = ReturnType!impl;
}

import dali.tostring.annotations;
@(ToStringOptions.builder().fieldTypes(true).qualifiedFieldTypes(false).build())
struct Arguments(alias Scope, string methodName, ArgTypes...){
    import std.meta: Alias;
    import std.traits: isArray, isAssociativeArray, fullyQualifiedName;
    import dali.tostring.mixins;
    import dali.builder.annotations;
    import dali.builder.mixins;

    alias ____Proxy___targetMethod = method!(Scope, methodName, ArgTypes);

    mixin template InjectField(int injectField____i){
        static if (injectField____i < ____Proxy___targetMethod.argNames.length){
            enum toInject = fullyQualifiedName!(____Proxy___targetMethod.argTypes[injectField____i])~" "~____Proxy___targetMethod.argNames[injectField____i]~";";
            static if (isArray!(____Proxy___targetMethod.argTypes[injectField____i]) || isAssociativeArray!(____Proxy___targetMethod.argTypes[injectField____i]))
                mixin("@Singular "~toInject);
            else
                mixin(toInject);
            mixin InjectField!(injectField____i+1);
        }
    }

    mixin InjectField!0;

    mixin ToString;
    mixin Builder;
}

interface Interceptor(alias Clazz, string methodName, Args...){


    returnType intercept(Args args);
}

version(unittest){
    struct ToIntercept {
        void foo(int i){}

        string foo(){return "";}

        string foo(string x, bool b){return "";}
    }

    //class I1: Interceptor!(ToIntercept, "foo"){
    //    override void intercept(){}
    //}
    //class I2: Interceptor!(ToIntercept, "foo", string, bool){
    //    override string intercept(string s, bool b){
    //        return "";
    //    }
    //}

}

unittest {
    import std.stdio;
    writeln(Arguments!(ToIntercept, "foo").builder().build());
    writeln(Arguments!(ToIntercept, "foo", int).builder().build());
    writeln(Arguments!(ToIntercept, "foo", string, bool).builder().build());

}