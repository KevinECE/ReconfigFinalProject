-- Ryan Laur
-- University of Florida

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity counter is
    port (
        clk     : in  std_logic;
        rst     : in  std_logic;
        go      : in  std_logic;
        en      : in  std_logic; 
        valid   : in  std_logic;
        size    : in  std_logic_vector(16 downto 0);        
        done    : out std_logic
        );
end counter;

architecture BHV of counter is

    signal count_s : unsigned(16 downto 0);
    type state_type is (S_START, S_UPDATE, S_WAIT, S_CHECK);
    signal state : state_type;

begin
    process (clk, rst)
        variable count_var : unsigned(16 downto 0);
    begin
        if (rst = '1') then           
            count_s <= (others => '0');
            count_var   := (others => '0');
            done <= '0';
            state       <= S_START;
        elsif (rising_edge(clk)) then
            count_s <= count_var;    
            done <= '0';
            case state is        
                when S_START =>     
                    count_var   := (others => '0');
                    state <= S_UPDATE;
    
                -- ***********************************************************    
                when S_UPDATE =>
                    if (en = '1' and valid = '1') then
                        count_var := count_var + 1;
                    end if;   
                    if (count_var = unsigned(size)) then
                        done <= '1';
                        state <= S_WAIT; 
                    else
                        state <= S_UPDATE;  
                    end if;         
                               
                when S_WAIT =>
                    done <= '1';
                    if (go = '1') then 
                        state <= S_START;
                    end if;
                when others => null;
            end case;       
        end if;
    end process;
end BHV;