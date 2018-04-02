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
			puts "type: $type character: '$character'"
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
		variable channel listener

		constructor {channel_ listener_} {
			set channel $channel_
			set listener $listener_
		}

		method parse {} {
			set stateStack [org::geekosphere::json::Stack new]
			set tokenNumber 0

			$stateStack push "NONE"

			set json ""

			set fieldNameTemp ""
			set fieldValueTemp ""
			set fieldName ""

			while {![chan eof $channel]} {
				incr tokenNumber
				set c [chan read $channel 1]
				lappend json $c
				set state [$stateStack peek]
				switch $c {
					"\{" 	{
						if {$state eq "NONE" || $state eq "WAITING_FOR_FIELDVALUE" || $state eq "ARRAY"} {
							if {[$stateStack peek] eq "WAITING_FOR_FIELDVALUE"} {
								$stateStack pop
							}
							$stateStack push "OBJECT"
						} elseif {$state eq "WAITING_FOR_NEXT_ELEMENT"} {
							$stateStack popExpect "WAITING_FOR_NEXT_ELEMENT"
						} else {
							error "Encountered $c in wrong state ${state} - Char: $tokenNumber"
						}
					}
					"\}" 	{
						if {$state eq "OBJECT"} {
							$stateStack popExpect "OBJECT"
						} elseif {$state eq "FIELDVALUE"} {
							$stateStack popExpect "FIELDVALUE"
							$stateStack popExpect "OBJECT"
							puts "FIELDNAME: $fieldName FIELDVALUE: $fieldValueTemp"
							set fieldName ""
							set fieldValueTemp ""
							# TODO: check if datatype is valid!
						} else {
							error "Encountered $c in wrong state ${state} - Char: $tokenNumber"
						}
					}
					"\[" 	{
						if {$state eq "WAITING_FOR_FIELDVALUE"} {
							$stateStack popExpect "WAITING_FOR_FIELDVALUE"
							$stateStack push "ARRAY"
						} else {
							error "Encountered $c in wrong state ${state} - Char: $tokenNumber"
						}
					}
					"\]" 	{
						if {$state eq "ARRAY"} {
							$stateStack popExpect "ARRAY"
						} else {
							error "Encountered $c in wrong state ${state} - Char: $tokenNumber [$stateStack getStack]"
						}
					}
					":" 	{
						if {$state eq "FIELDNAME"} {
							append fieldNameTemp $c
						} elseif {$state eq "FIELDVALUE"} {
							append fieldValueTemp $c
						} elseif {$state eq "OBJECT"} {
							$stateStack push "WAITING_FOR_FIELDVALUE"
						} else {
							error "Encountered $c in wrong state ${state} - Char: $tokenNumber"
						}
					}
					"\"" 	{
						if {$state eq "OBJECT" || $state eq "WAITING_FOR_NEXT_ELEMENT"} {
							if {[$stateStack peek] eq "WAITING_FOR_NEXT_ELEMENT"} {
								$stateStack popExpect "WAITING_FOR_NEXT_ELEMENT"
							}
							$stateStack push "FIELDNAME"
						} elseif {$state eq "FIELDNAME"} {
							$stateStack popExpect "FIELDNAME"
							set fieldName $fieldNameTemp
							set fieldNameTemp ""
						} elseif {$state eq "WAITING_FOR_FIELDVALUE"} {
							$stateStack popExpect "WAITING_FOR_FIELDVALUE"
							$stateStack push "FIELDVALUE"
						} elseif {$state eq "FIELDVALUE"} {
							$stateStack popExpect "FIELDVALUE"
							puts "FIELDNAME: $fieldName FIELDVALUE: $fieldValueTemp"
							set fieldName ""
							set fieldValueTemp ""
						} else {
							error "Encountered $c in wrong state ${state} - Char: $tokenNumber"
						}
					}
					"," 	{
						if {$state eq "FIELDVALUE"} {
							$stateStack popExpect "FIELDVALUE"
							set fieldValueTemp ""
							# TODO: check if data type is valid!
						} elseif {$state eq "OBJECT" || $state eq "NONE"} {
							$stateStack push "WAITING_FOR_NEXT_ELEMENT"
						} elseif {$state eq "ARRAY"} {
							# TODO: record
						} else {
							error "Encountered $c in wrong state ${state} - Char: $tokenNumber"
						}
					}
					"\\"	{  }
					default {
						if {$state eq "WAITING_FOR_FIELDVALUE"} {
							$stateStack popExpect "WAITING_FOR_FIELDVALUE"
							$stateStack push "FIELDVALUE"
							append fieldValueTemp $c
						}
						if {$state eq "FIELDVALUE"} {
							append fieldValueTemp $c
						}
						if {$state eq "FIELDNAME"} {
							append fieldNameTemp $c
						}
					}
				}

				set newState [$stateStack peek]
				if {$state ne $newState} {
					puts "'$c': FROM STATE: $state TO STATE: [$stateStack peek] -> [$stateStack getStack]"
				}
			}
		}

		method registerCharacter {type character} {
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

		method popExpect {args} {
			set result [my peek]
			set ok 0
			foreach expected $args {
				if {$expected eq $result} {
					set ok 1
					break
				}
			}
			if {!$ok} {
				error "Expect failed: $expect - $result"
			}
			set stackList [lreplace $stackList end end]
			return $result
		}

		method peek {} {
			return [lindex $stackList end]
		}

		method isEmpty {} {
			return [expr {[llength $stackList] == 0}]
		}

		method getStack {} {
			return [lreverse $stackList]
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
