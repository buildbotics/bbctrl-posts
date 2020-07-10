/**
  Copyright (C) 2012-2018 by Autodesk, Inc.
  All rights reserved.

  RS-274D post processor configuration with modifications for Buildbotics Controller.

  $Revision: 42145 3ef6ef136f68132df4d932bf16f29ac1ec1b893b $
  $Date: 2018-09-28 16:13:20 $
  
  FORKID {2EECF092-D7C3-4ACA-BFE6-377B72950FE9}
*/

/* The following changes were made from the original RS-274D post processor that was provided by Autodesk.
(See the comments at the named function where changes were made for more info)
1. Disabled "Canned Cycles" by causing immediate expand and return at OnCyclePoint
2. Set "Optional Stop" property default to "false" because M1 commands are not implemented at this time. We can change this back to "true" when the optional
stop button is added to the user interface.
3. Set post to generate a warning suggesting that user use "In Computer" in passes dialogue if cutter compensation is encountered
and generate and error and exit if cutter compensation is encountered.
*/

description = "Buildbotics 4-Axis CNC Controller";
vendor = "Buildbotics LLC";
vendorUrl = "http://www.buildbotics.com";
model = "";
legal = "Copyright (C) 2012-2018 by Autodesk, Inc.";
certificationLevel = 2;
minimumRevision = 40783;

longDescription = "Generic post for the Buildbotics Controller. It was derived from the RS-274D Post provided by Autodesk.";

extension = "nc";
setCodePage("ascii");

capabilities = CAPABILITY_MILLING;
tolerance = spatial(0.002, MM);

minimumChordLength = spatial(0.25, MM);
minimumCircularRadius = spatial(0.01, MM);
maximumCircularRadius = spatial(1000, MM);
minimumCircularSweep = toRad(0.01);
maximumCircularSweep = toRad(180);
allowHelicalMoves = true;
allowedCircularPlanes = undefined; // allow any circular motion

// user-defined properties
properties = {
  writeMachine: true, // write machine
  writeSimData: true,
  writeTools: true, // writes the tools
  preloadTool: true, // preloads next tool on tool change if any
  showSequenceNumbers: true, // show sequence numbers
  sequenceNumberStart: 10, // first sequence number
  sequenceNumberIncrement: 5, // increment for sequence numbers
  optionalStop: false, // optional stop - Set to false for Buildbotics because no action is taken on M1 commands. We can change this back to true when the optional pause button is added to the user interface
                       // This generates an error if set to true and suggests that user change it in the Post Process dialoge
  separateWordsWithSpace: true, // specifies that the words should be separated with a white space
  toolLengthCompensation: false, //Added for Buildbotics, specifies whether to use tool length compensation. Buildbotics controller does not have a tool table so users will have to keep track of this manually if they use it
  skipFirstToolChange: false, //Added for customer that wanted to bypass first tool change because he puts the tool in himself before starting the program
  zRetractHeight: 10,
  disableCoolantControl: false

};

// user-defined property definitions
propertyDefinitions = {
  writeMachine: {title:"Write machine", description:"Output the machine settings in the header of the code.", group:0, type:"boolean"},
  writeSimData: {title:"Write Simulation Data",description:"Outputs strarting location, stock, and tool info in CutViewer simulation format",group:0,type:"boolean"},
  writeTools: {title:"Write tool list",description:"Output a tool list in the header of the code.",group:0, type:"boolean"},
/*  writeTools: {
    title:"Write tool list",
    description:"Output a tool list in the header of the code.",
    group:0, 
    type:"enum",
    values:[{title: "Do not write tools", id:"none"},
            {title: "Autodesk format", id: "Autodesk"},
            {title: "CutViewer format", id: "CutViewer"},
            {title: "both", id: "both"}]
  },*/
  preloadTool: {title:"Preload tool", description:"Preloads the next tool at a tool change (if any).", type:"boolean"},
  showSequenceNumbers: {title:"Use sequence numbers", description:"Use sequence numbers for each block of outputted code.", group:1, type:"boolean"},
  sequenceNumberStart: {title:"Start sequence number", description:"The number at which to start the sequence numbers.", group:1, type:"integer"},
  sequenceNumberIncrement: {title:"Sequence number increment", description:"The amount by which the sequence number is incremented by in each block.", group:1, type:"integer"},
  optionalStop: {title:"Optional stop", description:"Outputs optional stop code during when necessary in the code.", type:"boolean"},
  separateWordsWithSpace: {title:"Separate words with space", description:"Adds spaces between words if 'yes' is selected.", type:"boolean"},
  toolLengthCompensation: {title: "Enable tool length compensation",
    description: "Causes z-axis positions to be automatically adjusted for changing tool length if 'yes' is selected",
    type:"boolean"},
  skipFirstToolChange: {title:"Skip first tool change",
                        description: "if yes, tool change on the first section will be skipped",
						type:"boolean"},
  zRetractHeight: {title:"Set Z-axis retract height",
                   description: "Hard codes the z-axis retract height. This is important when skipping first tool change.",
				   type:"number"},
  disableCoolantControl: {title:"Disable coolant control",
						  description: "Set to yes to disable coolant control commands in the GCode program. Set this to true if the Load1 or Load2 outputs on the Buildbotics Controller are used for something other than coolant control",
						  type: "boolean"}
};

var permittedCommentChars = " ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,=_-";

var 
numberOfToolSlots = 9999;

// samples:
// throughTool: {on: 88, off: 89}
// throughTool: {on: [8, 88], off: [9, 89]}
var coolants = {
  flood: {on: 8},
  mist: {on: 7},
  throughTool: {},
  air: {},
  airThroughTool: {},
  suction: {},
  floodMist: {},
  floodThroughTool: {},
  off: 9
};

var gFormat = createFormat({prefix:"G", decimals:0});
var mFormat = createFormat({prefix:"M", decimals:0});
var hFormat = createFormat({prefix:"H", decimals:0});
var dFormat = createFormat({prefix:"D", decimals:0});

var xyzFormat = createFormat({decimals:(unit == MM ? 3 : 4)});
var abcFormat = createFormat({decimals:3, forceDecimal:true, scale:DEG});
var feedFormat = createFormat({decimals:(unit == MM ? 1 : 2)});
var toolFormat = createFormat({decimals:0});
var toolProbeFormat = createFormat({decimals:0, zeropad:true, width:3});
var rpmFormat = createFormat({decimals:0});
var secFormat = createFormat({decimals:3, forceDecimal:true}); // seconds - range 0.001-1000
var taperFormat = createFormat({decimals:1, scale:DEG});

