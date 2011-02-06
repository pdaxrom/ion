--------------------------------------------------------------------------------
-- This file was generated automatically from '/src/mips_mpu2_template.vhdl'.
--------------------------------------------------------------------------------
-- Synthesizable MPU -- CPU + cache + bootstrap BRAM + UART
--
-- This module uses the 'stub' version of the cache: a cache which actually is 
-- only an interface between the cpu and external static memory. This is useful 
-- to test external memory interface and cache-cpu interface without the cache
-- functionality getting in the way.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.mips_pkg.all;

entity mips_mpu is
    generic (
        SRAM_ADDR_SIZE : integer := 17
    );
    port(
        clk             : in std_logic;
        reset           : in std_logic;
        interrupt       : in std_logic;
        
        -- interface to FPGA i/o devices
        io_rd_data      : in std_logic_vector(31 downto 0);
        io_rd_addr      : out std_logic_vector(31 downto 2);
        io_wr_addr      : out std_logic_vector(31 downto 2);
        io_wr_data      : out std_logic_vector(31 downto 0);
        io_rd_vma       : out std_logic;
        io_byte_we      : out std_logic_vector(3 downto 0);
        
        -- interface to asynchronous 16-bit-wide EXTERNAL SRAM
        sram_address    : out std_logic_vector(SRAM_ADDR_SIZE downto 1);
        sram_databus    : inout std_logic_vector(15 downto 0);
        sram_byte_we_n  : out std_logic_vector(1 downto 0);
        sram_oe_n       : out std_logic;

        -- UART 
        uart_rxd        : in std_logic;
        uart_txd        : out std_logic
    );
end; --entity mips_mpu

architecture rtl of mips_mpu is


signal reset_sync :         std_logic_vector(2 downto 0);

-- interface cpu-cache
signal cpu_data_rd_addr :   t_word;
signal cpu_data_rd_vma :    std_logic;
signal cpu_data_rd :        t_word;
signal cpu_code_rd_addr :   t_pc;
signal cpu_code_rd :        t_word;
signal cpu_code_rd_vma :    std_logic;
signal cpu_data_wr_addr :   t_pc;
signal cpu_data_wr :        t_word;
signal cpu_byte_we :        std_logic_vector(3 downto 0);
signal cpu_mem_wait :       std_logic;

-- interface to i/o
signal mpu_io_rd_data :     std_logic_vector(31 downto 0);
signal mpu_io_wr_data :     std_logic_vector(31 downto 0);
signal mpu_io_rd_addr :     std_logic_vector(31 downto 2);
signal mpu_io_wr_addr :     std_logic_vector(31 downto 2);
signal mpu_io_rd_vma :      std_logic;
signal mpu_io_byte_we :     std_logic_vector(3 downto 0);

-- interface to UARTs
signal data_uart :          t_word;
signal data_uart_status :   t_word;
signal uart_tx_rdy :        std_logic := '1';
signal uart_rx_rdy :        std_logic := '1';
signal uart_write_tx :      std_logic;
signal uart_read_rx :       std_logic;


-- Block ram
constant BRAM_SIZE : integer := 1024;
constant BRAM_ADDR_SIZE : integer := log2(BRAM_SIZE);

--type t_bram is array(0 to BRAM_SIZE-1) of std_logic_vector(7 downto 0);
type t_bram is array(0 to (BRAM_SIZE)-1) of t_word;

-- bram0 is LSB, bram3 is MSB
--signal bram3 :              t_bram := (@ code3@);
--signal bram2 :              t_bram := (@ code2@);
--signal bram1 :              t_bram := (@ code1@);
--signal bram0 :              t_bram := (@ code0@);

