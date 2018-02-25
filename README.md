# Dali

Dali - Lombok-inspired metaprogramming stuff that I'd love to see in DLang.

## Current features:

### Done (stable-ish)

> Mind you that following features may change a lot yet - they are usable, which doesn't
> mean that they have mature API.

- `ToString` - mixin that provides customizable implementation of toString() method
- `Builder` - mixin that provides lombok-style builders

### WIP

- `Proxy` - it is intended to provide wrapper type that can use method interceptors, 
    thus opening the way to observable objects and AOP.

### ToDo

- `EqualsAndHashCode` - mixin similiar to Lombok-style annotation
- integration with [poodinis](https://github.com/mbierlee/poodinis)
- scavenge package scan from [ioc](https://github.com/FilipMalczak/ioc)
- reactive streams (probably integrate with existing project)
- wrapping of `std.container` into normalized API, inspired by Java Collections API
- `<container>.stream()` - in java style, running thread per streaming operation

## About name

Initially I've called this lib "dombok", but I've figured that it's just lazy naming.
I've quickly read about Lombok island, figured it is close to Bali, hence Dali that also
refers to the legendary artist.