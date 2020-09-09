# Chip8-D
A Chip-8 Interpretter written in D.

# Info

Accurate interpretter for the Chip-8, minus the instruction calls to the COSMAP VIP (as most games do not support this). Uses raylib to handle audio, video, and input, and contains a few test files used to test the workings of the emulator.

# Running

Can be compiled using 

`dub build`

and run using

`dub run`

By default, pong will be run on the CHIP-8, but by editting app.d you can configure it to run any CHIP-8 program you want.

# Testing

There's a couple tests in __resources/__. Both __c8_opcode.c8__ and __c8_test.c8__ are public tests I've downloaded online that test many of the CHIP-8 opcodes. Similarly, __c8_timer.c8__ is a test that ensures the CHIP-8 timer is functional. However, __c8_keys.c8__ is a test I've written to ensure that the CHIP-8 input and timers are functional. Feel free to use it if you want. When running __c8_keys.c8__, pressing a button should display the corresponding button code on screen (0-F). So, the DXYN instruction (the instruction responsible for drawing to screen) needs to be functional.
