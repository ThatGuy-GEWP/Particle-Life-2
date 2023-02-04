local world = {}
local particles = {}
local colorsMax = 4;

local colorAttractions

function randomizeAttractions()
    for i = 1, colorsMax do
        colorAttractions[i] = {}
        for b = 1, colorsMax do
            table.insert(colorAttractions[i], math.random(-1000, 1000) * 0.001)
        end
    end
end

function createParticle(x,y,col)
    local newParticle = {x=x, y=y, col=col, velx=0, vely=0, gridspace={0,0}, indx = #particles+1}
    particles[#particles+1] = newParticle
    return newParticle
end

function initWorld(sizex, sizey, cellSize)
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

function getCellParticles(gridx, gridy)
    local nx = gridx
    local ny = gridy

    if gridx > world.sizex then
        nx = 1
    end

    if gridx < 1 then
        nx = world.sizex
    end

    if gridy > world.sizey then
        ny = 1
    end

    if gridy < 1 then
        ny = world.sizey
    end

    return world[nx][ny]
end

function Dist(ax, ay, bx, by)
    return math.sqrt(((bx - ax)^2) + ((by - ay)^2))
end

function ToWorldPos(x,y)
    return math.floor(x / world.cellSize) + 1, math.floor(y / world.cellSize) + 1
end

function SplitStr (inputstr, sep)
    if sep == nil then
            sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
            table.insert(t, str)
    end
    return t
end


local areasToCheck = {
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

function getInRadius(px, py, radius)
    local steps = math.floor(radius/0.2)
    local grids = {} -- particles around area
    local numbersDone = {}
    for s = 1, steps do
        local size = 0.2 * s
        for d = 0, 360, 6 do
            local rad = math.rad(d)
            local sx, sy = math.sin(rad*size), math.cos(rad*size)
            local gx, gy = ToWorldPos(sx + px, sy + py)
            if(numbersDone[gx.."."..gy] == nil) then
                grids[#grids+1] = getCellParticles(gx, gy)
                numbersDone[gx.."."..gy] = true
            end
        end
    end
    return grids
end

function InTable(tbl, val) -- returns true if value is within a table, false otherwise
    if tbl == nil then return false end
    if #tbl == 0 then return false end
    for key, value in pairs(tbl) do
        if value == val then
            return true
        end
    end
    return false
end

function getPartsInRadius(curPart, radius)
    local gridsToCheck = getInRadius(curPart.x, curPart.y, radius)
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

function getNearby(curPart)
    local gridsToCheck = {}
    local gridx, gridy = curPart.gridspace[1], curPart.gridspace[2]

    for i = 1, #areasToCheck do
        gridsToCheck[#gridsToCheck+1] = getCellParticles(gridx + areasToCheck[i][1], gridy + areasToCheck[i][2])
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

function findClosest(curParticle, colFilter, indxFilter) -- finds closest in a 3x3 area around current cell, you can set a color filter and exclude certin indexes from the search
    local cx, cy = curParticle.x, curParticle.y
    local gridsToCheck = {}
    local indxFilter = indxFilter or nil
    local gridx, gridy = curParticle.gridspace[1], curParticle.gridspace[2]
    for i = 1, #areasToCheck do
        gridsToCheck[#gridsToCheck+1] = getCellParticles(gridx + areasToCheck[i][1], gridy + areasToCheck[i][2])
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

function rebuildWorld()
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

function rebuildWorldGrid()
    rebuildWorld()
    for key, value in pairs(particles) do
        local wx, wy = world.sizex*world.cellSize, world.sizey*world.cellSize

        for _ = 1, 2 do
            if(value.x > wx-1) then -- Perfect fucking fix but this engine is retarded so i have to run it twice
                value.x = 1
            elseif(value.x < 1) then
                value.x = wx-2
            elseif (value.y > wy-1) then
                value.y = 1
            elseif (value.y < 1) then
                value.y = wy-2
            end
        end

        local posx = math.floor((value.x-0.9) / world.cellSize) + 1
        local posy = math.floor((value.y-0.9) / world.cellSize) + 1

        if posx > world.cellSize or posx < 1 then
            print(posx, value.x)
        end
        if posy > world.cellSize or posy < 1 then
            print(posx, value.y)
        end

        if(world[posx] == nil or world[posx][posy] == nil) then
            print("-------")
            print(key)
            print(posx, value.x, world.sizex)
            print(posy, value.y, world.sizey)
            love.timer.sleep(10)
        end

        value.gridspace = {posx, posy}
        table.insert(world[posx][posy], key)
    end
end


function clampMinMax(value, minMax)
    if value > minMax then
        return minMax
    end
    if value < -minMax then
        return -minMax
    end
    return value
end

function normalize(vx, vy)
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
    dirx, diry = normalize(dirx, diry)
    
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

local maxSpeed = 0.5
local switchTimer = 0
local swap = false

function collisionChecks()
    for _, curPart in pairs(particles) do
        local cdist, cpartIndx = findClosest(curPart, -1) -- Flat out closest particle

        if cdist <= 6 and cpartIndx ~= -1 then -- For collisions
            curPart.x = curPart.x + ((curPart.x - particles[cpartIndx].x)+0.00000000001)/cdist -- repel
            curPart.y = curPart.y + ((curPart.y - particles[cpartIndx].y)+0.00000000001)/cdist
        end

        boundParticle(curPart)
    end
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

function updateParticles()
    for _, curPart in pairs(particles) do
        local particlesFound = getNearby(curPart)

        curPart.x = curPart.x + (curPart.velx * love.timer.getDelta())
        curPart.y = curPart.y + (curPart.vely * love.timer.getDelta())
        
        curPart.velx = curPart.velx + (((curPart.velx)*-1) * love.timer.getDelta()) -- drag code
        curPart.vely = curPart.vely + (((curPart.vely)*-1) * love.timer.getDelta())

        for _, partIndx in pairs(particlesFound) do
            local targPart = particles[partIndx]

            local dist = Dist(curPart.x, curPart.y, targPart.x, targPart.y)
            local tx, ty, colision = distFalloff(curPart, partIndx, dist)

            local attractValue = colorAttractions[curPart.col][targPart.col]
            if not colision then
                curPart.velx = curPart.velx + (tx*attractValue)*maxSpeed -- atract
                curPart.vely = curPart.vely + (ty*attractValue)*maxSpeed
            else
                curPart.velx = curPart.velx + tx*maxSpeed -- Collision code
                curPart.vely = curPart.vely + ty*maxSpeed
            end
        end
    end
end

local debug = false
local fast = false

function love.load()
    math.randomseed(os.clock() + 25012)
    math.random(math.random(-500,500))
    colorsMax = 3
    colorAttractions = {
        {0.5,0,0},
        {0,0.5,0},
        {0,0,0.5},
    }

    initWorld(37,20,50)
    love.window.setMode(world.cellSize * world.sizex, world.cellSize * world.sizey);
    for i=1, 3500 do
        local col = math.random(1,colorsMax)
        createParticle(math.random(1, world.cellSize * world.sizex)+math.random(),math.random(1, world.cellSize * world.sizey)+math.random(), col)
    end
    updateParticles()
end

local colors = {
    {0,0,1},
    {1,0,0},
    {0,1,0},
    {1,0.5,0},
    {1,1,1}
}

function love.draw()
    love.graphics.setBackgroundColor(0.07,0.05,0.05)
    love.graphics.setColor(1,1,1,1)
    if debug then
        for _, curPart in pairs(particles) do
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
    elseif fast == false then
        for _, curPart in pairs(particles) do
            local blurSteps = 4
            local blurSize = 6
            local blurMax = 0.07
            local blurper = blurMax/blurSteps

            for b = 1, blurSteps do
                love.graphics.setColor(colors[curPart.col][1], colors[curPart.col][2], colors[curPart.col][3], blurper)
                love.graphics.circle("fill", curPart.x, curPart.y, 3 + ((blurSize/blurSteps)*(b)))
            end
            love.graphics.setColor(colors[curPart.col][1], colors[curPart.col][2], colors[curPart.col][3], 1)
            love.graphics.circle("fill", curPart.x, curPart.y, 3)
        end
    else
        local movespeedsum = 0
        for _, curPart in pairs(particles) do
            movespeedsum = movespeedsum + (math.abs(curPart.velx) + math.abs(curPart.vely))
            love.graphics.setColor(colors[curPart.col][1], colors[curPart.col][2], colors[curPart.col][3], 1)
            love.graphics.points(curPart.x, curPart.y)
        end
        love.graphics.setColor(1,1,1,1)
        love.graphics.print(movespeedsum/#particles)
    end
end

function love.keypressed(key, scancode, isrepeat)
    if key == "r" and not isrepeat then
        print("Randomizing Color attractions!")
        randomizeAttractions()
        print(colorAttractions[1][1])
        resetAndStuffs = false
    end
    if key == "d" and not isrepeat then
        debug = not debug
    end
    if key == "v" and not isrepeat then
        fast = not fast
    end
end

function love.update()
    updateParticles()
    rebuildWorldGrid()
end