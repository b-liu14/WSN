#ifndef MSG_H
#define MSG_H

typedef nx_struct int_msg_t {
	nx_uint16_t sequence_number;
	nx_uint32_t random_integer;
}int_msg_t;

typedef nx_struct seq_msg_t {
	nx_uint16_t sequence_number;
}seq_msg_t;

typedef nx_struct result_msg_t {
	nx_uint8_t group_id;
	nx_uint32_t max;
	nx_uint32_t min;
	nx_uint32_t sum;
	nx_uint32_t average;
	nx_uint32_t median;
}result_msg_t;

typedef nx_struct ack_msg_t {
	nx_uint8_t group_id;
}ack_msg_t;

enum {
  AM_MSG = 0,
  GROUP_ID = 3,
  ACK_NODE_ID = 0,
  N_RANDOM_NUMBER = 2000,
  REQUEST_THRESHOLD = 1800,
};

#endif
