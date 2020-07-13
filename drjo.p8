pico-8 cartridge // http://www.pico-8.com
version 27
__lua__
-- dr jo
-- by r. hunter gough (luvcraft)

-- constants
boulder_fall_state = 8
boulder_break_state = 10
max_boulders = 6
max_monsters = 6
monster_spawn_freq = 60
monster_default_movestyle = 1
bat_speed = 4
explosion_particles = 16
bonus_letters = {"b","o","n","u","s"}
rainbow_colors = {8,10,11,12}
gameover_letters = {64,65,66,67,0,68,69,67,70}
starting_lives = 3

-- max time between coins in a row
coin_countdown_max = 20

-- dying time (in frames) at which game resets / game overs
done_dying = 100

map_w = 12
map_h = 15
max_spr_x = (map_w-1) * 8
max_spr_y = (map_h-1) * 8

max_levels = 8

-- music
hero_death_music = 16
victory_music = 17
gameover_music = 19

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

-- lerp between a and b
function lerp(a, b, t)
	local c = b - a
	return a + (c * t)
end

-- convert from polar to cartesian coordinates
function pol2cart(a, r)
	local t = {}
	t.x = sin(a) * r
	t.y = -cos(a) * r
	return t;
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

-- draws outlined text
function outlined_text(text,x,y,text_color,outline_color)
	print(text,x-1,y-1,outline_color)
	print(text,x+1,y-1,outline_color)
	print(text,x-1,y+1,outline_color)
	print(text,x+1,y+1,outline_color)

	print(text,x,y-1,outline_color)
	print(text,x,y+1,outline_color)
	print(text,x-1,y,outline_color)
	print(text,x+1,y,outline_color)

	print(text,x,y,text_color)
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
					elseif(roundtonearest(hero.y,8) == b.y and inrange(hero.x - b.x,8)) then
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
					elseif(roundtonearest(hero.y,8) == b.y and inrange(b.x - hero.x,8)) then
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

game_mode = 0
-- game_mode
--- 0 = title screen
--- 1 = main game
--- 2 = game over
--- 3 = intermission
--- 4 = extra life animation
--- 5 = high score entry

current_level = 0

current_map_x = 12 + 12
current_map_y = 0

lives = 0
score = 0
coin_countdown = 0
coins_in_a_row = 0

monster_spawn_countup = 0
monster_spawner_pos = 0

dead_monsters = 0
next_bonus_letter = 1
rainbow_color = rainbow_colors[1]
level_won = false

debug_text = ""

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
		if(level_won) then
			return
		end
		
		if(self.dying < 1) then
			lives -= 1
			self.dying = 1
			music(hero_death_music)
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

-- monster

