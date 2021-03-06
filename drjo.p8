pico-8 cartridge // http://www.pico-8.com
version 27
__lua__
-- dr jo
-- r. hunter gough / studio hunty

-- constants
boulder_fall_state = 8
boulder_break_state = 10
max_boulders = 6
max_monsters = 6
monster_spawn_freq = 60
monster_default_movestyle = 1
bat_speed = 4
explosion_particles = 20
bonus_letters = {"b","o","n","u","s"}
rainbow_colors = {8,10,11,12}
gameover_letters = {64,65,66,67,0,68,69,67,70}
high_score_characters = { "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", ".", "!", "_", "\139" }
starting_lives = 3
intermission_frequency = 4

-- max time between coins in a row
coin_countdown_max = 15

-- dying time (in frames) at which game resets / game overs
done_dying = 100

map_w = 12
map_h = 15
max_spr_x = (map_w-1) * 8
max_spr_y = (map_h-1) * 8

bomb_sidebar_x = max_spr_x + 19
bomb_sidebar_y = 44

max_levels = 8

-- music
hero_death_music = 29
chalice_music = 16
victory_music = 17
gameover_music = 19
score_entry_music = 20
extra_life_music = 22
intermission_music = 25

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

-- returns the index of the first instance of value in the array, 0 if none
function index_of(array, value)
	for i=1,#array do
		if(array[i] == value) then
			return i
		end
	end
	
	return 0
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

-- load high scores
function load_high_scores()
	high_scores = {}
	for i=0,20,5 do		
		local t = {}
		t.score = dget(i)
		t.kscore = dget(i+1)
		t.name = {dget(i+2), dget(i+3), dget(i+4)}
		add(high_scores,t)
	end
	
	-- if high scores are empty, use default ones
	if(high_scores[1].score == 0 and high_scores[1].kscore == 0) then
		high_scores[1].kscore = 6
		high_scores[1].name = { 18,8,7 }								
		high_scores[2].kscore = 5
		high_scores[2].name = high_scores[1].name
		high_scores[3].kscore = 4
		high_scores[3].name = high_scores[1].name
		high_scores[4].kscore = 3
		high_scores[4].name = high_scores[1].name
		high_scores[5].kscore = 2
		high_scores[5].name = high_scores[1].name
		
		save_high_scores()
	end
end

-- save high scores
function save_high_scores()
	for i=1,5 do
		local n = (i-1)*5
		dset(n,high_scores[i].score)
		dset(n+1,high_scores[i].kscore)
		dset(n+2,high_scores[i].name[1])
		dset(n+3,high_scores[i].name[2])
		dset(n+4,high_scores[i].name[3])
	end
end

function concat_score(kscore, score)
	kscore = kscore or 0
	
	if(kscore == 0) then
		return tostring(score)
	end
	
	local s = tostring(kscore)
	if(score < 100) then
		s = s.."0"
	end
	if(score < 10) then
		s = s.."0"
	end
	
	return s..score
end

-- check to see if there's a boulder or wall immediately in the specified direction from the character
-- returns 0 for no boulder, 1 for blocked or vertical boulder, and the boulder if it's pushable
function boulder_check(character, dir)
	if(dir==0) then
		if(character.y<=0) then
			return 1
		else
			for b in all(boulder) do
				if(roundtonearest(character.x,8) == roundtonearest(b.x,8) and inrange(character.y - b.y,8)) then
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
				if(roundtonearest(character.y,8) == roundtonearest(b.y,8) and inrange(b.x - character.x,8)) then
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
				if(roundtonearest(character.x,8) == roundtonearest(b.x,8) and inrange(b.y - character.y,8)) then
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
				if(roundtonearest(character.y,8) == roundtonearest(b.y,8) and inrange(character.x - b.x,8)) then
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
kscore = 0
coin_countdown = 0
coins_in_a_row = 0

chalice_countdown = 0

monster_spawn_countup = 0
monster_spawner_pos = 0

dead_monsters = 0
next_bonus_letter = 1
rainbow_color = rainbow_colors[1]
level_won = false

