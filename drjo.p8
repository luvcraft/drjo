pico-8 cartridge // http://www.pico-8.com
version 27
__lua__
-- dr jo
-- by luvcraft

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
function inrange(num,min,max)
	max = max or 0
	
	if(min < max) do
		return num >= min and num <= max
	else
		return num <= min and num >= max
	end
end

-- constants
boulder_fall_state = 8
boulder_break_state = 10
max_spr_x = 120
max_spr_y = 120

debug_text = ""

-->8
-- characters

hero = {
	x=64, 
	y=64, 
	facing=1,
	speed=1,
 
	update = function(self)
		if (btn(0)) then
			self:move(3)
		elseif (btn(1)) then 
			self:move(1)
		elseif (btn(2)) then
			self:move(0)
		elseif (btn(3)) then
			self:move(2)
		end
		
		if(btnp(🅾️) or btnp(❎)) then 
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

		b = self:boulder_check(self.facing)
		speed = self.speed
		pushing_speed = self.speed * 0.7
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
	
	-- check to see if there's a boulder or wall immediately in the specified direction
	-- returns 0 for no boulder, 1 for blocked, and the boulder if it's pushable
	boulder_check = function(self,dir)
		if(dir==0) then
			if(self.y<=0) then
				return 1
			else
				for b in all(boulder) do
					if(self.x==b.x and inrange( self.y - b.y,8)) then
						if(b:blocked(dir) !=0 or b.state > 0) then
							return 1
						else
							return b
						end
					end
				end
			end
		elseif(dir==1) then
			if(self.x>=max_spr_x) then
				return 1
			else
				for b in all(boulder) do
					if(self.y==b.y and inrange( b.x - self.x,8)) then
						if(b:blocked(dir) !=0 or b.state > 0) then
							return 1
						else
							return b
						end
					end
				end
			end
		elseif(dir==2) then
			if(self.y>=max_spr_y) then
				return 1
			else
				for b in all(boulder) do
					if(self.x==b.x and inrange(b.y - self.y,8)) then
						if(b:blocked(dir) !=0 or b.state > 0) then
							return 1
						else
							return b
						end
					end
				end
			end
		elseif(dir==3) then
			if(self.x<=0) then
				return 1
			else
				for b in all(boulder) do
					if(self.y==b.y and inrange( self.x - b.x,8)) then
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
	end,
	 
	draw = function(self)
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
	end
}

-- behavior for the bomb
bomb = {
	state = 0,
	cooldown = 0,
	next_cooldown = 30,
	
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
		
		for b in all(boulder) do
			if(abs(self.x * 8 - b.x) <= 8 and abs(self.y * 8 - b.y) <= 8) then
				b.state = boulder_break_state
			end
		end
		
		self.state = 2
	end,
	
	draw = function(self)
		if(self.state == 0) then
			if(self.cooldown <= 0) then
				-- if bomb is available, draw bomb at 0,0
				spr(23,0,0)
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

-- prototype behavior for boulders
boulder_proto = {
	state = 0,
	
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
			
			if(mget(self.x/8,self.y/8 + 1) != 0) then
				-- falling boulder hit ground
				self.y -= (self.y % 8)
				if(self.y - self.starting_y > 8) then
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
					if(self != b and self.x==b.x and inrange( self.y - b.y,8)) then
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
					if(self != b and self.y==b.y and inrange( b.x - self.x,8)) then
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
					if(self != b and self.x==b.x and inrange(b.y - self.y,8)) then
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
					if(self != b and self.y==b.y and inrange( self.x - b.x,8)) then
						self.x = roundtonearest(self.x, 8)
						return b
					end
				end
			end
		end
		
		return 0
	end,
	
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

-->8
-- main functions

function _init()
	-- init boulders
	boulder = {}
	add(boulder,boulder_proto:instantiate(5,1))
	add(boulder,boulder_proto:instantiate(10,1))
end

function _update()
	bomb:update()
	hero:update()
	
	-- clear the block under the hero
	local herox = roundtonearest(hero.x,8)/8
	local heroy = roundtonearest(hero.y,8)/8
	mset(herox,heroy,0)
	
	for b in all(boulder) do
		b:update()
	end
	
end

function _draw()
	pal(5,0)
	map(16)
	pal()
	map()
	
	bomb:draw()
	hero:draw()
	
	for b in all(boulder) do
		b:draw()
	end
	
	print(debug_text,0,0)
--	print("x = "..hero.x.." y = "..hero.y,0,0)
end

__gfx__
0000000055555555009999000099990000999900009999000099990000999900009999000099990000e22e000000000000000000000000000000000000000000
00000000335333330999999009999990009f3f00009f3f00009f3f00009f3f00093ff390093ff39000eeee000000000000000000000000000000000000000000
00700700335333330999999009999990009fff00009fff00009fff00009fff0009ffff9009ffff90ee2222ee0000000000000000000000000000000000000000
00077000335333330999999009999990009ee000009ee000009ee000009ee00009eeee9009eeee90eeeeeeee0000000000000000000000000000000000000000
00077000555555550eeeeee00eeeeee000eeef0000eeef0000efe00000efe0000eeeeee00eeeeee0000000000000000000000000000000000000000000000000
00700700333335330feeeef00feeeef000efe00000efe00000eeef0000eeef000feeeef00feeeef0000000000000000000000000000000000000000000000000
000000003333353300eeee0000e44e0000eee0000eee4e0000eee0000eeeee0000eeee0000e44e00000000000000000000000000000000000000000000000000
000000003333353300e44e000000ee0000eeee000ee44ee000eeee000ee44ee000e44e000000ee00000000000000000000000000000000000000000000000000
00000000555511110049940000049940000004940000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000111155550499994000499994000049940440000000000000005555000000000000000000000000000000000000000000000000000000000000000000
000000001111111104a99a40004a999400004a944945000000000000056655500000000000000000000000000000000000000000000000000000000000000000
000000001111111149999994049999a40004999449a4500045555554056555500000000000000000000000000000000000000000000000000000000000000000
00000000555511119aaaaaa909aa99940009aaa4499945009999a9a9055555500000000000000000000000000000000000000000000000000000000000000000
0000000011115555499999940499aaa900049994049a944049a9a9a9055555500000000000000000000000000000000000000000000000000000000000000000
00000000111111119aaaaaa909aa99940009aaa404a9a9400449a9a4005555000000000000000000000000000000000000000000000000000000000000000000
0000000011111111049999400049aa4000004994000a440000049490000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0101010101010101010101010101010111111111111111111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010111111111111111111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010111111111111111111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010111111111111111111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010111111111111111111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010111111111111111111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010111111111111111111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010111111111111111111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010111111111111111111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010111111111111111111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010111111111111111111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010111111111111111111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010111111111111111111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010111111111111111111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010111111111111111111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010111111111111111111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
