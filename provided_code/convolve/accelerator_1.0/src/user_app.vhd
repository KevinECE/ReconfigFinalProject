-- Greg Stitt
-- University of Florida

library ieee;
use ieee.std_logic_1164.all;

use work.config_pkg.all;
use work.user_pkg.all;


entity user_app is
    port (
        clks   : in  std_logic_vector(NUM_CLKS_RANGE);
        rst    : in  std_logic;
        sw_rst : out std_logic;

        -- memory-map interface
        mmap_wr_en   : in  std_logic;
        mmap_wr_addr : in  std_logic_vector(MMAP_ADDR_RANGE);
        mmap_wr_data : in  std_logic_vector(MMAP_DATA_RANGE);
        mmap_rd_en   : in  std_logic;
        mmap_rd_addr : in  std_logic_vector(MMAP_ADDR_RANGE);
        mmap_rd_data : out std_logic_vector(MMAP_DATA_RANGE);

        -- DMA interface for RAM 0
        -- read interface
        ram0_rd_rd_en : out std_logic;                            -- acknowledge that I've seen the current data, move on to next piece of data
        ram0_rd_clear : out std_logic;                            -- asserted in-between each transfer to reset state
        ram0_rd_go    : out std_logic;                            -- begins transfer process
        ram0_rd_valid : in  std_logic;                            -- asserted by DMA to signal that data has arrived from memory
        ram0_rd_data  : in  std_logic_vector(RAM0_RD_DATA_RANGE); -- corresponding data stays there until read enable is asserted
        ram0_rd_addr  : out std_logic_vector(RAM0_ADDR_RANGE);    -- corresponds to 32-bit words
        ram0_rd_size  : out std_logic_vector(RAM0_RD_SIZE_RANGE); -- number of 32-bit words you want to read from memory (we're working with 16-bits so this is half the number elements we want to read)
        ram0_rd_done  : in  std_logic;                            -- assert after "size" elements have been read from memory
        -- write interface
        ram0_wr_ready : in  std_logic;
        ram0_wr_clear : out std_logic;
        ram0_wr_go    : out std_logic;
        ram0_wr_valid : out std_logic;
        ram0_wr_data  : out std_logic_vector(RAM0_WR_DATA_RANGE);
        ram0_wr_addr  : out std_logic_vector(RAM0_ADDR_RANGE);
        ram0_wr_size  : out std_logic_vector(RAM0_WR_SIZE_RANGE);
        ram0_wr_done  : in  std_logic;

        -- DMA interface for RAM 1
        -- read interface
        ram1_rd_rd_en : out std_logic;
        ram1_rd_clear : out std_logic;
        ram1_rd_go    : out std_logic;
        ram1_rd_valid : in  std_logic;
        ram1_rd_data  : in  std_logic_vector(RAM1_RD_DATA_RANGE);
        ram1_rd_addr  : out std_logic_vector(RAM1_ADDR_RANGE);
        ram1_rd_size  : out std_logic_vector(RAM1_RD_SIZE_RANGE);
        ram1_rd_done  : in  std_logic;
        -- write interface
        ram1_wr_ready : in  std_logic;
        ram1_wr_clear : out std_logic;
        ram1_wr_go    : out std_logic;
        ram1_wr_valid : out std_logic;
        ram1_wr_data  : out std_logic_vector(RAM1_WR_DATA_RANGE);
        ram1_wr_addr  : out std_logic_vector(RAM1_ADDR_RANGE);
        ram1_wr_size  : out std_logic_vector(RAM1_WR_SIZE_RANGE);
        ram1_wr_done  : in  std_logic
        );
end user_app;

architecture default of user_app is

    signal go        : std_logic;
    signal sw_rst_s  : std_logic;
    signal rst_s     : std_logic;
    signal size      : std_logic_vector(RAM0_RD_SIZE_RANGE);
--    signal ram0_rd_addr : std_logic_vector(RAM0_ADDR_RANGE);
--    signal ram1_wr_addr : std_logic_vector(RAM1_ADDR_RANGE);
    signal done      : std_logic;

    -- Signal Buffer
    signal signal_buffer_wr_en    : std_logic;
    signal signal_buffer_rd_en    : std_logic;
    signal signal_buffer_empty    : std_logic;
    signal signal_buffer_full     : std_logic;
    signal signal_buffer_wr_data  : std_logic_vector(KERNEL_WIDTH_RANGE);;
    signal signal_buffer_rd_data  : window;
    -- Kernel Buffer
    signal kernel_buffer_wr_en    : std_logic;
    signal kernel_buffer_full     : std_logic;
    signal kernel_buffer_wr_data  : std_logic_vector(KERNEL_WIDTH_RANGE);;
    signal kernel_buffer_rd_data  : window;

    -- Signals used to determine when pipeline data is valid
    signal pipeline_valid_in, pipeline_valid_out : std_logic;
    signal pipeline_latency : natural;

begin

    U_MMAP : entity work.memory_map
        port map (
            clk     => clks(C_CLK_USER),
            rst     => rst,
            wr_en   => mmap_wr_en,
            wr_addr => mmap_wr_addr,
            wr_data => mmap_wr_data,
            rd_en   => mmap_rd_en,
            rd_addr => mmap_rd_addr,
            rd_data => mmap_rd_data,

            -- dma interface for accessing DRAM from software
            ram0_wr_ready => ram0_wr_ready,
            ram0_wr_clear => ram0_wr_clear,
            ram0_wr_go    => ram0_wr_go,
            ram0_wr_valid => ram0_wr_valid,
            ram0_wr_data  => ram0_wr_data,
            ram0_wr_addr  => ram0_wr_addr,
            ram0_wr_size  => ram0_wr_size,
            ram0_wr_done  => ram0_wr_done,

            ram1_rd_rd_en => ram1_rd_rd_en,
            ram1_rd_clear => ram1_rd_clear,
            ram1_rd_go    => ram1_rd_go,
            ram1_rd_valid => ram1_rd_valid,
            ram1_rd_data  => ram1_rd_data,
            ram1_rd_addr  => ram1_rd_addr,
            ram1_rd_size  => ram1_rd_size,
            ram1_rd_done  => ram1_rd_done,

            -- circuit interface from software
            go            => go,
            sw_rst        => sw_rst_s,
            signal_size   => size,
            kernel_data   => kernel_buffer_wr_data,
            kernel_load   => kernel_buffer_wr_en,
            kernel_loaded => kernel_buffer_full,
            done          => done

            -- ram0_rd_addr => ram0_rd_addr,
            -- ram1_wr_addr => ram1_wr_addr,
            );

    rst_s  <= rst or sw_rst_s;
    sw_rst <= sw_rst_s;

    U_CTRL : entity work.ctrl
        port map (
            clk           => clks(C_CLK_USER),
            rst           => rst_s,
            go            => go,
            mem_in_go     => ram0_rd_go,
            mem_out_go    => ram1_wr_go,
            mem_in_clear  => ram0_rd_clear,
            mem_out_clear => ram1_wr_clear,
            mem_out_done  => ram1_wr_done,
            done          => done);

    -- Signal Buffer
    U_SIG : entity work.buffer
        port map (
            clk      => clks(C_CLK_USER),
            rst      => rst_s,
            wr_en    => ram0_rd_valid,
            rd_en    => 
            wr_data  => ram0_rd_data,
            empty    => signal_buffer_empty,
            full     => signal_buffer_full,
            rd_data  => signal_buffer_rd_data
        )

    -- Kernel Buffer
    U_KER : entity work.buffer
        port map (
            clk      => clks(C_CLK_USER),
            rst      => rst_s,
            wr_en    =>
            rd_en    => 
            wr_data  =>
            empty    =>
            full     => kernel_buffer_full,
            rd_data  => kernel_buffer_rd_data
        )

    -- Pipeline data is valid when the signal buffer isn't empty and the kernel buffer has data in it
    pipeline_valid_in <= 
    -- Delay valid_in for latency of pipeline to get valid_out
    pipeline_latency <= clog2(C_KERNEL_SIZE) + 1;
    U_PIPE_VALID : entity work.delay
      generic map(cycles => pipeline_latency, width => 1) 
      port map (clk, rst, en, pipeline_valid_in, pipeline_valid_out);

    -- Pipeline
    U_PIPE: entity work.mult_add_tree
    generic map (
        num_inputs   => C_KERNEL_SIZE,
        input1_width => C_KERNEL_WIDTH,
        input2_width => C_SIGNAL_WIDTH
        )
    port map (
        clk     => clks(C_CLK_USER),
        rst     => rst_s,
        en      => conv_data_valid
        input1  =>
        input2  => 
        output  => 
    )

    -- ram0_rd_rd_en <= ram0_rd_valid and ram1_wr_ready;
    -- ram0_rd_size  <= size;
--    ram0_rd_addr  <= ram0_rd_addr;
    -- ram1_wr_size  <= size;
--    ram1_wr_addr  <= ram1_rd_addr;
    -- ram1_wr_data  <= ram0_rd_data;
    -- ram1_wr_valid <= ram0_rd_valid and ram1_wr_ready;

end default;