var xOutput = createVariable({prefix:"X"}, xyzFormat);
var yOutput = createVariable({prefix:"Y"}, xyzFormat);
var zOutput = createVariable({onchange:function () {retracted = false;}, prefix:"Z"}, xyzFormat);
var aOutput = createVariable({prefix:"A"}, abcFormat);
var bOutput = createVariable({prefix:"B"}, abcFormat);
var cOutput = createVariable({prefix:"C"}, abcFormat);
var feedOutput = createVariable({prefix:"F"}, feedFormat);
var sOutput = createVariable({prefix:"S", force:true}, rpmFormat);
var dOutput = createVariable({}, dFormat);

// circular output
var iOutput = createReferenceVariable({prefix:"I"}, xyzFormat);
var jOutput = createReferenceVariable({prefix:"J"}, xyzFormat);
var kOutput = createReferenceVariable({prefix:"K"}, xyzFormat);

var gMotionModal = createModal({}, gFormat); // modal group 1 // G0-G3, ...
var gPlaneModal = createModal({onchange:function () {gMotionModal.reset();}}, gFormat); // modal group 2 // G17-19
var gAbsIncModal = createModal({}, gFormat); // modal group 3 // G90-91
var gFeedModeModal = createModal({}, gFormat); // modal group 5 // G93-94
var gUnitModal = createModal({}, gFormat); // modal group 6 // G20-21
var gCycleModal = createModal({}, gFormat); // modal group 9 // G81, ...
var gRetractModal = createModal({}, gFormat); // modal group 10 // G98-99

var WARNING_WORK_OFFSET = 0;

// collected state
var sequenceNumber;
var currentWorkOffset;
var retracted = false; // specifies that the tool has been retracted to the safe plane

var gParams = new Object();

function onParameter(name, value) {
  gParams[name] = value;
}

function getParam(name) {
  var key = "operation:" + name;
  if (key in gParams) {
    return gParams[key].toFixed(3);
  }
  return "?";
}

function getParVal(p) {
  var result;
  result = getGlobalParameter(p) * (unit == MM ? 1 : 1/25.4);
  return result.toFixed(3);
}

/**
 * Writes the STOCK and FROM lines into comments in G-Code output
 */
function showSim() {
  var lowX = getParVal("stock-lower-x");
  var highX = getParVal("stock-upper-x");
  var lowY = getParVal("stock-lower-y");
  var highY = getParVal("stock-upper-y");
  var lowZ = getParVal("stock-lower-z");
  var highZ = getParVal("stock-upper-z");
  writeln("");
  writeln("(Simulation Data)");
  writeln("(STOCK/BLOCK, " +
          Math.abs(highX - lowX) + ", " + 
          Math.abs(highY - lowY) + ", " + 
          Math.abs(highZ - lowZ) + ", " +
          -lowX +", " + -lowY + ", " + -lowZ + ")");
  writeln("(FROM/0,0," + getParVal("operation:clearanceHeight_value") + ")");
}
/**
  Writes the specified block.
*/
function writeBlock() {
  if (!formatWords(arguments)) {
    return;
  }
  if (properties.showSequenceNumbers) {
    writeWords2("N" + sequenceNumber, arguments);
    sequenceNumber += properties.sequenceNumberIncrement;
  } else {
    writeWords(arguments);
  }
}

function formatComment(text) {
  return "(" + filterText(String(text).toUpperCase(), permittedCommentChars) + ")";
}

/**
  Output a comment.
*/
function writeComment(text) {
  writeln(formatComment(text));
}

function onOpen() {
  if (!machineConfiguration.isMachineCoordinate(0)) {
    aOutput.disable();
  }
  if (!machineConfiguration.isMachineCoordinate(1)) {
    bOutput.disable();
  }
  if (!machineConfiguration.isMachineCoordinate(2)) {
    cOutput.disable();
  }
  
  if (!properties.separateWordsWithSpace) {
    setWordSeparator("");
  }

  sequenceNumber = properties.sequenceNumberStart;
  writeln("%");

  if (programName) {
    writeComment(programName);
  }
  if (programComment) {
    writeComment(programComment);
  }

  // dump machine configuration
 // var vendor = machineConfiguration.getVendor();
  var model = machineConfiguration.getModel();
//  var description = machineConfiguration.getDescription();

  if (properties.writeMachine && (vendor || model || description)) {
    writeComment(localize("Machine"));
    if (vendor) {
      writeComment("  " + localize("vendor") + ": " + vendor);
    }
    if (model) {
      writeComment("  " + localize("model") + ": " + model);
    }
    if (description) {
      writeComment("  " + localize("description") + ": "  + description);
    }
  }

  // output CutViewer simulation data
  if(properties.writeSimData) showSim();

  // output Autodesk tool information
  if (properties.writeTools) {
    var zRanges = {};
    if (is3D()) {
      var numberOfSections = getNumberOfSections();
      for (var i = 0; i < numberOfSections; ++i) {
        var section = getSection(i);
        var zRange = section.getGlobalZRange();
        var tool = section.getTool();
        if (zRanges[tool.number]) {
          zRanges[tool.number].expandToRange(zRange);
        } else {
          zRanges[tool.number] = zRange;
        }
      }
    }

    var tools = getToolTable();
    if (tools.getNumberOfTools() > 0) {
      writeln("");
      writeln("(Tools used)");
      for (var i = 0; i < tools.getNumberOfTools(); ++i) {
        var tool = tools.getTool(i);
        var comment = "T" + toolFormat.format(tool.number) + " " +
          "D=" + xyzFormat.format(tool.diameter) + " " +
          localize("CR") + "=" + xyzFormat.format(tool.cornerRadius);
        if ((tool.taperAngle > 0) && (tool.taperAngle < Math.PI)) {
          comment += " " + localize("TAPER") + "=" + taperFormat.format(tool.taperAngle) + localize("deg");
        }
        if (zRanges[tool.number]) {
          comment += " - " + localize("ZMIN") + "=" + xyzFormat.format(zRanges[tool.number].getMinimum());
        }
        comment += " - " + getToolTypeName(tool.type);
        writeComment(comment);
      }
    }
  }
 
  writeln("");

  if ((getNumberOfSections() > 0) && (getSection(0).workOffset == 0)) {
    for (var i = 0; i < getNumberOfSections(); ++i) {
      if (getSection(i).workOffset > 0) {
        error(localize("Using multiple work offsets is not possible if the initial work offset is 0."));
        return;
      }
    }
  }

  // absolute coordinates and feed per min
  writeBlock(gAbsIncModal.format(90), gFeedModeModal.format(94), "(Absolute distance mode; Feed in units per minute)");
  writeBlock(gPlaneModal.format(17), "(using XY plane)");

  switch (unit) {
  case IN:
    writeBlock(gUnitModal.format(20), "(Imperial Units)");
    break;
  case MM:
    writeBlock(gUnitModal.format(21), "(Metric Units)");
    break;
  }
}

