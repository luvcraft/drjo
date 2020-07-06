pico-8 cartridge // http://www.pico-8.com
version 27
__lua__
-- dr jo
-- by luvcraft

-- constants
boulder_fall_state = 8
boulder_break_state = 10
max_boulders = 6
max_monsters = 6
monster_spawn_freq = 60

-- max time between coins in a row
coin_countdown_max = 20

-- dying time (in frames) at which game resets / game overs
done_dying = 100

map_w = 12
map_h = 15
max_spr_x = (map_w-1) * 8
max_spr_y = (map_h-1) * 8

-- round num to the nearest multiple of target
function roundtonearest(num, target)
	if(num % target == 0) then
		return num
	elseif(num % target > target / 2) then
		return num + (target - num % target)
	else
		return num - (num % target)
	end
end

-- return num clamped to min and max (inclusive)
function minmax(num, min, max)
	if(num < min) then
		return min
	elseif(num > max) then
		return max
	else
		return num
	end
end

-- return whether or not num falls between min and max (inclusive)
function inrange(num, min, max)
	max = max or 0
	
	if(min < max) then
		return num >= min and num <= max
	else
		return num <= min and num >= max
	end
end

-- converts an int to a vector2
function to_xy(number) 
	local t = {}
	t.x = number % 16
	t.y = flr(number / 16)
	
	return t
end

-- converts a vector2 to a single int
function from_xy(x,y) 
	return (flr(y) * 16 + flr(x))
end

-- whether or not the array contains the specified value
function contains(array, value)
	for v in all(array) do
		if(v == value) then
			return true
		end
	end
	
	return false
end

-- whether or not the array does NOT contain the specified value
function not_contains(array, value)
	return contains(array,value) == false
end

-- check to see if there's a boulder or wall immediately in the specified direction from the character
-- returns 0 for no boulder, 1 for blocked or vertical boulder, and the boulder if it's pushable
function boulder_check(character, dir)
	if(dir==0) then
		if(character.y<=0) then
			return 1
		else
			for b in all(boulder) do
				if(character.x==b.x and inrange(character.y - b.y,8)) then
					-- boulder in the way vertically. return blocked!
					return 1
				end
			end
		end
	elseif(dir==1) then
		if(character.x>=max_spr_x) then
			return 1
		else
			for b in all(boulder) do
				if(character.y==b.y and inrange(b.x - character.x,8)) then
					if(b:blocked(dir) !=0 or b.state > 0) then
						return 1
					else
						return b
					end
				end
			end
		end
	elseif(dir==2) then
		if(character.y>=max_spr_y) then
			return 1
		else
			for b in all(boulder) do
				if(character.x==b.x and inrange(b.y - character.y,8)) then
					-- boulder in the way vertically. return blocked!
					return 1
				end
			end
		end
	elseif(dir==3) then
		if(character.x<=0) then
			return 1
		else
			for b in all(boulder) do
				if(character.y==b.y and inrange(character.x - b.x,8)) then
					if(b:blocked(dir) !=0 or b.state > 0) then
						return 1
					else
						return b
					end
				end
			end
		end
	end
	
	return 0
end

-- global vars
current_level = 0

current_map_x = 12 + 12
current_map_y = 0

score = 0
coin_countdown = 0
coins_in_a_row = 0

monster_spawn_countup = 0
monster_spawner_pos = 0

dead_monsters = 0

debug_text = ""

-->8
-- hero

