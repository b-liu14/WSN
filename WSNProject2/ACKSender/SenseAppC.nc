
#include <Timer.h>
#include "../include/msg.h"

configuration SenseAppC 
{ 
} 
implementation { 
  
  components SenseC,MainC, LedsC;

  components new AMSenderC(AM_MSG);
  components ActiveMessageC;

  components new AMReceiverC(AM_MSG);

  components SerialPrintfC;

  SenseC.Boot -> MainC;
  SenseC.Leds -> LedsC;



  SenseC.Packet -> AMSenderC;
  SenseC.AMPacket -> AMSenderC;
  SenseC.AMSend -> AMSenderC;
  SenseC.Control -> ActiveMessageC;

  SenseC.Receive -> AMReceiverC;
}
