#! /usr/bin/env gsl-shell

local function url_get(url)
   local cmd = 'wget -q -O - ' .. url 
   local f = io.popen(cmd)
   local s = f:read('*a')
   return s
end

local data_fn = 'data/data.txt'
local data_tmp_fn1 = '.data-tmp1.txt'
local data_tmp_fn2 = '.data-tmp2.txt'

local url_index = 'http://www.swpc.noaa.gov/pmap/Plots.html'
local url_base = 'http://www.swpc.noaa.gov/'
local gir_url_base = 'http://www.swpc.noaa.gov/pmap/gif/pmap'


local index = url_get(url_index)
--print(index)

local number_downloaded = 0

local match = [[<tr .-<td>(%d%d%d%d %d%d %d%d).-HREF="([^"]+)".-(%d%d%d%d) UT.-([SN]).-(%d+).-(%d+%.%d+ GW).-(%d+).-(%d+%.%d+)</td></tr>]]


os.execute(string.format('cp %s %s', data_fn, data_tmp_fn1))
local df = io.open(data_tmp_fn1, 'a')

for date, page_url, time, hemi, act, pwr, sat, n in string.gmatch(index, match) do
   local fn = 'images/' .. string.match(page_url, "(%d+.-)%.html") .. '.gif'
   local datetime = string.gsub(date..'T'..time, ' ', '')
   df:write(string.format("%s,%s,%s,%s,%s,%s\n", fn, datetime, sat, act, pwr, n))
   
--   print(date, page_url, time, hemi, act, pwr, sat, n, fn, gif_url)
   --print(fn)
   if hemi == 'S' then
      local f = io.open(fn, 'r')
      if f ~= nil then
         f:close()
      else  -- If file does not already exist
         local page = url_get(url_base .. page_url)
         local gif_url = string.match(page, [[<img src="(/pmap/gif/pmap_.-%.gif)"]])      
--         print(date, page_url, time, hemi, act, pwr, sat, n, fn, gif_url)
         print(fn) --gif_url)
         local gif_data = url_get(url_base .. gif_url)
         local f = io.open(fn, 'w')
         f:write(gif_data)
         f:close()
         number_downloaded = number_downloaded + 1
      end
   end
end

df:close()
os.execute(string.format('sort %s | uniq > %s; mv %s %s', data_tmp_fn1, data_tmp_fn2, data_tmp_fn2, data_fn))
os.execute('rm -f %s', data_tmp_fn1)

print(number_downloaded .. ' new images downloaded.')

if number_downloaded ~= 0 then
   print('Creating composite...')
   os.execute('ls -r1 images/20*.gif > .filelist.txt')
   local cmd = 'montage -geometry 160x160+4+4 -tile 10x @.filelist.txt composite.gif'
   os.execute(cmd)
   os.execute('rm .filelist.txt')
end

