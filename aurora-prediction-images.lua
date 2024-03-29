#! /usr/bin/env lua


-- Database

local function db_open(database)
   -- TODO: Metatable
   -- TODO: Error checking
   
   local db = {}
   db.fn = database
   db.tmp_fn1 = '.data-tmp1.txt'
   db.tmp_fn2 = '.data-tmp2.txt'

   os.execute(string.format('cp %s %s', db.fn, db.tmp_fn1))
   db.f = io.open(db.tmp_fn1, 'a')
   
   db.write = function(db, data)
      db.f:write(data)
   end
   
   db.close = function(db)
      db.f:close()

      os.execute(string.format('sort %s | uniq > %s; mv %s %s', db.tmp_fn1, db.tmp_fn2, db.tmp_fn2, db.fn))
      os.execute(string.format('rm -f %s', db.tmp_fn1))
   end

   return db
end


-- Reading URLs

local function url_get(url)
   local cmd = 'wget -q -O - ' .. url 
   local f = io.popen(cmd)
   local s = f:read('*a')
   return s
end


local data_fn = 'data/data.txt'
local url_index = 'http://www.swpc.noaa.gov/pmap/Plots.html'
local url_base = 'http://www.swpc.noaa.gov/'
local gir_url_base = 'http://www.swpc.noaa.gov/pmap/gif/pmap'




local index = url_get(url_index)
--print(index)

local number_downloaded = 0

local match = [[<tr .-<td>(%d%d%d%d %d%d %d%d).-HREF="([^"]+)".-(%d%d%d%d) UT.-([SN]).-(%d+).-(%d+%.%d+ GW).-(%d+).-(%d+%.%d+)</td></tr>]]


local grammer = [[
   row = 
]]


local db = db_open(data_fn)

for date, page_url, time, hemi, act, pwr, sat, n in string.gmatch(index, match) do
   local fn = 'images/' .. string.match(page_url, "(%d+.-)%.html") .. '.gif'
   local datetime = string.gsub(date..'T'..time, ' ', '')
   
   local f = io.open(fn, 'r')
   if f ~= nil then
      f:close()
   else  -- If file does not already exist
      local page = url_get(url_base .. page_url)
      local gif_url = string.match(page, [[<img src="(/pmap/gif/pmap_.-%.gif)"]])      
      db.write(db, string.format("%s,%s,%s,%s,%s,%s\n", fn, datetime, sat, act, pwr, n, gif_url))
      print(fn, datetime, sat, act, pwr, n)
      local gif_data = url_get(url_base .. gif_url)
      local f = io.open(fn, 'w')
      f:write(gif_data)
      f:close()
      number_downloaded = number_downloaded + 1
   end
end

db.close(db)

print(number_downloaded .. ' new images downloaded.')

if true then --number_downloaded ~= 0 then
   os.execute("tup upd")
end

