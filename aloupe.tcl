#! /usr/bin/env tclsh
# _______________________________________________________________________ #
#
# This is a screen loupe.
#
# Scripted by Alex Plotnikov (https://aplsimple.github.io).
#
# See README.md for details.
#
# License: MIT.
# _______________________________________________________________________ #

package require Tk
#lappend auto_path C:/ActiveTcl/lib/treectrl2.4.1
#lappend auto_path /usr/lib/treectrl2.4.1
package require treectrl
#lappend auto_path C:/ActiveTcl/lib/Img1.4.6
#lappend auto_path /usr/lib/tcltk/x86_64-linux-gnu/Img1.4.9
package require Img
::msgcat::mcload [file join [file dirname [info script]] msgs]

package provide aloupe 0.8.2

# _______________________________________________________________________ #

namespace eval ::aloupe {
  namespace eval my {
    variable size 26
    variable zoom 8
    variable data
    array set data [list \
      -size $size \
      -zoom $zoom \
      -alpha 0.3 \
      -background #ff40ff \
      -exit yes \
      -command "" \
      -ontop yes \
      -geometry "" \
      -parent "" \
    ]
  }
}
# ___________________________ Internal procs ____________________________ #

proc ::aloupe::my::Synopsis {} {
  # Short info about usage.

  puts "
Syntax:
  tclsh aloupe.tcl ?option value ...?
where 'option' may be -size, -zoom, -alpha, -background, -exit, -command, -ontop.
"
}
# ______

proc ::aloupe::my::Message {args} {
  # Displays a message, with the loupe hidden.

  variable data
  wm withdraw $data(WLOUP)
  tk_messageBox -parent $data(WDISP) -type ok {*}$args
  wm deiconify $data(WLOUP)
}
# ______

proc ::aloupe::my::CreateDisplay {} {
  # Creates the displaying window.

  variable data
  set data(IMSIZE) [expr {2*$data(-size)*$data(-zoom)}]
  set data(IMAGE) [image create photo -width $data(IMSIZE) -height $data(IMSIZE)]
  toplevel $data(WDISP)
  wm title $data(WDISP) [::msgcat::mc Loupe]
  $data(WDISP) configure -background [ttk::style configure . -background]
  grid [ttk::label $data(WDISP).lab1 -text " [::msgcat::mc Size]"] -row 0 -column 0 -sticky e
  grid [ttk::spinbox $data(WDISP).sp1 -from 8 -to 256 -justify center \
    -width 4 -textvariable ::aloupe::my::size -command ::aloupe::my::SizeLoupe] \
    -row 0 -column 1 -sticky w
  grid [ttk::label $data(WDISP).lab2 -text " [::msgcat::mc Zoom]"] -row 0 -column 2 -sticky e
  grid [ttk::spinbox $data(WDISP).sp2 -from 2 -to 32 -justify center \
    -width 2 -textvariable ::aloupe::my::zoom] -row 0 -column 3 -sticky w
  grid [ttk::separator $data(WDISP).sep1 -orient horizontal] -row 1 -columnspan 4 -sticky we -pady 2
  grid [ttk::label $data(LABEL) -image $data(IMAGE) -relief flat \
    -style [lindex [SetStyle TLabel no -bd 0] 1]] -row 2 -columnspan 4 -padx 2
  grid [ttk::button $data(WDISP).but1 -text [::msgcat::mc Save] \
    -command ::aloupe::my::Save] -row 3 -column 0 -columnspan 2 -sticky ew
  set data(BUT2) $data(WDISP).but2
  grid [ttk::button $data(BUT2) -text [::msgcat::mc "To clipboard"] \
    -command ::aloupe::my::Button2Click] -row 3 -column 2 -columnspan 2 -sticky ew
  set data(-geometry) [regexp -inline \\+.* $data(-geometry)]
  if {$data(-geometry) ne ""} {
    wm geometry $data(WDISP) $data(-geometry)
  } elseif {$data(-parent) ne ""} {
    ::tk::PlaceWindow $data(WDISP) widget $data(-parent)
  } else {
    ::tk::PlaceWindow $data(WDISP)
  }
  if {![info exists data(BUTCFG)]} {
    set defargs [list \
      -foreground [ttk::style configure . -foreground] \
      -background [ttk::style configure . -background] ]
    set data(BUTCFG) [StyleButton2 no {*}$defargs]
    lappend data(BUTCFG) {*}$defargs -text [$data(BUT2) cget -text]
  }
  bind $data(LABEL) <ButtonPress-1> {::aloupe::my::PickColor %W %X %Y}
  bind $data(WDISP) <Escape> exit
  wm resizable $data(WDISP) 0 0
  wm protocol $data(WDISP) WM_DELETE_WINDOW ::aloupe::my::Exit
  if {$data(-ontop)} {wm attributes $data(WDISP) -topmost 1}
}
# ______

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
    -relief flat -bd 0 -highlightthickness 2 -highlightbackground red
  pack $canvas -fill both -expand true
  bind $canvas <ButtonPress-1>   {::aloupe::my::DragStart %W %X %Y}
  bind $canvas <B1-Motion>       {::aloupe::my::Drag %W %X %Y}
  bind $canvas <ButtonRelease-1> {::aloupe::my::DragEnd %W}
  bind $canvas <Escape>          {::aloupe::my::Exit}
  after 50 "
    ::aloupe::my::InitGeometry $geom
    wm deiconify $data(WLOUP)
    wm attributes $data(WLOUP) -topmost 1 -alpha $data(-alpha)
    "
}
# ______

