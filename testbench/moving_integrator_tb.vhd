------------------------------------------------------------------------------------------------------------------------
--! @file      : moving_integrator_tb.vhd
--! @author    : Tomasz Oczkowski
--! @version   : 1.0
--! @date      : 2020.10.30
--! @copyright : BSD 2-Clause License
------------------------------------------------------------------------------------------------------------------------
--! @class MOVING_INTEGRATOR_TB
--! @details testbench module for moving_integrator/rom module. Test consists : \n
--! 1. INIT STATE - test uut if output values after global reset are in known correct state \n
--! 2. TEST INPUT VECTOR - test if unit generates correct output comparing to model \n
--! 3. RESET SIGNAL - test if unit correctly behave on reset signal \n
------------------------------------------------------------------------------------------------------------------------

--! Use standard library
library IEEE;
--! Use standard package
use IEEE.std_logic_1164.all;
--! Use numeric package
use IEEE.numeric_std.all;
--! Use math package
use IEEE.math_real.all;

--! Use std library
library STD;
--! use textio for file operations
use STD.textio.all;

--! Use vunit autotesting library
library VUNIT_LIB;
--! Use vunit check values package
use VUNIT_LIB.check_pkg.all;
--! Use vunit runner definition
use VUNIT_LIB.run_types_pkg.all;
--! Use vunit run pkg
use VUNIT_LIB.run_pkg.all;
--! Use vunit logger packge
use VUNIT_LIB.logger_pkg.all;
--! Use vunit com types package
use VUNIT_LIB.com_types_pkg.all;
--! Use vunit com package
use VUNIT_LIB.com_pkg.all;


--! @brief testbench for moving integrator entity
entity MOVING_INTEGRATOR_TB is
  generic (
    runner_cfg            : string        := runner_cfg_default;  --! VUNIT config generic
    G_DATA_IN_WIDTH       : natural       := 16;      --! input data width
    G_DATA_OUT_WIDTH      : natural       := 16;      --! output data width
    G_SAMPLES             : natural       := 32;      --! number of samples to integrate
    G_INPUT_SIGNED        : boolean       := true;    --! input data signed / unsigned
    G_ROUND_EVEN          : boolean       := false;   --! round/truncate data
    G_PROTECTION_BITS     : integer       := 0;       --! extra protection bits
    G_FILE_PATH           : string        := "test_vector.txt"; --! file path to input test vector
    G_CLK_FREQ            : real          := 100.0e6  --! main dut clock frequency
  );
end entity MOVING_INTEGRATOR_TB;

