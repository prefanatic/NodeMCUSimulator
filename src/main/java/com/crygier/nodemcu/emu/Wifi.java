package com.crygier.nodemcu.emu;

import org.luaj.vm2.LuaFunction;
import org.luaj.vm2.LuaTable;
import org.luaj.vm2.LuaValue;
import org.luaj.vm2.Varargs;
import org.luaj.vm2.lib.TwoArgFunction;

import java.util.HashMap;
import java.util.Map;

import static com.crygier.nodemcu.util.LuaFunctionUtil.*;

/**
 *
 */
public class Wifi extends TwoArgFunction {

    public static final Integer STATION                     = 0;
    public static final Integer SOFTAP                      = 1;
    public static final Integer STATIONAP                   = 2;

    public static final Integer STATION_IDLE                = 0;
    public static final Integer STATION_CONNECTING          = 1;
    public static final Integer STATION_WRONG_PASSWORD      = 2;
    public static final Integer STATION_NO_AP_FOUND         = 3;
    public static final Integer STATION_CONNECT_FAIL        = 4;
    public static final Integer STATION_GOT_IP              = 5;

    // EventMon
    public static final Integer STA_CONNECTED = 0;
    public static final Integer STA_DISCONNECTED = 1;
    public static final Integer STA_GOT_IP = 2;

    private Integer mode;
    private Integer status = 0;
    private String ssid;
    private String password;
    private String ip = "123.456.789.1";

    private Map<Integer, LuaFunction> eventmonCallbacks = new HashMap<>();

    @Override
    public LuaValue call(LuaValue modname, LuaValue env) {
        LuaTable wifi = new LuaTable();

        // Methods
        wifi.set("setmode", oneArgConsumer(this::setMode));

        // Constants
        wifi.set("STATION", STATION);
        wifi.set("SOFTAP", SOFTAP);
        wifi.set("STATIONAP", STATIONAP);

        // Station sub-obejct
        LuaTable sta = new LuaTable();
        sta.set("status", zeroArgFunction(this::getStationStatus));
        sta.set("config", varargsFunction(this::setStationConfig));
        sta.set("connect", zeroArgFunction(this::stationConnect));
        wifi.set("sta", sta);

        // Eventmon sub-object
        LuaTable eventmon = new LuaTable();
        eventmon.set("STA_CONNECTED", STA_CONNECTED);
        eventmon.set("STA_DISCONNECTED", STA_DISCONNECTED);
        eventmon.set("STA_GOT_IP", STA_GOT_IP);

        eventmon.set("register", twoArgFunction(this::register));
        wifi.set("eventmon", eventmon);

        env.set("wifi", wifi);
        env.get("package").get("loaded").set("wifi", wifi);

        return wifi;
    }

    private void register(LuaValue topic, LuaValue callback) {
        eventmonCallbacks.put(topic.toint(), callback.checkfunction());
    }

    private void callEventmonCallback(int topic) {
        LuaFunction callback = eventmonCallbacks.get(topic);
        if (callback == null) return;

        // TODO: Table return should vary depending on the topic.
        LuaTable table = new LuaTable();
        table.set("SSID", ssid);
        table.set("IP", ip);

        callback.call(table);
    }

    private Integer getStationStatus() {
        return status;
    }

    private void setMode(LuaValue value) {
        mode = value.toint();
    }

    private void setStationConfig(Varargs args) {
        boolean auto = false;

        if (args.arg1().istable()) {
            LuaTable table = args.arg1().checktable();
            ssid = table.get("ssid").toString();
            password = table.get("pwd").toString();
            auto = true;
        } else {
            ssid = args.arg1().toString();
            password = args.arg(2).toString();
            auto = args.arg(3) == null || args.arg(3).toboolean();
        }

        if (auto) {
            stationConnect();
        }
    }

    private void stationConnect() {
        status = STATION_GOT_IP;

        callEventmonCallback(STA_CONNECTED);
        callEventmonCallback(STA_GOT_IP);
    }
}