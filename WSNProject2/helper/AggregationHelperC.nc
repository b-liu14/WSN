#include "../include/msg.h"

module AggregationHelperC {
	uses {
		interface SplitControl as Control;
		interface Receive;
		interface Boot;
		interface Leds;

		interface AMSend;
		interface Packet;
		interface AMPacket;
	}
}
implementation {

	message_t sendBuf;
	uint16_t integers[2000];
	uint16_t sendList[100];
	uint16_t sendListLength = 0;
	uint16_t seq = 0;
	bool received[2000];
	bool busy = FALSE;

	event void Boot.booted() {
		int i;
		for (i = 0; i < 2000; ++i) {
			received[i] = FALSE;
		}
		call Control.start();
	}

	event void Control.startDone(error_t err) {
		if (err == SUCCESS) {
		} else {
			call Control.start();
		}
	}

	event void Control.stopDone(error_t err) {
  	// do nothing.
	}

	task void sendAskedData() {
		if (!busy) {
			int_msg_t* this_pkt = (int_msg_t*)(call Packet.getPayload(&sendBuf, NULL));
			sendListLength--;
			this_pkt->sequence_number = sendList[sendListLength];
			this_pkt->random_integer = integers[this_pkt->sequence_number-1];
			if(call AMSend.send(AM_BROADCAST_ADDR, &sendBuf, sizeof(int_msg_t)) == SUCCESS) {
				busy = TRUE;
				call Leds.led0Toggle();
			}
		}
	}
	
	event void AMSend.sendDone(message_t* msg, error_t error) {
		if(&sendBuf == msg) {
			busy = FALSE;
			if(sendListLength > 0){
				post sendAskedData();
			}
		}
	}

	event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
		if (len == sizeof(int_msg_t)) {
			int_msg_t* recv_pkt = (int_msg_t*)payload;
			call Leds.led2Toggle();

			seq = recv_pkt->sequence_number - 1;
			if (received[seq] == FALSE) {
				received[seq] = TRUE;
				integers[seq] = (uint16_t)recv_pkt->random_integer;
			}
			
		} else if (len == sizeof(seq_msg_t)) {
			seq_msg_t* recv_pkt = (seq_msg_t*)payload;
			call Leds.led1Toggle();
			if(received[recv_pkt->sequence_number-1]) {
				sendList[sendListLength] = recv_pkt->sequence_number;
				sendListLength++;
				post sendAskedData();
			}
		}
		return msg;
	}
}
