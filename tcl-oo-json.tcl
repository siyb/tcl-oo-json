namespace eval org::geekosphere::json {

	oo::class create JsonDeserializer {

		method fromJSON {jsonInput} {
			set channel [chan create {read write} [org::geekosphere::json::StringChannel new $jsonInput]]
			return [my fromJSONChannel $channel]
		}

		method fromJSONChannel {channel} {
			set jsonStreamParser [org::geekosphere::json::JsonStreamParser new $channel [self]]
			$jsonStreamParser parse
		}

		method on {type character} {
			puts "type: $type character: $character"
		}
	}

	oo::class create JsonSerializer {

		method toJSON {} {
			set variableList [info object vars [self]]
			set variableListLength [llength $variableList]

			set output "{"
			# meta information
			append output "\"__INSTANCE\":\"OBJ|[info object class [self]]\""

			if {$variableListLength != 0} {
				append output ","

				# check if there are fields marked as lists
				set knownLists [my getKnownLists $variableList]

				# ignored fields
				set ignoredFields [my getIgnoredFields $variableList]

				for {set i 0} {$i < $variableListLength} {incr i} {
					set ignoredFieldsLength [llength $ignoredFields]
					set var [lindex $variableList $i]
					if {[my isOnList $ignoredFields $var]} { continue }
					set varRef [self object]::$var

					if {[my isOnList $knownLists $var]} {
						append output [my writeList $var [set $varRef]]
					} elseif {[array exists $varRef]} {
						append output [my writeArray $var $varRef]
					} else {
						set content [set $varRef]
						append output [my writeField $var $content]
					}
					if {$i < [expr {$variableListLength - (1 + $ignoredFieldsLength)}]} {
						append output ","
					}
				}
			}
			append output "}"
		}

		method getFieldValue {variableList field} {
			if {[lsearch $variableList "$field"] != -1} {
				return [set [info object namespace [self]]::$field]
			}
			return []
		}

		method getIgnoredFields {variableList} {
			return [my getFieldValue $variableList "__IGNORE"]
		}

		method getKnownLists {variableList} {
			return [my getFieldValue $variableList "__LISTS"]

		}

		method isOnList {list var} {
			set searchResult [lsearch $list $var]
			return [expr {$searchResult != -1}]
		}

		method writeField {var content} {
			if {$var eq "__INSTANCE"} { error "The __INSTANCE field is reserved any may not be used as a variable name!" }
			if {$var eq "__LISTS" || $var eq "__IGNORE"} { return -code continue};# signal the variable list loop to continue processing, meta info is not serialized
			append output "\"$var\":"
			append output [my getJsonType $content]
			return $output
		}

		method writeList {var content} {
			set contentLength [llength $content]
			append output "\"$var\":"
			append output "\["
			for {set i 0} {$i < $contentLength} {incr i} {
				append output [my getJsonType [lindex $content $i]]
				if {$i < [expr {$contentLength - 1}]} {
					append output ","
				}
			}
			append output "\]"
			return $output
		}

		method writeArray {var varRef} {
			append output "\"$var\":"
			append output "{"
			append output "\"__INSTANCE\":\"OBJ|ARRAY\","; # array meta
			set arr [array get $varRef]
			set arrLength [llength $arr]
			for {set i 0} {$i < $arrLength} {incr i 2} {
				set arrayKey [lindex $arr $i]
				set arrayVal [lindex $arr [expr {$i + 1}]]
				append output [my writeField $arrayKey $arrayVal]
				if {$i < [expr {$arrLength - 2}]} {
					append output ","
				}
			}
			append output "}"
			return $output
		}

		method getJsonType {content} {
			if {[info object isa object $content] && [info object isa typeof $content org::geekosphere::json::JsonSerializer]} {
				return "[$content toJSON]"
			} elseif {[string is double $content]} {
				return "$content"
			} else {
				return "\"$content\""
			}
		}

		unexport writeField writeList writeArray isOnList getKnownLists getJsonType getIgnoredFields
	}

	oo::class create JsonStreamParser {
		variable channel listener stack

		constructor {channel_ listener_} {
			set channel $channel_
			set listener $listener_
			set stack [org::geekosphere::json::Stack new]
		}

		method parse {} {
			while {![chan eof $channel]} {
				set c [chan read $channel 1]
				switch $c {
					"\{" { my registerCharacter OBJSTART $c }
					"\}" { my registerCharacter OBJEND $c }
					"\[" { my registerCharacter ARRSTART $c}
					"\]" { my registerCharacter ARREND $c }
					":" { my registerCharacter SEP $c }
					"\"" { my registerCharacter QUOTE $c }
					default { my registerCharacter CONTENT $c }
				}
			}
		}

		method registerCharacter {type character} {
			$stack push $type
			$listener on $type $character
		}

		unexport registerCharacter
	}

	oo::class create Stack {
		variable stackList

		constructor {} {}

		method push {i} {
			lappend stackList $i
		}

		method pop {} {
			set result [my peek]
			set stackList [lreplace $stackList end end]
			return $result
		}

		method peek {} {
			return [lindex $pathList end]
		}

		method isEmpty {} {
			return [expr {[llength $stackList] == 0}]
		}
	}

	# Taken and adjusted from http://tcl.tk/man/tcl8.6/TclCmd/refchan.htm
	oo::class create StringChannel {
		variable data pos encoding

		constructor {{enc {}}} {
			if {$enc eq ""} {set encoding [encoding system]}
		}

		constructor {string {enc {}}} {
			if {$enc eq ""} {set encoding [encoding system]}
			set data [encoding convertto $encoding $string]
			set pos 0
		}

		method initialize {ch mode} { return [list initialize finalize watch read seek write] }

		method finalize {ch} { my destroy }

		method watch {ch events} {}

		method read {ch count} {
			set d [string range $data $pos [expr {$pos+$count-1}]]
			incr pos [string length $d]
			return $d
		}

		method write {ch inputData} {
			append data [encoding convertto $encoding $inputData]
			return [llength $inputData]
		}

		method seek {ch offset base} {
			switch $base {
				start { set pos $offset }
				current { incr pos $offset }
				end {
					set pos [string length $data]
					incr pos $offset
				}
			}
			if {$pos < 0} {
				set pos 0
			} elseif {$pos > [string length $data]} {
				set pos [string length $data]
			}
			return $pos
		}
	}
}

package provide tcloojson 1.0.0
