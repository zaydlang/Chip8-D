module cpu;

import std.stdio;
import std.random;
import std.algorithm;
import std.conv;

import core.stdc.stdlib;

import timer;

/++
 + a chip-8 cpu, capable of running all chip-8 instructions
 + except for 0NNN, which is a call to the RCA 1802 for Cosmic
 + VIP and is not necessary for most ROMs. More info at:
 + https://en.wikipedia.org/wiki/CHIP-8
 +/
class Cpu {
    public  const static int RAM_SIZE                = 0x1000;
    public  const static int NUM_REGISTERS           = 16;
    public  const static int SIZE_OF_INSTRUCTION     = 2;

    // absolute addresses
    private const static int ABSOLUTE_FONT_LOCATION  = 0x000;
    private const static int ABSOLUTE_ROM_LOCATION   = 0x200;
    private const static int ABSOLUTE_STACK_LOCATION = 0xEFF;
    
    private const static ubyte[] FONTSET = [
        0xF0, 0x90, 0x90, 0x90, 0xF0,
        0x20, 0x60, 0x20, 0x20, 0x70,
        0xF0, 0x10, 0xF0, 0x80, 0xF0,
        0xF0, 0x10, 0xF0, 0x10, 0xF0,
        0x90, 0x90, 0xF0, 0x10, 0x10,
        0xF0, 0x80, 0xF0, 0x10, 0xF0,
        0xF0, 0x80, 0xF0, 0x90, 0xF0,
        0xF0, 0x10, 0x20, 0x40, 0x40,
        0xF0, 0x90, 0xF0, 0x90, 0xF0,
        0xF0, 0x90, 0xF0, 0x10, 0xF0,
        0xF0, 0x90, 0xF0, 0x90, 0x90,
        0xE0, 0x90, 0xE0, 0x90, 0xE0,
        0xF0, 0x80, 0x80, 0x80, 0xF0,
        0xE0, 0x90, 0x90, 0x90, 0xE0,
        0xF0, 0x80, 0xF0, 0x80, 0xF0,
        0xF0, 0x80, 0xF0, 0x80, 0x80
    ];

    private ubyte[Cpu.NUM_REGISTERS] registers;
    private ushort                   registerI;
    private ushort                   addressRegister;
    private ushort                   stackPointer;
    
    private ubyte[Cpu.RAM_SIZE]      ram;

    // used in the execution stage of the cpu
    private ubyte  opcode0;
    private ubyte  opcode1;
    private ubyte  opcode2;
    private ubyte  opcode3;
    private ushort fullOpcode;

    private bool isEnabled;
    private bool isWaitingForInterrupt;

    private Timer delayTimer;
    private Timer soundTimer;

    // callbacks
    private bool delegate(int, int) drawToScreen;
    private void delegate()         clearScreen;
    private bool delegate(ubyte)    isKeyPressed;
    private void delegate()         playSound;
    private void delegate()         pauseSound;

    /++
     + loads the delegates, loads the fontset into the ram, and loads the timers.
    +/
    this(bool delegate(int, int) drawToScreen, void delegate() clearScreen, bool delegate(ubyte) isKeyPressed, void delegate() playSound, void delegate() pauseSound) {
        this.drawToScreen          = drawToScreen;
        this.clearScreen           = clearScreen;
        this.isKeyPressed          = isKeyPressed;
        this.playSound             = playSound;
        this.pauseSound            = pauseSound;

        this.addressRegister       = ABSOLUTE_ROM_LOCATION;
        this.stackPointer          = ABSOLUTE_STACK_LOCATION;
        this.isEnabled             = false;
        this.isWaitingForInterrupt = false;

        // load fontset into ram        
        ram[ABSOLUTE_FONT_LOCATION..ABSOLUTE_FONT_LOCATION + FONTSET.length] = FONTSET[0..FONTSET.length];

        // load timers
        delayTimer = new Timer(60, 0);
        soundTimer = new Timer(60, 0);
    }

    /++
     + loads the buffer into the ram
    +/
    void loadRom(ubyte[] buffer) {
        // copy rom into ram at ABSOLUTE_ROM_LOCATION and enable cpu
        ram[ABSOLUTE_ROM_LOCATION..ABSOLUTE_ROM_LOCATION + buffer.length] = buffer[0..buffer.length];
        isEnabled = true;
        writeln("loaded rom.");
    }

    /++
     + pushes the byte to the stack
    +/
    void stackPush(ubyte value) {
        ram[stackPointer] = value;
        stackPointer--;
    }

    /++
     + pops from the stack and returns the byte
    +/
    ubyte stackPop() {
        stackPointer++;
        return ram[stackPointer];
    }

    /++
     + Continuation of the following instruction:
     + FX0A -> a key press is awaited, then stored in register X
    +/
    void keyboardInterrupt(ubyte value) {
        if (isWaitingForInterrupt) {
            registers[opcode1] = value;

            isWaitingForInterrupt = false;
            isEnabled             = true;
        }
    }

