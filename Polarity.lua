-- Polarity - TIC-80 2D Platformer
-- Controls: Arrow keys to move | Up to jump | Z to flip gravity
-- Architecture: single TIC() loop — input, physics, collision, entities, render
-- Systems: velocity physics, AABB collision, gravity inversion,
--          procedural generation, enemy patrol, particle effects

-- fps tracking variables
fps_c=0 fps_t=0 fps=0

-- initial walk particle timer
 walk_particle_timer = 0

-- game over timer
game_over_timer = 0

-- Player position
x = 116
y = 65

-- timer for enemies to spawn
enemy_spawn_timer = 0

-- Player sprite settings (2x2 sprites)
player_sprite_right = 1
player_sprite_left  = 3
player_w = 15
player_h = 15


-- enemy tracking
enemies_spawned = 0


-- Sprite IDs
coin_sprite = 9
goal_sprite = 13
enemy_sprite = 11

-- Physics
vel_y = 0
gravity = 0.5
jump_strength = 8


-- landing particles effect
landing_effects = {}


-- Gravity state (1 = down, -1 = up)
gravity_dir = 1
flip_cooldown = 0

-- True when player is resting against a surface
grounded = false

-- Facing direction (1 = right, -1 = left)
facing = 1

-- HUD state
lives = 3
coins = 0

-- Level state
level = 1
level_complete_timer = 0
completed_level = 1
pending_level = 1

-- Camera offset
cam_x = 0

-- Goal
goal_x = 140
goal_y = 85
goal_w = 16
goal_h = 16
goal_set = false

-- Platforms
platforms = {}
last_spawn_x = 0
max_spawned = 8
spawned_count = 0

-- Enemy
enemies = {}
spawn_protn = 0

-- Coins
coin_list = {}
coin_w = 6
coin_h = 6

-- Platform height patterns
height_pattern_1 = {108, 100, 104, 112, 100, 108, 104, 112}
height_pattern_2 = {104, 112, 100, 108, 112, 104, 108, 100}
height_pattern_3 = {112, 104, 108, 100, 112, 96, 108, 104}
height_pattern_4 = {96, 108, 112, 100, 104, 96, 112, 108}


-- Clamps value v between a and b
-- Used to prevent camera scrolling past world boundaries
function clamp(v, a, b)
  if v < a then return a end
  if v > b then return b end
  return v
end


