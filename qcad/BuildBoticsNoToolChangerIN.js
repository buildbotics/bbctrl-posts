/**
 * This file generated by Chuck Tilbury Sept. 2019
 * 
 * This is a postprocessor for the Masso controller.
 */
include("GCodeBase.js");

function BuildBoticsNoToolChangerIN(cadDocumentInterface, camDocumentInterface) {
    GCodeBase.call(this, cadDocumentInterface, camDocumentInterface);

    this.decimals = 4;
    this.unit = RS.Inch;
    this.outputOffsetPath = true;
    this.fileExtensions = ["nc"]
    this.lineNumber = 1000;
    this.lineNumberIncrement = 10;
    

    this.header = [
		"(Program name: [PROGRAM_NAME])",
		"(Imperial measure)",
		"(File: [FILENAME] -- [DATETIME])",
		"",
        "[N] G20 G17 G90 G80"
    ];

    this.footer = [
        "[N] M05",      // stop the spindle
        "[N] G0 X0 Y0", // reset to start location
        "[N] M30", 		// rewind the program
        "(end program)",
        "" 
    ]; 
    
    this.toolpathHeader = [
		"",
		"(Begin Tool Path [TOOLPATH_INDEX]: [TOOLPATH_NAME])"
    ];
    
    this.toolpathFooter = [
		"(End Tool Path [TOOLPATH_INDEX]: [TOOLPATH_NAME])",
		""
    ];
    
}

// Configuration is derived from GCodeBase:
BuildBoticsNoToolChangerIN.prototype = new GCodeBase();

// Display name shown in user interface:
BuildBoticsNoToolChangerIN.displayName = "BuildBoticsNoToolChanger[in]";
