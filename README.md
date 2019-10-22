# buildbotics-fusion360-post
Post processor for fusion 360

Just select 'builbotics.cps' as your post processor from within Fusion 360.

<img src="images/F360_PP.png" >

A few new feature were added to the property table in the Fusion 360 post processor dialog.

<img src = "images/F360_PP_PROPERTY_TABLE.png">

The "Optional Stop" option was added because the Buildbotics Controller currently ignores
the 'M1' command. This was made optional because 'M1' will be supported in a future release.

The default value for "Enable tool length compensation" was set to "No" because the Buildbotics
Controller does not current support this capability. It is planned for a future release.

"Write Simulation Data" was added because this post processor will automatically generate
simulation commands that are compatible with the CutViewer CNC simulator. Setting this to "Yes"
puts this simulation in the comments in the g-code file.

"Set Z-axis retract height" feature was added to avoid confusion about retract height. 

Modified the writeRetact program to simply make a rapid move (G0) to the retract height specified by the "Set Z-Axis retract height value".

## Probing support added on 10/10/19
The following types of probing are now supported:
  * probing-xy-outer-corner
  * probing-x
  * probing-y
  * probing-z
