+================================================
+                                                
+ Buildbotics  - Vectric machine output configuration file   
+                                                
+================================================
+                                                
+ History                                        
+                                                  
+ Who      When       What                         
+ ======== ========== ===========================
+ Doug C.  11/5/19    Copied buildbotics_mm, changed to inches, changed accuracy to 1.4, changed G21 to G20
+ ======== ========== ===========================

POST_NAME = "Buildbotics No Jet (inches) (*.gcode)"
 
FILE_EXTENSION = "ngc"
 
UNITS = "INCHES"
 
+------------------------------------------------
+    Line terminating characters                 
+------------------------------------------------
 
LINE_ENDING = "[13][10]"
 
+------------------------------------------------
+    Block numbering                             
+------------------------------------------------
 
LINE_NUMBER_START     = 0
LINE_NUMBER_INCREMENT = 10
LINE_NUMBER_MAXIMUM = 9999999
 
+================================================
+                                                
+    Formatting for variables                     
+                                                
+================================================
 
VAR LINE_NUMBER = [N|A|N|1.0]
VAR SPINDLE_SPEED = [S|A| S|1.0]
VAR FEED_RATE = [F|C|F|1.1]
VAR X_POSITION = [X|C|X|1.4]
VAR Y_POSITION = [Y|C|Y|1.4]
VAR Z_POSITION = [Z|C|Z|1.4]
VAR ARC_CENTRE_I_INC_POSITION = [I|A|I|1.4]
VAR ARC_CENTRE_J_INC_POSITION = [J|A|J|1.4]
VAR X_HOME_POSITION = [XH|A| X|1.4]
VAR Y_HOME_POSITION = [YH|A| Y|1.4]
VAR Z_HOME_POSITION = [ZH|A| Z|1.4]
VAR SAFE_Z_HEIGHT = [SAFEZ|A| Z|1.4]
 
+================================================
+                                                
+    Block definitions for toolpath output       
+                                                
+================================================
 
+---------------------------------------------------
+  Commands output at the start of the file
+---------------------------------------------------
 
begin HEADER
 
"%" 
"T[T] M6"
"G0 G17 G20 G90 G40 G49 G64 P0.001"
"G0[ZH]"
"G0[XH][YH] M03[S]"
"M0(MSG, Click 'Continue' when the spindle is up to speed)"

+---------------------------------------------------
+  Commands output at toolchange
+---------------------------------------------------

begin TOOLCHANGE

"G0[ZH]"
"G0[XH][YH]"
"M05"
"M06 T[T]"

+---------------------------------------------------
+  Commands output for a new segment - toolpath
+  with same toolnumber but maybe different feedrates
+---------------------------------------------------

begin NEW_SEGMENT

"G0[SAFEZ] M03[S]"
"M0(MSG, Click 'Continue' when the spindle is up to speed)"



+---------------------------------------------------
+  Commands output for rapid moves 
+---------------------------------------------------
 
begin RAPID_MOVE
 
"G0[X][Y][Z]"
 
 
+---------------------------------------------------
+  Commands output for the first feed rate move
+---------------------------------------------------
 
begin FIRST_FEED_MOVE
 
"G1[X][Y][Z][F]"
 
 
+---------------------------------------------------
+  Commands output for feed rate moves
+---------------------------------------------------
 
begin FEED_MOVE
 
"G1[X][Y][Z]"
 
 
+---------------------------------------------------
+  Commands output for the first clockwise arc move
+---------------------------------------------------

begin FIRST_CW_ARC_MOVE

"G2[X][Y][I][J][F]"
 
 
+---------------------------------------------------
+  Commands output for clockwise arc  move
+---------------------------------------------------
 
begin CW_ARC_MOVE
 
"G2[X][Y][I][J]"
 
 
+---------------------------------------------------
+  Commands output for the first counterclockwise arc move
+---------------------------------------------------
 
begin FIRST_CCW_ARC_MOVE
 
"G3[X][Y][I][J][F]"
 
 
+---------------------------------------------------
+  Commands output for counterclockwise arc  move
+---------------------------------------------------
 
begin CCW_ARC_MOVE
 
"G3[X][Y][I][J]"
 
+---------------------------------------------------
+  Commands output at the end of the file
+---------------------------------------------------
 
begin FOOTER

"M5"
"G0[ZH]"
"G0[XH][YH]"
"M2"