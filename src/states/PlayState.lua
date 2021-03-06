--[[
    GD50
    Breakout Remake

    -- PlayState Class --

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    Represents the state of the game in which we are actively playing;
    player should control the paddle, with the ball actively bouncing between
    the bricks, walls, and the paddle. If the ball goes below the paddle, then
    the player should lose one point of health and be taken either to the Game
    Over screen if at 0 health or the Serve screen otherwise.
]]

PlayState = Class{__includes = BaseState}

--[[
    We initialize what's in our PlayState via a state table that we pass between
    states as we go from playing to serving.
]]
function PlayState:enter(params)
    self.paddle = params.paddle
    self.bricks = params.levelMap
    self.locked = params.locked
    self.health = params.health
    self.score = params.score
    self.highScores = params.highScores
    self.balls = {params.ball}
    self.level = params.level

    self.recoverPoints = params.recoverPoints

    -- give ball random starting velocity
    self.balls[1].dx = math.random(-200, 200)
    self.balls[1].dy = math.random(-50, -60)

    self.powerups = {}
end

function PlayState:update(dt)
    if self.paused then
        if love.keyboard.wasPressed('space') then
            self.paused = false
            gSounds['pause']:play()
        else
            return
        end
    elseif love.keyboard.wasPressed('space') then
        self.paused = true
        gSounds['pause']:play()
        return
    end

    -- update positions based on velocity
    self.paddle:update(dt)

    for k, ball in pairs(self.balls) do
        ball:update(dt)
    end
 
    for k, powerup in pairs(self.powerups) do
        powerup:update(dt)
    end

    for k, ball in pairs(self.powerups) do
        if self.ball:collides(self.paddle) then
         -- raise ball above paddle in case it goes below it, then reverse dy
            self.ball.y = self.paddle.y - 8
            self.ball.dy = -self.ball.dy

            --
         -- tweak angle of bounce based on where it hits the paddle
         --

           -- if we hit the paddle on its left side while moving left...
          if self.ball.x < self.paddle.x + (self.paddle.width / 2) and self.paddle.dx < 0 then
                self.ball.dx = -50 + -(8 * (self.paddle.x + self.paddle.width / 2 - self.ball.x))
            
          -- else if we hit the paddle on its right side while moving right...
          elseif self.ball.x > self.paddle.x + (self.paddle.width / 2) and self.paddle.dx > 0 then
                 self.ball.dx = 50 + (8 * math.abs(self.paddle.x + self.paddle.width / 2 - self.ball.x))
            end
        end

        gSounds['paddle-hit']:play()
    end

    -- detect collision across all bricks with the ball
    for k, brick in pairs(self.bricks) do

        -- only check collision if we're in play
        if brick.inPlay and self.ball:collides(brick) then

            -- add to score
            

            -- trigger the brick's hit function, which removes it from play
            brick:hit(self.key)

            if not brick.isLocked or not brick.inPlay then
                self.score = self.score + (brick.tier * 200 + brick.color * 25 + (bri.isLocked and 1 or 0)*500)
            end

            if not brick.inPlay then
                local powerup = nil
                if self:gotPowerup(brick) then
                    powerup = Powerup(9)
                end

                if self.locked then
                    if self:gotKey() and not self.key and not self:powerupsContainSkin(10) then
                        powerup = Powerup(10)
                    end
                end

                if powerup ~= nil then
                    powerup.x = brick.x + brick.width/2 - powerup.width/2
                    powerup.y = brick.y + brick.height
                    table.insert(self.powerups, powerup)
                end


                if brick.isLocked then
                    self.key = false
                    self.locked = false
                end
            end

            -- if we have enough points, recover a point of health
            if self.score > self.recoverPoints then
                -- can't go above 3 health
                self.health = math.min(3, self.health + 1)

                -- multiply recover points by 2
                self.recoverPoints = math.min(100000, self.recoverPoints * 2)

                -- play recover sound effect
                gSounds['recover']:play()

                self.paddle:grow()
            end

            -- go to our victory screen if there are no more bricks left
            if self:checkVictory() then
                gSounds['victory']:play()

                gStateMachine:change('victory', {
                    level = self.level,
                    paddle = self.paddle,
                    health = self.health,
                    score = self.score,
                    highScores = self.highScores,
                    ball = self.ball,
                    recoverPoints = self.recoverPoints
                })
            end

            --
            -- collision code for bricks
            --
            -- we check to see if the opposite side of our velocity is outside of the brick;
            -- if it is, we trigger a collision on that side. else we're within the X + width of
            -- the brick and should check to see if the top or bottom edge is outside of the brick,
            -- colliding on the top or bottom accordingly 
            --

            -- left edge; only check if we're moving right, and offset the check by a couple of pixels
            -- so that flush corner hits register as Y flips, not X flips
            if self.ball.x + 2 < brick.x and self.ball.dx > 0 then
                
                -- flip x velocity and reset position outside of brick
                self.ball.dx = -self.ball.dx
                self.ball.x = brick.x - 8
            
                -- right edge; only check if we're moving left, , and offset the check by a couple of pixels
                -- so that flush corner hits register as Y flips, not X flips
            elseif self.ball.x + 6 > brick.x + brick.width and self.ball.dx < 0 then
                
                -- flip x velocity and reset position outside of brick
                self.ball.dx = -self.ball.dx
                self.ball.x = brick.x + 32
            
                -- top edge if no X collisions, always check
            elseif self.ball.y < brick.y then
                
                -- flip y velocity and reset position outside of brick
                self.ball.dy = -self.ball.dy
                self.ball.y = brick.y - 8
            
                -- bottom edge if no X collisions or top collision, last possibility
            else
                
                -- flip y velocity and reset position outside of brick
                self.ball.dy = -self.ball.dy
                self.ball.y = brick.y + 16
            end

            -- slightly scale the y velocity to speed up the game, capping at +- 150
            if math.abs(self.ball.dy) < 150 then
                self.ball.dy = self.ball.dy * 1.02
            end

            -- only allow colliding with one brick, for corners
            break
        end
    end


    for k, powerup in pairs(self.powerups) do
        if powerup: collides(self.paddle) then
            gSounds['confirm']:play()

            if powerup.skin == 10 then
                self.key = true
            else
                for i=0,1 do
                    local newBall = Ball()
                    newBall.skin = math.random(7)
                    newBall.x = self.paddle.x + self.paddle.width/2 - newBall.width/2
                    newBall.y = self.paddle.y - newBall.height
                    newBall.dx = math.random(-200, 200)
                    newBall.dy = math.random(-50, -60)
                    table.insert(self.balls, newBall)
                end
            end
            powerup.inPlay = false
        end
    end

    for k, powerup in pairs(self.powerups) do
        if not powerup.inPlay or powerup.y >= VIRTUAL_HEIGHT then
            table.remove(self.powerups, k)
        end
    end
 
    for k, ball in pairs(self.balls) do
        if ball.y >= VIRTUAL_HEIGHT then
            table.remove(self.balls, k)
        end
    end

    -- if ball goes below bounds, revert to serve state and decrease health
    if #self.balls <= 0 then
        self.health = self.health - 1
        gSounds['hurt']:play()

        if self.health == 0 then
            gStateMachine:change('game-over', {
                score = self.score,
                highScores = self.highScores
            })
        else
            self.paddle:shrink()
            gStateMachine:change('serve', {
                paddle = self.paddle,
                levelMap = self.bricks,
                locked = self.locked,
                key = self.key,
                health = self.health,
                score = self.score,
                highScores = self.highScores,
                level = self.level,
                recoverPoints = self.recoverPoints
            })
        end
    end

    -- for rendering particle systems
    for k, brick in pairs(self.bricks) do
        brick.bricks:update(dt)
    end

    if love.keyboard.wasPressed('escape') then
        love.event.quit()
    end
