--##############################################################################
-- ION MIPS-compatible CPU demo on Terasic DE-1 Cyclone-II starter board
--##############################################################################
-- This module is little more than a wrapper around the SoC.
--------------------------------------------------------------------------------
-- Switch 9 (leftmost) is used as reset.
--------------------------------------------------------------------------------
-- NOTE: See note at bottom of file about optional use of PLL.
--##############################################################################
-- Copyright (C) 2011 Jose A. Ruiz
--                                                              
-- This source file may be used and distributed without         
-- restriction provided that this copyright statement is not    
-- removed from the file and that any derivative work contains  
-- the original copyright notice and the associated disclaimer. 
--                                                              
-- This source file is free software; you can redistribute it   
-- and/or modify it under the terms of the GNU Lesser General   
-- Public License as published by the Free Software Foundation; 
-- either version 2.1 of the License, or (at your option) any   
-- later version.                                               
--                                                              
-- This source is distributed in the hope that it will be       
-- useful, but WITHOUT ANY WARRANTY; without even the implied   
-- warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      
-- PURPOSE.  See the GNU Lesser General Public License for more 
-- details.                                                     
--                                                              
-- You should have received a copy of the GNU Lesser General    
-- Public License along with this source; if not, download it   
-- from http://www.opencores.org/lgpl.shtml
--##############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.mips_pkg.all; -- Only needed if port debug_info is not OPEN
use work.obj_code_pkg.all;

