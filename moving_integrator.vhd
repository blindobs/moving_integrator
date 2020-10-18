------------------------------------------------------------------------------------------------------------------------
--! @file      : moving_integrator.vhd
--! @author    : Tomasz Oczkowski
--! @version   : 1.0
--! @date      : 2020.10.18
--! @copyright : opensource free to use
------------------------------------------------------------------------------------------------------------------------
--! @details Module calculates average value of inpus signal from G_SAMPLES input signal samples. \n
--! Input signals are treated as unsigned or signed values based on parameter G_SIGNED flag. \n 
--! Generic G_PROTECTION_BITS can be used to scale output values according to user needs. \n
--! For proper reset module require that reset signal will be held asserted for at least G_SAMPLES +1 clock cycles.
------------------------------------------------------------------------------------------------------------------------

--! Use standard library
library IEEE;
--! Use standard package
use IEEE.std_logic_1164.all;
--! Use numeric std package
use IEEE.numeric_std.all;
--! use math package for log2 function
use IEEE.math_real.all;

--! @brief MOVING_INTEGRATOR diagnostic entity declaration
entity MOVING_INTEGRATOR is
  generic (
    G_DATA_IN_WIDTH       : natural       := 10;    --! input data width
    G_DATA_OUT_WIDTH      : natural       := 14;    --! output data width
    G_SAMPLES             : natural       := 32;    --! number of samples to integrate
    G_INPUT_SIGNED        : boolean       := false; --! input data signed / unsigned  
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

  --! integrator shift register
  signal data_samples : std_logic_vector_array_t := (others=>(others=>'0'));

begin
------------------------------------------------------------------------------------------------------------------------
-- SHIFT_REGISTER_PROC: process description
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
-- UPDATE_ACC_PROC: process description
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
-- output scale  
------------------------------------------------------------------------------------------------------------------------
  o_data <= acc(acc'left downto acc'length-G_DATA_OUT_WIDTH);

end architecture MOVING_INTEGRATOR_BEHAVE;