function onComment(message) {
  writeComment(message);
}

/** Force output of X, Y, and Z. */
function forceXYZ() {
  xOutput.reset();
  yOutput.reset();
  zOutput.reset();
}

/** Force output of A, B, and C. */
function forceABC() {
  aOutput.reset();
  bOutput.reset();
  cOutput.reset();
}

/** Force output of X, Y, Z, A, B, C, and F on next output. */
function forceAny() {
  forceXYZ();
  forceABC();
  feedOutput.reset();
}

var currentWorkPlaneABC = undefined;

function forceWorkPlane() {
  currentWorkPlaneABC = undefined;
}

function setWorkPlane(abc) {
  if (!machineConfiguration.isMultiAxisConfiguration()) {
    return; // ignore
  }
  if (!((currentWorkPlaneABC == undefined) ||
        abcFormat.areDifferent(abc.x, currentWorkPlaneABC.x) ||
        abcFormat.areDifferent(abc.y, currentWorkPlaneABC.y) ||
        abcFormat.areDifferent(abc.z, currentWorkPlaneABC.z))) {
    return; // no change
  }

  onCommand(COMMAND_UNLOCK_MULTI_AXIS);

  if (!retracted) {
    writeRetract(Z);
  }

  writeBlock(
    gMotionModal.format(0),
    conditional(machineConfiguration.isMachineCoordinate(0), "A" + abcFormat.format(abc.x)),
    conditional(machineConfiguration.isMachineCoordinate(1), "B" + abcFormat.format(abc.y)),
    conditional(machineConfiguration.isMachineCoordinate(2), "C" + abcFormat.format(abc.z))
  );
  
  onCommand(COMMAND_LOCK_MULTI_AXIS);

  currentWorkPlaneABC = abc;
}

var closestABC = false; // choose closest machine angles
var currentMachineABC;

function getWorkPlaneMachineABC(workPlane) {
  var W = workPlane; // map to global frame

  var abc = machineConfiguration.getABC(W);
  if (closestABC) {
    if (currentMachineABC) {
      abc = machineConfiguration.remapToABC(abc, currentMachineABC);
    } else {
      abc = machineConfiguration.getPreferredABC(abc);
    }
  } else {
    abc = machineConfiguration.getPreferredABC(abc);
  }
  
  try {
    abc = machineConfiguration.remapABC(abc);
    currentMachineABC = abc;
  } catch (e) {
    error(
      localize("Machine angles not supported") + ":"
      + conditional(machineConfiguration.isMachineCoordinate(0), " A" + abcFormat.format(abc.x))
      + conditional(machineConfiguration.isMachineCoordinate(1), " B" + abcFormat.format(abc.y))
      + conditional(machineConfiguration.isMachineCoordinate(2), " C" + abcFormat.format(abc.z))
    );
  }
  
  var direction = machineConfiguration.getDirection(abc);
  if (!isSameDirection(direction, W.forward)) {
    error(localize("Orientation not supported."));
  }
  
  if (!machineConfiguration.isABCSupported(abc)) {
    error(
      localize("Work plane is not supported") + ":"
      + conditional(machineConfiguration.isMachineCoordinate(0), " A" + abcFormat.format(abc.x))
      + conditional(machineConfiguration.isMachineCoordinate(1), " B" + abcFormat.format(abc.y))
      + conditional(machineConfiguration.isMachineCoordinate(2), " C" + abcFormat.format(abc.z))
    );
  }

  var tcp = true;
  if (tcp) {
    setRotation(W); // TCP mode
  } else {
    var O = machineConfiguration.getOrientation(abc);
    var R = machineConfiguration.getRemainingOrientation(abc, W);
    setRotation(R);
  }
  
  return abc;
}

function isProbeOperation() {
  return (hasParameter("operation-strategy") &&
    getParameter("operation-strategy") == "probe");
}