proc ::aloupe::my::Create {} {
  # Initializes and creates the utility's windows.

  variable data
  catch {destroy $data(WLOUP)}
  catch {destroy $data(WDISP)}
  set data(WLOUP) "$data(-parent)._a_loupe_loup"
  set data(WDISP) "$data(-parent)._a_loupe_disp"
  set data(LABEL) "$data(WDISP).label"
  set data(COLOR) [set data(CAPTURE) ""]
  catch {image delete $data(IMAGE)}
  if {[set wgr [grab current]] ne ""} {grab release $wgr}
  CreateDisplay
  CreateLoupe
  set data(PREVZOOM) $data(-zoom)
  set data(PREVSIZE) $data(-size)
  focus $data(WDISP)
}
# ______

proc ::aloupe::my::DragStart {w X Y} {
  # Initializes the frag-and-drop of the loupe.
  #   w - the loupe window's path 
  #   X - X-coordinate of the mouse pointer
  #   Y - Y-coordinate of the mouse pointer

  variable data
  variable size
  variable zoom
  set data(FOCUS) [focus]
  focus -force $data(WDISP)
  set data(-size) $size
  set data(-zoom) $zoom
  if {$data(PREVZOOM) != $data(-zoom) || $data(PREVSIZE) != $data(-size)} {
    SaveGeometry
    Create
    catch {unset data(dragX)}  ;# no drag-n-drop, update the loupe only
    update
    return
  }
  set data(COLOR) [set data(CAPTURE) ""]
  StyleButton2 no {*}$data(BUTCFG)
  InitGeometry
  update
  set data(dragX) [expr {$X - [winfo rootx $w]}]
  set data(dragY) [expr {$Y - [winfo rooty $w]}]
  set data(dragw) [winfo width $w]
  set data(dragh) [winfo height $w]
}
# ______

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
# ______

proc ::aloupe::my::DragEnd {w} {
  # Ends the frag-and-drop of the loupe and displays its magnified image.
  #   w - the loupe window's path 

  variable data
  if {![info exists data(dragX)]} return
  wm withdraw $data(WLOUP)
  if {!$data(-ontop) && ![string match $data(WDISP)* $data(FOCUS)] &&
  $::tcl_platform(platform) eq "unix"} {
    # the disp window can be overlapped by others => it should be deiconified
    wm withdraw $data(WDISP)
  }
  set curX [winfo rootx $w]
  set curY [winfo rooty $w]
  set curW [winfo width $w]
  set curH [winfo height $w]
  catch {image delete $data(CAPTURE)}
  set data(CAPTURE) [image create photo -width $curW -height $curH]
  set zoom 1
  set loupe_ctr_x [expr {$curX + $curW / 2}]
  set loupe_ctr_y [expr {$curY + $curH / 2}]
  after 40 "loupe $data(CAPTURE) $loupe_ctr_x $loupe_ctr_y $curW $curH $zoom"
  after 50
  update   ;# enough time to hide the window and capture the image
  after 50
  catch {
    $data(IMAGE) copy $data(CAPTURE) \
      -from 0 0 [expr {2*$data(-size)}] [expr {2*$data(-size)}] \
      -to 0 0 $data(IMSIZE) $data(IMSIZE) -zoom $data(-zoom)
  }
  wm deiconify $data(WDISP)
  wm deiconify $data(WLOUP)
  focus -force $data(WDISP).but2
  set data(-PREVGEOM) [wm geometry $data(WLOUP)]
}
# ______

