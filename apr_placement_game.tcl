########################################################################
###set macros, io_ports, nets data, initial placement###########
###array get chip/ dict get $macros/ lindex $macros
####################################################################
proc init_game {} {
    global chip macros io_ports nets placement
    set chip(width) 10
    set chip(height) 10

    set macros {
        SRAM_A {w 3 h 3 symbol A}
        SRAM_B {w 2 h 4 symbol B}
        DSP    {w 2 h 2 symbol D}
    }

    set io_ports {
        CPU {x 0 y 5 symbol C}
        DDR {x 9 y 5 symbol R}
    }

    set nets {
        {CPU SRAM_A}
        {CPU DSP}
        {DDR SRAM_B}
        {DSP SRAM_B}
    }

    set placement {}
}

##############################################################
###Show the list of supported game commands.
###################################################################

proc show_help {} {
    puts "Commands:"
    puts "  help"
    puts "  show"
    puts "  list"
    puts "  place <macro> <x> <y>"
    puts "  remove <macro>"
    puts "  score"
    puts "  reset"
    puts "  exit"
}

#################################################################################
###input "list" show macros, io, netlist data#########
###dict set placement $name(macro key) [list x $x y $y]-> set placement {SRAM_A {x num y num}} #in procedure of implememtation macro placement.
########################################################################

proc list_macros {} {
    global macros placement io_ports nets

    puts "=== Macros ==="
    foreach name [dict keys $macros] {
        set info [dict get $macros $name]
        set w [dict get $info w]
        set h [dict get $info h] 
        set s [dict get $info symbol]  
        if {[dict exists $placement $name]} {
            set pos [dict get $placement $name]
            puts "  $name (${w}x$h) placed at ([dict get $pos x],[dict get $pos y]) symbol:$s"
        } else {
            puts "  $name (${w}x$h) not placed symbol:$s"
        }
    }

    puts "\n=== IO Ports ==="
    foreach name [dict keys $io_ports] {
        set info [dict get $io_ports $name]
        puts "  $name at ([dict get $info x],[dict get $info y]) symbol:[dict get $info symbol]"
    }

    puts "\n=== Nets ==="
    foreach net $nets {
        puts "  [lindex $net 0] <-> [lindex $net 1]"
    }
}

##################################################################################################
###Check if a macro placed at (x, y) is within the chip boundary.##########
##################################################################################################
 
proc check_boundary {name x y} {
    global chip macros
    set info [dict get $macros $name]
    set w [dict get $info w]
    set h [dict get $info h]
    if {$x < 0 || $y < 0} { return 0 }
    if {$x + $w > $chip(width) || $y + $h > $chip(height)} { return 0 }
    return 1 
}

#################################################################################################
###Check if two macros overlap and check if the new macro overlaps with existing placed macros.
#################################################################################################

####Check if two macros overlap and check.#####################################
####rect1(w1xh1)(x1,y1) and rect2(w2xh2)(x2,y2)################################
####If it return 0, macros don't overlap, otherwise return 1.##################

proc rect_overlap {x1 y1 w1 h1 x2 y2 w2 h2} {
    if {$x1 + $w1 <= $x2 || $x2 + $w2 <= $x1 || $y1 + $h1 <= $y2 || $y2 + $h2 <= $y1} {
        return 0
    }
    return 1
}

####Check if the new macro overlaps with existing placed macros.################################
####Placed macros: keyname (w1 x h1) at (x1, y1).###############################################
####For each placed macro otherkeyname (w2 x h2) at (x2, y2), skip if keyname == otherkeyname.##

proc check_overlap {name x y} {
    global placement macros
    set info1 [dict get $macros $name]
    set w1 [dict get $info1 w]
    set h1 [dict get $info1 h]

    foreach other [dict keys $placement] {
        if {$other eq $name} { continue }
        set pos2 [dict get $placement $other]
        set x2 [dict get $pos2 x]
        set y2 [dict get $pos2 y]
        set info2 [dict get $macros $other]
        set w2 [dict get $info2 w]
        set h2 [dict get $info2 h]
        if {[rect_overlap $x $y $w1 $h1 $x2 $y2 $w2 $h2]} {
            return 1
        }
    }
    return 0
}