function onSection() {
  var insertToolCall = isFirstSection() ||
    currentSection.getForceToolChange && currentSection.getForceToolChange() ||
    (tool.number != getPreviousSection().getTool().number);
  retracted = false; // specifies that the tool has been retracted to the safe plane
  
  var newWorkOffset = isFirstSection() ||
    (getPreviousSection().workOffset != currentSection.workOffset); // work offset changes
  var newWorkPlane = isFirstSection() ||
    !isSameDirection(getPreviousSection().getGlobalFinalToolAxis(), currentSection.getGlobalInitialToolAxis()) ||
    (currentSection.isOptimizedForMachine() && getPreviousSection().isOptimizedForMachine() &&
      Vector.diff(getPreviousSection().getFinalToolAxisABC(), currentSection.getInitialToolAxisABC()).length > 1e-4) ||
    (!machineConfiguration.isMultiAxisConfiguration() && currentSection.isMultiAxis()) ||
    (!getPreviousSection().isMultiAxis() && currentSection.isMultiAxis() ||
      getPreviousSection().isMultiAxis() && !currentSection.isMultiAxis()); // force newWorkPlane between indexing and simultaneous operations

  if (insertToolCall || newWorkOffset || newWorkPlane) {
    
    // stop spindle before retract during tool change
    if (insertToolCall && !isFirstSection()) {
      onCommand(COMMAND_STOP_SPINDLE);
    }

    // retract to safe plane
    writeRetract(Z);
    zOutput.reset();
  }

  writeln("");
  if (hasParameter("operation-comment")) {
    var comment = getParameter("operation-comment");
    if (comment) {
      writeComment(comment);
    }
  }

  if (isFirstSection() && properties.skipFirstToolChange) {
    writeRetract(Z)
  } else if (insertToolCall) {
    forceWorkPlane();
    
    setCoolant(COOLANT_OFF);
  
    if (!isFirstSection() && properties.optionalStop) {
      warning(localize("Optional stop not supported. Set 'Optional Stop' to 'No' in 'Post Process' dialog for setup"))
      error(localize("Optional Stop (M1) not supported"));
      return;
      onCommand(COMMAND_OPTIONAL_STOP);
    }

    if (tool.number > numberOfToolSlots) {
      warning(localize("Tool number exceeds maximum value."));
    }

    writeln("");
    switch (tool.getType()) {
    case TOOL_DRILL_SPOT:
    case TOOL_DRILL:
      writeln("(TOOL/DRILL, " + getParam("tool_diameter") + ", " +
                                getParam("tool_tipAngle") + ", " + 
                                getParam("tool_fluteLength") + ")");
                                
      break;
    case TOOL_DRILL_CENTER:
      writeln("(TOOL/CDRILL, " + getParam("tool_diameter") + ", " +
                                 getParam("tool_tipAngle") + ", " +
                                 getParam("tool_tipLength") + ", " + 
                                 getParam("tool_tipDiameter") + ", " +
                                 getParam("tool_taperAngle") + ", " + 
                                 getParam("tool_fluteLength") + ")");
        break;
    case TOOL_MILLING_END_BALL:
    case TOOL_MILLING_END_FLAT:
    case TOOL_MILLING_END_BULLNOSE:
    case TOOL_MILLING_FACE:
    case TOOL_MILLING_SLOT:
    case TOOL_MILLING_RADIUS:
    case TOOL_TAP_RIGHT_HAND:
    case TOOL_TAP_LEFT_HAND:
    case TOOL_REAMER:
      writeln("(TOOL/MILL, " + getParam("tool_diameter") + ", " +
                               getParam("tool_cornerRadius") + ", " +
                               getParam("tool_fluteLength") + ", " + 
                               getParam("tool_taperAngle") + ")");                           
      break;
    case TOOL_MILLING_CHAMFER:
      writeln("(TOOL/CHAMFER, " + getParam("tool_diameter") + ", " +
                                  getParam("tool_taperAngle") + ", " +
                                  getParam("tool_shoulderLength") + ", " +
                                  getParam("tool_fluteLength") + ")"  );
      break;
    case TOOL_COUNTER_SINK:
      writeln("(TOOL/CHAMFER, " + getParam("tool_diameter") + ", " +
                                  getParam("tool_tipAngle") + ", " +
                                  getParam("tool_shoulderLength") + ", " +
                                  getParam("tool_fluteLength") + ")"  );
      break;
    case TOOL_PROBE:
      writeln("(TOOL/PROBE, " + getParam("tool_diameter") + ")")
      break;
    default:
       writeln("(CAN'T SIMULATE TOOL TYPE [" + tool.getType() + "])")
    };


    writeBlock("T" + toolFormat.format(tool.number), mFormat.format(6));
    if (tool.comment) {
      writeComment(tool.comment);
    }

    var showToolZMin = false;
    if (showToolZMin) {
      if (is3D()) {
        var numberOfSections = getNumberOfSections();
        var zRange = currentSection.getGlobalZRange();
        var number = tool.number;
        for (var i = currentSection.getId() + 1; i < numberOfSections; ++i) {
          var section = getSection(i);
          if (section.getTool().number != number) {
            break;
          }
          zRange.expandToRange(section.getGlobalZRange());
        }
        writeComment(localize("ZMIN") + "=" + zRange.getMinimum());
      }
    }

    if (properties.preloadTool) {
      var nextTool = getNextTool(tool.number);
      if (nextTool) {
        writeBlock("T" + toolFormat.format(nextTool.number));
      } else {
        // preload first tool
        var section = getSection(0);
        var firstToolNumber = section.getTool().number;
        if (tool.number != firstToolNumber) {
          writeBlock("T" + toolFormat.format(firstToolNumber));
        }
      }
    }
  }
  
  // modified code here to make sure that this is not a probe operation before setting spindle speed
  if ((insertToolCall ||
      isFirstSection() ||
      (rpmFormat.areDifferent(spindleSpeed, sOutput.getCurrent())) ||
      (tool.clockwise != getPreviousSection().getTool().clockwise)) &&
      !isProbeOperation()) {
    if (spindleSpeed < 1) {
      error(localize("Spindle speed out of range."));
      return;
    }
    if (spindleSpeed > 99999) {
      warning(localize("Spindle speed exceeds maximum value."));
    }
    writeBlock(
      sOutput.format(spindleSpeed), mFormat.format(tool.clockwise ? 3 : 4)
    );
  }
  if (isProbeOperation() == true) return;
  
  // wcs
  if (insertToolCall) { // force work offset when changing tool
    currentWorkOffset = undefined;
  }

  var workOffset = currentSection.workOffset;
  if (workOffset == 0) {
    warningOnce(localize("Work offset has not been specified. Using G54 as WCS."), WARNING_WORK_OFFSET);
    workOffset = 1;
  }
  if (workOffset > 0) {
    if (workOffset > 6) {
      var code = workOffset - 6;
      if (code > 3) {
        error(localize("Work offset out of range."));
        return;
      }
      if (workOffset != currentWorkOffset) {
        forceWorkPlane();
        writeBlock(gFormat.format(59) + "." + code);
        currentWorkOffset = workOffset;
      }
    } else {
      if (workOffset != currentWorkOffset) {
        forceWorkPlane();
        writeBlock(gFormat.format(53 + workOffset)); // G54->G59
        currentWorkOffset = workOffset;
      }
    }
  }
  forceXYZ();
  
  if (isProbeOperation() == true) return;

  if (machineConfiguration.isMultiAxisConfiguration()) { // use 5-axis indexing for multi-axis mode
    // set working plane after datum shift

    var abc = new Vector(0, 0, 0);
    if (currentSection.isMultiAxis()) {
      forceWorkPlane();
      cancelTransformation();
    } else {
      abc = getWorkPlaneMachineABC(currentSection.workPlane);
    }
    setWorkPlane(abc);
  } else { // pure 3D
    setWorkPlane(abc);
    var remaining = currentSection.workPlane;
    if (!isSameDirection(remaining.forward, new Vector(0, 0, 1))) {
      error(localize("Tool orientation is not supported."));
      return;
    }
    setRotation(remaining);
  }

  // set coolant after we have positioned at Z
  setCoolant(tool.coolant);

  forceAny();
  var initialPosition = getFramePosition(currentSection.getInitialPosition());
  if (!retracted && !insertToolCall) {
    if (getCurrentPosition().z < initialPosition.z) {
      writeBlock(gMotionModal.format(0), zOutput.format(initialPosition.z));
    }
  }

  if ((insertToolCall || retracted) && properties.toolLengthCompensation) {
    error(localize("Tool length compensation not supported in Buildbotics Controller"));
    return;
    var lengthOffset = tool.lengthOffset;
    if (lengthOffset > numberOfToolSlots) {
      error(localize("Length offset out of range."));
      return;
    }

    gMotionModal.reset();
    writeBlock(gPlaneModal.format(17));

    if (!machineConfiguration.isHeadConfiguration()) {
      writeBlock(
        gAbsIncModal.format(90),
        gMotionModal.format(0), xOutput.format(initialPosition.x), yOutput.format(initialPosition.y)
      );
      if (properties.toolLengthCompensation) {
        writeBlock(gMotionModal.format(0), gFormat.format(43), zOutput.format(initialPosition.z), hFormat.format(lengthOffset));
      } else {
        writeBlock(gMotionModal.format(0), gFormat.format(43), zOutput.format(initialPosition.z));
      }
    } else {
      if (properties.toolLengthCompensation) {
        writeBlock(
        gAbsIncModal.format(90),
        gMotionModal.format(0),
        gFormat.format(43), xOutput.format(initialPosition.x),
        yOutput.format(initialPosition.y),
        zOutput.format(initialPosition.z), hFormat.format(lengthOffset));
      } else {
        writeBlock(
          gAbsIncModal.format(90),
          gMotionModal.format(0),
          gFormat.format(43), xOutput.format(initialPosition.x),
          yOutput.format(initialPosition.y),
          zOutput.format(initialPosition.z)); 
      }
    }
  } else {
    writeBlock(
      gAbsIncModal.format(90),
      gMotionModal.format(0),
      xOutput.format(initialPosition.x),
      yOutput.format(initialPosition.y)
    );
  }
}


