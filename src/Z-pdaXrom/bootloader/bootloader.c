/**
* hello.c -- 'Hello World' basic test.
*/

#include <stdio.h>
#include "libsoc/src/hw.h"

#define SDPO        *((volatile unsigned int *)GPIO_P0)
#define SDPI        *((volatile unsigned int *)GPIO_P1)

/* Initialize SPI flash control port (CS=H, CLK=L, DI=H, DO=in) */

#define	CS_H()		SDPO |= 0x00000008	/* Set SPI flash CS "high" */
#define CS_L()		SDPO &= 0xFFFFFFF7	/* Set SPI flash CS "low" */
#define CK_H()		SDPO |= 0x00000010	/* Set SPI flash SCLK "high" */
#define	CK_L()		SDPO &= 0xFFFFFFEF	/* Set SPI flash SCLK "low" */
#define DI_H()		SDPO |= 0x00000020	/* Set SPI flash SI "high" */
#define DI_L()		SDPO &= 0xFFFFFFDF	/* Set SPI flash SI "low" */
#define DO		(SDPI & 0x00000002)	/* Test for SPI flash SO ('H':true) */

/*-----------------------------------------------------------------------*/
/* Transmit bytes to the card (bitbanging)                               */
/*-----------------------------------------------------------------------*/

static
void xmit_spi (
	const uint8_t* buff,	/* Data to be sent */
	uint32_t bc				/* Number of bytes to send */
)
{
	uint8_t d;

	do {
		d = *buff++;	/* Get a byte to be sent */
		if (d & 0x80) DI_H(); else DI_L();	/* bit7 */
		CK_H(); CK_L();
		if (d & 0x40) DI_H(); else DI_L();	/* bit6 */
		CK_H(); CK_L();
		if (d & 0x20) DI_H(); else DI_L();	/* bit5 */
		CK_H(); CK_L();
		if (d & 0x10) DI_H(); else DI_L();	/* bit4 */
		CK_H(); CK_L();
		if (d & 0x08) DI_H(); else DI_L();	/* bit3 */
		CK_H(); CK_L();
		if (d & 0x04) DI_H(); else DI_L();	/* bit2 */
		CK_H(); CK_L();
		if (d & 0x02) DI_H(); else DI_L();	/* bit1 */
		CK_H(); CK_L();
		if (d & 0x01) DI_H(); else DI_L();	/* bit0 */
		CK_H(); CK_L();
	} while (--bc);
}

/*-----------------------------------------------------------------------*/
/* Receive bytes from the card (bitbanging)                              */
/*-----------------------------------------------------------------------*/

static
void rcvr_spi (
	uint8_t *buff,	/* Pointer to read buffer */
	uint32_t bc		/* Number of bytes to receive */
)
{
	uint8_t r;


	DI_H();	/* Send 0xFF */

	do {
		r = 0;	 if (DO) r++;	/* bit7 */
		CK_H(); CK_L();
		r <<= 1; if (DO) r++;	/* bit6 */
		CK_H(); CK_L();
		r <<= 1; if (DO) r++;	/* bit5 */
		CK_H(); CK_L();
		r <<= 1; if (DO) r++;	/* bit4 */
		CK_H(); CK_L();
		r <<= 1; if (DO) r++;	/* bit3 */
		CK_H(); CK_L();
		r <<= 1; if (DO) r++;	/* bit2 */
		CK_H(); CK_L();
		r <<= 1; if (DO) r++;	/* bit1 */
		CK_H(); CK_L();
		r <<= 1; if (DO) r++;	/* bit0 */
		CK_H(); CK_L();
		*buff++ = r;			/* Store a received byte */
	} while (--bc);
}

static void init_spi()
{
    CS_H();
    CK_L();
    DI_L();
}

int main()
{
    uint8_t buf[5];
    init_spi();
    rcvr_spi(buf, 1);

    printf("\r\n\nZ-pdaXrom spi flash bootloader! %02X\r\n", buf[0]);

    buf[0] = 0x9f;
    CS_L();
    xmit_spi(buf, 1);
    rcvr_spi(buf, 5);
    CS_H();
    printf("%02X %02X %02X\r\n", buf[0], buf[1], buf[2]);

    return 0;
}
