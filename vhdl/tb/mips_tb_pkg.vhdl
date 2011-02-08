--------------------------------------------------------------------------------
-- mips_tb_pkg.vhdl -- Functions and data for the simulation test benches.
--------------------------------------------------------------------------------
-- Most of this file deals with the 'simulation log': the CPU execution history
-- is logged to a text file for easy comparison to a similaro log written by the
-- software simulator. This is meant as a debugging tool and is explained to 
-- some detail in the project doc.
-- It is used as a verification tool at least while no better verification test
-- bench exists.
--------------------------------------------------------------------------------
-- FIXME Console logging code should be here too
--------------------------------------------------------------------------------
-- WARNING: 
-- This package contains arguably the worst code of the project; in order
-- to expedite things, a number of trial-and-error hacks have been performed on
-- the code below. Mostly, the adjustment of the displayed PC.
-- This is just the kind of hdl you don't want prospective employers to see :)
-- 
-- The problem is: each change in the CPU state is logged in a text line, in 
-- which the address of the instruction that caused the change is included. 
-- From outside the CPU it is not always trivial to find out what instruction
-- caused what change (pipeline delays, cache stalls, etc.). 
-- I think the logging rules should be pretty stable now but I might have to
-- tweak them again as the cache implementation changes. Eventually I aim to
-- make this code fully independent of the cache implementation; it should
-- only depend on the cpu. I will do this step by step, as I do all the rest.
--------------------------------------------------------------------------------

library ieee,modelsim_lib;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.mips_pkg.all;

use modelsim_lib.util.all;
use std.textio.all;
use work.txt_util.all;


package mips_tb_pkg is

type t_pc_queue is array(0 to 3) of t_word;

type t_log_info is record
    rbank :                 t_rbank;
    prev_rbank :            t_rbank;
      
    cp0_epc :               t_pc;
    prev_epc :              t_pc;
    
    pc_m :                  t_pc_queue;
    
    reg_hi, reg_lo :        t_word;
    prev_hi, prev_lo :      t_word;
    negate_reg_lo :         std_logic;
    mdiv_count_reg :        std_logic_vector(5 downto 0);
    prev_count_reg :        std_logic_vector(5 downto 0);
    
    data_rd_vma :           std_logic;
    code_rd_vma :           std_logic;
    data_byte_we :          std_logic_vector(3 downto 0);

    present_data_wr_addr :  t_pc;
    present_data_wr :       t_word;
    present_data_rd_addr :  t_word;
    present_code_rd_addr :  t_pc;
    
    pending_data_rd_addr :  t_word;
    pending_data_wr_addr :  t_word;
    pending_data_wr_pc :    t_word;
    pending_data_wr :       t_word;
    pending_data_wr_we :    std_logic_vector(3 downto 0);
    
    word_loaded :           t_word;
    
    mdiv_address :          t_word;
    mdiv_pending :          boolean;
    
    data_rd_address :       t_word;
    load :                  std_logic;
    
    read_pending :          boolean;
    write_pending :         boolean;
end record t_log_info;

procedure log_cpu_activity(
                signal clk :    in std_logic;
                signal reset :  in std_logic;
                signal done :   in std_logic;
                entity_name :   string;
                signal info :   inout t_log_info; 
                signal_name :   string;
                file l_file :   TEXT);


end package;

package body mips_tb_pkg is

procedure log_cpu_status(
                signal info :   inout t_log_info; 
                file l_file :   TEXT) is