proc ::aloupe::my::SizeLoupe {} {
  # Re-displays the loupe at changing its size.

  variable data
  variable size
  set data(-size) $size
  lassign [split [winfo geometry $data(LABEL)] x+] w1
  lassign [split $data(-PREVGEOM) x+] w2 h2 x2 y2
  set w [expr {int(2.0*$size*$data(-zoom)*$w2/$w1)}]  ;# count the previous zoom
  destroy $data(WLOUP)
  CreateLoupe ${w}x${w}+$x2+$y2
}
# ______

proc ::aloupe::my::InitGeometry {{geom ""}} {
  # Gets and sets the geometry of the loupe window,
  # based on the image label's sizes and the zoom factor.
  #   geom - the predefined geometry

  variable data
  if {$geom eq ""} {
    lassign [split [winfo geometry $data(LABEL)] x+] w h
    set w [expr {int($w/$data(-zoom))}]
    set h [expr {int($h/$data(-zoom))}]
    lassign [winfo pointerxy .] x y
    set x [expr {$x-$w/2}]
    set y [expr {$y-$h/2}]
    set geom ${w}x${h}+$x+$y
    if {$w>0 && $h>0 && $x>-$w && $y>-$h} {
      set data(-PREVGEOM) $geom
    }
  }
  wm geometry $data(WLOUP) $geom
}
# ______

proc ::aloupe::my::SaveGeometry {} {
  # Saves the displaying window's geometry.

  variable data
  set data(-geometry) ""
  catch {set data(-geometry) [wm geometry $data(WDISP)]}
}
# ______

proc ::aloupe::my::SetStyle {type domap args} {
  # Sets a style for of widgets with a type.
  #   'type - the type of widgets
  #   domap - yes, if set the map options
  #   args - configuration options
  # Returns a list of old type's configuration and new type's name.

  set config [ttk::style configure TButton]
  set new ${type}_A_LOUPE
  ttk::style configure $new {*}$config
  ttk::style configure $new {*}$args
  if {$domap} {
    ttk::style map $new {*}[ttk::style map $type]
    set fg [dict get $args -foreground]
    set bg [dict get $args -background]
    ttk::style map $new -foreground [list pressed $fg active $fg alternate $fg focus $fg selected $fg]
    ttk::style map $new -background [list pressed $bg active $bg alternate $bg focus $bg selected $bg]
  } else {
    ttk::style map $new -foreground [list]
    ttk::style map $new -background [list]
    ttk::style map $new {*}[ttk::style map $type]
  }
  ttk::style layout $new [ttk::style layout $type]
  return [list $config $new]
}
# ______

proc ::aloupe::my::StyleButton2 {domap args} {
  # Makes a style for Tbutton.
   #  domap - yes, if set the map options
  #   args - options ("name value" pairs)
  # Returns the TButton's configuration options.

  variable data
  if {[dict exists $args -text]} {
    $data(BUT2) configure -text [dict get $args -text]
    set args [dict remove $args -text]
  }
  lassign [SetStyle TButton $domap {*}$args] config style
  $data(BUT2) configure -style $style
  return $config
}
# ______

proc ::aloupe::my::Button2Click {} {
  # Processes the click on 'Clipboard' button.

  variable data
  if {$data(COLOR) ne ""} {
    StyleButton2 yes -background $data(INVCOLOR) -foreground $data(COLOR)
    update idletasks
    after 60 ;# just to make the click visible
  }
  if {[HandleColor] && !$data(-exit) && $data(-command) ne ""} {
    SaveGeometry
    {*}[string map [list %c $data(COLOR)] $data(-command)]
  }
}
# ______

proc ::aloupe::my::IsCapture {} {
  # Checks if the image was captured.

  variable data
  if {$data(CAPTURE) eq ""} {
    Message -title "Color of Image" -icon warning \
      -message "Click, then drag and drop\nthe loupe to get the image."
    return no
  }
  return yes
}
# ______

