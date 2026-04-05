----------------------------------------------------------------------------------
-- Create Date: 04.04.2026 18:47:14
-- Module Name: DACS_source_1 - Behavioral
-- Revision:
-- Revision 0.01 - File Created
-- ---------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity DACS_source_1 is
    Port ( clk : in STD_LOGIC;
           reset : in STD_LOGIC;
           enter : in STD_LOGIC;
           passcode : in STD_LOGIC_VECTOR (3 downto 0);
           access_granted : out STD_LOGIC;
           access_denied : out STD_LOGIC;
           buzzer : out STD_LOGIC;
           lock : out STD_LOGIC;
           segment : out STD_LOGIC_VECTOR (6 downto 0);
           dp : out STD_LOGIC;
           an : out STD_LOGIC_VECTOR (3 downto 0));
end DACS_source_1;

architecture Behavioral of DACS_source_1 is
   
    -- Stored password = 1011
    constant STORED_PASSWORD : STD_LOGIC_VECTOR(3 downto 0) := "1011";

    -- 3 seconds at 100 MHz clock
    constant THREE_SEC_COUNT : integer := 300000000;

    -- Short beep duration (example: 0.25 second)
    constant SHORT_BEEP_COUNT : integer := 25000000;


    -- ATTEMPT COUNTER STATE BITS
    -- q2 q1 q0 are used to track number of failed attempts / lock state
    signal q2, q1, q0 : STD_LOGIC := '0';

    -- INTERNAL CONTROL SIGNALS
    --------------------------------------------------------------------
    signal match         : STD_LOGIC;   -- 1 if entered passcode matches stored password
    signal lock_flag     : STD_LOGIC := '0';

    -- 7-SEGMENT INTERNAL SIGNALS
    --------------------------------------------------------------------
    signal seg_num       : STD_LOGIC_VECTOR(6 downto 0); -- shows 0,1,2,3
    signal seg_L         : STD_LOGIC_VECTOR(6 downto 0); -- shows L for LOCK
    signal show_lock     : STD_LOGIC;                    -- selects number or L

 
    -- ENTER BUTTON EDGE DETECTION
    --------------------------------------------------------------------
    signal enter_d       : STD_LOGIC := '0'; -- delayed enter
    signal enter_pulse   : STD_LOGIC;        -- one-clock pulse when enter is pressed

    -- COOLDOWN TIMER
    -- prevents repeated attempts too quickly (3 seconds)
    --------------------------------------------------------------------
    signal cooldown_busy : STD_LOGIC := '0';
    signal timer_count   : integer range 0 to THREE_SEC_COUNT := 0;


    -- BUZZER TIMER FOR SHORT BEEP
    --------------------------------------------------------------------
    signal beep_short    : STD_LOGIC := '0';
    signal beep_count    : integer range 0 to SHORT_BEEP_COUNT := 0;

    
    -- LED REGISTERS
    --------------------------------------------------------------------
    signal green_reg     : STD_LOGIC := '0';
    signal red_reg       : STD_LOGIC := '0';

