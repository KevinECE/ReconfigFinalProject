-- Kevin McGrath
-- Reconfig 

library ieee;
use ieee.std_logic_1164.all;

entity dual_flop is
    port (
        clk_src  : in std_logic;
        clk_dest : in std_logic;
        rst      : in std_logic;
        input    : in std_logic;
        output   : out std_logic);
end dual_flop;

architecture STR of dual_flop is

    signal src_to_dst1, dst1_to_dst2 : std_logic;

begin

    -- Source flip-flop already synthesized in handshake.vhd -> assigning signals on clock edge
    --U_SourceFF : entity work.dual_flop_reg
    --port map (clk_src, rst, input, src_to_dst1);
	src_to_dst1 <= input;

    -- Destination flip-flops
    U_DestFF1 : entity work.dual_flop_reg
    port map (clk_dest, rst, src_to_dst1, dst1_to_dst2);

    U_DestFF2 : entity work.dual_flop_reg
    port map (clk_dest, rst, dst1_to_dst2, output);

end STR;