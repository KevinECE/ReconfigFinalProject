-- Ryan Laur and Kevin McGrath
-- University of Florida
-- Description: This entity implements a address generator to 
-- increment an address from a starting address, until it
-- reaches a specified size. This address generator takes in
-- a 16-bit size, but divides it by two to account for a
-- 32-bit RAM size. 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.config_pkg.all;
use work.user_pkg.all;

entity addr_gen is
    port (
        dram_clk        : in  std_logic; -- this entity uses the dram clock domain
        rst             : in  std_logic;
        go              : in  std_logic;
        size            : in  std_logic_vector(RAM0_RD_SIZE_RANGE);
        start_addr      : in  std_logic_vector(RAM0_ADDR_RANGE); 
        dram_ready      : in  std_logic; -- dram is ready to read
        valid           : out std_logic; -- address is valid, connect to dram_rd_en
        dram_rd_addr    : out std_logic_vector(DRAM0_ADDR_RANGE);
        done            : out std_logic;
        stall           : in  std_logic -- used for the fifo_program full
    );
end addr_gen;

architecture BHV of addr_gen is

    type state_type is (S_START, S_UPDATE, S_CHECK_READY, S_DONE);
    signal state, next_state : state_type;

    signal addr_s, next_addr_s, count_s, next_count_s     : std_logic_vector(C_RAM0_ADDR_WIDTH+1 downto 0);
    signal size_s, next_size_s : std_logic_vector(C_RAM0_ADDR_WIDTH+1 downto 0);
    constant max_size : unsigned(C_RAM0_ADDR_WIDTH+1 downto 0) := to_unsigned(32767,C_RAM0_ADDR_WIDTH+2);


begin  -- BHV

    process (dram_clk, rst)
    begin
        if (rst = '1') then
            addr_s <= (others => '0');
            size_s <= (others => '0');
            count_s <= (others => '0');
            state       <= S_START;
        elsif (rising_edge(dram_clk)) then
            addr_s   <= next_addr_s;
            size_s   <= next_size_s;
            count_s  <= next_count_s;
            state       <= next_state;
        end if;
    end process;

    process(addr_s, size_s, count_s, start_addr, state, go, dram_ready, size, stall)
    begin        
        next_size_s     <= size_s;
        next_addr_s     <= addr_s;
        next_count_s    <= count_s;
        done            <= '1';
        valid           <= '0';
        next_state      <= state;
        
        case state is
            -- ***********************************************************
            --
            -- S_START - Waits until the "go" signal is asserted.
            --
            -- ***********************************************************
            when S_START =>     
                valid       <= '0';
                next_addr_s <= (others => '0');
                next_count_s <= (others => '0');
                if (go = '1') then
                    done        <= '0';
                    next_state  <= S_CHECK_READY;
                end if;

            -- ***********************************************************
            --
            -- S_CHECK_READY - Sets start address and the size after
            -- dram_ready is asserted. 
            --
            -- ***********************************************************    

            when S_CHECK_READY =>
                
                valid <= '0';
                done <= '0';
                if (dram_ready = '1') then
                    done <= '0';
                    next_addr_s <= std_logic_vector(resize(unsigned(start_addr),C_RAM0_ADDR_WIDTH+2));
                    next_count_s <= (others => '0');
                    -- converts from 16-bit size to 32-bit size for the RAM
                    next_size_s <= std_logic_vector(resize(shift_right(unsigned(size), 1),C_RAM0_ADDR_WIDTH+2));
                    next_state <= S_UPDATE;
                end if;

            -- ***********************************************************
            --
            -- S_UPDATE - Asserts valid until the address is equal to 
            -- size. Increments the address if stall is not asserted,
            -- and sets valid to '0' if stall is asserted. 
            --
            -- ***********************************************************    
            when S_UPDATE =>

                done  <= '0';
                valid <= '1';

                if (unsigned(count_s) = unsigned(size_s)) then
                    --done        <= '1';
                    --valid       <= '0';
                    next_state  <= S_DONE;
                
                elsif (stall = '0') then
                    next_count_s <= std_logic_vector(unsigned(count_s)+1);
                    if (unsigned(addr_s) = max_size) then
                        next_addr_s <= (others => '0');
                    else
                        next_addr_s <= std_logic_vector(unsigned(addr_s)+1);
                    end if;
                elsif (stall = '1') then
                    valid <= '0';
                end if;
            when S_DONE =>
                done        <= '1';
                valid       <= '0';
                next_state <= S_START;
            when others => null;
        end case;

    end process;

    dram_rd_addr <= addr_s(DRAM0_ADDR_RANGE);

end BHV;
