import java.util.*;

import net.tinyos.message.*;
import net.tinyos.packet.*;
import net.tinyos.util.*;

public class MsgReader implements net.tinyos.message.MessageListener {

  private MoteIF moteIF;
  
  public MsgReader(String source) throws Exception {
    if (source != null) {
      moteIF = new MoteIF(BuildSource.makePhoenix(source, PrintStreamMessenger.err));
    }
    else {
      moteIF = new MoteIF(BuildSource.makePhoenix(PrintStreamMessenger.err));
    }
  }

  public void start() {
  }
  
  public void messageReceived(int to, Message msg) {
    if (msg instanceof SensorMsg) {
      SensorMsg omsg = (SensorMsg)msg;
      int id = omsg.get_id();
      int count = omsg.get_count();
      int[] tempData = omsg.get_tempData();
      int[] humidityData = omsg.get_humidityData();
      int[] photoData = omsg.get_photoData();
      long[] timeStamp = omsg.get_timeStamp();
      for (int i = 0; i < tempData.length; i ++) {
        System.out.print(id + " ");
        System.out.print(count + " ");
        System.out.print(tempData[i] + " ");
        System.out.print(humidityData[i] + " ");
        System.out.print(photoData[i] + " ");
        System.out.print(timeStamp[i] + " ");
        System.out.println();
      }
    }

    // byte[] data = message.dataGet();
    // for (int i = 2; i < 7; i ++) {
    //   int value = ((data[2*i] << 8) &0x0000ff00) | (data[2*i+1]) & 0x000000ff;
    //   System.out.print(value + " ");
    // }
    // long timeStamp = 0;
    // for (int i = 15; i < 18; i ++) {
    //   timeStamp = (timeStamp << 8) | (data[i] & 0x000000ff);
    // }
    // System.out.println(timeStamp);
  }

  
  private static void usage() {
    System.err.println("usage: MsgReader [-comm <source>] message-class [message-class ...]");
  }

  private void addMsgType(Message msg) {
    moteIF.registerListener(msg, this);
  }
  
  public static void main(String[] args) throws Exception {
    String source = null;
    Vector v = new Vector();
    if (args.length > 0) {
      for (int i = 0; i < args.length; i++) {
       if (args[i].equals("-comm")) {
         source = args[++i];
       }
       else {
         String className = args[i];
         try {
           Class c = Class.forName(className);
           Object packet = c.newInstance();
           Message msg = (Message)packet;
           if (msg.amType() < 0) {
            System.err.println(className + " does not have an AM type - ignored");
          }
          else {
            v.addElement(msg);
          }
        }
        catch (Exception e) {
         System.err.println(e);
       }
     }
   }
 }
 else if (args.length != 0) {
  usage();
  System.exit(1);
}

MsgReader mr = new MsgReader(source);
Enumeration msgs = v.elements();
while (msgs.hasMoreElements()) {
  Message m = (Message)msgs.nextElement();
  mr.addMsgType(m);
}
mr.start();
}


}
