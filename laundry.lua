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

local message = null

local function onLaundryTriggered(level, pulse)
    print("Hello the laundry is done.")

    message:publish("laundry/fin", "yep.", 0)
end

local function onMqttConnected(client)
    print("Hello client: " .. client)
end

local function onMessage(client, topic, data)
    print("Message received on topic: " .. topic .. "\nData: " .. data);
end

local function main()
    print("Hello World")

    -- Listen to our GPIO to trigger a laundry changed event.
    gpio.mode(PIN, gpio.INT)
    gpio.trig(PIN, TRIG_TYPE, onLaundryTriggered)

    message = mqtt.Client(MQTT_ID, KEEP_ALIVE)
    message:on("connect", onMqttConnected)
    message:on("message", onMessage)
    message:connect("test.mosquitto.org", 1883, false, true)

end
main()