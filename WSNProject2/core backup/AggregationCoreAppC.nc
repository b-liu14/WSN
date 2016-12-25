#include "../include/msg.h"
#include "printf.h"

configuration AggregationCoreAppC {} 
implementation { 
  
  components AggregationCoreC, MainC, LedsC;
  components new TimerMilliC() as Timer1;
  components new TimerMilliC() as Timer2;
  components new TimerMilliC() as Timer3;
	components ActiveMessageC;
  components new AMSenderC(AM_MSG);
  components new AMReceiverC(AM_MSG);

  AggregationCoreC.Boot -> MainC;
  AggregationCoreC.Leds -> LedsC;
  AggregationCoreC.Timer1 -> Timer1;
  AggregationCoreC.Timer2 -> Timer2;
  AggregationCoreC.Timer3 -> Timer3;
	AggregationCoreC.Control -> ActiveMessageC;
	AggregationCoreC.Packet -> AMSenderC;
  AggregationCoreC.AMSend -> AMSenderC;
  AggregationCoreC.AMPacket -> AMSenderC;
  AggregationCoreC.Receive -> AMReceiverC;
}
