all: MsgReader.class SensorMsg.class

MsgReader.class: MsgReader.java SensorMsg.class
	javac MsgReader.java 

SensorMsg.class: SensorMsg.java
	javac $^
	
SensorMsg.java:
	mig java -target=null -java-classname=SensorMsg ../common/THPSensorC.h THPSensor -o $@
	chmod +x $@
clean:
	rm -rf SensorMsg.java SensorMsg.class MsgReader.class

