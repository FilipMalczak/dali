module dali.constructors.annotations;

enum RequiredField;

struct WithDefault(T...) if (T.length == 1){ alias initializer = T[0]; };

enum PostConstruct;