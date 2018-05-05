/**
* hello.c -- 'Hello World' basic test.
*/

#include <stdio.h>

int main()
{
    printf("\r\n\nZ-pdaXrom uart bootloader!\r\n");

    while (1) {
	printf("\r\n>");
	int c = getchar();
	//printf("%08X", c);
	putchar(c);
    }

    return 0;
}
