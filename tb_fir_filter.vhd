


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use std.textio.all; 
use IEEE.STD_LOGIC_textio.all;


entity tb_fir_filter is
generic (
c_clkfreq	: integer := 100_000_000
);
end tb_fir_filter;



architecture Behavioral of tb_fir_filter is
component FIR_LP_50_TAP 
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
end component; 

signal clk			: std_logic := '0';
signal datain_i	    : std_logic_vector (31 downto 0) := (others => '0');
signal datavalid_i	: std_logic := '0';
signal dataout_o	: std_logic_vector (31 downto 0);
signal dataready_o	: std_logic;

signal counter_write : integer := 0;

file input_file : TEXT open READ_MODE is "noisy_sine_wave.txt";

file output_file : TEXT;
begin





dev_to_test : FIR_LP_50_TAP 
generic map(
c_clkfreq => c_clkfreq

)
port map (
clk			=>clk			,
datain_i	=>datain_i	,
datavalid_i	=>datavalid_i	,
dataout_o	=>dataout_o	,
dataready_o	=>dataready_o	
);





clk_stimulus : process 
begin 
wait for 5 ns; 
clk <= not clk; 
end process; 

data_stimulus :process
file output_file : text open write_mode is "C:/Users/musta/OneDrive/Masast/FPGA/projects/FIR_LP_50_TAP/FIR_LP_50_TAP.srcs/sim_1/new/filtered_sine_wave.txt";
variable write_buf : line ;

variable read_from_input_buf : line ; 
variable hex : std_logic_vector(31 downto 0);
begin 
    while not ENDFILE(input_file) loop
     READLINE(input_file, read_from_input_buf);
	 hread(read_from_input_buf,hex); 
	wait until falling_edge(clk); 	
	datain_i <= hex;	
     datavalid_i <='1'; 
	 wait for 10 ns; 
	 datavalid_i <= '0';
	 wait until rising_edge(dataready_o); 
	 hwrite(write_buf,dataout_o);
	 writeline(output_file,write_buf);
     wait for 10 ns;
	end loop;

	file_close(input_file);
	wait; 

end process;



end Behavioral;
