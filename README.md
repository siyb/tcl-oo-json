# tcl-oo-json

TCL 8.6+ Object (De)serializer

## Introduction

tcloojson takes care of serializing (and soon deserializing) of TCL objects for you.
All you need to do is mixin the appropriate class and you are ready to go! tcloojson
supports the following data types:

* Object - must mixin JsonSerializer in order to be processed.
* String
* Numeric Types
* Array - is converted to a JSON object.
* List - is converted to a String, unless stated otherwise.

```tcl

# a simple class definition
oo::class create MyClass {
    constructor {} {
        my variable iAmAString
        my variable iAmAnInt
        my variable iAmAFloat
        set iAmAString "string!"
        set iAmAFloat 1.5
        set iAmAnInt 2
    }
}

# mixin the JsonSerializer
oo::define MyClass {
	mixin org::geekosphere::json::JsonSerializer
}

set myInstance [MyClass new]

puts [$myInstance toJSON]

```

Refer to [example.tcl](../blob/master/example.tcl) for a more complex example,
that covers all available features.

## Explicit / Implicit Meta Data

tcloojson uses meta data to (de)serialize objects. The following types of meta
data are known to tcloojson:

| Name       | Purpose                      | Type     | Retention |
|------------|------------------------------|----------|-----------|
| __INSTANCE | transports object class type | implicit | yes       |
| __LISTS    | explicitly declare lists     | explicit | no        |
| __IGNORE   | ignoring fields              | explicit | no        |

### __INSTANCE

The __INSTANCE field must not be declared by a class explicitly, if a class contains
an __INSTANCE field, (de)serialization will fail. The __INSTANCE field is used by
tcloojson interally to transport object class data, which would otherwise be lost by
the serialization process.

### __LISTS

Since all TCL lists are strings and most strings are valid TCL lists, the user needs
to explicitly define which strings are to be treated as lists. The __LISTS field has
to be declared implicitly by the user. It contains a TCL list of all TCL lists contained
in the class, that need to be treated as lists during the serialization process. The __LISTS
field will NOT be serialized and will therefore not appear in the generated JSON. If a TCL
list is declared as a list, it is serialized as a JSON array.

## __IGNORE

The __IGNORE list contains all fields that should be ignore. As with __LISTS, users
must explicitly ignore fields. The __IGNORE field is not persisted to JSON.

## License

Apache 2.0
