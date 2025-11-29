require 'math'
require 'string'
require 'io'

-- Import C usleep() for Linux
## cinclude '<unistd.h>'
local function usleep(us: integer) <cimport, nodecl> end

global A: float32 = 0
global B: float32 = 0
global C: float32 = 0

global width: integer = 160
global height: integer = 44

global cubeWidth: float32 = 20
global incrementSpeed: float32 = 0.8
global distanceFromCam: float32 = 100
global horizontalOffset: float32 = 0
global K1: float32 = 40

global zBuffer: [160*44]float32
global buffer: [160*44]uint8
global colorBuf: [160*44]uint8 -- color index for ANSI

global backgroundChar: uint8 = string.byte('.')

-- ANSI colors
global colormap: [8]string = {
  "\27[0m",   -- 0 reset
  "\27[31m",  -- 1 red
  "\27[33m",  -- 2 yellow
  "\27[32m",  -- 3 green
  "\27[34m",  -- 4 blue
  "\27[35m",  -- 5 magenta
  "\27[36m",  -- 6 cyan
  "\27[37m",  -- 7 white
}

-- Light direction vector (normalized)
global lx, ly, lz: float32 = 0.5, 1.0, -1.0
local len = math.sqrt(lx*lx + ly*ly + lz*lz)
lx = lx / len
ly = ly / len
lz = lz / len

-- Calculate rotated coordinates
local function calcX(i: float32,j: float32,k: float32): float32
  return j*math.sin(A)*math.sin(B)*math.cos(C)
       - k*math.cos(A)*math.sin(B)*math.cos(C)
       + j*math.cos(A)*math.sin(C)
       + k*math.sin(A)*math.sin(C)
       + i*math.cos(B)*math.cos(C)
end

local function calcY(i: float32,j: float32,k: float32): float32
  return j*math.cos(A)*math.cos(C)
       + k*math.sin(A)*math.cos(C)
       - j*math.sin(A)*math.sin(B)*math.sin(C)
       + k*math.cos(A)*math.sin(B)*math.sin(C)
       - i*math.cos(B)*math.sin(C)
end

local function calcZ(i: float32,j: float32,k: float32): float32
  return k*math.cos(A)*math.cos(B)
       - j*math.sin(A)*math.cos(B)
       + i*math.sin(B)
end

-- Get normal vector for face (approximation for cube face)
local function faceNormal(dx: float32, dy: float32, dz: float32)
  local len = math.sqrt(dx*dx + dy*dy + dz*dz)
  return dx/len, dy/len, dz/len
end

-- Light shading intensity (0..1)
local function getLight(dx: float32, dy: float32, dz: float32)
  local nx, ny, nz = faceNormal(dx, dy, dz)
  local dot = nx*lx + ny*ly + nz*lz
  if dot < 0 then dot = 0 end
  return dot
end

local function calculateForSurface(cX: float32, cY: float32, cZ: float32, ch: uint8, colindex: uint8)
  local x = calcX(cX,cY,cZ)
  local y = calcY(cX,cY,cZ)
  local z = calcZ(cX,cY,cZ) + distanceFromCam

  local ooz: float32 = 1 / z
  local xp: integer = (@integer)(width/2 + horizontalOffset + K1*ooz*x*2)
  local yp: integer = (@integer)(height/2 + K1*ooz*y)
  local idx: integer = xp + yp*width

  if idx < 0 or idx >= width*height then return end

  -- light intensity shading
  local intensity = getLight(cX, cY, cZ)
  -- adjust color based on depth (closer = brighter)
  local depthFactor = ooz * 20
  local finalCol = colindex
  if depthFactor < 0.5 then
    finalCol = 7 -- white/dim glow
  elseif intensity > 0.7 then
    finalCol = colindex
  else
    finalCol = 0 -- darker / reset
  end

  if ooz > zBuffer[idx] then
    zBuffer[idx] = ooz
    buffer[idx] = ch
    colorBuf[idx] = finalCol
  end
end

local function drawCube(size: float32, offset: float32)
  cubeWidth = size
  horizontalOffset = offset
  local c, s = cubeWidth, incrementSpeed

  for cubeX: float32 = -c, c, s do
    for cubeY: float32 = -c, c, s do
      calculateForSurface(cubeX, cubeY, -c, string.byte('@'), 1)
      calculateForSurface(c, cubeY, cubeX, string.byte('$'), 2)
      calculateForSurface(-c, cubeY, -cubeX, string.byte('~'), 3)
      calculateForSurface(-cubeX, cubeY, c, string.byte('#'), 4)
      calculateForSurface(cubeX, -c, -cubeY, string.byte(';'), 5)
      calculateForSurface(cubeX, c, cubeY, string.byte('+'), 6)
    end
  end
end

local function clearScreen()
  io.stdout:write("\27[2J\27[H")
end

local function render()
  io.stdout:write("\27[H")
  for i=0,(width*height)-1 do
    if (i % width) == 0 then io.stdout:write("\n") end
    local c = buffer[i]
    local col = colorBuf[i]
    io.stdout:write(colormap[col] .. string.char(c))
  end
  io.stdout:write("\27[0m")
end

-- MAIN LOOP
clearScreen()

while true do
  for i=0,(width*height)-1 do
    buffer[i] = backgroundChar
    zBuffer[i] = 0
    colorBuf[i] = 0
  end

  drawCube(20, -40)
  drawCube(10, 10)
  drawCube(5, 40)

  render()

  -- increment angles
  A = A + 0.05
  B = B + 0.05
  C = C + 0.01

  usleep(16000)
end
