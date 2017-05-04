-- MAME Lua module to control player in Robotron 2084


local M = {}

local cpu = manager:machine().devices[":maincpu"]
local mem = cpu.spaces["program"]
local ioport = manager:machine():ioport()
local in0 = ioport.ports[":IN0"]
local in1 = ioport.ports[":IN1"]
M.move_up = { in0 = in0, field = in0.fields["Move Up"] }
M.move_down = { in0 = in0, field = in0.fields["Move Down"] }
M.move_left = { in0 = in0, field = in0.fields["Move Left"] }
M.move_right = { in0 = in0, field = in0.fields["Move Right"] }
M.fire_up = { in0 = in0, field = in0.fields["Fire Up"] }
M.fire_down = { in0 = in0, field = in0.fields["Fire Down"] }
M.fire_left = { in1 = in1, field = in1.fields["Fire Left"] }
M.fire_right = { in1 = in1, field = in1.fields["Fire Right"] }
M.start1 = { in0 = in0, field = in0.fields["1 Player Start"] }

M.family_ptr = 0x981F;
M.family = {};
-- grunts_hulks_brains_progs_cruise_tanks EQU $9821
M.grunts_hulks_brains_progs_cruise_tanks = 0x9821;
-- spheroids_enforcers_quarks_sparks_shells EQU $9817
M.spheroids_enforcers_quarks_sparks_shells = 0x9817;
--
M.baddies = {};
-- electrode_list_pointer EQU $9823
M.electrodes_ptr = 0x9823;
M.electrodes = {};
M.on = 0;
M.scount = 0;
M.sdelay = 15;
-- object element indices
M.Xindex = 6;
M.Yindex = 7;
-- counter
M.count = 0;
-- Player coordinates
M.myX = 0;
M.myY = 0;
-- object type @ offset 0x08
M.daddy = 0x033a;
M.mommy = 0x0335;
M.mikey = 0x0330;
M.grunt = 0x3a76;
M.hulk = 0x00b6;
M.spheroid = 0x12c8;
M.enforcer = 0x1483;
M.spark = 0x14dc;


-- c804 widget_pia_dataa (widget = I/O board)
-- bit 0  Move Up
-- bit 1  Move Down
-- bit 2  Move Left
-- bit 3  Move Right
-- bit 4  1 Player
-- bit 5  2 Players
-- bit 6  Fire Up
-- bit 7  Fire Down

-- c806 widget_pia_datab
-- bit 0  Fire Left
-- bit 1  Fire Right
-- bit 2
-- bit 3
-- bit 4
-- bit 5
-- bit 6
-- bit 7
M.up = 0x0001
M.down = 0x0002
M.left = 0x0004
M.right = 0x0008
M.fire = {M.up, M.up|M.left, M.left, M.left|M.down, M.down, M.down|M.right, M.right, M.right|M.up};
M.fireindex = 1;


local clock = os.clock
function M.sleep(n)  -- seconds
  local t0 = clock()
  while clock() - t0 <= n do end
end

-- insert coins
function M.credits(coins)
  mem:write_i8(0x9851, coins)
end

-- start game
function M.start(on)
  -- reset counter
  M.count = 0;
  -- add 99 coins
  mem:write_i8(0x9851, 0x99)
  -- start 1-player button
  M.start1.field:set_value(1)
  -- mem:write_i8(0xc804,0x10)
  -- update loop on
  M.on = on;
  -- register update loop callback function
  emu.register_frame_done(M.update,"frame")
end

-- stop update loop, sleep, reset inputs
-- (player button needs to go to 0 before a new game can start)
function M.stop()
  M.on = 0;
  M.sleep(1);
  -- mem:write_i8(0xc804,0x00)
  -- mem:write_i8(0xc806,0x00)
  M.start1.field:set_value(0)
end

-- print object hex
function M.printhex(addr, wlen)
  for i=0,wlen-2,2
  do
    print(string.format("%04X: %02X: %04X", addr+i, i, 0xFFFF & mem:read_i16(addr + i)))
  end
  print(string.format("--"))
end

