-- MAME Lua module to control player in Robotron 2084


local M = {}

local screen = manager:machine().screens[":screen"]
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
M.my = {}
M.my.X = 0;
M.my.Y = 0;
-- Goto coordinates (if any)
M.go = {}
M.go.X = 0;
M.go.Y = 0;
-- Waypoint coordinates (if any)
M.wp = {}
M.wp.X = 0;
M.wp.Y = 0;
-- object type @ offset 0x08
M.daddy = 0x033a;
M.mommy = 0x0335;
M.mikey = 0x0330;
M.grunt = 0x3a76;
M.hulk = 0x00b6;
M.spheroid = 0x12c8;
M.enforcer = 0x1483;
M.spark = 0x14dc;
M.quark = 0x4bc9;
M.shell = 0x4FD5;
M.tank = 0x4DF2;
M.prog = 0x1f1f;
M.cruise = 0x2119;
M.brain = 0x1dd6;
M.electrode = 0x3aa9;

M.wavefoes = 0;

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

function M.screenfind(X, Y)
  screen:draw_box((X>>8)*2, (Y>>8), (X>>8)*2-4, (Y>>8)-4, 0xff00ffff, 0xff00ffff);
  --screen:draw_box((X)*2, (Y), (X)*2-4, (Y)-4, 0xff00ffff, 0xff00ffff);
end

function M.screenline(X1, Y1, X2, Y2)
  screen:draw_line((X1>>8)*2, Y1>>8, (X2>>8)*2, Y2>>8, 0xff00ffff); -- (x0, y0, x1, y1, line-color)
  --screen:draw_line(X1*2, Y1, X2*2, Y2, 0xff00ffff); -- (x0, y0, x1, y1, line-color)
  -- M.sleep(1);
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

-- cur_grunts EQU $BE68
-- cur_electrodes EQU $BE69
-- cur_mommies EQU $BE6A
-- cur_daddies EQU $BE6B
-- cur_mikeys EQU $BE6C
-- cur_hulks EQU $BE6D
-- cur_brains EQU $BE6E                        
-- cur_sphereoids EQU $BE6F
-- cur_quarks EQU $BE70
-- cur_tanks EQU $BE71
function M.grunt_count()
  return mem:read_i8(0xbe68)
end
function M.electrode_count()
  return mem:read_i8(0xBE69)
end
function M.mommie_count()
  return mem:read_i8(0xBE6A)
end
function M.daddie_count()
  return mem:read_i8(0xBE6B)
end
function M.mikey_count()
  return mem:read_i8(0xBE6C)
end
function M.hulk_count()
  return mem:read_i8(0xBE6D)
end
function M.brain_count()
  return mem:read_i8(0xBE6E)
end
function M.spheroid_count()
  return mem:read_i8(0xBE6F)
end
function M.quark_count()
  return mem:read_i8(0xBE70)
end
function M.tank_count()
  return mem:read_i8(0xBE71)
end
function M.foe_count()
  -- Enemies that keep wave alive missing enforcers
  return M.grunt_count() + M.brain_count() + M.spheroid_count() + M.quark_count() + M.tank_count();
end
function M.family_count()
  -- family count
  return M.mommie_count() + M.daddie_count() + M.mikey_count();
end

-- return object type string
function M.objtypestr(otype)
  if otype == M.daddy then return "daddy" end
  if otype == M.mommy then return "mommy" end
  if otype == M.mikey then return "mikey" end
  if otype == M.grunt then return "grunt" end
  if otype == M.hulk then return "hulk" end
  if otype == M.spheroid then return "spheroid" end
  if otype == M.enforcer then return "enforcer" end
  if otype == M.spark then return "spark" end
  if otype == M.quark then return "quark" end
  if otype == M.shell then return "shell" end
  if otype == M.tank then return "tank" end
  if otype == M.prog then return "prog" end
  if otype == M.cruise then return "cruise" end
  if otype == M.brain then return "brain" end
  if otype == M.electrode then return "electrode" end
end

-- stop update loop, sleep, reset inputs
-- (player button needs to go to 0 before a new game can start)
function M.stop()
  M.on = 0;
  M.move4(0);
  M.shoot4(0);
  -- M.sleep(1);
  M.start1.field:set_value(0)
end


-- print PC
function M.printcpu(str)
  -- B
  -- S
  -- D
  -- U
  -- CC
  -- PC
  -- Y
  -- DP
  -- X
  -- CURPC
  -- CURFLAGS
  -- A
  print(string.format("PC = %04X", cpu.state[str].value))
end

-- print location
function M.printloc(addr)
  data8 = 0x00FF & mem:read_i8(addr);
  data16 = 0xFFFF & mem:read_i16(addr);
  print(string.format("%04X: %04X: (%d) %02X: (%d)", addr, data16, data16, data8, data8))
end

-- set location
function M.setloc(addr, data)
  mem:write_i16(addr, data);
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
  -- check  
  if listptr == 0.
  then
    return nil;
  end
  --
  local addr = 0x0000ffff & mem:read_i16(listptr);
  while (addr ~= 0)
  do
    -- object are 24 bytes, 12 words??
    M.printhex(addr, 24);
    addr = 0x0000ffff & mem:read_i16(addr);
  end
