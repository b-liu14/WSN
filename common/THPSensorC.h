/*
 * Copyright (c) 2006 Intel Corporation
 * All rights reserved.
 *
 * This file is distributed under the terms in the attached INTEL-LICENSE     
 * file. If you do not find these files, copies can be found by writing to
 * Intel Research Berkeley, 2150 Shattuck Avenue, Suite 1300, Berkeley, CA, 
 * 94704.  Attention:  Intel License Inquiry.
 */

// @author David Gay

#ifndef THPSENSOR_H
#define THPSENSOR_H

enum {
  /* Default sampling period. */
  DEFAULT_INTERVAL = 256,

  AM_THPSENSOR = 0x93
};

typedef nx_struct THPSensor {
  nx_uint16_t version; /* Version of the interval. */
  nx_uint16_t interval; /* Samping period. */
  nx_uint16_t id; /* Mote id of sending mote. */
  nx_uint16_t count; /* The readings are samples count */
  nx_uint16_t TempData;
  nx_uint16_t HumidityData;
  nx_uint16_t PhotoData;
  nx_uint32_t timeStamp;
} THPSensor_t;

#endif
