----------------------------------------------------------------------------------
-- Company:        Binghamton University
-- Engineer:       Kyle J. Temkin, <ktemkin@binghamton.edu>
-- 
-- Create Date:    21:27:59 11/21/2013 
-- Design Name:    NEC Receiever
-- Module Name:    nec_receiver - Behavioral 
-- Project Name:   NEC-to-PS/2
-- Target Devices: XC3S500E
-- Description:    Receives NEC encoded remote control data.
--
-- See source control for revisions and changelog.
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity nec_receiver is
  port(
    
    --Main system clock signal; used for reading the NEC signal's timing.
    clk_32MHz : in std_ulogic;

    --Active high reset signal
    reset : in std_ulogic := '0';

    -- The NEC infrared input.
    nec_in : in std_ulogic;

    --The most recently received command. 
    last_received_command : out std_ulogic_vector(7 downto 0);

    --High iff the given key is currently down, to the best of the
    --receiver's knowledge.
    key_down : out std_ulogic

  );
end nec_receiver;


architecture behavioral of nec_receiver is

  --
  -- NEC protocol timings.
  -- 

  -- The NEC header is a 9ms pulse; these constants specify the ideal and realistic timings of that header.
  constant HEADER_PULSE_TIME_ALLOWANCE : integer := 1000;
  constant HEADER_PULSE_TIME_BY_SPEC   : integer := 288000; -- 9ms @ 32MHz
  constant HEADER_MINUMUM_PULSE_LENGTH : integer := HEADER_PULSE_TIME_BY_SPEC - HEADER_PULSE_TIME_ALLOWANCE;
  constant HEADER_MAXIMUM_PULSE_LENGTH : integer := HEADER_PULSE_TIME_BY_SPEC + HEADER_PULSE_TIME_ALLOWANCE;

  -- After the header, there's a window about 2.25ms long which will always be low. The value /after/ this
  -- window can be used to detect whether the packet is a repeat command.
  constant HEADER_REPEAT_WINDOW_START  : integer := 73600;

  -- Stores the minimum pulse distance which should be considered a one. Taken directly from the NEC spec.
  constant DATA_MINIMUM_TIME_FOR_ONE   : integer := 18000;

  -- Stores the maximum amount of time we'll wait for a "repeat packet". If we don't receieve a repeat
  -- packet in this time, we'll decide that the key must have been released.
  constant KEY_PRESS_TIMEOUT : integer := 3456000 + 1000;

  --
  --Core controller FSM logic.
  --
  type receiver_state is (WAIT_FOR_HEADER, READ_HEADER, WAIT_FOR_REPEAT_WINDOW, WAIT_FOR_IDLE, WAIT_FOR_COMMAND, WAIT_FOR_END_OF_DATA_PULSE, COUNT_DATA_PULSE_SPACING, PROCESS_PACKET);

  --Current and next state logic for the FSM.
  signal current_state : receiver_state := WAIT_FOR_HEADER;
  signal next_state, next_state_with_reset : receiver_state;

  -- Control output signals.
  signal repeat_code_received, command_packet_started : std_ulogic;
  signal data_bit_received, packet_received : std_ulogic;

  --
  -- Datapath signals.
  --

  --Time counter, which counts the amount of time that has passed.
  signal time_counter_clear : std_ulogic;
  signal time_counter_value : unsigned(21 downto 0) := (others => '0');

  --Comparator output, which determine if the current time counter
  --value would be interpreted as a '0' or a '1' when interpreted as
  --a pulse spacing.
  signal current_bit_value : std_ulogic;

  --Pulse counter, which counts the amount of pulses passed.
  signal prior_input_value, is_rising_edge_of_input : std_ulogic;
  signal pulse_counter_clear          : std_ulogic;
  signal pulse_counter_value          : unsigned(4 downto 0);

  -- "Shift register" which stores the 16 most recent received bits.
  signal received_bits      : std_ulogic_vector(15 downto 0);
  signal data_is_valid : std_ulogic;


