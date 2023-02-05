-- Dont edit these
local world = {}
local particles = {}
local colorAttractions
local movespeedsum = 0
local xt, yt = 0, 0
-- Go crazy with these

local target_framerate = 60 -- Target framerate
local total_colors = 3; -- Amount of diffrent colors, upper limit is your imagination
local total_particles = 7000 -- How many particles to spawn
local spawn_grouped = true -- If true then spawn all the particles near the center of the world, otherwise spread them out across the world

-- Dont edit these
local w, h
local debug_render = false
local fast_rendering = false
local waterloop
local movesound
local camera
local zoomTarget = 1
local intro = true
local waterVol = 0
local bloomImage
local colors = {
    {1,0,0},
    {0,1,0},
    {0,0,1},
}
-- Dont edit these

function Lerp(a, b, t) -- Lerp value A to B with a step size of T
    return a + (b - a) * t
end

function Clamp(v, min, max) -- Clamp a value V between min and max
    if v < min then return min elseif v > max then return max else return v end
end

function CreateParticle(x,y,col) -- Create a particle at x,y set its color to col
    local newParticle = {x=x, y=y, col=col, velx=0, vely=0, gridspace={0,0}, indx = #particles+1}
    particles[#particles+1] = newParticle
    return newParticle
end

function InitWorld(sizex, sizey, cellSize) -- Self explanitory
    world.cellSize = cellSize;
    world.sizex = sizex;
    world.sizey = sizey;
    for x = 1, sizex do
        world[x] = {}
        for y = 1, sizey do
            world[x][y] = {}
        end
    end
    return world
end

function GetGridParticles(gridx, gridy) -- Returns the particles inside of the grid at (gridX,gridY)
    if gridx > world.sizex or gridx < 1 or gridy > world.sizey or gridy < 1 then
        local gxo, gyo


        if gridx > world.sizex then
            gxo = 1
        elseif gridx < 1 then
            gxo = world.sizex
        else
            gxo = gridx
        end

        if gridx > world.sizey then
            gyo = 1
        elseif gridx < 1 then
            gyo = world.sizey
        else
            gyo = gridy
        end

        return world[gxo][gyo], true -- true if mirroring
    end

    return world[gridx][gridy], false -- false otherwise
end

function Dist(ax, ay, bx, by) -- Distance between two points
    return math.sqrt(((bx - ax)^2) + ((by - ay)^2))
end


local areasToCheck = { -- Variable used to tell GetNearby what cells to look at relitive to the current position, add more if you want to search more cells!
    {-1,-1}, -- Top row
    {0,-1},
    {1,-1},

    {-1,0}, -- Middle row
    {0,0},
    {1,0},

    {-1, 1}, -- Bottom row
    {0,1},
    {1,1}

}


function InTable(tbl, val) -- returns true if value is within a table, false otherwise, Worst case of O(n)
    if tbl == nil then return false end
    if #tbl == 0 then return false end
    for key, value in pairs(tbl) do
        if value == val then
            return true
        end
    end
    return false
end

function GetNearby(curPart) -- Gets all particles in a 3x3 area around the current cell and returns them in a list
    local gridsToCheck = {}
    local mirrorChecks = {}
    local gridx, gridy = curPart.gridspace[1], curPart.gridspace[2]

    for i = 1, #areasToCheck do
        local inCell, mirror = GetGridParticles(gridx + areasToCheck[i][1], gridy + areasToCheck[i][2])
        if inCell ~= nil then
            gridsToCheck[#gridsToCheck+1] = inCell
            mirrorChecks[#gridsToCheck] = mirror
        end 
    end

    local particleIndexes = {}
    local mirrorIndexes = {}
    for i = 1, #gridsToCheck do
        for _, partIndx in pairs(gridsToCheck[i]) do
            if(partIndx ~= curPart.indx) then
                particleIndexes[#particleIndexes+1] = partIndx
                mirrorIndexes[#particleIndexes] = mirrorChecks[i]
            end
        end
    end
    return particleIndexes, mirrorIndexes
end

function GetInCell(curPart)
    local myGrid = GetGridParticles(curPart.gridspace[1], curPart.gridspace[2])

    local particleIndexes = {}

    for _, partIndx in pairs(myGrid) do
        if(partIndx ~= curPart.indx) then
            particleIndexes[#particleIndexes+1] = partIndx
        end
    end

    if #myGrid == 0 then
        return nil -- only i am in this cell
    end

    return particleIndexes
end

function FindClosest(curParticle, colFilter, indxFilter) -- finds closest in a 3x3 area around current cell, you can set a color filter and exclude certin indexes from the search
    local cx, cy = curParticle.x, curParticle.y
    local gridsToCheck = {}
    local indxFilter = indxFilter or nil
    local gridx, gridy = curParticle.gridspace[1], curParticle.gridspace[2]
    for i = 1, #areasToCheck do
        gridsToCheck[#gridsToCheck+1] = GetGridParticles(gridx + areasToCheck[i][1], gridy + areasToCheck[i][2])
    end
    
    local particlesToCheck = {}
    for _, grid in pairs(gridsToCheck) do
        for _, particleIndx in pairs(grid) do
            particlesToCheck[#particlesToCheck+1] = particleIndx
        end
    end

    local iterMax = 50 -- just in case there is a metric fuck ton of particles to check in nearby cells
    local iters = 0
    local closestDist = 99999999
    local closestIndx = -1
    for _, indx in pairs(particlesToCheck) do
        local part = particles[indx]
        if(indx ~= curParticle.indx and not InTable(indxFilter, indx)) then
            local cdist = Dist(cx, cy, part.x, part.y)
            if colFilter == -1 then
                if cdist < closestDist then
                    closestDist = cdist
                    closestIndx = indx
                end
            else
                if part.col == colFilter then
                    if cdist < closestDist then
                        closestDist = cdist
                        closestIndx = indx
                    end
                end
            end
        end
        if iters == iterMax then
            break
        end
    end
    return closestDist, closestIndx
end

function EmptyWorld()
    local sx = world.sizex
    local sy = world.sizey
    local cellSize = world.cellSize
    world = {}
    world.sizex = sx
    world.sizey = sy
    world.cellSize = cellSize
    for x = 1, world.sizex do
        world[x] = {}
        for y = 1, world.sizey do
            world[x][y] = {}
        end
    end
end

function RebuildWorldGrid()
    EmptyWorld()
    for key, value in pairs(particles) do
        local wx, wy = world.sizex*world.cellSize, world.sizey*world.cellSize
        local posx, posy = 0, 0 
        for _ = 1, 2 do -- Bodge fix
            if(value.x >= wx-2) then
                value.x = 2
            elseif(value.x <= 1) then
                value.x = wx-4
            elseif (value.y >= wy-2) then
                value.y = 2
            elseif (value.y <= 1) then
                value.y = wy-4
            end
        end
        
        local posx = math.floor((value.x+0.000001) / world.cellSize) + 1
        local posy = math.floor((value.y+0.000001) / world.cellSize) + 1

        if(world[posx] == nil or world[posx][posy] == nil) then
            -- if posx or posy is nill, there is no point to continue anymore since something is fucked BAD
            print("bruh")
            os.exit()
            print(posx, value.x)
            print(posy, value.y)
        end

        value.gridspace = {posx, posy}
        table.insert(world[posx][posy], key)
    end
end

function Normalize(vx, vy)
    local mag = math.sqrt((vx ^ 2) + (vy ^ 2)) + 0.0000000001
    return ((vx+0.00000001)/mag), ((vy+0.00000001)/mag)
end

function DistFalloff(curPart, partIndx, dist) -- Wow thats, huh
    local minDist = 6
    local maxDist = world.cellSize
    local maxSpeed = 1 -- Normalized Speed

    local dirx = (particles[partIndx].x - curPart.x)
    local diry = (particles[partIndx].y - curPart.y)
    local collision = false
    dirx, diry = Normalize(dirx, diry)
    
    local speed = 0
    if dist < minDist then
        speed = math.log(dist/minDist)*10
        collision = true
    elseif dist < maxDist then
        -- https://www.desmos.com/calculator/9kugwpwwwo

        -- local a = -dist + (minDist + maxDist)
        -- local b = dist - maxDist
        -- local f = math.min(a, b)
        -- local l = math.max(0,f)

        -- speed = (l/(maxSpeed/2)) * maxSpeed
        local collisionSpeed = math.min(math.log(dist/minDist),0)
        speed = collisionSpeed + (math.max(0, math.min(dist - minDist, -dist + (minDist + maxDist))) / (maxDist/2))
    else
        return 0, 0
    end
    return dirx * speed, diry * speed, collision -- Returns a normalized vector in the direction of the target particle based on distance
end

function boundParticle(curPart)
    if curPart.x > world.cellSize * world.sizex then
        curPart.x = world.cellSize * world.sizex
        curPart.velx = -curPart.velx
    end
    if curPart.x < 0 then
        curPart.x = 0
        curPart.velx = -curPart.velx
    end

    if curPart.y > world.cellSize * world.sizey then
        curPart.y = world.cellSize * world.sizey
        curPart.vely = -curPart.vely
    end
    if curPart.y < 0 then
        curPart.y = 0
        curPart.vely = -curPart.vely
    end
end

function GetDelta() -- just in case i want to mell with this later
    return love.timer.getDelta()
end

function mirror(gx, gy)
    local ox, oy = gx, gy
    if gx == world.sizex then
        ox = -world.sizex
    end
    if gx == 1 then
        ox = world.sizex-1
    end
    if gy == world.sizey then
        oy = -world.sizey
    end
    if gy == 1 then
        oy = world.sizey-1
    end
    return ox, oy
end


function SimulationRoutine(from, to, maxTime)
    local lastTime = love.timer.getTime()

    for pr = from+1, to do
        local curPart = particles[pr]
        local particlesFound, mirrors = GetNearby(curPart)
        local iterCount = #particlesFound

        for i = 1, iterCount do

            local partIndx = particlesFound[i]
            local targPart = particles[partIndx]
            local dist

            if mirrors[i] == true then
                local ofx, ofy = mirror(targPart.gridspace[1], targPart.gridspace[2])

                ofx, ofy = ofx * world.cellSize, ofy * world.cellSize

                dist = Dist(curPart.x, curPart.y, targPart.x + ofx, targPart.y + ofy)
            else
                dist = Dist(curPart.x, curPart.y, targPart.x, targPart.y)
            end


            local tx, ty, colision = DistFalloff(curPart, partIndx, dist)

            local attractValue = colorAttractions[curPart.col][targPart.col]
            if not colision then
                curPart.velx = curPart.velx + (tx * attractValue) -- atract
                curPart.vely = curPart.vely + (ty * attractValue)
            else
                curPart.velx = curPart.velx + tx * 3 -- Collision code
                curPart.vely = curPart.vely + ty * 3
            end
        end

        if love.timer.getTime() - lastTime >= maxTime then
            coroutine.yield()
            lastTime = love.timer.getTime()
        end
    end
end

local threadA = coroutine.create(SimulationRoutine)

local doneCounter = 0

function UpdateParticles()
    if coroutine.status(threadA) == "suspended" then
        coroutine.resume(threadA, 0, #particles, 1/target_framerate) -- Loop over all particles and only yeild if its been more than the time (currently set to 60 fps)
    end
    if coroutine.status(threadA) == "dead" then
        doneCounter = 1
    end    

    if(doneCounter == 1) then
        RebuildWorldGrid()
        threadA = coroutine.create(SimulationRoutine)

        for _, curPart in pairs(particles) do
            curPart.x = curPart.x + (curPart.velx * GetDelta())
            curPart.y = curPart.y + (curPart.vely * GetDelta())
    
            local drag = (0.5 * 0.1)*((curPart.velx^2 + curPart.vely^2)/2) + 0

            local nx, ny = Normalize(curPart.velx, curPart.vely)

            curPart.velx = curPart.velx - nx
            curPart.vely = curPart.vely - ny

            curPart.x = Clamp(curPart.x, 1, (world.cellSize * world.sizex)-1)
            curPart.y = Clamp(curPart.y, 1, (world.cellSize * world.sizey)-1)
        end
        doneCounter = 0
    end
end

function RandomizeAttractions(cMax)
    colorAttractions = {}
    for i = 1, cMax do
        colorAttractions[i] = {}
        for b = 1, cMax do
            table.insert(colorAttractions[i], math.random(-1000, 1000) * 0.001)
        end
    end
end

function MassSetAttractions(setTo)
    colorAttractions = {}
    for i = 1, total_colors do
        colorAttractions[i] = {}
        for b = 1, total_colors do
            table.insert(colorAttractions[i], setTo)
        end
    end
end

function AddSum(curPart)
    movespeedsum = movespeedsum + (math.abs(curPart.velx) + math.abs(curPart.vely))
end

-- http://lua-users.org/wiki/SimpleRound
function Round(num, numDecimalPlaces)
    return tonumber(string.format("%." .. (numDecimalPlaces or 0) .. "f", num))
end

function WithinRadius(circleX, circleY, x, y, r)
    return math.sqrt(( (y-circleY)^2 )+ ( (x-circleX)^2 )) <= r
end

function love.mousemoved(x, y, dx, dy)
    if love.mouse.isDown(1) then
        xt = xt + dx
        yt = yt + dy
    end
end

function love.wheelmoved(x, y)
    zoomTarget = zoomTarget + (y * 0.05)
end

function love.load()
    love.window.setMode(100, 100, {msaa=4,fullscreen = true});
    love.window.setTitle("Particle Life 2")
    love.window.setPosition(0,0,0)

    math.randomseed(os.clock() + 25012)
    math.random(math.random(-500,500))

    bloomImage = love.graphics.newImage("bloom.png")
    waterloop = love.audio.newSource("waterloop.wav", "stream")
    movesound = love.audio.newSource("movingsound.wav", "stream")

    waterloop:setVolume(0)
    waterloop:play()
    waterloop:setLooping(true)

    movesound:setVolume(0)
    movesound:play()
    movesound:setLooping(true)
    movesound:setPitch(1.5)

    MassSetAttractions(-1)

    -- Generate extra colors if needed
    if total_colors > 3 then
        for i = 4, total_colors, 1 do
            colors[i] = {0.1+math.random(), 0.1+math.random(), 0.1+math.random()}
        end
    end

    w, h = love.graphics.getWidth(), love.graphics.getHeight()

    InitWorld(math.ceil(w/50)*2, math.ceil(h/50)*2, 50)
    --InitWorld(6,6,50)

    for i=1, total_particles do
        local col = math.random(1,total_colors)
        if spawn_grouped then
            --Create in center
            CreateParticle(Clamp(w/2 + math.random(1, w)+math.random(),1, world.cellSize * world.sizex), Clamp(h/2 + math.random(1, h)+math.random(),1, world.cellSize * world.sizey), col)
        else
            -- just fill
            CreateParticle(math.random(1, world.cellSize*world.sizex)+math.random(), math.random(1, world.cellSize*world.sizey)+math.random(), col)
        end
    end

    RebuildWorldGrid()
    UpdateParticles()

    local wW, wH = world.cellSize*world.sizex, world.cellSize*world.sizey

    camera = {x=-wW/2, y=-wH/2, zoom=1}

    xt, yt = -wW/2, -wH/2

    for i = 1, 20, 1 do
        RebuildWorldGrid()
        UpdateParticles()
    end
end

function love.update()
    if intro == true then
        movesound:stop()
        waterVol = waterVol + (0.05 * love.timer.getDelta())
        if(waterVol >= 0.2) then
            intro = false
            waterVol = 0.2
            movesound:play()
        end
        waterloop:setVolume(waterVol)
    end

    UpdateParticles()

    movesound:setVolume(0.15 * (movespeedsum/#particles)/30)
end

function ToScreenSpace(x, y, s) -- x y and an optional scale component
    if s ~= nil then
        return -camera.x + x, -camera.y + y, s/camera.zoom
    end
    return -camera.x + x, -camera.y + y
end

function love.draw()
    local mx, my = love.mouse.getPosition()
    movespeedsum = 0

    zoomTarget = Clamp(zoomTarget, 0.2, 100)

    camera.zoom = Lerp(camera.zoom, zoomTarget, 4 * love.timer.getDelta())

    if camera.zoom < 0.325 then
        fast_rendering = true
    else
        fast_rendering = false
    end

    camera.x = Lerp(camera.x, xt, love.timer.getDelta())
    camera.y = Lerp(camera.y, yt, love.timer.getDelta())

    love.graphics.scale(camera.zoom, camera.zoom)
    love.graphics.translate(camera.x + w/2/camera.zoom, camera.y + h/2/camera.zoom)

    local w, h = world.sizex * world.cellSize, world.sizey * world.cellSize

    -- Background
    love.graphics.print("Test", mx, my)

    love.graphics.setColor(0.05,0.05,0.07)
    love.graphics.rectangle("fill", 0, 0, w, h)
    love.graphics.setColor(1,1,1)

    if debug_render then
        for _, curPart in pairs(particles) do
            AddSum(curPart)
            if curPart.velx ~= 0 or curPart.vely ~= 0 then
                love.graphics.setColor(1,0,0)
                love.graphics.line(curPart.x, curPart.y, curPart.x + curPart.velx, curPart.y + curPart.vely)
            else
                love.graphics.setColor(1,1,1)
            end
            love.graphics.circle("fill", curPart.x, curPart.y, 2)
            love.graphics.setColor(1,1,1,1)

            love.graphics.print(zoomTarget, ToScreenSpace(0,0))

            local vel = "VelX:"..Round(curPart.velx,1).." VelY:"..Round(curPart.vely,1)
            local col = "Color: "..curPart.col
            local pos = "X:"..Round(curPart.x,1).." Y:"..Round(curPart.y,1)

            if(WithinRadius(-camera.x, -camera.y, curPart.x, curPart.y, Clamp(300/camera.zoom, 100, 700))) then
                love.graphics.print(pos, curPart.x - #pos/2, curPart.y+9, 0, 0.2, 0.2)
                love.graphics.print(vel, curPart.x - #vel/2, curPart.y+3, 0, 0.2, 0.2)
                love.graphics.print(col, curPart.x - #col/2, curPart.y+6, 0, 0.2, 0.2)
            end
        end
        for x = 1, world.sizex do
            for y = 1, world.sizey do
                if #world[x][y] > 0 then
                    love.graphics.setColor(0,1,0, 0.15)
                else
                    love.graphics.setColor(1,1,1, 0.1)
                end

                love.graphics.rectangle("line", (x-1)*world.cellSize, (y-1)*world.cellSize, world.cellSize, world.cellSize)
            end
        end
    elseif fast_rendering == false then
        -- for _, curPart in pairs(particles) do
        --     local bloomSteps = 2
        --     local bloomSize = 12
        --     local bloomMax = 0.07

        --     if zoomTarget < 0.8 then
        --         bloomSteps = 2
        --     end
        --     if zoomTarget < 1 then
        --         bloomSteps = 3
        --     end
        --     if zoomTarget > 1 then
        --         bloomSteps = 4
        --     end
            
        --     local bloomPer = bloomMax/bloomSteps

        --     for b = 1, bloomSteps do
        --         love.graphics.setColor(colors[curPart.col][1], colors[curPart.col][2], colors[curPart.col][3], bloomPer)
        --         love.graphics.circle("fill", curPart.x, curPart.y, 3 + ((bloomSize/bloomSteps)*(b)))
        --     end
        -- end

        local bloomSize = 0.035

        for _, curPart in pairs(particles) do
            love.graphics.setColor(colors[curPart.col][1], colors[curPart.col][2], colors[curPart.col][3], 0.5)
            love.graphics.draw(bloomImage, curPart.x - (bloomImage:getWidth()/2)*bloomSize , curPart.y - (bloomImage:getHeight()/2)*bloomSize, 0, bloomSize, bloomSize)
        end


        for _, curPart in pairs(particles) do -- Fancy fancy rendering, cool blur at distances and stuffs
            AddSum(curPart)
            local alpha = Clamp(Dist(curPart.x, curPart.y, -camera.x, -camera.y) * 0.0002,0,1) * 5
            if(alpha > 0) then
                love.graphics.setColor(colors[curPart.col][1], colors[curPart.col][2], colors[curPart.col][3], 1 - alpha)
                love.graphics.circle("fill", curPart.x, curPart.y, 3)
            end
        end
        love.graphics.setColor(0,0,0,1)

        local bs = 15

        love.graphics.rectangle("fill", -bs, 0, w+bs*2, -bs)

        love.graphics.rectangle("fill", -bs, 0, bs, h+bs)

        love.graphics.rectangle("fill", -bs, h, w+bs*2, bs)

        love.graphics.rectangle("fill", w, 0, bs, h)

        for bs = 1, 10 do
            love.graphics.setColor(0,0,0,0.1)
            love.graphics.rectangle("fill", 0, 0, w, bs)
            love.graphics.rectangle("fill", 0, bs, bs, h-(bs*2))
            love.graphics.rectangle("fill", 0, h-bs, w, bs)
            love.graphics.rectangle("fill", w-bs, bs, bs, h-(bs*2))
        end

    else
        for _, curPart in pairs(particles) do
            AddSum(curPart)
            love.graphics.setColor(colors[curPart.col][1], colors[curPart.col][2], colors[curPart.col][3], 1)
            love.graphics.points(curPart.x, curPart.y)
        end
        love.graphics.setColor(1,1,1,1)
    end
    love.graphics.setColor(1,1,1,1)
end

function love.keypressed(key, scancode, isrepeat)
    if key == "escape" then
        os.exit()
    end
    if key == "space" and not isrepeat then
        RandomizeAttractions(total_colors)
    end
    if key == "1" and not isrepeat then
        debug_render = not debug_render
    end
    if key == "r" then
        MassSetAttractions(-1)
    end
end