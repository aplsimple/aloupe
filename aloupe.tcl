#! /usr/bin/env tclsh
###########################################################
# Name:    aloupe.tcl
# Author:  Alex Plotnikov  (aplsimple@gmail.com)
# Date:    Feb 26, 2021
# Brief:   Handles a screen loupe.
# License: MIT.
###########################################################

# _________________________ aloupe ________________________ #

package require Tk

package provide aloupe 1.8.1

namespace eval ::aloupe {
  variable solo [expr {[info exist ::argv0] && [file normalize $::argv0] eq [file normalize [info script]]}]
}
if {$::aloupe::solo} {wm withdraw .}

# _____ Remove installed (perhaps) packages used here _____ #

if {$::aloupe::solo} {
  foreach _ {apave baltip bartabs hl_tcl ttk::theme::awlight ttk::theme::awdark awthemes} {
    set __ [package version $_]
    catch {
      package forget $_
      namespace delete ::$_
      puts "aloupe: clearing $_ $__"
    }
    unset __
  }

  # use TCLLIBPATH variable (some tclkits don't see it)
  catch {
    foreach _apave_ [lreverse $::env(TCLLIBPATH)] {
      set _apave_ [file normalize $_apave_]
      if {[lsearch -exact $::auto_path $_apave_]<0 && [file exists $_apave_]} {
        set ::auto_path [linsert $::auto_path 0 $_apave_]
      }
    }
    unset _apave_
  }
}

# ________________________ Run solo at need _________________________ #

proc ::aloupe::RunSolo {} {
  # Runs aloupe as a sole Tcl script.
  # When aloupe runs from tclkit, it may fail. So try it with tclsh deployed.

  set tclsh [auto_execok tclsh]
  set tclexe [info nameofexecutable]
  # tclsh may be sort of "tcl.sh" to run a tclkit
  if {[file exists $tclsh] && [file size $tclsh]>1024 && $tclsh ne $tclexe} {
    if {$::aloupe::solo} {set aar $::argv} {set aar {}}
    exec -- $tclsh $::aloupe::aloupescript {*}$aar &
  } else {
    puts "aloupe: $::aloupe::runerr"
  }
}

proc ::aloupe::GetPackages {{dir .}} {
  # Gets required packages.
  #   dir - supposed directory of packages

  set dir [file normalize $dir]
  set dir1 [lindex [glob -nocomplain [file join $dir treectrl*]] 0]
  if {[info exists ::auto_path] && $dir1 ne {}} {
    set dir2 [lindex [glob -nocomplain [file join $dir Img1.*]] 0]
    if {$dir2 ne {}} {lappend ::auto_path $dir1 $dir2}
  }
  return [catch {package require treectrl; package require Img} ::aloupe::runerr]
}

proc ::aloupe::FindPackages {} {
  # Tries to find required packages in an upper bin directory.

  set dirs [file split [file dirname [file normalize $::aloupe::aloupescript]]]
  while 1 {
    set dir [file join {*}$dirs bin]
    if {[file exists $dir]} {
      if {![set ::aloupe::starterr [::aloupe::GetPackages $dir]]} {
        return yes
      }
    }
    if {[set dirs [lreplace $dirs end end]] eq {}} break
  }
  return no
}

set ::aloupe::aloupescript [info script]
set ::aloupe::starterr [::aloupe::GetPackages]
if {$::aloupe::solo && $::aloupe::starterr && ![::aloupe::FindPackages]} {
  ::aloupe::RunSolo
  exit
}

# ________________________ Variables _________________________ #

::msgcat::mcload [file join [file dirname [info script]] msgs]

namespace eval ::aloupe {
  variable filename {}
  namespace eval my {
    variable HOMEDIR ~
    if {[info exists ::env(HOME)]} {set HOMEDIR $::env(HOME)}
    variable size 26
    variable zoom 8
    variable pause 0
    variable data
    array set data [list \
      -size $size \
      -zoom $zoom \
      -pause $pause \
      -alpha 0.3 \
      -background #ff40ff \
      -exit yes \
      -command "" \
      -commandname "" \
      -ontop yes \
      -geometry "" \
      -parent "" \
      -save yes \
      -inifile [file join $HOMEDIR .config aloupe.conf] \
      -locale "" \
      -apavedir "" \
      -cs -2 \
      -fcgeom {} \
    ]
  }
}

