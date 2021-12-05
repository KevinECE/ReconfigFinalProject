library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.config_pkg.all;
use work.user_pkg.all;

entity kernel_buffer is
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;
        wr_en       : in  std_logic;
        rd_en       : in  std_logic;
        wr_data     : in  std_logic_vector(KERNEL_WIDTH_RANGE);     
        full        : out std_logic;        
        rd_data      : out window;
    )

architecture BHV of kernel_buffer is
    
    signal shift_reg : window;
    signal count : unsigned(KERNEL_SIZE_RANGE);
    begin
        process(clk, rst)
            if rst = '1' then
                for i in 0 to C_KERNEL_SIZE loop
                    shift_reg(i) <= (others => '0');
                count <= (others => '0');
                full <= '0';
            end loop;
            elsif rising_edge(clk) then
                -- once kernel buffer is full stop inputing data
                if count == C_KERNEL_SIZE then
                    full <= '1';
                else if wr_en == '1':
                    -- buffer is empty
                    full <= '0';
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
        end process;

        -- output
        rd_data <= shift_reg;

end BHV;