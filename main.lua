ROT = require "rotLove.rotLove"
Class = require "hump.class"
GameState = require "hump.gamestate"
Vector = require "hump.vector"

map = {}
empties = {}
walls = {}
game = {}
target_mode = {}
game.objects = {}
hud = {}
collide = {}

ID_COUNTER = 0

function spawn(spawntype,x,y)
    obj = spawntype(x,y)
    game.objects[obj.id] = obj
end

function kill(id)
    game.objects[id]:die()
    game.objects[id] = nil
end

------------------------------------------------------------------------------------------
--- Singletons ---------------------------------------------------------------------------
------------------------------------------------------------------------------------------

collide = {
	list = {},
	register = function (obj_type,obj)
		if not collide.list[obj_type] then
			collide.list[obj_type] = {}
		end
        collide.list[obj_type][obj.id] = obj
	end,
    deregister = function (obj_type,obj)
        collide.list[obj_type][obj.id] = nil
    end,
	check = function (x,y,a,b_type,callback)
		for i, b in pairs(collide.list[b_type]) do
            if x == b.x and y == b.y then
                callback(a,b)
                print("hit "..b_type)
            end
        end
	end
}

hud = {
    list = {},
    registerDisplay = function(obj,prop,msg,x,y)
        table.insert(hud.list, {obj=obj,prop=prop,x=x,y=y,msg=msg,value=0})
    end,
    update = function()
        for i, item in ipairs(hud.list) do
            item.value = item.obj[item.prop]
        end
    end,
    draw = function()
		local message = ""
        for i, item in ipairs(hud.list) do
			message = string.gsub(item.msg,"%%p",item.obj[item.prop])
			f:write(message,item.x,item.y)
        end
    end
}

----------------------------------------------------------------------------------
---  Add-ons  --------------------------------------------------------------------
----------------------------------------------------------------------------------

Spawnable = Class{
    init = function (self)
        self.id = tostring(ID_COUNTER)
        ID_COUNTER = ID_COUNTER + 1
        return self.id
    end
}

Moveable = Class{
	move = function(self,dx,dy)
		self.prev = {x=self.x,y=self.y}
        if dx > 0 then
            self.x = math.min(80,self.x + dx)
        end
        if dx < 0 then
            self.x = math.max(1,self.x + dx)
        end
        if dy > 0 then
            self.y = math.min(22,self.y + dy)
        end
        if dy < 0 then
            self.y = math.max(1,self.y + dy)
        end
		if map[self.y][self.x] == "." then
		end
	end,
    moveTo = function(self,tx,ty,speed)
		self.prev = {x=self.x,y=self.y}
        d = Vector(tx - self.x, ty - self.y):normalized() * speed
        if d.x > 0 then
            self.x = math.min(self.x + d.x, tx)
        end
        if d.x < 0 then
            self.x = math.max(self.x + d.x, tx)
        end
        if d.y > 0 then
            self.y = math.min(self.y + d.y, ty)
        end
        if d.y < 0 then
            self.y = math.max(self.y + d.y, ty)
        end
        self.x, self.y = math.floor(self.x), math.floor(self.y)
    end,
	moveBack = function(self)
		self.x, self.y = self.prev.x, self.prev.y
	end
}

Mortal = Class{
    health = 0,
    init = function(self,health)
        self.health = health
    end,
    damage = function(self,dmg)
        self.health = self.health - dmg
        if self.health <= 0 then
            kill(self.id)
        end
    end
}

BugAI = Class{
	update = function(self)
		self.move(self,(math.random(0,2)-1)*5,(math.random(0,2)-1)*5)
		collide.check(self.x,self.y,self,"player",function(self,other)
		--	self.melee.attack(other)
			self.moveBack(self)
		end)
	end
}

TargetingAI = Class{
	update = function(self)
		for i, p in pairs(collide.list["player"]) do
            player = p
        end
        self.moveTo(self,player.x,player.y,3)
		collide.check(self.x,self.y,self,"player",function(self,other)
		 	--self.melee.attack(other)
			self.moveBack(self)
		end)
	end
}

-----------------------------------------------------------
--- Creatures ---------------------------------------------
-----------------------------------------------------------

Enemy = Class{
	init = function(self,x,y,health)
        Mortal.init(self, health)
		self.x = x
		self.y = y
		collide.register("enemy",self)
	end,
    die = function(self)
        collide.deregister("enemy",self)
    end
}
Enemy:include(Moveable)
Enemy:include(Mortal)

Goblin = Class{
	init = function(self,x,y)
        Spawnable.init(self)
		Enemy.init(self,x,y,5)
	end,
	draw = function(self)
		f:write("g",self.x,self.y)
	end
}
Goblin:include(TargetingAI)
Goblin:include(Enemy)
Goblin:include(Spawnable)

