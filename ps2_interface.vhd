----------------------------------------------------------------------------------
-- Company:        Binghamton University
-- Engineer:       Kyle J. Temkin, <ktemkin@binghamton.edu>
-- 
-- Create Date:    21:27:59 11/21/2013 
-- Design Name:    PS/2 Interface
-- Module Name:    ps2_interface - Behavioral 
-- Project Name:   NEC-to-PS/2
-- Target Devices: XC3S500E
-- Description:    Transmits data in a PS/2 format that can be read by most 
--                 computers.
--
-- See source control for revisions and changelog.
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_MISC.ALL;
use IEEE.NUMERIC_STD.ALL;


entity ps2_interface is
  port(
    
    --Main system clock signal; used for generating the PS/2 signal's timing.
    clk_32MHz : in std_ulogic;

    --Active high reset signal
    reset     : in std_ulogic := '0';

    --The keycode of the currently pressed key.
    --Must be valid data whenever key_down is true.
    key_code   : in std_ulogic_vector(7 downto 0);

    --High if the key is currently down.
    --A break code will be queued if the 
    key_down  : in std_ulogic;

    --The two PS/2 pseudo-SPI signaling lines.
    ps2_data  : out std_ulogic;
    ps2_clock : out std_ulogic

  );
end ps2_interface;

--
-- This particular implemention is for a purely academic purpose,
-- and does not support command queing (or multiple keypresses).
--
-- Consider a more "serious" implementation when applications 
-- require it; though this should be fine for an NEC-to-PS/2
-- interface. 
-- 
architecture non_queuing_transmitter of ps2_interface is

  --
  -- PS/2 timing protocol information.
  -- 

  --The clock frequency for which the PS/2 device should transmit at.
  --Frequency values used by real keyboards seem to be between 10-30MHz.
  constant PS2_CLOCK_PERIOD     : integer := 1600;

  --The start and stop bit definitions for the PS/2 protocol.
  constant start_bit : std_ulogic := '0';
  constant stop_bit  : std_ulogic := '1';

  --The key release "break code" for the PS/2 protocol.
  --This short packet is sent prior to a 
  constant break_code : std_ulogic_vector := x"F0";

  --
  -- Datapath signals
  --

  --Counter which will keep track of the PS/2 signal timings,
  --and relevant control signals.
  signal ps2_clock_counter      : unsigned(10 downto 0) := (others => '0');
  signal ps2_clock_falling_edge : std_ulogic;
  signal ps2_clock_rising_edge  : std_ulogic;

  --Signals that are used to determine the PS/2 frame to be sent
  --for the current keycode.
  signal ps2_shift_register                  : std_ulogic_vector(10 downto 0) := (others => '1');
  signal store_keycode_for_transmission      : std_ulogic;
  signal store_break_code_for_transmission   : std_ulogic;
  signal store_release_code_for_transmission : std_ulogic;
  signal parity_bit                          : std_ulogic;

  -- Signals which store information about the most recently transmitted
  -- key code. These are used to transmit the appropriate key release.
  signal last_key_code   : std_ulogic_vector(7 downto 0);
  signal last_parity_bit : std_ulogic;

  --Counter which keeps track of the total bits transmitted.
  signal ps2_transmission_count       : unsigned(3 downto 0);
  signal ps2_transmission_count_clear : std_ulogic;
  
  --
  -- Controller signals.
  -- 

  --Indicates when the transmitter is actively transmitting.
  signal transmitting : std_ulogic;


  --State machine signals for the core PS/2 controller.
  type ps2_transmitter_state is (WAIT_FOR_PRESS, TRANSMIT_PRESS, WAIT_FOR_RELEASE, TRANSMIT_BREAK, TRANSMIT_RELEASE);
  signal current_state                        : ps2_transmitter_state;
  signal next_state, next_state_with_reset    : ps2_transmitter_state;