    /++
     + runs one cpu cycle. comprised of a fetch and execute stage.
    +/
    void cycle() {
        // run next instruction
        if (isEnabled) {
            fetch();
            execute();
        }

        // play audio if sound timer is ticking
        if (soundTimer.getValue() == 0) {
            pauseSound();
        } else {
            playSound();
        }
    }

    /++
     + fetches the next opcode using the addressRegister from the rom.
    +/
    void fetch() {
        const ubyte hiByte = ram[addressRegister + 0];
        const ubyte loByte = ram[addressRegister + 1];

        opcode0 = hiByte >> 4;
        opcode1 = hiByte & 0x0F;
        opcode2 = loByte >> 4;
        opcode3 = loByte & 0x0F;
        fullOpcode = cast(ushort)((hiByte << 8) + loByte);

        addressRegister += Cpu.SIZE_OF_INSTRUCTION;
    }

    /++
     + executes the current instruction using opcode0, opcode1, opcode2, and opcode3
    +/
    void execute() {
        stdout.flush();
        switch (opcode0) {
        case 0x0:
            switch (opcode3) {
            case 0x0:     // 00E0 -> clear screen
                clearScreen();
                break;

            default:      // 00EE -> return from subroutine
                ubyte loAddressRegister = stackPop();
                ubyte hiAddressRegister = stackPop();
                addressRegister = cast(ushort)((hiAddressRegister << 8) + loAddressRegister);
                break;
            }
            break;
        
        case 0x1:         // 1NNN -> jump to address NNN
            addressRegister = cast(ushort)((opcode1 << 8) + (opcode2 << 4) + (opcode3));
            break;
        
        case 0x2:         // 2NNN -> calls subroutine at NNN
            ubyte hiAddressRegister = cast(ubyte)(addressRegister >> 8);
            ubyte loAddressRegister = cast(ubyte)(addressRegister & 0xFF);
            stackPush(hiAddressRegister);
            stackPush(loAddressRegister);
            addressRegister = cast(ushort)((opcode1 << 8) + (opcode2 << 4) + (opcode3));
            break;
        
        case 0x3:         // 3XNN -> skips next instruction if register X == NN
            if (registers[opcode1] == (opcode2 << 4) + (opcode3))
                addressRegister += SIZE_OF_INSTRUCTION;
            break;

        case 0x4:         // 4XNN -> skips next instruction if register X != NN
            if (registers[opcode1] != (opcode2 << 4) + (opcode3))
                addressRegister += SIZE_OF_INSTRUCTION;
            break;
        
        case 0x5:         // 5XY0 -> skips next instruction if register X == register Y
            if (registers[opcode1] == registers[opcode2])
                addressRegister += SIZE_OF_INSTRUCTION;
            break;
        
        case 0x6:         // 6XNN -> sets register X to NN
            registers[opcode1] = cast(ubyte)((opcode2 << 4) + (opcode3));
            break;
        
        case 0x7:         // 7XNN -> adds NN to register X
            registers[opcode1] += (opcode2 << 4) + (opcode3);
            break;
        
        case 0x8:
            switch (opcode3) {
            case 0x0:     // 8XY0 -> sets register X to register Y
                registers[opcode1] =  registers[opcode2];
                break; 
            
            case 0x1:     // 8XY1 -> sets register X to (register X | register Y)
                registers[opcode1] |= registers[opcode2];
                break;
            
            case 0x2:     // 8XY2 -> sets register X to (register X & register Y)
                registers[opcode1] &= registers[opcode2];
                break;
            
            case 0x3:     // 8XY3 -> sets register X to (register X ^ register Y)
                registers[opcode1] ^= registers[opcode2];
                break;
            
            case 0x4:     // 8XY4 -> sets register X to (register X + register Y). register F is carry.
                // carry bit
                registers[0xF] = ((cast(int)registers[opcode1] + cast(int)registers[opcode2]) > 256);

                registers[opcode1] += registers[opcode2];
                break;
            
            case 0x5:     // 8XY5 -> sets register X to (register X - register Y). register F is !borrow.
                // borrow bit
                registers[0xF] = !((cast(int)registers[opcode1] - cast(int)registers[opcode2]) < 0);

                registers[opcode1] -= registers[opcode2];
                break;
            
            case 0x6:     // 8XY6 -> stores least significant bit of register X in register F, shifts register X right by 1.
                registers[0xF] = registers[opcode1] & 0x1;
                registers[opcode1] >>= 1;
                break;
            
            case 0x7:     // 8XY7 -> sets register X to (register Y - register X). register F is !borrow.
                // borrow bit
                registers[0xF] = !((cast(int)registers[opcode2] - cast(int)registers[opcode1]) < 0);

                registers[opcode1] = cast(ubyte)(registers[opcode2] - registers[opcode1]);
                break;
            
            case 0xE:     // 8XYE -> stores most significant bit of register X in register F, shifts register X left by 1.
                registers[0xF] = registers[opcode1] >> 7;
                registers[opcode1] <<= 1;
                break;
            
            default:
                throw new Error("Unsupported opcode.");
            }
            break;
        
        case 0x9:         // 9XY0 -> skips next instruction if register X != register Y
            if (registers[opcode1] != registers[opcode2])
                addressRegister += SIZE_OF_INSTRUCTION;
            break;
        
        case 0xA:         // ANNN -> sets I to the address NNN
            registerI = cast(ushort)((opcode1 << 8) + (opcode2 << 4) + (opcode3));
            break;
        
        case 0xB:         // BNNN -> jumps to address (register 0 + NNN)
            addressRegister = cast(ushort)((opcode1 << 8) + (opcode2 << 4) + (opcode3) + registers[0]);
            break;
        
        case 0xC:         // CXNN -> sets register X to NN & rand(0, 255)
            registers[opcode1] = cast(ubyte)(((opcode2 << 4) + opcode3) & uniform!"[]"(0, 255));
            break;

        case 0xD:         // DXYN -> draws sprite at (register X, register Y). width 8 pixels, height N pixels.
                          //         data for sprite taken from I. reigster VF is set if any pixels went from set to unset
                          //         register I's value doesnt change
            // each horizontal strip is one ubyte of data fetched from ram
            int xOffset = registers[opcode1];
            int yOffset = registers[opcode2];
            registers[0xF] = 0;

            for (int y = 0; y < opcode3; y++) {
                ubyte data = ram[registerI + y];
                
                for (int x = 0; x < 8; x++) {
                    bool value = (data >> (7 - x)) & 1; // nth bit. the (7 - x) part is for endianness

                    if (value) 
                        registers[0xF] |= (drawToScreen(x + xOffset, y + yOffset)); // set register F if any pixels went from set to unset
                }
            }

            break;
        
        case 0xE:
            switch (opcode3) {
            case 0xE:     // EX9E -> skips next instruction if the key stored in register X is     pressed
                if (isKeyPressed(registers[opcode1]))
                    addressRegister += SIZE_OF_INSTRUCTION;
                break;
            
            case 0x1:     // EXA1 -> skips next instruction if the key stored in register X is not pressed
                if (!isKeyPressed(registers[opcode1]))
                    addressRegister += SIZE_OF_INSTRUCTION;
                break;
            
            default:
                throw new Error("Unsupported opcode.");
            }
            break;

        case 0xF:
            switch (opcode3) {
            case 0x7:     // FX07 -> sets register X to the value of the delay timer
                registers[opcode1] = delayTimer.getValue();
                break;
            
            case 0xA:     // FX0A -> a key press is awaited, then stored in register X
                isWaitingForInterrupt = true;
                isEnabled             = false;
                break;
            
            case 0x8:     // FX18 -> sets the sound timer to register X
                soundTimer.setValue(registers[opcode1]);
                break;
            
            case 0xE:     // FX1E -> adds register X to I. does not affect register F.
                registerI += registers[opcode1];
                break;
            
            case 0x9:     // FX29 -> sets I to the location of the sprite for the character (0 - F) in register X.
                registerI = ABSOLUTE_FONT_LOCATION + 5 * registers[opcode1];
                break;
            
            case 0x3:     // FX33 -> stores the BCD representation of VX into I.
                          //         hundreds digit at I + 0
                          //         tens     digit at I + 1
                          //         ones     digit at I + 2
                
                int bcd = (cast(int)registers[opcode1]);
                ram[registerI + 0] = cast(ubyte)(bcd / 100);
                ram[registerI + 1] = cast(ubyte)((bcd % 100) / 10);
                ram[registerI + 2] = cast(ubyte)(bcd % 10);
                break;
            
            case 0x5:
                switch (opcode2) {
                case 0x1: // FX15 -> sets the delay timer to register X
                    delayTimer.setValue(registers[opcode1]);
                    break;

                case 0x5: // FX55 -> stores register 0 to register X (inclusive) in   memory starting at address I. I is unmodified.
                    for (int i = 0; i < opcode1 + 1; i++) {
                        ram[registerI + i] = registers[i];
                    }
                    break;
                case 0x6: // FX65 -> fills  register 0 to register X (inclusive) from memory starting at address I. I is unmodified.
                    for (int i = 0; i < opcode1 + 1; i++) {
                        registers[i] = ram[registerI + i];
                    }
                    break;
                default:
                    throw new Error("Unsupported opcode.");
                }
                break;
            
            default:
                throw new Error("Unsupported opcode.");
            }
            break;
            
        default:
            throw new Error("Unsupported opcode.");
        }
    }
}