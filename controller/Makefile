GEN=OscilloscopeMsg.java Constants.java

all: oscilloscope.jar

oscilloscope.jar: Oscilloscope.class
	jar cf $@ *.class

OscilloscopeMsg.java: ../common/THPSensor.h
	mig -target=null -java-classname=OscilloscopeMsg java ../common/THPSensor.h oscilloscope -o $@

Constants.java: ../common/THPSensor.h
	ncg -target=null -java-classname=Constants java ../common/THPSensor.h NREADINGS DEFAULT_INTERVAL -o $@

Oscilloscope.class: $(wildcard *.java) $(GEN)
	javac *.java

clean:
	rm -f *.class $(GEN)

veryclean: clean
	rm oscilloscope.jar
