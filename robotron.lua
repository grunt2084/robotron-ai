local M = {}

local cpu = manager:machine().devices[":maincpu"]
local mem = cpu.spaces["program"]

M.family_ptr = 0x981F;
M.family = {};
-- grunts_hulks_brains_progs_cruise_tanks EQU $9821
M.grunts_ptr = 0x9821;
M.grunts = {}
-- spheroids_enforcers_quarks_sparks_shells EQU $9817
M.quarks_ptr = 0x9817;
M.quarks = {};
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
  -- add 99 coins
  mem:write_i8(0x9851, 0x99)
  -- start 1-player button
  mem:write_i8(0xc804,0x10)
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
  mem:write_i8(0xc804,0x00)
  mem:write_i8(0xc806,0x00)
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


--
function M.getobj(addr)
  if addr == 0.
  then
    return nil;
  end

  local obj = {0,0,0,0,0,0,0,0,0,0,0,0};
  
  -- Next Object pointer
  obj[1] = 0x0000ffff & mem:read_i16(addr + 0);
  obj[2] = 0x0000ffff & mem:read_i16(addr + 2);
  obj[3] = 0x0000ffff & mem:read_i16(addr + 4);
  obj[4] = 0x0000ffff & mem:read_i16(addr + 6);
  obj[5] = 0x0000ffff & mem:read_i16(addr + 8);
  -- X position
  obj[6] = 0x0000ffff & mem:read_i16(addr + 10);
  -- Y position
  obj[7] = 0x0000ffff & mem:read_i16(addr + 12);
  obj[8] = 0x0000ffff & mem:read_i16(addr + 14);
  obj[9] = 0x0000ffff & mem:read_i16(addr + 16);
  obj[10] = 0x0000ffff & mem:read_i16(addr + 18);
  obj[11] = 0x0000ffff & mem:read_i16(addr + 20);
  obj[12] = 0x0000ffff & mem:read_i16(addr + 22);
  
  return obj;
end


--
function M.getlistobj(listptr, objlist)
  if listptr == nil or listptr == 0.
  then
    return nil;
  end

  if objlist == nil then
    objlist = {};
  end

  local addr = 0x0000ffff & mem:read_i16(listptr);
  
  if addr == 0.
  then
    return objlist;
  end

  local i = #objlist + 1;
  while (addr ~= 0)
  do
    objlist[i] = M.getobj(addr);
    addr = objlist[i][1];
    i = i + 1;
  end
  
  return objlist;
end


-- get current player x,y
function M.getmyxy()
  local x, y;

  -- player_x EQU $09864  ; X coordinate of player. #$4A = middle of screen, #$07 = as far as can go left, #$8C = as far as can go right of screen 
  -- player_y EQU $09866  ; Y coordinate of player. #$7C = middle of screen, #$18 = as far as can go up, #$DF = as far as can go down
  x = 0x0000ffff & mem:read_i16(0x9864);
  y = 0x0000ffff & mem:read_i16(0x9866);
  
  return x, y;
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
  bit4 = 0x0000000f & mem:read_i8(0xc804);
  return bit4;
end


-- Apply 4-bit move command
function M.move4(bit4)
  -- c804 widget_pia_dataa (widget = I/O board)
  -- bit 0  Move Up
  -- bit 1  Move Down
  -- bit 2  Move Left
  -- bit 3  Move Right
  -- bit 4  1 Player
  -- bit 5  2 Players
  -- bit 6  Fire Up
  -- bit 7  Fire Down
  -- clear move, keep fire
  pia = 0x000000f0 & mem:read_i8(0xc804);
  mem:write_i8(0xc804, pia | bit4)
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
  bit4 = (0x00ff & mem:read_i8(0xc804)) >> 6;
  bit4 = bit4 | (0x00ff & mem:read_i8(0xc806)) << 2;
  return bit4;
end


-- Apply 4-bit shoot command
function M.shoot4(bit4)
  bit4 = bit4 & 0x000f;
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
  -- clear fire, keep move
  pia1 = 0x0000003f & mem:read_i8(0xc804);
  -- pia2 = 0x00000000 & mem:read_i8(0xc806);
  
  mem:write_i8(0xc804, (pia1 | (bit4 & 0x0003) << 6))
  mem:write_i8(0xc806, (bit4 >> 2))
end


