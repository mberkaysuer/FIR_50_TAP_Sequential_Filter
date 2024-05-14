----------------------------------------------------------------------------------
 
-- Engineer: Mustafa Berkay SÜER 
-- 
-- Create Date: 12.05.2024 
-- Design Name: 
-- Module Name: FIR_LP_50_TAP - Behavioral
-- Project Name: FIR Low Pass Filter

-- Description: Sequential 50 Tap FIR(Finite Impulse Response) Low- Pass Filter Design with IEEE 754 32 bit floating point single precision.
-- Cutoff frequency 400 Hz. 50th order.
-- An FIR Filter consist series of delay elements and coefficents. The input signal is multiplied by these coefficents, and the resuts    
-- are summed to produce filtered output. 
-- Until all taps are full, filtered output won't show the correct data. In this case this filter won't be able to produce correct data until all 
-- 50 taps are full. 
-- 
-- Filter will delay input data when a new data arrives. Normally a new data should arrive every clock cycle but completing a 32 bit floating point operation 
-- takes more than one clock cycle. 
--
-- This design has 4 States. 
-- Idle State: In this state filter will wait for a 'Valid Date'. When 'datavalid_i' becomes '1', Filter moves to next state. 
-- Mul State: In this state filter multiplies incoming data with filter coefficent. When 'ready_o' signal becomes '1', filter moves to Result state. 
-- To produce a correct filtered data, filter will multiply every tap and even thou there are no valid date in the other taps.
-- Sum State: In this state filter will sum all the data in the 'mults' array one by one. After each sum, when 'ready_o' becomes '1', it will mover The
-- result state.   
-- Result State: This is the state where the filter decides when the transition between Mul state and Sum state takes place. 
-- In the result state, first it will save every multiplied data to an array called 'mults' and after the all multiplication is completed, 
-- filter will move to Sum state to finish the process. 
-- After all elements in the mults array are summed, filter will send 'dataready_o' signal as '1' and will go to the IDLE state to wait another valid Data. 
-- 
-- Additional Comments:
-- I want to thank Mehmet Burak Aykenar and Jidan Al-Eryani. 
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work; 
use work.fpupack.all;
use work.comppack.all;

entity FIR_LP_50_TAP is
generic (
c_clkfreq	: integer := 100_000_000
);
port (
clk			: in std_logic;
datain_i	: in std_logic_vector (31 downto 0);
datavalid_i	: in std_logic;
dataout_o	: out std_logic_vector (31 downto 0);
dataready_o	: out std_logic
);
end FIR_LP_50_TAP;

architecture Behavioral of FIR_LP_50_TAP is 
component fpu 
port (
        clk_i 			: in std_logic;

        -- Input Operands A & B
        opa_i        	: in std_logic_vector(FP_WIDTH-1 downto 0);  -- Default: FP_WIDTH=32 
        opb_i           : in std_logic_vector(FP_WIDTH-1 downto 0);
        
        -- fpu operations (fpu_op_i):
		-- ========================
		-- 000 = add, 
		-- 001 = substract, 
		-- 010 = multiply, 
		-- 011 = divide,
		-- 100 = square root
		-- 101 = unused
		-- 110 = unused
		-- 111 = unused
        fpu_op_i		: in std_logic_vector(2 downto 0);
        
        -- Rounding Mode: 
        -- ==============
        -- 00 = round to nearest even(default), 
        -- 01 = round to zero, 
        -- 10 = round up, 
        -- 11 = round down
        rmode_i 		: in std_logic_vector(1 downto 0);
        
        -- Output port   
        output_o        : out std_logic_vector(FP_WIDTH-1 downto 0);
        
        -- Control signals
        start_i			: in std_logic; -- is also restart signal
        ready_o 		: out std_logic;
        
        -- Exceptions
        ine_o 			: out std_logic; -- inexact
        overflow_o  	: out std_logic; -- overflow
        underflow_o 	: out std_logic; -- underflow
        div_zero_o  	: out std_logic; -- divide by zero
        inf_o			: out std_logic; -- infinity
        zero_o			: out std_logic; -- zero
        qnan_o			: out std_logic; -- queit Not-a-Number
        snan_o			: out std_logic -- signaling Not-a-Number


);
end component;

