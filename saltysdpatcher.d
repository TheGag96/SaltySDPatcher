/*
 * Quick Auto-Patcher for SaltySD v0.1.1
 *   written by TheGag96
 *
 * Contact me on Reddit/GBATemp if you have any questions, problems, or suggestions.
 * 
 * Do whatever you want with this code, just keep my name in it somewhere!
 */

import std.stdio, std.net.curl, std.file, std.process, std.typecons, std.algorithm, std.path;

bool buildNewest = true;
string inputFile;
string patchesDir = "temp";
bool isCodebin = false;

void main(string[] args) {
  if (args.length < 2 || args.length > 4) {
    writeln("Usage: saltypatcher <filename> <patches dir> (-codebin)");
    writeln("If <patces dir> is not specified, the files will be downloaded and compiled automatically.");
    writeln("Note that this requires DevkitPro and make to be installed on your machine!");
    return;
  }
  else if (args.length == 3) {
    if (args[2] == "-codebin") {
      isCodebin = true;
    }
    else {
      patchesDir = args[2];
      buildNewest = false;
    }
  }
  else if (args.length == 4) {
    if (args[3] == "-codebin") isCodebin = true;
    patchesDir = args[2];
    buildNewest = false;
  }

  inputFile = args[1];

  if (!checkFilesValidity()) return;

  if (buildNewest) compilePatches();

  patchItUp();

  if (buildNewest) cleanUpTemp();

  writeln("\nDone! Enjoy the salt!");
}

void compilePatches() {
  writeln("Grabbing newest patch files from git...");
  //Download source files and compile
  grabNewestFiles();

  writeln("Running make...");
  chdir("temp");
  auto shell = executeShell("make");
  writeln("Make output: ", shell.output);
  chdir("..");
}

void grabNewestFiles() {
  mkdir("temp");

  auto files = ["Makefile", "datasize.asm", "exist.asm", "find.asm", "hookdatasize.asm",
                "hookexist.asm", "hookfind.asm", "hooklock.asm", "lock.asm", "sdsound.asm"];

  foreach (file; files) {
    writeln("Downloading ", file, "...");
    download("https://github.com/shinyquagsire23/SaltySD/raw/master/smash/" ~ file,
             "temp/" ~ file);
  }
}

bool checkFilesValidity() {
  if (!exists(inputFile)) {
    writeln("Looks like that ROM file doesn't exist.");
    return false;
  }

  if (buildNewest) return true;

  if (!exists(patchesDir)) {
    writeln("Looks like the patch directory doesn't exist.");
    return false;
  }

  auto requiredFiles = ["datasize.bin", "exist.bin", "find.bin", "hookdatasize.bin", "hookexist.bin",
                        "hookfind.bin", "hooklock.bin", "lock.bin", "sdsound.bin"];

  foreach (file; requiredFiles) {
    if (!exists(patchesDir ~ "/" ~ file)) {
      writeln("Could not find required file ", file, " in patch directory!");
      return false;
    }
  }

  return true;
}


void cleanUpTemp() {
  foreach (string name; dirEntries("temp", SpanMode.depth)) {
    remove(name);
  }

  rmdir("temp");
}

alias BytePatch = Tuple!(long, "address", ubyte[], "bytes");

void patchItUp() {
  writeln("Patching file ", inputFile, "...");

  immutable long[string] insertionPoints = [
    "hookdatasize" : 0x13F4B8,
    "datasize"     : 0xA1C800,
    "hooklock"     : 0x1816CC,
    "lock"         : 0xA1B800,
    "hookexist"    : 0x159E9C,
    "exist"        : 0xA1CD00,
    //"hookfind"     : 0x16EFAC,
    //"find"         : 0xA1CF00,
    "sdsound"      : 0xA1CB00
  ];

  BytePatch[] extraPatches = [
    BytePatch(0x13F4B4, [0x1E, 0xFF, 0x2F, 0xE1]),
    BytePatch(0x140DBC, [0x01, 0x00, 0xA0, 0xE3, 0x1E, 0xFF, 0x2F, 0xE1]),
    BytePatch(0x159E98, [0x70, 0x40, 0x2D, 0xE9]),
    BytePatch(0x159EF0, [0x70, 0x80, 0xBD, 0xE8]),
    BytePatch(0x7AB5C4, [0x00, 0xCB, 0xA1, 0x00]),
    BytePatch(0x7AB5E0, [0x9B, 0x37, 0xB6, 0x00])
  ];

  auto romData = File(inputFile, "r+b");

  foreach (binFile; dirEntries(patchesDir, SpanMode.shallow).filter!(x => x.name.endsWith(".bin"))) {
    //chop off ".bin"
    auto patchName = baseName(binFile.name)[0..$-4];

    //skip what we don't know how to handle
    if (patchName !in insertionPoints) continue;

    //read in patch data
    auto patchData = cast(ubyte[]) read(binFile.name);
    

    //write the patch
    //also take into account if it needs to be done 0x100000 bytes back (if it's a codebin)
    romData.seek(insertionPoints[patchName] - isCodebin * 0x100000);
    romData.rawWrite(patchData);

    /* Commented out due to unnecessary hook
    //extra insertion point needed for hookfind
    if (patchName == "hookfind") {
      romData.seek(0x9E1F58 - isCodebin * 0x100000);
      romData.rawWrite(patchData);
    }
    */
  }

  //write the extra byte patches
  foreach (patch; extraPatches) {
    romData.seek(patch.address - isCodebin * 0x100000);
    romData.rawWrite(patch.bytes);
  }
}
