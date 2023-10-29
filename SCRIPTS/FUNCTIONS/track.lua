-- Antenna tracker LUA script for EdgeTX
-- Radio needs local GPS and Telemetry from airplane must contain GPS coordinates and height
-- This LUA expect the local position to be stored by one other LUA in the localGPS global variable and looks for the gpsfix = true (on other global variable)
-- This LUA is designed to use two ELRS RX with the same passphrase, one on the airplane and one on the tracker.
-- The RX on the tracker must have the telemetry disabled
-- What it does:
-- Gets local GPS coordinates from EdgeTx global variables
-- Gets remote GPS coordinates from telemetry variables
-- Calculates azimuth and elevation to remote vehicle
-- Maps azimuth and elevation to fit full range servo outputs
-- Calculated values for servos are stored in GV1 and GV2
-- How it is used:
-- Copy LUA to SCRIPTS\FUNCTIONS\track.lua
-- In EdgeTX, make two new Inputs and assign GV4 and GV5 to them
-- In Mixer, assign those two Inputs to Outputs of your liking (I use CH11 and CH12)
-- Plug servos to the second RX
-- Set servo endpoints and direction in usual way
-- Set tracker to true north
-- Enable tracker LUA by Special Function and a swicth
-- [c] SDV, inspired by kolin 2023

-- Variables for this script
localGPS = {}
local remoteGPS = {}
gpsfix = false
local nextTime = 0
local first_run = true

local nextSimTime = 0
local simLat = {}
local simLon = {}
local simAlt = {}
local simLocationId = -1

local function rnd(v, d)
    if d then
        return math.floor((v * 10 ^ d) + 0.5) / (10 ^ d)
    else
        return math.floor(v + 0.5)
    end
end

local function getAzElDist(localGPSlat, localGPSlon, localGPSalt, remoteGPSlat, remoteGPSlon, remoteGPSalt)
    local d2r = math.pi / 180.0
    local r2d = 180.0 / math.pi
    
    local lat1 = localGPSlat * d2r
    local lon1 = localGPSlon * d2r
    local lat2 = remoteGPSlat * d2r
    local lon2 = remoteGPSlon * d2r
    
    local dLon = lon2 - lon1
    
    local y = math.sin(dLon) * math.cos(lat2)
    local x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon)
    
    local azimuthRadians = math.atan2(y, x)
    local azimuthDegrees = ((azimuthRadians * r2d + 450)) % 360
    
    -- Earth radius in meters
    local R = 6371000
    
    -- Distance between the two GPS points in meters
    local dLat = lat2 - lat1
    local dLon = lon2 - lon1
    
    -- Haversine formula to calculate distance between two GPS points
    local a = (math.sin(dLat / 2)) ^ 2 + math.cos(lat1) * math.cos(lat2) * (math.sin(dLon / 2)) ^ 2
    local c = 2 * math.atan(math.sqrt(a), math.sqrt(1 - a))
    local distanceInMeters = R * c
    
    -- Elevation calculation using Pythagoras theorem
    -- Height difference between the two GPS points in meters
    local heightDifferenceInMeters = remoteGPSalt - localGPSalt
    
    -- Elevation angle calculation in radians using Pythagoras theorem
    -- tan(elevation angle) = height difference / distance between the two GPS points
    -- elevation angle in degrees is atan(tan(elevation angle))
    elevationAngleInRadians = math.atan(heightDifferenceInMeters / distanceInMeters)
    elevationAngleInDegrees = 90 - (elevationAngleInRadians * 180.0 / math.pi)
    
    return azimuthDegrees, elevationAngleInDegrees, distanceInMeters
end

function map_range(value, in_min, in_max, out_min, out_max)
    return (value - in_min) * (out_max - out_min) / (in_max - in_min) + out_min
end

-- function called once by EdgeTx
local function init_func()
    print("Antenna tracker in LUA started")
    print("Track v0.0")
end

local function getTelemetryId(name)
    field = getFieldInfo(name)
    if field then
        return field.id
    else
        return -1
    end
end

