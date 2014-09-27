--[[
The MIT License (MIT)

Copyright (c) 2014 Marcus Ihde

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]
local _PACKAGE = (...):match("^(.+)[%./][^%./]+") or ""
local class = require(_PACKAGE..'/class')
local Light = require(_PACKAGE..'/light')
local Body = require(_PACKAGE..'/body')
local height_map_conv = require(_PACKAGE..'/height_map_conv')

local light_world = class()

function light_world:init()
  self.translate_x = 0
  self.translate_y = 0
  self.direction = 0

  self.last_buffer = nil

	self.lights = {}
	self.ambient = {0, 0, 0}
	self.body = {}
	self.refraction = {}
	self.shadow = love.graphics.newCanvas()
	self.shadow2 = love.graphics.newCanvas()
	self.shine = love.graphics.newCanvas()
	self.shine2 = love.graphics.newCanvas()
	self.normalMap = love.graphics.newCanvas()
	self.glowMap = love.graphics.newCanvas()
	self.glowMap2 = love.graphics.newCanvas()
	self.refractionMap = love.graphics.newCanvas()
	self.refractionMap2 = love.graphics.newCanvas()
	self.reflectionMap = love.graphics.newCanvas()
	self.reflectionMap2 = love.graphics.newCanvas()
	self.normalInvert = false
	self.glowBlur = 1.0
	self.glowTimer = 0.0
	self.glowDown = false
	self.refractionStrength = 8.0

	self.pixelShadow = love.graphics.newCanvas()
	self.pixelShadow2 = love.graphics.newCanvas()

  self.blurv = love.graphics.newShader("shader/blurv.glsl")
  self.blurh = love.graphics.newShader("shader/blurh.glsl")
  self.blurv:send("screen", {love.window.getWidth(), love.window.getHeight()})
  self.blurh:send("screen", {love.window.getWidth(), love.window.getHeight()})

	self.shader = love.graphics.newShader("shader/poly_shadow.glsl")
	self.glowShader = love.graphics.newShader("shader/glow.glsl")
	self.normalShader = love.graphics.newShader("shader/normal.glsl")
	self.normalInvertShader = love.graphics.newShader("shader/normal_invert.glsl")
	self.materialShader = love.graphics.newShader("shader/material.glsl")
	self.refractionShader = love.graphics.newShader("shader/refraction.glsl")
	self.refractionShader:send("screen", {love.window.getWidth(), love.window.getHeight()})
	self.reflectionShader = love.graphics.newShader("shader/reflection.glsl")
	self.reflectionShader:send("screen", {love.window.getWidth(), love.window.getHeight()})

	self.reflectionStrength = 16.0
	self.reflectionVisibility = 1.0
	self.blur = 2.0
	self.optionShadows = true
	self.optionPixelShadows = true
	self.optionGlow = true
	self.optionRefraction = true
	self.optionReflection = true
	self.isShadows = false
	self.isLight = false
	self.isPixelShadows = false
	self.isGlow = false
	self.isRefraction = false
	self.isReflection = false
end

function light_world:updateShadows()
  if not self.optionShadows or not (self.isShadows or self.isLight) then
    return
  end

  self.last_buffer = love.graphics.getCanvas()
  love.graphics.setShader(self.shader)

  for i = 1, #self.lights do
    self.lights[i]:updateShadow()
  end

  -- update shadow
  love.graphics.setShader()
  love.graphics.setCanvas(self.shadow)
  love.graphics.setStencil()
  love.graphics.setColor(unpack(self.ambient))
  love.graphics.setBlendMode("alpha")
  love.graphics.rectangle("fill", self.translate_x, self.translate_y, love.graphics.getWidth(), love.graphics.getHeight())
  love.graphics.setColor(255, 255, 255)
  love.graphics.setBlendMode("additive")

  for i = 1, #self.lights do
    self.lights[i]:drawShadow()
  end

  -- update shine
  love.graphics.setCanvas(self.shine)
  love.graphics.setColor(unpack(self.ambient))
  love.graphics.setBlendMode("alpha")
  love.graphics.rectangle("fill", self.translate_x, self.translate_y, love.graphics.getWidth(), love.graphics.getHeight())
  love.graphics.setColor(255, 255, 255)
  love.graphics.setBlendMode("additive")

  for i = 1, #self.lights do
    self.lights[i]:drawShine()
  end
  love.graphics.setCanvas(self.last_buffer)
end

function light_world:updatePixelShadows()
  if not self.optionPixelShadows or not self.isPixelShadows then
    return
  end

  self.last_buffer = love.graphics.getCanvas()
  -- update pixel shadow
  love.graphics.setBlendMode("alpha")

  -- create normal map
  self.normalMap:clear()
  love.graphics.setShader()
  love.graphics.setCanvas(self.normalMap)
  for i = 1, #self.body do
    self.body[i]:drawPixelShadow()
  end
  love.graphics.setColor(255, 255, 255)
  love.graphics.setBlendMode("alpha")

  self.pixelShadow2:clear()
  love.graphics.setCanvas(self.pixelShadow2)
  love.graphics.setBlendMode("additive")
  love.graphics.setShader(self.shader2)

  for i = 1, #self.lights do
    self.lights[i]:drawPixelShadow()
  end

  love.graphics.setShader()
  self.pixelShadow:clear(255, 255, 255)
  love.graphics.setCanvas(self.pixelShadow)
  love.graphics.setBlendMode("alpha")
  love.graphics.draw(self.pixelShadow2, self.translate_x, self.translate_y)
  love.graphics.setBlendMode("additive")
  love.graphics.setColor({self.ambient[1], self.ambient[2], self.ambient[3]})
  love.graphics.rectangle("fill", self.translate_x, self.translate_y, love.graphics.getWidth(), love.graphics.getHeight())
  love.graphics.setBlendMode("alpha")

  love.graphics.setCanvas(self.last_buffer)
end

function light_world:updateGlow()
  if not self.optionGlow or not self.isGlow then
    return
  end

  self.last_buffer = love.graphics.getCanvas()
  -- create glow map
  self.glowMap:clear(0, 0, 0)
  love.graphics.setCanvas(self.glowMap)

  if self.glowDown then
    self.glowTimer = math.max(0.0, self.glowTimer - love.timer.getDelta())
    if self.glowTimer == 0.0 then
      self.glowDown = not self.glowDown
    end
  else
    self.glowTimer = math.min(self.glowTimer + love.timer.getDelta(), 1.0)
    if self.glowTimer == 1.0 then
      self.glowDown = not self.glowDown
    end
  end

  for i = 1, #self.body do
    self.body[i]:drawGlow()
  end
  love.graphics.setCanvas(self.last_buffer)
end

function light_world:updateRefraction()
  if not self.optionRefraction or not self.isRefraction then
    return
  end

  self.last_buffer = love.graphics.getCanvas()
  love.graphics.setShader()
  -- create refraction map
  self.refractionMap:clear()
  love.graphics.setCanvas(self.refractionMap)
  for i = 1, #self.body do
    self.body[i]:drawRefraction()
  end
  love.graphics.setCanvas(self.last_buffer)
end

function light_world:updateRelfection()
  if not self.optionReflection or not self.isReflection then
    return
  end

  self.last_buffer = love.graphics.getCanvas()
  -- create reflection map
  self.reflectionMap:clear(0, 0, 0)
  love.graphics.setCanvas(self.reflectionMap)
  for i = 1, #self.body do
    self.body[i]:drawReflection()
  end
  love.graphics.setCanvas(self.last_buffer)
end

function light_world:refreshScreenSize()
  self.shadow = love.graphics.newCanvas()
  self.shadow2 = love.graphics.newCanvas()
  self.shine = love.graphics.newCanvas()
  self.shine2 = love.graphics.newCanvas()
  self.normalMap = love.graphics.newCanvas()
  self.glowMap = love.graphics.newCanvas()
  self.glowMap2 = love.graphics.newCanvas()
  self.refractionMap = love.graphics.newCanvas()
  self.refractionMap2 = love.graphics.newCanvas()
  self.reflectionMap = love.graphics.newCanvas()
  self.reflectionMap2 = love.graphics.newCanvas()
  self.pixelShadow = love.graphics.newCanvas()
  self.pixelShadow2 = love.graphics.newCanvas()
end

-- draw shadow
function light_world:drawShadow()
  if not self.optionShadows or not (self.isShadows or self.isLight) then
    return
  end

  self:updateShadows()
  love.graphics.setColor(255, 255, 255)
  if self.blur then
    self.last_buffer = love.graphics.getCanvas()
    self.blurv:send("steps", self.blur)
    self.blurh:send("steps", self.blur)
    love.graphics.setBlendMode("alpha")
    love.graphics.setCanvas(self.shadow2)
    love.graphics.setShader(self.blurv)
    love.graphics.draw(self.shadow, self.translate_x, self.translate_y)
    love.graphics.setCanvas(self.shadow)
    love.graphics.setShader(self.blurh)
    love.graphics.draw(self.shadow2, self.translate_x, self.translate_y)
    love.graphics.setCanvas(self.last_buffer)
    love.graphics.setBlendMode("multiplicative")
    love.graphics.setShader()
    love.graphics.draw(self.shadow, self.translate_x, self.translate_y)
    love.graphics.setBlendMode("alpha")
  else
    love.graphics.setBlendMode("multiplicative")
    love.graphics.setShader()
    love.graphics.draw(self.shadow, self.translate_x, self.translate_y)
    love.graphics.setBlendMode("alpha")
  end
end

-- draw shine
function light_world:drawShine()
  if not self.optionShadows or not self.isShadows then
    return
  end
  love.graphics.setColor(255, 255, 255)
  if self.blur and false then
    self.last_buffer = love.graphics.getCanvas()
    self.blurv:send("steps", self.blur)
    self.blurh:send("steps", self.blur)
    love.graphics.setBlendMode("alpha")
    love.graphics.setCanvas(self.shine2)
    love.graphics.setShader(self.blurv)
    love.graphics.draw(self.shine, self.translate_x, self.translate_y)
    love.graphics.setCanvas(self.shine)
    love.graphics.setShader(self.blurh)
    love.graphics.draw(self.shine2, self.translate_x, self.translate_y)
    love.graphics.setCanvas(self.last_buffer)
    love.graphics.setBlendMode("multiplicative")
    love.graphics.setShader()
    love.graphics.draw(self.shine, self.translate_x, self.translate_y)
    love.graphics.setBlendMode("alpha")
  else
    love.graphics.setBlendMode("multiplicative")
    love.graphics.setShader()
    love.graphics.draw(self.shine, self.translate_x, self.translate_y)
    love.graphics.setBlendMode("alpha")
  end
end

-- draw pixel shadow
function light_world:drawPixelShadow()
  if not self.optionPixelShadows or not self.isPixelShadows then
    return 
  end
  self:updatePixelShadows()
  love.graphics.setColor(255, 255, 255)
  love.graphics.setBlendMode("multiplicative")
  love.graphics.setShader()
  love.graphics.draw(self.pixelShadow, self.translate_x, self.translate_y)
  love.graphics.setBlendMode("alpha")
end

-- draw material
function light_world:drawMaterial()
  love.graphics.setShader(self.materialShader)
  for i = 1, #self.body do
    self.body[i]:drawMaterial()
  end
  love.graphics.setShader()
end

-- draw glow
function light_world:drawGlow()
  if not self.optionGlow or not self.isGlow then
    return
  end

  self:updateGlow()
  love.graphics.setColor(255, 255, 255)
  if self.glowBlur == 0.0 then
    love.graphics.setBlendMode("additive")
    love.graphics.setShader()
    love.graphics.draw(self.glowMap, self.translate_x, self.translate_y)
    love.graphics.setBlendMode("alpha")
  else
    self.blurv:send("steps", self.glowBlur)
    self.blurh:send("steps", self.glowBlur)
    self.last_buffer = love.graphics.getCanvas()
    love.graphics.setBlendMode("additive")
    self.glowMap2:clear()
    love.graphics.setCanvas(self.glowMap2)
    love.graphics.setShader(self.blurv)
    love.graphics.draw(self.glowMap, self.translate_x, self.translate_y)
    love.graphics.setCanvas(self.glowMap)
    love.graphics.setShader(self.blurh)
    love.graphics.draw(self.glowMap2, self.translate_x, self.translate_y)
    love.graphics.setCanvas(self.last_buffer)
    love.graphics.setShader()
    love.graphics.draw(self.glowMap, self.translate_x, self.translate_y)
    love.graphics.setBlendMode("alpha")
  end
end
-- draw refraction
function light_world:drawRefraction()
  if not self.optionRefraction or not self.isRefraction then
    return
  end

  self:updateRefraction()
  self.last_buffer = love.graphics.getCanvas()
  if self.last_buffer then
    love.graphics.setColor(255, 255, 255)
    love.graphics.setBlendMode("alpha")
    love.graphics.setCanvas(self.refractionMap2)
    love.graphics.draw(self.last_buffer, self.translate_x, self.translate_y)
    love.graphics.setCanvas(self.last_buffer)
    self.refractionShader:send("backBuffer", self.refractionMap2)
    self.refractionShader:send("refractionStrength", self.refractionStrength)
    love.graphics.setShader(self.refractionShader)
    love.graphics.draw(self.refractionMap, self.translate_x, self.translate_y)
    love.graphics.setShader()
  end
end

-- draw reflection
function light_world:drawReflection()
  if not self.optionReflection or not self.isReflection then
    return
  end

  self:updateRelfection()
  self.last_buffer = love.graphics.getCanvas()
  if self.last_buffer then
    love.graphics.setColor(255, 255, 255)
    love.graphics.setBlendMode("alpha")
    love.graphics.setCanvas(self.reflectionMap2)
    love.graphics.draw(self.last_buffer, self.translate_x, self.translate_y)
    love.graphics.setCanvas(self.last_buffer)
    self.reflectionShader:send("backBuffer", self.reflectionMap2)
    self.reflectionShader:send("reflectionStrength", self.reflectionStrength)
    self.reflectionShader:send("reflectionVisibility", self.reflectionVisibility)
    love.graphics.setShader(self.reflectionShader)
    love.graphics.draw(self.reflectionMap, self.translate_x, self.translate_y)
    love.graphics.setShader()
  end
end

-- new light
function light_world:newLight(x, y, red, green, blue, range)
  self.lights[#self.lights + 1] = Light(self, x, y, red, green, blue, range)
  self.isLight = true
  return self.lights[#self.lights]
end

-- clear lights
function light_world:clearLights()
  self.lights = {}
  self.isLight = false
end

-- clear objects
function light_world:clearBodys()
  self.body = {}
  self.isShadows = false
  self.isPixelShadows = false
  self.isGlow = false
  self.isRefraction = false
  self.isReflection = false
end

-- set offset
function light_world:setTranslation(translateX, translateY)
  self.translate_x = translateX
  self.translate_y = translateY
end

-- set ambient color
function light_world:setAmbientColor(red, green, blue)
  self.ambient = {red, green, blue}
end

-- set ambient red
function light_world:setAmbientRed(red)
  self.ambient[1] = red
end

-- set ambient green
function light_world:setAmbientGreen(green)
  self.ambient[2] = green
end

-- set ambient blue
function light_world:setAmbientBlue(blue)
  self.ambient[3] = blue
end

-- set normal invert
function light_world:setNormalInvert(invert)
  self.normalInvert = invert
end

-- set blur
function light_world:setBlur(blur)
  self.blur = blur
end

-- set blur
function light_world:setShadowBlur(blur)
  self.blur = blur
end

-- set buffer
function light_world:setBuffer(buffer)
  if buffer == "render" then
    love.graphics.setCanvas(self.last_buffer)
  else
    self.last_buffer = love.graphics.getCanvas()
  end

  if buffer == "glow" then
    love.graphics.setCanvas(self.glowMap)
  end
end

-- set glow blur
function light_world:setGlowStrength(strength)
  self.glowBlur = strength
end

-- set refraction blur
function light_world:setRefractionStrength(strength)
  self.refractionStrength = strength
end

-- set reflection strength
function light_world:setReflectionStrength(strength)
  self.reflectionStrength = strength
end

-- set reflection visibility
function light_world:setReflectionVisibility(visibility)
  self.reflectionVisibility = visibility
end

-- new rectangle
function light_world:newRectangle(x, y, w, h)
  return self:newBody("rectangle", x, y, width, height)
end

-- new circle
function light_world:newCircle(x, y, r)
  return self:newBody("circle", x, y, radius)
end

-- new polygon
function light_world:newPolygon(...)
  return self:newBody("polygon", ...)
end

-- new image
function light_world:newImage(img, x, y, width, height, ox, oy)
  return self:newBody("image", img, x, y, width, height, ox, oy)
end

-- new refraction
function light_world:newRefraction(normal, x, y, width, height)
  return self:newBody("refraction", normal, x, y, width, height)
end

-- new refraction from height map
function light_world:newRefractionHeightMap(heightMap, x, y, strength)
  local normal = height_map_conv.toNormalMap(heightMap, strength)
  return self.newRefraction(p, normal, x, y)
end

-- new reflection
function light_world:newReflection(normal, x, y, width, height)
  return self:newBody("reflection", normal, x, y, width, height)
end

-- new reflection from height map
function light_world:newReflectionHeightMap(heightMap, x, y, strength)
  local normal = height_map_conv.toNormalMap(heightMap, strength)
  return self.newReflection(p, normal, x, y)
end

-- new body
function light_world:newBody(type, ...)
  local id = #self.body + 1
  self.body[id] = Body(self, id, type, ...)
  return self.body[#self.body]
end

-- get body count
function light_world:getBodyCount()
  return #self.body
end

-- get light
function light_world:getBody(n)
  return self.body[n]
end

-- get light count
function light_world:getLightCount()
  return #self.lights
end

-- get light
function light_world:getLight(n)
  return self.lights[n]
end

return light_world