function onDwell(seconds) {
  if (seconds > 99999.999) {
    warning(localize("Dwelling time is out of range."));
  }
  seconds = clamp(0.001, seconds, 99999.999);
  writeBlock(gFormat.format(4), "P" + secFormat.format(seconds));
}

function onSpindleSpeed(spindleSpeed) {
  writeBlock(sOutput.format(spindleSpeed));
}

function onCycle() {
  writeBlock(gPlaneModal.format(17));
  writeBlock("F" + cycle.feedrate)
  if (isProbeOperation() == true) {
    switch (cycleType) {
    case 'probing-xy-outer-corner':
    case 'probing-z':
    case 'probing-x':
    case 'probing-y':
      break;
    default:
      warning('cycleType: ' + cycleType + ' not supported') 
    }
  }
}

function getCommonCycle(x, y, z, r) {
  forceXYZ();
  return [xOutput.format(x), yOutput.format(y),
    zOutput.format(z),
    "R" + xyzFormat.format(r)];
}

/* Modified by Buildbotics to disable "Canned" cycles. This changes simply expands all cycle calls
to individual g-code commands and returns.*/
function onCyclePoint(x, y, z) {
  switch (cycleType) {
  case "probing-xy-outer-corner":
    writeComment(cycleType)
    value1 = (cycle.approach1 == 'positive') ? 1 : -1; 
    value2 = (cycle.approach2 == 'positive') ? 1 : -1;
    offset = (cycle.probeClearance + tool.diameter/2)

    writeBlock(gFormat.format(0),"Z" + cycle.retract)
    writeBlock(gFormat.format(0),"Y" + (y + value2 * (2 * offset)))
    writeBlock(gFormat.format(1),"Z" + -tool.diameter/2)
    writeBlock(gFormat.format(91))
    writeBlock(gFormat.format(38) + ".2 X" + value1 * (offset + cycle.probeOvertravel))
    writeBlock(gFormat.format(92), "X" + (x + value1 * (offset - tool.diameter / 2)))
    writeBlock(gFormat.format(90))
    writeBlock(gFormat.format(0),"Z" + cycle.retract)
    writeBlock(gFormat.format(0),"Y" + y)

    writeComment("probing y")
    writeBlock(gFormat.format(0),"X" + (x + value1 * (2 * offset)))
    writeBlock(gFormat.format(1),"Z" + -tool.diameter/2)
    writeBlock(gFormat.format(91))
    writeBlock(gFormat.format(38) + ".2 Y" + value2 * (offset + cycle.probeOvertravel))
    writeBlock(gFormat.format(92), "Y" + (y + value2 * (offset - tool.diameter / 2)))
    writeBlock(gFormat.format(90))
    writeBlock(gFormat.format(0),"Z" + cycle.retract)
    writeBlock(gFormat.format(0),"X" + (x + value1 * offset), "Y" + (y + value2 * offset))
    return;
  case "probing-x":
    writeComment(cycleType)
    value = (cycle.approach1 == 'positive') ? 1 : -1;      
    offset = (cycle.probeClearance + tool.diameter/2)
    writeBlock(gFormat.format(0),"Z" + -tool.diameter/2)
    writeBlock(gFormat.format(91))
    writeBlock(gFormat.format(38) + ".2 X" + value * (cycle.retract + cycle.probeOvertravel))
    writeBlock(gFormat.format(92), "X" + (x + value * (offset - tool.diameter / 2)))
    writeBlock(gFormat.format(90))
    writeBlock(gFormat.format(0),"Z" + cycle.retract)
    writeBlock(gFormat.format(0),"X" + 0,"Y" + 0)
    return;
  case "probing-y":
    writeComment(cycleType)
    value = (cycle.approach1 == 'positive') ? 1 : -1;      
    offset = (cycle.probeClearance + tool.diameter/2)
    writeBlock(gFormat.format(0),"Z" + -tool.diameter/2)
    writeBlock(gFormat.format(91))
    writeBlock(gFormat.format(38) + ".2 Y" + value * (cycle.retract + cycle.probeOvertravel))
    writeBlock(gFormat.format(92), "Y" + (y + value * (offset - tool.diameter / 2)))
    writeBlock(gFormat.format(90))
    writeBlock(gFormat.format(0),"Z" + cycle.retract)
    writeBlock(gFormat.format(0),"X" + 0,"Y" + 0)
    return;
  case "probing-z":
    writeComment(cycleType)
    writeBlock(gFormat.format(0),"Z" + cycle.retract)
    writeBlock(gFormat.format(91))
    writeBlock(gFormat.format(38) + ".2 Z" + (-cycle.retract - cycle.probeOvertravel))
    writeBlock(gFormat.format(92), "Z" + 0)
    writeBlock(gFormat.format(90))
    writeBlock(gFormat.format(0),"Z" + cycle.retract)
    writeBlock(gFormat.format(0),"X" + 0,"Y" + 0)
    return;
  case "probe":
  case "tapping":
  case "left-tapping":
  case "right-tapping":
  case "tapping-with-chip-breaking":
  case "fine-boring":
  case "back-boring":
    error(localize("Cycle Type (" + cycleType + ") not supported in Buildbotics Controller"));
    return;
  default:
    break;
  }
  warning(localize(cycleType));
  expandCyclePoint(x,y,z);
  return;
  if (!isSameDirection(getRotation().forward, new Vector(0, 0, 1))) {
    expandCyclePoint(x, y, z);
    return;
  }
  if (isFirstCyclePoint()) {
    repositionToCycleClearance(cycle, x, y, z);
    
    // return to initial Z which is clearance plane and set absolute mode

    var F = cycle.feedrate;
    var P = !cycle.dwell ? 0 : clamp(0.001, cycle.dwell, 99999.999); // in seconds

    switch (cycleType) {
    case "drilling":
      writeBlock(
        gRetractModal.format(98), gAbsIncModal.format(90), gCycleModal.format(81),
        getCommonCycle(x, y, z, cycle.retract),
        feedOutput.format(F)
      );
      break;
    case "counter-boring":
      if (P > 0) {
        writeBlock(
          gRetractModal.format(98), gAbsIncModal.format(90), gCycleModal.format(82),
          getCommonCycle(x, y, z, cycle.retract),
          "P" + secFormat.format(P), // not optional
          feedOutput.format(F)
        );
      } else {
        writeBlock(
          gRetractModal.format(98), gAbsIncModal.format(90), gCycleModal.format(81),
          getCommonCycle(x, y, z, cycle.retract),
          feedOutput.format(F)
        );
      }
      break;
    case "chip-breaking":
      expandCyclePoint(x, y, z);
      break;
    case "deep-drilling":
      if (P > 0) {
        expandCyclePoint(x, y, z);
      } else {
        writeBlock(
          gRetractModal.format(98), gAbsIncModal.format(90), gCycleModal.format(83),
          getCommonCycle(x, y, z, cycle.retract),
          "Q" + xyzFormat.format(cycle.incrementalDepth),
          feedOutput.format(F)
        );
      }
      break;
    case "tapping":
      if (!F) {
        F = tool.getTappingFeedrate();
      }
      writeBlock(
        gRetractModal.format(98), gAbsIncModal.format(90), gCycleModal.format((tool.type == TOOL_TAP_LEFT_HAND) ? 74 : 84),
        getCommonCycle(x, y, z, cycle.retract),
        feedOutput.format(F)
      );
      break;
    case "left-tapping":
      if (!F) {
        F = tool.getTappingFeedrate();
      }
      writeBlock(
        gRetractModal.format(98), gAbsIncModal.format(90), gCycleModal.format(74),
        getCommonCycle(x, y, z, cycle.retract),
        feedOutput.format(F)
      );
      break;
    case "right-tapping":
      if (!F) {
        F = tool.getTappingFeedrate();
      }
      writeBlock(
        gRetractModal.format(98), gAbsIncModal.format(90), gCycleModal.format(84),
        getCommonCycle(x, y, z, cycle.retract),
        feedOutput.format(F)
      );
      break;
    case "fine-boring": // not supported
      expandCyclePoint(x, y, z);
      break;
    case "back-boring":
      if (P > 0) {
        expandCyclePoint(x, y, z);
      } else {
        var I = cycle.shift * 1;
        var J = cycle.shift * 0;
        writeBlock(
          gRetractModal.format(98), gAbsIncModal.format(90), gCycleModal.format(87),
          getCommonCycle(x, y, z, cycle.retract),
          "I" + xyzFormat.format(I),
          "J" + xyzFormat.format(J),
          "K" + xyzFormat.format(cycle.bottom - cycle.backBoreDistance),
          feedOutput.format(F)
        );
      }
      break;
    case "reaming":
      writeBlock(
        gRetractModal.format(98), gAbsIncModal.format(90), gCycleModal.format(85),
        getCommonCycle(x, y, z, cycle.retract),
        feedOutput.format(F)
      );
      break;
    case "stop-boring":
      writeBlock(
        gRetractModal.format(98), gAbsIncModal.format(90), gCycleModal.format(86),
        getCommonCycle(x, y, z, cycle.retract),
        feedOutput.format(F),
        // conditional(P > 0, "P" + secFormat.format(P)),
        "P" + secFormat.format(P) // not optional
      );
      break;
    case "manual-boring":
      writeBlock(
        gRetractModal.format(98), gAbsIncModal.format(90), gCycleModal.format(88),
        getCommonCycle(x, y, z, cycle.retract),
        "P" + secFormat.format(P), // not optional
        feedOutput.format(F)
      );
      break;
    case "boring":
      if (P > 0) {
        writeBlock(
          gRetractModal.format(98), gAbsIncModal.format(90), gCycleModal.format(89),
          getCommonCycle(x, y, z, cycle.retract),
          "P" + secFormat.format(P), // not optional
          feedOutput.format(F)
        );
      } else {
        writeBlock(
          gRetractModal.format(98), gAbsIncModal.format(90), gCycleModal.format(85),
          getCommonCycle(x, y, z, cycle.retract),
          feedOutput.format(F)
        );
      }
      break;
    default:
      expandCyclePoint(x, y, z);
    }
  } else {
    if (cycleExpanded) {
      expandCyclePoint(x, y, z);
    } else {
      var _x = xOutput.format(x);
     var _y = yOutput.format(y);
      if (!_x && !_y) {
        xOutput.reset(); // at least one axis is required
        _x = xOutput.format(x);
      }
      writeBlock(_x, _y);
    }
  }
}

