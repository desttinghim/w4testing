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