# ___________________________ Common procs ____________________________ #

proc ::aloupe::my::Synopsis {} {
  # Short info about usage.

  variable data
  puts "
Syntax:
  tclsh aloupe.tcl ?option value ...?
where 'option' may be [array names $data(DEFAULTS)].
"
  exit
}
#_______________________

proc ::aloupe::my::Message {args} {
  # Displays a message, with the loupe hidden.

  variable data
  wm withdraw $data(WLOUP)
  tk_messageBox -parent $data(WDISP) -type ok {*}$args
  wm deiconify $data(WLOUP)
}
#_______________________

proc ::aloupe::my::InvertBg {color} {
  # Gets fg color (white/black) for a bg color.
  #  color - bg color

  lassign [winfo rgb . $color] r g b
  if {($r%256+$b%256)<15 && ($g%256)>180} {
    set res black
  } elseif {$r+1.5*$g+0.5*$b > 100000} {
    set res black
  } else {
    set res white
  }
  return $res
}

# ________________________ Main and loop windows _________________________ #

proc ::aloupe::my::CreateDisplay {start} {
  # Creates the displaying window.
  #   start - yes, if called at start

  variable data
  set sZ [expr {2*$data(-size)*$data(-zoom)}]
  set data(IMAGE) [image create photo -width $sZ -height $sZ]
  toplevel $data(WDISP)
  wm title $data(WDISP) [::msgcat::mc Loupe]
  set fg [ttk::style configure . -foreground]
  set bg [ttk::style configure . -background]
  set opts [ttk::style config TButton]
  catch {set fg [dict get $opts -foreground]}
  catch {set bg [dict get $opts -background]}
  $data(WDISP) configure -background $bg
  grid [label $data(WDISP).l -fg $fg -bg $bg] -row 0 -columnspan 3 -sticky we
  pack [label $data(WDISP).l.lab1 -text " [::msgcat::mc Size]" -fg $fg -bg $bg] -side left -anchor e -expand 1
  pack [ttk::spinbox $data(WDISP).l.sp1 -from 8 -to 500 -justify center \
    -width 4 -textvariable ::aloupe::my::size -command ::aloupe::my::ShowLoupe \
    -validate focus -validatecommand {::aloupe::my::Valid size 8 500 25}] -side left
  pack [label $data(WDISP).l.lab2 -text " [::msgcat::mc Zoom]" -fg $fg -bg $bg] -side left -anchor e -expand 1
  pack [ttk::spinbox $data(WDISP).l.sp2 -from 1 -to 50 -justify center \
    -width 2 -textvariable ::aloupe::my::zoom -validate focus \
    -validatecommand {::aloupe::my::Valid zoom 1 50 10}] -side left
  pack [label $data(WDISP).l.lab3 -text " [::msgcat::mc Pause]" -fg $fg -bg $bg] -side left -anchor e -expand 1
  pack [ttk::spinbox $data(WDISP).l.sp3 -from 0 -to 60 -justify center \
    -width 2 -textvariable ::aloupe::my::pause \
    -validate focus -validatecommand {::aloupe::my::Valid pause 0 60 0}] -side left
  grid [ttk::separator $data(WDISP).sep1 -orient horizontal] -row 1 -columnspan 3 -sticky we -pady 2
  grid [ttk::label $data(LABEL) -image $data(IMAGE) -relief flat] -row 2 -columnspan 3 -padx 2
  set data(BUT0) $data(WDISP).but0
  set data(BUT1) $data(WDISP).but1
  set data(BUT2) $data(WDISP).but2
  if {[set but1text $data(-commandname)] eq ""} {
    set but1text [::msgcat::mc "To clipboard"]
  }
  grid [button $data(BUT0) -text [::msgcat::mc "Refresh"] \
    -command ::aloupe::my::Refresh -fg $fg -bg $bg -font TkFixedFont] \
    -row 3 -column 0 -sticky ew
  grid [button $data(BUT1) -text $but1text \
    -command ::aloupe::my::Button2Click -font TkFixedFont] \
    -row 3 -column 1 -sticky ew
  grid [button $data(BUT2) -text [::msgcat::mc Save] \
    -command ::aloupe::my::Save -fg $fg -bg $bg -font TkFixedFont] \
    -row 3 -column 2 -sticky ew
  set data(-geometry) [regexp -inline \\+.* $data(-geometry)]
  if {$data(-geometry) ne ""} {
    wm geometry $data(WDISP) $data(-geometry)
  } elseif {$data(-parent) ne ""} {
    ::tk::PlaceWindow $data(WDISP) widget $data(-parent)
  } else {
    ::tk::PlaceWindow $data(WDISP)
  }
  if {$start} {
    set defargs [list -foreground $fg -background $bg]
    set data(BUTCFG) [StyleButton2 {*}$defargs]
    lappend data(BUTCFG) {*}$defargs -text $but1text
  }
  foreach w {BUT0 BUT1 BUT2} {
    set w $data($w)
    foreach k {<Up> <Left>} {
      bind $w $k "\
        if {{$::tcl_platform(platform)} eq {windows}} { \
          event generate $w <Shift-Tab> \
        } else { \
          event generate $w <Key> -keysym ISO_Left_Tab \
        }"
    }
    foreach k {<Down> <Right>} {
      bind $w $k "event generate $w <Key> -keysym Tab"
    }
    foreach k {<Return> <KP_Enter>} {
      bind $w $k "event generate $w <Key> -keysym space"
    }
  }
  bind $data(LABEL) <ButtonPress-1> {::aloupe::my::PickColor %W %X %Y}
  bind $data(WDISP) <Escape> ::aloupe::my::Exit
  wm resizable $data(WDISP) 0 0
  wm protocol $data(WDISP) WM_DELETE_WINDOW ::aloupe::my::Exit
  if {$data(-ontop)} {wm attributes $data(WDISP) -topmost 1}
}
#_______________________

