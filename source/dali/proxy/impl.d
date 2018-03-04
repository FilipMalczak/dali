module dombok.proxy.impl;

import std.string;


import dali.tostring.annotations;
@(ToStringOptions.builder().fieldTypes(true).qualifiedFieldTypes(false).build())
struct Arguments(alias Scope, string methodName, ArgTypes...){
    import std.meta: Alias;
    import std.traits: isArray, isAssociativeArray, fullyQualifiedName;
    import dali.tostring.mixins;
    import dali.builder.annotations;
    import dali.builder.mixins;
    import dali.wither.mixins;
    import dali.constructors.mixins;

    alias targetMethod = MethodDescriptor!(Scope, methodName, ArgTypes);

    mixin template InjectField(int ___i){
        static if (___i < targetMethod.argNames.length){
            enum toInject = fullyQualifiedName!(targetMethod.argTypes[___i])~" "~targetMethod.argNames[___i]~";";
            static if (isArray!(targetMethod.argTypes[___i]) || isAssociativeArray!(targetMethod.argTypes[___i]))
                mixin("@Singular "~toInject);
            else
                mixin(toInject);
            mixin InjectField!(___i+1);
        }
    }

    mixin InjectField!0;

    mixin ToString;
    mixin Builder;
    //mixin AllArgsConstructor;
}

import std.traits;
import dali.utils.typedescriptor;

template InterceptorChain(Target, string methodName, ArgTypes...){
    alias InterceptorChain = MethodDescriptor!(Target, methodName, ArgTypes).returnType delegate(Arguments!(Target, methodName, ArgTypes));
}

InterceptorChain!(Target, methodName, ArgTypes) bindMethodWithObject(alias Target, string methodName, ArgTypes...)(Target obj){
    import std.algorithm.iteration;
    mixin("return (a) => obj."~methodName~"("~join(map!((n) => "a."~n)(MethodDescriptor!(Target, methodName, ArgTypes).argNames), ", ")~");");
}

template pushInterceptor(alias Target, string methodName, ArgTypes...){
    InterceptorChain!(Target, methodName, ArgTypes) pushInterceptor(InterceptorChain!(Target, methodName, ArgTypes) chain, Interceptor!(Target, methodName, ArgTypes) interceptor){
        return (a) => interceptor.intercept(chain, a);
    }
}

interface Interceptor(alias Target, string methodName, ArgTypes...){
    alias Chain = InterceptorChain!(Target, methodName, ArgTypes);
    alias Args = Arguments!(Target, methodName, ArgTypes);
    alias ResultType = MethodDescriptor!(Target, methodName, ArgTypes).returnType;

    ResultType intercept(ResultType delegate(Args) interceptorChainTail, Args args);
}

version(unittest){

    struct StructToIntercept {
        void foo(int i){}

        string foo(){return "1";}

        string foo(string x, bool b){return x~(b? "T":"F")~"2";}
    }

    class PrefixingInterceptor: Interceptor!(StructToIntercept, "foo", string, bool) {
        import dali.constructors.mixins;

        string intercept(InterceptorChain!(StructToIntercept, "foo", string, bool) chain, Arguments!(StructToIntercept, "foo", string, bool) args){
            args.x = "_paramPrefix_"~args.x;
            return "_resultPrefix::"~chain(args);
        }

        //mixin NoArgsConstructor;
    }
}

unittest {
    import std.stdio;

    auto args = Arguments!(StructToIntercept, "foo", string, bool)("a", 1);
    auto adapted = bindMethodWithObject!(StructToIntercept, "foo", string, bool)(StructToIntercept());
    assert(adapted(args) == "aT2");

    PrefixingInterceptor interceptor = new PrefixingInterceptor();
    auto intercepted = pushInterceptor!(StructToIntercept, "foo", string, bool)(adapted, interceptor);
    assert(intercepted(args) == "_resultPrefix::_paramPrefix_aT2");
}