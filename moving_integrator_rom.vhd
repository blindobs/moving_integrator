------------------------------------------------------------------------------------------------------------------------
--! @file      : moving_integrator_rom.vhd
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

--! @brief MOVING_INTEGRATOR_ROM diagnostic entity declaration
entity MOVING_INTEGRATOR_ROM is
  generic (
    G_DATA_IN_WIDTH       : natural       := 10;    --! input data width
    G_DATA_OUT_WIDTH      : natural       := 14;    --! output data width
    G_SAMPLES             : natural       := 256;   --! number of samples to integrate
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
end entity MOVING_INTEGRATOR_ROM;

--! @brief VHDL2002 compilant code for MOVING_INTEGRATOR entity
architecture MOVING_INTEGRATOR_ROM_BEHAVE of MOVING_INTEGRATOR_ROM is

  --! used ram address width
  constant C_ADDR_WIDTH : integer := integer(ceil(log2(real(G_SAMPLES))));
  
  --! create std_logic_vector array for incoming data samples
  type std_logic_vector_array_t is array (0 to 2**C_ADDR_WIDTH-1) of std_logic_vector(i_data'range);

  --! ram write address
  signal write_addr : unsigned(C_ADDR_WIDTH-1 downto 0) := to_unsigned(G_SAMPLES-1, C_ADDR_WIDTH);
  --! ram write data
  signal write_data : std_logic_vector(i_data'range)    := (others=>'0');
  --! ram read data
  signal read_data  : std_logic_vector(i_data'range)    := (others=>'0');
  --! ram model
  signal ram        : std_logic_vector_array_t          := (others=>(others=>'0'));
  --! ram write enable
  signal write_en   : std_logic := '0';

  --! moving integrator accumulator register 
  signal acc : std_logic_vector(G_DATA_IN_WIDTH + C_ADDR_WIDTH + G_PROTECTION_BITS-1 downto 0) := (others=>'0');

begin
------------------------------------------------------------------------------------------------------------------------
-- RAM_DRIVER_PROC: process description
--! @brief Process for driving ram address / data ports
------------------------------------------------------------------------------------------------------------------------
ram_driver_proc:process(i_clk)
begin
  if rising_edge(i_clk) then
    -- reset data signal
    if '1' = i_rst then
      write_data <= (others=>'0');
    else
      write_data <= i_data;
    end if;
    -- update addr on reset or enable
    if '1' = (i_rst or i_en) then
      write_addr  <= write_addr + 1;
    end if;
    write_en <= i_rst or i_en;
  end if;
end process ram_driver_proc;

------------------------------------------------------------------------------------------------------------------------
-- RAM_PROC: process description
--! @brief Process instantating ram model, can be changed with vendor specific single port ram
------------------------------------------------------------------------------------------------------------------------
ram_proc:process(i_clk)
begin
  if rising_edge(i_clk) then
    if '1' = i_en then
      ram(to_integer(write_addr)) <= i_data;
    end if;
    read_data <= ram(to_integer(write_addr-G_SAMPLES+1));
  end if;
end process ram_proc;

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
        acc <= std_logic_vector(signed(acc)  - signed(read_data) + signed(i_data));
      else
        acc <= std_logic_vector(unsigned(acc) - unsigned(read_data) + unsigned(i_data));
      end if;
    end if;
  end if;
end process update_acc_proc;

------------------------------------------------------------------------------------------------------------------------
-- output scale  
------------------------------------------------------------------------------------------------------------------------
  o_data <= acc(acc'left downto acc'length-G_DATA_OUT_WIDTH);

end architecture MOVING_INTEGRATOR_ROM_BEHAVE;