###################################################################################################
###This function places a macro at (x, y) after performing legality checks such as existence, coordinate validation, boundary checking, and overlap detection.
###################################################################################################

proc place_macro {name x y} {
    global macros placement
    if {![dict exists $macros $name]} {
        puts "ERROR: Unknown macro $name"
        return
    }
    if {![string is integer -strict $x] || ![string is integer -strict $y]} {
        puts "ERROR: x and y must be integers"
        return
    }
    if {![check_boundary $name $x $y]} {
        puts "ERROR: Out of boundary"
        return
    }
    if {[check_overlap $name $x $y]} {
        puts "ERROR: Overlap detected"
        return
    }
    dict set placement $name [list x $x y $y]
    puts "$name placed at ($x,$y)"
}

################################################################################################
###Remove a macro from the placement database if it exists.
################################################################################################

proc remove_macro {name} {
    global placement
    if {[dict exists $placement $name]} {
        dict unset placement $name
        puts "$name removed"
    } else {
        puts "ERROR: $name is not placed"
    }
}

##################################################################################################
###get_node_center is the core function for wirelength calculation. It takes a node (macro or IO) and returns its center coordinates.
##################################################################################################

proc get_node_center {name} {
    global io_ports placement macros
                                          ;#If it is an IO,return the IO coordinates.
    if {[dict exists $io_ports $name]} {       

        set info [dict get $io_ports $name]
        return [list [dict get $info x] [dict get $info y]]
    }
                                            ;#If the macro has not been placed, return an empty
    if {![dict exists $placement $name]} {  
        return ""
    }
    set pos [dict get $placement $name]     ;#If the macro is placed, return its center point     
    set x [dict get $pos x]
    set y [dict get $pos y]
    set info [dict get $macros $name]
    set w [dict get $info w]
    set h [dict get $info h]
    return [list [expr {$x + $w / 2.0}] [expr {$y + $h / 2.0}]]
}


####calculat total wirelength################################
                                          ;#simplified distance calculation method, like HPWL
proc manhattan {x1 y1 x2 y2} {               
    return [expr {abs($x1 - $x2) + abs($y1 - $y2)}]
}

proc calc_wirelength {} {
    global nets
    set total 0
    foreach net $nets {
        lassign $net a b                     ;#For each net
        set p1 [get_node_center $a]
        set p2 [get_node_center $b]          ;#Get the core coordinates of both io/macros.
        if {$p1 eq "" || $p2 eq ""} {
            continue                         ;#If any node is not placed, skip it.
        }
        lassign $p1 x1 y1
        lassign $p2 x2 y2
        set total [expr {$total + [manhattan $x1 $y1 $x2 $y2]}]   ;#Compute the distance.
    }
    return $total
}

###If two macros are placed too close to each other, the routing channel between them becomes too narrow, increasing congestion risk, so a penalty is applied.###########
###"for" Outer loop: iterate over macros from the first one (i is the first macro)
###"for" Inner loop: select the second macro (j = i + 1)##########################

proc calc_congestion {} {
    global placement macros
    set penalty 0
    set names [dict keys $placement]                       ;#get all placed macro name 
    for {set i 0} {$i < [llength $names]} {incr i} {            
        for {set j [expr {$i+1}]} {$j < [llength $names]} {incr j} {
            set a [lindex $names $i]                       ;#get macro name1
            set b [lindex $names $j]                       ;#get macro name2
            set pa [get_node_center $a]                ;#get macro name1(cx1,cy1)
            set pb [get_node_center $b]                ;#get macro name2(cx2,cy2)
            lassign $pa ax ay
            lassign $pb bx by
            set d [manhattan $ax $ay $bx $by]   
                                                   ;#If d is less than 4, add a penalty of 5
            if {$d < 4} {                       
                incr penalty 5
            }                                         
        }
    }
    return $penalty
}

###Verify placement legality, then compute wirelength and congestion, and finally calculate and output the total score.##################################

