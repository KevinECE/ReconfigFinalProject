library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.config_pkg.all;
use work.user_pkg.all;

entity buffer is
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;
        wr_en       : in  std_logic;
        rd_en       : in  std_logic;
        wr_data     : in  std_logic_vector(KERNEL_WIDTH_RANGE);
        empty       : out std_logic;        
        full        : out std_logic;        
        rd_data     : out window;
    )

architecture BHV of buffer is
    
    signal shift_reg : window;
    signal count : unsigned(KERNEL_SIZE_RANGE);
    begin
        process(clk, rst)
            if rst = '1')then
                for i in 0 to C_KERNEL_SIZE loop
                    shift_reg(i) <= (others => '0');
                end loop;
                count <= (others => '0');
                empty <= '1';
                full  <= '0';
            end loop;
            elsif rising_edge(clk) then
                -- pipeline can read whenever buffer isn't empty
                if count == C_KERNEL_SIZE then
                    empty <= '0';   
                    -- check if buffer is full (not empty and data not being read)
                    if rd_en == '1' then
                        full <= '0';
                        -- shift register data
                        for i in 0 to C_KERNEL_SIZE-1 loop
                            shift_reg(i+1) <= shift_reg(i);
                        end loop;
                    else
                        full <= '1';

                    if wr_en == '1' then
                        cv-- read in new wr_data
                        shift_reg(0) <= wr_data;
                    end if;
                -- fill empty buffer with data
                else 
                    -- buffer is empty
                    empty <= '1';
                    full  <= '0';

                    if wr_en == '1' then
                        -- increment count
                        count <= count + 1;
                        -- read in new wr_data
                        shift_reg(0) <= wr_data;
                        -- shift register data
                        for i in 0 to C_KERNEL_SIZE-1 loop
                            shift_reg(i+1) <= shift_reg(i);
                    end loop;
                    end if;
                end if;
            end if;
        end process;

        -- output
        rd_data <= shift_reg;
end BHV;