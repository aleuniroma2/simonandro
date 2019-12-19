----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 20.10.2019 16:26:29
-- Design Name: 
-- Module Name: Reconfigurator - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use work.ram_pkg.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity Reconfigurator2 is

generic (
    NB_COL    : integer := 32;                       -- Specify number of columns (number of bytes)
    COL_WIDTH : integer := 8;                       -- Specify column width (byte width, typically 8 or 9)
    RAM_DEPTH : integer := 1024;                    -- Specify RAM depth (number of entries)
    INIT_FILE : string := "";            -- Specify name/location of RAM initialization file if using one (leave blank if not)
    ADDED_BITS: integer:= 2
    );

    Port (
           key: in std_logic_vector(NB_COL*COL_WIDTH/2 - 1 downto 0);   --128 bit massimi
           value: in std_logic_vector(NB_COL*COL_WIDTH/2 - 3 downto 0); --126 bit massimi
 
           control_in: in std_logic_vector(1 downto 0);
           control_out_a, control_out_b: out std_logic_vector(1 downto 0);
           
           data_a, data_b: in std_logic_vector(NB_COL*COL_WIDTH - 1 downto 0);
           
           key_len, value_len: in std_logic_vector(7 downto 0);
           we_a, we_b: in std_logic;
           switch: in std_logic;
           address_a: in std_logic_vector((clogb2(RAM_DEPTH) +ADDED_BITS -1) downto 0); --aggiungendo altri 2 bit andro ad indirizzare fino a 4 volte il numero di parole di dimensione un quarto
           address_b: in std_logic_vector((clogb2(RAM_DEPTH) +ADDED_BITS -1) downto 0);
           clk: in std_logic;
          -- data_out_a: out std_logic_vector(NB_COL*COL_WIDTH-1 downto 0);
          -- data_out_b: out std_logic_vector(NB_COL*COL_WIDTH-1 downto 0);
           
           key_out_a:   out std_logic_vector(NB_COL*COL_WIDTH/2 - 1 downto 0);   --128 bit massimi
           value_out_a: out std_logic_vector(NB_COL*COL_WIDTH/2 - 1 downto 0);   --128 bit massimi

           key_out_b:   out std_logic_vector(NB_COL*COL_WIDTH/2 - 1 downto 0);   --128 bit massimi
           value_out_b: out std_logic_vector(NB_COL*COL_WIDTH/2 - 1 downto 0)   --128 bit massimi
          
          -- quartimod: in std_logic   -- 1 se le word le scrivo un quarto e tre quarti, 0 altrimenti dove sono met�
             );
end Reconfigurator2;

architecture Behavioral of Reconfigurator2 is

--SEGNALI-----------------------------------

signal data_in_a, data_in_b, data_in_hash, data_in_ram_a, data_in_ram_b, data_out_ram_a, data_out_ram_b, data_out_a, data_out_b: std_logic_vector(NB_COL*COL_WIDTH-1 downto 0); -- dimensioni massime di data_in, relative alle dimensioni della ram generata
signal word_dimension, word_dimension_r: std_logic_vector(8 downto 0);  --somma di key e value len
signal zeros: std_logic_vector(255 downto 0):=(others => '0'); --segnale di appoggio per tutti 0
signal address_ram_a, address_ram_b:std_logic_vector((clogb2(RAM_DEPTH) - 1) downto 0);
signal we_byte_a, we_byte_b: std_logic_vector(NB_COL-1 downto 0);      --per parole di 256, abbiamo 256/8 = 32 we
signal len: std_logic_vector(15 downto 0);
signal key_len_r, value_len_r: std_logic_vector(7 downto 0);

signal address_out_a, address_out_b: std_logic_vector((clogb2(RAM_DEPTH) +ADDED_BITS -1 )downto 0);

--COMPONENTS---------------------------------


component xilinx_true_dual_port_read_first_byte_write_2_clock_ram is


port (
        addra : in std_logic_vector((clogb2(RAM_DEPTH)-1) downto 0);     -- Port A Address bus, width determined from RAM_DEPTH
        addrb : in std_logic_vector((clogb2(RAM_DEPTH)-1) downto 0);     -- Port B Address bus, width determined from RAM_DEPTH
        dina  : in std_logic_vector(NB_COL*COL_WIDTH-1 downto 0);		  -- Port A RAM input data
        dinb  : in std_logic_vector(NB_COL*COL_WIDTH-1 downto 0);		  -- Port B RAM input data
        clka  : in std_logic;                       			  -- Port A Clock
        clkb  : in std_logic;                       			  -- Port B Clock
        wea   : in std_logic_vector(NB_COL-1 downto 0);	  -- Port A Write enable
        web   : in std_logic_vector(NB_COL-1 downto 0); 	  -- Port B Write enable
        ena   : in std_logic;                       			  -- Port A RAM Enable, for additional power savings, disable port when not in use
        enb   : in std_logic;                       			  -- Port B RAM Enable, for additional power savings, disable port when not in use
--        rsta  : in std_logic;                       			  -- Port A Output reset (does not affect memory contents)
--        rstb  : in std_logic;                       			  -- Port B Output reset (does not affect memory contents)
--        regcea: in std_logic;                       			  -- Port A Output register enable
--        regceb: in std_logic;                       			  -- Port B Output register enable
        douta : out std_logic_vector(NB_COL*COL_WIDTH-1 downto 0);   --  Port A RAM output data
        doutb : out std_logic_vector(NB_COL*COL_WIDTH-1 downto 0)   	--  Port B RAM output data
    );

end component;



