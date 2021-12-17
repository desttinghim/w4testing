# W4 Testbed

This is intended to be a platformer at some point but right now it's the snake
game tutorial with some changes. Specifically:

* Written in Zig
* Sound effects (2 of them!)
* Build file to automate calling `w4` (although it seems to have broken)
* Parses alda-like sound language at comptime to generate music system
  "bytecode" 
  
## Sound Language

This is probably the coolest part of this project.

``` alda
!tempo 112
!time 4/4
!instrument pulse50
o3 (mp)
c16 d e f g
```

The above code is parsed at comptime and generates an event list. This event
list acts like byte code for the music VM in `music.zig`, which decodes the 
generated list and plays back the audio. Here's twinkle twinkle little star in
the language:

``` alda
!tempo 112
!time 4/4
!instrument pulse50
o3
(mp) c4 c g g | a a g2 | f4 f e e | d d c2
g4 g f f | e e d2 | g4 g f f | e e d2
c4 c g g | a a g2 | f4 f e e | d d c2
```

To parse it I just call `alda.parseAlda(MAX_EVENTS, aldaStr)` and pass the result
to `music.playSong`.

## WAEL and WAE Design Thoughts

WAE uses SFX, Instruments, Parts, and Arrangements to playback music and sound
effects. 

WAEL is parsed into WAE data to be used at runtime.

### SFX
- Allows runtime parameters
- Sub-types: relative pitch, absolute pitch 
- Timing based on frames
- Specific to WASM-4 "synthesizer"

Meant to define a specific sound.

When using a relative pitch sound effect, a pitch parameter is required. The 
sound will be played back relative to the supplied pitch;

When using absolute pitch, the frequencies of the sounds are predefined.

### Instrument
- Sub-types: pitched, unpitched

Defines how WAEL will parse a section of music. 

An unpitched instrument defines a list of SFX that can be used as a drumkit.

A pitched instrument defines parameters to use when playing back each note. 

### Parts

Defines a sequence of notes. The sound is defined by the supplied instrument.

### Arrangements
Defines how parts will be played and how they loop


## TODO

- [ ] Make WAE more music aware (use note durations instead of frames, etc.)
- [ ] Make SFX type
	- [ ] Absolute pitch
	- [ ] Relative pitch
- [ ] Use SFX for drumkit
- [ ] Use SFX for in game sound effects
- [ ] Add legato notes
- [ ] Add glides between notes
- [ ]
