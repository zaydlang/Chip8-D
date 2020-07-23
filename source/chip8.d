module chip8;

import cpu;
import pulsewave;

import std.stdio;
import std.digest: toHexString;
import std.file;
import std.conv;
import std.datetime.stopwatch;

import raylib;

import core.stdc.stdlib;

/++
 + a chip-8 cpu, contains a cpu and an pulsewave for playing audio.
 + loads roms from a buffer and handles player input, as well as
 + displaying them to screen. contains callbacks that the cpu can use.
+/
class Chip8 {
    private static const int   CYCLE_FREQUENCY   = 800;
    private static const int   NUM_PIXELS_WIDTH  = 64;
    private static const int   NUM_PIXELS_HEIGHT = 32;
    private static const int   SCREEN_WIDTH      = NUM_PIXELS_WIDTH  * PIXEL_SIDE_LENGTH;
    private static const int   SCREEN_HEIGHT     = NUM_PIXELS_HEIGHT * PIXEL_SIDE_LENGTH;
    private static const int   PIXEL_SIDE_LENGTH = 4;
    private static const Color TRUE_COLOR        = WHITE;
    private static const Color FALSE_COLOR       = BLACK;
    
    private bool[NUM_PIXELS_HEIGHT][NUM_PIXELS_WIDTH] pixelMap;

    private static int[] keyMappings = [
        KeyboardKey.KEY_ONE,
        KeyboardKey.KEY_TWO,
        KeyboardKey.KEY_THREE,
        KeyboardKey.KEY_FOUR,
        KeyboardKey.KEY_Q,
        KeyboardKey.KEY_W,
        KeyboardKey.KEY_E,
        KeyboardKey.KEY_R,
        KeyboardKey.KEY_A,
        KeyboardKey.KEY_S,
        KeyboardKey.KEY_D,
        KeyboardKey.KEY_F,
        KeyboardKey.KEY_Z,
        KeyboardKey.KEY_X,
        KeyboardKey.KEY_C,
        KeyboardKey.KEY_V
    ];
    private bool[16]        keys;

    private Cpu           cpu;
    private PulseWave     pulsewave;     // audio
    private bool          isEnabled;

    private long          lastCycleTime; // in millis
    private StopWatch     stopwatch;     // used to time cycle()

    /++
     + creates the cpu, starts the stopwatch (used to time cycle()), and initializes
     + the keys as well as the pulsewave.
    +/
    this() {
        this.cpu       = new Cpu(&this.updatePixelMap, &this.clearScreen, &this.isKeyPressed, &this.playSound, &this.pauseSound);
        this.isEnabled = false;
        this.stopwatch = StopWatch(AutoStart.yes);

        for (int i = 0; i < keys.length; i++) {
            keys[i] = false;
        }

        pulsewave = new PulseWave();
    }

    /++
     + loads the rom and enables the cpu.
    +/
    public void loadRom(ubyte[] buffer) {
        cpu.loadRom(buffer);
        isEnabled = true;
    }

    public void run() {
        InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Chip-8");

        while (!WindowShouldClose()) {
            long currentTime = stopwatch.peek.total!"msecs";
            long elapsedTime = currentTime - lastCycleTime;
            if (elapsedTime * CYCLE_FREQUENCY / 1000 > 1) {
                lastCycleTime = stopwatch.peek.total!"msecs";
                cycle();
            }

            // this code could be refactored maybe... there's duplicate information here
            // and with the isKeyPressed() functions, they send the same information to the
            // same class and maybe it'd be smarter to find a way to consolidate them.
            // i mean this is all caused by raylib's lack of event-based input system but that
            // could be changed by maybe making an event-based class for raylib's input system.
            //writeln(keys[0]); stdout.flush();
            for (ubyte i = 0; i < keyMappings.length; i++) {
                bool actualValue = IsKeyDown(keyMappings[i]);

                if (actualValue != keys[i]) {
                    keys[i] = actualValue;

                    if (keys[i]) // interrupt if pressed
                        cpu.keyboardInterrupt(i);
                }
            }
            
            pulsewave.cycle();
            render();
        }
    }

    /++
     + cycles the cpu once, if the chip8 is enabled.
    +/
    private void cycle() {
        if (isEnabled) {
            cpu.cycle();
        }
    }

    /++
     + renders the contents of pixelMap onto the screen.
     +/
    public void render() {
        BeginDrawing();

        for (int x = 0; x < NUM_PIXELS_WIDTH;  x++) {
        for (int y = 0; y < NUM_PIXELS_HEIGHT; y++) {
            Color color = pixelMap[x][y] ? TRUE_COLOR : FALSE_COLOR;
            DrawRectangle(x * PIXEL_SIDE_LENGTH, 
                          y * PIXEL_SIDE_LENGTH, 
                          PIXEL_SIDE_LENGTH, 
                          PIXEL_SIDE_LENGTH, 
                          color);
        }
        }

        EndDrawing();
    }

    /++
     + displays an error message and exits
     +/
    void displayErrorMessageAndExit(const char* errorMessage) {
	    stderr.writeln(errorMessage);
	    exit(1);
    }

    // DELEGATES FOR CPU:

    /++
     + inverts the specified pixel and returns true if the pixel becomes unset.
     +/
    private bool updatePixelMap(int x, int y) {
        int wrappedX = x % NUM_PIXELS_WIDTH;
        int wrappedY = y % NUM_PIXELS_HEIGHT;

        pixelMap[wrappedX][wrappedY] = !pixelMap[wrappedX][wrappedY];
        return !pixelMap[wrappedX][wrappedY]; // did we unset a previously set pixel?
    }

    /++
     + clears the contents of the screen
     +/
    private void clearScreen() {
        for (int x = 0; x < NUM_PIXELS_WIDTH;  x++) {
        for (int y = 0; y < NUM_PIXELS_HEIGHT; y++) {
            pixelMap[x][y] = false;
        }
        }
    }

    /++
     + returns true if the specified key is pressed
     +/
    private bool isKeyPressed(ubyte key) {
        return keys[key];
    }

    /++
     + plays the pulsewave
     +/
    private void playSound() {
        pulsewave.setPlaying(true);
    }

    /++
     + pauses the pulsewave
     +/
    private void pauseSound() {
        pulsewave.setPlaying(false);
    }
}