end


function PlayState:render()
    -- render bricks
    for k, brick in pairs(self.bricks) do
        brick:render()
    end

    -- render all particle systems
    for k, brick in pairs(self.bricks.bricks) do
        brick:renderParticles()
    end

    self.paddle:render()
    
    for k, ball in pairs(self.balls) do
        ball:render()
    end

    for k, powerup in pairs(self.powerups) do
        powerup:render()
    end

    renderScore(self.score)
    renderHealth(self.health)

    if self.key then
        renderKeyPowerup()
    end

    -- pause text, if paused
    if self.paused then
        love.graphics.setFont(gFonts['large'])
        love.graphics.printf("PAUSED", 0, VIRTUAL_HEIGHT / 2 - 16, VIRTUAL_WIDTH, 'center')
    end
end

function PlayState:checkVictory()
    for k, brick in pairs(self.bricks) do
        if brick.inPlay then
            return false
        end 
    end

    return true
end

function PlayState:gotPowerup(brick)
    local powerupRnd = brick.initiTier*13 + brick.initColor * 8
    return math.random(1,100) <= powerupRnd
end

function PlayState:gotKey()
    return math.random(1, self:bricksInPlay()) <=2
end

function PlayState.powerupsContainSkin(skin)
    for k, powerup in pairs(self.powerups) do 
        if powerup.skin == skin then
            return true
        end
    end

    return false
end

