#! /usr/bin/env gsl-shell


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
   db.write(db, string.format("%s,%s,%s,%s,%s,%s\n", fn, datetime, sat, act, pwr, n))
   
   local f = io.open(fn, 'r')
   if f ~= nil then
      f:close()
   else  -- If file does not already exist
      local page = url_get(url_base .. page_url)
      local gif_url = string.match(page, [[<img src="(/pmap/gif/pmap_.-%.gif)"]])      
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

function create_composites(hemi)
   local pattern  = '(images/(' .. string.rep('%d', 8) .. ')%d+'..hemi..'.-.gif)'
   local f = io.popen('ls -r1 images/*.gif')
   local dates = {}
   local files_by_date = {}
   for l in f:lines() do
      --print(l)
      local path, date = string.match(l, pattern)
      if date ~= nil then
         if files_by_date[date] == nil then
            files_by_date[date] = {}
            dates[#dates+1] = date
         end
         local t = files_by_date[date]
         t[#t+1] = path
      end
   end
   
   table.sort(dates)
   
   for _, date in ipairs(dates) do
      local files = files_by_date[date]
      local fn = 'composite-'..date..'-'..hemi..'.gif'
      print('Creating '..fn)
      local filelist = table.concat(files, ' ')
      local cmd = table.concat({ 'montage -geometry 160x160+4+4 -tile 7x', filelist, fn }, ' ')
      --print(cmd)
      os.execute(cmd)
   end
end

if true then --number_downloaded ~= 0 then
   create_composites('S')
   create_composites('N')
end