high_scores = {}

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
				-- place bomb
				sfx(29,3)
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
				
				sfx(32+coins_in_a_row,3)
				coins_in_a_row += 1
				coin_countdown = coin_countdown_max
				score += 5 + (coins_in_a_row * 5)
				del(coin,c)
			end
		end
				
		if(crack.state == 1 and tile_x == crack.x and tile_y == crack.y) then
			score += 100
			crack.state = 2
			chalice_countdown = 60
			music(chalice_music)
			
			victory_hero.x = self.x
			victory_hero.y = self.y

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
	ghostly = false,
	movestyle = 0,
	-- movestyle
	--- 0 = erratic
	--- 1 = can only reverse if hit a wall
	--- 2 = can only reverse if hit a dead end

	update = function(self)	
		self:move()
		
		-- if this monster has caught the hero, hero dies
		if(inrange(self.x-hero.x,-4,4) and inrange(self.y-hero.y,-4,4)) then
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
			
			if(self.ghostly) then
				local map_y = roundtonearest(self.y,8)/8
				local map_x = roundtonearest(self.x,8)/8
				
				if(mget(map_x,map_y) == 0) then
					self.ghostly = false
				elseif(self.facing == 1 and map_x >= map_w-1) then
					self.facing = 3
				elseif(self.facing == 3 and map_x <= 0) then
					self.facing = 1
				end
				
				if(self.ghostly) then
					add(potential_directions,self.facing)
					speed = self.speed * 0.7
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
		
		if(self.facing == 1 or self.facing == 3) then
			self.y = roundtonearest(self.y,8)
		else
			self.x = roundtonearest(self.x,8)
		end
		
		self.x = minmax(self.x,0,max_spr_x)
		self.y = minmax(self.y,-8,max_spr_y)		
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
		sfx(42,3)
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
		
		if(self.ghostly) then
			pal(8,12)
		end
		spr(sprite,self.x,self.y,1,1,flip)
		pal()
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
			if(level_won or hero.dying>0) then
				return
			end
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
			if(abs(self.x * 8 - m.x) <= 12 and abs(self.y * 8 - m.y) <= 12) then
				point_value += 25
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
		if(time() % 0.5 < 0.25) then
				pal(5,8)
		end
		
		if(self.state == 0) then
			if(self.cooldown <= 0) then
				-- if bomb is available, draw bomb on sidebar
				spr(23,bomb_sidebar_x, bomb_sidebar_y)
			end
		elseif(self.state == 1) then
			spr(23,self.x*8,self.y*8)
		elseif(self.state >= 2) then
			r = (3-self.state) * 12
			circfill((self.x*8)+4,(self.y*8)+4,r,8)
			circfill((self.x*8)+4,(self.y*8)+4,r/2,9)
		end
		pal()
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
		
		if(reverse) then
			sfx(31,3)
		else
			sfx(30,3)
		end
		
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
				-- start wiggling.
				sfx(40,3)
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
					self.point_value += 25
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
					sfx(41,3)
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
					sfx(41,3)
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
	
	draw = function(self, chalice)
		chalice = chalice or false
	
		-- draw hat
		spr(14, self.x, self.y-3)
		
		spr(12, self.x, self.y)
		
		if(chalice) then
			pal(10,rainbow_color)
			spr(28,self.x+3,self.y-6)
			pal()
		elseif(self.state > 0) then
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
	local p = {}
	local new_boulders = {}
	
	for m in all(monster) do
		p.x = roundtonearest(m.x,8)/8
		p.y = roundtonearest(m.y,8)/8
		add(new_boulders, boulder_proto:instantiate(p.x,p.y))
	end
	
	monster = {}
	
	for b in all(boulder) do
		if(b.state > 0) then
			add(new_boulders,b)
		else
			p.x = roundtonearest(b.x,8)/8
			p.y = roundtonearest(b.y,8)/8
			local m = monster_proto:instantiate(p.x,p.y,monster_default_movestyle)
			if(mget(p.x,p.y) > 0) then
				m.ghostly = true
				if(p.x > map_w/2) then
					m.facing = 3
				else
					m.facing = 1
				end
			end
			add(monster, m)
		end
	end

	dead_monsters = max_monsters - #monster
	
	boulder = new_boulders
		
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
	score += 100
	
	if(next_bonus_letter > #bonus_letters) then	
		next_bonus_letter = 1
		extra_life:start()
	elseif(current_level % intermission_frequency == 0) then
		intermission:start()
	else
		next_level()
	end
end

function next_level()
	-- make sure game mode is normal game if we came here from intermission or something
	game_mode = 1

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
	start = function(self)
		game_mode = 1

		coin = {}
		boulder = {}
		monster = {}
		floaty_numbers = {}

		camera(0,-8)
		chalice_countdown = 0
		
		lives = starting_lives
		score = 0
		kscore = 0
		current_level = 0
		next_bonus_letter = 1
		
		next_level()
	end,

	update = function(self)
		if(chalice_countdown > 0) then
			-- dramatic pause for collecting chalice
			chalice_countdown -= 1
			return
		end
	
		crack:update()
		bomb:update()
		bat:update()
		explosion:update()

		if(level_won) then
			victory_hero:update()
		else 
			hero:update()
			if(chalice_countdown > 0) then
				return
			end
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
				gameover:start()
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
	
	draw = function(self)
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

		if(chalice_countdown > 0) then
			victory_hero:draw(true)
		elseif(level_won) then
			victory_hero:draw(false)
		else 
			hero:draw()
		end
		
		explosion:draw()
		
		-- draw sidebar
		print("score:\n"..concat_score(kscore,score),(map_w*8)+3,3,7)
		
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
		
		rect(bomb_sidebar_x-1, bomb_sidebar_y-1, bomb_sidebar_x+8,  bomb_sidebar_y+8,6)
		
		print("level:\n"..current_level,(map_w*8)+3,120-13-16,7)
		
		print("high:\n"..concat_score(high_scores[1].kscore,high_scores[1].score),(map_w*8)+3,120-13,7)
		
		print(debug_text,8,-8)	
	end
}