--function called periodically
local function run_func()
    
    if first_run then
        playFile("/SOUNDS/AntennaTracker/TrkStr.wav")
        first_run = false
    end
    
    if (useRemoteGPS <= 1) then
        
        if (gpsfix == true) then
            
            local telemetryGpsID = getTelemetryId("GPS")
            local telemetryGpsAltID = getTelemetryId("Alt")
            
            --if "ALT" can't be read, try to read "GAlt"
            if (telemetryGpsAltID == -1) then telemetryGpsAltID = getTelemetryId("GAlt") end
            
            if (telemetryGpsID ~= nil) then
                
                local remoteGPStable = getValue(telemetryGpsID)--read value of ID
                
                if (type(remoteGPStable) == "table") then -- sanity check
                    remoteGPS.lat = remoteGPStable.lat
                    remoteGPS.lon = remoteGPStable.lon
                    remoteGPS.alt = rnd(getValue(telemetryGpsAltID), 0)
                    
                    azimuth, elevation, distance = getAzElDist(localGPS.lat, localGPS.lon, localGPS.alt, remoteGPS.lat, remoteGPS.lon, remoteGPS.alt)
                    
                    -- when the drone is close to the homepoint azimuth and elevation can become instable. I set to zero to allow calibration
                    if distance < 10 then
                        azimuth = 0
                        elevation = 0
                    end
                    
                    -- Tilt servo on tracker cannot look down, so negative elevation limit would be 0deg
                    if elevation < 0 then
                        elevation = 0
                    end
                    
                    -- azimuth and elevation correction acording the max servo rotation
                    local aOffset = model.getGlobalVariable(2, 0)-- vertical offse in deg when servo is in center posizion
                    local eOffset = model.getGlobalVariable(3, 0)-- horizzontal offset in deg when servo is in center posizion
                    
                    --map range of degrees to match range for servo
                    local azimuthMapped = math.floor(map_range((azimuth - aOffset) % 360, 0, eServoAngle, -1024, 1024))
                    local elevationMapped = (math.floor(map_range(90 - elevation + eOffset, 0, eServoAngle, -1024, 1024)))
                    
                    --output mapped values to GVARs -----------------------------------------------------------------------------------------------------------------------
                    model.setGlobalVariable(0, 0, azimuthMapped)-- model.setGlobalVariable(index, flight_mode, value), use 0 for GV1, 8 for GV9
                    model.setGlobalVariable(1, 0, elevationMapped)
                    
                    if getRtcTime() > (nextTime + 10) then
                        nextTime = getRtcTime()
                        playTone(1000, 400, 400)
                    end
                end
            
            else
                
                if getRtcTime() > (nextSimTime + 20) then
                    nextSimTime = getRtcTime()
                    playFile("/SOUNDS/AntennaTracker/noTLM.wav")
                end
            end
        
        else
            
            if getRtcTime() > (nextTime + 20) then
                nextTime = getRtcTime()
                playFile("/SOUNDS/AntennaTracker/WFGPS.wav")
            end
        
        end
    
    else --simulator
        
        localGPS.lat = 45.625203
        localGPS.lon = 9.321213
        localGPS.alt = 0
        
        simLat[0] = 45.588816
        simLat[1] = 45.600107
        simLat[2] = 45.625563
        simLat[3] = 45.666366
        
        simLon[0] = 9.285183
        simLon[1] = 9.257722
        simLon[2] = 9.232321
        simLon[3] = 9.286899
        
        simAlt[0] = 0
        simAlt[1] = 100
        simAlt[2] = 200
        simAlt[3] = 5000
        
        if getRtcTime() > (nextSimTime + 15) then
            nextSimTime = getRtcTime()
            
            simLocationId = simLocationId + 1
            if simLocationId == 4 then
                simLocationId = 0
            end
            
            playNumber(simLocationId, 0)
            
            remoteGPS.lat = simLat[simLocationId]
            remoteGPS.lon = simLon[simLocationId]
            remoteGPS.alt = simAlt[simLocationId]
            
            azimuth, elevation, distance = getAzElDist(localGPS.lat, localGPS.lon, localGPS.alt, remoteGPS.lat, remoteGPS.lon, remoteGPS.alt)
                        
            -- Tilt servo on tracker cannot look down, so negative elevation limit would be 0deg
            if elevation < 0 then
                elevation = 0
            end
            
            -- azimuth and elevation correction acording the max servo rotation
            local aOffset = model.getGlobalVariable(2, 0)-- vertical offse in deg when servo is in center posizion
            local eOffset = model.getGlobalVariable(3, 0)-- horizzontal offset in deg when servo is in center posizion
            
            --map range of degrees to match range for servo
            local azimuthMapped = math.floor(map_range((azimuth - aOffset) % 360, 0, eServoAngle, -1024, 1024))
            local elevationMapped = (math.floor(map_range(90 - elevation + eOffset, 0, eServoAngle, -1024, 1024)))
            
            --output mapped values to GVARs -----------------------------------------------------------------------------------------------------------------------
            model.setGlobalVariable(0, 0, azimuthMapped)-- model.setGlobalVariable(index, flight_mode, value), use 0 for GV1, 8 for GV9
            model.setGlobalVariable(1, 0, elevationMapped)
            
            playTone(1000, 400, 400)
        
        end
    end

end

return {run = run_func, init = init_func}