hero = {
	x=5 * 8, 
	y=max_spr_y,
	facing=1,
	speed=1,
	dying=0,
 
	update = function(self)
		if(self.dying > 0) then
			self.dying+=1
			return
		end
	
		if (btn(0)) then
			self:move(3)
		elseif (btn(1)) then 
			self:move(1)
		elseif (btn(2)) then
			self:move(0)
		elseif (btn(3)) then
			self:move(2)
		end
		
		if(btnp(4) or btnp(5)) then 
			if(bomb.state == 0 and bomb.cooldown <= 0) then
				bomb.x = roundtonearest(self.x,8)/8
				bomb.y = roundtonearest(self.y,8)/8
				bomb.state = 1
			elseif(bomb.state == 1) then
				bomb:explode()
			end
		end		
	end,
	
	move = function(self, dir)
		-- if partway through a move, complete the move regardless of direction pressed,
		-- unless the direction is the opposite direction
		if(self.facing == 1 and (self.x % 8) > 2) then 
			if (dir == 3) then
				self.facing = dir
			end
		elseif(self.facing == 3 and ((8-self.x) % 8) > 2 ) then 
			if (dir == 1) then
				self.facing = dir
			end
		elseif(self.facing == 2 and (self.y % 8) > 2 ) then
			if (dir == 0) then
				self.facing = dir
			end
		elseif(self.facing == 0 and ((8-self.y) % 8) > 2 ) then
			if (dir == 2) then
				self.facing = dir
			end
		else
			self.facing = dir
			if(dir == 0 or dir == 2) then 
				self.x = roundtonearest(self.x, 8)
			else
				self.y = roundtonearest(self.y, 8)
			end
		end

		local b = boulder_check(self, self.facing)
		local speed = self.speed
		local pushing_speed = self.speed * 0.7
		if(self:digging(dir)) then
			speed = self.speed * 0.7
		end
		
		if(b != 1) then
			if(self.facing == 0) then 
				self.y-=speed
				-- don't check for pushing boulder vertically
			elseif(self.facing==2) then 
				self.y+=speed
				-- don't check for pushing boulder vertically
			elseif(self.facing==1) then 
				if(b != 0) then
					speed = pushing_speed
					b.x += speed
				end
				self.x+=speed
			elseif(self.facing==3) then
				if(b != 0) then
					speed = pushing_speed
					b.x -= speed
				end
				self.x-=speed
			end
		end
		
		self.x = minmax(self.x,0,max_spr_x)
		self.y = minmax(self.y,0,max_spr_y)
		
		local tile_x = roundtonearest(self.x, 8)/8
		local tile_y = roundtonearest(self.y, 8)/8
		
		for c in all(coin) do
			local pos = to_xy(c)
			if(tile_x == pos.x and tile_y == pos.y) then
				-- collect coin
				
				-- TODO: put collect coin sfx here
				coins_in_a_row += 1
				coin_countdown = coin_countdown_max
				score += 5 + (coins_in_a_row * 5)
				del(coin,c)
			end
		end
				
		if(crack.state == 1 and tile_x == crack.x and tile_y == crack.y) then
			score += 100
			crack.state = 2
			
			swap_monsters_and_boulders()
			-- TODO: letter man appears!
		end		
	end,
	
	-- returns true if hero is digging vs moving unobstructed
	digging = function(self, dir)
		if(dir==1) then
			return mget((self.x/8)+1,self.y/8) > 0
		elseif(dir==2) then
			return mget((self.x/8),self.y/8+1) > 0
		else
			return mget((self.x/8),self.y/8) > 0
		end
	end,
	
	-- start dying
	die = function(self)
		if(self.dying < 1) then
			self.dying = 1
		end
	end,
	
	draw = function(self)
		if(self.dying < 1) then	
			-- normal
			local frame = flr((self.x + self.y)/2) % 4
			local flip = (self.facing == 3) or (self.facing != 1 and frame == 3)
			local sprite = 4+frame
			
			if(self.facing==0) then
				sprite = 2 + (frame % 2)
			elseif(self.facing==2) then
				sprite = 8 + (frame % 2)
			end
			
			spr(sprite,self.x,self.y,1,1,flip)
			
			-- draw hat
			spr(10,self.x,self.y-3)
		else
			-- dying
			local frame = flr((self.dying - 1) / 10)
			if(frame < 6) then
				if((frame % 2) == 0) then
					spr(10,self.x,self.y-2 + frame)
				elseif(frame == 3) then
					spr(11,self.x,self.y-2 + frame, 1, 1, true)
				else
					spr(11,self.x,self.y-2 + frame)
				end
			else
				spr(10,self.x,self.y+4)
			end
		end
	end
}