function onCycleEnd() {
  if (!cycleExpanded) {
    writeBlock(gCycleModal.format(80));
    zOutput.reset();
  }
}

var pendingRadiusCompensation = -1;

function onRadiusCompensation() {
  pendingRadiusCompensation = radiusCompensation;
}

// Added by Doug Coffland to allow support for plasma and laser cutting
var onPower(power) {
    writeBlock(mFormat.format(power ? 3 : 5), conditional(power, qFormat.format(power)));
}

function onRapid(_x, _y, _z) {
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  if (x || y || z) {
    if (pendingRadiusCompensation >= 0) {
      error(localize("Radius compensation mode cannot be changed at rapid traversal."));
      return;
    }
    writeBlock(gMotionModal.format(0), x, y, z);
    feedOutput.reset();
  }
}

function onLinear(_x, _y, _z, feed) {
  // at least one axis is required
  if (pendingRadiusCompensation >= 0) {
    // ensure that we end at desired position when compensation is turned off
    xOutput.reset();
    yOutput.reset();
  }
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  var f = feedOutput.format(feed);
  if (x || y || z) {
    if (pendingRadiusCompensation >= 0) {
      // modificatons by Buildbotics to prevent user from attempting "In Controller" cutter compensation
      warning(localize("Cutter compensation not implemented in Buildbotics Controller."));
      warning(localize("Set Compensation Type to 'In Controller' in Passes dialogue."));
      error(localize("Cannot decode cutter compensation request (G40,G41,G42), exiting"))
      return;
      pendingRadiusCompensation = -1;
      var d = tool.diameterOffset;
      if (d > numberOfToolSlots) {
        warning(localize("The diameter offset exceeds the maximum value."));
      }
      writeBlock(gPlaneModal.format(17));
      switch (radiusCompensation) {
      case RADIUS_COMPENSATION_LEFT:
        dOutput.reset();
        writeBlock(gMotionModal.format(1), gFormat.format(41), x, y, z, dOutput.format(d), f);
        break;
      case RADIUS_COMPENSATION_RIGHT:
        dOutput.reset();
        writeBlock(gMotionModal.format(1), gFormat.format(42), x, y, z, dOutput.format(d), f);
        break;
      default:
        writeBlock(gMotionModal.format(1), gFormat.format(40), x, y, z, f);
      }
    } else {
      writeBlock(gMotionModal.format(1), x, y, z, f);
    }
  } else if (f) {
    if (getNextRecord().isMotion()) { // try not to output feed without motion
      feedOutput.reset(); // force feed on next line
    } else {
      writeBlock(gMotionModal.format(1), f);
    }
  }
}

