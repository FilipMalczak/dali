module dali.wither.annotations;

struct WitherOptions {
    import dali.builder.mixins;

    mixin Builder;

    string prefix = "with";
}