end


--
function M.getobjxy(obj)
  if obj == nil then
    return nil, nil;
  end
  return obj.X, obj.Y;
end

function M.distance(obj1, obj2)
  dx = obj1.X - obj2.X;
  dy = obj1.Y - obj2.Y;
  return dx*dx + dy*dy;
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
  posxy = 0x0000ffff & mem:read_i16(addr + 4);
  --obj[4] = 0x0000ffff & mem:read_i16(addr + 6);
  -- Object ID???
  obj.id = 0x0000ffff & mem:read_i16(addr + 8);
  -- X,Y position
  if (obj.id == M.cruise) or (obj.id == M.prog) then
    obj.X = (0x0000ff00 & posxy);
    obj.Y = (0x00000ff & posxy)<<8;
  else
    obj.X = 0x0000ffff & mem:read_i16(addr + 10);
    obj.Y = 0x0000ffff & mem:read_i16(addr + 12);
  end
  -- obj[8] = 0x0000ffff & mem:read_i16(addr + 14);
  -- obj[9] = 0x0000ffff & mem:read_i16(addr + 16);
  -- obj[10] = 0x0000ffff & mem:read_i16(addr + 18);
  -- obj[11] = 0x0000ffff & mem:read_i16(addr + 20);
  -- obj[12] = 0x0000ffff & mem:read_i16(addr + 22);
  obj.dX = (obj.X - M.my.X)*2;
  obj.dY = obj.Y - M.my.Y;
  obj.dXr = math.floor(obj.dX*0.707 - obj.dY*0.707);
  obj.dYr = math.floor(obj.dX*0.707 + obj.dY*0.707);
  -- distance from play to object (squared: why waste time taking square-root?)
  obj.dist = obj.dX*obj.dX + obj.dY*obj.dY;

  return obj;
end


-- print-out array of processed objects
function M.printobjarray(objarray)
  for i=1,#objarray do
    print(M.objtypestr(objarray[i].id))
    print(string.format("X = %04X (%d), Y = %04X (%d)", objarray[i].X, objarray[i].X, objarray[i].Y, objarray[i].Y))
    print(string.format("dX = %d, dY = %d", objarray[i].dX, objarray[i].dY))
    print(string.format("dXr = %d, dYr = %d", objarray[i].dXr, objarray[i].dYr))
    print(string.format("dist = %d", objarray[i].dist))
    print('--')
  end
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
    -- update foe count
    if (objlist[i].id == M.enforcer) then M.wavefoes = M.wavefoes + 1 end;
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
  M.my.X = 0x0000ffff & mem:read_i16(0x9864);
  M.my.Y = 0x0000ffff & mem:read_i16(0x9866);
  --M.myX = (0x0000ffff & mem:read_i16(0x9864))>>8;
  --M.myY = (0x0000ffff & mem:read_i16(0x9866))>>8;
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
  if M.my.X < x then
  -- go right
    move = move | M.right
  end
  if M.my.X > x then
  -- go left
    move = move | M.left
  end
  if M.my.Y < y then
  -- go down
    move = move | M.down
  end
  if M.my.Y > y then
  -- go up
    move = move | M.up
  end
  -- update move
  return move;
end


-- shoot sequentially in every direction
function M.spraynpray(shoot)
  M.scount = M.scount + 1;
  if M.scount >= M.sdelay then
    -- shoot
    shoot = M.fire[M.fireindex];
    
    if M.fireindex >= #M.fire then
      M.fireindex = 1;
    else
      M.fireindex = M.fireindex + 1;
    end
    M.scount = 0;
  end
  return shoot;
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
    -- check Hulk (skip Hulks)
    if objtable[i].id == M.hulk then goto continue end
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
        move = M.left | M.down
      else
        move = M.right | M.up
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
        move = M.up | M.left
      else
        move = M.down | M.right
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
-- return index
function M.findnearest(objtable, range, otype)
  -- check objtable
  if objtable == nil then
    return 0
  end
  -- check range
  if range == nil then
    range = math.huge;
  end
  -- Minimum distance to nearest firing line.
  minD = math.huge;
  -- Index of nearest target
  minI = 0;

  -- Loop thru object array, find nearest
  for i=1, #objtable do
    -- check in-range
    if (objtable[i].dist > range) then goto continue end
    -- check otype
    if (otype ~= nil) and (objtable[i].id ~= otype) then goto continue end

    -- Find nearest
    if objtable[i].dist < minD then
      minD = objtable[i].dist;
      minI = i;
    end
    -- continue
    ::continue::
  end -- for-loop
  
  return minI;
end

-- Shoot nearest
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
      move = M.left | M.down
    else
      move = M.right | M.up
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
      move = M.up | M.left
    else
      move = M.down | M.right
    end
    if objtable[minI].dXr < 0 then
      shoot = M.left | M.down
    else
      shoot = M.right | M.up
    end
  end
  
  -- check hulk: run away, not towards
  if minI > 0 and objtable[minI].id == M.hulk then
    -- cw = {}
    -- cw.X = M.my.X + objtable[minI].dX;
    -- cw.Y = M.my.Y - objtable[minI].dY;
    -- ccw = {}
    -- ccw.X = M.my.X - objtable[minI].dX;
    -- ccw.Y = M.my.Y + objtable[minI].dY;
    -- move straight away
