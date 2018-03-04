module dali.utils.daliconstants;

enum IsDaliInternalField(string fieldName) = isDaliInternalField(fieldName);

bool isDaliInternalField(string fieldName){
    import std.string;
    return startsWith(fieldName, "___dali_");
}

string asInternalFieldName(string generatedBy, string symbolicName){
    return "___dali_"~generatedBy~"_"~symbolicName;
}