proc score_design {} {
    global macros placement
                                           ;#Check if all macros have been placed.
    foreach name [dict keys $macros] {           
        if {![dict exists $placement $name]} {
            puts "ERROR: Please place all macros before scoring"
            return
        }
    }

    set wl [calc_wirelength]                    ;#calculate wirelength (all nets)
    set cg [calc_congestion]                    ;#calculate congestion penalty
    set score [expr {100 - int($wl) - $cg}] ;#score = 100 - wirelength - congestion
    if {$score < 0} { set score 0 }

    puts "Placement Result"
    puts "----------------"
    puts "Legal Placement : YES"
    puts "Wirelength      : $wl"
    puts "Congestion Pen. : $cg"
    puts "Total Score     : $score"
}

################################################################################################
###Visualize the chip layout (IO and macros) as a 2D text map.
################################################################################################
proc show_board {} {
    global chip io_ports placement macros
    array set board {}                               ;#build empty array: board
    for {set y 0} {$y < $chip(height)} {incr y} {
        for {set x 0} {$x < $chip(width)} {incr x} {
            set board($x,$y) .             
        }                           ;#Assign"."to every location (x, y) to build a 2D grid
    }
 
                                          ;#Visualize the IO ports on the board.
    foreach name [dict keys $io_ports] {     
        set info [dict get $io_ports $name]
        set x [dict get $info x]
        set y [dict get $info y]
        set s [dict get $info symbol]
        set board($x,$y) $s
    }

                                              ;#Visualize the macro on the board.
    foreach name [dict keys $placement] {    
        set pos [dict get $placement $name]
        set x0 [dict get $pos x]
        set y0 [dict get $pos y]
        set info [dict get $macros $name]
        set w [dict get $info w]
        set h [dict get $info h]
        set s [dict get $info symbol]
        for {set y $y0} {$y < $y0 + $h} {incr y} {   
            for {set x $x0} {$x < $x0 + $w} {incr x} {
                set board($x,$y) $s
            }                       ;# Fill the macro's rectangular area with its symbol
        }
    }

    puts ""                           ;#print "\n"
    for {set y [expr {$chip(height)-1}]} {$y >= 0} {incr y -1} {
        puts -nonewline "$y  "                          ;#-nonewline =not "\n" ;#print y-axis
        for {set x 0} {$x < $chip(width)} {incr x} {
            puts -nonewline "$board($x,$y) "
        }
        puts ""                       ;#9 board(9,0->9)print "\n" 8 board(8,0->9)...
    }
    puts -nonewline "   "
    for {set x 0} {$x < $chip(width)} {incr x} {
        puts -nonewline "$x "                       
    }                                  ;#print x-axis
    puts "\n"
}

###############################################################################################
###Receive user input, parse the command, invoke the corresponding functionality, and continue execution until an exit command is issued.
###############################################################################################

proc main {} {
    init_game
    puts "==============================="
    puts " Mini APR Placement Challenge"
    puts "==============================="
    puts "Type 'help' to see commands."

    while {1} {
        puts -nonewline "APR> "
        flush stdout                           ;#flush stdout: Flush the standard output
        if {[gets stdin line] < 0} { break }   ;#if EOF, break loop
        if {$line eq ""} { continue }          ;#if input "enter", skip this loop and do next loop

        set cmd [lindex $line 0] ;#switch is used to choose different actions based on a value
        switch -- $cmd {             
            help   { show_help }
            show   { show_board }
            list   { list_macros }
            place  {
                if {[llength $line] != 4} {
                    puts "Usage: place <macro> <x> <y>"
                } else {
                    place_macro [lindex $line 1] [lindex $line 2] [lindex $line 3]
                }
            }
            remove {
                if {[llength $line] != 2} {
                    puts "Usage: remove <macro>"
                } else {
                    remove_macro [lindex $line 1]
                }
            }
            score  { score_design }
            reset  { init_game; puts "Game reset" }
            exit   { puts "Bye!"; break }
            default { puts "Unknown command. Type 'help'." }
        }
    }
}

main