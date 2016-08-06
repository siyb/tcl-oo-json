namespace eval org::geekosphere::json {
	oo::class create JsonSerializer {

		method toJSON {} {
			set variableList [info object vars [self]]
			set output "{"
			# meta information
			append output "\"__INSTANCE\":\"OBJ|[info object class [self]]\","

			# check if there are fields marked as lists
			set knownLists [my getKnownLists $variableList]

			# ignored fields
			set ignoredFields [my getIgnoredFields $variableList]

			set variableListLength [llength $variableList]
			for {set i 0} {$i < $variableListLength} {incr i} {
				set var [lindex $variableList $i]
				if {[my isOnList $ignoredFields $var]} { continue }
				set varRef [info object namespace [self]]::$var

				if {[my isOnList $knownLists $var]} {
					append output [my writeList $var [set $varRef]]
				} elseif {[array exists $varRef]} {
					append output [my writeArray $var $varRef]
				} else {
					set content [set $varRef]
					append output [my writeField $var $content]
				}
				set ignoredFieldsLength [llength $ignoredFields]
				if {$i < [expr {$variableListLength - (1 + $ignoredFieldsLength)}]} {
					append output ","
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
}

package provide tcloojson 1.0.0
