module dombok.proxy.impl;

import std.string;


import dali.tostring.annotations;
@(ToStringOptions.builder().fieldTypes(true).qualifiedFieldTypes(false).build())
struct Arguments(alias Scope, string methodName, ArgTypes...) if (!MethodDescriptor!(Scope, methodName, ArgTypes).isProperty){
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
    //mixin AllArgsConstructor; //todo
}

import std.traits;
import dali.utils.typedescriptor;

template InterceptorChain(Target, string methodName, ArgTypes...){
    import std.meta;
    alias InterceptorChain = Alias!(MethodDescriptor!(Target, methodName, ArgTypes).returnType delegate(Arguments!(Target, methodName, ArgTypes)));
}

InterceptorChain!(Target, methodName, ArgTypes) bindMethodWithObject(Target, string methodName, ArgTypes...)(Target obj) if (!MethodDescriptor!(Target, methodName, ArgTypes).isProperty){
    import std.algorithm.iteration;
    alias argsType = Arguments!(Target, methodName, ArgTypes);
    mixin("return ("~fullyQualifiedName!(argsType)~" a) => obj."~methodName~"("~join(map!((n) => "a."~n)(cast(string[]) MethodDescriptor!(Target, methodName, ArgTypes).argNames), ", ")~");");
}

//this is here because the compiler seems to complain if  for no-arg method - it looks for pushInterceptor!(T, m) and can't
//match empty varargs template argument, so we manually tell it that in such case pushInterceptor!(T, m) = pushInterceptor!(T, m, [])
InterceptorChain!(Target, methodName)
    pushInterceptor(Target, string methodName)(
        InterceptorChain!(Target, methodName) chain,
        Interceptor!(Target, methodName) interceptor
    ) if (!MethodDescriptor!(Target, methodName, AliasSeq!()).isProperty){
    import std.meta;
    return pushInterceptor!(Target, methodName, AliasSeq!())(chain, interceptor);
}

//todo: understand why commented lines won't work, while uncommented work perfectly oO and why the hell it works above? oO

MethodDescriptor!(Target, methodName, ArgTypes).returnType delegate(Arguments!(Target, methodName, ArgTypes))
//MethodDescriptor!(Target, methodName, ArgTypes).returnType delegate(Arguments!(Target, methodName, ArgTypes))
    pushInterceptor(Target, string methodName, ArgTypes...) (
        //InterceptorChain!(Target, methodName) chain,
        MethodDescriptor!(Target, methodName, ArgTypes).returnType delegate(Arguments!(Target, methodName, ArgTypes)) chain,
        Interceptor!(Target, methodName, ArgTypes) interceptor
    ) if (!MethodDescriptor!(Target, methodName, ArgTypes).isProperty){
    return (Arguments!(Target, methodName, ArgTypes) a) => interceptor.intercept(chain, a);
}

interface Interceptor(Target, string methodName, ArgTypes...) if (!MethodDescriptor!(Target, methodName, ArgTypes).isProperty){
    alias Chain = InterceptorChain!(Target, methodName, ArgTypes);
    alias Args = Arguments!(Target, methodName, ArgTypes);
    alias ResultType = MethodDescriptor!(Target, methodName, ArgTypes).returnType;

    ResultType intercept(Chain interceptorChainTail, Args args);
}

version(unittest){

    struct StructToIntercept {
        private int x;

        void foo(int i){}

        string foo(){
            import std.conv;
            return "1"~to!string(x);
        }

        string foo(string x, bool b){return x~(b? "T":"F")~"2";}
    }

    class PrefixingInterceptor: Interceptor!(StructToIntercept, "foo", string, bool) {
        import dali.constructors.mixins;

        string intercept(InterceptorChain!(StructToIntercept, "foo", string, bool) chain, Arguments!(StructToIntercept, "foo", string, bool) args){
            args.x = "_paramPrefix_"~args.x;
            return "_resultPrefix::"~chain(args);
        }

        //mixin NoArgsConstructor; //todo
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

struct Interceptors(T){
    alias descriptor = Descriptor!T;

    private void[][string] backend;

    void add(string methodName, ArgTypes...)(Interceptor!(T, methodName, ArgTypes) interceptor){
        auto mangled = mangledName!(MethodDescriptor!(T, methodName, ArgTypes).targetMethod);
        if ((mangled in backend)==null)
            backend[mangled] = [];
        backend[mangled] ~= [ interceptor ];
    }

    Interceptor!(T, methodName, ArgTypes)[] registered(string methodName, ArgTypes...)() if (!MethodDescriptor!(T, methodName, ArgTypes).isProperty){
        import std.conv;
        auto mangled = mangledName!(MethodDescriptor!(T, methodName, ArgTypes).targetMethod);
        if ((mangled in backend)==null)
            return [];
        return cast(Interceptor!(T, methodName, ArgTypes)[]) (backend[mangled]);
    }
}

mixin template _ProxyBody(T) {
    private T ___dali_proxy_target;

    Interceptors!(T) interceptors;

    private MethodDescriptor!(T, name, Args).returnType ___dali_proxy_dispatch(string name, Args...)(Args args){
        auto chainEnd = bindMethodWithObject!(T, name, Args)(___dali_proxy_target);
        auto chainHead = chainEnd;
        foreach (interceptor; interceptors.registered!(name, Args)())
            chainHead = pushInterceptor!(T, name, Args)(
                cast(InterceptorChain!(T, name, Args)) chainHead,
                //cast(MethodDescriptor!(T, name, Args).returnType delegate(Arguments!(T, name, Args))) chainHead,
                cast(Interceptor!(T, name, Args)) interceptor
            );
        static if (is(MethodDescriptor!(T, name, Args).returnType == void)){
            chainHead(Arguments!(T, name, Args)(args));
        } else {
            return chainHead(Arguments!(T, name, Args)(args));
        }
    }

    private mixin template _methodBody(alias desc){
        static if (!desc.isProperty) {
            static if (is(desc.returnType == void)){
                mixin(desc.declaration~" { ___dali_proxy_dispatch!(\""~desc.name~"\", "~desc.paramTypeList~")("~desc.paramNameList~"); }");
            } else {
                mixin(desc.declaration~" { return ___dali_proxy_dispatch!(\""~desc.name~"\", "~desc.paramTypeList~")("~desc.paramNameList~"); }");
            }
        }
    }

    mixin forEachMethodMixin!(T, _methodBody);
}

template Proxy(T){
    //todo: add constructor interceptors

    //todo: wrap fields with properties
    //todo: check how properties work
    //todo: wrap it up, make sure that we have property interceptors that work both on fields and properties
    static if (is(T == class)){
        class Proxy {
            mixin _ProxyBody!T;

            this(A...)(A args) if (__traits(compiles, new T(args))) {
                ___dali_proxy_target = new T(args);
            }
        }
    } else static if (is(T == struct)){
        struct Proxy {
            mixin _ProxyBody!T;

            this(A...)(A args) if (__traits(compiles, T(args))) {
                ___dali_proxy_target = T(args);
            }
        }
    } else {
        static assert(false);
    }
}

unittest {
    auto intercepted = Proxy!(StructToIntercept)(2);
    intercepted.interceptors.add(new PrefixingInterceptor());
    assert(intercepted.foo("a", 1) == "_resultPrefix::_paramPrefix_aT2");
    assert(intercepted.foo() == "12");
}