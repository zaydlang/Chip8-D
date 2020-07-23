module timer;

import std.stdio;
import std.datetime.stopwatch;


/++
 + a timer. used for sound and delay for the cpu.
+/
class Timer {
    private long  previousTime;
    private int   frequency;
    private ubyte previousValue;

    private StopWatch stopwatch; // used to know how much time elapsed on calls to getValue()

    
    /++
     + constructs the timer, and starts it. the timer only updates its value
     + when getValue() is called, which avoids having to constantly tick()
     + the timer.
     +/
    this(int frequency, ubyte previousValue) {
        this.previousTime  = stopwatch.peek.total!"msecs";
        this.frequency     = frequency;
        this.previousValue = previousValue;

        this.stopwatch     = StopWatch(AutoStart.yes);
    }

    /++
     + calculates the current value and returns it.
     +/
    public ubyte getValue() {
        long  currentTime  = stopwatch.peek.total!"msecs";
        int   elapsedTime  = cast(int)(currentTime - previousTime);
        ubyte elapsedTicks = cast(ubyte)(elapsedTime * frequency / 1000);
            
        ubyte currentValue = 0;
        if (elapsedTicks <= this.previousValue) {
            currentValue = cast(ubyte)(this.previousValue - elapsedTicks);
        }

        return currentValue;
    }

    /++
     + sets the value to a specified amount.
     +/
    public void setValue(ubyte value) {
        previousValue = value;
        previousTime  = stopwatch.peek.total!"msecs";
    }
}