----------------------------------------------------------------------------------
-- Testbench file: ps2_transmitter_testbench.vhd
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity ps2_transmitter_testbench is
end entity;


architecture simple_stimulus of ps2_transmitter_testbench is

  constant clk_period : time := 31.25 ns;

  --UUT signals
  signal clk_32MHz, key_down : std_ulogic := '0';
  signal ps2_data, ps2_clock : std_ulogic;
  signal key_code            : std_ulogic_vector(7 downto 0);

begin

  --Instantiate the unit under test.
  PS2_TX: entity work.ps2_interface port map(clk_32MHz => clk_32MHz, key_code => key_code, key_down => key_down, ps2_data => ps2_data, ps2_clock => ps2_clock);

  --Create our system clock.
  clk_32MHz <= not clk_32MHz after clk_period / 2;

  process
  begin

    --Apply the intial keycode.
    wait for 1 ps;
    key_code <= x"AB";

    --Press the key...
    wait for 10 * clk_period;
    key_down <= '1';

    -- Wait for a millisecond, and release the key.
    wait for 1 ms;
    key_down <= '0';

    wait;



  end process;


end simple_stimulus;