-- FPGA i/o for Terasic DE-1 board
-- (Many of the board's i/o devices will go unused in this demo)
entity c2sb_demo is
    port (
        -- ***** Clocks
		clk_ext	: in std_logic;

        -- ***** SRAM 256K x 16
        sram_addr     : out std_logic_vector(19 downto 0);
        sram_data     : inout std_logic_vector(15 downto 0);
        sram_oe_n     : out std_logic;
        sram_ub_n     : out std_logic;
        sram_lb_n     : out std_logic;
        sram_ce_n     : out std_logic;
        sram_we_n     : out std_logic;

        -- ***** RS-232
        rxd           : in std_logic;
        txd           : out std_logic;

        -- ***** Buttons
        button  : in std_logic;

        -- ***** Quad 7-seg displays
        seg_led_h          : out std_logic_vector(0 to 8);
        seg_led_l          : out std_logic_vector(0 to 8);

        -- ***** Leds
        led_rgb      : out std_logic_vector(2 downto 0);

        -- ***** SD Card
        miso       : in  std_logic;
        mss         : out std_logic;
        mosi        : out std_logic;
        msck        : out std_logic;
		
		-- ***** TV out
		tvout		: out std_logic_vector(5 downto 0);
		
		-- ***** PS2 keyboard
		ps2dat		: in std_logic;
		ps2clk		: in std_logic;
		
		--****** Audio out
		audio		: out std_logic_vector(0 to 1)
    );
end c2sb_demo;

architecture minimal of c2sb_demo is


--##############################################################################
-- Parameters

-- Address size (FIXME: not tested with other values)
constant SRAM_ADDR_SIZE : integer := 32;

-- Clock rate selection (affects UART configuration)
-- Acceptable values: {27000000, 50000000, 45000000(pll config)}
constant CLOCK_FREQ : integer := 12000000;

--##############################################################################
-- RS232 interface signals

signal rx_rdy :             std_logic;
signal tx_rdy :             std_logic;
signal rs232_data_rx :      std_logic_vector(7 downto 0);
signal rs232_status :       std_logic_vector(7 downto 0);
signal data_io_out :        std_logic_vector(7 downto 0);
signal io_port :            std_logic_vector(7 downto 0);
signal read_rx :            std_logic;
signal write_tx :           std_logic;


--##############################################################################
-- I/O registers


signal p0_out :             std_logic_vector(31 downto 0);
signal p1_in :              std_logic_vector(31 downto 0);

signal sd_clk_reg :         std_logic;
signal sd_cs_reg :          std_logic;
signal sd_cmd_reg :         std_logic;
signal sd_do_reg :          std_logic;


-- CPU access to hex display
signal reg_display :        std_logic_vector(15 downto 0);


--##############################################################################
-- DE-1 board interface signals

-- Synchronization FF chain for asynchronous reset input
signal reset_sync :         std_logic_vector(3 downto 0);

-- Reset pushbutton debouncing logic
subtype t_debouncer is natural range 0 to CLOCK_FREQ*4;
constant DEBOUNCING_DELAY : t_debouncer := 1500;
signal debouncing_counter : t_debouncer := (CLOCK_FREQ/1000) * DEBOUNCING_DELAY;

-- Quad 7-segment display (non multiplexed) & LEDS
signal display_data :       std_logic_vector(15 downto 0);
signal reg_gleds :          std_logic_vector(7 downto 0);

-- Clock & reset signals
signal clk_1hz :            std_logic;
signal clk_master :         std_logic;
signal counter_1hz :        std_logic_vector(25 downto 0);
signal reset :              std_logic;
-- Master clock signal
signal clk :                std_logic;
-- Clock from PLL, is a PLL is used
signal clk_pll :            std_logic;
-- '1' when PLL is locked or when no PLL is used
signal pll_locked :         std_logic;

-- Altera PLL component declaration (in case it's used)
-- Note that the MegaWizard component needs to be called 'pll' or the component
-- name should be changed in this file.
--component pll
--    port (
--        areset      : in std_logic  := '0';
--        inclk0      : in std_logic  := '0';
--        c0          : out std_logic ;
--        locked      : out std_logic
--    );
--end component;

-- MPU interface signals
signal data_uart :          std_logic_vector(31 downto 0);
signal data_uart_status :   std_logic_vector(31 downto 0);
signal uart_tx_rdy :        std_logic := '1';
signal uart_rx_rdy :        std_logic := '1';

--signal io_rd_data :         std_logic_vector(31 downto 0);
--signal io_rd_addr :         std_logic_vector(31 downto 2);
--signal io_wr_addr :         std_logic_vector(31 downto 2);
--signal io_wr_data :         std_logic_vector(31 downto 0);
--signal io_rd_vma :          std_logic;
--signal io_byte_we :         std_logic_vector(3 downto 0);

signal mpu_sram_address :   std_logic_vector(SRAM_ADDR_SIZE-1 downto 0);
signal mpu_sram_data_rd :   std_logic_vector(15 downto 0);
signal mpu_sram_data_wr :   std_logic_vector(15 downto 0);
signal mpu_sram_byte_we_n : std_logic_vector(1 downto 0);
signal mpu_sram_oe_n :      std_logic;

signal debug_info :         t_debug_info;

-- Converts hex nibble to 7-segment
-- Segments ordered as "GFEDCBA"; '0' is ON, '1' is OFF
function nibble_to_7seg(nibble : std_logic_vector(3 downto 0))
                        return std_logic_vector is
begin
    case nibble is
    when X"0"       => return "1111110";
    when X"1"       => return "0110000";
    when X"2"       => return "1101101";
    when X"3"       => return "1111001";
    when X"4"       => return "0110011";
    when X"5"       => return "1011011";
    when X"6"       => return "1011111";
    when X"7"       => return "1110000";
    when X"8"       => return "1111111";
    when X"9"       => return "1111011";
    when X"a"       => return "1110111";
    when X"b"       => return "0011111";
    when X"c"       => return "1001110";
    when X"d"       => return "0111101";
    when X"e"       => return "1001111";
    when X"f"       => return "1000111";
    when others     => return "1000000"; -- can't happen
    end case;
end function nibble_to_7seg;


begin

    mpu: entity work.mips_soc
    generic map (
        OBJECT_CODE    => obj_code,
        BOOT_BRAM_SIZE => work.obj_code_pkg.BRAM_SIZE,
        CLOCK_FREQ     => CLOCK_FREQ,
        SRAM_ADDR_SIZE => SRAM_ADDR_SIZE
    )
    port map (
        interrupt   => "00000000",

        -- interface to off-SoC, on-FPGA i/o devices: UNUSED
        io_rd_data  => X"00000000",
        io_rd_addr  => OPEN,
        io_wr_addr  => OPEN,
        io_wr_data  => OPEN,
        io_rd_vma   => OPEN,
        io_byte_we  => OPEN,

        -- interface to asynchronous 16-bit-wide EXTERNAL SRAM
        sram_address    => mpu_sram_address,
        sram_data_rd    => mpu_sram_data_rd,
        sram_data_wr    => mpu_sram_data_wr,
        sram_byte_we_n  => mpu_sram_byte_we_n,
        sram_oe_n       => mpu_sram_oe_n,

        uart_rxd    => rxd,
        uart_txd    => txd,

        p0_out      => p0_out,
        p1_in       => p1_in,
        
        debug_info  => debug_info,
        
        clk         => clk,
        reset       => reset
    );

    

--##############################################################################
-- GPIO and LEDs
--##############################################################################

---- LEDS -- We'll use the LEDs to display debug info --------------------------

-- HEX display is mostly unused
reg_display <= p0_out(31 downto 16);


-- Show the SD interface signals on the green leds for debug
--reg_gleds <= p1_in(0) & "0000" & p0_out(2 downto 0);

-- Red leds (light with '1') -- some CPU control signals
led_rgb(0) <= debug_info.cache_enabled;
led_rgb(1) <= debug_info.unmapped_access;
-- led_rgb(8) <= reset;
led_rgb(2) <= clk_1hz;


--##############################################################################
-- terasIC Cyclone II STARTER KIT BOARD -- interface to on-board devices
--##############################################################################


--##############################################################################
-- SRAM
--##############################################################################

sram_addr <= mpu_sram_address(sram_addr'high+1 downto 1);
sram_oe_n <= '0'    
    when mpu_sram_address(31 downto 27)="00000" and mpu_sram_oe_n='0'
    else '1';

sram_ub_n <= mpu_sram_byte_we_n(1) and mpu_sram_oe_n;
sram_lb_n <= mpu_sram_byte_we_n(0) and mpu_sram_oe_n;
sram_ce_n <= '0';
sram_we_n <= mpu_sram_byte_we_n(1) and mpu_sram_byte_we_n(0);

sram_data <= mpu_sram_data_wr when mpu_sram_byte_we_n/="11" else (others => 'Z');

-- The only reason we need this mux is because we have the static RAM and the
-- static flash in separate FPGA pins, whereas in a real world application they
-- would be on the same data+address bus
mpu_sram_data_rd <= sram_data;

--##############################################################################
-- RESET, CLOCK
--##############################################################################


-- This FF chain only prevents metastability trouble, it does not help with
-- switching bounces.
-- (NOTE: the anti-metastability logic is probably not needed when we include 
-- the debouncing logic)
reset_synchronization:
process(clk)
begin
    if clk'event and clk='1' then
        reset_sync(3) <= not button;
        reset_sync(2) <= reset_sync(3);
        reset_sync(1) <= reset_sync(2);
        reset_sync(0) <= reset_sync(1);
    end if;
end process reset_synchronization;

reset_debouncing:
process(clk)
begin
    if clk'event and clk='1' then
        if reset_sync(0)='1' and reset_sync(1)='0' then
            debouncing_counter <= (CLOCK_FREQ/1000) * DEBOUNCING_DELAY;
        else
            if debouncing_counter /= 0 then
                debouncing_counter <= debouncing_counter - 1;
            end if;
        end if;
    end if;
end process reset_debouncing;

-- Reset will be active and glitch free for some serious time (1.5 s).
reset <= '1' when debouncing_counter /= 0 or pll_locked='0' else '0';

-- Generate a 1-Hz 'clock' to flash a LED for visual reference.
process(clk)
begin
  if clk'event and clk='1' then
    if reset = '1' then
      clk_1hz <= '0';
      counter_1hz <= (others => '0');
    else
      if conv_integer(counter_1hz) = CLOCK_FREQ-1 then
        counter_1hz <= (others => '0');
        clk_1hz <= not clk_1hz;
      else
        counter_1hz <= counter_1hz + 1;
      end if;
    end if;
  end if;
end process;

-- Master clock is external 50MHz or 27MHz oscillator

clk <= clk_ext;

--##############################################################################
-- LEDS, SWITCHES
--##############################################################################

-- Display the contents of a debug register at the green leds bar
--green_leds <= reg_gleds;


--##############################################################################
-- QUAD 7-SEGMENT DISPLAYS
--##############################################################################

-- Show contents of debug register in hex display
display_data <= reg_display;
    

-- 7-segment encoders; the dev board displays are not multiplexed or encoded
--hex3 <= nibble_to_7seg(display_data(15 downto 12));
--hex2 <= nibble_to_7seg(display_data(11 downto  8));
seg_led_h(0 to 6) <= nibble_to_7seg(display_data( 7 downto  4));
seg_led_l(0 to 6) <= nibble_to_7seg(display_data( 3 downto  0));

seg_led_h(7) <= '1';
seg_led_h(8) <= '1';
seg_led_l(7) <= '1';
seg_led_l(8) <= '1';

--##############################################################################
-- SD card interface
--##############################################################################

-- Connect to FFs for use in bit-banged interface (still unused)
mss    <= p0_out(0);       -- SPI CS
mosi    <= p0_out(2);       -- SPI DI
msck  <= p0_out(1);       -- SPI SCLK
p1_in(0)    <= miso ;    -- SPI DO


--##############################################################################
-- SERIAL
--##############################################################################

--  Embedded in the MPU entity

end minimal;

--------------------------------------------------------------------------------
-- NOTE: Optional use of a PLL
-- 
-- In order to try the core with any clock other the 50 and 27MHz oscillators 
-- readily available onboard we need to use a PLL.
-- Unfortunately, Quartus-II won't let you just instantiate a PLL like ISE does.
-- Instead, you have to build a PLL module using the MegaWizard tool.
-- A nasty consequence of this is that the PLL can't be reconfigured without
-- rebuilding it with the MW tool, and a bunch of ugly binary files have to be 
-- committed to SVN if the project is to be complete.
-- When I figure up what files need to be committed to SVN I will. Meanwhile you
-- have to build the module yourself if you want to u se a PLL -- Sorry!
-- At least it is very straightforward -- create an ALTPLL variation (from the 
-- IO module library) named 'pll' with a 45MHz clock at output c0, that's it.
--
-- Please note that the system will run at >50MHz when using 'balanced' 
-- synthesis. Only the 'area optimized' synthesis may give you trouble.
--------------------------------------------------------------------------------
