GEN=OscilloscopeMsg.java Constants.java

all: oscilloscope.jar

oscilloscope.jar: Oscilloscope.class
	jar cf $@ *.class

OscilloscopeMsg.java:
	mig -target=null -java-classname=OscilloscopeMsg java ../common/THPSensorC.h THPSensor -o $@

Constants.java: 
	ncg -target=null -java-classname=Constants java ../common/THPSensorC.h NDATA DEFAULT_INTERVAL -o $@

Oscilloscope.class: $(wildcard *.java) $(GEN)
	javac *.java

clean:
	rm -f *.class $(GEN)

veryclean: clean
	rm oscilloscope.jar
