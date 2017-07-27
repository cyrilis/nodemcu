print("Hello world!")

print("Hello world!")

print("Yeps")

local timer = tmr.create()

timer:register(1500, tmr.ALARM_SINGLE, function ()
  print("Hello world!----")
  timer:stop()
end)

timer:start()
