wifi.setmode(wifi.STATIONAP)
station_cfg={}
station_cfg.ssid="Dont Panic"
station_cfg.pwd="fullstackoverflow"
station_cfg.save=false
wifi.sta.config(station_cfg)
wifi.sta.connect()


ap_cfg={}
ap_cfg.ssid="NODEMCU"
ap_cfg.pwd="fullstackoverflow"
ap_cfg.auth = wifi.WPA_WPA2_PSK
ap_cfg.channel = 9
wifi.ap.config(ap_cfg)

function startServer()
	sv = net.createServer(net.TCP, 30)
	function receiver(sck, data)
	  print("receive:", data)
	  sck:close()
	end

	if sv then
	  sv:listen(80, function(conn)
	    conn:on("receive", receiver)
	    conn:send([[
	    	<html>
	    		<body>
	    			<form action="/" method="POST">
	    				<input type="text" placeholder="ssid" name="ssid" />
	    				<input type="password" placeholder="password" name="password"/>
	    			</form>
	    		</body>
			</html>
	    ]])
	    conn:close()
	  end)
	end
end

startServer();

function stopServer()
end

function changeSSID(ssid, password)
	station_cfg.ssid = ssid
	station_cfg.pwd = password
	wifi.sta.disconnect()
	wifi.sta.config(station_cfg)
	wifi.sta.connect()
end

-- print AP list in old format (format not defined)
function listap(t)
    for k,v in pairs(t) do
        print(k.." : "..v)
    end
end

wifi.sta.getap(listap)

local INDEX = {
	["CN"] = {
		["pm2.5"] = {0,35,75,115,150,250,350,500},
		["pm10"] = {0,50,150,250,350,420,500,600}
	},
	["US"] = {
		["pm2.5"] =  {0,12,35,55,150,250,350,500},
		["pm10"] = {0,54,155,255,355,425,505,600}
	}
}

local IAQI =        {0,50,100,150,200,300,400,500}

function calculateIndex(value, list)
	local IAQIHigh, IAQILow
	local BPHigh, BPLow
	local index
	local AOI
	for i, j in pairs(IAQI) do
		if j > value then
			index = i
			break
		end
	end
	if index and index >= 1 and index < 8 then
		IAQIHigh = IAQI[index]
		IAQILow = (index == 1 and 0 or IAQI[index - 1])
		BPHigh = list[index]
		BPLow = (index == 1 and 0 or list[index - 1])
		AOI = (IAQIHigh - IAQILow)/(BPHigh - BPLow) * (value - BPLow) + IAQILow
	else
		AOI = value
	end
	return AOI, index or 0
end

function parseData( data, country, standard )
	country = country or "US"
	standard = standard or "ATM"

	local pm1, pm25, pm10
	if standard == "ATM" then
		pm1, pm25, pm10 = data[4], data[5], data[6]
	else
		pm1, pm25, pm10 = data[1], data[2], data[3]
	end

	local pm1Index = pm1
	local pm25Index, pm25Level = calculateIndex(pm25, INDEX[country]["pm2.5"])
	local pm10Index, pm10Level = calculateIndex(pm10, INDEX[country]["pm10"])
	local HCHO = data[13] / 1000

	local result =  {
		["pm1"] = pm1,
		["pm25"] = pm25,
		["pm10"] = pm10,
		["pm25Index"] = pm25Index,
		["pm25Level"] = pm25Level - 1,
		["pm10Index"] = pm10Index,
		["pm10Level"] = pm10Level - 1,
		["HCHO"] = HCHO
	}
	return result
end

PMset=7
require('plantower').init(PMset)
plantower.verbose=true -- verbose mode
plantower.psd=true
plantower.read(function(data)
	if data then
		print("---- CN - TSI ----")
		for k, v in pairs(parseData(data, "CN", "TSI")) do
			print(k,":",v)
		end
		print("---- US - ATM ----")
		for k, v in pairs(parseData(data, "CN", "TSI")) do
			print(k,":",v)
		end
	end
end)

function getTemperature()
	local pin = 5
	status, temp, humi, temp_dec, humi_dec = dht.read(pin)
	if status == dht.OK then
	    print("DHT Temperature:"..temp..";".."Humidity:"..humi)
	end
	return temp, humi
end


local sendDataTimer = tmr.create()
local weatherURL = "https://wechat.again.cc/weather"

sendDataTimer:register(15000, tmr.ALARM_AUTO, function ()
	local headers = "Content-Type: application/json\r\n"
	local json = ""
	plantower.read(function (data)
		if data then
			print("---- CN - TSI ----")
			local pmData = parseData(data, "CN", "TSI")
			for k, v in pairs(pmData) do
				print(k,":",v)
			end
			local temp, humi = getTemperature()
			pmData.temperature = temp
			pmData.humidity = humi
			ok, json = pcall(cjson.encode, pmData)
			if not(ok) then
			  json = '{"status" : "Failed to parse JSON in NODEMCU"}'
			end
			http.post(weatherURL, headers, json, function ()
				print("Data Sent")
			end)
		else
			print("NODATA")
		end
	end)
end)
-- sendDataTimer:start()