-- prototype behavior for monsters
monster_proto = {
	facing = 0,
	speed = 1,
	digging = false,
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
		local b = boulder_check(self, self.facing)

		if(flr(self.x%8) == 0 and flr(self.y%8) == 0) then
			local potential_directions = {}
			local available_directions = {}
			for i=0,3 do
				if(self:wallcheck(i) == 0 and b != 1) then
					add(available_directions, i)
				end
			end
			
			if(self.digging) then
				if(mget(self.x/8,self.y/8) > 0) then
					mset(self.x/8,self.y/8,0)
					if(self.x <= 0 and self.facing == 3) then
						self.facing = 1
					elseif(self.x >= map_w*8 and self.facing == 1) then
						self.facing = 3
					end
					
					add(potential_directions,self.facing)
					speed = self.speed * 0.7
				else
					self.digging = false
				end
			elseif(self.movestyle == 0) then
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

				if(contains(available_directions,self.facing)) then
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
		elseif(b == 1) then
			self.facing = reverse_facing
		end

		-- check for boulder again in case facing has changed
		b = boulder_check(self, self.facing)

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
		self.y = minmax(self.y,-8,max_spr_y)
		
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
		if(self == letter_man) then
			next_bonus_letter+=1
		end
	end,
	
	draw = function(self)
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

-- behavior for letter man, who's a monster with some differences
letter_man = monster_proto:instantiate(0,0,2)

letter_man.start = function(self)
	if(contains(monster,self)) then
		return
	end
	
	self.x = 5*8
	self.y = -1*8
	self.facing = 2
	add(monster,self)
	dead_monsters -= 1
end

letter_man.draw = function(self)
	local frame = flr((self.x + self.y)/2) % 4
	if(frame == 1) then
		spr(51,self.x,self.y)
	elseif(frame == 3) then
		spr(51,self.x,self.y,1,1,true)
	else
		spr(50,self.x,self.y)
	end
	
	print(bonus_letters[next_bonus_letter],self.x+3, self.y+1,10)
end

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
		print(self.value,self.x,self.y-(self.progress/2),rainbow_color)
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
				if(self.cooldown == 0) then
					explosion:start(hero.x+4,hero.y+4,true)
				end
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
				local xx = self.x+x
				local yy = self.y+y
				if(xx > -1 and xx < map_w and yy > -1 and yy < map_h) then
					mset(xx,yy,0)
				end
			end
		end
		
		-- if explosion hits the crack, open the crack
		if(crack.state == 0) then
			if(abs(self.x - crack.x) <= 1 and abs(self.y - crack.y) <= 1) then
				crack.state = 1
			end
		end
		
		-- if explosion hits a boulder, break the boulder
		for b in all(boulder) do
			if(abs(self.x * 8 - b.x) <= 8 and abs(self.y * 8 - b.y) <= 8) then
				b.state = boulder_break_state
				bat:start(b.x,b.y)
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

		self.state = 2
		explosion:start(self.x*8+4,self.y*8+4,false)
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

-- explosion / implosion behavior
explosion = {
	x, y,
	particle = {},
	progress = 0,
	frame = 0,
	
	start = function(self,x,y,reverse)
		self.reverse = reverse
		self.progress = 0
		self.x = x
		self.y = y
		self.particle = {}		
		
		for i=1,explosion_particles do
			add(self.particle, pol2cart(rnd(100)/100,64))
		end
	end,
	
	update = function(self)
		if(self.progress > 1) then
			return
		end
		self.progress += 1/30
		
		self.frame += 1
		self.frame %= 2
	end,
	
	draw = function(self)
		if(self.progress > 1) then
			return
		elseif(level_won and self.reverse) then
			return
		end
	
		local x,y
		local progress = self.progress
		if(self.reverse) then
			progress = 1-self.progress
			self.x = hero.x+4
			self.y = hero.y+4
		end
		
		local n = 0
		for p in all(self.particle) do
			n += 1
			if(n % 2 == self.frame) then
				x = self.x + (p.x * progress)
				y = self.y + (p.y * progress)
--				circfill(x,y,1,7)
				circfill(x,y,1,rainbow_colors[(n%#rainbow_colors)+1])
			end
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
		pal(10,rainbow_color)
	
		if(self.state == 0) then
			-- closed
			spr(26,x,y)
		elseif(self.state == 1) then
			-- open and not collected
			spr(27,x,y)
			spr(28,x,y)
		elseif(self.state == 2) then
			-- open and empty
			pal()
			pal(5,0)
			spr(27,x,y)
		end
		
		pal()
	end
}

-- behavior for bat
bat = {
	done = true,

	-- set bat starting position and speed
	start = function(self, xpos, ypos)
		-- if crack is already exposed, skip bat
		if(crack.state > 0) then
			return
		end
	
		self.x = xpos
		self.y = ypos
		
		self.xspeed = (crack.x * 8) - xpos
		self.yspeed = (crack.y * 8) - ypos
		
		local total_speed = abs(self.xspeed) + abs(self.yspeed)
		
		-- make sure total speed is not 0, because bat could spawn right on top of crack
		if(total_speed > 0) then
			self.xspeed *= (bat_speed / total_speed)
			self.yspeed *= (bat_speed / total_speed)
			
			self.done = false
		else
			self.done = true
		end
	end,

	update = function(self)
		if(self.done) then
			return 
		end
		
		self.x += self.xspeed
		self.y += self.yspeed
		
		if(self.x < -8 or self.y < -8) then
			self.done = true
		elseif(self.x > max_spr_x or self.y > max_spr_y) then
			self.done = true
		end
	end,
	
	draw = function(self)
		if(self.done) then
			return 
		end	

		local frame = flr((time() %1) * 2)
		spr(43+frame, self.x, self.y)
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
					bat:start(self.x,self.y)
				else
					self.state = 0
				end
			else
				local b = self:blocked(2)
				if(b != 0) then
					-- break boulder if it falls on another boulder or bottom of screen
					self.y -= (self.y % 8)
					
					self.state = boulder_break_state
					bat:start(self.x,self.y)
					
					-- if it fell on another boulder, break that one too, but don't spawn bat
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

-- behavior for the hero in a victory animation
victory_hero = {
	state = 0,
	-- state
	--- 0 = victory pose delay
	--- 1 = fire grappling hook
	--- 2 = rappel up off screen
	--- 3 = wait delay
	--- 4 = next level
	
	delay = 0,

	start = function(self)
		self.state = 0
		self.delay = 0
		
		self.x = hero.x
		self.y = hero.y
		
		self.hookx = self.x + 3
		self.hooky = self.y - 8		
	end,

	update = function(self)
		if(self.state == 0 or self.state == 3) then
			-- wait
			self.delay+=1
			if(self.delay >= 30) then
				self.delay = 0
				self.state += 1
			end
		elseif(self.state == 1) then
			-- fire hook
			self.hooky -= 4
			if(self.hooky < -24) then
				self.state += 1
			end
		elseif(self.state == 2) then
			-- rappel up off screen
			self.y -= 2
			if(self.y < -24) then
				self.state += 1
			end
		else
			end_level()
		end		
	end,
	
	draw = function(self)
		-- draw hat
		spr(14, self.x, self.y-3)
		
		spr(12, self.x, self.y)
		
		if(self.state > 0) then
			spr(13, self.hookx, self.hooky)
			line(self.x + 6, self.hooky + 8, self.x + 6, self.y, 7)
		end
	end
}

-- place the boulders and the crack
place_boulders = function()
	local tiles = {}
	local crack_tiles = {}
	
	for x=1,map_w-2 do
		for y=0,map_h do
			if(mget(x,y) != 0) then
				add(crack_tiles,from_xy(x,y))
				if(y<map_h/2 and mget(x,y+1) != 0) then
					add(tiles,from_xy(x,y))
				end
			end
		end
	end

	-- delete tiles with coins on them from possible boulder or crack placements
	for c in all(coin) do
		del(tiles,c)
		del(crack_tiles,c)
	end

	-- place crack in a random position
	local t = rnd(crack_tiles)
	local pos = to_xy(t)
	crack.x = pos.x
	crack.y = pos.y
	crack.state = 0
	
--	debug_text = "crack tile at "..crack.x..","..crack.y
			
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
	add(monster, monster_proto:instantiate(pos.x,pos.y,monster_default_movestyle))
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
		local m = monster_proto:instantiate(b.x/8,b.y/8,monster_default_movestyle)
		add(monster, m)
		if(mget(b.x/8,b.y/8) > 0) then
			m.digging = true
			if(b.x/8 > map_w/2) then
				m.facing = 3
			else
				m.facing = 1
			end
		end
	end

	dead_monsters = max_monsters - #monster
	
	boulder = {}
	
	for p in all(pos) do
		add(boulder, boulder_proto:instantiate(p.x,p.y))
	end
	
	letter_man:start()
end

-- reset the level. Called after hero dies
function reset_level()
	hero.dying = 0
	hero.x=5 * 8
	hero.y=max_spr_y
	
	bomb:reset()
	
	monster = {}
	floaty_numbers = {}
	
	music(0,0,3)
end

function end_level()
	-- TODO: play intermission if it's time for one
	
	if(next_bonus_letter > #bonus_letters) then
	-- TODO: play bonus animation if bonus is full
		next_bonus_letter = 1
	end
	
	next_level()
end

function next_level()
	local offset = (current_level % max_levels) + 2
	current_map_x = (offset) * 12
	
	current_level += 1

	coin = {}

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
	level_won = false
	
	reset_level()
end

-- maingame mode
maingame = {
	start = function()
		game_mode = 1

		coin = {}
		boulder = {}
		monster = {}
		floaty_numbers = {}

		camera(0,-8)
		
		lives = starting_lives
		score = 0
		current_level = 0
		
		next_level()
	end,

	update = function()
		rainbow_color = rainbow_colors[(flr(((time() * 2) %1) * #rainbow_colors))+1]

		crack:update()
		bomb:update()
		bat:update()
		explosion:update()

		if(level_won) then
			victory_hero:update()
		else 
			hero:update()
		end
		
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

		if(hero.dying < 1 and level_won == false) then
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
			
			if(#coin == 0) then
				-- if hero collected all coins, hero won
				level_won = true
			elseif(dead_monsters == max_monsters) then
				-- if hero killed all monsters, hero won
				level_won = true
			elseif(next_bonus_letter > #bonus_letters) then
				-- if hero completed bonus letters, hero won
				level_won = true
			end
			
			if(level_won) then
			-- if hero won, go to the next level
				victory_hero:start()
				music(victory_music)
			end
			
		elseif(hero.dying >= done_dying and boulders_falling == false) then
			if(lives > 0) then
				reset_level()
			else
				gameover.start()
			end
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
	end,
	
	draw = function()
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

		bat:draw()

		if(level_won) then
			victory_hero:draw()
		else 
			hero:draw()
		end
		
		explosion:draw()
		
		print("score:\n"..score,(map_w*8)+3,3,7)
		
		local bonus_y = 20
		rect((map_w*8)+3,bonus_y,125,bonus_y+8,6)
		
		for i = 1,#bonus_letters do
			local x = (map_w*8)+(i*5)
			if(i<next_bonus_letter) then		
				print(bonus_letters[i],x,bonus_y + 2,rainbow_color)
			else
				print(bonus_letters[i],x,bonus_y + 2,5)
			end
		end
		
		spr(10,(map_w*8)+7,33)
		print("X"..lives,(map_w*8)+7+9,32,7)
		
		print("level:\n"..current_level,(map_w*8)+3,44,7)
		
		print(debug_text,8,-8)	
	end
}

-- title screen mode
title_screen = {
	start = function()
		game_mode = 0
	end,
	
	update = function()
		if(btnp(4) or btnp(5)) then 
			maingame.start()
		end
	end,
	
	draw = function()
		cls()
	
		local y = 24
		local stripes_x = (-time()*16)%8
	
		-- draw stripes
		map(120,0,stripes_x,y,8,4)
		map(120,0,stripes_x+64,y,8,4)
		
		pal(1,0)
		
		-- draw logo
		map(120,4,4*8,y,8,4)
		
		-- draw blockers
		map(120,8,0,y,4,4)
		map(120,8,12*8,y,4,4)
		
		pal()
		
		local s = "press \142 or \151 to start!"
		print(s,64-(#s*2),80,7)
		
		s = "by r.hunter gough"
		print(s,64-(#s*2),128-12,6)
		
		s = "studiohunty.com"
		print(s,64-(#s*2),128-6,6)

	end
}

-- gameover mode
gameover = {
	progress = 0,

	start = function()
		game_mode = 2
		
		music(gameover_music)		
		progress = 0
	end,
	
	update = function()
		progress += 1
		if(progress > 30 * 4) then
			-- TODO: go to score entry if high score
			title_screen.start()
		end
	end,
	
	draw = function()
		maingame.draw()
		local x = (map_w*4) - 37
		local y = (map_h*4) - 4
		if(progress < 60) then
			y -= 60 - progress
		end
		
		for i=1,#gameover_letters do
			if(gameover_letters[i] > 0) then
				spr(gameover_letters[i], x + 6*i, y)
			end
		end
	end
}

-- main functions

function _init()
	cls()
	title_screen.start()
end

function _update()
	if(game_mode == 0) then
		title_screen.update()
	elseif(game_mode == 1) then
		maingame.update()
	elseif(game_mode == 2) then
		gameover.update()
	end
	
end

function _draw()
	if(game_mode == 0) then
		title_screen.draw()
	elseif(game_mode == 1) then
		maingame.draw()
	elseif(game_mode == 2) then
		gameover.draw()
	end

end

__gfx__
0000000055555555009999000099990000999900009999000099990000999900009999000099990000e22e0000e20000009999000000000000e22e0000000000
00000000335333330999999009999990009f3f00009f3f00009f3f00009f3f00093ff390093ff39000eeee0000ee2e00093ff3f00000000000eeee0000000000
00000000335333330999999009999990009fff00009fff00009fff00009fff0009ffff9009ffff90ee2222eeee22ee0009ffffe0000000002222222200000000
00000000335333330999999009999990009ee000009ee000009ee000009ee00009eeee9009eeee90eeeeeeee0eee22ee09eeeee0000600002222222200000000
00000000555555550eeeeee00eeeeee000eeef0000eeef0000efe00000efe0000eeeeee00eeeeee000000000000eeee00eeeee40066666000000000000000000
00000000333335330feeeef00feeeef000efe00000efe00000eeef0000eeef000feeeef00feeeef000000000000000000feeee00650605600000000000000000
000000003333353300eeee0000e44e0000eee0000eee4e0000eee0000eeeee0000eeee0000e44e00000000000000000000eeee00000600000000000000000000
000000003333353300e44e000000ee0000eeee000ee44ee000eeee000ee44ee000e44e000000ee00000000000000000000e44e00006660000000000000000000
555511115dddddd50049940000049940000004940000000000000000000000000000000000000000000000000055550000000000000000000000000000000000
11115555d5dddd5d0499994000499994000049940440000000000000005555000099990000099000000100000511115000aaaa00000000000000000000000000
11111111dd5555dd04a99a40004a999400004a94494500000000000005665550099a9990009aa9000000100051111115009aa900000000000000000000000000
11111111ddd5dddd49999994049999a40004999449a45000455555540565555009a99a900099a900001100005111111500999900000000000000000000000000
55551111ddd5dddd9aaaaaa909aa99940009aaa4499945009999a9a90555555009a99a900099a900000011005111111500099000000000000000000000000000
11115555dd5d5ddd499999940499aaa900049994049a944049a9a9a9055555500999a990009aa900000100005111111500099000000000000000000000000000
1111111155ddd5559aaaaaa909aa99940009aaa404a9a9400449a9a4005555000099990000099000000010005111111500999900000000000000000000000000
111111115ddddddd049999400049aa4000004994000a440000049490000000000000000000000000000000000555555000000000000000000000000000000000
005555000055550000888800008888000088880000888800008888000088880000888800008888000000000000000000c000000c000000000000000000000000
051111500522225008888880088888800888888008888880088888800888888008888880088888800000000000000000dc0000cd000000000000000000000000
0511115005b22b5008888880088888800888b8800888b8800888b8800888b88008b88b8008b88b80000000000cc00cc0ddc00cdd000000000000000000000000
0511115005222250088888800888888008888880088888800888888008888880088888800888888000000000cdaccadc0daccad0000000000000000000000000
0051150000522500006dd600006dd60000d66d0000d66d0000d66d0000d66d00006dd600006dd60000000000cdccccdc00cccc00000000000000000000000000
0051150000522500086dd680086dd68000dd668000dd668000dd668000dd6680088dd880088dd88000888800c00cc00c000cc000000000000000000000000000
005115000052250000dddd000022dd00000dd0000255dd00000dd00008dd550000dddd000022dd0008b88b800c0000c000000000000000000000000000000000
05555550055555500082280000008800000888000220888000088800088022200082280000008800222dd2220000000000000000000000000000000000000000
544454443dd33dd300cccc0000cccc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4545444433dd33dd0cccccc00cccccc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44544444d33dd33d0cccccc0dcccccc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
45454444dd33dd33dccccccddccccccd000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
544454443dd33dd3dccccccd0ccccccd000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4444454533dd33dd0cccccc00cccccc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44444454d33dd33d00cccc0000cccc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44444545dd33dd330dd00dd00000dd00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0aaaaa000aaaaa00aaaaaaa0aaaaaaa00aaaaa00aaa0aaa0aaaaaa00eebbccdd1999999999911111111111111199999999999111111111111111111119999111
aa888aa0aa888aa0a88a88a0a88888a0aa888aa0a8a0a8a0a8888aa0ebbccdde9aaaaaaaaaa911111111111119aaaaaaaaaaa91111111111111111119aaaa911
a8aaa8a0a88a88a0a8a8a8a0a8aaaaa0a8aaa8a0a8aaa8a0a8aaa8a0bbccddee9a000000000a91111111111119a000000000a9111111111111111119a0000a91
a8aaaaa0a8aaa8a0a8a8a8a0a8888a00a8a0a8a0aa8a8aa0a8aaa8a0bccddeeb9a0000000000a9111111111119a000000000a9111111111111111119a0000a91
a8aa88a0a88888a0a8a8a8a0a8aaaa00a8a0a8a00a8a8a00a8888aa0ccddeebb19a000aaa000a9199919911119aa0000000aa911111111111111119a000000a9
a8aaa8a0a8aaa8a0a8aaa8a0a8aaaaa0a8aaa8a00aa8aa00a8a8aaa0cddeebbc19a000a99a000a9aaa9aa9111199a00000a99111111111111111119a000000a9
aa8888a0a8a0a8a0a8a0a8a0a88888a0aa888aa000a8a000a8aa88a0ddeebbcc19a000a99a000aa000a00a911119a00000a91111111111111111119a000000a9
0aaaaaa0aaa0aaa0aaa0aaa0aaaaaaa00aaaaa0000aaa000aaaaaaa0deebbccd19a000a99a000a00000000a91119a00000a91111111111111111119a000000a9
000000000000000000000000000000000000000000000000000000000000000019a000a99a000a00000000a91119a00000a91111111999999111119a000000a9
000000000000000000000000000000000000000000000000000000000000000019a000a99a000aa000a000a91119a00000a91111199aaaaaa991119a000000a9
000000000000000000000000000000000000000000000000000000000000000019a000a99a000aa000aaaa991119a00000a911119aa000000aa91119a0000a91
000000000000000000000000000000000000000000000000000000000000000019a000a99a000aa000a999aa9119a00000a91119a0000000000a9119a0000a91
000000000000000000000000000000000000000000000000000000000000000019a000a99a000aa000a99a00a919a00000a9119a000000000000a919a0000a91
000000000000000000000000000000000000000000000000000000000000000019a000aaa000aaa000a9a0000a99a00000a9119a0000aa000000a919a0000a91
00000000000000000000000000000000000000000000000000000000000000009a0000000000a9a000a9a0000a99a00000a919a0000a99a000000a99a0000a91
00000000000000000000000000000000000000000000000000000000000000009a000000000a9a00000a9a00a919a00000a919a000a9119a00000a919a00a911
00000000000000000000000000000000000000000000000000000000000000009aaaaaaaaaa99aaaaaaa19aa9119a00000a99a0000a9119a000000a99a00a911
00000000000000000000000000000000000000000000000000000000000000001999999999911999999911991119a00000a99a0000a91119a00000a99a00a911
00000000000000000000000000000000000000000000000000000000000000001111111111111111111999911119a00000a99a0000a91119a00000a919aa9111
00000000000000000000000000000000000000000000000000000000000000001111111111111111119aaaa91119a00000a99a0000a911119a0000a919aa9111
0000000000000000000000000000000000000000000000000000000000000000111111111111111119a0000a9119a00000a99a0000a911119a0000a911991111
0000000000000000000000000000000000000000000000000000000000000000111111111111111119a0000a9119a00000a99a00000a91119a0000a911111111
0000000000000000000000000000000000000000000000000000000000000000111111111111111119a0000a9119a00000a99a00000a91119a0000a911111111
0000000000000000000000000000000000000000000000000000000000000000111111111111111119a0000a9119a00000a99a000000a9119a0000a919999111
0000000000000000000000000000000000000000000000000000000000000000000000000000000019a0000a9999a00000a919a00000a9119a000a919aaaa911
0000000000000000000000000000000000000000000000000000000000000000000000000000000019a00000aaaa000000a919a000000a99a0000a919a00a911
0000000000000000000000000000000000000000000000000000000000000000000000000000000019a00000000000000a91119a000000aa0000a919a0000a91
00000000000000000000000000000000000000000000000000000000000000000000000000000000119a0000000000000a91119a000000000000a919a0000a91
00000000000000000000000000000000000000000000000000000000000000000000000000000000119a000000000000a9111119a0000000000a9119a0000a91
000000000000000000000000000000000000000000000000000000000000000000000000000000001119aa000000000a911111119aa000000aa911119a00a911
00000000000000000000000000000000000000000000000000000000000000000000000000000000111199aaaaaaaaa911111111199aaaaaa99111119aaaa911
00000000000000000000000000000000000000000000000000000000000000000000000000000000111111999999999111111111111999999111111119999111
__map__
1010101010101010101010101010101010101010101010100101010000000000010101011111000000000000000011113030000000000000000030303131313131000000000031310100000000000000000000011111110000000000001111113000000000000000000000303131310000000000003131314747474747474747
1010101010101010101010101010101010101010101010101801010101000101010101011100001111111111110000113000003030303030300000303131313100003131310031310100180101010101010100011111000018111811000011113000303030301830183000303131000031313131000031314747474747474747
1010101010101010101010101010101010101010101010100101010101000118011801011100111111111811181100113000303030303018303000303131310000183118310018310100010101010101010101011100001111111111110000113030303030303030303000303100003131313118310000314747474747474747
1010101010101010101010101010101010101010101010101801011801000101010101011111111111111111111100113018301830303030303000303131000031313131310031310100180101010101010101011100111111111111111100113030303030303030300000303100311831313131313100314747474747474747
10101010101010101010101010101010101010101010101001010101010001010101010111181118111111111111001130303030303030183030003031000031313131313100183101000101010101010101180111001111111111111111111130183018303030300000303031003131313131183131003148494a4b4c4d4e4f
10101010101010101010101010101010101010101010101001010118010001010101010111111111111111111100001130303030303030303000003031003131313131313100313101000101011801180101010111001811181111111111181130303030303030000030303031003118313131313131003158595a5b5c5d5e5f
10101010101010101010101010101010101010101010101001010101010001010101010111111111111111000000111130303030303030300000303031003131313131313100313101000101010101010101180111001111111111111111111130303030303000003030303031000031313131313100003168696a6b6c6d6e6f
1010101010101010101010101010101010101010101010100101010101200100000000011111111111002000111111111830300000200000003030303100000000002000000000310100000000002000000001011100110000002000001118113030303030200030303018303131000000002000000031314d4d7a7b7c7d7e7f
1010101010101010101010101010101010101010101010100101010101000100180100011111110000001118111111113030301830183030000030303131313131313131310031310118011801010101010000011100000011111111000011113030303030003030303030303100003131313131310000314d4d4d4d4d4d4d4d
1010101010101010101010101010101010101010101010101801180101000100010100011111000011111111111118111830303030303030300000303131313118311831310031310101010101010101010100011100111811111111110000113030303030003018303018303100183118313131183100314d4d4d4d4d4d4d4d
1010101010101010101010101010101010101010101010100101010101000100180100011100001111111118111111113030303030303030303000303131313131313131310031310101010101010101010100011100111111111811111100113030303030003030303030303100313131313131313100314d4d4d4d4d4d4d4d
1010101010101010101010101010101010101010101010100101010101000100010100011100111111111111111118113000303030303030303000303118313131313131310031310100010101010101010100011100111811111111111100111830183030003018303030303100313131313131183100314d4d4d4d4d4d4d4d
1010101010101010101010101010101010101010101010100100010101000100000000011100111811181111111111113000003018301830300000303131313131183118310031310100000118011801010000011100001111111811110000113030303030003030303030303100311831183131313100310000000000000000
1010101010101010101010101010101010101010101010100100010101000101010101011100111111111111111111113030000030303030000030303118313131313131310031310101000001010101000001011111000011111111000011113030303030003030303030303100003131313131310000310000000000000000
1010101010101010101010101010101010101010101010100100000000000101010101011100000000000000000000113030300000000000003030303131313131000000000031310101010000000000000101011111110000000000001111113030303030003030303030303131000000000000000031310000000000000000
__sfx__
01060000051000510000000000000010000100000000000007100071000000000000001000010000000000000510005100000000000000100001000000000000071000710000000000000c1000c1000000000000
010800181155011500115500000011550000001155011550115501155000000000001555015550000000000011550000000e5500e5500c5000c5000c550000000000000000000000000000000000000000000000
010800181155000000115500000011550000001155011550115501155000000000001555015550155500000016550165501855018550185000000000000000000000000000000000000000000000000000000000
010800181855018550185500000018550000001655016550165500000016550000001555015550155500000015550000001355013550135501355000000000000000000000000000000000000000000000000000
010600000513005130051300513000600001000000000000001300013000130001300060000100006000010007130071300713007130006000010000600001000013000130001300013000600001000060000100
010600000513005130051300513000600001000060000000001300013000130001300060000100006000010007130071300713007130006000010000600001000c1300c1300c1300c1300c600001000060000100
010c00000e5500e5500e5500e5000e5500c0000e5000e55011550115501155011550115500c0000c0001150011550115501155011500115500c00011500115501555015550155501550013550135500c0000c000
010c00000e5500e5500e5500e5000e5500c0000e5000e55011550115501155011550115500c0000c0001150015550155501555011500155500c000115001655013550135501355013550135500c0000c0000c000
010c000002130021300000002100021300000000000021300513005130006000010005130000000000005130021300213000000000000213000000006000213005130051300c6000c10007130000000000007130
010600080562500005000050000505605056200000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050560500005
011000001155018550000001855016550000001655015550000001555013550000001150011550000000c5000c550000001150011550000000000000000000000000000000000000000000000000000000000000
010800181155011500115500000011550000001155011550115501155000000000001555000000155500000015550000001555015550155501555000000000001150013500155001d500185001d5000000000000
011000001155013550155501d55000000185501d55000000000000515000000021000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010c000011550000000000011550000001155011550115500000000000105500000000000105500000010550105501055000000000000b5500b550000000f5500f5500b5500b5500000010550000000000000000
010c00000512005120051200512000000000000000000000000000000004120041200412004120000000000000000000000000000000001200012000120001200310000000000000000004120041200412004120
__music__
00 41044344
00 41054344
00 41040944
00 41050944
01 01040940
00 02050940
00 01040940
00 03050940
00 01040940
00 02050940
00 01040940
00 03050940
00 06080940
00 07080940
00 06080944
02 07080944
04 0a404344
00 0b050944
04 0c424344
04 0d0e4944