begin

  --
  -- Datapath
  --

  --20kHz PS/2 clock generation signal.
  ps2_clock_counter      <= (ps2_clock_counter + 1) mod 1600 when rising_edge(clk_32MHz);

  --Signals that indicate whether the next 
  ps2_clock_rising_edge  <= '1' when ps2_clock_counter = PS2_CLOCK_PERIOD - 1 else '0';
  ps2_clock_falling_edge <= '1' when ps2_clock_counter = (PS2_CLOCK_PERIOD / 2) - 1 else '0';

  --Generate the PS/2 clock; which goes high for the first half of each PS/2 clock cycle
  --_during transmission_.
  ps2_clock <= '1' when ps2_clock_counter < 800 and transmitting = '1' else '0';

  --Determine the value of the parity bit for the current key code.
  parity_bit <= xor_reduce(key_code);

  --Store the PS/2 key data at the start of each key press. 
  --We use this to provide a key-up code once the key is released.
  last_key_code   <= key_code when rising_edge(clk_32MHz) and store_keycode_for_transmission = '1';
  last_parity_bit <= xor_reduce(last_key_code);


  --Shift register; used for ordered transmission of PS/2 data.
  process(clk_32MHz)
  begin
    if rising_edge(clk_32MHz) and ps2_clock_rising_edge = '1' then

      --Fill the shift register with ones on reset.
      if reset = '1' then
        ps2_shift_register <= (others => '1');

      --If we're first receiving a keycode to transmit, queue an entire frame
      --for transmission.
      elsif store_keycode_for_transmission = '1' then
        ps2_shift_register <= stop_bit & parity_bit & key_code & start_bit;

      --If the key has just been released, queue the break code for transmission.
      elsif store_break_code_for_transmission = '1' then
        ps2_shift_register <= stop_bit & '0' & break_code & start_bit;
    
      --If we've just transmitted the break code, queue the keycode itself for transmission.
      elsif store_release_code_for_transmission = '1' then
        ps2_shift_register <= stop_bit & last_parity_bit & last_key_code & start_bit;

      --If we're actively transmitting, shift out a new piece of PS/2 data on 
      --each rising edge of the PS/2 clock.
      elsif transmitting = '1' and ps2_clock_rising_edge = '1' then
        ps2_shift_register <= '1' & ps2_shift_register(10 downto 1);
      end if;

    end if;
  end process;


  --Transmission counter; keeps track of the total amount of bits transmitted
  --in the given frame-- and thus to our position in the frame.
  process(clk_32MHz)
  begin
    if rising_edge(clk_32MHz) and ps2_clock_rising_edge = '1' then

      --Reset: when this signal is asserted, clear the total transmission bitcount.
      if ps2_transmission_count_clear = '1' then
        ps2_transmission_count <= (others => '0');

      --If a PS/2 rising edge has occured while transmission is enabled,
      --we've just transmitted an additional PS/2 data bit. Count it.
      elsif transmitting = '1' and ps2_clock_rising_edge = '1' then
        ps2_transmission_count <= ps2_transmission_count + 1;
      end if;

    end if;
  end process;

  --Connect the output of our transmitter shift register to the PS/2 data line.
  ps2_data <= ps2_shift_register(0);
  
  --
  -- Controller.
  --

  --Move to the next state at each rising edge _of the PS/2 clock_.
  current_state <= next_state_with_reset when rising_edge(clk_32MHz) and ps2_clock_rising_edge = '1';

  --FSM reset logic.
  next_state_with_reset <= WAIT_FOR_PRESS when reset = '1' else next_state;


  --
  -- Next-state and control logic. 
  -- Note: This could be optimized further by preventing the counters from counting
  --       when not in use. This would incur the use of slightly more logic, but save
  --       dynamic power. 
  -- 
  --
  process(current_state, key_down, ps2_clock_rising_edge, ps2_transmission_count)
  begin


    --Assume that the control signals are zero unless explicitly asserted.
    transmitting <= '0';
    ps2_transmission_count_clear <= '0';
    store_keycode_for_transmission <= '0';
    store_break_code_for_transmission <= '0';
    store_release_code_for_transmission <= '0';

    --Assume that we stay in the current state, unless the FSM
    --specifies otherwise. (Don't remove this! The behavior may
    --seem to be the same, but you'll cause the synthesis tools
    --to infer latches!)
    next_state <= current_state;

    --TODO: Possibly abstract the ps2_clock_rising_edge out of the
    --next-state logic?
    case current_state is

      --
      -- Idle in the "wait for press" state until we have a key-press,
      -- which is indicated by a '1' on the key_down signal.
      -- 
      when WAIT_FOR_PRESS =>

        --Remain until this state until a key is pressed _and_
        --we encounter a rising edge of the PS/2 clock.
        --(Waiting for the rising edge ensures that a full PS/2 
        -- period passes before we move on to the second bit, and
        -- keeps everything synchronous to both the system and PS/2
        -- clock.)
        if key_down = '1' then

          --Store the PS/2 frame to be transmitted,
          --which includes the keycode to be transmitted.
          store_keycode_for_transmission <= '1';

          --Clear the transmission count, which we'll use in the next state.
          ps2_transmission_count_clear <= '1';

          --And move to the state in which we transmit the keycode.
          next_state <= TRANSMIT_PRESS;

        end if;


      --
      -- Transmit all eleven bits of the key-press frame,
      -- indicating that the key was pressed.
      --
      when TRANSMIT_PRESS =>

        --Indicate that we're transmitting.
        transmitting <= '1';

        --If we're just finishing transmission of the final bit in the frame,
        --we'll want to wait until a key-release to send the next code.
        if ps2_transmission_count = ps2_shift_register'left then
          next_state <= WAIT_FOR_RELEASE;
        end if;


      --
      -- Once the key-code has been pressed, we'll need to wait for the key
      -- to be released before we can continue.
      --
      when WAIT_FOR_RELEASE =>

        --Remain in this state until the key_down signal goes low.
        if key_down = '0' then

          --Load the break code, which "modifies" the transmitted keycode
          --to indicate that they code has been released.
          store_break_code_for_transmission <= '1';

          --Clear the transmission count, which we'll use in the next state.
          ps2_transmission_count_clear <= '1';

          --And move to the state in which we transmit the break code.
          next_state <= TRANSMIT_BREAK;

        end if;

      --
      -- Transmit all eleven bits of the break-code frame,
      -- indicating that the next key-code to be transmitted
      -- corresponds to a key release.
      --
      when TRANSMIT_BREAK =>

        --Indicate that we're transmitting.
        transmitting <= '1';

        --If we're just finishing transmission of the final bit in the frame,
        --we'll want to wait until a key-release to send the next code.
        if ps2_transmission_count = ps2_shift_register'left then

          --Store the PS/2 frame to be transmitted,
          --which includes the keycode to be transmitted.
          store_release_code_for_transmission <= '1';

          --Clear the transmission count, which we'll use in the next state.
          ps2_transmission_count_clear <= '1';

          --And move to the state in which we transmit the keycode.
          next_state <= TRANSMIT_RELEASE;

        end if;


      --
      -- Transmit all elevent bits of the key-code for the key
      -- which has just been released.
      --
      when TRANSMIT_RELEASE =>

        --Indicate that we're transmitting.
        transmitting <= '1';

        --If we're just finishing transmission of the final bit in the frame,
        --we'll want to wait until a key-release to send the next code.
        if ps2_transmission_count = ps2_shift_register'left then
          next_state <= WAIT_FOR_PRESS;
        end if;


    end case;


  end process;



end non_queuing_transmitter;

