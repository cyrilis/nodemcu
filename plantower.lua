local M={
  name=...,
  model=5,
  mlen=nil,
  stdATM=nil,
  verbose=nil,
  debug=nil,
  pm01=nil,
  pm25=nil,
  pm10=nil,
  psd=nil
}
_G[M.name]=M

local function decode(data)
  assert(M.debug~=true or #data==M.mlen,('%s: Incomplete message.'):format(M.name))
  local pms,cksum,dlen={},0,#data/2-2
  local n,msb,lsb
  for n=-1,dlen do
    msb,lsb=data:byte(2*n+3,2*n+4)
    pms[n]=msb*0x100+lsb
    cksum=cksum+(n<dlen and msb+lsb or 0)
  end
  msb,lsb,dlen,n=nil,nil,nil,nil
  assert(M.debug~=true or (pms[-1]==0x424D and pms[0]==#data-4),
    ('%s: Wrongly phrased message.'):format(M.name))
  if cksum==pms[#pms] and M.stdATM~=true then
    M.pm01,M.pm25,M.pm10=pms[1],pms[2],pms[3]
  elseif cksum==pms[#pms] then
    M.pm01,M.pm25,M.pm10=pms[4],pms[5],pms[6]
  else
    M.pm01,M.pm25,M.pm10=nil,nil,nil
  end
  if cksum==pms[#pms] and pms[0]==28 then
    psd={}
    for n=1,5 do psd[n]=pms[n+7]-pms[n+6] end
  else
    psd=nil
  end
  return pms
end

local pinSET=nil
local init=false
function M.init(pin_set,volatile,status)
  if volatile==true then
    _G[M.name],package.loaded[M.name]=nil,nil
  end

  if type(pin_set)=='number' then
    pinSET=pin_set
    gpio.mode(pinSET,gpio.OUTPUT)
  end

  if type(pinSET)=='number' then
    uart.on('data',0,function(data) end,0)
    gpio.write(pinSET,gpio.LOW)
    if M.verbose==true then
      print(('%s: data acquisition %s.\n  Console %s.')
        :format(M.name,type(status)=='string' and status or 'paused','enhabled'))
    end
    uart.on('data')
  end
  if not init then
    M.mlen=({32,24,24,nil,32,nil,32})[M.model]
    M.model=M.mlen and ('PMSx003'):gsub('x',M.model) or nil
  end
  init=(M.model~=nil)and(M.mlen~=nil)
  return init
end

function M.read(callBack)
  assert(init,('Need %s.init(...) before %s.read(...)'):format(M.name,M.name))
  gpio.write(pinSET,gpio.HIGH)
  uart.on('data',M.mlen*2,function(data)
    local bm=data:find("BM")
    if bm then
      tmr.stop(4)
      local result = decode(data:sub(bm,M.mlen+bm-1))
      if type(callBack)=='function' then
        callBack(result)
        gpio.write(pinSET,gpio.LOW)
        uart.on('data')
      end
    end
  end,0)
end

return M
