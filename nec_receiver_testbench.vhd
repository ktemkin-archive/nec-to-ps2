----------------------------------------------------------------------------------
-- Testbench file: nec_receiver_testbench
--
-- Generated automatically from Logic Analyzer / Oscilloscope output
-- by csv_to_vhdl; a tool by Kyle Temkin <ktemkin@binghamton.edu>.
--
-- Minimum recommended simulation duration: 1.204e-01 sec
-- Minimum recommended simulation precision: 4.880e-04 sec
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity nec_receiver_testbench is
end entity;


architecture captured_waveforms of nec_receiver_testbench is

  constant clk_period : time := 31.25 ns;

  --UUT signals
  signal clk_32MHz, nec_in, key_down : std_ulogic := '0';
  signal last_received_command : std_ulogic_vector(7 downto 0);

  --Signals automatically generated from CSV file:
  signal ir_input : std_ulogic;

  --Delays between the samples captured from the instrument.
  --These are used to re-create the captured waveforms.
  type sample_delay_times is array(natural range <>) of time;
  constant duration_of_previous_sample : sample_delay_times := (0.0 sec,0.001 sec,0.009022 sec,0.004425 sec,0.0006249999999999988 sec,0.000504000000000001 sec,0.000562 sec,0.0005409999999999981 sec,0.0006260000000000016 sec,0.000504000000000001 sec,0.0006229999999999986 sec,0.0005059999999999995 sec,0.0005600000000000015 sec,0.0005429999999999983 sec,0.0006239999999999996 sec,0.000505000000000002 sec,0.000622000000000001 sec,0.000507999999999998 sec,0.0005679999999999991 sec,0.0005350000000000008 sec,0.000622000000000001 sec,0.0016359999999999986 sec,0.0005670000000000015 sec,0.0016660000000000008 sec,0.0006180000000000005 sec,0.0016139999999999974 sec,0.0006190000000000015 sec,0.0016400000000000026 sec,0.0005629999999999941 sec,0.0016690000000000038 sec,0.0006239999999999996 sec,0.0016079999999999983 sec,0.0006260000000000016 sec,0.0005029999999999965 sec,0.0006230000000000055 sec,0.0016100000000000003 sec,0.0006239999999999996 sec,0.0016339999999999966 sec,0.0006089999999999984 sec,0.0004940000000000014 sec,0.0006220000000000045 sec,0.0016369999999999996 sec,0.0006169999999999995 sec,0.0016149999999999984 sec,0.0006180000000000005 sec,0.0005109999999999976 sec,0.0006159999999999985 sec,0.0004880000000000023 sec,0.0006180000000000005 sec,0.0005109999999999976 sec,0.0006160000000000054 sec,0.0005129999999999996 sec,0.0006129999999999955 sec,0.0004900000000000043 sec,0.0006169999999999995 sec,0.0016419999999999976 sec,0.0006110000000000004 sec,0.0004919999999999994 sec,0.0005949999999999983 sec,0.0005339999999999998 sec,0.0006220000000000045 sec,0.0016100000000000003 sec,0.0005929999999999963 sec,0.0016660000000000008 sec,0.0006180000000000005 sec,0.0016139999999999974 sec,0.0006190000000000084 sec,0.0016139999999999904 sec,0.0005890000000000062 sec,0.040877 sec,0.009027999999999994 sec,0.0021870000000000084 sec,0.0006099999999999994 sec);

  --The actual samples captured by the instrument.
  --These are used to re-create the captured waveforms.
  type std_ulogic_samples is array(natural range <>) of std_ulogic;
  constant ir_input_samples : std_ulogic_samples := ('1', '0', '1', '0', '1', '0', '1', '0', '1', '0', '1', '0', '1', '0', '1', '0', '1', '0', '1', '0', '1', '0', '1', '0', '1', '0', '1', '0', '1', '0', '1', '0', '1', '0', '1', '0', '1', '0', '1', '0', '1', '0', '1', '0', '1', '0', '1', '0', '1', '0', '1', '0', '1', '0', '1', '0', '1', '0', '1', '0', '1', '0', '1', '0', '1', '0', '1', '0', '1', '0', '1', '0', '1');

begin

  --Instantiate the unit under test.
  IR_RX: entity work.nec_receiver port map(clk_32MHz => clk_32MHz, nec_in => nec_in, last_received_command => last_received_command, key_down => key_down);

  --Create the nec input, which is equivalent to the inverse of the IR in.
  nec_in <= not ir_input;

  --Create our system clock.
  clk_32MHz <= not clk_32MHz after clk_period / 2;

  --Main stimulus process. This process applies the captured waveforms.
  process
  begin
    --Loop through all of the captured samples.
    for i in 0 to 72 loop
      wait for duration_of_previous_sample(i);
      ir_input <= ir_input_samples(i);
    end loop;
  end process;

end captured_waveforms;
