#include "../common/THPSensorC.h"
#include "SensirionSht11.h"
#include "Timer.h"

module THPSensorC @safe()
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


    /* Current local state - interval, version and accumulated ns */
  THPSensor_t local;

  uint8_t nTemp; /* 0 -> NDATA */
  uint8_t nHumidity; 
  uint8_t nPhoto;

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
    nTemp = 0;
    nHumidity = 0;
    nPhoto = 0;
  }

  event void RadioControl.startDone(error_t error) { startTimer(); }

  event void RadioControl.stopDone(error_t error) {}

  // receive packets
  event message_t *Receive.receive(message_t * msg, void *payload,
    uint8_t len) {
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
  - read next sample */
  event void Timer.fired() {
    if (nTemp == NDATA && nHumidity == NDATA && nPhoto == NDATA) {
      if (!sendBusy && sizeof local <= call AMSend.maxPayloadLength()) {
        // Don't need to check for null because we've already checked length
        // above
        memcpy(call AMSend.getPayload(&sendBuf, sizeof(local)), &local, sizeof local);
        if (call AMSend.send(AM_BROADCAST_ADDR, &sendBuf, sizeof local) == SUCCESS) {
          sendBusy = TRUE;
        }
        if (!sendBusy)
          report_problem();
        nTemp = 0;
        nHumidity = 0;
        nPhoto = 0;
        /* Part 2 of cheap "time sync": increment our count if we didn't
           jump ahead. */
        if (!suppressCountChange) {
          local.count++;
        }
        else {
          suppressCountChange = FALSE;
        }
      }
    }
    if(nTemp < NDATA) {
      call readTemp.read();
    }
    if(nHumidity < NDATA) {
      call readHumidity.read();
    }
    if(nPhoto < NDATA) {
      call readPhoto.read();
    }
  }

  event void readTemp.readDone(error_t result, uint16_t val) {
    if (result == SUCCESS ){
      double T = -39.6 + 0.01*(double)(val);
      local.tempData[nTemp] = (uint16_t)(T);
      nTemp ++;
    }
    else {
      report_problem();
    }
  }

  event void readHumidity.readDone(error_t result, uint16_t val) {
    while(nTemp < nHumidity) {
      // do nothing.
    }
    if (result == SUCCESS){
      uint16_t temp = local.tempData[nHumidity];
      double RH_linear = -2.0468 + 0.0367*val + (-1.595/1000000)*val*val;
      double RH_true = (temp-25)*(0.01+0.00008*(double)(val))+RH_linear;
      local.humidityData[nHumidity] = (uint16_t)(RH_true);
      nHumidity ++;
    }
    else {
      report_problem();
    }
  }

  event void readPhoto.readDone(error_t result, uint16_t val) {
    if (result == SUCCESS){
      local.photoData[nPhoto] = val;
      local.timeStamp[nPhoto] = Timer.getNow();
      nPhoto ++;
    }
    else {
      report_problem();
    }
  }

  event void AMSend.sendDone(message_t * msg, error_t error) {
    if (error == SUCCESS)
      report_sent();
    else
      report_problem();

    sendBusy = FALSE;
  }
}