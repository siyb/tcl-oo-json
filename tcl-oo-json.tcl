namespace eval org::geekosphere::json {
	oo::class create JsonSerializer {

		method toJSON {} {
			set variableList [info object vars [self]]
			set output "{"
			# meta information
			append output "\"__INSTANCE\":\"OBJ|[info object class [self]]\","
			
			# check if there are fields marked as lists
			set knownLists [my getKnownLists $variableList]
			
			for {set i 0} {$i < [llength $variableList]} {incr i} {
				set var [lindex $variableList $i]
				set varRef [info object namespace [self]]::$var
				
				if {[my isKnownList $knownLists $var]} {
					append output [my writeList $var [set $varRef]]
				} elseif {[array exists $varRef]} {
					append output [my writeArray $var $varRef]
				} else {
					set content [set $varRef]
					append output [my writeField $var $content]
				}
				if {$i < [expr [llength $variableList] - 1]} {
					append output ","
				}
			}
			append output "}"
		}
		
		method getKnownLists {variableList} {
			if {[lsearch $variableList "__LISTS"] != -1} {
				return [set [info object namespace [self]]::__LISTS]
			}
			return []
		}
		
		method isKnownList {knownLists var} {
			return [expr [lsearch $knownLists $var] != -1]
		}
		
		method writeField {var content} {
			if {$var eq "__INSTANCE"} { error "The __INSTANCE field is reserved any may not be used as a variable name!" }
			if {$var eq "__LISTS"} { return -code continue};# signal the variable list loop to continue processing, because the __LIST meta info is _not_ written to json!
			append output "\"$var\":"
			append output [my getJsonType $content]
			return $output
		}
		
		method writeList {var content} {
			append output "\"$var\":"
			append output "\["
			for {set i 0} {$i < [llength $content]} {incr i} {
				append output [my getJsonType [lindex $content $i]]
				if {$i < [expr [llength $content] - 1]} {
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
			foreach {arrayKey arrayVal} [array get $varRef] {
				append output [my writeField $arrayKey $arrayVal]
				append output ","
			}
			set output [string trimright $output ","]
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
		
		unexport writeField writeList writeArray isKnownList getKnownLists getJsonType
	}
}

package provide tcloojson 1.0.0