--------------------------------------------------------------------
--- Player ---------------------------------------------------------
--------------------------------------------------------------------

Player = Class{
    init = function(self,x,y)
		Mortal.init(self,100)
        Spawnable.init(self)
        self.x = x
        self.y = y
		self.points =  0
		self.name = "Herald"
        self.speed = 7
		self.power = 100
        self.walk = 1
        self.jump = 5
		collide.register("player",self)
        self.message = "Welcome to hell!"
		hud.registerDisplay(self, "name", "Name: %p", 1, 23)
		hud.registerDisplay(self, "health", "Health: %p", 30, 23)
		hud.registerDisplay(self, "power", "Power: %p", 43, 23)
		hud.registerDisplay(self, "message", "%p", 1, 24)
    end,
    update = function(self,x,y)
        if love.keyboard.isDown("lshift") then
            self.speed = self.walk
        else
            self.speed = self.jump
        end
        if love.keyboard.isDown("left") then
			Player.move(self,-self.speed,0)
        end
        if love.keyboard.isDown("up") then
			Player.move(self,0,-self.speed)
        end
        if love.keyboard.isDown("right") then
			Player.move(self,self.speed,0)
        end
        if love.keyboard.isDown("down") then
			Player.move(self,0,self.speed)
        end
        if love.keyboard.isDown("f") then
			GameState.switch(target_mode, self, function(c)
                collide.check(c.x,c.y,self,"enemy",function(self,other)
                    other:damage(5)
                end)
                self.power = self.power - 30
            end)
        end
		collide.check(self.x,self.y,self,"enemy",function(self,other)
            other.health = other.health - 1
            self.power = self.power - 10
			self.moveBack(self)
		end)
		if self.power < 100 then
			math.min(self.power + 3, 100)
		end
    end,
    draw = function(self)
        f:write("@",self.x,self.y)
    end
}
Player:include(Moveable)
Player:include(Spawnable)
Player:include(Mortal)

---------------------------------------------------------------------------------------------------
--- GameStates ------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------

function game:enter()
    for y = 1, 24 do
        if not map[y] then
            map[y] = {}
        end
        for x = 1, 80 do
            map[y][x] = "."
        end
    end
end

function game:keypressed()
    for i, obj in pairs(game.objects) do
        obj:update()
    end
	hud:update()
end

function game:draw()
    f:clear()
    local x, y = 0, 0
    for y, list in ipairs(map) do
        for x, cell in ipairs(map[y]) do
            f:write(map[y][x],x,y)
        end
    end
    for i, obj in pairs(game.objects) do
        obj:draw()
    end
	hud:draw()
    f:draw()
end

function target_mode:enter(previous, targeting, callback)
    self.targeting = targeting
    self.callback = callback
    self.cursor = {x=self.targeting.x,y=self.targeting.y}
end

function target_mode:keypressed()
    prev = {x=self.cursor.x,y=self.cursor.y}
    if love.keyboard.isDown("left") then
        self.cursor.x = self.cursor.x - 1
    end
    if love.keyboard.isDown("up") then
        self.cursor.y = self.cursor.y - 1
    end
    if love.keyboard.isDown("right") then
        self.cursor.x = self.cursor.x + 1
    end
    if love.keyboard.isDown("down") then
        self.cursor.y = self.cursor.y + 1
    end
    if love.keyboard.isDown("f") then
        self.callback(self.cursor)
        GameState.switch(game,self.cursor)
    end
    d = Vector(self.cursor.x - self.targeting.x, self.cursor.y - self.targeting.y)
    print(d:len())
    if d:len() > 6 then
        self.cursor.x = prev.x
        self.cursor.y = prev.y
    end
end

function target_mode:draw()
    game:draw()
    p = Vector(self.targeting.x,self.targeting.y)
    d = Vector(self.cursor.x - p.x, self.cursor.y - p.y):normalized()
    repeat
        if d.x > 0 then
            p.x = math.min(p.x + d.x, self.cursor.x)
        end
        if d.x < 0 then
            p.x = math.max(p.x + d.x, self.cursor.x)
        end
        if d.y > 0 then
            p.y = math.min(p.y + d.y, self.cursor.y)
        end
        if d.y < 0 then
            p.y = math.max(p.y + d.y, self.cursor.y)
        end
        if not (math.floor(p.x) == self.targeting.x and math.floor(p.y) == self.targeting.y) then
            f:write("*",math.floor(p.x),math.floor(p.y))
        end
    until math.floor(p.x) == self.cursor.x and math.floor(p.y) == self.cursor.y
    f:write("X",math.floor(p.x),math.floor(p.y))
    f:draw()
end

---------------------------------------------------------------------------------------------------
--- Initialize ------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------

function love.load()
    f = ROT.Display()
    spawn(Player,10,10)
    spawn(Goblin,30,12)
    GameState.registerEvents()
    GameState.switch(game)
end