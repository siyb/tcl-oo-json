#
# Souring library, not required if installed!
#

source ./tcl-oo-json.tcl

#
# Requiring package
#

package require tcloojson 1.0.0

#
# Some test class definitions
#

oo::class create A {
	constructor {} {
		my variable woot
		my variable lol
		my variable thisIsARealList
		my variable __LISTS
		set lol "asdasd"
		set woot 1
		set thisIsARealList [list this is a real list! with 0.1 doubles and objects [B new]]
		set anotherB [B new]

		# since TCL lists are always strings, we need to declare lists manually, the __LISTS field only contains meta data
		# and will not be serialized to JSON.
		set __LISTS [list thisIsARealList]
	}
}

oo::class create B {
	constructor {} {
		my variable wat
		my variable dbl
		set wat "wat?"
		set dbl 0.1
	}
}

oo::class create C {
	constructor {} {
		my variable test
		my variable anotherTest
		my variable listTest
		my variable marshaller
		my variable arrayTest
		set test 1
		set anotherTest "test"
		set listTest [list a b c d]
		set marshaller [B new]
		set arrayTest(1) "one"
		set arrayTest(2) "two"
		set arrayTest(objTest) [A new]
	}
}

#
# JsonMarshaller must be mixed into any class that should be JSON serializable
#

oo::define A {
	mixin org::geekosphere::json::JsonSerializer
}

oo::define B {
	mixin org::geekosphere::json::JsonSerializer
}

oo::define C {
	mixin org::geekosphere::json::JsonSerializer
}

#
# Creating an instance of C and serializing object graph
#

set t [C new]

puts [$t toJSON]