proc ::aloupe::my::CreateLoupe {{geom ""}} {
  # Creates the loupe window.
  #   geom - the predefined geometry

  variable data
  frame $data(WLOUP)
  wm manage $data(WLOUP)
  wm withdraw $data(WLOUP)
  wm overrideredirect $data(WLOUP) 1
  set canvas $data(WLOUP).c
  canvas $canvas -width 100 -height 100 -background $data(-background) \
    -relief flat -bd 0 -highlightthickness 1 -highlightbackground red
  pack $canvas -fill both -expand true
  bind $canvas <ButtonPress-1>   {::aloupe::my::DragStart %W %X %Y %x %y}
  bind $canvas <B1-Motion>       {::aloupe::my::Drag %W %X %Y}
  bind $canvas <ButtonRelease-1> {::aloupe::my::DragEnd %W}
  bind $canvas <Escape>          {::aloupe::my::Exit}
  after 50 "
    ::aloupe::my::InitGeometry $geom
    wm deiconify $data(WLOUP)
    wm attributes $data(WLOUP) -topmost 1 -alpha $data(-alpha)
    "
}
#_______________________

proc ::aloupe::my::Theme {} {
  # Themes the utility

  variable data
  if {$data(-apavedir) eq {}} return
  source [file join $data(-apavedir) apave.tcl]
  ::apave::initWM -cs $data(-cs) -theme alt
  if {$data(-fcgeom) ne {}} {
    ::apave::obj chooserGeomVars {} ::aloupe::my::data(-fcgeom)
  }
}
#_______________________