--------------------------------------------
begin


 --   A: process(key,value,key_len,value_len ) --determino, con casi ben specifici, la dimensione delle word della ram e creo il vettore data_in della ram
 --   begin



	len <= value_len_r & key_len_r;
	
    Seq: process(clk)
    begin
         if (clk'event and clk = '1') then
             word_dimension_r <= word_dimension;
             key_len_r <= key_len;
             value_len_r <= value_len;
             address_out_a <= address_a;
             address_out_b <= address_b;
             
         end if;
    end process;
    
--	B:process(control_in, value, key, data_out_a, data_out_b, len, zeros )
	
--	begin
--		case(len) is
--			when "1000000010000000" =>

--				 word_dimension <= std_logic_vector(to_unsigned(256,9));                                              
--        			 data_in_hash    <=  control_in & value & key ;
--	         		 key_out_a       <=  data_out_a(127 downto 0);
--       	 		 	 key_out_b       <=  data_out_b(127 downto 0);
--         			 value_out_a     <=                       data_out_a(255 downto 128);
--         			 value_out_b     <=  data_out_b(255 downto 128);
--			when "0100000001000000"	 =>
--				 word_dimension <= std_logic_vector(to_unsigned(128,9));                                              
--        			 data_in_hash    <=  zeros(127 downto 0) & control_in & value(61 downto 0) & key(63 downto 0);
--	         		 key_out_a       <=  zeros(63 downto 0) & data_out_a(63 downto 0);
--	         		 key_out_b       <=  zeros(63 downto 0) & data_out_b(63 downto 0);
--         			 value_out_a     <=  zeros(63 downto 0) & data_out_a(127 downto 64);
--         			 value_out_b     <=  zeros(63 downto 0) & data_out_b(127 downto 64);
--			when "0010000001100000" =>
--				 word_dimension <= std_logic_vector(to_unsigned(128,9));                                              
--        			 data_in_hash    <=  zeros(127 downto 0) & control_in & value(29 downto 0) & key(95 downto 0);
--	         		 key_out_a       <=  zeros(31 downto 0) & data_out_a(95 downto 0);
--	         		 key_out_b       <=  zeros(31 downto 0) & data_out_b(95 downto 0);
--         			 value_out_a     <=  zeros(95 downto 0) & data_out_a(127 downto 96);
--         			 value_out_b     <=  zeros(95 downto 0) & data_out_b(127 downto 96);
--			when "0010000000100000" =>
--				 word_dimension <= std_logic_vector(to_unsigned(64,9));                                              
--        			 data_in_hash    <=  zeros(191 downto 0) & control_in & value(29 downto 0) & key(31 downto 0);
--	         		 key_out_a       <=  zeros(95 downto 0) & data_out_a(31 downto 0);
--	         		 key_out_b       <=  zeros(95 downto 0) & data_out_b(31 downto 0);
--         			 value_out_a     <=  zeros(95 downto 0) & data_out_a(63 downto 32);
--         			 value_out_b     <=  zeros(95 downto 0) & data_out_b(63 downto 32);
--			when "0001000000110000" =>
--				 word_dimension <= std_logic_vector(to_unsigned(64,9));                                              
--        			 data_in_hash    <=  zeros(191 downto 0) & control_in & value(13 downto 0) & key(47 downto 0);
--	         		 key_out_a       <=  zeros(79 downto 0) & data_out_a(47 downto 0);
--	         		 key_out_b       <=  zeros(79 downto 0) & data_out_b(47 downto 0);
--         			 value_out_a     <=  zeros(111 downto 0) & data_out_a(63 downto 48);
--         			 value_out_b     <=  zeros(111 downto 0) & data_out_b(63 downto 48);
--			when others =>
--				word_dimension <= (others => '0');
--				data_in_hash <= (others => '0');
--				key_out_a <= (others => '0');
--				key_out_b <= (others => '0');
--				value_out_a <= (others => '0');
--				value_out_b <= (others => '0');
--            end case;

--	end process;


--	word_dimension <= std_logic_vector(to_unsigned(256,9)) when  (value_len(7)='1') and     (key_len(7)='1') else                                               
--                          std_logic_vector(to_unsigned(128,9)) when ((value_len(6)='1') and     (key_len(6)='1'))  or ((value_len(5)='1') and (key_len(6)='1')) else
--                          std_logic_vector(to_unsigned(64,9))  when ((value_len(5)='1') and (not(key_len(6))='1')) or  (value_len(4)='1'  and  key_len(5)='1')  else
--                          (others => '0');
                           
        data_in_hash        <= control_in & value & key                                            when  (value_len(7)='1') and     (key_len(7)='1')   else -- word da 128 e 128
                          zeros(127 downto 0) & control_in & value(61 downto 0) & key(63 downto 0) when ((value_len(6)='1') and     (key_len(6)='1'))  else -- word da 64 e 64
                          zeros(127 downto 0) & control_in & value(29 downto 0) & key(95 downto 0) when  (value_len(5)='1'  and      key_len(6) ='1')  else -- word da 32 e 96
                          zeros(191 downto 0) & control_in & value(29 downto 0) & key(31 downto 0) when ((value_len(5)='1') and (not(key_len(6))='1')) else -- word da 32 e 32
                          zeros(191 downto 0) & control_in & value(13 downto 0) & key(47 downto 0) when  (value_len(4)='1'  and      key_len(5) = '1') else   -- word da 16 e 48
                          (others => '0');
                          
--         key_out_a       <=                       data_out_a(127 downto 0) when (value_len(7)='1') and (key_len(7)='1')   else
--                             zeros(63 downto 0) & data_out_a(63  downto 0) when (value_len(6)='1') and (key_len(6)='1')   else
--                             zeros(31 downto 0) & data_out_a(95  downto 0) when (value_len(5)='1') and (key_len(6)='1')   else
--                             zeros(95 downto 0) & data_out_a(31  downto 0) when (value_len(5)='1') and (not(key_len(6))='1')   else
--                             zeros(79 downto 0) & data_out_a(47  downto 0) when (value_len(4)='1') and (key_len(5)='1')   else
--                             (others => '0');
 
--         value_out_a     <=                       data_out_a(255 downto 128) when (value_len(7)='1') and (key_len(7)='1')   else
--                             zeros(63 downto 0) & data_out_a(127  downto 64) when (value_len(6)='1') and (key_len(6)='1')   else
--                             zeros(95 downto 0) & data_out_a(127  downto 96) when (value_len(5)='1') and (key_len(6)='1')   else
--                             zeros(95 downto 0) & data_out_a(63  downto 32) when (value_len(5)='1') and (not(key_len(6))='1')   else
--                             zeros(111 downto 0) & data_out_a(63  downto 48) when (value_len(4)='1') and (key_len(5)='1')   else
--                             (others => '0');
            
--         key_out_b       <=  data_out_b(127 downto 0) when (value_len(7)='1') and (key_len(7)='1')   else
--                             zeros(63 downto 0) & data_out_b(63  downto 0) when (value_len(6)='1') and (key_len(6)='1')   else
--                             zeros(31 downto 0) & data_out_b(95  downto 0) when (value_len(5)='1') and (key_len(6)='1')   else
--                             zeros(95 downto 0) & data_out_b(31  downto 0) when (value_len(5)='1') and (not(key_len(6))='1')   else
--                             zeros(79 downto 0) & data_out_b(47  downto 0) when (value_len(4)='1') and (key_len(5)='1')   else
--                             (others => '0');
                     
--         value_out_b     <=  data_out_b(255 downto 128) when (value_len(7)='1') and (key_len(7)='1')   else
--                             zeros(63 downto 0) & data_out_b(127  downto 64) when (value_len(6)='1') and (key_len(6)='1')   else
--                             zeros(95 downto 0) & data_out_b(127  downto 96) when (value_len(5)='1') and (key_len(6)='1')   else
--                             zeros(95 downto 0) & data_out_b(63  downto 32) when (value_len(5)='1') and (not(key_len(6))='1')   else
--                             zeros(111 downto 0) & data_out_b(63  downto 48) when (value_len(4)='1') and (key_len(5)='1')   else
--                             (others => '0');


         data_in_a       <= data_a;        
         data_in_b       <= data_b when switch = '1' else data_in_hash;                                                      --lo switch va attaccato al we dell'hash table per decidere data in tra axi e hash
--   A: process(word_dimension,clk, data_in)
--      begin
--   --    case word_dimension
--       if(clk'event and clk = '1') then
--            if (data_in = "0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000") then
--                   data_out <= data_in ;   
--            else
--                   data_out <= (others =>'0');   
--            end if;
--        end if;
--      end process;
--                   we_byte_out <= we_byte;
                   --data_out    <= data_in_ram ;   
                   
                   
                   
DUT : xilinx_true_dual_port_read_first_byte_write_2_clock_ram

 
  port map  (
 addra  => address_ram_a,
 addrb  => address_ram_b,
 dina   => data_in_ram_a,
 dinb   => data_in_ram_b,
 clka   => clk,
 clkb   => clk,
 wea    => we_byte_a,
 web    => we_byte_b,
 ena    => '1',
 enb    => '1',
-- rsta   => rsta,
-- rstb   => rstb,
-- regcea => regcea,
-- regceb => regceb,
 douta  => data_out_ram_a,
 doutb  => data_out_ram_b
);                   
                   
                   
                   
                   
   A: process(len, address_a, address_b, we_a, we_b, data_in_a, data_in_b, data_out_ram_a, data_out_ram_b, address_out_a, address_out_b)
begin
    case len is
         when "1000000010000000" =>                                   --word dim 256
               control_out_a   <= data_out_ram_a(255 downto 254);
               control_out_b   <= data_out_ram_b(255 downto 254);
               key_out_a    <=  data_out_ram_a(127 downto 0);
               key_out_b   <=  data_out_ram_b(127 downto 0);
               value_out_a     <=  data_out_ram_a(255 downto 128);
               value_out_b     <=  data_out_ram_b(255 downto 128);

               data_in_ram_a <= data_in_a;
               data_in_ram_b <= data_in_b;
               address_ram_a <= address_a(9 downto 0);
               address_ram_b <= address_b(9 downto 0);
               we_byte_a     <= (others => we_a);
               we_byte_b     <= (others => we_b);
               
         when "0100000001000000" =>                                   --word dim 128
                     address_ram_a <= address_a(10 downto 1);
                     address_ram_b <= address_b(10 downto 1);
      --               data_out_a(255 downto 128) <= (others => '0');
      --               data_out_b(255 downto 128) <= (others => '0');
                     key_out_a(127 downto 64) <= (others => '0');
                     key_out_b(127 downto 64) <= (others => '0');
                     value_out_a(127 downto 64) <= (others => '0');
                     value_out_b(127 downto 64) <= (others => '0');
                     
                     if address_out_a(0) = '0' then
                          control_out_a   <= data_out_ram_a(127 downto 126);
                          value_out_a(63 downto 0) <= data_out_ram_a(127 downto 64);
                          key_out_a(63 downto 0)   <= data_out_ram_a(63 downto 0);
                     else   
                          control_out_a   <= data_out_ram_a(255 downto 254);
                       value_out_a(63 downto 0) <= data_out_ram_a(255 downto 192);
                       key_out_a(63 downto 0) <= data_out_ram_a(191 downto 128);
                     end if;
                     if address_a(0) = '0' then
           --               data_out_a(127 downto 0) <= data_out_ram_a(127 downto 0);
                          data_in_ram_a(255 downto 128) <= (others => '0');
                          data_in_ram_a(127 downto 0) <= data_in_a(127 downto 0);
      
                          we_byte_a(31 downto 16) <= (others => '0');
                          we_byte_a(15 downto 0 ) <= (others =>  we_a);
                     else   
      
                          data_in_ram_a(255 downto 128) <= data_in_a(127 downto 0);
                          data_in_ram_a(127 downto 0) <= (others => '0');
      
                          we_byte_a(31 downto 16) <= (others =>  we_a);
                          we_byte_a(15 downto 0 ) <= (others => '0');
                     end if;
                     if address_out_b(0) = '0' then
                          control_out_b   <= data_out_ram_b(127 downto 126);
       --              data_out_b(127 downto 0) <= data_out_ram_b(127 downto 0);
                     value_out_b(63 downto 0) <= data_out_ram_b(127 downto 64);
                     key_out_b(63 downto 0)   <= data_out_ram_b(63 downto 0);
                     else
                          control_out_b   <= data_out_ram_b(255 downto 254);
                 --    data_out_b(127 downto 0) <= data_out_ram_b(255 downto 128);
                     value_out_b(63 downto 0) <= data_out_ram_b(255 downto 192);
                     key_out_b(63 downto 0) <= data_out_ram_b(191 downto 128);
                     end if;
                     if address_b(0) = '0' then
                          data_in_ram_b(255 downto 128) <= (others => '0');
                          data_in_ram_b(127 downto 0) <= data_in_b(127 downto 0);
      
                          we_byte_b(31 downto 16) <= (others => '0');
                          we_byte_b(15 downto 0 ) <= (others =>  we_b);
                     else   
                            
                          data_in_ram_b(255 downto 128) <= data_in_b(127 downto 0);
                          data_in_ram_b(127 downto 0) <= (others => '0');
      
                          we_byte_b(31 downto 16) <= (others =>  we_b);
                          we_byte_b(15 downto 0 ) <= (others => '0');
                     end if;
         when "0010000001100000" =>                                   --word dim 128
                           address_ram_a <= address_a(10 downto 1);
                           address_ram_b <= address_b(10 downto 1);
            --               data_out_a(255 downto 128) <= (others => '0');
            --               data_out_b(255 downto 128) <= (others => '0');
                           key_out_a(127 downto 96) <= (others => '0');
                           key_out_b(127 downto 96) <= (others => '0');
                           value_out_a(127 downto 32) <= (others => '0');
                           value_out_b(127 downto 32) <= (others => '0');
                           if address_out_a(0) = '0' then
			     control_out_a   <= data_out_ram_a(127 downto 126);
                 --               data_out_a(127 downto 0) <= data_out_ram_a(127 downto 0);
                                value_out_a(31 downto 0) <= data_out_ram_a(127 downto 96);
                                key_out_a(95 downto 0)   <= data_out_ram_a(95 downto 0);

			   else
			                 control_out_a   <= data_out_ram_a(255 downto 254);
                                  value_out_a(31 downto 0) <= data_out_ram_a(255 downto 224);
                                  key_out_a(95 downto 0) <= data_out_ram_a(223 downto 128);
 
			   end if;
			   if address_a(0) = '0' then
                 --               control_out_a   <= data_out_ram_a(127 downto 126);
                 --               data_out_a(127 downto 0) <= data_out_ram_a(127 downto 0);
                 --               value_out_a(31 downto 0) <= data_out_ram_a(127 downto 96);
                 --               key_out_a(95 downto 0)   <= data_out_ram_a(95 downto 0);
                                data_in_ram_a(255 downto 128) <= (others => '0');
                                data_in_ram_a(127 downto 0) <= data_in_a(127 downto 0);
          
                                we_byte_a(31 downto 16) <= (others => '0');
                                we_byte_a(15 downto 0 ) <= (others =>  we_a);
                           else   
                           --     control_out_a   <= data_out_ram_a(255 downto 254);
                           --       value_out_a(31 downto 0) <= data_out_ram_a(255 downto 224);
                           --       key_out_a(95 downto 0) <= data_out_ram_a(223 downto 128);
          
                                data_in_ram_a(255 downto 128) <= data_in_a(127 downto 0);
                                data_in_ram_a(127 downto 0) <= (others => '0');
          
                                we_byte_a(31 downto 16) <= (others =>  we_a);
                                we_byte_a(15 downto 0 ) <= (others => '0');
                           end if;

			   if address_out_b(0) = '0' then
			     control_out_b   <= data_out_ram_b(127 downto 126);
                  --              data_out_b(127 downto 0) <= data_out_ram_b(127 downto 0);
                                value_out_b(31 downto 0) <= data_out_ram_b(127 downto 96);
                                key_out_b(95 downto 0)   <= data_out_ram_b(95 downto 0); 

			   else 
			       control_out_b   <= data_out_ram_b(255 downto 254);
                            --    data_out_b(127 downto 0) <= data_out_ram_b(255 downto 128);
                                value_out_b(31 downto 0) <= data_out_ram_b(255 downto 224);
                                key_out_b(95 downto 0) <= data_out_ram_b(223 downto 128);         
			    
			   end if; 
                           if address_b(0) = '0' then
                            --    control_out_b   <= data_out_ram_b(127 downto 126);
                  --              data_out_b(127 downto 0) <= data_out_ram_b(127 downto 0);
                            --    value_out_b(31 downto 0) <= data_out_ram_b(127 downto 96);
                            --    key_out_b(95 downto 0)   <= data_out_ram_b(95 downto 0); 
                              
                                data_in_ram_b(255 downto 128) <= (others => '0');
                                data_in_ram_b(127 downto 0) <= data_in_b(127 downto 0);
          
                                we_byte_b(31 downto 16) <= (others => '0');
                                we_byte_b(15 downto 0 ) <= (others =>  we_b);
                           else   
                            --    control_out_b   <= data_out_ram_b(255 downto 254);
                            --    data_out_b(127 downto 0) <= data_out_ram_b(255 downto 128);
                            --    value_out_b(31 downto 0) <= data_out_ram_b(255 downto 224);
                           --     key_out_b(95 downto 0) <= data_out_ram_b(223 downto 128);                                 
     
                                data_in_ram_b(255 downto 128) <= data_in_b(127 downto 0);
                                data_in_ram_b(127 downto 0) <= (others => '0');
          
                                we_byte_b(31 downto 16) <= (others =>  we_b);
                                we_byte_b(15 downto 0 ) <= (others => '0');
                           end if;
         when "0010000000100000" =>                                   --word dim 64
               address_ram_a <= address_a(11 downto 2);
               address_ram_b <= address_b(11 downto 2);
       --        data_out_a(255 downto 64) <= (others => '0');
         --      data_out_b(255 downto 64) <= (others => '0');
               value_out_a(127 downto 32) <= (others =>'0');
               value_out_b(127 downto 32) <= (others =>'0');
               key_out_a(127 downto 32) <= (others =>'0');
               key_out_b(127 downto 32) <= (others =>'0');
               case address_a(1 downto 0) is
                    when "00" =>
              --            control_out_a             <= data_out_ram_a(63 downto 62);
                         -- data_out_a(63 downto 0) <= data_out_ram_a(63 downto 0);
              --            value_out_a(31 downto 0) <= data_out_ram_a(63 downto 32);
              --            key_out_a  (31 downto 0) <= data_out_ram_a(31 downto 0);


                          data_in_ram_a(255 downto 64) <= (others => '0');
                          data_in_ram_a(63 downto 0) <= data_in_a(63 downto 0);

                          we_byte_a(31 downto 8)  <= (others => '0');
                          we_byte_a(7 downto 0)   <= (others => we_a );
                    when "01" =>
             --             control_out_a               <= data_out_ram_a(127 downto 126);
                         -- data_out_a(63 downto 0)   <= data_out_ram_a(127 downto 64);
            --              value_out_a(31 downto 0) <= data_out_ram_a(127 downto 96);
            --              key_out_a(31 downto 0) <= data_out_ram_a(95 downto 64);
                  
                  
                          data_in_ram_a(255 downto 128) <= (others => '0');
                          data_in_ram_a(127 downto 64) <= data_in_a(63 downto 0);
                          data_in_ram_a(63 downto 0)   <= (others =>'0');
                  
                          we_byte_a(31 downto 16)  <= (others => '0');
                          we_byte_a(15 downto 8)   <= (others => we_a );                       
                          we_byte_a(7 downto 0)    <= (others => '0');  
                    when "10" =>
              --            control_out_a               <= data_out_ram_a(191 downto 190);
                       --   data_out_a(63 downto 0)   <= data_out_ram_a(191 downto 128);
             --             value_out_a(31 downto 0) <= data_out_ram_a(191 downto 160);
             --             key_out_a(31 downto 0) <= data_out_ram_a(159 downto 128);                    
                  
                          data_in_ram_a(255 downto 192) <= (others => '0');
                          data_in_ram_a(191 downto 128) <= data_in_a(63 downto 0);
                          data_in_ram_a(127 downto 0)   <= (others =>'0');

                          we_byte_a(31 downto 24)   <= (others => '0');
                          we_byte_a(23 downto 16)   <= (others => we_a );                       
                          we_byte_a(15 downto 0)    <= (others => '0');  
                    when "11" =>
              --            control_out_a               <= data_out_ram_a(255 downto 254);
                          --data_out_a(63 downto 0)   <= data_out_ram_a(255 downto 192);
              --            value_out_a(31 downto 0) <= data_out_ram_a(255 downto 224);
              --            key_out_a(31 downto 0) <= data_out_ram_a(223 downto 192);                    
                  
                          data_in_ram_a(255 downto 192) <= data_in_a(63 downto 0);
                          data_in_ram_a(191 downto 0)   <= (others =>'0');
                  
                          we_byte_a(31 downto 24)   <= (others => we_a);
                          we_byte_a(23 downto 0)    <= (others => '0');
                    when others =>
               --           control_out_a            <= (others => '0');
               --           value_out_a(31 downto 0)   <= (others => '0');
               --           key_out_a(31 downto 0)   <= (others => '0');
                          data_in_ram_a <= (others => '0');
                          we_byte_a     <= (others => '0');
               end case;

               case address_out_a(1 downto 0) is
                    when "00" =>
                          control_out_a             <= data_out_ram_a(63 downto 62);
                         -- data_out_a(63 downto 0) <= data_out_ram_a(63 downto 0);
                          value_out_a(31 downto 0) <= data_out_ram_a(63 downto 32);
                          key_out_a  (31 downto 0) <= data_out_ram_a(31 downto 0);
                    when "01" =>
                          control_out_a               <= data_out_ram_a(127 downto 126);
                         -- data_out_a(63 downto 0)   <= data_out_ram_a(127 downto 64);
                          value_out_a(31 downto 0) <= data_out_ram_a(127 downto 96);
                          key_out_a(31 downto 0) <= data_out_ram_a(95 downto 64);
                    when "10" =>
                          control_out_a               <= data_out_ram_a(191 downto 190);
                       --   data_out_a(63 downto 0)   <= data_out_ram_a(191 downto 128);
                          value_out_a(31 downto 0) <= data_out_ram_a(191 downto 160);
                          key_out_a(31 downto 0) <= data_out_ram_a(159 downto 128);                    
                    when "11" =>
                          control_out_a               <= data_out_ram_a(255 downto 254);
                          --data_out_a(63 downto 0)   <= data_out_ram_a(255 downto 192);
                          value_out_a(31 downto 0) <= data_out_ram_a(255 downto 224);
                          key_out_a(31 downto 0) <= data_out_ram_a(223 downto 192);                    
                  
                    when others =>
                          control_out_a            <= (others => '0');
                          value_out_a(31 downto 0)   <= (others => '0');
                          key_out_a(31 downto 0)   <= (others => '0');
               end case;

               case address_b(1 downto 0) is
                    when "00" =>
--                          control_out_b             <= data_out_ram_b(63 downto 62);
                          --data_out_b(63 downto 0) <= data_out_ram_b(63 downto 0);
--                          value_out_b(31 downto 0) <= data_out_ram_b(63 downto 32);
--                          key_out_b  (31 downto 0) <= data_out_ram_b(31 downto 0);


                          data_in_ram_b(255 downto 64) <= (others => '0');
                          data_in_ram_b(63 downto 0) <= data_in_b(63 downto 0);

                          we_byte_b(31 downto 8)  <= (others => '0');
                          we_byte_b(7 downto 0)   <= (others => we_b );
                    when "01" =>
--                          control_out_b             <= data_out_ram_b(127 downto 126);
                     --     data_out_b(63 downto 0)   <= data_out_ram_b(127 downto 64);
--                          value_out_b(31 downto 0) <= data_out_ram_b(127 downto 96);
--                          key_out_b(31 downto 0) <= data_out_ram_b(95 downto 64);
                  
                  
                          data_in_ram_b(255 downto 128) <= (others => '0');
                          data_in_ram_b(127 downto 64) <= data_in_b(63 downto 0);
                          data_in_ram_b(63 downto 0)   <= (others =>'0');
                  
                          we_byte_b(31 downto 16)  <= (others => '0');
                          we_byte_b(15 downto 8)   <= (others => we_b );                       
                          we_byte_b(7 downto 0)    <= (others => '0');  
                    when "10" =>
 --                         control_out_b             <= data_out_ram_b(191 downto 190);
               --           data_out_b(63 downto 0)   <= data_out_ram_b(191 downto 128);
--                          value_out_b(31 downto 0) <= data_out_ram_b(191 downto 160);
--                          key_out_b(31 downto 0) <= data_out_ram_b(159 downto 128);                    
                
                  
                          data_in_ram_b(255 downto 192) <= (others => '0');
                          data_in_ram_b(191 downto 128) <= data_in_b(63 downto 0);
                          data_in_ram_b(127 downto 0)   <= (others =>'0');

                          we_byte_b(31 downto 24)   <= (others => '0');
                          we_byte_b(23 downto 16)   <= (others => we_b );                       
                          we_byte_b(15 downto 0)    <= (others => '0');  
                    when "11" =>
 --                         control_out_b             <= data_out_ram_b(255 downto 254);
                    --      data_out_b(63 downto 0)   <= data_out_ram_b(255 downto 192);
--                          value_out_b(31 downto 0) <= data_out_ram_b(255 downto 224);
 --                         key_out_b(31 downto 0) <= data_out_ram_b(223 downto 192);                    
                   
                  
                          data_in_ram_b(255 downto 192) <= data_in_b(63 downto 0);
                          data_in_ram_b(191 downto 0)   <= (others =>'0');
                  
                          we_byte_b(31 downto 24)   <= (others => we_b);
                          we_byte_b(23 downto 0)    <= (others => '0');
                    when others =>
--                          control_out_b             <= (others => '0');
                          --data_out_b(63 downto 0)   <= (others => '0');
--                          value_out_b(31 downto 0) <= (others =>'0');
--                          key_out_b(31 downto 0) <= (others =>'0');
                        
                          data_in_ram_b <= (others => '0');
                          we_byte_b     <= (others => '0');
               end case;


               case address_out_b(1 downto 0) is
                    when "00" =>
                          control_out_b             <= data_out_ram_b(63 downto 62);
                          --data_out_b(63 downto 0) <= data_out_ram_b(63 downto 0);
                          value_out_b(31 downto 0) <= data_out_ram_b(63 downto 32);
                          key_out_b  (31 downto 0) <= data_out_ram_b(31 downto 0);


--                         data_in_ram_b(255 downto 64) <= (others => '0');
--                         data_in_ram_b(63 downto 0) <= data_in_b(63 downto 0);
--
--                         we_byte_b(31 downto 8)  <= (others => '0');
--                         we_byte_b(7 downto 0)   <= (others => we_b );
                    when "01" =>
                          control_out_b             <= data_out_ram_b(127 downto 126);
                     --     data_out_b(63 downto 0)   <= data_out_ram_b(127 downto 64);
                          value_out_b(31 downto 0) <= data_out_ram_b(127 downto 96);
                          key_out_b(31 downto 0) <= data_out_ram_b(95 downto 64);
                  
                  
--                         data_in_ram_b(255 downto 128) <= (others => '0');
--                         data_in_ram_b(127 downto 64) <= data_in_b(63 downto 0);
--                         data_in_ram_b(63 downto 0)   <= (others =>'0');
--                 
--                         we_byte_b(31 downto 16)  <= (others => '0');
--                         we_byte_b(15 downto 8)   <= (others => we_b );                       
--                         we_byte_b(7 downto 0)    <= (others => '0');  
                    when "10" =>
                          control_out_b             <= data_out_ram_b(191 downto 190);
               --           data_out_b(63 downto 0)   <= data_out_ram_b(191 downto 128);
                          value_out_b(31 downto 0) <= data_out_ram_b(191 downto 160);
                          key_out_b(31 downto 0) <= data_out_ram_b(159 downto 128);                    
                
                  
--                        data_in_ram_b(255 downto 192) <= (others => '0');
--                        data_in_ram_b(191 downto 128) <= data_in_b(63 downto 0);
--                        data_in_ram_b(127 downto 0)   <= (others =>'0');
--
--                        we_byte_b(31 downto 24)   <= (others => '0');
--                        we_byte_b(23 downto 16)   <= (others => we_b );                       
--                        we_byte_b(15 downto 0)    <= (others => '0');  
                    when "11" =>
                          control_out_b             <= data_out_ram_b(255 downto 254);
                    --      data_out_b(63 downto 0)   <= data_out_ram_b(255 downto 192);
                          value_out_b(31 downto 0) <= data_out_ram_b(255 downto 224);
                          key_out_b(31 downto 0) <= data_out_ram_b(223 downto 192);                    
                   
                  
--                         data_in_ram_b(255 downto 192) <= data_in_b(63 downto 0);
--                         data_in_ram_b(191 downto 0)   <= (others =>'0');
--                 
--                         we_byte_b(31 downto 24)   <= (others => we_b);
--                         we_byte_b(23 downto 0)    <= (others => '0');
                    when others =>
                          control_out_b             <= (others => '0');
                          --data_out_b(63 downto 0)   <= (others => '0');
                          value_out_b(31 downto 0) <= (others =>'0');
                          key_out_b(31 downto 0) <= (others =>'0');
                        
--                          data_in_ram_b <= (others => '0');
--                          we_byte_b     <= (others => '0');
               end case;
         when "0001000000110000" =>                                   --word dim 64
               address_ram_a <= address_a(11 downto 2);
               address_ram_b <= address_b(11 downto 2);
       --        data_out_a(255 downto 64) <= (others => '0');
         --      data_out_b(255 downto 64) <= (others => '0');
               value_out_a(127 downto 16) <= (others =>'0');
               value_out_b(127 downto 16) <= (others =>'0');
               key_out_a(127 downto 48) <= (others =>'0');
               key_out_b(127 downto 48) <= (others =>'0');

               case address_a(1 downto 0) is
                    when "00" =>
                --         control_out_a             <= data_out_ram_a(63 downto 62);
                --        -- data_out_a(63 downto 0) <= data_out_ram_a(63 downto 0);
                --         value_out_a(15 downto 0) <= data_out_ram_a(63 downto 48);
                --         key_out_a  (47 downto 0) <= data_out_ram_a(47 downto 0);


                          data_in_ram_a(255 downto 64) <= (others => '0');
                          data_in_ram_a(63 downto 0) <= data_in_a(63 downto 0);

                          we_byte_a(31 downto 8)  <= (others => '0');
                          we_byte_a(7 downto 0)   <= (others => we_a );
                    when "01" =>
                 --        control_out_a               <= data_out_ram_a(127 downto 126);
                 --       -- data_out_a(63 downto 0)   <= data_out_ram_a(127 downto 64);
                 --        value_out_a(15 downto 0) <= data_out_ram_a(127 downto 112);
                 --        key_out_a(47 downto 0) <= data_out_ram_a(111 downto 64);
                  
                  
                          data_in_ram_a(255 downto 128) <= (others => '0');
                          data_in_ram_a(127 downto 64) <= data_in_a(63 downto 0);
                          data_in_ram_a(63 downto 0)   <= (others =>'0');
                  
                          we_byte_a(31 downto 16)  <= (others => '0');
                          we_byte_a(15 downto 8)   <= (others => we_a );                       
                          we_byte_a(7 downto 0)    <= (others => '0');  
                    when "10" =>
                  --       control_out_a               <= data_out_ram_a(191 downto 190);
                  --    --   data_out_a(63 downto 0)   <= data_out_ram_a(191 downto 128);
                  --       value_out_a(15 downto 0) <= data_out_ram_a(191 downto 176);
                  --       key_out_a(47 downto 0) <= data_out_ram_a(175 downto 128);                    
                  
                          data_in_ram_a(255 downto 192) <= (others => '0');
                          data_in_ram_a(191 downto 128) <= data_in_a(63 downto 0);
                          data_in_ram_a(127 downto 0)   <= (others =>'0');

                          we_byte_a(31 downto 24)   <= (others => '0');
                          we_byte_a(23 downto 16)   <= (others => we_a );                       
                          we_byte_a(15 downto 0)    <= (others => '0');  
                    when "11" =>
                  --      control_out_a               <= data_out_ram_a(255 downto 254);
                  --      --data_out_a(63 downto 0)   <= data_out_ram_a(255 downto 192);
                  --      value_out_a(15 downto 0) <= data_out_ram_a(255 downto 240);
                  --      key_out_a(47 downto 0) <= data_out_ram_a(239 downto 192);                    
                  
                          data_in_ram_a(255 downto 192) <= data_in_a(63 downto 0);
                          data_in_ram_a(191 downto 0)   <= (others =>'0');
                  
                          we_byte_a(31 downto 24)   <= (others => we_a);
                          we_byte_a(23 downto 0)    <= (others => '0');
                    when others =>
                  --        control_out_a            <= (others => '0');
                  --        value_out_a(15 downto 0)   <= (others => '0');
                  --        key_out_a(47 downto 0)   <= (others => '0');
                          data_in_ram_a <= (others => '0');
                          we_byte_a     <= (others => '0');
               end case;


               case address_out_a(1 downto 0) is
                    when "00" =>
                          control_out_a             <= data_out_ram_a(63 downto 62);
                         -- data_out_a(63 downto 0) <= data_out_ram_a(63 downto 0);
                          value_out_a(15 downto 0) <= data_out_ram_a(63 downto 48);
                          key_out_a  (47 downto 0) <= data_out_ram_a(47 downto 0);


                    when "01" =>
                          control_out_a               <= data_out_ram_a(127 downto 126);
                         -- data_out_a(63 downto 0)   <= data_out_ram_a(127 downto 64);
                          value_out_a(15 downto 0) <= data_out_ram_a(127 downto 112);
                          key_out_a(47 downto 0) <= data_out_ram_a(111 downto 64);
                  
                    when "10" =>
                          control_out_a               <= data_out_ram_a(191 downto 190);
                       --   data_out_a(63 downto 0)   <= data_out_ram_a(191 downto 128);
                          value_out_a(15 downto 0) <= data_out_ram_a(191 downto 176);
                          key_out_a(47 downto 0) <= data_out_ram_a(175 downto 128);                    
                  
                    when "11" =>
                          control_out_a               <= data_out_ram_a(255 downto 254);
                          --data_out_a(63 downto 0)   <= data_out_ram_a(255 downto 192);
                          value_out_a(15 downto 0) <= data_out_ram_a(255 downto 240);
                          key_out_a(47 downto 0) <= data_out_ram_a(239 downto 192);                    
                  
                    when others =>
                          control_out_a            <= (others => '0');
                          value_out_a(15 downto 0)   <= (others => '0');
                          key_out_a(47 downto 0)   <= (others => '0');
               end case;

               case address_b(1 downto 0) is
                    when "00" =>
--                         control_out_b             <= data_out_ram_b(63 downto 62);
--                         --data_out_b(63 downto 0) <= data_out_ram_b(63 downto 0);
--                         value_out_b(15 downto 0) <= data_out_ram_b(63 downto 48);
--                         key_out_b  (47 downto 0) <= data_out_ram_b(47 downto 0);


                          data_in_ram_b(255 downto 64) <= (others => '0');
                          data_in_ram_b(63 downto 0) <= data_in_b(63 downto 0);

                          we_byte_b(31 downto 8)  <= (others => '0');
                          we_byte_b(7 downto 0)   <= (others => we_b );
                    when "01" =>
--                        control_out_b             <= data_out_ram_b(127 downto 126);
--                   --     data_out_b(63 downto 0)   <= data_out_ram_b(127 downto 64);
--                        value_out_b(15 downto 0) <= data_out_ram_b(127 downto 112);
--                        key_out_b(47 downto 0) <= data_out_ram_b(111 downto 64);
                  
                  
                          data_in_ram_b(255 downto 128) <= (others => '0');
                          data_in_ram_b(127 downto 64) <= data_in_b(63 downto 0);
                          data_in_ram_b(63 downto 0)   <= (others =>'0');
                  
                          we_byte_b(31 downto 16)  <= (others => '0');
                          we_byte_b(15 downto 8)   <= (others => we_b );                       
                          we_byte_b(7 downto 0)    <= (others => '0');  
                    when "10" =>
--                         control_out_b             <= data_out_ram_b(191 downto 190);
--              --           data_out_b(63 downto 0)   <= data_out_ram_b(191 downto 128);
--                         value_out_b(15 downto 0) <= data_out_ram_b(191 downto 176);
--                         key_out_b(47 downto 0) <= data_out_ram_b(175 downto 128);                    
                
                  
                          data_in_ram_b(255 downto 192) <= (others => '0');
                          data_in_ram_b(191 downto 128) <= data_in_b(63 downto 0);
                          data_in_ram_b(127 downto 0)   <= (others =>'0');

                          we_byte_b(31 downto 24)   <= (others => '0');
                          we_byte_b(23 downto 16)   <= (others => we_b );                       
                          we_byte_b(15 downto 0)    <= (others => '0');  
                    when "11" =>
--                         control_out_b             <= data_out_ram_b(255 downto 254);
--                   --      data_out_b(63 downto 0)   <= data_out_ram_b(255 downto 192);
--                         value_out_b(15 downto 0) <= data_out_ram_b(255 downto 240);
--                         key_out_b(47 downto 0) <= data_out_ram_b(239 downto 192);                    
                   
                  
                          data_in_ram_b(255 downto 192) <= data_in_b(63 downto 0);
                          data_in_ram_b(191 downto 0)   <= (others =>'0');
                  
                          we_byte_b(31 downto 24)   <= (others => we_b);
                          we_byte_b(23 downto 0)    <= (others => '0');
                    when others =>
--                          control_out_b             <= (others => '0');
                          --data_out_b(63 downto 0)   <= (others => '0');
--                          value_out_b(15 downto 0) <= (others =>'0');
--                          key_out_b(47 downto 0) <= (others =>'0');
                        
                          data_in_ram_b <= (others => '0');
                          we_byte_b     <= (others => '0');
               end case;


               case address_out_b(1 downto 0) is
                    when "00" =>
                          control_out_b             <= data_out_ram_b(63 downto 62);
                          --data_out_b(63 downto 0) <= data_out_ram_b(63 downto 0);
                          value_out_b(15 downto 0) <= data_out_ram_b(63 downto 48);
                          key_out_b  (47 downto 0) <= data_out_ram_b(47 downto 0);

                    when "01" =>
                          control_out_b             <= data_out_ram_b(127 downto 126);
                     --     data_out_b(63 downto 0)   <= data_out_ram_b(127 downto 64);
                          value_out_b(15 downto 0) <= data_out_ram_b(127 downto 112);
                          key_out_b(47 downto 0) <= data_out_ram_b(111 downto 64);
                  
                    when "10" =>
                          control_out_b             <= data_out_ram_b(191 downto 190);
               --           data_out_b(63 downto 0)   <= data_out_ram_b(191 downto 128);
                          value_out_b(15 downto 0) <= data_out_ram_b(191 downto 176);
                          key_out_b(47 downto 0) <= data_out_ram_b(175 downto 128);                    
                
                    when "11" =>
                          control_out_b             <= data_out_ram_b(255 downto 254);
                    --      data_out_b(63 downto 0)   <= data_out_ram_b(255 downto 192);
                          value_out_b(15 downto 0) <= data_out_ram_b(255 downto 240);
                          key_out_b(47 downto 0) <= data_out_ram_b(239 downto 192);                    
                   
                  
                    when others =>
                          control_out_b             <= (others => '0');
                          --data_out_b(63 downto 0)   <= (others => '0');
                          value_out_b(15 downto 0) <= (others =>'0');
                          key_out_b(47 downto 0) <= (others =>'0');
                        
               end case;
         when others =>
               value_out_a    <= (others => '0');
               value_out_b    <= (others => '0');
               key_out_a    <= (others => '0');
               key_out_b    <= (others => '0');
               address_ram_a <= (others => '0');
               address_ram_b <= (others => '0');
               we_byte_a     <= (others => '0');
               we_byte_b     <= (others => '0');
               data_in_ram_a <= (others => '0');
               data_in_ram_b <= (others => '0');
               control_out_a  <= (others => '0');
               control_out_b  <= (others => '0');
    end case;       
end process; 
--  A: process(word_dimension_r, address_a, address_b, we_a, we_b, data_in_a, data_in_b, data_out_ram_a, data_out_ram_b)
--    begin
--        case word_dimension_r is
--             when "100000000" =>                                   --word dim 256
--                   control_out_a   <= data_out_ram_a(255 downto 254);
--                   control_out_b   <= data_out_ram_b(255 downto 254);
--                   data_out_a    <= data_out_ram_a;
--                   data_out_b    <= data_out_ram_b;
--                   data_in_ram_a <= data_in_a;
--                   data_in_ram_b <= data_in_b;
--                   address_ram_a <= address_a(9 downto 0);
--                   address_ram_b <= address_b(9 downto 0);
--                   we_byte_a     <= (others => we_a);
--                   we_byte_b     <= (others => we_b);
                   
--             when "010000000" =>                                   --word dim 128
--                   address_ram_a <= address_a(10 downto 1);
--                   address_ram_b <= address_b(10 downto 1);
--                   data_out_a(255 downto 128) <= (others => '0');
--                   data_out_b(255 downto 128) <= (others => '0');
--                   if address_a(0) = '0' then
--                        control_out_a   <= data_out_ram_a(127 downto 126);
--                        data_out_a(127 downto 0) <= data_out_ram_a(127 downto 0);
                   
--                        data_in_ram_a(255 downto 128) <= (others => '0');
--                        data_in_ram_a(127 downto 0) <= data_in_a(127 downto 0);
 
--                        we_byte_a(31 downto 16) <= (others => '0');
--                        we_byte_a(15 downto 0 ) <= (others =>  we_a);
--                   else   
--                        control_out_a   <= data_out_ram_a(255 downto 254);
--                        data_out_a(127 downto 0) <= data_out_ram_a(255 downto 128);
  
--                        data_in_ram_a(255 downto 128) <= data_in_a(127 downto 0);
--                        data_in_ram_a(127 downto 0) <= (others => '0');
 
--                        we_byte_a(31 downto 16) <= (others =>  we_a);
--                        we_byte_a(15 downto 0 ) <= (others => '0');
--                   end if;
--                   if address_b(0) = '0' then
--                        control_out_b   <= data_out_ram_b(127 downto 126);
--                        data_out_b(127 downto 0) <= data_out_ram_b(127 downto 0);
                   
--                        data_in_ram_b(255 downto 128) <= (others => '0');
--                        data_in_ram_b(127 downto 0) <= data_in_b(127 downto 0);
 
--                        we_byte_b(31 downto 16) <= (others => '0');
--                        we_byte_b(15 downto 0 ) <= (others =>  we_b);
--                   else   
--                        control_out_b   <= data_out_ram_b(255 downto 254);
--                        data_out_b(127 downto 0) <= data_out_ram_b(255 downto 128);
  
--                        data_in_ram_b(255 downto 128) <= data_in_b(127 downto 0);
--                        data_in_ram_b(127 downto 0) <= (others => '0');
 
--                        we_byte_b(31 downto 16) <= (others =>  we_b);
--                        we_byte_b(15 downto 0 ) <= (others => '0');
--                   end if;
--             when "001000000" =>                                   --word dim 64
--                   address_ram_a <= address_a(11 downto 2);
--                   address_ram_b <= address_b(11 downto 2);
--                   data_out_a(255 downto 64) <= (others => '0');
--                   data_out_b(255 downto 64) <= (others => '0');
--                   case address_a(1 downto 0) is
--                        when "00" =>
--                              control_out_a             <= data_out_ram_a(63 downto 62);
--                              data_out_a(63 downto 0) <= data_out_ram_a(63 downto 0);
 
--                              data_in_ram_a(255 downto 64) <= (others => '0');
--                              data_in_ram_a(63 downto 0) <= data_in_a(63 downto 0);
 
--                              we_byte_a(31 downto 8)  <= (others => '0');
--                              we_byte_a(7 downto 0)   <= (others => we_a );
--                        when "01" =>
--                              control_out_a               <= data_out_ram_a(127 downto 126);
--                              data_out_a(63 downto 0)   <= data_out_ram_a(127 downto 64);
                        
--                              data_in_ram_a(255 downto 128) <= (others => '0');
--                              data_in_ram_a(127 downto 64) <= data_in_a(63 downto 0);
--                              data_in_ram_a(63 downto 0)   <= (others =>'0');
                        
--                              we_byte_a(31 downto 16)  <= (others => '0');
--                              we_byte_a(15 downto 8)   <= (others => we_a );                       
--                              we_byte_a(7 downto 0)    <= (others => '0');  
--                        when "10" =>
--                              control_out_a               <= data_out_ram_a(191 downto 190);
--                              data_out_a(63 downto 0)   <= data_out_ram_a(191 downto 128);
                        
--                              data_in_ram_a(255 downto 192) <= (others => '0');
--                              data_in_ram_a(191 downto 128) <= data_in_a(63 downto 0);
--                              data_in_ram_a(127 downto 0)   <= (others =>'0');
 
--                              we_byte_a(31 downto 24)   <= (others => '0');
--                              we_byte_a(23 downto 16)   <= (others => we_a );                       
--                              we_byte_a(15 downto 0)    <= (others => '0');  
--                        when "11" =>
--                              control_out_a               <= data_out_ram_a(255 downto 254);
--                              data_out_a(63 downto 0)   <= data_out_ram_a(255 downto 192);
                        
--                              data_in_ram_a(255 downto 192) <= data_in_a(63 downto 0);
--                              data_in_ram_a(191 downto 0)   <= (others =>'0');
                        
--                              we_byte_a(31 downto 24)   <= (others => we_a);
--                              we_byte_a(23 downto 0)    <= (others => '0');
--                        when others =>
--                              control_out_a            <= (others => '0');
--                              data_out_a(63 downto 0)   <= (others => '0');
--                              data_in_ram_a <= (others => '0');
--                              we_byte_a     <= (others => '0');
--                   end case;
--                   case address_b(1 downto 0) is
--                        when "00" =>
--                              control_out_b             <= data_out_ram_b(63 downto 62);
--                              data_out_b(63 downto 0) <= data_out_ram_b(63 downto 0);
 
--                              data_in_ram_b(255 downto 64) <= (others => '0');
--                              data_in_ram_b(63 downto 0) <= data_in_b(63 downto 0);
 
--                              we_byte_b(31 downto 8)  <= (others => '0');
--                              we_byte_b(7 downto 0)   <= (others => we_b );
--                        when "01" =>
--                              control_out_b             <= data_out_ram_b(127 downto 126);
--                              data_out_b(63 downto 0)   <= data_out_ram_b(127 downto 64);
                        
--                              data_in_ram_b(255 downto 128) <= (others => '0');
--                              data_in_ram_b(127 downto 64) <= data_in_b(63 downto 0);
--                              data_in_ram_b(63 downto 0)   <= (others =>'0');
                        
--                              we_byte_b(31 downto 16)  <= (others => '0');
--                              we_byte_b(15 downto 8)   <= (others => we_b );                       
--                              we_byte_b(7 downto 0)    <= (others => '0');  
--                        when "10" =>
--                              control_out_b             <= data_out_ram_b(191 downto 190);
--                              data_out_b(63 downto 0)   <= data_out_ram_b(191 downto 128);
                        
--                              data_in_ram_b(255 downto 192) <= (others => '0');
--                              data_in_ram_b(191 downto 128) <= data_in_b(63 downto 0);
--                              data_in_ram_b(127 downto 0)   <= (others =>'0');
 
--                              we_byte_b(31 downto 24)   <= (others => '0');
--                              we_byte_b(23 downto 16)   <= (others => we_b );                       
--                              we_byte_b(15 downto 0)    <= (others => '0');  
--                        when "11" =>
--                              control_out_b             <= data_out_ram_b(255 downto 254);
--                              data_out_b(63 downto 0)   <= data_out_ram_b(255 downto 192);
                        
--                              data_in_ram_b(255 downto 192) <= data_in_b(63 downto 0);
--                              data_in_ram_b(191 downto 0)   <= (others =>'0');
                        
--                              we_byte_b(31 downto 24)   <= (others => we_b);
--                              we_byte_b(23 downto 0)    <= (others => '0');
--                        when others =>
--                              control_out_b             <= (others => '0');
--                              data_out_b(63 downto 0)   <= (others => '0');
--                              data_in_ram_b <= (others => '0');
--                              we_byte_b     <= (others => '0');
--                   end case;
--             when others =>
--                   data_out_a    <= (others => '0');
--                   data_out_b    <= (others => '0');
--                   address_ram_a <= (others => '0');
--                   address_ram_b <= (others => '0');
--                   we_byte_a     <= (others => '0');
--                   we_byte_b     <= (others => '0');
--                   data_in_ram_a <= (others => '0');
--                   data_in_ram_b <= (others => '0');
--                   control_out_a  <= (others => '0');
--                   control_out_b  <= (others => '0');
--        end case;       
--    end process;
end Behavioral;