--! @brief VHDL2018 compilant code for MOVING_INTEGRATOR_TB entity
--! @details checked in active-hdl, ghdl
architecture TESTBENCH of MOVING_INTEGRATOR_TB is

  --! change dut clock frequency to period
  constant C_SYSCLK_PERIOD : time := 1.0/G_CLK_FREQ *1.0 sec;

  --! simple function to calculate uut latency based on input generics
  function f_calculate_latency ( round_operation : boolean) return integer is
  variable v_result : integer;
  begin
    v_result := 3 when G_ROUND_EVEN else 2;
  return v_result;
  end function f_calculate_latency;

  --! module calculation latency (3 for round operation, 2 for signed)
  constant C_LATENCY    : integer := f_calculate_latency(G_ROUND_EVEN);

  --! array of std logic vectors definition
  type std_logic_vector_array_t is array (natural range <>) of std_logic_vector;

  --! system clock
  signal i_clk          : std_logic := '1';
  --! reset signal
  signal i_rst          : std_logic := '0';
  
  --! input data enable
  signal i_en           : std_logic := '1';
  --! dut data input
  signal i_data         : std_logic_vector(G_DATA_IN_WIDTH-1 downto 0)  := (others=>'0');
  --! dut data output
  signal o_data         : std_logic_vector(G_DATA_OUT_WIDTH-1 downto 0) := (others=>'0');

  --! pointer to text file with test vectors
  file file_ptr         : text;
  --! golden data read from file and its delayed version to match UUT latency
  signal golden_data    : std_logic_vector_array_t(0 to C_LATENCY)(o_data'range) := (others=>(others=>'0'));

begin                
------------------------------------------------------------------------------------------------------------------------
-- System signals stimulus
------------------------------------------------------------------------------------------------------------------------
  i_clk   <= not i_clk after C_SYSCLK_PERIOD/2;

------------------------------------------------------------------------------------------------------------------------
--! Design Under Test instance
------------------------------------------------------------------------------------------------------------------------
MOVING_INTEGRATOR_UUT: entity work.MOVING_INTEGRATOR(MOVING_INTEGRATOR_BEHAVE) generic map (
    G_DATA_IN_WIDTH       => G_DATA_IN_WIDTH,
    G_DATA_OUT_WIDTH      => G_DATA_OUT_WIDTH,
    G_SAMPLES             => G_SAMPLES,
    G_INPUT_SIGNED        => G_INPUT_SIGNED,
    G_ROUND_EVEN          => G_ROUND_EVEN,
    G_PROTECTION_BITS     => G_PROTECTION_BITS
  )
  port map( 
    i_clk           => i_clk,
    i_rst           => i_rst,
    i_en            => i_en,
    i_data          => i_data,
    o_data          => o_data
);

------------------------------------------------------------------------------------------------------------------------
-- main process description
--! @brief MAIN testing process
--! @details
--! \b Description \n
--! process generates driver to moving_integrator signals and checks DUT signals
------------------------------------------------------------------------------------------------------------------------
main_test:process
  variable v_iline        : Line;
  variable v_sample       : integer;
  variable v_output       : integer;
begin            
  test_runner_setup(runner, runner_cfg);
  
  while test_suite loop

    if  run("TEST::INIT STATE") then
      check_equal(o_data, std_logic_vector'(o_data'range=>'0'), "data out shouldn't be asserted after power-up");

    elsif run("TEST::TEST INPUT VECTORS") then
      file_open(file_ptr, G_FILE_PATH, read_mode);
      while not endfile(file_ptr) loop
        readline(file_ptr, v_iline);
        read(v_iline, v_sample);
        read(v_iline, v_output);
        if G_INPUT_SIGNED then
          i_data         <= std_logic_vector(to_signed(v_sample, i_data'length));
          golden_data(0) <= std_logic_vector(to_signed(v_output, golden_data(0)'length));
        else
          i_data         <= std_logic_vector(to_unsigned(v_sample, i_data'length));
          golden_data(0) <= std_logic_vector(to_unsigned(v_output, golden_data(0)'length));
        end if;
        golden_data(1 to golden_data'right) <= golden_data(0 to golden_data'right-1);
        check_equal(golden_data(golden_data'right), o_data, "golden data and dut data mismatched");
        wait until rising_edge(i_clk);
      end loop;
      file_close(file_ptr);

    elsif run("TEST::RESET SIGNAL") then
      file_open(file_ptr, G_FILE_PATH, read_mode);
      for i in 0 to 3*G_SAMPLES+7 loop -- random value to be honest greater then module buffer size
        readline(file_ptr, v_iline);
        read(v_iline, v_sample);
        read(v_iline, v_output);
        if G_INPUT_SIGNED then
          i_data         <= std_logic_vector(to_signed(v_sample, i_data'length));
          golden_data(0) <= std_logic_vector(to_signed(v_output, golden_data(0)'length));
        else
          i_data         <= std_logic_vector(to_unsigned(v_sample, i_data'length));
          golden_data(0) <= std_logic_vector(to_unsigned(v_output, golden_data(0)'length));
        end if;
        golden_data(1 to golden_data'right) <= golden_data(0 to golden_data'right-1);
        check_equal(golden_data(golden_data'right), o_data, "golden data and dut data mismatched");
        wait until rising_edge(i_clk);
      end loop;
      file_close(file_ptr);
      apply_correct_reset:for i in 0 to G_SAMPLES loop
        i_rst       <= '1';
        golden_data <= (others=>(others=>'0'));
        wait until rising_edge(i_clk);
      end loop apply_correct_reset;
      -- try again read golden file and check vectors
      i_rst <= '0';
      file_open(file_ptr, G_FILE_PATH, read_mode);
      while not endfile(file_ptr) loop
        readline(file_ptr, v_iline);
        read(v_iline, v_sample);
        read(v_iline, v_output);
        if G_INPUT_SIGNED then
          i_data         <= std_logic_vector(to_signed(v_sample, i_data'length));
          golden_data(0) <= std_logic_vector(to_signed(v_output, golden_data(0)'length));
        else
          i_data         <= std_logic_vector(to_unsigned(v_sample, i_data'length));
          golden_data(0) <= std_logic_vector(to_unsigned(v_output, golden_data(0)'length));
        end if;
        golden_data(1 to golden_data'right) <= golden_data(0 to golden_data'right-1);
        check_equal(golden_data(golden_data'right), o_data, "golden data and dut data mismatched");
        wait until rising_edge(i_clk);
      end loop;

    --elsif run("TEST::ENABLE SIGNALS") then
    --To be tested by formal verification

    end if;

  end loop;

  test_runner_cleanup(runner);
  wait;
end process main_test;

  test_runner_watchdog(runner, 2 ms);

end architecture TESTBENCH;