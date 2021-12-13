-- Ryan Laur
-- University of Florida
-- Entity: dram_rd_ram0
-- Description: 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.config_pkg.all;
use work.user_pkg.all;

entity dram_rd_ram0 is 
    port(
        -- user dma control signals
        dram_clk   : in  std_logic;
        user_clk   : in  std_logic;
        rst        : in  std_logic;
        clear      : in  std_logic;
        go         : in  std_logic;
        rd_en      : in  std_logic;
        stall      : in  std_logic;
        start_addr : in  std_logic_vector(C_RAM0_ADDR_WIDTH-1 downto 0);
        size       : in  std_logic_vector(RAM0_RD_SIZE_RANGE);
        valid      : out std_logic;
        data       : out std_logic_vector(RAM0_RD_DATA_RANGE);
        done       : out std_logic;

        -- dram control signals
        dram_ready    : in  std_logic;
        dram_rd_en    : out std_logic;
        dram_rd_addr  : out std_logic_vector(DRAM0_ADDR_RANGE);
        dram_rd_data  : in  std_logic_vector(DRAM0_DATA_RANGE);
        dram_rd_valid : in  std_logic;
        dram_rd_flush : out std_logic
    );
end dram_rd_ram0;

architecture DMA of dram_rd_ram0 is

    component fifo_generator_0
        port (
        rst         : in std_logic;
        wr_clk      : in std_logic;
        rd_clk      : in std_logic;
        din         : in std_logic_vector(C_RAM0_WR_DATA_WIDTH-1 downto 0);
        wr_en       : in std_logic;
        rd_en       : in std_logic;
        dout        : out std_logic_vector(C_RAM0_RD_DATA_WIDTH-1 downto 0);
        full        : out std_logic;
        empty       : out std_logic; 
        prog_full   : out std_logic
        );
     end component;        

    signal size_r           : std_logic_vector(RAM0_RD_SIZE_RANGE);
    signal start_addr_r     : std_logic_vector(C_RAM0_ADDR_WIDTH-1 downto 0);
    signal ack              : std_logic;
    signal go_sync          : std_logic;
    signal awk_signal       : std_logic;
    signal fifo_progfull    : std_logic; 
    signal fifo_full        : std_logic; 
    signal fifo_empty       : std_logic; 
    signal addr_done        : std_logic;
    signal fiforst          : std_logic;
    signal dram_rd_data_f   : std_logic_vector(DRAM0_DATA_RANGE);
    constant C0_rd_size          : std_logic_vector(RAM0_RD_SIZE_RANGE) := (others => '0');
    constant C0_rd_addr          : std_logic_vector(C_RAM0_ADDR_WIDTH-1 downto 0) := (others => '0');
    signal count_valid      : std_logic;

begin

    --------------------------------------- user_clk domain----------------------------------------------
    U_SIZE_REG : entity work.delay
    generic map (
        cycles => 1,
        width => C_RAM0_RD_SIZE_WIDTH,
        init => C0_rd_size
        )
    port map (
        clk    => user_clk,
        rst    => rst,
        en     => go,
        input  => size,
        output => size_r
        );

    U_START_ADDR_REG : entity work.delay
    generic map (
        cycles => 1,
        width => C_RAM0_ADDR_WIDTH,
        init => C0_rd_addr
        )
    port map (
        clk    => user_clk,
        rst    => rst,
        en     => go,
        input  => start_addr,
        output => start_addr_r
        );

    U_GO_SYNC : entity work.handshake
    port map (
        clk_src   => dram_clk,
        clk_dest  => user_clk,
        rst       => rst,
        go        => go,
        rcv       => go_sync,
        ack       => awk_signal,
        delay_ack => C_0
        );   

    --------------------------------------- dram_clk domain----------------------------------------------
    U_ADDR_GEN : entity work.addr_gen
    port map (
        dram_clk        => dram_clk,
        rst             => rst,
        go              => go_sync,
        size            => size_r,
        start_addr      => start_addr_r,
        valid           => dram_rd_en,
        dram_rd_addr    => dram_rd_addr,
        dram_ready      => dram_ready,
        done            => addr_done,
        stall           => fifo_progfull
        );
    
    -- write width of 32 bits and read width of 16 bits
    U_FIFO_32_PROG_FULL : fifo_generator_0
    port map (
		rst 		=> fiforst,
		wr_clk 		=> dram_clk,
		rd_clk 		=> user_clk,
		din 		=> dram_rd_data_f,
		wr_en 		=> dram_rd_valid,
		rd_en 		=> rd_en,
		dout 		=> data,
		full 		=> fifo_full,
		empty 		=> fifo_empty,
		prog_full 	=> fifo_progfull
		);
		
	
	
    U_COUNTER : entity work.counter
    port map(
        clk => user_clk,
        rst => rst,
        en => rd_en,
        valid => count_valid,
        go => go,
        size => size_r,
        done => done
    );
    
    fiforst <= rst or clear;
    dram_rd_flush <= (clear or go_sync) and (not(rst));
    dram_rd_data_f <= dram_rd_data(15 downto 0) & dram_rd_data(31 downto 16);
    valid <= not(fifo_empty);
    count_valid <= not(fifo_empty);
end DMA;