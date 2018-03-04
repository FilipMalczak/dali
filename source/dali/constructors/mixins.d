module dali.constructors.mixins;

mixin template NoArgsConstructor() {
    import dali.utils.typedescriptor;
    import dali.constructors.annotations;
    import std.traits;

    alias Self = typeof(this);
    alias descriptor = Descriptor!Self;

    static if (descriptor.annotatedFieldNames!(RequiredField).length > 0)
        static assert(false);
    this(){
        static foreach(fieldName; descriptor.annotatedFieldNames!(WithDefault)){
            alias withDefault = getAnnotations!(mixin("this."~fieldName), WithDefault);
            static if (isCallable!(withDefault.initializer))
                mixin("this."~fieldName~" = withDefault.initializer();");
            else
                mixin("this."~fieldName~" = withDefault.initializer;");
        }
        static if (descriptor.hasAnnotatedMethod!PostConstruct){
            descriptor.annotatedMethod!PostContruct.forObject!this();
        }
    }
}

mixin template AllArgsConstructor(){
    import dali.utils.typedescriptor;
    import dali.constructors.annotations;
    import std.traits;
    import std.conv;
    import std.meta;

    alias Self = typeof(this);
    alias descriptor = Descriptor!Self;

    this(T...)(T args) if (is(T == descriptor.fieldTypes)){
        static foreach(i, fieldName; descriptor.fieldNames){
            mixin("this."~fieldName~" = args["~to!string(i)~"];");
        }
        static if (descriptor.hasAnnotatedMethod!PostConstruct){
            descriptor.annotatedMethod!PostContruct.forObject!this();
        }
    }
}

mixin template RequiredArgsContructor(){
    import dali.utils.typedescriptor;
    import dali.constructors.annotations;
    import std.traits;
    import std.conv;
    import std.meta;

    alias Self = typeof(this);
    alias descriptor = Descriptor!Self;

    this(T...)(T args) if (is(T == descriptor.annotatedFieldTypes!RequiredField)){
        static foreach(i, fieldName; descriptor.annotatedFieldNames!RequiredField){
            mixin("this."~fieldName~" = args["~to!string(i)~"];");
        }
        static foreach(fieldName; descriptor.annotatedFieldNames!WithDefault){
            static assert(staticIndexOf!(fieldName, descriptor.annotatedFieldTypes!RequiredField) == -1);
            alias withDefault = getAnnotations!(mixin("this."~fieldName), WithDefault);
            static if (isCallable!(withDefault.initializer))
                mixin("this."~fieldName~" = withDefault.initializer();");
            else
                mixin("this."~fieldName~" = withDefault.initializer;");
        }
        static if (descriptor.hasAnnotatedMethod!PostConstruct){
            descriptor.annotatedMethod!PostContruct.forObject!this();
        }
    }
}