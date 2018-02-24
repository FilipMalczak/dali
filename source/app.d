import std.stdio;
import std.conv;

import dombok.tostring.annotations;
import dombok.tostring.mixins: ToString;

string doubleToStr(int x){
    return to!string(2*x);
}

int doubleMe(int x){
    return 2*x;
}

struct X {
    mixin ToString;

    int i;
    //@ToStringWith!(doubleMe)
    @ToStringWith!(doubleToStr)
    int j;
    string a;
    @ToStringIgnore
    double d;
}

void main()
{
    writeln(X(1, 5, "A", 0.0));
	writeln("Edit source/app.d to start your project.");
}