variable i : integer;
variable ri : std_logic_vector(7 downto 0);
variable full_pc, temp, temp2 : t_word;
variable k : integer := 2;
begin
    
    -- This is the address of the opcode that triggered the changed we're
    -- about to log
    full_pc := info.pc_m(k);
    
    
    -- Log activity only at the 1st cycle of each instruction
    if info.code_rd_vma='1' then
        
        -- Log register changes -------------------------------------
        ri := X"00";
        for i in 0 to 31 loop
            if info.prev_rbank(i)/=info.rbank(i) 
               and info.prev_rbank(i)(0)/='U' then    
                print(l_file, "("& hstr(full_pc)& ") "& 
                      "["& hstr(ri)& "]="& hstr(info.rbank(i)));
            end if;
            ri := ri + 1;
        end loop;        

        -- Log memory writes ----------------------------------------
        if info.write_pending then

            ri := X"0" & info.pending_data_wr_we;
            temp := info.pending_data_wr;
            if info.pending_data_wr_we(3)='0' then
                temp := temp and X"00ffffff";
            end if;
            if info.pending_data_wr_we(2)='0' then
                temp := temp and X"ff00ffff";
            end if;
            if info.pending_data_wr_we(1)='0' then
                temp := temp and X"ffff00ff";
            end if;
            if info.pending_data_wr_we(0)='0' then
                temp := temp and X"ffffff00";
            end if;
            print(l_file, "("& hstr(info.pending_data_wr_pc) &") ["& 
                  hstr(info.pending_data_wr_addr) &"] |"& 
                  hstr(ri)& "|="& 
                  hstr(temp)& " WR" );    
            info.write_pending <= false;
        end if;   


        -- Log memory reads ------------------------------------------
        if info.read_pending and info.load='1' then
            print(l_file, "("& hstr(info.pc_m(1)) &") ["& 
                  hstr(info.pending_data_rd_addr) &"] <"& 
                  "**"& ">="& 
                  hstr(info.word_loaded)& " RD" ); -- FIXME
            info.read_pending <= false;
        end if;    
                           
        -- Log aux register changes ---------------------------------
        if info.prev_lo /= info.reg_lo and info.prev_lo(0)/='U' then
            -- Adjust opcode PC when LO came from the mul module
            if info.mdiv_pending then
                temp2 := info.mdiv_address;
                info.mdiv_pending <= false;
            else
                temp2 := info.pc_m(k-1);
            end if;
        
            -- we're observing the value of reg_lo, but the mult core
            -- will output the negated value in some cases. We
            -- have to mimic that behavior.
            if info.negate_reg_lo='1' then
                -- negate reg_lo before displaying
                temp := not info.reg_lo;
                temp := temp + 1;
                print(l_file, "("& hstr(temp2)& ") [LO]="& hstr(temp));
            else
                print(l_file, "("& hstr(temp2)& ") [LO]="& hstr(info.reg_lo));
            end if;
        end if;
        if info.prev_hi /= info.reg_hi and info.prev_hi(0)/='U' then
            -- Adjust opcode PC when HI came from the mul module
            if info.mdiv_pending then
                temp2 := info.mdiv_address;
                info.mdiv_pending <= false;
            else
                temp2 := info.pc_m(k-1);
            end if;

            print(l_file, "("& hstr(temp2)& ") [HI]="& hstr(info.reg_hi));
        end if;                
                       
        if info.prev_epc /= info.cp0_epc and info.cp0_epc(31)/='U'  then
            temp := info.cp0_epc & "00";
            print(l_file, "("& hstr(info.pc_m(k-1))& ") [EP]="& hstr(temp));
            info.prev_epc <= info.cp0_epc;
        end if;

                       
        -- Save present cycle info to compare the next cycle --------
        info.prev_rbank <= info.rbank;
        info.prev_hi <= info.reg_hi;
        info.prev_lo <= info.reg_lo;
        
        info.pc_m(3) <= info.pc_m(2);
        info.pc_m(2) <= info.pc_m(1);
        info.pc_m(1) <= info.pc_m(0);
        info.pc_m(0) <= info.present_code_rd_addr & "00";
        
    end if;

    if info.data_byte_we/="0000" then
        info.write_pending <= true;
        info.pending_data_wr_we <= info.data_byte_we;
        info.pending_data_wr_addr <= info.present_data_wr_addr & "00";
        info.pending_data_wr_pc <= info.pc_m(k-1);
        info.pending_data_wr <= info.present_data_wr;
    end if;

    if info.data_rd_vma='1' then
        info.read_pending <= true;
        info.pending_data_rd_addr <= info.present_data_rd_addr;
    end if;
    
    if info.mdiv_count_reg="100000" then
        info.mdiv_address <= info.pc_m(1);
        info.mdiv_pending <= true;
    end if;

    info.prev_count_reg <= info.mdiv_count_reg;

end procedure log_cpu_status;

procedure log_cpu_activity(
                signal clk :    in std_logic;
                signal reset :  in std_logic;
                signal done :   in std_logic;   
                entity_name :   string;
                signal info :   inout t_log_info; 
                signal_name :   string;
                file l_file :   TEXT) is
begin
    init_signal_spy("/"&entity_name&"/p1_rbank", signal_name&".rbank", 0, -1);
    init_signal_spy("/"&entity_name&"/code_rd_addr", signal_name&".present_code_rd_addr", 0, -1);
    init_signal_spy("/"&entity_name&"/mult_div/upper_reg", signal_name&".reg_hi", 0, -1);
    init_signal_spy("/"&entity_name&"/mult_div/lower_reg", signal_name&".reg_lo", 0, -1);
    init_signal_spy("/"&entity_name&"/mult_div/negate_reg", signal_name&".negate_reg_lo", 0, -1);
    init_signal_spy("/"&entity_name&"/mult_div/count_reg", signal_name&".mdiv_count_reg", 0, -1);
    init_signal_spy("/"&entity_name&"/cp0_epc", signal_name&".cp0_epc", 0, -1);
    init_signal_spy("/"&entity_name&"/data_rd_vma", signal_name&".data_rd_vma", 0, -1);
    init_signal_spy("/"&entity_name&"/code_rd_vma", signal_name&".code_rd_vma", 0, -1);
    init_signal_spy("/"&entity_name&"/p2_do_load", signal_name&".load", 0, -1);
    init_signal_spy("/"&entity_name&"/data_wr_addr", signal_name&".present_data_wr_addr", 0, -1);
    init_signal_spy("/"&entity_name&"/data_wr", signal_name&".present_data_wr", 0, -1);
    init_signal_spy("/"&entity_name&"/byte_we", signal_name&".data_byte_we", 0, -1);
    init_signal_spy("/"&entity_name&"/p2_data_word_rd", signal_name&".word_loaded", 0, -1);
    init_signal_spy("/"&entity_name&"/data_rd_addr", signal_name&".present_data_rd_addr", 0, -1);

    while done='0' loop
        wait until clk'event and clk='1';
        if reset='1' then
            -- FIXME should use real reset vector here
            info.pc_m <= (others => X"00000000");
        else
            log_cpu_status(info, l_file);
        end if;
    end loop;
    

end procedure log_cpu_activity;



end package body;
