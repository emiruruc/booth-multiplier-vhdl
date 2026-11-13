----------------------------------------------------------------------------------
-- Author      : Emir Uruç
-- Project     : Sequential Booth Multiplier in VHDL
-- Module      : multiplier_error
--
-- Description :
--   Copy of multiplier.vhd with ONE deliberately injected fault: q_l is not
--   cleared in the START state. Used with tb_multiplier_error to show that
--   the testbench detects a bug when one multiplication
--   follows another.
--
-- Description :
--   Parameterized (N-bit) sequential signed multiplier using radix-2 Booth's
--   algorithm, controlled by a 7-state FSM. Takes two signed integers (N-bit
--   range) and returns their 2N-bit signed product.
--
-- Usage       :
--   Apply both operands, pulse enable for one clock cycle, then wait for
--   ready_o to go high. result_o is valid while ready_o = '1'. ready_o stays
--   high until the next multiplication is accepted.
--
-- Notes       :
--   - The accumulator is N+1 bits wide so that results such as
--     0 - (-2^(N-1)) do not overflow.
--   - Synchronous, active-high reset.
--   - Operands outside the N-bit range are truncated by to_signed.
--   - The 2N-bit product must fit in a VHDL integer (N <= 16).
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity multiplier_error is
generic(
N : integer := 5    -- operand width in bits
);
port(
clk			   : in std_logic;
rst			   : in std_logic;
enable 		   : in std_logic;
multiplicand_i : in integer;
multiplier_i   : in integer;
ready_o 	   : out std_logic;
result_o	   : out integer
);
end multiplier_error;

architecture Behavioral of multiplier_error is

signal accumulator : signed(N downto 0) 	:= (others => '0');  -- A register, N+1 bits (extra bit keeps the true sign)
signal q		   : signed(N-1 downto 0) 	:= (others => '0');  -- multiplier register Q
signal m 		   : signed(N-1 downto 0) 	:= (others => '0');  -- multiplicand M
signal q_l  	   : std_logic 			  	:= '0';              -- Q-1: bit shifted out in the previous step
signal count 	   : integer   			  	:= 0;                -- remaining iterations
signal combined    : signed(2*N+1 downto 0)   := (others => '0');  -- {sign copy, A, Q}, used for the right shift
signal result_r    : signed(2*N-1 downto 0) := (others => '0');  -- 2N-bit product



-- START: idle/load | CHECK: Booth decision | ADD, SUBTRACT: update A
-- SHIFT, CHECK_2: arithmetic right shift | RESULT: drive the outputs
type states is (START, CHECK, ADD, SUBTRACT, SHIFT, CHECK_2, RESULT);
signal state : states := START;


begin

process(clk) 
begin
if (rising_edge(clk)) then

	if (rst = '1') then 

		-- synchronous reset: clear everything and return to START
		accumulator  <= (others => '0');
		q		  	 <= (others => '0');		
		m 		  	 <= (others => '0');
		q_l  	  	 <= '0';
		count 	  	 <= 0;	
		combined   	 <= (others => '0');
		result_r     <= (others => '0');
		state 		 <= START;
		ready_o        <= '0';
		result_o     <= 0;
	
	else 
	
		case state is
			when START => 
				
				-- INJECTED FAULT: q_l is intentionally NOT cleared here.
				-- The correct design has "q_l <= '0';" at this point, so no stale Q-1 bit
				-- from the previous multiplication can reach the next one.
				accumulator  <= (others => '0');
			
		
				-- new multiplication: load operands and start counting
				if(enable = '1') then 
					q     <= to_signed(multiplier_i, q'length); 
					m     <= to_signed(multiplicand_i, m'length);
					count <= N;
					state <= CHECK;
					ready_o       <= '0';
				end if;
				
			when CHECK => 
				
				-- Booth decision on (Q0, Q-1) = (q(0), q_l)
				-- (1,0):  -> subtract
				-- (0,1):  -> add
				-- (0,0) or (1,1) -> shift only
				if(q_l = '1' and q(0) ='0') then 
					state <= ADD;
				end if;
				
				if(q_l = '0' and q(0) ='1') then 
					state <= SUBTRACT;
				end if;
				
				if((q_l = '0' and q(0) ='0') or (q_l = '1' and q(0) ='1')) then 
					state <= SHIFT;
				end if;
				
			when ADD => 
				
				-- M is sign-extended to N+1 bits
				accumulator <= accumulator + (m(m'left) & m);
				state  	 	<= SHIFT;
				
			when SUBTRACT => 
			
				accumulator <= accumulator - (m(m'left) & m);
				state  	 	<= SHIFT;
			
			when SHIFT => 
			
				-- {sign copy, A, Q}: the shift itself is done by slicing in CHECK_2
				-- (a signal written here is only visible one clock later)
				combined 	<= accumulator(N) & accumulator & q;
				count    	<= count -1;
				state		<= CHECK_2;
			
				
			when CHECK_2 => 
				
				if (count = 0) then
					-- last iteration: the 2N-bit product is combined(2N downto 1)
					state        <= RESULT;
					result_r 	 <= combined(2*N downto 1);
					
				else
					-- right-shifted values become the new A, Q and Q-1
					accumulator <= combined(2*N+1 downto N+1);
					q 			<= combined(N downto 1);
					q_l         <= combined(0);
					state    	<= CHECK;
				end if;
				
			
			when RESULT => 
			
				-- result_o and ready_o change on the same clock edge
				result_o <= to_integer(result_r);
				state    <= START;
				ready_o 		 <= '1';

		end case;
	end if;
	
	
end if;
end process; 

end Behavioral;