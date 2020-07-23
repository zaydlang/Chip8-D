import std.stdio;
import std.string : fromStringz;
import std.conv;

import chip8;
import cpu;

import pulsewave;
import chip8;

void main() {
    Chip8 chip8 = new Chip8();
    chip8.loadRom(getFileAsByteBuffer("resources/pong.c8"));
    chip8.run();
}

/++
+ reads the given file and outputs it as ubyte[]
+/
ubyte[] getFileAsByteBuffer(string fileName) {
	File file = File(fileName, "r");
    auto buffer = new ubyte[file.size()];
    file.rawRead(buffer);
    writeln("read file.");
    return buffer;
}