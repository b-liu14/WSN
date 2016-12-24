#include <stdio.h>
#include <stdlib.h>
#include <memory.h>

typedef struct calculate_result
{
	char group_id;
	unsigned max;
	unsigned min;
	unsigned sum;
	unsigned average;
	unsigned median;
} calculate_result;

typedef union calculate_result_u {
	calculate_result r;
	unsigned char c[24];
} calculate_result_u;

unsigned seed = 0x24b4da1c;
unsigned nums[2000];

int cmp ( const void *a , const void *b )
{
unsigned ca = *(unsigned *)a;
unsigned cb = *(unsigned *)b;
return ca > cb ? 1 : (ca < cb ? -1 : 0);
}

int main(int argc, char **argv)
{
	int i;
	calculate_result_u u;
	int sum = 0;

	for(i=0; i<2000; i++) {
		nums[i] = seed % 5000;
		seed = seed * 0x428a3e67 + 0x24a90b21;
	}

	memset(u.c, 0, sizeof(u.c));

	u.r.group_id = 0;
	for(i=0; i<2000; i++) {
		sum += nums[i];
	}
	u.r.sum = htonl(sum);
	u.r.average = htonl(sum / 2000);
	qsort(nums, 2000, 4, cmp);
	u.r.max = htonl(nums[1999]);
	u.r.min = htonl(nums[0]);
	u.r.median = htonl((nums[999] + nums[1000]) / 2);

	for(i=0; i<sizeof(u.c); i++) {
		printf("%02x ", u.c[i]);
	}

printf("\n");
	return 0;
}
