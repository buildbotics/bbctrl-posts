/**
  Copyright (C) 2012-2019 by Autodesk, Inc.
  All rights reserved.

  Grbl post processor configuration.

  $Revision: 42473 905303e8374380273c82d214b32b7e80091ba92e $
  $Date: 2019-09-04 00:46:02 $
  
  FORKID {0A45B7F8-16FA-450B-AB4F-0E1BC1A65FAA}

  Modified for Buildbotics Controller with Jet operation
*/

description = "Buildbotics Jet";
vendor = "Buildbotics LLC";
vendorUrl = "https://buildbotics.com";
legal = "Copyright (C) 2012-2019 by Autodesk, Inc.";
certificationLevel = 2;
minimumRevision = 24000;
highFeedrate = (unit == IN) ? 100 : 2500;

longDescription = "Generic post for Buildbotics Jet cutting.";

extension = "nc";
setCodePage("ascii");

capabilities = CAPABILITY_JET;
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
  showSequenceNumbers: false, // show sequence numbers
  sequenceNumberStart: 10, // first sequence number
  sequenceNumberIncrement: 1, // increment for sequence numbers
  separateWordsWithSpace: true, // specifies that the words should be separated with a white space
  pierceDelay: 1, // specifies the delay to pierce in seconds
  useZAxis: false, // specifies to enable the output for Z coordinates
  pierceHeight: 0, // specifies the pierce height
  useG0: true // toggle between using G0 or G1 with a highFeedrate for rapid movements
  //throughPower: 255, // set the Laser Power for though cutting
  //etchPower: 50, // set the power for etching
  //vaporizePower: 255 // set the power for vaporize
};

// user-defined property definitions
propertyDefinitions = {
  writeMachine: {title:"Write machine", description:"Output the machine settings in the header of the code.", group:0, type:"boolean"},
  showSequenceNumbers: {title:"Use sequence numbers", description:"Use sequence numbers for each block of outputted code.", group:1, type:"boolean"},
  sequenceNumberStart: {title:"Start sequence number", description:"The number at which to start the sequence numbers.", group:1, type:"integer"},
  sequenceNumberIncrement: {title:"Sequence number increment", description:"The amount by which the sequence number is incremented by in each block.", group:1, type:"integer"},
  separateWordsWithSpace: {title:"Separate words with space", description:"Adds spaces between words if 'yes' is selected.", type:"boolean"},

  pierceDelay: {title:"Pierce delay", description:"Specifies the delay to pierce in seconds.", type:"number"},
  useZAxis: {title:"Use Z axis", description:"Specifies to enable the output for Z coordinates.", type:"boolean"},
  pierceHeight: {title:"Pierce Height", description:"Specifies the pierce height.", type:"number"},
  useG0: {title:"Use G0", description:"Toggle between using G0 or G1 with a highFeedrate for rapid movements.", type:"boolean"}
  //throughPower: {title: "Through power", description: "Sets the laser power used for through cutting.", type: "number"},
  //etchPower: {title:"Etch power", description:"Sets the laser power used for etching.", type:"number"},
  //vaporizePower: {title:"Vaporize power", description:"Sets the laser power used for vaporize cutting.", type:"number"}
};

var gFormat = createFormat({prefix:"G", decimals:0});
var mFormat = createFormat({prefix:"M", decimals:0});

var xyzFormat = createFormat({decimals:(unit == MM ? 3 : 4)});
var zFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true});
var feedFormat = createFormat({decimals:(unit == MM ? 1 : 2)});
var toolFormat = createFormat({decimals:0});
var powerFormat = createFormat({decimals:0});
var secFormat = createFormat({decimals:3, forceDecimal:true}); // seconds - range 0.001-1000

var xOutput = createVariable({prefix:"X"}, xyzFormat);
var yOutput = createVariable({prefix:"Y"}, xyzFormat);
var zOutput = createVariable({prefix:"Z"}, xyzFormat);
var feedOutput = createVariable({prefix:"F"}, feedFormat);
var sOutput = createVariable({prefix:"S", force:true}, powerFormat);

// circular output
var iOutput = createVariable({prefix:"I"}, xyzFormat);
var jOutput = createVariable({prefix:"J"}, xyzFormat);

var gMotionModal = createModal({force:true}, gFormat); // modal group 1 // G0-G3, ...
var gPlaneModal = createModal({onchange:function () {gMotionModal.reset();}}, gFormat); // modal group 2 // G17-19
var gAbsIncModal = createModal({}, gFormat); // modal group 3 // G90-91
var gFeedModeModal = createModal({}, gFormat); // modal group 5 // G93-94
var gUnitModal = createModal({}, gFormat); // modal group 6 // G20-21