-- generate move command to go to x,y
function M.gotoxy(x, y)
  
  mx, my = M.getmyxy();

  move = 0;      
  if mx < x then
  -- go right
    move = move | M.right
  end
  if mx > x then
  -- go left
    move = move | M.left
  end
  if my < y then
  -- go down
    move = move | M.down
  end
  if my > y then
  -- go up
    move = move | M.up
  end
  -- update move
  M.move4(move);
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
function M.fireline(objtable)
  myX, myY = M.getmyxy();
  dX = 0;
  dY = 0;
  dXr = 0;
  dYr = 0;
  minD = 1000000;
  minI = 0;
  move = 0;
  shoot = 0;
  --
  if objtable == nil then
    return 0,0
  end
  --
  for i=1, #objtable do
    -- check for not-a-grunt
    -- if objtable[i][5] ~= 14966 then goto continue end
    -- 182 == Hulk?
    -- if objtable[i][5] == 182 then goto continue end
    --
    dX = objtable[i][6] - myX;
    dY = objtable[i][7] - myY;
    -- check in-range
    if (math.abs(dX) > 10000) or (math.abs(dY) > 10000) then goto continue end
    --
    -- -- check zero move X
    -- if dX == 0 then
      -- if dY > 0 then
        -- return 0, M.down;
      -- else
        -- return 0, M.up;
      -- end
    -- end
    -- -- check zero move Y
    -- if dY == 0 then
      -- if dX > 0 then
        -- return 0, M.right;
      -- else
        -- return 0, M.left;
      -- end
    -- end
    --
    if math.abs(dX) < math.abs(minD) then
      minD = dX;
      minI = i;
      if dX < 0 then
        move = M.left
      else
        move = M.right
      end
      if dY < 0 then
        shoot = M.up
      else
        shoot = M.down
      end
    end
    --
    if math.abs(dY) < math.abs(minD) then
      minD = dY;
      minI = i;
      if dY < 0 then
        move = M.up
      else
        move = M.down
      end
      if dX < 0 then
        shoot = M.left
      else
        shoot = M.right
      end
    end
    --
    -- Rotate Enemy 45 deg about Player
    rX = objtable[i][6] - myX;
    rY = objtable[i][7] - myY;
    dXr = rX*0.707 - rY*0.707;
    dYr = rX*0.707 + rY*0.707;
    --
    if math.abs(dXr) < math.abs(minD) then
      minD = dXr;
      minI = i;
      if dXr < 0 then
        move = M.right | M.up
      else
        move = M.left | M.down
      end
      if dYr < 0 then
        shoot = M.up | M.left
      else
        shoot = M.down | M.right
      end
    end
    --
    if math.abs(dYr) < math.abs(minD) then
      minD = dYr;
      minI = i;
      if dYr < 0 then
        move = M.down | M.right
      else
        move = M.up | M.left
      end
      if dXr < 0 then
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
  if minI > 0 and objtable[minI][5] == 182 then
    -- move = M.flip4(shoot);
    move = 0
    shoot = 0
  end
  
  return move, shoot;
end

-- Chase nearest family
function M.chase(objtable)
  myX, myY = M.getmyxy();
  dX = 0;
  dY = 0;
  minD = math.huge;
  minI = 0;
  --
  if objtable == nil or #objtable == 0 then
    return myX, myY
  end
  --
  for i=1, #objtable do
    --
    dX = objtable[i][6] - myX;
    dY = objtable[i][7] - myY;
    temp = dX*dX + dY*dY
    if temp < minD then
      minD = temp;
      minI = i;
    end
  end
  return objtable[minI][6], objtable[minI][7];
end

-- function called every frame: update move and shoot
function M.update()
 
  M.family = M.getlistobj(M.family_ptr);
  -- M.grunts = M.getlistobj(M.grunts_ptr);
  -- M.electrodes = M.getlistobj(M.electrodes_ptr);
  M.baddies = M.getlistobj(M.grunts_ptr);
  M.baddies = M.getlistobj(M.electrodes_ptr, M.baddies);
  M.baddies = M.getlistobj(M.quarks_ptr, M.baddies);

  if M.on == 1 then
    -- shoot
    -- M.spraynpray()
    if M.shootnrun() == 0 then
      M.spraynpray()
    end
    -- run
    if M.family ~= nil and #M.family > 0 then
      M.gotoxy(M.family[1][M.Xindex], M.family[1][M.Yindex])
    else
      M.gotoxy(M.getmyxy())
    end
  elseif  M.on == 2 then
    move, shoot = M.fireline(M.baddies);
    -- get family
    if (move | shoot) == 0 then
      M.gotoxy(M.chase(M.family))
      M.spraynpray()
    else
      M.move4(move);
      M.shoot4(shoot);
    end
  end
end
  
return M
