/**
* hello.c -- 'Hello World' basic test.
*/

#include <stdio.h>

int main()
{
    unsigned int *ptr = 0;
    unsigned int count;

    printf("compile time: " __DATE__ " -- " __TIME__ "\r\n");
    printf("gcc version:  " __VERSION__ "\r\n");
    printf("\r\n\nZ-pdaXrom: MEMCHK\r\n\r\n\r\n");
    
    printf("Fill RAM!\r\n");
    
    for (count = 1024; count < 2048*1024 / 4; count++) {
	ptr[count] = count;
	if (count % 1024 == 0) {
	    printf("Addr = %04X\r", count);
	}
    }
    
    printf("\nFilled!\r\n Check RAM!\r\n");

    for (count = 1024; count < 2048*1024 / 4; count++) {
	if (ptr[count] != count) {
	    printf("Error at Address = %04X\r\n", count);
	}
	if (count % 1024 == 0) {
	    printf("Addr = %04X\r", count);
	}
    }

    printf("\nDone!!!\r\n\r\n");
    
}