proc ::aloupe::my::Create {start} {
  # Initializes and creates the utility's windows.
  #   start - yes, if called at start

  variable data
  catch {destroy $data(WLOUP)}
  catch {destroy $data(WDISP)}
  catch {image delete $data(IMAGE)}
  if {[set wgr [grab current]] ne ""} {grab release $wgr}
  CreateDisplay $start
  CreateLoupe
  set data(PREVZOOM) $data(-zoom)
  set data(PREVSIZE) $data(-size)
  focus $data(WDISP)
}
#_______________________

proc ::aloupe::my::Valid {vnam val1 val2 valdef} {
  # Validates spinbox's value.
  #   vnam - variable name
  #   val1 - "from" value
  #   val2 - "to" value
  #   valdef - default value

  set vnam ::aloupe::my::$vnam
  set val [set $vnam]
  if {$val<$val1 || $val>$val2} {
    set $vnam $valdef
  }
  return 1
}

# ________________________ Drag-n-drop _________________________ #

proc ::aloupe::my::DragStart {w X Y x y} {
  # Initializes the frag-and-drop of the loupe.
  #   w - the loupe window's path
  #   X - X-coordinate of the mouse pointer
  #   Y - Y-coordinate of the mouse pointer
  #   x - X-coordinate inside the loupe
  #   y - Y-coordinate inside the loupe

  variable data
  variable size
  variable zoom
  set data(FOCUS) [focus]
  focus -force $data(WDISP)
  set data(-size) $size
  set data(-zoom) $zoom
  if {$data(PREVZOOM) != $data(-zoom) || $data(PREVSIZE) != $data(-size)} {
    SaveGeometry
    Create no
    catch {unset data(dragX)}  ;# no drag-n-drop, update the loupe only
    update
    return
  }
  InitButton2
  set data(x) $x
  set data(y) $y
  InitGeometry
  update
  set data(dragX) [expr {$X - [winfo rootx $w]}]
  set data(dragY) [expr {$Y - [winfo rooty $w]}]
}
#_______________________

proc ::aloupe::my::InitButton2 {} {
  # Initializes color ("to clipboard") button.

  variable data
  set data(COLOR) [set data(CAPTURE) ""]
  StyleButton2 {*}$data(BUTCFG)
}
#_______________________

proc ::aloupe::my::ColorButton2 {} {
  # Colorizes color ("to clipboard") button.

  variable data
  if {$data(COLOR) ne ""} {
    StyleButton2 -background $data(COLOR) -foreground $data(INVCOLOR) \
      -text $data(COLOR)
  }
}
#_______________________

proc ::aloupe::my::Drag {w X Y} {
  # Performs the frag-and-drop of the loupe.
  #   w - the loupe window's path
  #   X - X-coordinate of the mouse pointer
  #   Y - Y-coordinate of the mouse pointer

  variable data
  if {![info exists data(dragX)]} return
  set dx [expr {$X - $data(dragX)}]
  set dy [expr {$Y - $data(dragY)}]
  wm geometry $data(WLOUP) +$dx+$dy
}
#_______________________

proc ::aloupe::my::DragEnd {w} {
  # Ends the frag-and-drop of the loupe and displays its magnified image.
  #   w - the loupe window's path

  variable pause
  if {$pause} {
    after 1000 [list ::aloupe::my::CountDownPause $pause $pause]
    after [expr {$pause*1000}] [list ::aloupe::my::DisplayImage $w]
  } else {
    ::aloupe::my::DisplayImage $w
  }
}
#_______________________

proc ::aloupe::my::CountDownPause {pause p} {
  # Counts down a pause.
  #   pause - seconds to count down
  #   p - remaining seconds to count down

  variable data
  if {$p} {
    set ::aloupe::my::pause [incr p -1] ;# shows remaining seconds
    set msec [expr {$p ? 1000 : 200}]
    after $msec [list ::aloupe::my::CountDownPause $pause $p]
  } else {
    set ::aloupe::my::pause $pause
  }
}
#_______________________

