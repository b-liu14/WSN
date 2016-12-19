COMPONENT=TestSerialAppC
BUILD_EXTRA_DEPS += TestSerial.class
CLEAN_EXTRA = *.class TestSerialMsg.java

CFLAGS += -I$(TOSDIR)/lib/T2Hack

TestSerial.class: $(wildcard *.java) TestSerialMsg.java
	javac -target 1.4 -source 1.4 *.java

TestSerialMsg.java:
	mig java -target=null $(CFLAGS) -java-classname=TestSerialMsg ../common/THPSensorC.h THPSensor -o $@


include $(MAKERULES)

