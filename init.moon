SSID = "test"
PASSWORD = "test"

MQTT_ID = "DasLaundryMachine"
MQTT_HOST = "localhost"
MQTT_PORT = 1883
MQTT_KEEP_ALIVE = 120

MQTT_TOPICS = {
	OTA_START: "/ota/" .. wifi.sta.gethostname(),
	OTA_PART: "/ota/" .. wifi.sta.gethostname() .. "/part",
	OTA_END: "/ota/" .. wifi.sta.gethostname() .. "/end",

	REGISTER: "/regsiter"
}

IMMEDIATE_STARTUP = true

-- State values
isOtaActive = false -- Determines if an OTA is currently active.
activeOtaDetails = { -- Container for active OTA information.
	fileName: "",
	parts: -1
}

-- Forward declare all of our methods.
local *

-- @function startup
-- @description Executes the application.lua
startup = ->
	if file.open "init.lua" == nil
		print "init.lua is missing!"
	else
		print "Running."
		file.close "init.lua"

		-- TODO: Execute application.


-- @function mqttRegisterWithCommunicator
-- @description Begins the process to register itself with the Communicator over MQTT.
mqttRegisterWithCommunicator = ->
	mqttClient = mqtt.Client MQTT_ID, MQTT_KEEP_ALIVE
	mqttClient\on "connect", onMqttConnected
	mqttClient\on "message", onMqttMessage
	mqttClient\connect MQTT_HOST, MQTT_PORT, false, true

onMqttConnected = (client) ->
	print "Connected to " .. MQTT_HOST

	-- Register this node, and listen to any OTA requests.
	payload = "TODO"
	mqttClient\publish MQTT_TOPICS.REGISTER, payload, 2, false
	mqttClient\subscribe MQTT_TOPICS.OTA_START, 2

onMqttMessage = (client, topic, data) ->
	print "Message :: " .. topic .. " -> " .. tostring(data)

	-- Check to see if this is an OTA request.
	if topic == MQTT_TOPICS.OTA_START
		-- TODO: Parse the OTA request.
		request = {
			fileName: "application.lua",
			parts: 300 -- How many batches are coming in.
		}

		isOtaActive = true
		activeOtaDetails = request
		activeOtaDetails.fileHandle = file.open request.fileName, "w+"

	-- Check to see if this is an OTA part. 
	if topic == MQTT_TOPICS.OTA_PART
		if not isOtaActive
			print "Received an OTA part, but we were not expecting one.  !!!!"
			return
		if not activeOtaDetails.fileHandle
			print "Received an OTA part, but our file handle is invalid. !!!!"
			return

		-- TODO: Parse the OTA part.
		part = {
			number: 1,
			contents: "print \"Hello World!\""
		}

		activeOtaDetails.fileHandle\write part.contents

	if topic == MQTT_TOPICS.OTA_END
		if not isOtaActive
			print "Received an OTA end, but we were not expecting one.  !!!!"
			return

		-- Tadah!
		activeOtaDetails.fileHandle\flush()
		activeOtaDetails.fileHandle\close()

		isOtaActive = false


wifiConnectEvent = (T) -> 
	print "Connection to AP(" .. T.SSID  .. ") established!"
	print "Waiting for IP address..."
	if disconnect_ct ~= nil 
		disconnect_ct = nil

wifiGotIpEvent = (T) ->
	print "Wifi connection is ready!  IP address is: " .. T.IP
	if IMMEDIATE_STARTUP
		print "Startup will immediately register with Communicator."
		mqttRegisterWithCommunicator()
	else
		print "Startup will register with Communicator in 3 seconds."
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