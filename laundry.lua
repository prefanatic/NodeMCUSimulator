--
-- Created by IntelliJ IDEA.
-- User: cgoldberg02
-- Date: 9/26/17
-- Time: 1:46 PM
-- To change this template use File | Settings | File Templates.
--

local PIN = 1
local TRIG_TYPE = "down"

local MQTT_ID = "DasLaundyMachine"
local KEEP_ALIVE = 120

local mqttClient = null
local mqttConnected = false

local TOPIC_REGISTER = "/register"
local TOPIC_OTA = "/ota/" .. wifi.sta.gethostname()

local ERROR = 0
local INFO = 1
local log = function(level, msg) end

local function onLaundryTriggered(level, pulse)
    print("Hello the laundry is done.")

    mqttClient:publish("laundry/fin", "yep.", 0)
end

local function onMqttConnected(client)
    mqttConnected = true
    log(INFO, "Hello client: " .. tostring(client))

    -- Build a registration payload.
    local payload = {
        id = wifi.sta.gethostname(),
        time = tmr.now()
    }

    local success, json = pcall(sjson.encode, payload)
    if (not success) then
        log(ERROR, "Unable to encode registration payload.")
        return
    end

    mqttClient:publish(TOPIC_REGISTER, json, 0, 0)
    mqttClient:subscribe(TOPIC_OTA, 2)
end

local function performOta(fileName, contents)
    local file = file.open(fileName, "w")
    if not file then log(ERROR, "Unable to perform OTA.") return end

    file:write(contents)
    file:close()
end

local function onMessage(client, topic, data)
    log(INFO, "Message received on topic: " .. topic .. "\nData: " .. data);

    if (topic == TOPIC_OTA) then
        log(INFO, tostring(data))
        local otaWrite = sjson.decode(data)
        performOta(otaWrite.fileName, otaWrite.content)
    end
end

log = function(level, m)
    print(m)

    if (mqttClient == null or not mqttConnected) then return end
    mqttClient:publish("/log", m, 0, 0)
end

local function main()
    print("Hello World")

    -- Listen to our GPIO to trigger a laundry changed event.
    gpio.mode(PIN, gpio.INT)
    gpio.trig(PIN, TRIG_TYPE, onLaundryTriggered)

    mqttClient = mqtt.Client(MQTT_ID, KEEP_ALIVE)
    mqttClient:on("connect", onMqttConnected)
    mqttClient:on("message", onMessage)
    mqttClient:connect("192.168.1.210", 1883, false, true)
end

main()