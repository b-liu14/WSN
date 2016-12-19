#include "Timer.h"
#include "../common/THPSensorC.h"
#include "SensirionSht11.h"

module OscilloscopeC @safe()
{
    uses {
        interface Boot;
        interface SplitControl as RadioControl;
        interface AMSend;
        interface Receive;
        interface Timer<TMilli>;
        interface Leds;
        interface Read<uint16_t> as readTemp;
        interface Read<uint16_t> as readHumidity;
        interface Read<uint16_t> as readPhoto;
    }
}
implementation
{
    message_t sendBuf;
    bool sendBusy;


    /* Current local state - interval, version and accumulated readings */
    THPSensor_t local;

    uint8_t readingTemp; /* 0 -> not reading, 1 -> reading */
    uint8_t readingHumidity; 
    uint8_t readingPhoto;

    /* When we head an Oscilloscope message, we check it's sample count. If
         it's ahead of ours, we "jump" forwards (set our count to the received
         count). However, we must then suppress our next count increment. This
         is a very simple form of "time" synchronization (for an abstract
         notion of time). */
    bool suppressCountChange;

    // Use LEDs to report various status issues.
    void report_problem() { call Leds.led0Toggle(); }
    void report_sent() { call Leds.led1Toggle(); }
    void report_received() { call Leds.led2Toggle(); }

    event void Boot.booted() {
        local.interval = DEFAULT_INTERVAL;
        local.id = TOS_NODE_ID;
        if (call RadioControl.start() != SUCCESS)
            report_problem();
    }

    void startTimer() {
        call Timer.startPeriodic(local.interval);
        readingTemp = 0;
        readingHumidity = 0;
        readingPhoto = 0;
    }

    event void RadioControl.startDone(error_t error) {
        startTimer();
    }

    event void RadioControl.stopDone(error_t error) {
    }

    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
        THPSensor_t *sensor_msg = payload;

        report_received();

        /* If we receive a newer version, update our interval. 
             If we hear from a future count, jump ahead but suppress our own change
        */  
        if (sensor_msg->version > local.version) {
            local.version = sensor_msg->version;
            local.interval = sensor_msg->interval;
            startTimer();
        }
        if (sensor_msg->count > local.count) {
            local.count = sensor_msg->count;
            suppressCountChange = TRUE;
        }

        return msg;
    }

    /* At each sample period:
         - if local sample buffer is full, send accumulated samples
         - read next sample
    */
    event void Timer.fired() {
        if (readingTemp == 1 && readingHumidity == 1 && readingPhoto == 1) {
            if (!sendBusy && sizeof local <= call AMSend.maxPayloadLength()) {
                 // Don't need to check for null because we've already checked length
                // above
                local.timeStamp = call Timer.getNow();
                memcpy(call AMSend.getPayload(&sendBuf, sizeof(local)), &local, sizeof local);
                if (call AMSend.send(AM_BROADCAST_ADDR, &sendBuf, sizeof local) == SUCCESS)
                    sendBusy = TRUE;
            }
            if (!sendBusy)
                report_problem();
            readingTemp = 0;
            readingHumidity = 0;
            readingPhoto = 0;
            /* Part 2 of cheap "time sync": increment our count if we didn't
                 jump ahead. */
            if (!suppressCountChange) {
                local.count++;
            }
            else {
                suppressCountChange = FALSE;
            }
        }
        if ((readingTemp == 0 && call readTemp.read() != SUCCESS) || 
            (readingHumidity == 0 && call readHumidity.read() != SUCCESS) || 
            (readingPhoto == 0 && call readPhoto.read() != SUCCESS)) {
            report_problem();
        }
    }

    event void readTemp.readDone(error_t result, uint16_t val) {
        if (result == SUCCESS){
            double T = -39.6 + 0.01*(double)(val);
            local.TempData = (uint16_t)(T);
            readingTemp = 1;
        }
        else {
            local.TempData = 0xffff;
        }
    }

    event void readHumidity.readDone(error_t result, uint16_t val) {
        while(readingTemp == 0) {
            // do nothing.
        }
        if (result == SUCCESS){
            double RH_linear = -2.0468 + 0.0367*(double)(val) + (-1.5955/1000/1000)*(val*val);
            double RH_true = (local.TempData-25)*(0.01+0.00008*(double)(val))+RH_linear;
            local.HumidityData = (uint16_t)(RH_true);
            readingHumidity = 1;
        }
        else {
            local.HumidityData = 0xffff;
        }
    }

    event void readPhoto.readDone(error_t result, uint16_t val) {
        if (result == SUCCESS){
            local.PhotoData = val;
            readingPhoto = 1;
        }
        else {
            local.PhotoData = 0xffff;
        }
    }

    event void AMSend.sendDone(message_t* msg, error_t error) {
        if (error == SUCCESS)
            report_sent();
        else
            report_problem();

        sendBusy = FALSE;
    }
}