-- Adds a platform to the active platform list
-- Platforms are checked every frame for collision
function addPlatform(px, py, pw, ph)
  platforms[#platforms+1] = {x=px, y=py, w=pw, h=ph}
end

-- Resets the platform list at level start
function clearPlatforms()
  platforms = {}
end


-- Creates a dust particle at px, py
-- Triggered on landing and while moving grounded
-- Timer counts down each frame; effect removed at 0
function spawnLandingEffect(px, py)
  landing_effects[#landing_effects+1] = {
    x = px,
    y = py,
    timer = 10
  }
end


-- Decrements each particle timer and removes expired effects
-- Iterates backwards to safely remove during iteration
function updateLandingEffects()
  for i = #landing_effects, 1, -1 do
    local e = landing_effects[i]
    e.timer = e.timer - 1

    if e.timer <= 0 then
      table.remove(landing_effects, i)
    end
  end
end


-- Draws two small rect dust puffs that shrink as timer decreases
-- Size is derived from timer so effect naturally fades out
function drawLandingEffects()
  for i=1,#landing_effects do
    local e = landing_effects[i]

    local size = e.timer / 2

    -- simple dust puff
    rect(e.x - cam_x - size, e.y, size, 2, 10)
    rect(e.x - cam_x + size, e.y, size, 2, 10)
  end
end

-- AABB overlap check between two rectangles
-- Returns true if they intersect on both axes
-- Used for player-platform, player-enemy, and player-coin detection
function overlap(ax, ay, aw, ah, bx, by, bw, bh)
  return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by
end



-- Draws the top status bar showing level, lives and coins
-- Rendered first each frame so game elements draw on top
function drawHUD()
  rect(0, 0, 240, 10, 3)
  print("LEVEL: "..level, 5, 2, 11)
  print("LIVES: "..lives, 90, 2, 11)
  print("COINS: "..coins, 160, 2, 11)
end



-- Draws the player as a 2x2 sprite grid (16x16 total)
-- Sprite set selected based on gravity direction and facing direction
-- Four gravity/facing combinations: normal right, normal left,
-- inverted right, inverted left
function drawPlayer(px, py)
  local base_sprite

  -- Select sprite set based on gravity + facing
  if gravity_dir == 1 then
    if facing == 1 then
      base_sprite = 1
    else
      base_sprite = 3
    end
  else
    if facing == 1 then
      base_sprite = 5
    else
      base_sprite = 7
    end
  end

  spr(base_sprite,     px,     py,     0)
  spr(base_sprite + 1, px + 8, py,     0)
  spr(base_sprite +16, px,     py + 8, 0)
  spr(base_sprite +17, px + 8, py + 8, 0)
end



-- Resets player to the start of the level on the first platform
-- Called after taking damage or falling into lava
-- Spawn position aligned to top of first platform minus player height
function respawnPlayer()
  x = 60
  y = 85
  vel_y = 0
  grounded = false
end



-- Spawns an enemy on a randomly selected platform
-- Skips the first platform to protect the player spawn area
-- Detects ceiling vs floor platforms by y position threshold (y < 60)
-- Ceiling enemies hang below the platform; floor enemies stand on top
function spawnEnemyOnPlatform()
  if #platforms < 2 then return end

  local idx = 2 + math.random(0, #platforms - 2)
  local p = platforms[idx]

  local e = {
    pidx = idx,
    w = 12,
    h = 12,
    dir = (math.random(0,1) == 0) and -1 or 1,
    speed = 0.6 + (level - 1) * 0.3
  }

  -- X position
  e.x = p.x + math.random(0, math.max(0, p.w - e.w))

  --Determine if platform is ceiling or floor
  if p.y < 60 then
    -- ceiling → hang below it
    e.y = p.y + p.h
    e.on_ceiling = true
  else
    -- floor → stand on top
    e.y = p.y - e.h
    e.on_ceiling = false
  end

  enemies[#enemies+1] = e
end


-- Moves each enemy horizontally within its platform bounds
-- Reverses direction at platform edges
-- Removes enemies whose parent platform no longer exists
-- Maintains correct vertical position relative to platform each frame
function updateEnemy()
  for i=#enemies,1,-1 do
    local e = enemies[i]
    local p = platforms[e.pidx]

    if not p then
      table.remove(enemies, i)
    else
      e.x = e.x + e.dir * e.speed

      local left_bound = p.x
      local right_bound = p.x + p.w - e.w

      if e.x < left_bound then
        e.x = left_bound
        e.dir = 1
      elseif e.x > right_bound then
        e.x = right_bound
        e.dir = -1
      end

      -- Maintain correct vertical position
      if e.on_ceiling then
        e.y = p.y + p.h
      else
        e.y = p.y - e.h
      end
    end
  end
end



-- Draws each enemy as a 2x2 sprite grid
-- Ceiling enemies use a separate inverted sprite set (sprites 33,34,49,50)
-- Floor enemies use the standard enemy sprite set
function drawEnemy()
  for i=1,#enemies do
    local e = enemies[i]
    local ex = e.x - cam_x
    local ey = e.y

    if e.on_ceiling then
      -- Upside-down sprite
      spr(33, ex,     ey,     0)
      spr(34, ex + 8, ey,     0)
      spr(49, ex,     ey + 8, 0)
      spr(50, ex + 8, ey + 8, 0)
    else
      -- Normal sprite
      spr(enemy_sprite,      ex,     ey,     0)
      spr(enemy_sprite + 1,  ex + 8, ey,     0)
      spr(enemy_sprite + 16, ex,     ey + 8, 0)
      spr(enemy_sprite + 17, ex + 8, ey + 8, 0)
    end
  end
end


-- Removes all coins from the active list at level start
function clearCoins()
  coin_list = {}
end


-- Adds a collectible coin at cx, cy to the coin list
function addCoin(cx, cy)
  coin_list[#coin_list+1] = {x=cx, y=cy, w=coin_w, h=coin_h, alive=true}
end


-- Draws all living coins using the coin sprite
function drawCoins()
  for i=1,#coin_list do
    local c = coin_list[i]
    if c.alive then
      spr(coin_sprite, c.x - cam_x, c.y, 0)
    end
  end
end


-- Checks player overlap with each coin and collects if alive
function checkCoinPickup()
  for i=1,#coin_list do
    local c = coin_list[i]
    if c.alive and overlap(x, y, player_w, player_h, c.x, c.y, c.w, c.h) then
      c.alive = false
      coins = coins + 1
      sfx(1)
    end
  end
end



-- Inverts the gravity direction variable between 1 (down) and -1 (up)
-- Resets vertical velocity to prevent momentum carrying through the flip
-- Nudges player out of any overlapping platform to prevent embedding
-- A cooldown prevents rapid toggling which caused collision instability
function flipGravity()
  gravity_dir = -gravity_dir
  vel_y = 0
  grounded = false

  -- Push player out of any overlapping platform after flip
  local nudge = -gravity_dir
  for step=1,6 do
    local stuck = false
    for i=1,#platforms do
      local p = platforms[i]
      if overlap(x, y, player_w, player_h, p.x, p.y, p.w, p.h) then
        stuck = true
        break
      end
    end
    if not stuck then break end
    y = y + nudge
  end

  flip_cooldown = 10
end


-- Resets all dynamic game state for a new level
-- Clears platforms, coins, enemies and resets spawn counters
-- Places the initial starting platform manually before procedural generation begins
function seedPlatformsForLevel(n)
  enemies = {}
  enemies_spawned = 0

  clearPlatforms()
  clearCoins()

  addPlatform(40, 100, 100, 10)

  spawned_count = 0
  goal_set = false
  last_spawn_x = 140

  goal_x = last_spawn_x + 200
  goal_y = 120 - goal_h

  spawn_protn = 0
  coins = 0
end



-- Fully initialises a level by number
-- Resets player position, velocity, gravity state, camera and level data
-- Called at game start, level completion and game over reset
function loadLevel(n)
  level = n

  x = 60
  y = 85
  vel_y = 0
  grounded = false
  facing = 1

  gravity_dir = 1
  flip_cooldown = 0

  cam_x = 0

  seedPlatformsForLevel(level)
end



-- Procedurally generates platforms as the player moves forward
-- Spawns paired floor and ceiling platforms at each position
-- Uses predefined height patterns per level for controlled variation
-- Random width and gap values add unpredictability within safe bounds
-- Places a coin above each floor platform
-- Sets goal position once max platforms have been spawned
function maybeSpawnMorePlatforms()
  if spawned_count >= max_spawned then
    if not goal_set then
      goal_x = last_spawn_x + 40
      goal_y = 120 - goal_h
      goal_set = true
    end
    return
  end

  local ahead = cam_x + 320
  if last_spawn_x < ahead then
    local gap = 30 + math.random(0, 12)
    local w = math.max(40, 80 - (level - 1) * 12) + math.random(0, 20) -- shorter platforms for higher levels to increase difficulty.

    local px = last_spawn_x + gap

    --  FLOOR PLATFORM
    local py_floor
    if level == 1 then
      py_floor = height_pattern_1[spawned_count + 1] or 100
    elseif level == 2 then
      py_floor = height_pattern_2[spawned_count + 1] or 100
    elseif level == 3 then
      py_floor = height_pattern_3[spawned_count + 1] or 100
    else
      py_floor = height_pattern_4[spawned_count + 1] or 100
    end

    addPlatform(px, py_floor, w, 10)

    --  CEILING PLATFORM 
    -- mirrored vertically, with slight variation
    local py_ceil = 5 + math.random(0, 15)

    addPlatform(px, py_ceil, w, 10)

    --  coin kept on the floor 
    local cx = px + math.floor(w / 2) - math.floor(coin_w / 2)
    local cy = py_floor - coin_h - 4
    addCoin(cx, cy)

    last_spawn_x = px + w
    spawned_count = spawned_count + 1

    goal_x = last_spawn_x + 80
    goal_y = 120 - goal_h
  end
end

loadLevel(1)

function TIC()

   if level == 1 then max_enemies_per_level = 2
  elseif level == 2 then max_enemies_per_level = 3
  elseif level == 3 then max_enemies_per_level = 5
  else max_enemies_per_level = 7
  end

  fps_c=fps_c+1
  if time()-fps_t>1000 then fps=fps_c fps_c=0 fps_t=time() end

  if game_over_timer > 0 then
    game_over_timer = game_over_timer - 1

    cls(0)
    print("GAME OVER", 87, 60, 12)
    print("Restarting...", 87, 70, 11)


    if game_over_timer == 0 then
      lives = 3
    
      loadLevel(1)
    end

    return
  end

  cls(0)
  drawHUD()

  if enemy_spawn_timer > 0 then
    enemy_spawn_timer = enemy_spawn_timer - 1
  end


  if level_complete_timer > 0 then
    level_complete_timer = level_complete_timer - 1
    cam_x = clamp(x - 80, 0, 999999)

  

    for i=1,#platforms do
      local p = platforms[i]
      rect(p.x - cam_x, p.y, p.w, p.h, 12)
    end

    spr(goal_sprite,     goal_x - cam_x,     goal_y,     0)
    spr(goal_sprite + 1, goal_x - cam_x + 8, goal_y,     0)
    spr(goal_sprite +16, goal_x - cam_x,     goal_y + 8, 0)
    spr(goal_sprite +17, goal_x - cam_x + 8, goal_y + 8, 0)

    drawCoins()
    drawEnemy()
    drawPlayer(x - cam_x, y)

    print("LEVEL "..completed_level.." COMPLETE!", 70, 50, 11)
    print("Loading next level...", 72, 62, 11)

    if level_complete_timer == 0 then
      loadLevel(pending_level)
    end

    return
  end

  -- Spawn protection: brief invincibility after taking damage
  -- Prevents multiple damage events from a single enemy contact
  if spawn_protn > 0 then spawn_protn = spawn_protn - 1 end


  if flip_cooldown > 0 then flip_cooldown = flip_cooldown - 1 end

  -- Previous position for stomp checks
  local prev_y = y

  if btnp(4) and flip_cooldown == 0 then
    flipGravity()
  end

  if btn(2) then
    x = x - 1
    facing = -1
  end

  if btn(3) then
    x = x + 1
    facing = 1
  end

  if btn(0) and grounded then
  		sfx(0)
    vel_y = -gravity_dir * jump_strength
    grounded = false
  end


  -- Physics: apply gravity each frame and update vertical position
  -- gravity_dir multiplies all vertical forces so inversion requires
  -- no changes to the physics logic itself
  local g = gravity * gravity_dir
  y = y + vel_y
  vel_y = vel_y + g

  grounded = false

  -- Grounded collision: only resolve when moving WITH gravity
  -- Prevents incorrect snapping when jumping or falling the wrong way
  if vel_y * gravity_dir > 0 then
    for i=1,#platforms do
      local p = platforms[i]
      if overlap(x, y, player_w, player_h, p.x, p.y, p.w, p.h) then
        if gravity_dir == 1 then
          y = p.y - player_h
        else
          y = p.y + p.h
        end
        vel_y = 0
        grounded = true
        break
      end
    end
  end

   if gravity_dir == 1 then
    if y > 120 then
      lives = lives - 1
      if lives <= 0 then
        sfx(5)
        game_over_timer = 120
      else
        sfx(2)
        spawn_protn = 90
        respawnPlayer()
      end
    end
  else
    if y < 0 then
      y = 0
      vel_y = 0
      grounded = true
    end
  end

    -- Ceiling collision: resolves contacts when moving AGAINST gravity
    -- Stops player clipping through platforms when jumping upward
    -- This pass was added after testing revealed the bug    
    if vel_y * gravity_dir < 0 then
      for i=1,#platforms do
        local p = platforms[i]
        if overlap(x, y, player_w, player_h, p.x, p.y, p.w, p.h) then
          if gravity_dir == 1 then
            y = p.y + p.h
          else
            y = p.y - player_h
          end
          vel_y = 0
          break
        end
      end
    end

  -- World space hint text
    print("! watch out for the lava below !", 30 - cam_x, 50, 2)
    print("! Kill All Enemies by jumping on them!", 30 - cam_x, 70, 2)

    print(">> press Z to defy gravity <<", 300 - cam_x, 50, 11)
    print(">> don't forget your coins! <<", 500 - cam_x, 50, 4)
    
 -- particle effects
  if grounded and (btn(2) or btn(3)) then
    walk_particle_timer = walk_particle_timer - 1

    if walk_particle_timer <= 0 then
      spawnLandingEffect(
        x + player_w/2,
        y + (gravity_dir == 1 and player_h or 0)
      )
      walk_particle_timer = 5 -- tweak this (lower = more particles)
    end
  else
    walk_particle_timer = 0
  end


  cam_x = clamp(x - 80, 0, 999999)

  maybeSpawnMorePlatforms()

  -- Only spawn if: No enemy currently alive and Haven’t reached max spawns
  if #enemies == 0 and enemies_spawned < max_enemies_per_level and enemy_spawn_timer == 0 then
    spawnEnemyOnPlatform()
    enemies_spawned = enemies_spawned + 1
    enemy_spawn_timer = 60 -- 1 second delay
  end

  updateLandingEffects()

  updateEnemy()
  checkCoinPickup()



  -- Enemy interaction: checks stomp vs damage based on movement direction
  -- Stomp detected by comparing previous and current y against enemy bounds
  -- gravity_dir taken into account so stomping works in both gravity states
  for i=#enemies,1,-1 do
    local e = enemies[i]

  if spawn_protn == 0 and overlap(x, y, player_w, player_h, e.x, e.y, e.w, e.h) then
    local do_damage = true

    if vel_y * gravity_dir > 0 then
      if gravity_dir == 1 then
        if prev_y + player_h <= e.y and y + player_h >= e.y then
          sfx(3)
          table.remove(enemies, i)
          vel_y = -gravity_dir * jump_strength * 0.7
          do_damage = false
        end
      else
        if prev_y >= e.y + e.h and y <= e.y + e.h then
          sfx(3)
          table.remove(enemies, i)
          vel_y = -gravity_dir * jump_strength * 0.7
          do_damage = false
        end
      end
    end

    if do_damage then
      lives = lives - 1

      if lives <= 0 then
        sfx(5)
        game_over_timer = 120
      else
        sfx(2)
        spawn_protn = 90
        respawnPlayer()
      end
    end
  end
end


    -- Goal detection: reaching the flag triggers level complete sequence
  if overlap(x, y, player_w, player_h, goal_x, goal_y, goal_w, goal_h) then
    sfx(4)
    completed_level = level
    level_complete_timer = 120
    pending_level = level + 1
    if pending_level > 4 then pending_level = 1 end
  end

  for i=1,#platforms do
    local p = platforms[i]
    rect(p.x - cam_x, p.y, p.w, p.h, 12)
  end

  spr(goal_sprite,     goal_x - cam_x,     goal_y,     0)
  spr(goal_sprite + 1, goal_x - cam_x + 8, goal_y,     0)
  spr(goal_sprite +16, goal_x - cam_x,     goal_y + 8, 0)
  spr(goal_sprite +17, goal_x - cam_x + 8, goal_y + 8, 0)

  drawLandingEffects()
  drawCoins()
  drawEnemy()

  -- Draw lava
  rect(0, 128, 240, 8, 2)
  rect(0, 130, 240, 6, 4)

  if not (spawn_protn > 0 and (spawn_protn % 6) < 3) then
    drawPlayer(x - cam_x, y)
  end

  print("FPS:"..fps,205,2,6)
end