-- title screen mode
title_screen = {
	start = function(self)
		game_mode = 0
		
		music(-1)
		camera()
	end,
	
	update = function(self)
		if(btnp(4) or btnp(5)) then 
			maingame:start()
		end
	end,
	
	draw = function(self)
		cls()
	
		local y = 20
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
		print(s,64-(#s*2),64,7)
		
		s = "studio hunty presents"
		print(s,64-(#s*2),0,13)
		
		rect(2,78,126,127,5)
		
		s = "high scores:"
		print(s,64-(#s*2),80,12)
		
		for i=1,#high_scores do
			s = high_score_characters[high_scores[i].name[1]]
			s = s..high_score_characters[high_scores[i].name[2]] 
			s = s..high_score_characters[high_scores[i].name[3]]
			
			local color = 7
			if(i == score_entry.place) then
				color = 10
			end	
			
			print(i.." "..s.." "..concat_score(high_scores[i].kscore,high_scores[i].score),40,81+(8*i),color)
		end

	end
}

-- intermission mode
intermission = {
	y_plane = 64+16,
	trip_x = 50,
	state = 0,
	-- state:
	--- -1 = drum fill
	--- 0 = jo and monster running
	--- 1 = jo trips
	--- 2 = jo gets up
	--- 3 = jo continues running
	--- 4 = monster looks at bomb
	--- 5 = bomb explodes
	--- 6 = tiny monster blinks
	--- 7 = bat
	--- 8 = end

	start = function(self)
		game_mode = 3	
		
		music(intermission_music)
		self.state = -1
		self.jo_x = -16
		self.jo_y = 0		
		self.monster_x = -80
		self.bat_x = -8
		self.state_wait = 0
	end,
	
	update = function(self)
		if(self.state == -1) then
			self.state_wait += 1
			if(self.state_wait > 64) then
				self.state += 1
				self.state_wait = 0
			end
		elseif(self.state == 0) then
			if(self.jo_x > self.trip_x) then
				self.state += 1
				self.jo_y = 0
			end
		elseif(self.state == 1) then
			self.jo_y = (self.jo_x - self.trip_x) / 3
			if(self.jo_y > 4) then
				self.state += 1
				self.state_wait = 0
				self.bomb_x = self.jo_x
			end
		elseif(self.state == 2) then
			self.state_wait += 1
			if(self.state_wait > 30) then
				self.state += 1
				self.state_wait = 0
			end
		elseif(self.state == 3) then
			if(self.monster_x >= self.bomb_x - 10) then
				self.state += 1
				self.state_wait = 0
			end
		elseif(self.state == 5) then
			self.state_wait += 1
			if(self.state_wait > 30) then
				self.state += 1
				self.state_wait = 0
			end
		elseif(self.state == 7) then
			self.bat_x += 1.5
			if(self.bat_x >= 128+8) then
				self.state += 1
			end
		elseif(self.state > 3) then
			self.state_wait += 1
			if(self.state_wait > 60) then
				self.state += 1
				self.state_wait = 0
			end
		end
		
		if(self.state > -1) then
			if(self.state != 2) then
				self.jo_x += 1
			end
			
			if(self.state < 4) then
				self.monster_x += 1
			end
		end
		
		if(self.state == 8) then
			next_level()
		end
	end,
	
	draw = function(self)
		cls()

		local run_frame = flr(time()*8)%4
	
		local s = "intermission"
		if(self.state < 0) then
			print(s,64-(#s*2),64-(self.state_wait/2),rainbow_color)
		else
			print(s,64-(#s*2),32,10)
		end

		-- draw bomb
		if(self.state > 1 and self.state < 5) then
			if(run_frame > 2) then
				pal(5,8)
			end
			spr(23,self.bomb_x,self.y_plane-7)
			pal()
		end

		-- draw jo
		if(self.state == 1) then
			-- jo trips
			spr(128,self.jo_x,self.y_plane-16+self.jo_y,2,1)
			spr(147,self.jo_x-8,self.y_plane-8+self.jo_y,3,1)
		elseif(self.state == 2) then
			-- jo gets up
			if(self.state_wait < 20) then
				spr(128,self.jo_x,self.y_plane-16+self.jo_y,2,1)
				spr(147,self.jo_x-8,self.y_plane-8+self.jo_y,3,1)				
			else
				spr(134,self.jo_x,self.y_plane-16,2,2)
			end
		elseif(self.jo_x < 128 and self.jo_x > -16) then
			if(run_frame == 0) then
				spr(128,self.jo_x,self.y_plane-16,2,2)
			elseif(run_frame == 2) then
				spr(128,self.jo_x,self.y_plane-16,2,1)
				spr(131,self.jo_x,self.y_plane-8,2,1)
			else
				spr(130,self.jo_x+4,self.y_plane-16,1,2)
				spr(128,self.jo_x,self.y_plane-17,2,1)
			end
		end
		
		-- draw monster
		if(self.state == 4) then
			-- monster looks at bomb
			spr(166,self.monster_x+4,self.y_plane-16,1,2)
			if(self.state_wait > 30) then
				-- question mark
				spr(167,self.monster_x+4,self.y_plane-28,1,2)
			end
		elseif(self.state == 5) then
			spr(36,self.monster_x+4,self.y_plane-8)
		elseif(self.state > 5) then
			spr(40,self.monster_x+4,self.y_plane-8)
			if(self.state_wait > 20 and self.state_wait < 30) then
				-- blink
				line(self.monster_x+6,self.y_plane-6,self.monster_x+10,self.y_plane-6,8)
			elseif(self.state == 7) then
				-- eyes follow bat
				if(self.bat_x < self.monster_x-8) then
					spr(45,self.monster_x+4,self.y_plane-8)
				elseif(self.bat_x < self.monster_x+16) then
					spr(45,self.monster_x+5,self.y_plane-8)
				else
					spr(45,self.monster_x+4,self.y_plane-8,1,1,true)
				end
			end
		elseif(self.monster_x > -16) then
			if(run_frame == 0) then
				spr(162,self.monster_x,self.y_plane-16,2,2)
			elseif(run_frame == 2) then
				spr(164,self.monster_x,self.y_plane-16,2,2)
			else
				spr(160,self.monster_x,self.y_plane-16,2,2)
			end
		end	

		-- draw explosion
		if(self.state == 5) then
			circfill(self.bomb_x+4,self.y_plane-4,(30-self.state_wait),rainbow_color)
		end
		
		-- draw bat
		if(self.state == 7) then
			spr(43+run_frame%2,self.bat_x,self.y_plane-24)
			
			local s = "follow bats to hidden treasure!"
			print(s,64-(#s*2),self.y_plane+16,12)
		end
		
	end,
}

-- extra life animation mode
extra_life = {
	current_letter,
	progress = 0,
	hat_y = 64,
	draw_light = true,

	start = function(self)
		game_mode = 4
		
		music(extra_life_music)		
		self.current_letter = 1
		self.progress = 1
	end,
	
	update = function(self)
		if(self.progress > 0) then
			self.progress -= 1/190
		else
			self.progress -= 1/10
		end
		
		if(self.progress < -10) then
			if(current_level % intermission_frequency == 0) then
				intermission:start()
			else 
				next_level()
			end
		end
	end,
	
	draw = function(self)
		cls()

		if(self.progress > 0) then
			pal(3,0)
			pal(1,rainbow_color)
		end

		-- draw hat back
		spr(80,64-16,self.hat_y,2,2)
		spr(80,64,self.hat_y,2,2,true)		
		
		if(self.draw_light and self.progress > 0) then
			spr(140,48,self.hat_y-28,4,4)
			self.draw_light = false		
		else
			self.draw_light = true
		end
		
		if(self.progress > 0) then
			local letters = {"s","u","n","o","b"}
		
			-- draw letters
			for i=1,#letters do
				local a=(i+time()*1.5)/5
				local x=64 + sin(a)*24*self.progress
				local y=64 - cos(a)*8*self.progress
				
				outlined_text(letters[i],x,self.hat_y+9-(y*self.progress),rainbow_color,3)
			end
			
			-- draw hat front
			spr(82,64-16,self.hat_y,2,2)
			spr(82,64,self.hat_y,2,2,true)
		else
			local y = self.progress * 16
			
			if(self.progress < -1) then
				y = -16
			end
			spr(10,64-4,self.hat_y+y)
		end
				
		if(self.progress < -1) then
			local s = "extra life!"
			print(s,64-(#s*2),32,12)
		end
		
		pal()
	end
}

-- gameover mode
gameover = {
	progress = 0,

	start = function(self)
		game_mode = 2
		
		music(gameover_music)		
		self.progress = 0
	end,
	
	update = function(self)
		self.progress += 1
		if(self.progress > 30 * 4) then
			local new_high_score = (kscore > high_scores[#high_scores].kscore) or 
					(kscore == high_scores[#high_scores].kscore and score > high_scores[#high_scores].score)
			
			if (new_high_score) then
				score_entry:start()
			else 			
				title_screen:start()
			end
		end
	end,
	
	draw = function(self)
		maingame.draw()
		local x = (map_w*4) - 37
		local y = (map_h*4) - 4
		if(self.progress < 60) then
			y -= 60 - self.progress
		end
		
		for i=1,#gameover_letters do
			if(gameover_letters[i] > 0) then
				spr(gameover_letters[i], x + 6*i, y)
			end
		end
	end
}

-- high score entry mode
score_entry = {
	selected_letter = 1,
	name_letter = 1,
	name = {29,29,29},
	place = 0,

	start = function(self)
		game_mode = 5		
		camera()
		music(score_entry_music)
		
		self.countdown = 60
		self.selected_letter = 1
		self.name_letter = 1
		self.name = {29,29,29}
		
		self.place = 0
		for i=#high_scores,1,-1 do
			if(kscore > high_scores[i].kscore) then
				self.place = i
			elseif(kscore == high_scores[i].kscore and score > high_scores[i].score) then
				self.place = i
			end
		end
		
		local t = {}
		t.kscore = kscore
		t.score = score
		t.name = {29,29,29}
		
		-- insert by index wouldn't work, so I have to do this instead
		local new_high_scores = {}
		for i=1,5 do
			if(self.place == i) then
				add(new_high_scores,t)
			end
			if(#new_high_scores<5) then
				add(new_high_scores,high_scores[i])
			end
		end
		
		high_scores = new_high_scores
		
	end,

	update = function(self)
		if(self.name_letter < 4) then
			if (btnp(0)) then
				self.selected_letter -= 1
			elseif (btnp(1)) then 
				self.selected_letter += 1
			elseif (btnp(2)) then
				self.selected_letter -= 10
			elseif (btnp(3)) then
				self.selected_letter += 10
			end
			
			if(self.selected_letter < 1) then
				self.selected_letter += #high_score_characters
			elseif(self.selected_letter > #high_score_characters) then
				self.selected_letter -= #high_score_characters
			end
			
			if(btnp(4) or btnp(5)) then
				if(self.selected_letter == 30) then
					if(self.name_letter > 1) then
						self.name_letter -= 1
						self.name[self.name_letter] = 29
					end
				else
					self.name[self.name_letter] = self.selected_letter
					self.name_letter += 1
				end
			end
			
			high_scores[self.place].name = self.name
		else
			-- name entry done
			-- do countdown, and then save and return to title
			self.countdown -= 1
			if(self.countdown < 0) then
				save_high_scores()
				title_screen:start()
			end
		end
	end,

	-- draw a letter man at the specified position
	draw_letter_man = function(self,x,y)
		local frame = flr(time()*8) % 4
		if(frame == 1) then
			spr(51,x-3,y-1)
		elseif(frame == 3) then
			spr(51,x-3,y-1,1,1,true)
		else
			spr(50,x-3,y-1)
		end
	end,
	
	draw = function(self)
		cls()
	
		local s = "you got a new high score!"
		print(s,64-(#s*2),8,10)

		if(self.name_letter < 4) then
			for i=1,#high_score_characters do
				local x = (((i-1) % 10) * 8) + 24
				local y = (flr((i-1)/10) * 12) + 24
				if(i==self.selected_letter) then
					self:draw_letter_man(x,y)
					print(high_score_characters[i], x, y, 10)
				else
					print(high_score_characters[i], x, y, 7)
				end
			end
		end

		rect(64-8,62,64+6,70,7)

		for i=1,3 do
			local color = 10
			if(i==self.name_letter) then
				color = rainbow_color
			end
			local x = 64-10+(i*4)
			print(high_score_characters[self.name[i]],x,64,color)
		end

		s = "high scores:"
		print(s,64-(#s*2),80,12)
		
		for i=1,#high_scores do
			s = high_score_characters[high_scores[i].name[1]]
			s = s..high_score_characters[high_scores[i].name[2]] 
			s = s..high_score_characters[high_scores[i].name[3]]
			local color = 7
			if(i == self.place) then
				color = 10
			end	
			
			print(i.." "..s.." "..concat_score(high_scores[i].kscore,high_scores[i].score),40,81+(8*i),color)
		end
	end
}

-- main functions

function _init()
	cartdata("drjo_luvcraft")
	load_high_scores()
	
	cls()
	title_screen:start()
end

function _update()
	rainbow_color = rainbow_colors[(flr(((time() * 2) %1) * #rainbow_colors))+1]

	if(game_mode == 0) then
		title_screen:update()
	elseif(game_mode == 1) then
		maingame:update()
	elseif(game_mode == 2) then
		gameover:update()
	elseif(game_mode == 3) then
		intermission:update()
	elseif(game_mode == 4) then
		extra_life:update()
	elseif(game_mode == 5) then
		score_entry:update()
	end
	
	-- move thousands+ digits of score into kscore
	if(score >= 1000) then
		kscore += flr(score/1000)
		score %= 1000
	end
end

function _draw()
	if(game_mode == 0) then
		title_screen:draw()
	elseif(game_mode == 1) then
		maingame:draw()
	elseif(game_mode == 2) then
		gameover:draw()
	elseif(game_mode == 3) then
		intermission:draw()
	elseif(game_mode == 4) then
		extra_life:draw()
	elseif(game_mode == 5) then
		score_entry:draw()
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
051111500522225008888880088888800888888008888880088888800888888008888880088888800000000000000000dc0000cd0b88b8000000000000000000
0511115005b22b5008888880088888800888b8800888b8800888b8800888b88008b88b8008b88b80000000000cc00cc0ddc00cdd088888000000000000000000
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
000000002eeeeeee00000000000000000000000000000000000000000000000019a000a99a000a00000000a91119a00000a91111111999999111119a000000a9
00002eeeeeeeeeee00000000000000000000000000000000000000000000000019a000a99a000aa000a000a91119a00000a91111199aaaaaa991119a000000a9
002eeeeeeee1111100000000000000000000000000000000000000000000000019a000a99a000aa000aaaa991119a00000a911119aa000000aa91119a0000a91
2eeeeeeee111111100000000000000000000000000000000000000000000000019a000a99a000aa000a999aa9119a00000a91119a0000000000a9119a0000a91
2eeeeeee111111112eeeeeee000000000000000000000000000000000000000019a000a99a000aa000a99a00a919a00000a9119a000000000000a919a0000a91
2eeeeeeee11111112eeeeeeee00000000000000000000000000000000000000019a000aaa000aaa000a9a0000a99a00000a9119a0000aa000000a919a0000a91
002eeeeeeee11111002eeeeeeee00000000000000000000000000000000000009a0000000000a9a000a9a0000a99a00000a919a0000a99a000000a99a0000a91
00002eeeeeeeeeee00002eeeeeeeeeee000000000000000000000000000000009a000000000a9a00000a9a00a919a00000a919a000a9119a00000a919a00a911
00000022eeeeeeee00000022eeeeeeee000000000000000000000000000000009aaaaaaaaaa99aaaaaaa19aa9119a00000a99a0000a9119a000000a99a00a911
00000022222222220000002222222222000000000000000000000000000000001999999999911999999911991119a00000a99a0000a91119a00000a99a00a911
00000022222222220000002222222222000000000000000000000000000000001111111111111111111999911119a00000a99a0000a91119a00000a919aa9111
0000002eeeeeeeee0000002eeeeeeeee000000000000000000000000000000001111111111111111119aaaa91119a00000a99a0000a911119a0000a919aa9111
0000000eeeeeee220000000eeeeeee2200000000000000000000000000000000111111111111111119a0000a9119a00000a99a0000a911119a0000a911991111
00000002eeeee22200000002eeeee22200000000000000000000000000000000111111111111111119a0000a9119a00000a99a00000a91119a0000a911111111
000000002eeee222000000002eeee22200000000000000000000000000000000111111111111111119a0000a9119a00000a99a00000a91119a0000a911111111
0000000002222200000000000222220000000000000000000000000000000000111111111111111119a0000a9119a00000a99a000000a9119a0000a919999111
0000000000000000000000000000000000000000000000000000000000000000000000000000000019a0000a9999a00000a919a00000a9119a000a919aaaa911
0000000000000000000000000000000000000000000000000000000000000000000000000000000019a00000aaaa000000a919a000000a99a0000a919a00a911
0000000000000000000000000000000000000000000000000000000000000000000000000000000019a00000000000000a91119a000000aa0000a919a0000a91
00000000000000000000000000000000000000000000000000000000000000000000000000000000119a0000000000000a91119a000000000000a919a0000a91
00000000000000000000000000000000000000000000000000000000000000000000000000000000119a000000000000a9111119a0000000000a9119a0000a91
000000000000000000000000000000000000000000000000000000000000000000000000000000001119aa000000000a911111119aa000000aa911119a00a911
00000000000000000000000000000000000000000000000000000000000000000000000000000000111199aaaaaaaaa911111111199aaaaaa99111119aaaa911
00000000000000000000000000000000000000000000000000000000000000000000000000000000111111999999999111111111111999999111111119999111
000000eee00000000000000000000eeee000ff000000000000000000000000000000000000000000000000000000000007000700070007000700070007000700
0000eeeee200e0000000000000ee2eeeeeeeef000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000e2222eee0000000000000ffe2e2eeeeee00000000000000000eee00000000000000000000000000000000000000070707070707070707070707070707070
00002eeee9900000000000000ff00ee220000000000000000000eeeee200e0000000000000000000000000000000000000000000000000000000000000000000
00eee9999ff000000000000000000ee2eee00000000000000000e2222eee00000000000000000000000000000000000070707070707070707070707070707070
000999fffcf000000000000000000ee2eeee00000000000000002eeee99000000000000000000000000000000000000007000700070007000700070007000700
0999999ffff00000000000000044eee000ee44000000000000eee9999ff000000000000000000000000000000000000070707070707070707070707070707070
099900fffff00000000eee000044ee000004400000000000000099fffcf000000000000000000000000000000000000007000700070007000700070007000700
00000eeee000ff0000e2ee000000000000000eeee00000000000999ffff000000000000000000000000000000000000000707070707070707070707070707070
000eeeeee2eeff0000e2ee00000044eeeeeeee2eeeeeeff0000999fffff000000000000000000000000000000000000000070007000700070007000700070000
00feee22e2eee00000ee2ef0000444eeeeeeeee2eeeeefff000999eeee0000000000000000000000000000000000000000707070707070707070707070707070
00ff02eee0000000002eeff00044442222222222222224440000002eee0000000000000000000000000000000000000000070707070707070707070707070700
000002eeeee00000002ee0000000000000000000000000000000002ee2ee00000000000000000000000000000000000000707070707070707070707070707000
00000e22eeee0000000ee0000000000000000000000000000000002ee2ee00000000000000000000000000000000000000070707070707070707070707070700
0044eee000ee4400000440000000000000000000000000000044eee2ef4400000000000000000000000000000000000000007070707070707070707070707000
0044ee0000044000000444000000000000000000000000000044ee22ff4440000000000000000000000000000000000000070777077707770777077707770000
0000888800000000000088880000000000008888000000000000000000bbbb000000000000000000000000000000000000007070707070707070707070707000
008888888000000000888888800000000088888880000000088888000bbbbbb00000000000000000000000000000000000007707770777077707770777070000
088888888800000008888888880000000888888888000000888888800bb00bb00000000000000000000000000000000000007070707070707070707070700000
0888888b880000000888888b880000000888888b88000000888888880bb00bb00000000000000000000000000000000000007777777777777777777777770000
088888888800000008888888880000000888888888000000088888880000bbb00000000000000000000000000000000000000070707070707070707070700000
0008888888000000000888888800000000088888880000000d8888b8000bbb000000000000000000000000000000000000000707770777077707770777000000
000dd66666668880000dd66666668880000dd66666668880d6668888000bb0000000000000000000000000000000000000000070707070707070707070700000
000dd66666668800000dd66666668800000dd66666668800d666d880000bb0000000000000000000000000000000000000000077777777777777777777000000
000dd66666660000000dd66666660000000dd66666660000d66dd000000000000000000000000000000000000000000000000070707070707070707070000000
000ddddd00000000000ddddd00000000000ddddd00000000d66dd000000bb0000000000000000000000000000000000000000077777777777777777777000000
000ddddd00000000000ddddd00000000000ddddd00000000d88dd000000bb0000000000000000000000000000000000000000007770777077707770770000000
0000ddd0000000000005dddd00000000000dddd500000000088d0000000000000000000000000000000000000000000000000007777777777777777770000000
0000ddd000000000005555ddd000000000dddd55500000000ddd0000000000000000000000000000000000000000000000000007777777777777777770000000
0000ddd0000000000555500ddd8800000dddd005558800000ddd0000000000000000000000000000000000000000000000000000777777777777777700000000
00008888000000000855000dd880000008dd00055880000008888000000000000000000000000000000000000000000000000000777000000000077700000000
00008888800000000888800088000000088880008800000008888800000000000000000000000000000000000000000000000000700000000000000700000000
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
01080000051000510000000000000010000100000000000007100071000000000000001000010000000000000510005100000000000000100001000000000000071000710000000000000c1000c1000000000000
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
010c0000150521505215052150551805218052180521a0521a0521a0521a0521a055000000000000000180521a0521a0521d0511d0521a0521a0521a052180521805218052180551305215052150521505213055
010c0000150521505215052150551805218052180521a0521a0521a0521a0521a055000000000000000180551a0521a0521a0521a0551d0521d0521d052210522105221052210551d0521f0521f0521f0521d055
010c00201162018000000000000011625000000000011625116200000000000180001162500000000001162511620000001800011625116250000011600116200000000000000001162511625000000000011625
0110000010352103521035200002133521335213352000021535215352153520000213352003021535200002153520000215352003021a3520000218352000021735200002153521735217352000020000000000
010800001735217352173521735217352173521a300000001a3521a3521a3521a3521a3521a35200000000001c3521c3521c3521c3521c3521c35200000000001535215352000000000013352133520000000000
010800001a4501a450000000000015450154500000018450174501745000000004001345013450000000000013453134000000000000134530000000000000001345300000000000000000000000000000000000
01100010104531045300000104530e4530e453000000e4530c4530c453000000b453000000b4530b4530000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0110000015450000001545515450184500000015450000000000000000154500000017450000001845000000184500000018455184501c450000001845000000000000000018450000001a450000001c45000000
011000001d450000001d4551d45021450000001d4500000000000000001d450000001f4500000021450000001c450000001c4551c4501a450000001a4551a4501845000000184551845017450000001845000000
011000001545000000154551545018450000001545000000000000000018450000001745000000184500000015450154501545015450000000000015455154551545500000000000000000000000000000000000
010800081163000000000000000011635000001163500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01080000135521555117551185511a5511c5511d5511f55121552004021d552004021d55200502215522155200500005000050000500245520050021552005002155200500245522455200402004020040200000
0108000007552095520b5520c5520e552105521155213552155521555215552155521155211552155521555215552155521555215552185521855218552185521555215552185521855218552185520050200502
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000001855523555005050050500505005050050500505005050050500505005050050500505005050050500505005050050500505005050050500505005050050500505005050050500505005050050500505
011000001d6501d6551c4571a45718457174571545713455004050040500405004050040500405004050040500405004050040500405004050040500405004050040500405004050040500405004050040500405
010f0000134571545717457184571a4571c4550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010800002455026550285500050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500
010800002655028550295500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0108000028550295502b5500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01080000295502b5502d5500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010800002b5502d5502f5500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010800002d5502f550305500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010800002f55030550325500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010800003055030550305500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011400001f345000001c345000001f345000001c345003051f3401d3411c3311a3211831100305003050030500305003050030500305003050030500305003050030500305003050030500305003050000000000
011000000c65318553235530000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003
010c0000210531a053180530000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000000000000000
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
02 1a1b4344
00 0b050944
04 0c424344
04 0d0e4944
01 0f114044
02 10114044
00 12424344
00 13424344
04 14424344
00 15004344
00 16194344
00 17194344
04 18194344
00 0a424344

