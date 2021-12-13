library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.config_pkg.all;
use work.user_pkg.all;

entity smart_buffer is
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;
        wr_en       : in  std_logic;
        rd_en       : in  std_logic;
        wr_data     : in  std_logic_vector(KERNEL_WIDTH_RANGE);
        empty       : out std_logic;        
        full        : out std_logic;        
        rd_data     : out window(KERNEL_SIZE_RANGE));
end smart_buffer;

architecture BHV of smart_buffer is
    
    signal shift_reg : window(KERNEL_SIZE_RANGE);
    signal count : unsigned(KERNEL_SIZE_RANGE);

begin
    process(clk, rst)
    begin
        if rst = '1' then
            count <= (others => '0');
            for i in 0 to C_KERNEL_SIZE-1 loop
                shift_reg(i) <= (others => '0');
            end loop;
           elsif rising_edge(clk) then
                -- pipeline can read whenever buffer isn't empty
                if count = C_KERNEL_SIZE then  
                    -- check if buffer is full (not empty and data not being read)
                    if rd_en = '1' then
                        -- shift register data
                        for i in C_KERNEL_SIZE-1 downto 1 loop
                            shift_reg(i-1) <= shift_reg(i);
                        end loop;

                        -- write to buffer if enabled 
                        if wr_en = '1' then
                            -- read in new wr_data
                            shift_reg(C_KERNEL_SIZE-1) <= wr_data;
--                       else
--                           count <= count - 1;
--                            shift_reg(C_KERNEL_SIZE-1) <= (others => '0');
                       end if;
                    end if;
                    -- write to buffer if enabled
                    if wr_en = '1' then
                        -- read in new wr_data
                        shift_reg(C_KERNEL_SIZE-1) <= wr_data;
                    end if;

                -- fill empty buffer with data until count = 128
                else 
                    -- write to buffer if enabled
                    if wr_en = '1' then
                        -- increment count
                        count <= count + 1;
                        -- shift register data left by 1
                        for i in C_KERNEL_SIZE-1 downto 1 loop
                            shift_reg(i-1) <= shift_reg(i);
                        end loop;
                        -- read in new wr_data
                        shift_reg(C_KERNEL_SIZE-1) <= wr_data;
                    end if;
                end if;
            end if;
        end process;

        -- empty logic
        empty <= '0' when (count = C_KERNEL_SIZE) else '1'; 
        -- full logic
        full <= '1' when ((count = C_KERNEL_SIZE) and rd_en = '0') else '0';
        -- output
        rd_data <= shift_reg;
end BHV;