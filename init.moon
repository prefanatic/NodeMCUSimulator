SSID = "test"
PASSWORD = "test"

startup = ->
	if file.open "init.lua" == nil
		print "init.lua is missing!"
	else
		print "Running."
		file.close "init.lua"

		-- TODO: Execute application.

wifiConnectEvent = (T) -> 
	print "Connection to AP(" .. T.SSID  .. ") established!"
	print "Waiting for IP address..."
	if disconnect_ct ~= nil 
		disconnect_ct = nil

wifiGotIpEvent = (T) ->
	print "Wifi connection is ready!  IP address is: " .. T.IP
	print "Startup will resume in 3 seconds."
	timer = tmr.create!
	timer\alarm 3000, tmr.ALARM_SINGLE, startup

wifiDisconnectEvent = (T) ->
	if T.reason == wifi.eventmon.reason.ASSOC_LEAVE
		-- the station has disassociated from a previously connected AP.
		return

	totalTries = 75
	print "Wifi connection to AP(" .. T.SSID .. ") has failed!"

	for key, value in pairs wifi.eventmon.reason
		if value == T.reason 
			print "Disconnect reason: " .. value .. " (" .. key .. ")"

	if disconnect_ct == nil
		disconnect_ct = 1
	else
		disconnect_ct += 1

	if disconnect_ct < totalTries
		print "Retrying connection ... (attempt: " .. disconnect_ct + 1 .. " of " .. totalTries .. ")"
	else
		wifi.sta.disconnect()
		print "Aborting connection to AP."
		disconnect_ct = nil

-- Main	
wifi.eventmon.register wifi.eventmon.STA_CONNECTED, wifiConnectEvent
wifi.eventmon.register wifi.eventmon.STA_DISCONNECTED, wifiDisconnectEvent
wifi.eventmon.register wifi.eventmon.STA_GOT_IP, wifiGotIpEvent

print "Connecting to wifi access point."
wifi.setmode wifi.STATION
wifi.sta.config {ssid: SSID, pwd: PASSWORD}