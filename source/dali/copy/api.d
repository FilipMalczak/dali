module dali.copy.api;

interface Copyable(T) {
    T copy();
}

struct CopyableStruct(T){
    T copy(){
        throw new Exception("This should be shadowed by implementation of class/struct doing 'alias ... this'");
    }
}

class CopyableClass(T): Copyable!T {
    override T copy(){
        throw new Exception("This should be shadowed by implementation of class/struct doing 'alias ... this'");
    }
}

interface DeepCopyable(T) {
    T deepCopy();
}

struct DeepCopyableStruct(T){
    T deepCopy(){
        throw new Exception("This should be shadowed by implementation of class/struct doing 'alias ... this'");
    }
}

class DeepCopyableClass(T): DeepCopyable!T {
    override T deepCopy(){
        throw new Exception("This should be shadowed by implementation of class/struct doing 'alias ... this'");
    }
}