signal bram :               t_bram := (
    X"3C1C8000",X"279C7FF0",X"3C058000",X"24A50000",
    X"3C048000",X"24840200",X"3C1D8000",X"27BD01E8",
    X"ACA00000",X"00A4182A",X"1460FFFD",X"24A50004",
    X"0C00008B",X"00000000",X"0800000E",X"23BDFF98",
    X"AFA10010",X"AFA20014",X"AFA30018",X"AFA4001C",
    X"AFA50020",X"AFA60024",X"AFA70028",X"AFA8002C",
    X"AFA90030",X"AFAA0034",X"AFAB0038",X"AFAC003C",
    X"AFAD0040",X"AFAE0044",X"AFAF0048",X"AFB8004C",
    X"AFB90050",X"AFBF0054",X"401A7000",X"235AFFFC",
    X"AFBA0058",X"0000D810",X"AFBB005C",X"0000D812",
    X"AFBB0060",X"3C062000",X"8CC40020",X"00000000",
    X"8CC60010",X"00000000",X"00862024",X"0C0000E0",
    X"23A50000",X"8FA10010",X"8FA20014",X"8FA30018",
    X"8FA4001C",X"8FA50020",X"8FA60024",X"8FA70028",
    X"8FA8002C",X"8FA90030",X"8FAA0034",X"8FAB0038",
    X"8FAC003C",X"8FAD0040",X"8FAE0044",X"8FAF0048",
    X"8FB8004C",X"8FB90050",X"8FBF0054",X"8FBA0058",
    X"8FBB005C",X"00000000",X"03600011",X"8FBB0060",
    X"00000000",X"03600013",X"23BD0068",X"341B0001",
    X"03400008",X"409B6000",X"40026000",X"03E00008",
    X"40846000",X"00000000",X"00000000",X"3C050000",
    X"24A50188",X"8CA60000",X"00000000",X"AC06003C",
    X"8CA60004",X"00000000",X"AC060040",X"8CA60008",
    X"00000000",X"AC060044",X"8CA6000C",X"00000000",
    X"03E00008",X"AC060048",X"3C1A1000",X"375A003C",
    X"03400008",X"00000000",X"AC900000",X"AC910004",
    X"AC920008",X"AC93000C",X"AC940010",X"AC950014",
    X"AC960018",X"AC97001C",X"AC9E0020",X"AC9C0024",
    X"AC9D0028",X"AC9F002C",X"03E00008",X"34020000",
    X"8C900000",X"8C910004",X"8C920008",X"8C93000C",
    X"8C940010",X"8C950014",X"8C960018",X"8C97001C",
    X"8C9E0020",X"8C9C0024",X"8C9D0028",X"8C9F002C",
    X"00000000",X"03E00008",X"34A20000",X"00850019",
    X"00001012",X"00002010",X"03E00008",X"ACC40000",
    X"0000000C",X"03E00008",X"00000000",X"3C040000",
    X"27BDFFE8",X"AFBF0014",X"0C0000A1",X"248403DC",
    X"3C040000",X"0C0000A1",X"24840404",X"3C040000",
    X"8FBF0014",X"2484041C",X"080000A1",X"27BD0018",
    X"3C032000",X"8C620020",X"00000000",X"30420002",
    X"1040FFFC",X"3C022000",X"AC440000",X"03E00008",
    X"00001021",X"90850000",X"00000000",X"10A00011",
    X"2407000A",X"3C032000",X"3C062000",X"2408000D",
    X"10A7000E",X"00000000",X"24840001",X"8C620020",
    X"00000000",X"30420002",X"1040FFFC",X"00000000",
    X"ACC50000",X"90850000",X"00000000",X"14A0FFF4",
    X"00000000",X"03E00008",X"00001021",X"8C620020",
    X"00000000",X"30420002",X"1040FFFC",X"00000000",
    X"ACC80000",X"080000AB",X"24840001",X"2405001C",
    X"3C022000",X"3C082000",X"2407FFFC",X"00A43006",
    X"30C6000F",X"2CC3000A",X"1060000D",X"00000000",
    X"8C430020",X"00000000",X"30630002",X"1060FFFC",
    X"00000000",X"24C60030",X"24A5FFFC",X"AD060000",
    X"14A7FFF3",X"00A43006",X"03E00008",X"00000000",
    X"8C430020",X"00000000",X"30630002",X"1060FFFC",
    X"00000000",X"24C60057",X"24A5FFFC",X"AD060000",
    X"14A7FFE7",X"00A43006",X"03E00008",X"00000000",
    X"3C032000",X"8C620020",X"00000000",X"30420002",
    X"1040FFFC",X"3C022000",X"24030049",X"AC430000",
    X"03E00008",X"00000000",X"3C022000",X"8C420020",
    X"03E00008",X"30420001",X"3C032000",X"8C620020",
    X"00000000",X"30420001",X"1040FFFC",X"3C022000",
    X"8C420000",X"03E00008",X"00000000",X"636F6D70",
    X"696C6520",X"74696D65",X"3A204665",X"62202036",
    X"20323031",X"31202D2D",X"2032303A",X"31373A33",
    X"360A0000",X"67636320",X"76657273",X"696F6E3A",
    X"2020342E",X"342E310A",X"00000000",X"0A0A4865",
    X"6C6C6F20",X"576F726C",X"64210A0A",X"0A000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000",
    X"00000000",X"00000000",X"00000000",X"00000000"
    );

subtype t_bram_address is std_logic_vector(BRAM_ADDR_SIZE-1 downto 0);

signal bram_rd_addr :       t_bram_address; 
signal bram_wr_addr :       t_bram_address;
signal bram_rd_data :       t_word;
signal bram_wr_data :       t_word;
signal bram_byte_we :       std_logic_vector(3 downto 0);


--------------------------------------------------------------------------------
begin