-- print table x,y
function M.printtabxy(tabxy)
  
  print(string.format("tab = ["))
  for i=1,#tabxy,2 do
    print(string.format("  %d, %d", tabxy[i], tabxy[i+1]))
  end
  print(string.format("];"))
  
end


-- Follow linked-list: print out objects
function M.printlist(listptr)
  
  if listptr == 0.
  then
    return nil;
  end

  local addr = 0x0000ffff & mem:read_i16(listptr);
  
  while (addr ~= 0)
  do
    -- object are 24 bytes, 12 words??
    M.printhex(addr, 24);
    addr = 0x0000ffff & mem:read_i16(addr);
  end
end


--
function M.getobjxy(addr)
  local x, y;
  
  if addr == 0.
  then
    return nil, nil;
  end
  x = 0x0000ffff & mem:read_i16(addr + 0x0a);
  y = 0x0000ffff & mem:read_i16(addr + 0x0c);
  
  return x, y;
end

--
function M.getlistxy(listptr)
  local tabxy = {};
  
  if listptr == 0.
  then
    return nil;
  end

  local addr = 0x0000ffff & mem:read_i16(listptr);
  
  if addr == 0.
  then
    return nil;
  end

  local i = 1;
  while (addr ~= 0)
  do
    x, y = M.getobjxy(addr);

    tabxy[i + 0] = x
    tabxy[i + 1] = y
    i = i + 2;
    addr = 0x0000ffff & mem:read_i16(addr);
  end
  
  return tabxy;
end


-- Copy object (array of 12 16-bit values) from arcade memory into Lua array
function M.getobj(addr)
  -- check valid addr
  if addr == nil or addr == 0.
  then
    return nil;
  end
  -- intialize with zeros
  -- Customized array: ptr, id, x, y, dist, dx, dy, dxr, dxy
  --local obj = {0,0,0,0,0,0,0,0,0,0,0,0};
--  local obj = {0,0,0,0,0,0,0,0,0};
  obj = {};
  -- Next Object pointer
  obj.next = 0x0000ffff & mem:read_i16(addr + 0);
  --obj[2] = 0x0000ffff & mem:read_i16(addr + 2);
  -- obj[3] = 0x0000ffff & mem:read_i16(addr + 4);
  --obj[4] = 0x0000ffff & mem:read_i16(addr + 6);
  -- Object ID???
  obj.id = 0x0000ffff & mem:read_i16(addr + 8);
  -- X position
  obj.X = 0x0000ffff & mem:read_i16(addr + 10);
  -- Y position
  obj.Y = 0x0000ffff & mem:read_i16(addr + 12);
  -- obj[8] = 0x0000ffff & mem:read_i16(addr + 14);
  -- obj[9] = 0x0000ffff & mem:read_i16(addr + 16);
  -- obj[10] = 0x0000ffff & mem:read_i16(addr + 18);
  -- obj[11] = 0x0000ffff & mem:read_i16(addr + 20);
  -- obj[12] = 0x0000ffff & mem:read_i16(addr + 22);
  obj.dX = obj.X - M.myX;
  obj.dY = obj.Y - M.myY;
  obj.dXr = obj.dX*0.707 - obj.dY*0.707;
  obj.dYr = obj.dX*0.707 + obj.dY*0.707;
  -- distance from play to object (squared: why waste time taking square-root?)
  obj.dist = obj.dX*obj.dX + obj.dY*obj.dY;

  return obj;
end


-- append linked-list of objects to objlist array
function M.getlistobj(listptr, objlist)
  -- error check
  if listptr == nil or listptr == 0.
  then
    return nil;
  end

  -- if no objlist, start new one.  Otherwise, append to given list
  if objlist == nil then
    objlist = {};
  end

  -- 1st object address is at given listptr location
  local addr = 0x0000ffff & mem:read_i16(listptr);
  -- check if end-of-list
  if addr == 0.
  then
    return objlist;
  end

  -- next object index: append
  local i = #objlist + 1;
  while (addr ~= 0)
  do
    objlist[i] = M.getobj(addr);
    -- next, linked object address (first location in object)
    addr = objlist[i].next;
    -- next object index: append
    i = i + 1;
  end
  
  return objlist;
