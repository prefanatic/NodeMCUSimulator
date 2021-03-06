INITVERSION = 5

-- TODO: Description should exist in the application lua.
DESCRIPTION = "I am a test device."

SSID = "WILDROUTER"
PASSWORD = "5ABAC16C9D"

MQTT_ID = "DasLaundryMachine"
MQTT_HOST = "misterman"
MQTT_PORT = 1883
MQTT_KEEP_ALIVE = 120

MQTT_TOPICS = {
	OTA_START: "/ota/" .. wifi.sta.gethostname(),
	OTA_PART: "/ota/" .. wifi.sta.gethostname() .. "/part",
	OTA_END: "/ota/" .. wifi.sta.gethostname() .. "/end",

	REGISTER: "/register",
	HEARTBEAT: "/heartbeat",

	DATA: "/data"
}

IMMEDIATE_STARTUP = true

-- Accelerometer Config
I2C_DEVICE_ID = 0
SDA_PORT = 2
SCL_PORT = 1

-- State values
isOtaActive = false -- Determines if an OTA is currently active.
activeOtaDetails = { -- Container for active OTA information.
	fileName: "",
	parts: -1
}

-- Forward declare all of our methods.
local *
local mqttClient
disconnect_ct = 0

-- @function startup
-- @description Executes the application.lua
startup = ->
		i2c.setup I2C_DEVICE_ID, SDA_PORT, SCL_PORT, i2c.SLOW

		for i = 0, 127
			d = string.byte i2cRead i, 0
			if d == 0
				print "Device found: " .. string.format "%02X", i


		adxl345.setup()

		timer = tmr.create!
		timer\alarm 500, tmr.ALARM_AUTO, readAccelerometerData

readAccelerometerData = ->
	x = i2cRead 0x53, 0x32, 2
	print string.format "%02X", x

	--_x, _y, _z = adxl345.read()
	--payload = x: _x, y: _y, z: _z

    --success, json = pcall sjson.encode, payload
    --if not success
    --	print "Unable to encode payload."
    --	return

	--mqttClient\publish MQTT_TOPICS.DATA, json, 0, 0
	--print string.format "X: %d, Y: %d, Z: %d", _x, _y, _z


i2cRead = (deviceAddress, registryAddress, bytes=1) ->
	i2c.start I2C_DEVICE_ID
	i2c.address I2C_DEVICE_ID, deviceAddress, i2c.TRANSMITTER
	i2c.write I2C_DEVICE_ID, registryAddress
	i2c.stop I2C_DEVICE_ID
	i2c.start I2C_DEVICE_ID
	i2c.address I2C_DEVICE_ID, deviceAddress, i2c.RECEIVER

    data = i2c.read I2C_DEVICE_ID, bytes
	i2c.stop I2C_DEVICE_ID

	data

-- @function mqttRegisterWithCommunicator
-- @description Begins the process to register itself with the Communicator over MQTT.
mqttRegisterWithCommunicator = ->
	mqttClient = mqtt.Client MQTT_ID, MQTT_KEEP_ALIVE
	mqttClient\on "connect", onMqttConnected
	mqttClient\on "message", onMqttMessage
	mqttClient\connect MQTT_HOST, MQTT_PORT, false, true

-- @function registerNode
-- @description Registers this node with Communicator
registerNode = ->
	-- Define registration payload
	payload = {
		-- Identifier for the node
        id: wifi.sta.gethostname(),
        -- Node's current time
        time: tmr.now(),
        -- Description of what this node provides
        description: DESCRIPTION,
        -- Node's version
        initVersion: INITVERSION
    }

    success, json = pcall sjson.encode, payload
    if not success
    	print "Unable to encode registration payload."
    	return

	mqttClient\publish MQTT_TOPICS.REGISTER, json, 2, 0


onMqttConnected = (client) ->
	print "Connected to " .. MQTT_HOST

	-- Register this node, and listen to any OTA requests.
	registerNode!

	subscriptions = {
		[MQTT_TOPICS.OTA_START]: 2,
		[MQTT_TOPICS.OTA_PART]: 2,
		[MQTT_TOPICS.OTA_END]: 2,
		[MQTT_TOPICS.HEARTBEAT]: 0
	}
	mqttClient\subscribe subscriptions

	-- TODO: We should wait until we get an OK from communicator before starting.
	startup()


onMqttMessage = (client, topic, data) ->
	print "Message :: " .. topic .. " -> " .. tostring(data)

	-- Check to see if this is an OTA request.
	if topic == MQTT_TOPICS.OTA_START
		request = sjson.decode data

		print "OTA START :: " .. request.fileName .. "(" .. request.parts .. ")"
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
		part = sjson.decode data
		print "OTA PART :: " .. part.part .. "/" .. activeOtaDetails.parts

		activeOtaDetails.fileHandle\writeline part.content

	if topic == MQTT_TOPICS.OTA_END
		if not isOtaActive
			print "Received an OTA end, but we were not expecting one.  !!!!"
			return

		-- Tadah!
		activeOtaDetails.fileHandle\flush()
		activeOtaDetails.fileHandle\close()

		print "OTA END :: Success write to " .. activeOtaDetails.fileName

		isOtaActive = false

	if topic == MQTT_TOPICS.HEARTBEAT
		print "Heartbeat requested."

		registerNode!


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