proc ::aloupe::my::DisplayImage {w} {
  # Ends the frag-and-drop of the loupe and displays its magnified image.
  #   w - the loupe window's path

  variable data
  if {![info exists data(dragX)]} return
  wm attributes $data(WLOUP) -topmost 1 -alpha 0.0
  wm attributes $data(WDISP) -alpha 0.0
  wm withdraw $data(WLOUP)
  wm withdraw $data(WDISP)
  set curX [winfo rootx $w]
  set curY [winfo rooty $w]
  set curW [winfo width $w]
  set curH [winfo height $w]
  catch {image delete $data(CAPTURE)}
  set sz [expr {2*$data(-size)}]
  set sZ [expr {$sz*$data(-zoom)}]
  set data(CAPTURE) [image create photo -width $sz -height $sz]
  set loupe_x [expr {$curX + $sz/2}]
  set loupe_y [expr {$curY + $sz/2}]
  after 40 "loupe $data(CAPTURE) $loupe_x $loupe_y $sz $sz 1"
  after 50
  update   ;# enough time to hide the window and capture the image
  after 50
  catch {
    $data(IMAGE) copy $data(CAPTURE) -from 0 0 $sz $sz \
      -to 0 0 $sZ $sZ -zoom $data(-zoom)
  }
  wm deiconify $data(WDISP)
  wm deiconify $data(WLOUP)
  after idle " \
    wm attributes $data(WLOUP) -topmost 1 -alpha $data(-alpha);\
    wm attributes $data(WDISP) -alpha 1.0"
  focus -force $data(BUT0)
}
#_______________________

proc ::aloupe::my::Refresh {} {
  # Refreshes the loupe image without mouse click.

  variable data
  InitButton2
  DragEnd $data(WLOUP)
}

# ________________________ Geometry _________________________ #

proc ::aloupe::my::ShowLoupe {} {
  # Re-displays the loupe at changing its size.

  variable data
  variable size
  set data(-size) $size
  lassign [split [wm geometry $data(WLOUP)] +] -> x y
  set sz [expr {2*$size}]
  destroy $data(WLOUP)
  CreateLoupe ${sz}x${sz}+$x+$y
  ColorButton2
}
#_______________________

proc ::aloupe::my::InitGeometry {{geom ""}} {
  # Gets and sets the geometry of the loupe window,
  # based on the image label's sizes and the zoom factor.
  #   geom - the predefined geometry

  variable data
  if {$geom eq ""} {
    set sz [expr {2*$data(-size)}]
    lassign [winfo pointerxy .] x y
    if {[info exists data(x)]} {set dx $data(x)} {set dx $sz/2}
    if {[info exists data(y)]} {set dy $data(y)} {set dy $sz/2}
    set x [expr $x-$dx]
    set y [expr $y-$dy]
    set geom ${sz}x${sz}+$x+$y
  }
  wm geometry $data(WLOUP) $geom
}
#_______________________

proc ::aloupe::my::SaveGeometry {} {
  # Saves the displaying window's geometry.

  variable data
  set data(-geometry) ""
  catch {set data(-geometry) [wm geometry $data(WDISP)]}
}

# ________________________ Widgets' styles _________________________ #

proc ::aloupe::my::StyleButton2 {args} {
  # Makes a style for Tbutton.
  #   args - options ("name value" pairs)
  # Returns the TButton's configuration options.

  variable data
  if {[dict exists $args -text]} {
    $data(BUT1) configure -text [dict get $args -text]
    set args [dict remove $args -text]
  }
  set fg [dict get $args -foreground]
  set bg [dict get $args -background]
  $data(BUT1) configure -foreground $fg -background $bg
  return {}
}

# ________________________ Capturing image _________________________ #

proc ::aloupe::my::Button2Click {} {
  # Processes the click on 'Clipboard' button.

  variable data
  if {$data(COLOR) ne ""} {
    StyleButton2 -background $data(INVCOLOR) -foreground $data(COLOR)
    update idletasks
    after 60 ;# just to make the click visible
  }
  if {[HandleColor] && !$data(-exit) && $data(-command) ne ""} {
    SaveGeometry
    {*}[string map [list %c $data(COLOR)] $data(-command)]
  }
}
#_______________________