proc ::aloupe::my::InvertBg {r g b} {
  # Inverts colors from light to dark and vice versa to get "fg" from "bg".
  # It's simplified way, just to not include the bulky HSV code.
  #  r - red component
  #  g - green component
  #  b - blue component
  # Returns {R G B} list of inverted colors.

  set c [expr {$r<100 && $g<100 || $r<100 && $b<100 || $b<100 && $g<100 ||
    ($r+$g+$b)<300 ? 255 : 0}]
  return [list $c $c $c]
}
# ______

proc ::aloupe::my::HandleColor {{doclb yes}} {
  # Processes the image color under the mouse pointer,
  # optionally saving it to the clipboard.
  #   doclb - if 'yes', means "put the color into the clipboard"
  # Returns 'yes' if the color was chosen.

  variable data
  set res no
  if {[IsCapture]} {
    if {$data(COLOR) eq ""} {
      Message -title "Color of Image" -icon warning \
        -message "Click the magnified image\nto get a pixel's color.\n\nThen hit this button."
    } else {
      if {$doclb} {
        clipboard clear
        clipboard append -type STRING $data(COLOR)
      }
      StyleButton2 yes -background $data(COLOR) -foreground $data(INVCOLOR) \
        -text $data(COLOR)
      set res yes
    }
  }
  return $res
}
# ______

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
    set data(INVCOLOR) [format "#%02x%02x%02x" {*}[InvertBg $r $g $b]]
    HandleColor no
  }
}
# ______

proc ::aloupe::my::Save {} {
  # Saves the magnified image to a file.

  variable data
  if {![IsCapture]} return
  wm withdraw $data(WLOUP)
  set filetypes { {"PNG Images" .png} {"All Image Files" {.png .gif}} }
  catch {::apave::obj themeExternal "$data(WLOUP)*"}  ;# theme the file chooser
  set file [tk_getSaveFile -parent $data(WDISP) \
    -title [::msgcat::mc "Save the Loupe"] -filetypes $filetypes]
  if {$file ne ""} {
    if {![regexp -nocase {\.(png|gif)$} $file -> ext]} {
      set ext "png"
      append file ".${ext}"
    }
    if {[catch {$data(IMAGE) write $file -format [string tolower $ext]} err]} {
      Message -title "Error Writing File" -icon error \
        -message "Error writing to file \"$file\":\n$err"
    }
  }
  wm deiconify $data(WLOUP)
}
# ______

proc ::aloupe::my::Exit {} {
  # Clears all and exits.

  variable data
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
# ______

proc ::aloupe::run {args} {
  # Runs the loupe.
  #  args - options of the loupe

  variable my::data
  variable my::size
  variable my::zoom
  # save the default settings of aloupe
  if {![info exists my::data(DEFAULTS)]} {
    set my::data(DEFAULTS) ::aloupe::_DEFAULTS_
    array set $my::data(DEFAULTS) [array get my::data]
  }
  # restore the default settings of aloupe (for a 2nd/3rd... run)
  set svd $my::data(DEFAULTS)
  foreach an [array names $svd)] {
    set my::data($an) [set ${svd}($an)] ;# a bit of addresses
  }
  foreach {a v} $args {
    if {($v ne "" || $a in {-geometry}) && \
    [info exists my::data($a)] && [string is lower [string index $a 1]]} {
      set my::data($a) $v
    } else {
      puts "Bad option: $a \"$v\""
      my::Synopsis
      my::Exit
      return
    }
  }
  catch {::apave::obj untouchWidgets "*_a_loupe_loup*"}  ;# don't theme the loupe
  set my::size [set my::data(PREVSIZE) $my::data(-size)]
  set my::zoom [set my::data(PREVZOOM) $my::data(-zoom)]
  my::Create
}
# ___________________________ Stand-alone run ___________________________ #

if {[info exist ::argv0] && [file normalize $::argv0] eq [file normalize [info script]]} {
  wm withdraw .
  catch {
    ttk::style theme use clam
    ttk::style config TButton -width 9 -buttonborder 1 -labelborder 0 -padding 1
  }
  ::aloupe::run {*}$::argv
}
# _________________________________ EOF _________________________________ #
#ARGS1: -size 20 -zoom 10 -alpha .2 -background "yellow" -ontop 0
#-RUNF1: ~/PG/github/pave/tests/test2_pave.tcl 23 9 12 "small icons"