cpu: entity work.mips_cpu
    port map (
        interrupt   => '0',
        
        data_rd_addr=> cpu_data_rd_addr,
        data_rd_vma => cpu_data_rd_vma,
        data_rd     => cpu_data_rd,
        
        code_rd_addr=> cpu_code_rd_addr,
        code_rd     => cpu_code_rd,
        code_rd_vma => cpu_code_rd_vma,
        
        data_wr_addr=> cpu_data_wr_addr,
        data_wr     => cpu_data_wr,
        byte_we     => cpu_byte_we,
    
        mem_wait    => cpu_mem_wait,
        
        clk         => clk,
        reset       => reset
    );

cache: entity work.mips_cache_stub
    generic map (
        BRAM_ADDR_SIZE => BRAM_ADDR_SIZE,
        SRAM_ADDR_SIZE => SRAM_ADDR_SIZE
    )
    port map (
        clk             => clk,
        reset           => reset,
        
        -- Interface to CPU core
        data_rd_addr    => cpu_data_rd_addr,
        data_rd         => cpu_data_rd,
        data_rd_vma     => cpu_data_rd_vma,
                        
        code_rd_addr    => cpu_code_rd_addr,
        code_rd         => cpu_code_rd,
        code_rd_vma     => cpu_code_rd_vma,
                        
        data_wr_addr    => cpu_data_wr_addr,
        byte_we         => cpu_byte_we,
        data_wr         => cpu_data_wr,
                        
        mem_wait        => cpu_mem_wait,
        cache_enable    => '1',
        
        -- interface to FPGA i/o devices
        io_rd_data      => mpu_io_rd_data,
        io_wr_data      => mpu_io_wr_data,
        io_rd_addr      => mpu_io_rd_addr,
        io_wr_addr      => mpu_io_wr_addr,
        io_rd_vma       => mpu_io_rd_vma,
        io_byte_we      => mpu_io_byte_we,
    
        -- interface to synchronous 32-bit-wide FPGA BRAM
        bram_rd_data    => bram_rd_data,
        bram_wr_data    => bram_wr_data,
        bram_rd_addr    => bram_rd_addr,
        bram_wr_addr    => bram_wr_addr,
        bram_byte_we    => bram_byte_we,
        
        -- interface to asynchronous 16-bit-wide external SRAM
        sram_address    => sram_address,
        sram_databus    => sram_databus,
        sram_byte_we_n  => sram_byte_we_n,
        sram_oe_n       => sram_oe_n
    );


--------------------------------------------------------------------------------
-- BRAM interface 

fpga_ram_block:
process(clk)
begin
    if clk'event and clk='1' then
            
        --bram_rd_data <= 
        --    bram3(conv_integer(unsigned(bram_rd_addr))) &
        --    bram2(conv_integer(unsigned(bram_rd_addr))) &
        --    bram1(conv_integer(unsigned(bram_rd_addr))) &
        --    bram0(conv_integer(unsigned(bram_rd_addr)));
        bram_rd_data <= bram(conv_integer(unsigned(bram_rd_addr)));
        
    end if;
end process fpga_ram_block;

-- FIXME this should be in parent block
reset_synchronization:
process(clk)
begin
    if clk'event and clk='1' then
        reset_sync(2) <= reset;
        reset_sync(1) <= reset_sync(2);
        reset_sync(0) <= reset_sync(1);
    end if;
end process reset_synchronization;

--------------------------------------------------------------------------------


--------------------------------------------------------------------------------

serial_rx : entity work.rs232_rx 
    port map(
        rxd =>      uart_rxd,
        data_rx =>  OPEN, --rs232_data_rx,
        rx_rdy =>   uart_rx_rdy,
        read_rx =>  '1', --read_rx,
        clk =>      clk,
        reset =>    reset_sync(0)
    );


uart_write_tx <= '1' 
    when mpu_io_byte_we/="0000" and mpu_io_wr_addr(31 downto 28)=X"2" 
    else '0';

serial_tx : entity work.rs232_tx 
    port map(
        clk =>      clk,
        reset =>    reset_sync(0),
        rdy =>      uart_tx_rdy,
        load =>     uart_write_tx,
        data_i =>   mpu_io_wr_data(7 downto 0),
        txd =>      uart_txd
    );

-- UART read registers; only status, and hardwired, for the time being
data_uart <= data_uart_status; -- FIXME no data rx yet
data_uart_status <= X"0000000" & "00" & uart_tx_rdy & uart_rx_rdy;

mpu_io_rd_data <= data_uart;

-- io_rd_data 
io_rd_addr <= mpu_io_rd_addr;
io_wr_addr <= mpu_io_wr_addr;
io_wr_data <= mpu_io_wr_data;
io_rd_vma <= mpu_io_rd_vma;
io_byte_we <= mpu_io_byte_we;


end architecture rtl;