-->8
-- monster

-- prototype behavior for monsters
monster_proto = {
	facing = 0,
	speed = 1,
	movestyle = 0,
	-- movestyle
	--- 0 = erratic
	--- 1 = can only reverse if hit a wall
	--- 2 = can only reverse if hit a dead end

	update = function(self)	
		self:move()
		
		-- if this monster has caught the hero, hero dies
		if(self.x == hero.x and inrange(self.y-hero.y,-4,4)) then
			hero:die()
		elseif(self.y == hero.y and inrange(self.x-hero.x,-4,4)) then
			hero:die()
		end
	end,
	
	move = function(self)	
		local speed = self.speed
		local pushing_speed = self.speed * 0.7
		local reverse_facing = (self.facing + 2) % 4 -- opposite direction from facing
		
		if(flr(self.x%8) == 0 and flr(self.y%8) == 0) then
			local potential_directions = {}
			local available_directions = {}
			for i=0,3 do
				if(self:wallcheck(i) == 0) then
					add(available_directions,i)
				end
			end
			
			if(self.movestyle == 0) then
				-- erratic movestyle. 
				-- Can reverse at any time, but less likely than other moves					
				for i in all(available_directions) do
					-- if direction is clear, add it to potential list
					add(potential_directions, i)
					if(i == self.facing) then
						-- if already facing this direction, add it to potential list again x2
						add(potential_directions, i)
						add(potential_directions, i)
					end
					if(i != reverse_facing) then
						-- if direction is NOT the opposite of facing, add it again x2
						add(potential_directions, i)
						add(potential_directions, i)
					end
				end
					
			elseif (self.movestyle == 1) then
				-- movestyle 1 = can only reverse if hit a wall, but can turn

				if(contains(available_direction,self.facing)) then
					del(available_directions,reverse_facing)
				end
				potential_directions = available_directions				
				
			elseif (self.movestyle == 2) then
				-- movestyle 2 = can only reverse if hit a dead end
				
				if(#available_directions > 1) then
					del(available_directions,reverse_facing)
				end
				potential_directions = available_directions
			end

			if(#potential_directions>0) then
				self.facing = rnd(potential_directions)
			else
				self.facing = 4
			end
		end

		local b = boulder_check(self, self.facing)

		if(b != 1) then
			if(self.facing == 0) then 
				self.y-=speed
				-- don't check for pushing boulder vertically
			elseif(self.facing==2) then 
				self.y+=speed
				-- don't check for pushing boulder vertically
			elseif(self.facing==1) then 
				if(b != 0) then
					speed = pushing_speed
					b.x += speed
				end
				self.x+=speed
			elseif(self.facing==3) then
				if(b != 0) then
					speed = pushing_speed
					b.x -= speed
				end
				self.x-=speed
			end
		end
		
		self.x = minmax(self.x,0,max_spr_x)
		self.y = minmax(self.y,0,max_spr_y)
		
		local tile_x = roundtonearest(self.x, 8)/8
		local tile_y = roundtonearest(self.y, 8)/8
	end,
	
	-- check for a wall in the specified direction
	-- returns 0 for unblocked, 1 for a wall, or 2 for the edge of the screen
	wallcheck = function(self, dir)
		local x = self.x / 8
		local y = self.y / 8
		
		if(dir == 0) then
			y -= 1
		elseif(dir == 1) then
			x += 1
		elseif(dir == 2) then
			y += 1
		elseif(dir == 3) then
			x -= 1
		end
		
		if(x < 0 or y < 0) then
			return 2
		elseif(x >= map_w or y >= map_h) then
			return 2
		else
			if(mget(x,y) > 0) then
				return 1
			else
				return 0
			end
		end
	end,
	
	die = function(self, point_value)
		add(floaty_numbers, floaty_number_proto:instantiate(self.x, self.y, point_value))				
		dead_monsters += 1
		del(monster, self)
	end,
	
	draw = function(self)
		-- normal
		local frame = flr((self.x + self.y)/2) % 4
		local flip = (self.facing == 3) or (self.facing != 1 and frame == 3)
		local sprite = 36+frame
		
		if(self.facing==0) then
			sprite = 34 + (frame % 2)
		elseif(self.facing==2) then
			sprite = 40 + (frame % 2)
		end
		
		spr(sprite,self.x,self.y,1,1,flip)
	end,
	
	-- instantiate a monster from this prototype
	instantiate = function(self,xpos,ypos,movestyle)
		t = {}
		for key, value in pairs(self) do
			t[key] = value
		end
		t.x = (xpos or 0) * 8
		t.y = (ypos or 0) * 8
		t.facing = flr(rnd(3))
		t.movestyle = movestyle
		
		return t
	end
}

-->8
-- coins

-- draw all coins at once
draw_coins = function()		
	local frame = flr((time() %1) * 4)
			
	if(frame == 2) then
		pal(10,9)
	end
	
	for c in all(coin) do
		local x = to_xy(c).x*8
		local y = to_xy(c).y*8

		if(frame == 0)  then
			spr(24,x,y)
		elseif(frame == 1) then
			spr(25,x,y)
		elseif(frame == 2) then
			spr(24,x,y)
		else
			spr(25,x,y,1,1,true)
		end

	end
	
	pal()
end

-- add a cluster of 4 coins, with top left at specified tile
add_coin_cluster = function(x,y)
	add(coin,from_xy(x,y))	
	add(coin,from_xy(x+1,y))	
	add(coin,from_xy(x,y+1))	
	add(coin,from_xy(x+1,y+1))
end

-->8
-- other objects

-- prototype behavior for floaty numbers
floaty_number_proto = {
	progress = 0,
	
	update = function(self)
		self.progress += 1
		if(self.progress > 30) then
			del(floaty_numbers,self)
		end
	end,
	
	draw = function(self)
		print(self.value,self.x,self.y-(self.progress/2))
	end,

	instantiate = function(self,xpos,ypos,value)
		t = {}
		for key, value in pairs(self) do
			t[key] = value
		end
		t.x = xpos
		t.y = ypos
		t.value = value
		
		return t
	end
}

-- behavior for the bomb
bomb = {
	state = 0,
	-- state
	--- 0 = not placed
	--- 1 = placed
	--- 2 = exploding
	--- 3 = done exploding
	
	cooldown = 0,
	next_cooldown = 30,
	
	reset = function(self)
		self.state = 0
		self.cooldown = 0
		self.next_cooldown = 30
	end,
	
	update = function(self)
		if(self.state == 0) then
			-- if no bomb is set, decrease cooldown timer
			if(self.cooldown > 0) then
				self.cooldown -= 1
			end
		elseif(self.state >= 2) then
			self.state += 0.1
			if(self.state >= 3) then			
				self.state = 0
				self.cooldown = self.next_cooldown
				self.next_cooldown += 30
			end
		end
	end,
	
	explode = function(self)
		for x=-1,1 do
			for y=-1,1 do
				mset(self.x+x,self.y+y,0)
			end
		end
		
		-- if explosion hits a boulder, break the boulder
		for b in all(boulder) do
			if(abs(self.x * 8 - b.x) <= 8 and abs(self.y * 8 - b.y) <= 8) then
				b.state = boulder_break_state
			end
		end
		
		local point_value = 0
		
		-- if explosion hits a monster, kill the monster
		for m in all(monster) do
			if(abs(self.x * 8 - m.x) <= 8 and abs(self.y * 8 - m.y) <= 8) then
				point_value += 10
				score += point_value
				
				m:die(point_value)
			end
		end
		
		-- if explosion hits the hero, kill the hero
		if(abs(self.x * 8 - hero.x) <= 8 and abs(self.y * 8 - hero.y) <= 8) then
			hero:die()
		end

		-- if explosion hits the crack, open the crack
		if(crack.state == 0) then
			if(abs(self.x - crack.x) <= 1 and abs(self.y - crack.y) <= 1) then
				crack.state = 1
			end
		end
		
		self.state = 2
	end,
	
	draw = function(self)
		if(self.state == 0) then
			if(self.cooldown <= 0) then
				-- if bomb is available, draw bomb at 0,-8
				spr(23,0,-8)
			end
		elseif(self.state == 1) then
			if(time() % 0.5 < 0.25) then
				pal(5,8)
			end
			
			spr(23,self.x*8,self.y*8)
			pal()
		elseif(self.state >= 2) then
			r = (3-self.state) * 12
			circfill((self.x*8)+4,(self.y*8)+4,r,8)
			circfill((self.x*8)+4,(self.y*8)+4,r/2,9)
		end
	end
}

-- behavior for the crack
crack = {
	x = 4,
	y = 4,
	state = 0,
	-- state
	--- 0 = closed
	--- 1 = open and not collected
	--- 2 = open and empty
	
	update = function(self)
	end,
	
	draw = function(self)
		local x = self.x*8
		local y = self.y*8
		
		pal(1,0)
	
		if(self.state == 0) then
			-- closed
			spr(26,x,y)
		elseif(self.state == 1) then
			-- open and not collected
			spr(27,x,y)
			spr(28,x,y)
		elseif(self.state == 2) then
			-- open and empty
			spr(27,x,y)
		end
		
		pal()
	end
}

-- prototype behavior for boulders
boulder_proto = {
	state = 0,
	-- state
	--- 0 = not moving
	--- 1+ = wiggling
	--- boulder_fall_state = falling
	--- boulder_break_state = breaking
	--- boulder_break_state + 3 = done breaking
	
	point_value = 0,
	
	update = function(self)
		if(self.state == 0) then
			local x = roundtonearest(self.x,8)
			if(mget(x/8,self.y/8 + 1) == 0) then
				-- start wiggling. play start wiggling sfx here
				self.state = 1
				self.x = x
				self.starting_y = self.y
			end
		elseif(self.state < boulder_fall_state) then
			-- wiggle
			self.state += 0.2
		elseif(self.state >= boulder_break_state) then
			-- boulder is breaking
			self.state += 0.2
			if(self.state > boulder_break_state + 3) then
				del(boulder,self)
			end
		else	
			-- boulder is falling
			self.y+=1.5
			
			-- if boulder hits a monster, kill the monster
			for m in all(monster) do
				if(inrange(self.x - m.x,-6,6) and inrange(self.y - m.y,-6,6)) then
					self.point_value += 10
					score += self.point_value
					
					m:die(self.point_value)
				end
			end

			-- if boulder hits the hero, kill the hero
			if(inrange(self.x - hero.x,-6,6) and inrange(self.y - hero.y,-6,6)) then
				hero:die()
			end
			
			if(mget(self.x/8,self.y/8 + 1) != 0) then
				-- falling boulder hit ground
				self.y -= (self.y % 8)
				if(self.y - self.starting_y > 8) then
					-- boulder fell far enough to break
					self.point_value += 10
					score += self.point_value
					
					self.state = boulder_break_state
				else
					self.state = 0
				end
			else
				local b = self:blocked(2)
				if(b != 0) then
					-- break boulder if it falls on another boulder or bottom of screen
					self.state = boulder_break_state
					self.y -= (self.y % 8)
					if(b != 1) then
						b.state = boulder_break_state					
					end
				end
			end
		end
	end,
	
	draw = function(self)
		stateint = flr(self.state)
		if(stateint >= boulder_break_state) then
			-- boulder is breaking
			local sprnum = 20 - boulder_break_state + stateint
			spr(sprnum,self.x-4,self.y)
			spr(sprnum,self.x+4,self.y,1,1,true)
		elseif(stateint % 2 == 0 or stateint >= boulder_fall_state) then
			-- boulder is idle or falling
			spr(18,self.x,self.y)
		elseif((stateint-1) % 4 == 0) then
			spr(19,self.x,self.y)
		else
			spr(19,self.x,self.y,1,1,true)
		end
	end,
	
	-- check to see if this boulder is blocked by another boulder or edge of screen
	-- returns 0 for unblocked, 1 for edge of screen, and the boulder if it's a boulder
	blocked = function(self, dir)
		if(dir==0) then
			if(self.y<=0) then
				return 1
			else
				for b in all(boulder) do
					if(self != b and abs(self.x-b.x) < 8 and inrange( self.y - b.y,8)) then
						self.y = roundtonearest(self.y, 8)
						return b
					end
				end
			end
		elseif(dir==1) then
			if(self.x>=max_spr_x) then
				return 1
			else
				for b in all(boulder) do
					if(self != b and abs(self.y-b.y) < 8 and inrange(b.x - self.x,8)) then
						self.x = roundtonearest(self.x, 8)
						return b
					end
				end
			end
		elseif(dir==2) then
			if(self.y>=max_spr_y) then
				return 1
			else
				for b in all(boulder) do
					if(self != b and abs(self.x-b.x) < 8 and inrange(b.y - self.y,8)) then
						self.y = roundtonearest(self.y, 8)
						return b
					end
				end
			end
		elseif(dir==3) then
			if(self.x<=0) then
				return 1
			else
				for b in all(boulder) do
					if(self != b and abs(self.y-b.y) < 8 and inrange(self.x - b.x,8)) then
						self.x = roundtonearest(self.x, 8)
						return b
					end
				end
			end
		end
		
		return 0
	end,
	
	-- instantiate a boulder from this prototype
	instantiate = function(self,xpos,ypos)
		t = {}
		for key, value in pairs(self) do
			t[key] = value
		end
		t.x = (xpos or 0) * 8
		t.y = (ypos or 0) * 8
		return t
	end
}

-- place the boulders and the crack
place_boulders = function()
	local tiles = {}
	local crack_tiles = {}
	
	for x=1,map_w-2 do
		for y=0,map_h do
			if(mget(x+current_map_x,y+current_map_y) != 0 and mget(x+current_map_x,y+current_map_y+1) != 0) then
				add(crack_tiles,from_xy(x,y))
				if(y<map_h/2) then
					add(tiles,from_xy(x,y))
				end
			end
		end
	end

	-- place crack in a random position
	local t = rnd(crack_tiles)
	local pos = to_xy(t)
	crack.x = pos.x
	crack.y = pos.y
	
--	debug_text = "crack tile at "..crack.x..","..crack.y

	-- delete tiles with coins on them from possible boulder placements
	for c in all(coin) do
		del(tiles,c)
	end
			
	boulder = {}

	for i = 1,max_boulders do
		t = rnd(tiles)
		pos = to_xy(t)
		add(boulder, boulder_proto:instantiate(pos.x,pos.y))
		-- delete this tile so it won't get used again
		del(tiles,t)
		-- also delete the tiles adjacent to this one
		del(tiles,t-1)
		del(tiles,t+1)
		del(tiles,t-16)
		del(tiles,t+16)
	end
end

-- spawn a monster from the monster spawner
function spawn_monster()
	local pos = to_xy(monster_spawner_pos)
	add(monster, monster_proto:instantiate(pos.x,pos.y,0))
end

-- draw the monster spawner
function draw_monster_spawner()
	local pos = to_xy(monster_spawner_pos)
	
	if(#monster + dead_monsters < max_monsters) then
		if(monster_spawn_countup < (monster_spawn_freq/2)) then
			spr(32,pos.x*8,pos.y*8)
		else
			spr(33,pos.x*8,pos.y*8)
		end
	end
end

-- swap monsters and boulders. Happens when hero collects treasure
function swap_monsters_and_boulders()
	local pos = {}
	
	for m in all(monster) do
		local p = {}
		p.x = roundtonearest(m.x,8)/8
		p.y = roundtonearest(m.y,8)/8
		add(pos,p)
	end
	
	monster = {}
	
	for b in all(boulder) do
		add(monster, monster_proto:instantiate(b.x/8,b.y/8,0))
	end

	dead_monsters = max_monsters - #monster
	
	boulder = {}
	
	for p in all(pos) do
		add(boulder, boulder_proto:instantiate(p.x,p.y))
	end
end

-- reset the level. Called after hero dies
function reset_level()
	hero.dying = 0
	hero.x=5 * 8
	hero.y=max_spr_y
	
	bomb:reset()
	
	monster = {}
	floaty_numbers = {}
end

function next_level()
	current_level += 1

	for x=0,map_w-1 do
		for y=0,map_h-1 do
			local n = mget(x+current_map_x,y+current_map_y)
			if(n == 24) then
				-- if coin at map position, add coin, and set tile to solid
				add_coin_cluster(x,y)
				mset(x,y,mget(x+current_map_x+1,y+current_map_y))
			elseif(n == 32) then
				monster_spawner_pos = from_xy(x,y)
				mset(x,y,0)
			else
				mset(x,y,n)
			end
		end
	end
	
	place_boulders()
		
	coin_countdown = 0
	coins_in_a_row = 0
	dead_monsters = 0
	
	reset_level()
end

-->8
-- main functions

function _init()
	coin = {}
	boulder = {}
	monster = {}
	floaty_numbers = {}

	camera(0,-8)
	
	next_level()
end

function _update()
	crack:update()
	bomb:update()
	hero:update()
	
	-- clear the block under the hero
	local herox = roundtonearest(hero.x,8)/8
	local heroy = roundtonearest(hero.y,8)/8
	mset(herox,heroy,0)

	local boulders_falling = false
	
	for b in all(boulder) do
		b:update()
		if(b.state > 0) then
			boulders_falling = true
		end
	end

	if(hero.dying < 1) then
		for m in all(monster) do
			m:update()
		end
		
		if(#monster + dead_monsters < max_monsters) then
			monster_spawn_countup += 1
			if(monster_spawn_countup >= monster_spawn_freq) then
				monster_spawn_countup = 0
				spawn_monster()
			end
		end
		
		if(#coin == 0 or dead_monsters == max_monsters) then
			-- if hero collected all coins or killed all monsters, go to the next level
			next_level()
		end
		
	elseif(hero.dying >= done_dying and boulders_falling == false) then
		reset_level()
	end
	
	for n in all(floaty_numbers) do
		n:update()
	end
	
	-- update "coins in a row"
	if(coins_in_a_row > 0) then
		coin_countdown -= 1
		if(coin_countdown < 0) then
			coins_in_a_row = 0
		end
	end
	
end

function _draw()
	cls()
	rect((map_w *8)+1,0,127,127-8,6)
	pal(5,0)
	map(12,0,0,0,map_w,map_h)
	pal()
	crack:draw()
	map(0,0,0,0,map_w,map_h)
	
	draw_monster_spawner()
	
	draw_coins()
		
	bomb:draw()
	
	for m in all(monster) do
		m:draw()
	end
	
	for b in all(boulder) do
		b:draw()
	end

	for n in all(floaty_numbers) do
		n:draw()
	end

	hero:draw()
	
	print("score:\n"..score,(map_w*8)+3,3)
	
	print(debug_text,8,-8)
end

__gfx__
0000000055555555009999000099990000999900009999000099990000999900009999000099990000e22e0000e2000000000000000000000000000000000000
00000000335333330999999009999990009f3f00009f3f00009f3f00009f3f00093ff390093ff39000eeee0000ee2e0000000000000000000000000000000000
00700700335333330999999009999990009fff00009fff00009fff00009fff0009ffff9009ffff90ee2222eeee22ee0000000000000000000000000000000000
00077000335333330999999009999990009ee000009ee000009ee000009ee00009eeee9009eeee90eeeeeeee0eee22ee00000000000000000000000000000000
00077000555555550eeeeee00eeeeee000eeef0000eeef0000efe00000efe0000eeeeee00eeeeee000000000000eeee000000000000000000000000000000000
00700700333335330feeeef00feeeef000efe00000efe00000eeef0000eeef000feeeef00feeeef0000000000000000000000000000000000000000000000000
000000003333353300eeee0000e44e0000eee0000eee4e0000eee0000eeeee0000eeee0000e44e00000000000000000000000000000000000000000000000000
000000003333353300e44e000000ee0000eeee000ee44ee000eeee000ee44ee000e44e000000ee00000000000000000000000000000000000000000000000000
00000000555511110049940000049940000004940000000000000000000000000000000000000000000000000055550000000000000000000000000000000000
000000001111555504999940004999940000499404400000000000000055550000999900000990000001000005111150009aa900000000000000000000000000
000000001111111104a99a40004a999400004a94494500000000000005665550099a9990009aa900000010005111111500999900000000000000000000000000
000000001111111149999994049999a40004999449a45000455555540565555009a99a900099a900001100005111111500999900000000000000000000000000
00000000555511119aaaaaa909aa99940009aaa4499945009999a9a90555555009a99a900099a900000011005111111500099000000000000000000000000000
0000000011115555499999940499aaa900049994049a944049a9a9a9055555500999a990009aa900000100005111111500099000000000000000000000000000
00000000111111119aaaaaa909aa99940009aaa404a9a9400449a9a4005555000099990000099000000010005111111500999900000000000000000000000000
0000000011111111049999400049aa4000004994000a440000049490000000000000000000000000000000000555555000000000000000000000000000000000
00555500005555000088880000888800008888000088880000888800008888000088880000888800000000000000000000000000000000000000000000000000
05111150052222500888888008888880088888800888888008888880088888800888888008888880000000000000000000000000000000000000000000000000
0511115005b22b5008888880088888800888b8800888b8800888b8800888b88008b88b8008b88b80000000000000000000000000000000000000000000000000
05111150052222500888888008888880088888800888888008888880088888800888888008888880000000000000000000000000000000000000000000000000
0051150000522500006dd600006dd60000d66d0000d66d0000d66d0000d66d00006dd600006dd600000000000000000000000000000000000000000000000000
0051150000522500086dd680086dd68000dd668000dd668000dd668000dd6680088dd880088dd880000000000000000000000000000000000000000000000000
005115000052250000dddd000022dd00000dd0000255dd00000dd00008dd550000dddd000022dd00000000000000000000000000000000000000000000000000
05555550055555500082280000008800000888000220888000088800088022200082280000008800000000000000000000000000000000000000000000000000
__map__
1111111111111111111111111111111111111111111111110101010000000000010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1111111111111111111111111111111111111111111111111801010101000101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1111111111111111111111111111111111111111111111110101010101000118011801010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1111111111111111111111111111111111111111111111111801011801000101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1111111111111111111111111111111111111111111111110101010101000101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1111111111111111111111111111111111111111111111110101011801000101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1111111111111111111111111111111111111111111111110101010101000101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1111111111111111111111111111111111111111111111110101010101200100000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1111111111111111111111111111111111111111111111110101010101000100180100010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1111111111111111111111111111111111111111111111111801180101000100010100010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1111111111111111111111111111111111111111111111110101010101000100180100010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1111111111111111111111111111111111111111111111110101010101000100010100010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1111111111111111111111111111111111111111111111110100010101000100000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1111111111111111111111111111111111111111111111110100010101000101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1111111111111111111111111111111111111111111111110100000000000101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
