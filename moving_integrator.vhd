------------------------------------------------------------------------------------------------------------------------
--! @file      : moving_integrator.vhd
--! @author    : Tomasz Oczkowski
--! @version   : 1.0
--! @date      : 2020.10.18
--! @copyright : BSD 2-Clause License
------------------------------------------------------------------------------------------------------------------------
--! @class MOVING_INTEGRATOR
--! @details Module calculates average value of input signal from G_SAMPLES input samples. Input signals are treated as 
--! unsigned or signed values based on parameter G_SIGNED flag. \n
--! Generic G_PROTECTION_BITS can be used to scale output values according to user needs. \n
--! For proper reset module require that reset signal will be held asserted for at least G_SAMPLES clock cycles. \n
--! Enabling G_ROUND_EVEN operation add +1 clock cycle latency on the output. Rounding is performed according to  \n
--! IEEE floating point operation to remove DC bias (operation is equall to PC round).
------------------------------------------------------------------------------------------------------------------------

--! Use standard library
library IEEE;
--! Use standard package
use IEEE.std_logic_1164.all;
--! Use numeric std package
use IEEE.numeric_std.all;
--! use math package for log2/ceil function
use IEEE.math_real.all;

--! @brief MOVING_INTEGRATOR entity declaration
entity MOVING_INTEGRATOR is
  generic (
    G_DATA_IN_WIDTH       : natural       := 10;    --! input data width
    G_DATA_OUT_WIDTH      : natural       := 10;    --! output data width
    G_SAMPLES             : natural       := 32;    --! number of samples to integrate
    G_INPUT_SIGNED        : boolean       := true; --! input data signed / unsigned
    G_ROUND_EVEN          : boolean       := true ; --! round even or truncate (round +1 latency)
    G_PROTECTION_BITS     : integer       := 0      --! extra protection bits
  );
  port  (
    i_clk      : in  std_logic;                                     --!  main clock signal
    i_rst      : in  std_logic := '0';                              --!  synchronous reset signal
    i_en       : in  std_logic := '1';                              --!  clock enable
    i_data     : in  std_logic_vector(G_DATA_IN_WIDTH -1 downto 0); --!  input data samples
    o_data     : out std_logic_vector(G_DATA_OUT_WIDTH-1 downto 0)  --!  integrated data output
  );
end entity MOVING_INTEGRATOR;

--! @brief VHDL2002 compilant code for MOVING_INTEGRATOR entity
architecture MOVING_INTEGRATOR_BEHAVE of MOVING_INTEGRATOR is

  --! create std_logic_vector array for incoming data samples
  type std_logic_vector_array_t is array (0 to G_SAMPLES-1) of std_logic_vector(i_data'range);

  --! moving integrator accumulator register
  signal acc : std_logic_vector(G_DATA_IN_WIDTH +integer(ceil(log2(real(G_SAMPLES)))) + G_PROTECTION_BITS-1 downto 0)
    := (others=>'0');

  --! value of moving integrator after rounding operation if enabled
  signal acc_rounded : std_logic_vector(acc'range) := (others=>'0');

  --! integrator shift register
  signal data_samples : std_logic_vector_array_t := (others=>(others=>'0'));

begin
------------------------------------------------------------------------------------------------------------------------
-- shift_reg_proc: process description
--! @brief Process for storing incoming data samples in shift register
------------------------------------------------------------------------------------------------------------------------
shift_reg_proc:process(i_clk)
begin
  if rising_edge(i_clk) then
    if '1' = i_rst then
      data_samples(0)                <= (others=>'0');
      data_samples(1 to G_SAMPLES-1) <= data_samples(0 to data_samples'right-1);
    elsif '1' = i_en then
      data_samples <= i_data&data_samples(0 to data_samples'right-1);
    end if;
  end if;
end process shift_reg_proc;

------------------------------------------------------------------------------------------------------------------------
-- update_acc_proc: process description
--! @brief Process for calculating diff and updating accumulator
------------------------------------------------------------------------------------------------------------------------
update_acc_proc:process(i_clk)
begin
  if rising_edge(i_clk) then
    if '1' = i_rst then
      acc <= (others=>'0');
    elsif '1' = i_en then
      if G_INPUT_SIGNED then
        acc <= std_logic_vector(signed(acc)  - signed(data_samples(data_samples'right)) + signed(i_data));
      else
        acc <= std_logic_vector(unsigned(acc) - unsigned(data_samples(data_samples'right)) + unsigned(i_data));
      end if;
    end if;
  end if;
end process update_acc_proc;

------------------------------------------------------------------------------------------------------------------------
-- round even output if selected
------------------------------------------------------------------------------------------------------------------------
add_round_even_operation: if G_ROUND_EVEN = true generate

  ----------------------------------------------------------------------------------------------------------------------
  -- round_proc: process description
  --! @brief Process adds correction to output data to round it in even/odd scheme according to IEEE round operation
  ----------------------------------------------------------------------------------------------------------------------
  round_proc:process(i_clk)
  variable v_correction : std_logic_vector(acc'length-G_DATA_OUT_WIDTH-1 downto 0) := (others=>'0');
  begin
    if rising_edge(i_clk) then
      if '1' = i_rst then
        acc_rounded  <= (others=>'0');
        v_correction := (others=>'0');
      else
        v_correction := (acc(v_correction'left+1), others => not(acc(v_correction'left+1)));
        if G_INPUT_SIGNED then
          acc_rounded <= std_logic_vector(signed(acc) + signed('0'&v_correction));
        else
          acc_rounded <= std_logic_vector(unsigned(acc) + unsigned(v_correction));
        end if;
      end if;
    end if;
  end process round_proc;

end generate add_round_even_operation;

------------------------------------------------------------------------------------------------------------------------
-- if round is not selected simple truncate data
------------------------------------------------------------------------------------------------------------------------
truncate_operation: if G_ROUND_EVEN = false generate

  acc_rounded <= acc;

end generate truncate_operation;

------------------------------------------------------------------------------------------------------------------------
-- output scaled (truncate)
------------------------------------------------------------------------------------------------------------------------
  o_data   <= acc_rounded(acc_rounded'left downto acc_rounded'length-G_DATA_OUT_WIDTH);

------------------------------------------------------------------------------------------------------------------------
-- generic parameters check
------------------------------------------------------------------------------------------------------------------------
generic_check: assert (G_DATA_IN_WIDTH+integer(ceil(log2(real(G_SAMPLES)))) + G_PROTECTION_BITS >= G_DATA_OUT_WIDTH)
  report "ERROR: " & MOVING_INTEGRATOR'instance_name & LF & "G_DATA_OUT_WIDTH " & integer'image(G_DATA_OUT_WIDTH) &
    " is greater then accumulator size " & integer'image(acc'length)  & " [(G_DATA_IN_WIDTH + log2(G_SAMPLES) +" &
    " G_PROTECTION_BITS)]" severity failure;

end architecture MOVING_INTEGRATOR_BEHAVE;