--    if (M.go.X <= 0) or (M.go.Y <= 0) then
      M.wp.X = M.my.X - objtable[minI].dX/2;
      M.wp.Y = M.my.Y - objtable[minI].dY;
      move = M.gotoxy(M.wp.X, M.wp.Y);
    -- elseif M.distance(M.go, cw) < M.distance(M.go, ccw) then
      -- M.wp.X = cw.X;
      -- M.wp.Y = cw.Y;
      -- -- move clockwise away
      -- move = M.gotoxy(cw.X, cw.Y);
      -- --move = M.gotoxy(M.my.X - objtable[minI].dX, M.my.Y - objtable[minI].dY);
    -- else
      -- M.wp.X = ccw.X;
      -- M.wp.Y = ccw.Y;
      -- -- move counter-clockwise away
      -- move = M.gotoxy(ccw.X, ccw.Y);
      -- --move = M.gotoxy(M.my.X - objtable[minI].dX, M.my.Y - objtable[minI].dY);
    -- end
  end
  
  return move, shoot;
end


-- Chase nearest family
-- return X,Y
function M.chase(famtable)
  minD = math.huge;
  minI = 0;
  --
  if famtable == nil or #famtable == 0 then
    return M.my.X, M.my.Y
  end
  --
  for i=1, #famtable do
    if famtable[i].dist < minD then
      minD = famtable[i].dist;
      minI = i;
    end
  end
  return famtable[minI].X, famtable[minI].Y;
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- function called every frame: update move and shoot
function M.update()
  M.count = M.count + 1;
    -- get player X,Y
  M.getmyxy();
  move = 0;
  shoot = 0;
  M.go.X = 0;
  M.go.Y = 0;
  -- On?
  if M.on == 0 then return end
  if M.on == 0 then return end
  -- call foe_count BEFORE getobjlist()!
  -- wavefoes are objects that keep the wave alive
  M.wavefoes = M.foe_count();
  M.family = M.getlistobj(M.family_ptr);
  -- M.grunts = M.getlistobj(M.grunts_hulks_brains_progs_cruise_tanks);
  -- M.electrodes = M.getlistobj(M.electrodes_ptr);
  M.baddies = M.getlistobj(M.grunts_hulks_brains_progs_cruise_tanks);
  M.baddies = M.getlistobj(M.electrodes_ptr, M.baddies);
  M.baddies = M.getlistobj(M.spheroids_enforcers_quarks_sparks_shells, M.baddies);
  if (M.family ~= nil) and (#M.family > 0) then
    -- move = M.gotoxy(M.family[1].X, M.family[1].Y);
    M.go.X, M.go.Y = M.chase(M.family);
  end
  
  if M.on == 1 then
    -- shoot
    -- M.spraynpray()
    if M.shootnrun() == 0 then
      shoot = M.spraynpray(M.getshoot4());
    end
    -- run
    if M.family ~= nil and #M.family > 0 then
      move = M.gotoxy(M.family[1].X, M.family[1].Y);
    else
      move = M.gotoxy(M.my.X, M.my.Y);
    end
  elseif  M.on == 2 then
    move, shoot = M.fireline(M.baddies);
    -- get family
    if (shoot == 0x0f) then
      move = M.gotoxy(M.chase(M.family));
      shoot = M.spraynpray(M.getshoot4());
    end
  elseif  M.on == 3 then
    move, shoot = M.shootnearest(M.baddies);
    -- get family
    if (shoot == 0x0f) then
      move = M.gotoxy(M.chase(M.family));
      shoot = M.spraynpray(M.getshoot4());
    end
  elseif M.on == 4 then
    -- Move/shoot nearest foe in bubble, move away from hulks
    move, shoot = M.shootnearest(M.baddies,50000000);
    -- None in bubble:
    if (move == 0) and (shoot == 0) then
      -- Move/shoot nearest line-of-fire spheroid or quark
      -- But ONLY if #M.family==0 OR M.foes > 1
      if (#M.family == 0) or (M.wavefoes > 1) then
        move, shoot = M.fireline(M.baddies, M.spheroid);
      end
      -- No spheroids:
      if (move == 0) and (shoot == 0) then
        -- Create path to nearest family: goto point (around hulks)
        -- Shoot nearest foe.
        if (M.go.X > 0) and (M.go.Y > 0) then
          -- move = M.gotoxy(M.family[1].X, M.family[1].Y);
          move = M.gotoxy(M.go.X, M.go.Y);
          -- But ONLY shoot if #M.family==0 OR M.wavefoes > 1
          if (#M.family == 0) or (M.wavefoes > 1) then
            shoot = M.spraynpray(M.getshoot4())
          else
            shoot = 0;
          end
        else
          -- kill remaining foes
          move, shoot = M.fireline(M.baddies);
        end
      end
    end
  end -- 4
  M.move4(move);
  M.shoot4(shoot);
end
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

return M
