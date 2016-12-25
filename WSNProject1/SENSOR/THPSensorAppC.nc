#include "printf.h"
configuration THPSensorAppC{

}
implementation {
  components THPSensorC;
  components MainC;
  components ActiveMessageC;
  components LedsC;
  components new TimerMilliC();
  components new SensirionSht11C();
  components new HamamatsuS1087ParC();
  components new AMSenderC(AM_THPSENSOR);
  components new AMReceiverC(AM_THPSENSOR);

  THPSensorC.Boot -> MainC;
  THPSensorC.RadioControl -> ActiveMessageC;
  THPSensorC.AMSend -> AMSenderC;
  THPSensorC.Receive -> AMReceiverC;
  THPSensorC.Timer -> TimerMilliC;
  THPSensorC.Leds -> LedsC;
  THPSensorC.readTemp -> SensirionSht11C.Temperature;
  THPSensorC.readHumidity -> SensirionSht11C.Humidity;
  THPSensorC.readPhoto -> HamamatsuS1087ParC;
}