function onRapid5D(_x, _y, _z, _a, _b, _c) {
  if (!currentSection.isOptimizedForMachine()) {
    error(localize("This post configuration has not been customized for 5-axis simultaneous toolpath."));
    return;
  }
  if (pendingRadiusCompensation >= 0) {
    error(localize("Radius compensation mode cannot be changed at rapid traversal."));
    return;
  }
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  var a = aOutput.format(_a);
  var b = bOutput.format(_b);
  var c = cOutput.format(_c);
  writeBlock(gMotionModal.format(0), x, y, z, a, b, c);
  feedOutput.reset();
}

function onLinear5D(_x, _y, _z, _a, _b, _c, feed) {
  if (!currentSection.isOptimizedForMachine()) {
    error(localize("This post configuration has not been customized for 5-axis simultaneous toolpath."));
    return;
  }
  // at least one axis is required
  if (pendingRadiusCompensation >= 0) {
    error(localize("Radius compensation cannot be activated/deactivated for 5-axis move."));
    return;
  }
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  var a = aOutput.format(_a);
  var b = bOutput.format(_b);
  var c = cOutput.format(_c);
  var f = feedOutput.format(feed);
  if (x || y || z || a || b || c) {
    writeBlock(gMotionModal.format(1), x, y, z, a, b, c, f);
  } else if (f) {
    if (getNextRecord().isMotion()) { // try not to output feed without motion
      feedOutput.reset(); // force feed on next line
    } else {
      writeBlock(gMotionModal.format(1), f);
    }
  }
}

function onCircular(clockwise, cx, cy, cz, x, y, z, feed) {
  // one of X/Y and I/J are required and likewise
  
  if (pendingRadiusCompensation >= 0) {
    error(localize("Radius compensation cannot be activated/deactivated for a circular move."));
    return;
  }

  var start = getCurrentPosition();

  if (isFullCircle()) {
    if (isHelical()) {
      linearize(tolerance);
      return;
    }
    switch (getCircularPlane()) {
    case PLANE_XY:
      writeBlock(gPlaneModal.format(17), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), iOutput.format(cx - start.x, 0), jOutput.format(cy - start.y, 0), feedOutput.format(feed));
      break;
    case PLANE_ZX:
      writeBlock(gPlaneModal.format(18), gMotionModal.format(clockwise ? 2 : 3), zOutput.format(z), iOutput.format(cx - start.x, 0), kOutput.format(cz - start.z, 0), feedOutput.format(feed));
      break;
    case PLANE_YZ:
      writeBlock(gPlaneModal.format(19), gMotionModal.format(clockwise ? 2 : 3), yOutput.format(y), jOutput.format(cy - start.y, 0), kOutput.format(cz - start.z, 0), feedOutput.format(feed));
      break;
    default:
      linearize(tolerance);
    }
  } else {
    switch (getCircularPlane()) {
    case PLANE_XY:
      writeBlock(gPlaneModal.format(17), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), iOutput.format(cx - start.x, 0), jOutput.format(cy - start.y, 0), feedOutput.format(feed));
      break;
    case PLANE_ZX:
      writeBlock(gPlaneModal.format(18), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), iOutput.format(cx - start.x, 0), kOutput.format(cz - start.z, 0), feedOutput.format(feed));
      break;
    case PLANE_YZ:
      writeBlock(gPlaneModal.format(19), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), jOutput.format(cy - start.y, 0), kOutput.format(cz - start.z, 0), feedOutput.format(feed));
      break;
    default:
      linearize(tolerance);
    }
  }
}

var currentCoolantMode = undefined;
var coolantOff = undefined;