end


-- get current player x,y
function M.getmyxy()
  -- player_x EQU $09864  ; X coordinate of player. #$4A = middle of screen, #$07 = as far as can go left, #$8C = as far as can go right of screen 
  -- player_y EQU $09866  ; Y coordinate of player. #$7C = middle of screen, #$18 = as far as can go up, #$DF = as far as can go down
  M.myX = 0x0000ffff & mem:read_i16(0x9864);
  M.myY = 0x0000ffff & mem:read_i16(0x9866);
end


-- Get current 4-bit move command
function M.getmove4()
  -- c804 widget_pia_dataa (widget = I/O board)
  -- bit 0  Move Up
  -- bit 1  Move Down
  -- bit 2  Move Left
  -- bit 3  Move Right
  -- bit 4  1 Player
  -- bit 5  2 Players
  -- bit 6  Fire Up
  -- bit 7  Fire Down
  --
  -- get 4-bit move
  -- bit4 = 0x0000000f & mem:read_i8(0xc804);
  bit4 = 0x0000000f & in0:read();
  return bit4;
end


-- Apply 4-bit move command
function M.move4(bit4)
  M.move_up.field:set_value(bit4 & M.up);
  M.move_down.field:set_value(bit4 & M.down);
  M.move_right.field:set_value(bit4 & M.right);
  M.move_left.field:set_value(bit4 & M.left);
end

-- flip 4-bit move/shoot command
function M.flip4(bit4)
  -- bit 0  Move Up
  -- bit 1  Move Down
  -- bit 2  Move Left
  -- bit 3  Move Right
  flip = 0;
  if bit4 & 0x01 then
    flip = 0x02
  elseif bit4 & 0x02 then
    flip = 0x01
  end
  if bit4 & 0x04 then
    flip = 0x08
  elseif bit4 & 0x08 then
    flip = 0x04
  end
  return flip
end



-- Get current 4-bit shoot command
function M.getshoot4()
  -- c804 widget_pia_dataa (widget = I/O board)
  -- bit 0  Move Up
  -- bit 1  Move Down
  -- bit 2  Move Left
  -- bit 3  Move Right
  -- bit 4  1 Player
  -- bit 5  2 Players
  -- bit 6  Fire Up
  -- bit 7  Fire Down
  --
  -- c806 widget_pia_datab
  -- bit 0  Fire Left
  -- bit 1  Fire Right
  -- bit 2
  -- bit 3
  -- bit 4
  -- bit 5
  -- bit 6
  -- bit 7
  --
  -- get 4-bit fire (shift into lower 4 bits)
  bit4 = (0x00ff & in0:read()) >> 6;
  bit4 = bit4 | (0x00ff & in1:read()) << 2;
  return bit4;
end


-- Apply 4-bit shoot command
function M.shoot4(bit4)
  M.fire_up.field:set_value(bit4 & M.up);
  M.fire_down.field:set_value(bit4 & M.down);
  M.fire_right.field:set_value(bit4 & M.right);
  M.fire_left.field:set_value(bit4 & M.left);
end


-- return move command to go to x,y
function M.gotoxy(x, y)
  move = 0;      
  if M.myX < x then
  -- go right
    move = move | M.right
  end
  if M.myX > x then
  -- go left
    move = move | M.left
  end
  if M.myY < y then
  -- go down
    move = move | M.down
  end
  if M.myY > y then
  -- go up
    move = move | M.up
  end
  -- update move
  return move;
end


-- shoot sequentially in every direction
function M.spraynpray()
  M.scount = M.scount + 1;
  if M.scount >= M.sdelay then
    -- shoot
    M.shoot4(M.fire[M.fireindex]);
    
    if M.fireindex >= #M.fire then
      M.fireindex = 1;
    else
      M.fireindex = M.fireindex + 1;
    end
    M.scount = 0;
  end
end


-- shoot in direction of move
function M.shootnrun()
  -- clear fire, keep move
  move = M.getmove4();
  --
  if move == 0 then
    return move
  end
  --
  M.shoot4(move);
  --
  return move
end


