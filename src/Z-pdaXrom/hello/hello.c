/**
* hello.c -- 'Hello World' basic test.
*/

#include <stdio.h>

int main()
{
    printf("compile time: " __DATE__ " -- " __TIME__ "\r\n");
    printf("gcc version:  " __VERSION__ "\r\n");
    printf("\r\n\nZ-pdaXrom: Hello World!\r\n\r\n\r\n");
}