begin


  --
  -- Datapath.
  --

  -- Core counter, which counts the amount of cycles that have passed since
  -- its last reset. (Note that this could alternatively be accomplished with a
  -- process, but this method is less ugly.)
  TIME_COUNTER:
  process(clk_32mhz)
  begin
    if rising_edge(clk_32mhz) then

      --if our clear signal is high, clear the counter.
      if time_counter_clear = '1' then
        time_counter_value <= (others => '0');

      --otherwise, count normally.
      else
        time_counter_value <= time_counter_value + 1;
      end if;
    end if;
  end process;
      

  -- Comparator, which determines whether the current time-counter value
  -- would be considered a '0' or a '1'.
  current_bit_value <= '1' when time_counter_value > DATA_MINIMUM_TIME_FOR_ONE else '0'; 


  -- Pulse counter, which counts the amount of pulses that have passed since
  -- its last reset.
  PULSE_COUNTER:
  process(clk_32mhz)
  begin
    if rising_edge(clk_32mhz) then

      --If our clear signal is high, clear the pulse counter.
      if pulse_counter_clear = '1' then
        pulse_counter_value <= (others => '0');

      --Otherwise, count rising edges.
      elsif is_rising_edge_of_input = '1' then
        pulse_counter_value <= pulse_counter_value + 1;

      end if;
    end if;
  end process;


  -- Edge detect for the pulse counter.
  prior_input_value <= nec_in when rising_edge(clk_32MHz);
  is_rising_edge_of_input <= '1' when nec_in = '1' and prior_input_value = '0' else '0';

  -- Shift register, which loads in the received data each time a bit is received.
  received_bits <= current_bit_value & received_bits(15 downto 1) when rising_edge(clk_32MHz) and data_bit_received = '1';

  -- The received data is valid when the most recently received octet
  -- is the logical inverse of the octet before it.
  data_is_valid <= '1' when received_bits(15 downto 8) = not received_bits(7 downto 0);

  --Whenever we recieve a valid data byte, apply it to the output.
  last_received_command <= received_bits(7 downto 0) when rising_edge(clk_32MHz) and data_is_valid = '1' and packet_received = '1';


  --KEY_PRESS_TRACKER:
  process(clk_32MHz)
  begin

    if rising_edge(clk_32MHz) then

      --Once we receieve a new packet, mark the given key as pressed.
      if packet_received = '1' then
        key_down <= '1';

      --If we've receieved a new command packet, we must be starting
      --a new button press. Inidcate a key release.
      elsif command_packet_started = '1' then
        key_down <= '0';

      -- If we're able to reach the keypress timeout without a new 
      -- key press occurring, then indicate a key release.
      elsif time_counter_value > KEY_PRESS_TIMEOUT  then
        key_down <= '0';
      end if;


    end if;
  end process;


  --
  -- Controller.
  --

  --Move to the next state at each clock edge.
  current_state <= next_state_with_reset when rising_edge(clk_32MHz);

  --FSM reset logic.
  next_state_with_reset <= WAIT_FOR_HEADER when reset = '1' else next_state;


  --
  -- Next-state and control logic. 
  -- Note: This could be optimized further by preventing the counters from counting
  --       when not in use. This would incur the use of slightly more logic, but save
  --       dynamic power. 
  -- 
  --
  process(nec_in, current_state, time_counter_value, pulse_counter_value)
  begin

    --Assume that the control signals are zero unless explicitly
    --asserted.
    packet_received <= '0';
    data_bit_received <= '0';
    time_counter_clear <= '0';
    pulse_counter_clear <= '0';
    repeat_code_received <= '0';
    command_packet_started <= '0';

    --Assume that we stay in the current state, unless the FSM
    --specifies otherwise. (Don't remove this! The behavior may
    --seem to be the same, but you'll cause the synthesis tools
    --to infer latches!)
    next_state <= current_state;

    --
    -- Determine the next-state and control signal behavior based
    -- on the current state.
    -- 
    case current_state is

      --
      -- State in which we wait for receipt of the IR code to begin.
      -- We'll wait for the 
      -- 
      when WAIT_FOR_HEADER =>

        --Remain in this state until the IR receiver input goes high,
        --indicating the start of the NEC frame.
        if nec_in = '1' then

          --Once we're receiveing the start pulse, move to the "read header"
          --state.
          next_state <= READ_HEADER;

          --Once we've ready to move to the READ_HEADER state,
          --reset the time counter.
          time_counter_clear <= '1';
        end if;


      --
      -- Read the NEC header, which should be a pulse about 9ms (288k cycles) long.
      -- 
      when READ_HEADER =>

        --Potentially have the time counter count here.

        --If we've encountered an erroneously short packet, 
        --restart the FSM.
        if nec_in = '0' then 
          
          --If we're within an acceptable tolerance of the header pulse length...
          if (time_counter_value >= HEADER_MINUMUM_PULSE_LENGTH) and (time_counter_value <= HEADER_MAXIMUM_PULSE_LENGTH) then

            --Continue to see if this is a reset state.
            next_state <= WAIT_FOR_REPEAT_WINDOW;

            --Clear the time counter for the next state.
            time_counter_clear <= '1';

          --Otherwise, the transmission was an error. Restart the FSM.
          else--
            next_state <= WAIT_FOR_HEADER;

          end if;
        end if;

      --
      -- Once we've received a valid header, we have to wait for >2.25ms to see if the packet
      -- is a repeat code. If it is, the IR line will go high, and the packet will end.
      --
      -- We want to be able to detect these, so we can detect when a key is being pressed down.
      --
      when WAIT_FOR_REPEAT_WINDOW =>

        --If we've entered the repeat window, process the signal according
        --to whether or not it's a repeat packet.
        if time_counter_value = HEADER_REPEAT_WINDOW_START then

          --If this _is_ a repeat packet...
          if nec_in = '1' then

            --... indicate that we've received a repeat code...
            repeat_code_received <= '1';

            -- ... and wait for the line to go idle, again.
            next_state <= WAIT_FOR_IDLE;

          --Otherwise, this must be a command packet.
          else
          
            --Move to the "wait for command" state.
            next_state <= WAIT_FOR_COMMAND;

            --And clear the pulse counter, which will
            --be used by the wait for command state.
            pulse_counter_clear <= '1';

            -- Set the control signal that indicates that we've
            -- startad a new command packet. This clears the current
            -- "keypress" state.
            command_packet_started <= '1';

          end if;

        end if;


      --
      -- After a short packet ends, we'll need to wait for the line to become idle
      -- before we can detect a subsequent packet.
      -- 
      when WAIT_FOR_IDLE =>

        --Ensure that the core time counter remains at zero.
        --We'll use this in the "wait for idle" state to keep track
        --of the time since the last keypress.
        time_counter_clear <= '1';

        --Once the line has become idle, resume waiting for the header.
        if nec_in = '0' then
          next_state <= WAIT_FOR_HEADER;
        end if;


      --
      -- In this revision of the NEC receiver, we ignore address data,
      -- as it's not particularly useful for processing normal remote
      -- controls. Address data always consists of 16 pulses, 
      -- so we'll skip over 16 pulses worth of data.
      --
      when WAIT_FOR_COMMAND =>

        --Once we've seen 16 pulses...
        if pulse_counter_value >= 16 then

          -- ...move to the receive data state...
          next_state <= WAIT_FOR_END_OF_DATA_PULSE;

          --... and clear the pulse count, which we'll
          -- use to keep track of the total amount of data received.
          pulse_counter_clear <= '1';

        end if;


      --
      -- The NEC protocol uses Pulse Distance Encoding to transmit its
      -- messages. To interpret these messges, we'll wait for the input
      -- to become zero, and then time how remains there.
      --
      when WAIT_FOR_END_OF_DATA_PULSE =>

        --Once the input has dropped to zero...
        if nec_in = '0' then

          --... move to the "count zero length" state...
          next_state <= COUNT_DATA_PULSE_SPACING;

          --... and clear the pulse-time counter, which we'll
          -- use to count the pulse's length.
          time_counter_clear <= '1';
        
        end if;


      --
      -- In the "count data pulse spacing" state, 
      -- we count how long it takes for the data 
      -- signal to go high, and then interpret the result as a bit.
      --
      when COUNT_DATA_PULSE_SPACING =>

        --If we've just received the start of a new pulse,
        --handle the old pulses's timing.
        if nec_in = '1' then

          --Indicate that we've received a data bit.
          data_bit_received <= '1';

          -- We expect to receive all NEC data twice: once in plaintext,
          -- and once inverted. If we've seen a full octet of data in 
          -- both forms, we can assume the packet is over. We'll move to 
          -- the "process packet" state.
          if pulse_counter_value >= 16 then
              next_state <= PROCESS_PACKET;

          -- If the packet isn't over, continue to receive the next
          -- data bit.
          else 
              next_state <= WAIT_FOR_END_OF_DATA_PULSE;
          end if;

        end if;


      --
      -- Finally, once the packet is complete, we have enough information
      -- to extract the full message. We'll extract the message, and then
      -- wait for the line to return to idle-- which will take another half
      -- of a ms, or eighteen thousand clock cycles.
      -- 
      when PROCESS_PACKET =>

        --Indicate that we've received a full packet.
        packet_received <= '1';

        --And move to the "wait for idle" state.
        --This state waits for the line to go idle, and then restarts.
        next_state <= WAIT_FOR_IDLE;


    end case;

  end process;

  


end Behavioral;

