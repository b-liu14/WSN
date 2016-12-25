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
  // sequences will be requsted.
  uint16_t lackSeqs[N_RANDOM_NUMBER - REQUEST_THRESHOLD];
  // number of packet we have received.
  uint16_t nReceived;
  bool busy = FALSE;
  bool received[N_RANDOM_NUMBER];
  // when we received all packet and calculated the result.
  // we begin to send result.
  bool readyToSendResult = FALSE;
  // when we have received enough packet
  // we begin to request packet from helpers.
  bool readyToRequest = FALSE; 
  // If we are sending request to helpers.
  bool isAsking = FALSE;
  // number of packet that will be request from helper.
  int nToRequest;
  // current index of packet we are requsting.
  int curIndexToRequest;
  int i;

  event void Boot.booted() {
    nReceived = 0;
    result.group_id = GROUP_ID;
    result.max = 0;
    result.min = 65535;
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
      call Leds.led1Toggle();
      // while the current packet has received, reduce the value of curIndexToRequest
      while (curIndexToRequest >= 0 && received[lackSeqs[curIndexToRequest]]) {
        curIndexToRequest --;
      }

      if (curIndexToRequest >= 0) {
        this_pkt->sequence_number = lackSeqs[curIndexToRequest]+1;
        --curIndexToRequest;
        printf("send lack seq: %u\n", this_pkt->sequence_number);

        if(call AMSend.send(AM_BROADCAST_ADDR, &sendBuf, sizeof(seq_msg_t)) == SUCCESS) {
          busy = TRUE;
        }
      }
    }
  }

  event void AMSend.sendDone(message_t* msg, error_t error) {
    if(&sendBuf == msg) {
      busy = FALSE;
      // send 10 requests in a period at most.
      if (curIndexToRequest >= 0 && curIndexToRequest > nToRequest - 10) {
        post askForLackData();
      } else {
        isAsking = FALSE;
      }
    }
  }

  task void request() {
    printf("enter request\n");
    // if it's first time to requst, we should initial the array lackSeq
    if (! readyToRequest) {
      readyToRequest = TRUE;
      // init the array.
      for (i = 0; i < N_RANDOM_NUMBER; i ++) {
        if (received[i] == FALSE) {
          lackSeqs[nToRequest] = i;
          nToRequest ++;
        }
      }
      // request packet.
      curIndexToRequest = nToRequest - 1;
      isAsking = TRUE;
      post askForLackData();
    } else {
      // update the value of nToRequest and curIndexToRequest.
      while (nToRequest > 0 && received[lackSeqs[nToRequest-1]] == TRUE) {
        nToRequest --;
      }
      curIndexToRequest = nToRequest - 1;
      if(! isAsking) {
        post askForLackData();
      }
    }
    printf("leave request\n");
  }

  int tmp;
  int partition(int  a[], int low, int high)
  {
    int i_ = low - 1;
    int j_ = low;
    while (j_ < high)
    {
      if (a[j_] >= a[high])
      {
        tmp = a[j_];
        a[j_] = a[j_ + 1];
        a[j_+1] = tmp;
        i_ ++;
      }
      j_++;
    }
    tmp = a[high];
    a[high] = a[i_ + 1];
    a[i_ + 1] = tmp;
    return i_ + 1;
  }

  int findk(int  a[], int low, int high, int k)
  {
    if (low < high)
    {
      int q = partition(a, low, high);

      int len = q - low + 1; //表示第几个位置    
      if (len == k)
        return q; //返回第k个位置   
      else if (len < k)
        return findk(a, q + 1, high, k - len);
      else
        return findk(a, low, q - 1, k);
    }
  }

  void calculate() {
    // q is the index of the 1001th integer.
    int q = findk(data, 0, N_RANDOM_NUMBER - 1, N_RANDOM_NUMBER / 2 + 1);
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
    printf("leave calculate\n");
  }

  event void Timer1.fired() {
    if (nReceived == N_RANDOM_NUMBER) {
      call Timer1.stop();
      calculate();
      if (readyToSendResult == FALSE) {
        readyToSendResult = TRUE;
        call Timer2.startPeriodic(10);
      }
      post sendResult();
    } else if (nReceived >= REQUEST_THRESHOLD) {
      post request();
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
      }
    } 
    // receive ACK packet
    else if (len == sizeof(ack_msg_t) && call AMPacket.source(msg) == 0) {
      ack_msg_t* recv_pkt = (ack_msg_t*)payload;
      if (recv_pkt->group_id == GROUP_ID) {
        call Timer2.stop();
        call Control.stop();
        // when received ack, we open timer3 to tell us we successed.
        call Timer3.startPeriodic(1000);
        printf("receive ack msg\n");
      }
    } 
    return msg;
  }
}
