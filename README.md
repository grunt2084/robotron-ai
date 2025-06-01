# robotron-ai
Lua scripts to automate Robotron 2084 play on MAME.  https://en.wikipedia.org/wiki/Robotron:_2084

This project takes advantage of the Lua Engine in MAME to automate gameplay of the classic Robotron 2084 Solid Blue Label arcade game.  To run this code, you will need MAME and the Robotron 2084 Solid Blue label ROMS.

To make updates with your own algorithms to play the game, you will want to familiarize yourself with the MAME Lua engine: http://docs.mamedev.org/techspecs/luaengine.html.

You will also want to have a look at Scott Tunstall's brilliant reverse-engineering of the Robotron ROMs, which he updates periodically, on Sean Riddle's site:  http://seanriddle.com/robomame.asm  The primary information required is how to insert tokens, start the game and move the joysticks AND the memory addresses and contents of all the objects (Robotrons, electrodes, family members, etc.) on the screen.  Knowing where everything is on the screen is required in order to adequately command movement of the player via the joysticks.  Understanding this information will allow you invent algorithms to outsmart the Robotrons and save the human family.

Since 1982 when the game was introduced by Williams, designed by Vid Kidz, I have spent way too many hours trying to beat the robotrons and have only been humiliated.  I am finally going to take the upper hand!

- grunt2084

Instructions:

  1. Place robotron.lua in the MAME plugins folder.
  2. Start MAME: > mame64 -console -window -rompath C:\your_path\ROMS  robotron
  3. Lua prompt> r = require "robotron"
  4. Lua prompt> r.start(4)

  Note that r.start(4) will start the game and run algorithm 4.  There are currently 1-4.
  
AI Evolution:

  1. Run towards family at top of list, shoot ahead.
     - No family: sit and spray in all directions.
  2. Move/Shoot robotron that requires least player repositioning, within a given range.
     - None in range: pickup nearest family & shoot ahead.
     - No family: sit and spray in all directions
  3. Move/Shoot nearest robotron.
  4. Move/shoot nearest foe in bubble, move away from hulks
     - None?: Move/shoot nearest (to line-of-fire) spheroid
     - None?: Chase nearest family, circular spray laser
     - No family: Move/shoot nearest foe (to line-of-fire)
  
YouTube Videos:
  - https://youtu.be/hPItPwnsjig
  - https://youtu.be/7dapV20G3iw