signal opa_i          : std_logic_vector(FP_WIDTH-1 downto 0);
signal opb_i          : std_logic_vector(FP_WIDTH-1 downto 0);
signal fpu_op_i       : std_logic_vector(2 downto 0);
signal rmode_i        : std_logic_vector(1 downto 0);
signal output_o       : std_logic_vector(FP_WIDTH-1 downto 0);
signal start_i	      : std_logic;
signal ready_o        : std_logic;
signal ine_o 		  : std_logic;
signal overflow_o     : std_logic;
signal underflow_o    : std_logic;
signal div_zero_o     : std_logic;
signal inf_o		  : std_logic;
signal zero_o		  : std_logic;
signal qnan_o		  : std_logic;
signal snan_o		  : std_logic;
signal counter		  : integer range 0 to 50;
signal first		  : std_logic := '1';
signal mult_counter	  : integer range 0 to 50;
signal adder_counter  : integer range 0 to 399;
--------------------------------------------------------------------
--ROM
-- Filter Coefficents for Low Pass filter.
type ROM_type is array ( 0 to 50 ) of std_logic_vector(31 downto 0);

	constant ROM : ROM_type := (
			0	=> x"BA4521DE",
			1	=> x"BB6523DC",
			2	=> x"BB28E135",
			3	=> x"BB419B40",
			4	=> x"BAF95699",
			5	=> x"389EF6D1",
			6	=> x"3B3F7850",
			7	=> x"3BC60609",
			8	=> x"3C0CF61D",
			9	=> x"3C1DCD70",
			10	=> x"3C07C343",
			11	=> x"3B876915",
			12	=> x"BB2B0ADB",
			13	=> x"BC331F11",
			14	=> x"BC9C502D",
			15	=> x"BCCB1B52",
			16	=> x"BCD29091",
			17	=> x"BCA2933D",
			18	=> x"BBC9BBA0",
			19	=> x"3C784663",
			20	=> x"3D2DE6A8",
			21	=> x"3D952A19",
			22	=> x"3DD1EB35",
			23	=> x"3E0279D7",
			24	=> x"3E1378B2",
			25	=> x"3E196F15",
			26	=> x"3E1378B2",
			27	=> x"3E0279D7",
			28	=> x"3DD1EB35",
			29	=> x"3D952A19",
			30	=> x"3D2DE6A8",
			31	=> x"3C784663",
			32	=> x"BBC9BBA0",
			33	=> x"BCA2933D",
			34	=> x"BCD29091",
			35	=> x"BCCB1B52",
			36	=> x"BC9C502D",
			37	=> x"BC331F11",
			38	=> x"BB2B0ADB",
			39	=> x"3B876915",
			40	=> x"3C07C343",
			41	=> x"3C1DCD70",
			42	=> x"3C0CF61D",
			43	=> x"3BC60609",
			44	=> x"3B3F7850",
			45	=> x"389EF6D1",
			46	=> x"BAF95699",
			47	=> x"BB419B40",
			48	=> x"BB28E135",
			49	=> x"BB6523DC",
			50	=> x"BA4521DE");
	


---------------------------------------------------------------------
--States and signals

type t_state is (IDLE,MUL, ADD,RESULT);
signal s_state : t_state:=IDLE; 


signal sum 	   :std_logic_vector(31 downto 0) := (others => '0');  
signal multi 	   :std_logic_vector(31 downto 0);
---------------------------------------------------------------------
-- Time delay 

type delayed_input_type is array (0 to 50) of std_logic_vector(31 downto 0);
signal delayed_input :delayed_input_type:= (others => x"00000000"); 

-----------------------------------------------------------------------
-- MUL Array 
type mults_type is array (0 to 50) of std_logic_vector(31 downto 0); 
signal mults: mults_type; 

------------------------------------------------------------------------


begin

fpu_p : fpu
port map(
clk_i		 => clk			 ,
opa_i        => opa_i        ,
opb_i        => opb_i        ,
fpu_op_i     => fpu_op_i     ,
rmode_i      => rmode_i      ,
output_o     => output_o     ,
start_i	     => start_i	    ,
ready_o      => ready_o      ,
ine_o 		 => ine_o 		,
overflow_o   => overflow_o   ,
underflow_o  => underflow_o  ,
div_zero_o   => div_zero_o   ,
inf_o		 => inf_o		,
zero_o		 => zero_o		,
qnan_o		 => qnan_o		,
snan_o		 => snan_o		
);
------------------------------
-- x[n], x[n-1}, x[n-2]....x[n-N]

delay: process(datavalid_i) 
begin 
if rising_edge(datavalid_i) then 
    delayed_input(0)<=datain_i; 
		for i in 1 to 50 loop 
	
		
		delayed_input(i) <= delayed_input(i-1); 
	
	
		end loop;
end if;
end process;


---------------------------------


main_process :process(clk) 
begin 
	if rising_edge(clk) then 
				
				case s_state is
				when IDLE => 
				dataready_o <= '0';
				if datavalid_i = '1' then 
				start_i <= '1';
				fpu_op_i <= "010"; 	
				s_state <= MUL ;
				end if;
			
				when	MUL => 
				start_i <= '0';
				dataready_o <= '0'; 

			
				
				
					if (ready_o = '0') then 
					
					
							opa_i <= delayed_input(mult_counter); 

							opb_i <= ROM(mult_counter); 
			
						
					else
						
						s_state <= RESULT; 
					
						 
					end if; 
				
				
				
				
				
					when	ADD =>
					start_i <= '0';
					
					if ready_o= '0' then 
				
						opa_i <= mults(adder_counter);
						opb_i <= sum;				
					
					else    
					
						sum	<=	output_o; -- Caused a problem. I added another output assignment in the result state.
					    s_state <= RESULT; 
					
					end if;
					
				
			
				

			when RESULT => 
			if(fpu_op_i = "000") then 
			    if(adder_counter = 50) then 
				adder_counter <= 0;
				dataout_o <= sum; 
				dataready_o <='1'; 
				sum <=x"00000000";
				fpu_op_i <= "010";
				--start_i <='1';
				s_state <= IDLE; 

				else 
				adder_counter <= adder_counter +1 ;
				sum	<=	output_o;
				start_i <='1';
				fpu_op_i <= "000";
				s_state <= ADD;
				
				
				end if;
				 

				
				
				
			elsif (fpu_op_i = "010") then 
			
			if mult_counter= 50 then 
			mults(mult_counter) <= output_o; 
			mult_counter <= 0;
		
			start_i <= '1';
			fpu_op_i <= "000";
			s_state <= ADD; 
			
			else
			mults(mult_counter) <= output_o; 
			mult_counter <= mult_counter + 1 ;
			start_i <= '1';
			s_state <= MUL; 
			end if;
			
			
			end if;
			    

			
			end case; 
			

	
	end if;
end process main_process;


		
	
		
		
end Behavioral;