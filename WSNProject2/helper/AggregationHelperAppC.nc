#include "../include/msg.h"

configuration AggregationAppC {} 
implementation { 
  
  components AggregationHelperC, MainC, LedsC, new TimerMilliC();

	components ActiveMessageC;
  components new AMReceiverC(AM_MSG);
  components new AMSenderC(AM_MSG);

  AggregationHelperC.Boot -> MainC;
  AggregationHelperC.Leds -> LedsC;

	AggregationHelperC.Control -> ActiveMessageC;
  AggregationHelperC.Receive -> AMReceiverC;
  AggregationHelperC.AMPacket -> AMSenderC;
  AggregationHelperC.Packet -> AMSenderC;
  AggregationHelperC.AMSend -> AMSenderC;
}
