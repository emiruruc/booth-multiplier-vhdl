----------------------------------------------------------------------------------
-- Author      : Emir Uruç
-- Project     : Sequential Booth Multiplier in VHDL
-- Module      : tb_multiplier
--
-- Description :
--   Self-checking testbench for the multiplier entity. It applies every
--   possible pair of N-bit signed operands (-2^(N-1) .. 2^(N-1)-1), one
--   multiplication after the other without resetting in between, and compares
--   result_o with the product computed by the VHDL "*" operator.
--
-- Result      :
--   Success : the run ends with "Failure: SIM DONE" (severity failure is only
--             used to stop the simulation).
--   Mismatch: the run stops with "Failure: ERROR" at the first wrong result.
--
-- Notes       :
--   - The operand width is set by the generic N. The number of pairs grows as
--     4^N, so large N takes a long time to simulate.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;



entity tb_multiplier is
generic(
N : integer := 5
);
end tb_multiplier;


architecture Behavioral of tb_multiplier is

signal clk        		 : std_logic := '0';
signal rst			     : std_logic := '0';
signal enable 		  	 : std_logic := '0';
signal multiplicand_i	 : integer 	 := 0;
signal multiplier_i      : integer 	 := 0;	
signal result_o          : integer 	 := 0;
signal ready_o			 : std_logic := '0';

	  
begin

DUT : entity work.multiplier(Behavioral)
generic map(
N => N 
)
port map(
clk			         => clk	  				,
rst			         => rst		            ,
enable 		         => enable 		        ,
multiplicand_i       => multiplicand_i      ,
multiplier_i         => multiplier_i        ,
ready_o  			 => ready_o				,
result_o	         => result_o	        
);


-- 10 ns clock
P_CLKGEN :process begin 
clk <= '0';
wait for 5 ns;
clk <= '1';
wait for 5 ns;
end process P_CLKGEN;



P_STIMULI: process begin 

-- initial reset
rst <= '1';
wait for 100 ns;
rst <= '0';
wait for 100 ns;

-- sweep all operand pairs
for i in -(2**(N-1)) to (2**(N-1)-1) loop
	for j in -(2**(N-1)) to (2**(N-1)-1) loop

		-- change the operands on the falling edge, away from the DUT's sampling edge
		wait until (falling_edge(clk));
		multiplicand_i <= i;
		multiplier_i   <= j;
		
		-- one-clock enable pulse
		wait until (rising_edge(clk));
		enable <= '1';
		
		wait until (rising_edge(clk));
		enable <= '0';
		
		-- result_o is valid when ready_o rises
		wait until rising_edge(ready_o);
		

assert (result_o = multiplicand_i * multiplier_i)
report "ERROR"
severity failure;

	end loop;
end loop;

-- all pairs passed: end the simulation
assert false 
report "SIM DONE"
severity failure;
wait;

end process P_STIMULI;

end Behavioral;