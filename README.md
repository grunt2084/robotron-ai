# robotron-ai
Lua scripts to automate Robotron 2084 play on MAME.

This project takes advantage of the Lua Engine in MAME to automate gameplay of the classic Robotron 2084 Solid Blue Label arcade game.  To run this code, you will need MAME and the Robotron 2084 Solid Blue label ROMS.

To make updates with your own algorithms to play the game, you will want to familiarize yourself with the MAME Lua engine: http://docs.mamedev.org/techspecs/luaengine.html.

You will also want to have a look at Scott Tunstall's brilliant reverse-engineering of the Robotron ROMs, which he updates periodically, on Sean Riddle's site:  http://seanriddle.com/robomame.asm  The primary information required is how to insert tokens, start the game and move the joysticks AND the memory addresses and contents of all the objects (Robotrons, electrodes, family members, etc.) on the screen.  Knowing where everything is on the screen is required in order to adequately command movement of the player via the joysticks.  Understanding this information will allow you invent algorithms to outsmart the Robotrons and save the human family.

Since 1982 when the game was introduced by Midway, designed by Vid Kidz, I have spent way too many hours trying to beat the robotrons and have only been humiliated.  I am finally going to take the upper hand!

Instructions:

  1. Place robotron.lua in the MAME plugins folder.
  2. Start MAME: > mame64 -console -window -rompath C:\your_path\ROMS  robotron
  3. Lua prompt> r = require "robotron"
  4. Lua prompt> r.start(2)

  
  
- grunt2084
