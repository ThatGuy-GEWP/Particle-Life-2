-- Dont edit these
local world = {}
local particles = {}
local colorAttractions
local movespeedsum = 0
local xt, yt = 0, 0
-- Go crazy with these

local time_scale = 4; -- Time scale, dont go to crazy with this one as it will break everything
local total_colors = 6; -- Amount of diffrent colors, upper limit is your imagination
local total_particles = 8000 -- How many particles to spawn
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
        -- returning nil here since the only way this is happening is when check nearby looks outside of bounds.
        return nil
    end

    return world[gridx][gridy]
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
    local gridx, gridy = curPart.gridspace[1], curPart.gridspace[2]

    for i = 1, #areasToCheck do
        gridsToCheck[#gridsToCheck+1] = GetGridParticles(gridx + areasToCheck[i][1], gridy + areasToCheck[i][2])
    end

    local particleIndexes = {}
    for i = 1, #gridsToCheck do
        for _, partIndx in pairs(gridsToCheck[i]) do
            if(partIndx ~= curPart.indx) then
                particleIndexes[#particleIndexes+1] = partIndx
            end
        end
    end
    return particleIndexes
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
        local posx = math.floor((value.x-0.9) / world.cellSize) + 1
        local posy = math.floor((value.y-0.9) / world.cellSize) + 1

        value.gridspace = {posx, posy}
        table.insert(world[posx][posy], key)

        -- replace above code with below code if this function starts giving you issues
        -- local wx, wy = world.sizex*world.cellSize, world.sizey*world.cellSize
        -- local posx, posy = 0, 0 
        -- for _ = 1, 2 do -- Bodge fix
        --     if(value.x > wx-1) 
        --         value.x = 1
        --     elseif(value.x < 1) then
        --         value.x = wx-2
        --     elseif (value.y > wy-1) then
        --         value.y = 1
        --     elseif (value.y < 1) then
        --         value.y = wy-2
        --     end
        -- end
        --
        -- local posx = math.floor((value.x-0.9) / world.cellSize) + 1
        -- local posy = math.floor((value.y-0.9) / world.cellSize) + 1

        -- value.gridspace = {posx, posy}
        -- table.insert(world[posx][posy], key)
    end
end


function Normalize(vx, vy)
    local mag = math.sqrt((vx ^ 2) + (vy ^ 2))
    return (vx/mag), (vy/mag)
end

function distFalloff(curPart, partIndx, dist) -- Wow thats, huh
    local minDist = 8
    local maxDist = world.cellSize
    local maxSpeed = 1 -- Normalized Speed

    local dirx = (particles[partIndx].x - curPart.x)
    local diry = (particles[partIndx].y - curPart.y)
    local collision = false
    dirx, diry = Normalize(dirx, diry)
    
    local speed = 0
    if dist < minDist then
        speed = dist - minDist
        collision = true
    elseif dist < maxDist then
        -- https://www.desmos.com/calculator/9kugwpwwwo

        -- local a = -dist + (minDist + maxDist)
        -- local b = dist - maxDist
        -- local f = math.min(a, b)
        -- local l = math.max(0,f)

        -- speed = (l/(maxSpeed/2)) * maxSpeed
    
        speed = (math.abs(math.max(0, math.min(dist - minDist, -dist + (minDist + maxDist))))/(maxDist/2))*maxSpeed
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

function getDelta()
    return love.timer.getDelta()
end


function newRoutine(from, to, yeildAmount)
    local yeildAmount = yeildAmount or 500
    local curYeildAmount = 0
    for pr = from+1, to do
        local curPart = particles[pr]
        local particlesFound = GetNearby(curPart)
        local iterCount = #particlesFound

        for i = 1, iterCount do
            local partIndx = particlesFound[i]
            local targPart = particles[partIndx]

            local dist = Dist(curPart.x, curPart.y, targPart.x, targPart.y)
            local tx, ty, colision = distFalloff(curPart, partIndx, dist)

            local attractValue = colorAttractions[curPart.col][targPart.col]
            if not colision then
                curPart.velx = curPart.velx + (tx * attractValue) -- atract
                curPart.vely = curPart.vely + (ty * attractValue)
            else
                curPart.velx = curPart.velx + tx * 1 -- Collision code
                curPart.vely = curPart.vely + ty * 1
            end
        end

        curYeildAmount = curYeildAmount + 1
        if curYeildAmount == yeildAmount then
            coroutine.yield()
            curYeildAmount = 0
        end
    end
end



local threadA = coroutine.create(newRoutine)
local threadB = coroutine.create(newRoutine)
local threadC = coroutine.create(newRoutine)
local threadD = coroutine.create(newRoutine)

local doneCounter = 0

function UpdateParticles()
    local maxSpeed = 4
    local maxEffectors = 150
    local yeildTarget = total_particles/4

    local splitAmount = (total_particles/4)-1

    if coroutine.status(threadA) == "suspended" then
        coroutine.resume(threadA, 0, splitAmount, yeildTarget)
    end
    if coroutine.status(threadA) == "dead" then
        doneCounter = doneCounter + 1
    end    

    if coroutine.status(threadB) == "suspended" then
        coroutine.resume(threadB, splitAmount, splitAmount*2, yeildTarget)
    end
    if coroutine.status(threadB) == "dead" then
        doneCounter = doneCounter + 1
    end    

    if coroutine.status(threadC) == "suspended" then
        coroutine.resume(threadC, splitAmount*2, splitAmount*3, yeildTarget)
    end
    if coroutine.status(threadC) == "dead" then
        doneCounter = doneCounter + 1
    end    

    if coroutine.status(threadD) == "suspended" then
        coroutine.resume(threadD, splitAmount*3, splitAmount*4, yeildTarget)
    end
    if coroutine.status(threadD) == "dead" then
        doneCounter = doneCounter + 1
    end    

    if(doneCounter == 4) then
        RebuildWorldGrid()
        threadA = coroutine.create(newRoutine)
        threadB = coroutine.create(newRoutine)
        threadC = coroutine.create(newRoutine)
        threadD = coroutine.create(newRoutine)

        for _, curPart in pairs(particles) do
            curPart.x = curPart.x + (curPart.velx * getDelta())
            curPart.y = curPart.y + (curPart.vely * getDelta())
    
            curPart.velx = curPart.velx + (((curPart.velx) * -1) * getDelta()) -- drag code
            curPart.vely = curPart.vely + (((curPart.vely) * -1) * getDelta())

            curPart.x = Clamp(curPart.x, 1, world.cellSize * world.sizex)
            curPart.y = Clamp(curPart.y, 1, world.cellSize * world.sizey)
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

function love.mousemoved(x, y, dx, dy)
    if love.mouse.isDown(1) then
        xt = xt + dx
        yt = yt + dy
    end
end

function love.wheelmoved(x, y)
    zoomTarget = zoomTarget + (y * 0.125)
end

function love.load()
    love.window.setMode(100, 100, {msaa=4,fullscreen = true});
    love.window.setTitle("Particle Life 2")
    love.window.setPosition(0,0,0)

    math.randomseed(os.clock() + 25012)
    math.random(math.random(-500,500))

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
    UpdateParticles()

    local wW, wH = world.cellSize*world.sizex, world.cellSize*world.sizey

    camera = {x=-wW/2, y=-wH/2, zoom=1}

    xt, yt = -wW/2, -wH/2


    for i = 1, 20, 1 do
        UpdateParticles()
        RebuildWorldGrid()
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

function love.draw()
    local mx, my = love.mouse.getPosition()
    movespeedsum = 0

    zoomTarget = Clamp(zoomTarget, 0.2, 100)

    camera.zoom = Lerp(camera.zoom, zoomTarget, 4 * love.timer.getDelta())

    if camera.zoom < 0.4 and debug_render == false then
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
        for _, curPart in pairs(particles) do
            local bloomSteps = 2
            local bloomSize = 12
            local bloomMax = 0.07

            if zoomTarget < 0.8 then
                bloomSteps = 1
                bloomSize = 8
            end
            if zoomTarget < 1 then -- Gods greatest LOD system i swear
                bloomSteps = 2
            end
            if zoomTarget > 1 then
                bloomSteps = 3
            end
            if zoomTarget > 2 then
                bloomSteps = 4
            end
            if zoomTarget > 4 then
                bloomSteps = 5
            end
            
            local bloomPer = bloomMax/bloomSteps

            for b = 1, bloomSteps do
                love.graphics.setColor(colors[curPart.col][1], colors[curPart.col][2], colors[curPart.col][3], bloomPer)
                love.graphics.circle("fill", curPart.x, curPart.y, 3 + ((bloomSize/bloomSteps)*(b)))
            end
        end

        for _, curPart in pairs(particles) do
            AddSum(curPart)
            love.graphics.setColor(colors[curPart.col][1], colors[curPart.col][2], colors[curPart.col][3], 1)
            love.graphics.circle("fill", curPart.x, curPart.y, 3)
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
end

function love.keypressed(key, scancode, isrepeat)
    if key == "escape" then
        os.exit()
    end
    if key == "space" and not isrepeat then
        print("Randomizing Color attractions!")
        RandomizeAttractions(total_colors)
        print(colorAttractions[1][1])
        resetAndStuffs = false
    end
    if key == "1" and not isrepeat then
        debug_render = not debug_render
    end
    if key == "r" then
        MassSetAttractions(-1)
    end
end