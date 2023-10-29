-- LUA script for EdgeTX to store the GPS position in a couple of GV
-- Radio needs local GPS
-- What it does:
-- Gets local GPS coordinates from EdgeTx
-- Store local GPS coordinates into a global variable localGPS
-- How it is used:
-- Copy LUA to SCRIPTS\FUNCTIONS\gpsfix.lua
-- In EdgeTX enable gpsfix LUA by Special Function and a swicth
-- [c] SDV, ispired by kolin 2023
-- Global Configuration --------------------------------------------------------------------------------------------------

aServoAngle = 180 -- max rotation angle of the azimut servo
eServoAngle = 180 -- max rotation angle of the elevation servo
useRemoteGPS = 1  -- 0: use local (TX radio) gps, 1: use remote (aircraft) gps, 2: use simulated GPS
minSats = 7       -- mimimum number of satellites required to consider the remote gps position aquired

-- -----------------------------------------------------------------------------------------------------------------------

localGPS = {}
gpsfix = false
local nexttime = 0

-- function called once by EdgeTx
local function init_func()
    
    print("GPSFix LUA started")
    print("GPSFix v0.0")
    gpsfix = false

end


local function getTelemetryId(name)
    field = getFieldInfo(name)
    if field then
        return field.id
    else
        return -1
    end
end


local function rnd(v, d)
    if d then
        return math.floor((v * 10 ^ d) + 0.5) / (10 ^ d)
    else
        return math.floor(v + 0.5)
    end
end

function map_range(value, in_min, in_max, out_min, out_max)
    return (value - in_min) * (out_max - out_min) / (in_max - in_min) + out_min
end


--function called periodically
local function run_func()

    local eOffset = model.getGlobalVariable(3, 0) 
    local elevationMapped = (math.floor(map_range(eOffset, 0, eServoAngle, -1024, 1024))) 
    
    -- set servo in zero positions
    model.setGlobalVariable(0, 0, 0) 
    model.setGlobalVariable(1, 0, elevationMapped)

    if (useRemoteGPS == 1) then -- use aircraft GPS data
        
        -- wait for remote gps. We assume the drone is close to the radio so we can consider the initial drone GPS position valid as radio/tracker position
        --find what ID has GPS telemetry slot been assigned
        --local telemetryGpsAltID = getTelemetryId("Alt") --GPS altitude m
        local telemetryGpsID = getTelemetryId("GPS")
        local telemetryGpsAltID = getTelemetryId("Alt")
        local telemetryGpsSatsID = getTelemetryId("Sats")
                
        --if "ALT" can't be read, try to read "GAlt"
        if (telemetryGpsAltID == -1) then telemetryGpsAltID = getTelemetryId("GAlt") end
        
        if (getValue(telemetryGpsSatsID) >= minSats) then
            
            if (telemetryGpsID ~= nil) then
                
                local remoteGPStable = getValue(telemetryGpsID)--read value of ID
                
                if (type(remoteGPStable) == "table") then -- sanity check
                    localGPS.lat = remoteGPStable.lat
                    localGPS.lon = remoteGPStable.lon
                    localGPS.alt = rnd(getValue(telemetryGpsAltID), 0)
                    gpsfix = true
                    
                    if getRtcTime() > (nexttime + 10) then
                        nexttime = getRtcTime()
                        playFile("/SOUNDS/AntennaTracker/GPSFix.wav")
                    end
                
                else
                    print("ERROR: GPS data cannot not found in telemetry variables")
                    
                    if getRtcTime() > (nexttime + 20) then
                        nexttime = getRtcTime()
                        playFile("/SOUNDS/AntennaTracker/WFGPS.wav")
                    end
                
                end
            
            else
                
                if getRtcTime() > (nexttime + 20) then
                    nexttime = getRtcTime()
                    playFile("/SOUNDS/AntennaTracker/noTLM.wav")
                end
            
            end
        
        else
            
            if getRtcTime() > (nexttime + 20) then
                nexttime = getRtcTime()
                playFile("/SOUNDS/AntennaTracker/WFGPS.wav")
            end
        end
    end
    
    if (useRemoteGPS == 0) then -- use tx radio GPS data
        
        local TextGPS = getTxGPS()
        
        if (TextGPS == nil) then
            
            if getRtcTime() > (nexttime + 10) then
                nexttime = getRtcTime()
                playFile("/SOUNDS/AntennaTracker/GPSnf.wav")
            end
        
        else
            
            if getTxGPS().fix then
                
                localGPS = getTxGPS()
                gpsfix = true
                
                if getRtcTime() > (nexttime + 10) then
                    nexttime = getRtcTime()
                    playFile("/SOUNDS/AntennaTracker/GPSFix.wav")
                end
                
                --debug output ---------------------------------------------------------------------------------------------------------------------------------------
                print("-----------------------------------------------------------------------------------------------------------")
                print(string.format("Local  GPS latitude: %-20s Local GPS longitude: %-20s Local altitude: %s", localGPS.lat, localGPS.lon, localGPS.alt))
            
            else
                gpsfix = false
                
                if getRtcTime() > (nexttime + 20) then
                    nexttime = getRtcTime()
                    playFile("/SOUNDS/AntennaTracker/WFGPS.wav")
                end
            
            end
        end
    end
    
    if (useRemoteGPS == 2) then -- use simulated GPS data
                       
        gpsfix = true

        if getRtcTime() > (nexttime + 10) then
            nexttime = getRtcTime()
            playFile("/SOUNDS/AntennaTracker/GPSFix.wav")
        end
    
    end

end

return {run = run_func, init = init_func}


