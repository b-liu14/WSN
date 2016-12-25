
#include "Timer.h"
#include "../include/msg.h"
#include <stdio.h>

#define SAMPLING_FREQUENCY 100

module SenseC {
  uses {
  	interface SplitControl as Control;
  	interface AMSend;
  	interface Packet;
  	interface AMPacket;
    interface Boot;
    interface Leds;

    interface Receive;
  }
}
implementation {

	message_t sendBuf;

	bool busy = FALSE;

	uint16_t cur_temp = 0;
	uint16_t cur_humid = 0;
	uint16_t cur_light = 0;
	
	uint16_t counter = 0;
  
  event void Boot.booted() {
  	call Control.start();
  }

  
  event void Control.startDone(error_t err) {
		if (err == SUCCESS) {
			
		} else {
			call Control.start();
		}
  }

  event void Control.stopDone(error_t err) {}

	event void AMSend.sendDone(message_t* msg, error_t error) {
		if(&sendBuf == msg) {
			busy = FALSE;
		}
	}

	event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
		if(len == sizeof(result_msg_t) && call AMPacket.destination(msg) == 0) {
			result_msg_t* recv_pkt = (result_msg_t*)payload;
			ack_msg_t* this_pkt = (ack_msg_t*)(call Packet.getPayload(&sendBuf, NULL));
			printf("group_id: %u\nmax: %lu\nmin: %lu\nsum: %lu\naverage: %lu\nmedian: %lu\n", recv_pkt->group_id, recv_pkt->max, recv_pkt->min, recv_pkt->sum, recv_pkt->average, recv_pkt->median);
			this_pkt -> group_id = recv_pkt->group_id;
			if(call AMSend.send(AM_BROADCAST_ADDR, &sendBuf, sizeof(ack_msg_t)) == SUCCESS) {
				busy = TRUE;
				call Leds.led0Toggle();
			}
		}
		return msg;
	}
}

