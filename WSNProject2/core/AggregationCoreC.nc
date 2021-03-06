#include "../include/msg.h"
#include "Timer.h"
#include "printf.h"

module AggregationCoreC {
  uses {
    interface SplitControl as Control;
    interface Receive;
    interface Boot;
    interface Leds;
    interface Packet;
    interface AMPacket;
    interface AMSend;
    interface Timer<TMilli> as Timer1;
    interface Timer<TMilli> as Timer2;
    interface Timer<TMilli> as Timer3;
  }
}
implementation {
  message_t sendBuf;
  result_msg_t result;
  uint16_t data[N_RANDOM_NUMBER];
  // current sequence number we are receiving.
  uint16_t seq = 0;
  // number of packet we have received.
  uint16_t nReceived;
  bool busy = FALSE;
  bool received[N_RANDOM_NUMBER];
  // when we received all packet and calculated the result.
  // we begin to send result.
  bool readyToSendResult = FALSE;
  int i;
  // 
  uint16_t curIndexToRequest = 0;

  event void Boot.booted() {
    nReceived = 0;
    result.group_id = GROUP_ID;
    result.max = 0;
    result.min = 0;
    result.sum = 0;
    result.average = 0;
    result.median = 0;
    for (i = 0; i < N_RANDOM_NUMBER; ++i) {
      received[i] = FALSE;
    }
    call Control.start();
  }

  task void sendResult() {
    uint16_t size = sizeof(result);
    memcpy(call AMSend.getPayload(&sendBuf, size), &result, size);
    call AMSend.send(ACK_NODE_ID, &sendBuf, size);
    printf("send result\n");
  }

  event void Control.startDone(error_t err) {
    if (err == SUCCESS) {
      call Timer1.startPeriodic(200);
    } else {
      call Control.start();
    }
  }

  event void Control.stopDone(error_t err) {
    // do nothing.
  }

  task void askForLackData() {
    if (!busy) {
      seq_msg_t* this_pkt = (seq_msg_t*)(call Packet.getPayload(&sendBuf, NULL));
      while(curIndexToRequest < N_RANDOM_NUMBER && received[curIndexToRequest]) {
        curIndexToRequest ++;
      }
      printf("curIndexToRequest = %u, seq=%u\n", curIndexToRequest, seq);
      if(curIndexToRequest < seq) {
        call Leds.led1Toggle();
        this_pkt->sequence_number = curIndexToRequest;
        if(call AMSend.send(AM_BROADCAST_ADDR, &sendBuf, sizeof(seq_msg_t)) == SUCCESS) {
          busy = TRUE;
        }
      }
    }
  }

  event void AMSend.sendDone(message_t* msg, error_t error) {
    if(&sendBuf == msg) {
      busy = FALSE;
    }
  }

  int q;
  task void calculate() {

    // q is the index of the 1001th integer.
    printf("enter calculate\n");
    result.median = data[q];
    result.min = data[q];
    result.max = 0;
    // scan the left to find out min and the 1000th integer.
    for (i = 0; i < q; i++) {
      if (data[i] > result.max) {
        result.max = data[i];
      } else if (data[i] < result.min) {
        result.min = data[i];
      }
      result.sum += data[i];
    }
    // median = 1000th + 1001th / 2.
    result.median = (result.median + result.max) / 2;
    // scan the right side to find out the max.
    for (i = q; i < N_RANDOM_NUMBER; i++) {
      if (data[i] > result.max) {
        result.max = data[i];
      }
      result.sum += data[i];
    }
    result.average = result.sum / N_RANDOM_NUMBER;
    post sendResult();
    call Timer2.startPeriodic(100);
    printf("leave calculate\n");
    printf("The result is: \n\t max: %lld\n\t min: %lld\n\t sum: %lld\n\t average: %lld\n\t median: %lld\n", 
		result.max, result.min, result.sum, result.average, result.median);
  }

  int tmp;
  int low = 0;
  int high = N_RANDOM_NUMBER - 1;
  bool foundK = FALSE;
  int k = N_RANDOM_NUMBER / 2;
  task void findk()
  {
    if (low < high)
    {
      int i_ = low - 1;
      int j_ = low;
      while (j_ < high)
      {
        if (data[j_] <= data[high])
        {
          tmp = data[j_];
          data[j_] = data[i_ + 1];
          data[i_+1] = tmp;
          i_ ++;
        }
        j_++;
      }
      tmp = data[high];
      data[high] = data[i_ + 1];
      data[i_ + 1] = tmp;
      q = i_ + 1;
   
      if (q == k)
        post calculate();
      else if (q < k) {
        low = q + 1;
        post findk();
      }
      else {
        high = q - 1;
        post findk();
      }
    }
  }

  event void Timer1.fired() {
    call Leds.led0Toggle();
    if (nReceived == N_RANDOM_NUMBER) {
      printf("all received\n");
      post findk();
      call Timer1.stop();
    } else {
      post askForLackData();
    }

    printf("seq=%u, int=%u nRecv=%u\n", seq, data[seq], nReceived);
  }

  event void Timer2.fired() {
    call Leds.led0Toggle();
    post sendResult();
  }

  // tell us we successed.
  event void Timer3.fired() {
    call Leds.led0Toggle();
    call Leds.led1Toggle();
    call Leds.led2Toggle();
  }

  event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
    // receive packet with random integer.
    if (len == sizeof(int_msg_t) && !readyToSendResult) {
      int_msg_t* recv_pkt = (int_msg_t*)payload;
      seq = recv_pkt->sequence_number - 1;
      if (received[seq] == FALSE) {
        received[seq] = TRUE;
        data[seq] = (uint16_t)recv_pkt->random_integer;
        nReceived ++;
        call Leds.led2Toggle();
        printf("nReceived = %u\n", nReceived);
      }
    } 
    // receive ACK packet
    else if (len == sizeof(ack_msg_t) && call AMPacket.source(msg) == 0) {
      ack_msg_t* recv_pkt = (ack_msg_t*)payload;
      printf("ack: group_id=%u\n", recv_pkt->group_id);
      if (recv_pkt->group_id == GROUP_ID) {
        call Timer2.stop();
        // call Control.stop();
        // when received ack, we open timer3 to tell us we successed.
        call Timer3.startPeriodic(1000);
        printf("receive ack msg\n");
      }
    } 
    return msg;
  }
}
