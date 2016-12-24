#include "../common/THPSensorC.h"
#include "SensirionSht11.h"
#include "Timer.h"
#include "printf.h"

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
  message_t sendBuf2;
  bool sendBusy;


    /* Current local state - interval, version and accumulated ns */
  THPSensor_t local;
  /* where to send packat */
  uint16_t dest_node_id;

  uint8_t nTemp; /* 0 -> NDATA */
  uint8_t nHumidity;
  uint8_t nPhoto;
  bool TRbusy;
  bool HRbusy;
  bool PRbusy;

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
        if(local.id == TRANSIT_NODE_ID) {
          dest_node_id = BASE_ID;
        }
        else {
          dest_node_id = TRANSIT_NODE_ID;
        }
        if (call RadioControl.start() != SUCCESS)
          report_problem();
      }

      void startTimer() {
        call Timer.startPeriodic(local.interval);
        nTemp = 0;
        nHumidity = 0;
        nPhoto = 0;
        TRbusy = FALSE;
        HRbusy = FALSE;
        PRbusy = FALSE;
      }

      event void RadioControl.startDone(error_t error) { startTimer(); }

      event void RadioControl.stopDone(error_t error) {}

	THPSensor_t *tmp;

      // receive packets
      event message_t *Receive.receive(message_t * msg, void *payload, uint8_t len) {
        THPSensor_t *sensor_msg = payload;
        report_received();
        // control message from BASE
        if(sensor_msg->id == BASE_ID) {
          if (sensor_msg->version > local.version) {
            local.version = sensor_msg->version;
            local.interval = sensor_msg->interval;
            startTimer();
          }
          if (sensor_msg->count > local.count) {
            local.count = sensor_msg->count;
            suppressCountChange = TRUE;
          }  
        } 
        // transit message from normal node
        else if (sensor_msg->id == NORMAL_NODE_ID){
	  tmp = call AMSend.getPayload(&sendBuf2, sizeof(local));
          memcpy(tmp, sensor_msg, sizeof local);
          printf("received a packet from node %u\n", tmp->id);
          if (call AMSend.send(dest_node_id, &sendBuf2, sizeof local) == SUCCESS) {
            sendBusy = TRUE;
          }
        }
        return msg;
      }

  /* At each sample period:
  - if local sample buffer is full, send accumulated samples
  - read next sample */
  event void Timer.fired() {

    if (!sendBusy && sizeof local <= call AMSend.maxPayloadLength()) {
      // Don't need to check for null because we've already checked length
      // above
      local.timeStamp[0] = call Timer.getNow();
      printf("before send: T=%u, H=%u, P=%u, time=%lu\n",
        local.tempData[0], local.humidityData[0], local.photoData[0], local.timeStamp[0]);

	if (!suppressCountChange) {
        local.count++;
      }
      suppressCountChange = FALSE;
      memcpy(call AMSend.getPayload(&sendBuf, sizeof(local)), &local, sizeof local);
      
      if (call AMSend.send(dest_node_id, &sendBuf, sizeof local) == SUCCESS) {
        sendBusy = TRUE;
      }
    }
    if (!sendBusy)
      report_problem();
    if (nTemp >= NDATA && nHumidity >= NDATA && nPhoto >= NDATA) {
      nTemp = 0;
      nHumidity = 0;
      nPhoto = 0;
      /* Part 2 of cheap "time sync": increment our count if we didn't
         jump ahead. */
    }
    if(!TRbusy && !HRbusy && !PRbusy && (nTemp < NDATA) && (nHumidity < NDATA) && (nPhoto < NDATA)) {
      call readTemp.read();
      TRbusy = TRUE;
      call readHumidity.read();
      HRbusy = TRUE;
      call readPhoto.read();
      PRbusy = TRUE;
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
    TRbusy = FALSE;
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
    HRbusy = FALSE;
  }

  uint16_t atmp;
  event void readPhoto.readDone(error_t result, uint16_t val) {
    if (result == SUCCESS){
      local.photoData[nPhoto] = val;
      nPhoto ++;
    }
    else {
      report_problem();
    }
    PRbusy = FALSE;
  }

  event void AMSend.sendDone(message_t * msg, error_t error) {
    if (error == SUCCESS)
      report_sent();
    else
      report_problem();

    sendBusy = FALSE;
  }
}

