-- Kevin McGrath
-- Reconfig 

library ieee;
use ieee.std_logic_1164.all;

entity dual_flop_reg is
  port (
    clk    : in  std_logic;
    rst    : in  std_logic;
    input  : in  std_logic;
    output : out std_logic);
end dual_flop_reg;

architecture BHV of dual_flop_reg is
begin
  process(clk, rst)
  begin
    if (clk'event and clk = '1') then
      if (rst = '1') then
        output <= '0';
      else
        output <= input;
      end if;
    end if;
  end process;
end BHV;
