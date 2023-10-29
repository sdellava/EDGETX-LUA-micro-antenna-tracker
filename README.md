# EDGETX micro antenna tracker with LUA.

LUA scritps to drive an antenna tracker from an EDGETX radio with ELRS radio link.

## Mandatory prerequisites.

- A free three-position switch is needed
- 2 free radio channels are needed
- GPS on the aircraft is required
- A ELRS Tx module on the Tx radio (or a ERLS native radio)
- A second ELRS Rx with at least two PWM outputs receiving two LUA-controlled channels is needed.
- Two servos connected to the second receiver are needed.

## Optional prerequisites.
- Install a GPS (configured by default to talk NEMEA @9600 bps) on the TX radio and enable it in the EdgeTx system configuration.

## Configure LUA according your setup.

Before to copy the LUAs scripts to the TX radio SD card, set the configuration variables.

The gpsfix LUA is configured by default to use the GPS installed in the aricraft. If your tx radio support/have a the GPS, then change the following variable.

```
useRemoteGPS = 1  -- 0: use local (TX radio) gps, 1: use remote (aircraft) gps, 2: use simulated GPS
minSats = 7       -- mimimum number of satellites required to consider the remote gps position aquired  
```
Set minSats to the number of satellites you need to consider the position correctly fixed.

Note: if you use the aircraft GPS, let it fix close to the tracker. Wait for the "GPS fixed" announce, then ativativate the track LUA. The current aircraft position is stored as tracker position. Now you can move the aircrft to the take off posion. Never disbale the track LUA until the aircraft is landed.

The track LUA need to be configured to correclty move your servos :

```
aServoAngle = 180 -- max rotation angle of the azimut servo
eServoAngle = 180 -- max rotation angle of the elevation servo

```

Adjust the variables values according your specific hw. In example, if your servos has 180° max angle (from 0 to 180 degress) then you need to change the hServoAngle and vServoAngle to 180. Set aDirection to -1 to invert the azimuth server rotation direction and do the same for eDireation for the servo that manage the elevation.

If your hw configuration,for some reason, when the servos are in the center position, do not point North and vertical, you need to fine tune the Tracker changing GV3 and GV3 value. Look at the "The mechanical tracker nutral position tunig" session for more details. 

## Tx configuration
We need two free channels with 10-bit resolution on the TX. 
refere to this page to choose the correct ERLS configuration https://www.expresslrs.org/software/switch-config/

If you are flying a drone or an airplane, you normally need only 4 "10-bit" channels for throttle, picht, roll and yaw. All other channels are associated to switch so ELRS uses 3 or 4 bits.

We need to more 10-bit channels, so we need to confifure ERLS TX in the "Full Res 8 ch" or "Full Res 16 ch Rate/2" or "Full Res 12 ch Mixed". Choose acording your specific configuration needs and keep free two of the 10-bit channels for the tracker's servors. 

## Second Rx Configuration
Allow the Rx to enter in configuration mode, then connect the the ERLS wifi network.
Go the the Model configuration page and look for the output mapping.

In this example, the channels 15 and 16 are mapped to two radio's PWM output where the servos are connected.

![image](https://github.com/sdellava/EDGETX-antenna-tracker-LUAs/assets/11772150/5fa555f3-92ca-479c-b8d7-c6a8796593fe)

Note the Failsafe configuration: set the value according your hw configuration to let the servo move in a specific position when the Tx radio is switched off. If needed revert the servio direction.

## How to install LUAs on the radio.

- Copy the SOUNDS and FUNCTIONS directories to the SD card of the EdgeTX.
- Assign a special function to an unused switch on the radio, center position, and choose "Lua Script" as the function. Then select "gpsfix" from the list of available LUAs.
- Assign a special function to the same radio switch, low position, and choose "Lua Script" as the func and select "track" from the list of available LUAs.
- The track.lua file sets the EdgeTx global variables GV1 and GV2 with the PPM values needed to move two servos that move the antenna tracker. To transmit the values, set two radio channels using GV1 and GV2 as inputs.

## How to use LUAs.

Step 1: Move the switch to the center position to activate the LUA gpsfix. The LUA waits for the GPS fix and announces it.

Wait for the "gps fixed" announce. Be sure the aircraft GPS is already fixed and the radio receive the telemetry, then move to step 2.

Step 2: move the switch to the down position. The track LUA starts to estimate the angle needed to move the tracker antenna.

## The tracker hw.

The tracker is made of four simple components:

- two servo that move the antennas up/down and rotate clockwise/counterclocwise.
- one RX with at least two PWM output where to connect the two servo
- one battery

The TX radio must communicate with both RXs. 

The radio system must allow the use of two RXs connected to the same TX and it is important to disable telemetry on the antenna tracker radio. 

ExpressLRS allows this option so I suggesto to use this radio link system but in teory you can use some others or use two different band for the two radio links. 

## The mechanical tracker nutral position tunig

Acording your specifc mechanical tracker configuration, the servo neutral position may or may not be correct. 
The correct neutral position is with antenna looking North and perfectly orizzontal (0° on the horizon).

If you are flying South or simply if the azimut server neutral position do not move the antennas to 90°, then adjust the GV3 and GV4 to a correct value while the gpsfix LUA is active. Use a leveling tool for precise fine tuing. 
Beware that this tuning may lead to a reduces movement of the tracker in one of the two possible directions.

## The mechanical tracker

These are a possible mechanical component to build the antenna tracker: 
https://it.aliexpress.com/item/1005005888488630.html

![image](https://github.com/sdellava/EDGETX-antenna-tracker-LUAs/assets/11772150/67f95374-1697-4816-b368-6e1c7004b2f8)


https://it.aliexpress.com/item/1005005123007080.html

![image](https://github.com/sdellava/EDGETX-antenna-tracker-LUAs/assets/11772150/2fdbda2f-f990-439e-988b-7b9b6ac50867)

https://it.aliexpress.com/i/2026289826.html

![image](https://github.com/sdellava/EDGETX-antenna-tracker-LUAs/assets/11772150/5c277b7e-2d8a-4ef4-b9d9-259882ced743)