-- Find nearest to firing lines
-- return 4-bit move, shoot commands
function M.fireline(objtable, otype)
  -- check objtable
  if objtable == nil then
    return 0,0
  end
  -- Minimum distance to nearest firing line.
  minD = math.huge;
  -- Index of nearest target
  minI = 0;
  move = 0;
  shoot = 0;
  -- Loop thru object array
  for i=1, #objtable do
    -- check otype
    if otype ~= nil and objtable[i].id ~= otype then goto continue end
    --
    -- check zero move X
    if objtable[i].dX == 0 then
      if objtable[i].dY > 0 then
        return 0, M.down;
      else
        return 0, M.up;
      end
    end
    -- check zero move Y
    if objtable[i].dY == 0 then
      if objtable[i].dX > 0 then
        return 0, M.right;
      else
        return 0, M.left;
      end
    end
 
    -- Check Enemy Rotation 0 deg about Player
    --
    if math.abs(objtable[i].dX) < math.abs(minD) then
      minD = objtable[i].dX;
      minI = i;
      if objtable[i].dX < 0 then
        move = M.left
      else
        move = M.right
      end
      if objtable[i].dY < 0 then
        shoot = M.up
      else
        shoot = M.down
      end
    end
    --
    if math.abs(objtable[i].dY) < math.abs(minD) then
      minD = objtable[i].dY;
      minI = i;
      if objtable[i].dY < 0 then
        move = M.up
      else
        move = M.down
      end
      if objtable[i].dX < 0 then
        shoot = M.left
      else
        shoot = M.right
      end
    end
    --
    -- Check Enemy Rotation 45 deg about Player
    --
    if math.abs(objtable[i].dXr) < math.abs(minD) then
      minD = objtable[i].dXr;
      minI = i;
      if objtable[i].dXr < 0 then
        move = M.right | M.up
      else
        move = M.left | M.down
      end
      if objtable[i].dYr < 0 then
        shoot = M.up | M.left
      else
        shoot = M.down | M.right
      end
    end
    --
    if math.abs(objtable[i].dYr) < math.abs(minD) then
      minD = objtable[i].dYr;
      minI = i;
      if objtable[i].dYr < 0 then
        move = M.down | M.right
      else
        move = M.up | M.left
      end
      if objtable[i].dXr < 0 then
        shoot = M.left | M.down
      else
        shoot = M.right | M.up
      end
    end
    --
    -- continue
    ::continue::
  end -- for-loop

  -- check hulk: run away, not towards
--  if minI > 0 and objtable[minI][5] == 182 then
  if minI > 0 and objtable[minI].id == 183 then
    -- move = M.flip4(shoot);
    move = 0
    shoot = 0
  end
  
  return move, shoot;
end


-- Find nearest
-- return 4-bit move, shoot commands
function M.shootnearest(objtable, range)
  -- check objtable
  if objtable == nil then
    return 0,0
  end
  -- check range
  if range == nil then
    range = math.huge;
  end
  -- Minimum distance to nearest firing line.
  minD = math.huge;
  -- Index of nearest target
  minI = 0;
  move = 0;
  shoot = 0;

  -- Loop thru object array, find nearest
  for i=1, #objtable do
    -- check in-range
    if (objtable[i].dist > range) then goto continue end

    -- Find nearest Enemy
    if objtable[i].dist < minD then
      minD = objtable[i].dist;
      minI = i;
    end
    -- continue
    ::continue::
  end -- for-loop

  if minI == 0 then return 0,0 end
  -- calculate move, shoot
  -- put this in a function?
  -- assume dX is min
  minD = objtable[minI].dX;
--  if math.abs(objtable[minI].dX) < math.abs(minD) then
    if objtable[minI].dX < 0 then
      move = M.left
    else
      move = M.right
    end
    if objtable[minI].dY < 0 then
      shoot = M.up
    else
      shoot = M.down
    end