proc ::aloupe::my::IsCapture {} {
  # Checks if the image was captured.

  variable data
  if {$data(CAPTURE) eq ""} {
    Message -title [msgcat::mc {Color of Image}] -icon warning \
      -message  [msgcat::mc "Click, then drag and drop\nthe loupe to get the image."]
    return no
  }
  return yes
}
#_______________________

proc ::aloupe::my::HandleColor {{doclb yes}} {
  # Processes the image color under the mouse pointer,
  # optionally saving it to the clipboard.
  #   doclb - if 'yes', means "put the color into the clipboard"
  # Returns 'yes' if the color was chosen.

  variable data
  set res no
  if {[IsCapture]} {
    if {$data(COLOR) eq ""} {
      Message -title [msgcat::mc {Color of Image}] -icon warning \
        -message [msgcat::mc "Click the magnified image\nto get a pixel's color.\n\nThen hit this button."]
    } else {
      if {$doclb && $data(-commandname) eq ""} {
        clipboard clear
        clipboard append -type STRING $data(COLOR)
      }
      ColorButton2
      set res yes
    }
  }
  return $res
}
#_______________________

proc ::aloupe::my::PickColor {w X Y} {
  # Gets the image color under the mouse pointer.
  #   w - the image label's path
  #   X - X-coordinate of the mouse pointer
  #   Y - Y-coordinate of the mouse pointer

  variable data
  if {![IsCapture]} return
  set x [expr {max(($X - [winfo rootx $w] -4),0)}]
  set y [expr {max(($Y - [winfo rooty $w] -4),0)}]
  catch {
    lassign [$data(IMAGE) get $x $y] r g b
    set data(COLOR) [format "#%02x%02x%02x" $r $g $b]
    set data(INVCOLOR) [InvertBg $data(COLOR)]
    HandleColor no
    set msec [clock milliseconds]
    if {[info exists data(MSEC)] && [expr {($msec-$data(MSEC))<400}]} {
      Button2Click
    }
    set data(MSEC) $msec
  }
}
#_______________________

proc ::aloupe::my::SaveOptions {} {
  # Saves options of appearance to a file.

  variable data
  variable size
  variable zoom
  variable pause
  if {!$data(-save)} return
  set data(-size) $size
  set data(-zoom) $zoom
  set data(-pause) $pause
  set w $data(WDISP)
  catch {file mkdir [file dirname $data(-inifile)]}
  catch {
    append opts {[options]} \n
    foreach opt [array names data] {
      if {$opt in {-size -geometry -background -zoom -pause -alpha -ontop}} {
        if {$opt eq "-geometry"} {
          set val [wm geometry $w]
        } else {
          set val $data($opt)
        }
        append opts "[string range $opt 1 end]=$val" \n
      }
    }
    set chan [open $data(-inifile) w]
    puts -nonewline $chan $opts
    close $chan
  }
}

# ________________________ Save / restore options _________________________ #

proc ::aloupe::my::RestoreOptions {} {
  # Restores options of appearance from a file.

  variable data
  if {!$data(-save)} return
  if {![file exists $data(-inifile)]} return
  set chan [open $data(-inifile)]
  set data(CONFIG) [read $chan]
  close $chan
  set svd $data(DEFAULTS)
  foreach line [split $data(CONFIG) \n] {
    if {[string match "*=*" $line]} {
      set opt -[string range $line 0 [string first = $line]-1]
      set val [string range $line [string length $opt] end]
      set ${svd}($opt) [set data($opt) $val]
    }
  }
}
#_______________________

