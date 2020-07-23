module pulsewave;

import std.stdio;
import std.math;
import std.format;

import core.stdc.stdlib;
import core.stdc.string;
import core.thread.osthread;

import raylib;

private const static int   SAMPLE_RATE             = 22050;
private const static float FREQUENCY               = 440.0f;
private const static int   WAVELENGTH              = cast(int)(SAMPLE_RATE / FREQUENCY);
private const static int   AMPLITUDE               = 10000;
private const static int   MAX_SAMPLES_PER_UPDATE  = 4096;
private const static int   MAX_SAMPLES             = 512;

private short* data;

private bool isPlaying;
/++
 + plays a pulse wave into audio using raylib. used by chip8.
+/
class PulseWave {
    private AudioStream stream;
    private bool        isPlaying;

    static this() {
        data = cast(short*)malloc(short.sizeof * MAX_SAMPLES_PER_UPDATE);

        for (int i = 0; i < WAVELENGTH; i++) {
            data[i] = cast(short)(AMPLITUDE * sin(((2 * raylib.PI * i / WAVELENGTH))));
        }
    }

    /++
     + initializes the audio device with some boilerplate raylib code
     + and sets isPlaying to false
    +/
    this() {
        InitAudioDevice();

        stream = InitAudioStream(SAMPLE_RATE, 16, 1);
        PlayAudioStream(stream);
        isPlaying = false;
    }

    /++
     + fills the audiostream with a pulsewave if isPlaying is true.
    +/
    public void cycle() {
        int readCursor;
        short* writeBuf = cast(short *)malloc(short.sizeof*MAX_SAMPLES_PER_UPDATE);

        if (isPlaying) {
            if (IsAudioStreamProcessed(stream)) {
                int writeCursor = 0;
                while (writeCursor < MAX_SAMPLES_PER_UPDATE) {
                    int writeLength = MAX_SAMPLES_PER_UPDATE - writeCursor;
                    int readLength  = WAVELENGTH             - readCursor;
                    if (writeLength > readLength) writeLength = readLength;

                    memcpy(writeBuf + writeCursor, data + readCursor, writeLength*short.sizeof);

                    readCursor = (readCursor + writeLength) % WAVELENGTH;
                    writeCursor += writeLength;
                }

                UpdateAudioStream(stream, writeBuf, MAX_SAMPLES_PER_UPDATE);
            }
        }
    }

    /++
     + sets isPlaying to the specified value.
    +/
    public void setPlaying(bool newIsPlaying) {
        isPlaying = newIsPlaying;
    }
}
