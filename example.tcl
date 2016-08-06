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

oo::class create Person {
	variable firstName lastName age height gender hobbies ssn telephoneNumbers __LISTS __IGNORE
	constructor {} {
		set firstName "John"
		set middleNames [list "Jake" "Richard"];# will not be treated as a real list
		set lastName "Doe"
		set age 25
		set height 1.87
		set gender [Gender new "male"]
		set ssn 12345
		set hobbies [list [Hobby new "Programming" 20] [Hobby new "Skiing" 1] [Hobby new "Jogging" 5]];# treated as a real list

		set telephoneNumbers(1) 0049000000
		set telephoneNumbers(2) 0049000001
		set telephoneNumbers(3) 0049000002
		set telephoneNumbers(4) 0049000003

		# Meta Data
		set __LISTS [list hobbies];# defines which lists to serialize as JSON arrays
		set __IGNORE [list ssn];# defines fields to be ignored
	}
}

oo::class create Hobby {
	variable designation timePerWeek
	constructor {des tpw} {
		set designation $des
		set timePerWeek $tpw
	}
}

oo::class create Gender {
	variable designation
	constructor {des} {
		set designation $des
	}
}

#
# JsonMarshaller must be mixed into any class that should be JSON serializable
#

oo::define Person {
	mixin org::geekosphere::json::JsonSerializer org::geekosphere::json::JsonDeserializer
}

oo::define Hobby {
	mixin org::geekosphere::json::JsonSerializer;# org::geekosphere::json::JsonDeserializer
}

oo::define Gender {
	mixin org::geekosphere::json::JsonSerializer;# org::geekosphere::json::JsonDeserializer
}

#
# Creating an instance of C and serializing object graph
#

set toJsonPerson [Person new]
set jsonData [$toJsonPerson toJSON]

puts $jsonData

set fromJsonPerson [Person new]
$fromJsonPerson fromJSON $jsonData