var WARNING_WORK_OFFSET = 0;

// collected state
var sequenceNumber;
var currentWorkOffset;

/**
  Writes the specified block.
*/
function writeBlock() {
  if (properties.showSequenceNumbers) {
    writeWords2("N" + sequenceNumber, arguments);
    sequenceNumber += properties.sequenceNumberIncrement;
  } else {
    writeWords(arguments);
  }
}

function formatComment(text) {
  return "(" + String(text).replace(/[()]/g, "") + ")";
}

/**
  Output a comment.
*/
function writeComment(text) {
  writeln(formatComment(text));
}

function getPowerMode(section) {
  var mode;
  switch (section.quality) {
  case 0: // auto
    mode = 4;
    break;
  case 1: // high
    mode = 3;
    break;
    /*
  case 2: // medium
  case 3: // low
*/
  default:
    error(localize("Only Cutting Mode Through-auto and Through-high are supported."));
    return 0;
  }
  return mode;
}

function onOpen() {

  if (properties.useZAxis) {
    zFormat.setOffset(0);
    zOutput = createVariable({prefix:"Z"}, zFormat);
  } else {
    zOutput.disable();
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
  var vendor = machineConfiguration.getVendor();
  var model = machineConfiguration.getModel();
  var description = machineConfiguration.getDescription();

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

  if ((getNumberOfSections() > 0) && (getSection(0).workOffset == 0)) {
    for (var i = 0; i < getNumberOfSections(); ++i) {
      if (getSection(i).workOffset > 0) {
        error(localize("Using multiple work offsets is not possible if the initial work offset is 0."));
        return;
      }
    }
  }

  // absolute coordinates and feed per min
  writeBlock(gAbsIncModal.format(90), gFeedModeModal.format(94));
  writeBlock(gPlaneModal.format(17));

  switch (unit) {
  case IN:
    writeBlock(gUnitModal.format(20));
    break;
  case MM:
    writeBlock(gUnitModal.format(21));
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

/** Force output of X, Y, Z, and F on next output. */
function forceAny() {
  forceXYZ();
  feedOutput.reset();
}

function onSection() {

  writeln("");
  
  if (hasParameter("operation-comment")) {
    var comment = getParameter("operation-comment");
    if (comment) {
      writeComment(comment);
    }
  }
  
  if (currentSection.getType() == TYPE_JET) {
    switch (tool.type) {
    case TOOL_LASER_CUTTER:
      break;
    default:
      error(localize("The CNC does not support the required tool/process. Only laser cutting is supported."));
      return;
    }

    var power = 0;
    switch (currentSection.jetMode) {
    case JET_MODE_THROUGH:
      power = properties.throughPower;
      break;
    case JET_MODE_ETCHING:
      power = properties.etchPower;
      break;
    case JET_MODE_VAPORIZE:
      power = properties.vaporizePower;
      break;
    default:
      error(localize("Unsupported cutting mode."));
      return;
    }
  } else {
    error(localize("The CNC does not support the required tool/process. Only laser cutting is supported."));
    return;
  }

  { // pure 3D
    var remaining = currentSection.workPlane;
    if (!isSameDirection(remaining.forward, new Vector(0, 0, 1))) {
      error(localize("Tool orientation is not supported."));
      return;
    }
    setRotation(remaining);
  }

  forceAny();

  var initialPosition = getFramePosition(currentSection.getInitialPosition());
  var zIsOutput = false;
  if (properties.useZAxis) {
    var previousFinalPosition = isFirstSection() ? initialPosition : getFramePosition(getPreviousSection().getFinalPosition());
    if (xyzFormat.getResultingValue(previousFinalPosition.z) <= xyzFormat.getResultingValue(initialPosition.z)) {
      if (properties.useG0) {
        writeBlock(gMotionModal.format(0), zOutput.format(initialPosition.z));
      } else {
        writeBlock(gMotionModal.format(1), zOutput.format(initialPosition.z), feedOutput.format(highFeedrate));
      }
      zIsOutput = true;
    }
  } 
 
  if (properties.useG0) {
    writeBlock(gMotionModal.format(0), xOutput.format(initialPosition.x), yOutput.format(initialPosition.y));
  } else {
    writeBlock(gMotionModal.format(1), xOutput.format(initialPosition.x), yOutput.format(initialPosition.y), feedOutput.format(highFeedrate));
  }

  if (properties.useZAxis && !zIsOutput) {
    if (properties.useG0) {
      writeBlock(gMotionModal.format(0), zOutput.format(initialPosition.z));
    } else {
      writeBlock(gMotionModal.format(1), zOutput.format(initialPosition.z), feedOutput.format(highFeedrate));
    }
  }
}

function onDwell(seconds) {
  if (seconds > 99999.999) {
    warning(localize("Dwelling time is out of range."));
  }
  seconds = clamp(0.001, seconds, 99999.999);
  writeBlock(gFormat.format(4), "P" + secFormat.format(seconds));
}

var pendingRadiusCompensation = -1;

function onRadiusCompensation() {
  pendingRadiusCompensation = radiusCompensation;
}

var powerIsOn = false
function onPower(power) {
  writeComment("pierce height = " + properties.pierceHeight)
  writeComment("current z pos = " + getCurrentPosition().z)
  if (properties.useZAxis && power) {
    zFormat.setOffset(properties.pierceHeight);
    if (properties.useG0) {
      writeBlock(gMotionModal.format(0), zOutput.format(properties.pierceHeight + getCurrentPosition().z));
    } else {
      writeBlock(gMotionModal.format(1), zOutput.format(properties.pierceHeight + getCurrentPosition().z), feedOutput.format(highFeedrate));
    }
    zFormat.setOffset(0);
  }
  writeBlock(mFormat.format(power ? 3 : 5));
  powerIsOn = power;
  if (power) {
    onDwell(properties.pierceDelay);
    if (zFormat.isSignificant(properties.pierceHeight)) {
      feedOutput.reset();
      var f = (hasParameter("operation:tool_feedEntry") ? getParameter("operation:tool_feedEntry") : toPreciseUnit(1000, MM));
      zOutput = createVariable({prefix:"Z"}, zFormat);
      writeBlock(gMotionModal.format(1), zOutput.format(getCurrentPosition().z), feedOutput.format(f));
      zFormat.setOffset(0);
    }
  } else {
    if (zFormat.isSignificant(properties.pierceHeight)) {
      zFormat.setOffset(0);
      zOutput = createVariable({prefix:"Z"}, zFormat);
    }
    writeln("");
  }
}

function onRapid(_x, _y, _z) {
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  if (x || y) {
    if (pendingRadiusCompensation >= 0) {
      error(localize("Radius compensation mode cannot be changed at rapid traversal."));
      return;
    }
    if (properties.useG0) {
      writeBlock(gMotionModal.format(0), x, y, z);
    } else {
      writeBlock(gMotionModal.format(1), x, y, z, feedOutput.format(highFeedrate));
    }
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
  var f = feedOutput.format(feed);
  if (x || y) {
    if (pendingRadiusCompensation >= 0) {
      error(localize("Radius compensation mode is not supported."));
      return;
    } else {
      writeBlock(gMotionModal.format(1), x, y, f);
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
  error(localize("The CNC does not support 5-axis simultaneous toolpath."));
}

function onLinear5D(_x, _y, _z, _a, _b, _c, feed) {
  error(localize("The CNC does not support 5-axis simultaneous toolpath."));
}

function forceCircular(plane) {
  switch (plane) {
  case PLANE_XY:
    xOutput.reset();
    yOutput.reset();
    iOutput.reset();
    jOutput.reset();
    break;
  case PLANE_ZX:
    zOutput.reset();
    xOutput.reset();
    kOutput.reset();
    iOutput.reset();
    break;
  case PLANE_YZ:
    yOutput.reset();
    zOutput.reset();
    jOutput.reset();
    kOutput.reset();
    break;
  }
}

function onCircular(clockwise, cx, cy, cz, x, y, z, feed) {
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
      forceCircular(getCircularPlane());
      writeBlock(gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), iOutput.format(cx - start.x), jOutput.format(cy - start.y), feedOutput.format(feed));
      break;
    default:
      linearize(tolerance);
    }
  } else {
    switch (getCircularPlane()) {
    case PLANE_XY:
      forceCircular(getCircularPlane());
      writeBlock(gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), iOutput.format(cx - start.x), jOutput.format(cy - start.y), feedOutput.format(feed));
      break;
    default:
      linearize(tolerance);
    }
  }
}

var mapCommand = {
  COMMAND_STOP:0,
  COMMAND_END:2
};

function onCommand(command) {
  switch (command) {
  case COMMAND_POWER_ON:
    return;
  case COMMAND_POWER_OFF:
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
  forceAny();
}

function onClose() {
  writeBlock(sOutput.format(0)); // laser off
  writeBlock(mFormat.format(30)); // stop program, spindle stop, coolant off
  writeln("%");
}