--  end
  --
  if math.abs(objtable[minI].dY) < math.abs(minD) then
    minD = objtable[minI].dY;
    if objtable[minI].dY < 0 then
      move = M.up
    else
      move = M.down
    end
    if objtable[minI].dX < 0 then
      shoot = M.left
    else
      shoot = M.right
    end
  end
  --
  -- Check Enemy Rotation 45 deg about Player
  --
  if math.abs(objtable[minI].dXr) < math.abs(minD) then
    minD = objtable[minI].dXr;
    if objtable[minI].dXr < 0 then
      move = M.right | M.up
    else
      move = M.left | M.down
    end
    if objtable[minI].dYr < 0 then
      shoot = M.up | M.left
    else
      shoot = M.down | M.right
    end
  end
  --
  if math.abs(objtable[minI].dYr) < math.abs(minD) then
--    minD = objtable[minI].dYr;
    if objtable[minI].dYr < 0 then
      move = M.down | M.right
    else
      move = M.up | M.left
    end
    if objtable[minI].dXr < 0 then
      shoot = M.left | M.down
    else
      shoot = M.right | M.up
    end
  end
  
  -- check hulk: run away, not towards
  if minI > 0 and objtable[minI].id == M.hulk then
    move = M.gotoxy(M.myX - objtable[minI].dX, M.myY - objtable[minI].dY);
  end
  
  return move, shoot;
end


-- Chase nearest family
-- return X,Y
function M.chase(objtable)
  minD = math.huge;
  minI = 0;
  --
  if objtable == nil or #objtable == 0 then
    return M.myX, M.myY
  end
  --
  for i=1, #objtable do
    if objtable[i].dist < minD then
      minD = objtable[i].dist;
      minI = i;
    end
  end
  return objtable[minI].X, objtable[minI].Y;
end

-- function called every frame: update move and shoot
function M.update()
  M.count = M.count + 1;
    -- get player X,Y
  M.getmyxy();
  move = 0;
  shoot = 0;
  -- On?
  if M.on == 0 then return end
  --
  M.family = M.getlistobj(M.family_ptr);
  -- M.grunts = M.getlistobj(M.grunts_hulks_brains_progs_cruise_tanks);
  -- M.electrodes = M.getlistobj(M.electrodes_ptr);
  M.baddies = M.getlistobj(M.grunts_hulks_brains_progs_cruise_tanks);
  M.baddies = M.getlistobj(M.electrodes_ptr, M.baddies);
  M.baddies = M.getlistobj(M.spheroids_enforcers_quarks_sparks_shells, M.baddies);

  if M.on == 1 then
    -- shoot
    -- M.spraynpray()
    if M.shootnrun() == 0 then
      M.spraynpray()
    end
    -- run
    if M.family ~= nil and #M.family > 0 then
      M.move4(M.gotoxy(M.family[1].X, M.family[1].Y))
    else
      M.move4(M.gotoxy(M.myX, M.myY))
    end
  elseif  M.on == 2 then
    move, shoot = M.fireline(M.baddies);
    -- get family
    if (shoot == 0x0f) then
      M.move4(M.gotoxy(M.chase(M.family)))
      M.spraynpray()
    else
      M.move4(move);
      M.shoot4(shoot);
    end
  elseif  M.on == 3 then
    move, shoot = M.shootnearest(M.baddies);
    -- get family
    if (shoot == 0x0f) then
      M.move4(M.gotoxy(M.chase(M.family)))
      M.spraynpray()
    else
      M.move4(move);
      M.shoot4(shoot);
    end
  elseif M.on == 4 then
    -- Move/shoot nearest foe in bubble, move away from hulks
    move, shoot = M.shootnearest(M.baddies,50000000);
    -- print(move,shoot)
    if (move == 0) and (shoot == 0) then
      -- Move/shoot nearest line-of-fire spheroid or quark
      move, shoot = M.fireline(M.baddies, M.spheroid);
      if (move == 0) and (shoot == 0) then
        -- Create path to nearest family: goto point (around hulks)
        -- Shoot nearest foe.
        if (M.family ~= nil) and (#M.family > 0) then
          move = M.gotoxy(M.family[1].X, M.family[1].Y);
        else
          move = M.gotoxy(M.myX, M.myY);
        end
        if move == 0 then
          -- no family: sit, spray & pray
        end
      end
    end
  end -- 4
  M.move4(move);
  M.shoot4(shoot);
end
  
return M