proc ::aloupe::my::Save {} {
  # Saves the magnified image to a file.

  variable data
  if {![IsCapture]} return
  wm withdraw $data(WLOUP)
  set filetypes { {"PNG Images" .png} {"All Image Files" {.png .gif}} }
  set file [file tail $::aloupe::filename]
  set argl [list -parent $data(WDISP) -title [::msgcat::mc "Save the Loupe"] \
    -filetypes $filetypes -defaultextension .png -initialfile $file]
  if {$data(-fcgeom) ne {}} {
    set file [::apave::obj chooser tk_getSaveFile ::aloupe::filename {*}$argl]
  } else {
    catch {::apave::obj themeExternal "$data(WLOUP)*"}  ;# theme the file chooser
    set file [tk_getSaveFile {*}$argl]
  }
  if {$file ne ""} {
    set ::aloupe::filename $file
    if {![regexp -nocase {\.(png|gif)$} $file -> ext]} {
      set ext "png"
      append file ".${ext}"
    }
    if {[catch {$data(IMAGE) write $file -format [string tolower $ext]} err]} {
      Message -title "Error Writing File" -icon error \
        -message "Error writing to file \"$file\":\n$err"
    }
  }
  ShowLoupe
}
#_______________________

proc ::aloupe::my::Exit {} {
  # Clears all and exits.

  variable data
  SaveOptions
  if {$data(-exit)} exit
  SaveGeometry
  catch {image delete $data(IMAGE)}
  catch {image delete $data(CAPTURE)}
  catch {destroy $data(WDISP)}
  catch {
    wm withdraw $data(WLOUP)
    destroy $data(WLOUP)
  }
}
# __________________________ Interface procs ____________________________ #

proc ::aloupe::option {opt} {
  # Returns a value of aloupe option.
  #   opt - the option's name

  variable data
  return $data($opt)
}
#_______________________

proc ::aloupe::run {args} {
  # Runs the loupe.
  #  args - options of the loupe

  if {$::aloupe::starterr} {
    RunSolo
    return
  }
  variable my::data
  variable my::size
  variable my::zoom
  # save the default settings of aloupe
  set data(-commandname) ""
  if {![info exists my::data(DEFAULTS)]} {
    set defar ::aloupe::_DEFAULTS_
    array set $defar [array get my::data]
    set my::data(DEFAULTS) $defar
  }
  catch {set my::data(-inifile) [dict get $args -inifile]}
  catch {
    if {([dict exists $args -save] && [dict get $args -save]) || \
    (![dict exists $args -save] && $my::data(-save))} {
      my::RestoreOptions
    }
  }
  # restore the default settings of aloupe (for a 2nd/3rd... run)
  set svd $my::data(DEFAULTS)
  foreach an [array names $svd] {
    set my::data($an) [set ${svd}($an)] ;# "by variable address"
  }
  foreach {a v} $args {
    if {($v ne "" || $a in {-geometry -fcgeom}) && \
    [info exists my::data($a)] && [string is lower [string index $a 1]]} {
      set my::data($a) $v
    } else {
      puts "Bad option: $a \"$v\""
      my::Synopsis
    }
  }
  if {$my::data(-locale) ne {}} {
    catch {
      ::msgcat::mcload [file join [file dirname [info script]] msgs]
      ::msgcat::mclocale $my::data(-locale)
    }
  }
  catch {::apave::obj untouchWidgets "*_a_loupe_loup*"}  ;# don't theme the loupe
  set my::size [set my::data(PREVSIZE) $my::data(-size)]
  set my::zoom [set my::data(PREVZOOM) $my::data(-zoom)]
  set my::pause $my::data(-pause)
  set my::data(WDISP) "$data(-parent)._a_loupe_disp"
  set my::data(WLOUP) "$data(-parent)._a_loupe_loup"
  set my::data(LABEL) "$data(WDISP).label"
  set my::data(COLOR) [set data(CAPTURE) ""]
  my::Theme
  my::Create yes
}

# ___________________________ Stand-alone run ___________________________ #

if {$::aloupe::solo} {
  wm withdraw .
  catch {
    ttk::style config TButton -width 9 -buttonborder 1 -labelborder 0 -padding 1
  }
  ::aloupe::run {*}$::argv
}
# _________________________________ EOF _________________________________ #
#-ARGS1: -locale ua -alpha .2 -background "yellow" -ontop 1 -save 1 -commandname "Get"
#-RUNF1: ~/PG/github/pave/tests/test2_pave.tcl 23 9 12 "small icons"
