# W4 Platformer

This will be a platformer for the WASM4 platform. From a flavor perspective I'm
thinking of occult fantasy. My personal goals for the project are:

- Create an original and appealing soundtrack
  - Learn how to compose music by "stealing like an artist"
- Create appealing visuals
- Create a compelling gameplay loop, even if it's not particularily interesting
  or original.
- Explore what tools are useful game development 
  
## WAE/WAEL

WAE (Wasm Audio Engine) and WAEL (WAE Language) are the custom audio backend I
am experimentally writing for this project. It is based on Alda, Lilypond, and
Pently primarily. The goal is to make adding audio to my game easy and without
forcing a dependency on any composition tools. Also, I want to be able to work
primarily with my keyboard - moving my hand between my keyboard and the mouse is
annoying when I'm trying to be in the flow of creating.

### Design Thoughts

WAE uses SFX, Instruments, Parts, and Arrangements to playback music and sound
effects. 

WAEL is parsed into WAE data to be used at runtime.

#### SFX
- Allows runtime parameters
- Sub-types: relative pitch, absolute pitch 
- Timing based on frames
- Specific to WASM-4 "synthesizer"

Meant to define a specific sound.

When using a relative pitch sound effect, a pitch parameter is required. The 
sound will be played back relative to the supplied pitch;

When using absolute pitch, the frequencies of the sounds are predefined.

#### Instrument
- Sub-types: pitched, unpitched

Defines how WAEL will parse a section of music. 

An unpitched instrument defines a list of SFX that can be used as a drumkit.

A pitched instrument defines parameters to use when playing back each note. 

#### Parts

Defines a sequence of notes. The sound is defined by the supplied instrument.

#### Song
Defines how parts will be played and how they loop