begin

   
    -- PASSWORD COMPARATOR
    -- This checks whether passcode = STORED_PASSWORD
 
 match <= '1' when passcode = STORED_PASSWORD else '0';

  
    -- ENTER BUTTON EDGE DETECTION
    -- enter_pulse becomes 1 for one clock cycle when button is pressed

    enter_pulse <= enter and (not enter_d);

   
    -- MAIN PROCESS
    
    process(clk, reset)
    begin
        if reset = '1' then
     
            -- RESET EVERYTHING
          
            q2 <= '0';
            q1 <= '0';
            q0 <= '0';

            lock_flag <= '0';

            enter_d <= '0';
            cooldown_busy <= '0';
            timer_count <= 0;

            green_reg <= '0';
            red_reg <= '0';

            beep_short <= '0';
            beep_count <= 0;

        elsif rising_edge(clk) then
        
            -- SAVE PREVIOUS ENTER VALUE FOR EDGE DETECTION
          
            enter_d <= enter;


            -- HANDLE 3-SECOND COOLDOWN TIMER
            -- keeps LEDs active during cooldown, then clears them
           
            if cooldown_busy = '1' then
                if timer_count = THREE_SEC_COUNT - 1 then
                    timer_count <= 0;
                    cooldown_busy <= '0';

                    green_reg <= '0';
                    red_reg <= '0';
                else
                    timer_count <= timer_count + 1;
                end if;
            end if;

         
            -- HANDLE SHORT BUZZER TIMER
            -- used for incorrect attempts before lock
     
            if beep_short = '1' then
                if beep_count = SHORT_BEEP_COUNT - 1 then
                    beep_short <= '0';
                    beep_count <= 0;
                else
                    beep_count <= beep_count + 1;
                end if;
            end if;

          
            -- ACCEPT ONLY ONE ENTER PRESS
            -- and only if cooldown is finished
            
            if enter_pulse = '1' and cooldown_busy = '0' then
                cooldown_busy <= '1';
                timer_count <= 0;

    
                -- CORRECT PASSCODE
               
                if match = '1' then
                    -- clear failed attempts
                    q2 <= '0';
                    q1 <= '0';
                    q0 <= '0';
                    lock_flag <= '0';

                    green_reg <= '1';
                    red_reg <= '0';

                    beep_short <= '0';
                    beep_count <= 0;

          
                -- INCORRECT PASSCODE
              
                else
                    green_reg <= '0';
                    red_reg <= '1';

                    -- INCREMENT FAILED ATTEMPT COUNT
                
                    if q2 = '0' and q1 = '0' and q0 = '0' then
                        -- 0 wrong attempts -> 1 wrong attempt
                        q2 <= '0';
                        q1 <= '0';
                        q0 <= '1';
                        beep_short <= '1';
                        beep_count <= 0;

                    elsif q2 = '0' and q1 = '0' and q0 = '1' then
                        -- 1 wrong attempt -> 2 wrong attempts
                        q2 <= '0';
                        q1 <= '1';
                        q0 <= '0';
                        beep_short <= '1';
                        beep_count <= 0;

                    elsif q2 = '0' and q1 = '1' and q0 = '0' then
                        -- 2 wrong attempts -> 3 wrong attempts = LOCK
                        q2 <= '0';
                        q1 <= '1';
                        q0 <= '1';
                        lock_flag <= '1';
                        beep_short <= '0';

                    else
                        -- stay locked for any higher state
                        q2 <= '0';
                        q1 <= '1';
                        q0 <= '1';
                        lock_flag <= '1';
                        beep_short <= '0';
                    end if;
                end if;
            end if;
        end if;
    end process;

  
    -- OUTPUTS
   
    access_granted <= green_reg;

    -- red LED turns on for wrong attempt or lock
    access_denied <= (not green_reg) and (red_reg or lock_flag);

    -- buzzer = short beep on wrong attempts, continuous when locked
    buzzer <= beep_short or lock_flag;

    -- external lock status
    lock <= lock_flag;


    -- SELECT WHETHER TO SHOW NUMBER OR LOCK
    -- show_lock = 1 means display "L"
 
    show_lock <= lock_flag;

 
    -- ACTIVE-LOW 7-SEGMENT FOR 0,1,2,3 USING q1,q0
    -- segment order = a b c d e f g
  
    -- 0
    -- 1
    -- 2
    -- 3
segment_num_logic: process(q1, q0)
begin
    if q1 = '0' and q0 = '0' then
        -- 0
        seg_num <= "0000001";
    elsif q1 = '0' and q0 = '1' then
        -- 1
        seg_num <= "1001111";
    elsif q1 = '1' and q0 = '0' then
        -- 2
        seg_num <= "0010010";
    else
        -- 3
        seg_num <= "0000110";
    end if;
end process;


    -- ACTIVE-LOW "L"
    -- L = d e f on
 
    seg_L <= "1110001";

   
    -- FINAL 7-SEGMENT OUTPUT
    -- if locked show L, otherwise show current attempt count
  
    segment <= seg_L when show_lock = '1' else seg_num;

  
    -- BASYS 3 DISPLAY SETTINGS
    
    dp <= '1';       -- decimal point OFF
    an <= "1110";    -- use only the rightmost digit


end Behavioral;