function setCoolant(coolant) {
  if (properties.disableCoolantControl == true) {return false;}
  var coolantCodes = getCoolantCodes(coolant);
  if (Array.isArray(coolantCodes)) {
    for (var c in coolantCodes) {
      writeBlock(coolantCodes[c]);
    }
    return undefined;
  }
  return coolantCodes;
}

function getCoolantCodes(coolant) {
  if (!coolants) {
    error(localize("Coolants have not been defined."));
  }
  if (!coolantOff) { // use the default coolant off command when an 'off' value is not specified for the previous coolant mode
    coolantOff = coolants.off;
  }

  if (isProbeOperation()) { // avoid coolant output for probing
    coolant = COOLANT_OFF;
  }

  if (coolant == currentCoolantMode) {
    return undefined; // coolant is already active
  }

  var multipleCoolantBlocks = new Array(); // create a formatted array to be passed into the outputted line
  if ((coolant != COOLANT_OFF) && (currentCoolantMode != COOLANT_OFF)) {
    multipleCoolantBlocks.push(mFormat.format(coolantOff));
  }

  var m;
  if (coolant == COOLANT_OFF) {
    m = coolantOff;
    coolantOff = coolants.off;
  }

  switch (coolant) {
  case COOLANT_FLOOD:
    if (!coolants.flood) {
      break;
    }
    m = coolants.flood.on;
    coolantOff = coolants.flood.off;
    break;
  case COOLANT_THROUGH_TOOL:
    if (!coolants.throughTool) {
      break;
    }
    m = coolants.throughTool.on;
    coolantOff = coolants.throughTool.off;
    break;
  case COOLANT_AIR:
    if (!coolants.air) {
      break;
    }
    m = coolants.air.on;
    coolantOff = coolants.air.off;
    break;
  case COOLANT_AIR_THROUGH_TOOL:
    if (!coolants.airThroughTool) {
      break;
    }
    m = coolants.airThroughTool.on;
    coolantOff = coolants.airThroughTool.off;
    break;
  case COOLANT_FLOOD_MIST:
    if (!coolants.floodMist) {
      break;
    }
    m = coolants.floodMist.on;
    coolantOff = coolants.floodMist.off;
    break;
  case COOLANT_MIST:
    if (!coolants.mist) {
      break;
    }
    m = coolants.mist.on;
    coolantOff = coolants.mist.off;
    break;
  case COOLANT_SUCTION:
    if (!coolants.suction) {
      break;
    }
    m = coolants.suction.on;
    coolantOff = coolants.suction.off;
    break;
  case COOLANT_FLOOD_THROUGH_TOOL:
    if (!coolants.floodThroughTool) {
      break;
    }
    m = coolants.floodThroughTool.on;
    coolantOff = coolants.floodThroughTool.off;
    break;
  }
  
  if (!m) {
    onUnsupportedCoolant(coolant);
    m = 9;
  }

  if (m) {
    if (Array.isArray(m)) {
      for (var i in m) {
        multipleCoolantBlocks.push(mFormat.format(m[i]));
      }
    } else {
      multipleCoolantBlocks.push(mFormat.format(m));
    }
    currentCoolantMode = coolant;
    return multipleCoolantBlocks; // return the single formatted coolant value
  }
  return undefined;
}

var mapCommand = {
  COMMAND_STOP:0,
  COMMAND_OPTIONAL_STOP:1,
  COMMAND_END:2,
  COMMAND_SPINDLE_CLOCKWISE:3,
  COMMAND_SPINDLE_COUNTERCLOCKWISE:4,
  COMMAND_STOP_SPINDLE:5,
  COMMAND_ORIENTATE_SPINDLE:19,
  COMMAND_LOAD_TOOL:6
};

function onCommand(command) {
  switch (command) {
  case COMMAND_START_SPINDLE:
    onCommand(tool.clockwise ? COMMAND_SPINDLE_CLOCKWISE : COMMAND_SPINDLE_COUNTERCLOCKWISE);
    return;
  case COMMAND_LOCK_MULTI_AXIS:
    return;
  case COMMAND_UNLOCK_MULTI_AXIS:
    return;
  case COMMAND_BREAK_CONTROL:
    return;
  case COMMAND_TOOL_MEASURE:
    return;
  }

  var stringId = getCommandStringId(command);
  var mcode = mapCommand[stringId];
  if (mcode != undefined) {
    writeBlock(mFormat.format(mcode));
  } else {
    onUnsupportedCommand(command);
  }
}

function onSectionEnd() {
  writeBlock(gPlaneModal.format(17));
  forceAny();
}

/** Output block to do safe retract and/or move to home position. */
function writeRetract() {
  if (arguments.length == 0) {
    error(localize("No axis specified for writeRetract()."));
    return;
  }
  var words = []; // store all retracted axes in an array
  for (var i = 0; i < arguments.length; ++i) {
    let instances = 0; // checks for duplicate retract calls
    for (var j = 0; j < arguments.length; ++j) {
      if (arguments[i] == arguments[j]) {
        ++instances;
      }
    }
    if (instances > 1) { // error if there are multiple retract calls for the same axis
      error(localize("Cannot retract the same axis twice in one line"));
      return;
    }
    switch (arguments[i]) {
    case X:
      words.push("X" + xyzFormat.format(machineConfiguration.hasHomePositionX() ? machineConfiguration.getHomePositionX() : 0));
      break;
    case Y:
      words.push("Y" + xyzFormat.format(machineConfiguration.hasHomePositionY() ? machineConfiguration.getHomePositionY() : 0));
      break;
    case Z:
      words.push("Z" + properties.zRetractHeight * (unit == MM ? 1 : 1/25.4) );
      retracted = true; // specifies that the tool has been retracted to the safe plane
      break;
    default:
      error(localize("Bad axis specified for writeRetract()."));
      return;
    }
  }
  
  if (words.length > 0) {
    gMotionModal.reset();
    gAbsIncModal.reset();
    writeBlock(gFormat.format(0), gAbsIncModal.format(91), words); // retract
    writeBlock(gAbsIncModal.format(90));
  }
  zOutput.reset();
}

function onClose() {
  setCoolant(COOLANT_OFF);

  writeRetract(Z);

  setWorkPlane(new Vector(0, 0, 0)); // reset working plane

  writeRetract(X, Y);

  onImpliedCommand(COMMAND_END);
  onImpliedCommand(COMMAND_STOP_SPINDLE);
  writeBlock(mFormat.format(30)); // stop program, spindle stop, coolant off
  writeln("%");
}
