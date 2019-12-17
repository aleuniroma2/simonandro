 ----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11/07/2019 05:04:21 PM
-- Design Name: 
-- Module Name: ht128new - Behavioral
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
use IEEE.STD_LOGIC_unsigned.ALL;

use ieee.numeric_std.all;
use work.salutil.all;
library work;
use work.ram_pkg.all;
use work.hash_pkg.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity ht128newa is

  generic(
     key_len_max  : integer:= 128;
     value_len_max: integer:= 126
    );
  Port ( 
    clock : in std_logic;
    reset : in std_logic;
    search   : in std_logic;

    --AXI interface
    we: in std_logic;
    rd: in std_logic;
    input_din: in std_logic_vector(1 + key_len_max+value_len_max downto 0);
    --addr :in std_logic_vector(11 downto 0);
    addr :in std_logic_vector(13 downto 0);
    data_out :out std_logic_vector(1 + key_len_max+value_len_max downto 0);

    --Hash Interface
    remove : in std_logic; -- 1 to remove
    insert : in std_logic; -- 1 to insert
    update : in std_logic; -- 1 to update
    key    : in std_logic_vector(key_len_max-1 downto 0); -- insert key
    value  : in std_logic_vector(value_len_max-1 downto 0); -- insert value
    search_key : in std_logic_vector(key_len_max-1 downto 0); -- search key
    
    key_len: in std_logic_vector(clogb2(key_len_max) downto 0);
    value_len: in std_logic_vector(clogb2(value_len_max + 2) downto 0);
    
    kicked        : out std_logic; -- 1 if a key has been kicked out
    kicked_value  : out std_logic_vector(value_len_max-1 downto 0); -- kicked value
    kicked_key    : out std_logic_vector(key_len_max-1 downto 0); -- kicked key

    out_count_collision :out std_logic_vector(31 downto 0);
    clear_count_collision: in std_logic;
    out_count_item :out std_logic_vector(31 downto 0);

    match  : out std_logic; -- 1 if hit on query
    output : out std_logic_vector(value_len_max-1 downto 0) -- value associated with the search key
  );

end ht128newa;

architecture Behavioral of ht128newa is

 signal dout_query1,dout_query2,dout_query3,dout_query4:std_logic_vector(1 + key_len_max+value_len_max downto 0);
  signal write_enable_1,write_enable_2, write_enable_3, write_enable_4: std_logic;
  signal memory_write_enable_1,memory_write_enable_2, memory_write_enable_3, memory_write_enable_4: std_logic;

  signal din_insert1:  std_logic_vector(1 + key_len_max+value_len_max downto 0);
  signal din_insert2:  std_logic_vector(1 + key_len_max+value_len_max downto 0);
  signal din_insert3:  std_logic_vector(1 + key_len_max+value_len_max downto 0);
  signal din_insert4:  std_logic_vector(1 + key_len_max+value_len_max downto 0);
  signal dinb1:  std_logic_vector(1 + key_len_max+value_len_max downto 0);
  signal dinb2:  std_logic_vector(1 + key_len_max+value_len_max downto 0);
  signal dinb3:  std_logic_vector(1 + key_len_max+value_len_max downto 0);
  signal dinb4:  std_logic_vector(1 + key_len_max+value_len_max downto 0);

  signal mem_addr: std_logic_vector(39 downto 0);
  signal dout_insert1,dout_insert2,dout_insert3,dout_insert4,dout1,dout2,dout3,dout4:  std_logic_vector(1 + key_len_max+value_len_max downto 0);

  signal search_d,key_d    : std_logic_vector(key_len_max-1 downto 0);
  signal value_d  : std_logic_vector(value_len_max-1 downto 0);
  signal remove_d :std_logic:='0';
  signal update_d :std_logic:='0';
  signal insert_d :std_logic:='0';
  
--  attribute max_fanout: integer;
--  attribute max_fanout of output: signal is 1;
--  attribute max_fanout of dinb1: signal is 1;
--  attribute max_fanout of dinb2: signal is 1;
--  attribute max_fanout of dinb3: signal is 1;
--  attribute max_fanout of dinb4: signal is 1;
--  attribute max_fanout of din_insert1: signal is 1;
--  attribute max_fanout of din_insert2: signal is 1;
--  attribute max_fanout of din_insert3: signal is 1;
--  attribute max_fanout of din_insert4: signal is 1;



  --signal addrb_1,addrb_2,addrb_3,addrb_4,addr_insert1,addr_insert2,addr_insert3,addr_insert4:std_logic_vector(9 downto 0);
  --signal addr_query1,addr_query2,addr_query3,addr_query4:std_logic_vector(9 downto 0);
  signal addr_query1,addr_query2,addr_query3,addr_query4:std_logic_vector(11 downto 0);
  signal addrb_1,addrb_2,addrb_3,addrb_4,addr_insert1,addr_insert2,addr_insert3,addr_insert4:std_logic_vector(11 downto 0);
  signal control_in_1, control_in_2, control_in_3, control_in_4, control_out_1a, control_out_1b, control_out_2a, control_out_2b, control_out_3a, control_out_3b, control_out_4a, control_out_4b:std_logic_vector(1 downto 0);
         signal to_hash: std_logic_vector(key_len_max-1 downto 0);
          signal hashed_query,hashed_insert: std_logic_vector(63 downto 0);
--        attribute max_fanout of addrb_1: signal is 1;
--        attribute max_fanout of addrb_2: signal is 1;
--        attribute max_fanout of addrb_3: signal is 1;
--        attribute max_fanout of addrb_4: signal is 1;



          signal count_collision_next,count_collision: std_logic_vector(31 downto 0);
          signal count_item_next,count_item: std_logic_vector(31 downto 0);
          signal count_select_kick: std_logic_vector(15 downto 0);

component Reconfigurator2 is

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
           address_a: in std_logic_vector((clogb2(RAM_DEPTH) + ADDED_BITS -1) downto 0);
           address_b: in std_logic_vector((clogb2(RAM_DEPTH) + ADDED_BITS -1) downto 0);
           clk: in std_logic;
--           data_out_a: out std_logic_vector(NB_COL*COL_WIDTH-1 downto 0);
--           data_out_b: out std_logic_vector(NB_COL*COL_WIDTH-1 downto 0);
           key_out_a:   out std_logic_vector(NB_COL*COL_WIDTH/2 - 1 downto 0);   --128 bit massimi
           value_out_a: out std_logic_vector(NB_COL*COL_WIDTH/2 - 1 downto 0);   --128 bit massimi

           key_out_b:   out std_logic_vector(NB_COL*COL_WIDTH/2 - 1 downto 0);   --128 bit massimi
           value_out_b: out std_logic_vector(NB_COL*COL_WIDTH/2 - 1 downto 0)   --128 bit massimi

--           quartimod: in std_logic   -- 1 se le word le scrivo un quarto e tre quarti, 0 altrimenti dove sono met�
             );
end component;


begin

--         out_count_collision  <= count_collision; 
--         out_count_item <=count_item; 



          hashed_query <= search_key(63 downto 0 ) xor myror(search_key(127 downto 64),7);
          addr_query1<=  hashed_query(19 downto 8)  xor hashed_query(11 downto 0) xor hashed_query(51 downto 40);
          addr_query2<=  hashed_query(21 downto 10) xor hashed_query(61 downto 50);
          addr_query3<=  hashed_query(31 downto 20) xor hashed_query(63 downto 52);
          addr_query4<=  hashed_query(41 downto 30) xor hashed_query(26 downto 15);

--          addr_query1<=  hashed_query(17 downto 8)  xor hashed_query(9 downto 0) xor hashed_query(49 downto 40);
--          addr_query2<=  hashed_query(19 downto 10) xor hashed_query(59 downto 50);
--          addr_query3<=  hashed_query(29 downto 20) xor hashed_query(63 downto 54);
--          addr_query4<=  hashed_query(39 downto 30) xor hashed_query(24 downto 15);

          --hashed_insert <= key(63 downto 0 ) xor myror(key(127 downto 64),7);

          hashed_insert <= (key_d(63 downto 0 ) xor myror(key_d(127 downto 64),7)) when write_enable_1='1' else
                           (key_d(63 downto 0 ) xor myror(key_d(127 downto 64),7)) when write_enable_2='1' else
                           (key_d(63 downto 0 ) xor myror(key_d(127 downto 64),7)) when write_enable_3='1' else
                           (key_d(63 downto 0 ) xor myror(key_d(127 downto 64),7)) when write_enable_4='1' else
                           (key(63 downto 0 ) xor myror(key(127 downto 64),7));


          addr_insert1<=  hashed_insert(19 downto 8)  xor hashed_insert(11 downto 0) xor hashed_insert(51 downto 40);
          addr_insert2<=  hashed_insert(21 downto 10) xor hashed_insert(61 downto 50);
          addr_insert3<=  hashed_insert(31 downto 20) xor hashed_insert(63 downto 52);
          addr_insert4<=  hashed_insert(41 downto 30) xor hashed_insert(26 downto 15);

          process(clock)
          begin
            if(clock'event and clock = '1') then
              search_d<=search_key;
              key_d<= key;
              value_d<= value;
              update_d<=update;
              remove_d<=remove;
              insert_d<=insert;
            end if;
          end process;
    
    htmem1: Reconfigurator2
        port map (
            clk       => clock,
            we_a        => '0',
            we_b        => write_enable_1,
            switch    =>  we,
            key       => key_d,
            value =>  value_d,
            --value(125 downto 0) =>  value_d,
            --value(128 downto 127)=> (others =>'0'),
            data_a    => (others => '0'),
            data_b    => input_din,
            key_len   => key_len,
            value_len => value_len,
            
            key_out_a  => dout_query1(127 downto 0),
            value_out_a  => dout_query1(255 downto 128),
            
            key_out_b  => dout_insert1(127 downto 0),
            value_out_b  => dout_insert1(255 downto 128),
            
            address_a   => addr_query1,
            address_b   => addrb_1,
          --  quartimod => '0',
            
            control_in  => control_in_1,
            control_out_a => control_out_1a,
            control_out_b => control_out_1b
        );
        
    htmem2: Reconfigurator2
        port map (
            clk       => clock,
            we_a        => '0',
            we_b        => write_enable_2,
            switch    =>  we,
            key       => key_d,
            value     => value_d,
            data_a    => (others => '0'),
            data_b    => input_din,
            key_len   => key_len,
            value_len => value_len,
            key_out_a  => dout_query2(127 downto 0),
            value_out_a  => dout_query2(255 downto 128),
            
            key_out_b  => dout_insert2(127 downto 0),
            value_out_b  => dout_insert2(255 downto 128),

            address_a   => addr_query2,
            address_b   => addrb_2,
 --           quartimod => '0',
            
            control_in  => control_in_2,
            control_out_a => control_out_2a,
            control_out_b => control_out_2b
        );
        
    htmem3: Reconfigurator2
        port map (
            clk       => clock,
            we_a        => '0',
            we_b        => write_enable_3,
            switch    =>  we,
            key       => key_d,
            value     => value_d,
            data_a    => (others => '0'),
            data_b    => input_din,
            key_len   => key_len,
            value_len => value_len,
            key_out_a    => dout_query3(127 downto 0),
            value_out_a  => dout_query3(255 downto 128),
            
            key_out_b    => dout_insert3(127 downto 0),
            value_out_b  => dout_insert3(255 downto 128),
            address_a   => addr_query3,
            address_b   => addrb_3,
  --          quartimod => '0',
            
            control_in  => control_in_3,
            control_out_a => control_out_3a,
            control_out_b => control_out_3b
        );
    htmem4: Reconfigurator2
        port map (
            clk       => clock,
            we_a        => '0',
            we_b        => write_enable_4,
            switch    =>  we,
            key       => key_d,
            value     => value_d,
            data_a    => (others => '0'),
            data_b    => input_din,
            key_len   => key_len,
            value_len => value_len,
            key_out_a    => dout_query4(127 downto 0),
            value_out_a  => dout_query4(255 downto 128),
            
            key_out_b    => dout_insert4(127 downto 0),
            value_out_b  => dout_insert4(255 downto 128),
            address_a   => addr_query4,
            address_b   => addrb_4,
--            quartimod => '0',
            
            control_in  => control_in_4,
            control_out_a => control_out_4a,
            control_out_b => control_out_4b
        );


          addrb_1<= addr(11 downto 0) when ((we='1') or (rd='1')) else addr_insert1;
          addrb_2<= addr(11 downto 0) when ((we='1') or (rd='1')) else addr_insert2;
          addrb_3<= addr(11 downto 0) when ((we='1') or (rd='1')) else addr_insert3;
          addrb_4<= addr(11 downto 0) when ((we='1') or (rd='1')) else addr_insert4;


          data_out <= dout_insert1 when addr(13 downto 12)="00" else 
                      dout_insert2 when addr(13 downto 12)="01" else
                      dout_insert3 when addr(13 downto 12)="10" else 
                      dout_insert4;
          

          write_enable_1 <= '1' when we='1' and addr(13 downto 12)="00" else memory_write_enable_1;
          write_enable_2 <= '1' when we='1' and addr(13 downto 12)="01" else memory_write_enable_2;
          write_enable_3 <= '1' when we='1' and addr(13 downto 12)="10" else memory_write_enable_3;
          write_enable_4 <= '1' when we='1' and addr(13 downto 12)="11" else memory_write_enable_4;

-- OUTPUT logic: select the query answer---------------------------------------------------------------------

          process(search, dout_query1, dout_query2, dout_query3, dout_query4, search_d, control_out_1a, control_out_2a, control_out_3a, control_out_4a )
          begin
            match <= '0';
            output <= (others => '0');
            if search= '1' then
                --if ((dout_query1(key_len-1 downto 0)=search_d) and dout_query1(key_len+value_len)='1') then
                if ((dout_query1(key_len_max-1 downto 0)=search_d) and control_out_1a(0)='1') then
                  output <= dout_query1(key_len_max+value_len_max-1 downto key_len_max); --lunghezza del value esclusi i due bit di controllo
                  match <='1';
                end if;
                if ((dout_query2(key_len_max-1 downto 0)=search_d) and control_out_2a(0)='1') then
                  output <= dout_query2(key_len_max+value_len_max-1 downto key_len_max); --lunghezza del value esclusi i due bit di controllo
                  match <= '1';
                end if;
                if ((dout_query3(key_len_max-1 downto 0)=search_d) and control_out_3a(0)='1') then
                  output <= dout_query3(key_len_max+value_len_max-1 downto key_len_max); --lunghezza del value esclusi i due bit di controllo
                  match <= '1';
                end if;
                if ((dout_query4(key_len_max-1 downto 0)=search_d) and control_out_4a(0)='1') then
                  output <= dout_query4(key_len_max+value_len_max-1 downto key_len_max); --lunghezza del value esclusi i due bit di controllo
                  match <= '1';
                end if;
            end if;
          end process;
          
          
--          process(clock)
--          begin
--            if(clock'event and clock = '1') then
--        if (RESET = '1') then
--            count_collision <= x"00000000";
--            count_item <=  x"00000000";
--            count_select_kick <=  x"0000";
--        else
--            count_select_kick <=  (count_select_kick + 1) xor myror(count_select_kick(15 downto 0),5); --select the item to kick out
--            if (clear_count_collision='1') then 
--              count_collision <= x"00000000";
--            else 
--              count_collision <= count_collision_next;
--            end if;  
--            count_item <= count_item_next;
--        end if;
--        end if;
--          end process;
 --CONTROL LOGIC-------------------------------------------------------------------------
 
          process(count_item,count_collision,key,key_d,value,value_d,update_d,remove_d,insert_d,dout_insert1,dout_insert2,dout_insert3,dout_insert4,control_out_1b,control_out_2b,control_out_3b,control_out_4b)
          variable updated: boolean;
          begin
                updated:=false;
	            kicked  <='0';
                kicked_value<=(others => '0'); 
                kicked_key <=(others => '0');  
  --              count_collision_next <= count_collision;
  --              count_item_next <= count_item;
	            
	            
	            control_in_1 <= (others =>'0');
	            control_in_2 <= (others =>'0');
	            control_in_3 <= (others =>'0');
	            control_in_4 <= (others =>'0');
	            
                memory_write_enable_1<='0';
                memory_write_enable_2<='0';
                memory_write_enable_3<='0';
                memory_write_enable_4<='0';
	            
            if (remove_d='1') then
              if ((dout_insert1(key_len_max-1 downto 0)=key_d) and control_out_1b(0)='1') then 
    --            count_item_next <= count_item-1;
                memory_write_enable_1<='1';
              elsif ((dout_insert2(key_len_max-1 downto 0)=key_d) and control_out_2b(0)='1') then 
    --            count_item_next <= count_item-1;
                memory_write_enable_2<='1';
              elsif ((dout_insert3(key_len_max-1 downto 0)=key_d) and control_out_3b(0)='1') then 
   --             count_item_next <= count_item-1;
                memory_write_enable_3<='1';
              elsif ((dout_insert4(key_len_max-1 downto 0)=key_d) and control_out_4b(0)='1') then 
   --             count_item_next <= count_item-1;
                memory_write_enable_4<='1';
              else
                report "remove failed" & LF;
              end if;
            end if;
            
            if ((update_d='1') or (insert_d='1')) then
            --if the item is already here --------------------------------
              if ((dout_insert1(key_len_max-1 downto 0)=key_d) and control_out_1b(0)='1') then 
                control_in_1 <= (others => '1');
                memory_write_enable_1<='1';
                updated:=true;
              end if;
              if ((dout_insert2(key_len_max-1 downto 0)=key_d) and control_out_2b(0)='1') then 
                control_in_2 <= (others => '1');
                memory_write_enable_2<='1';
                updated:=true;
              end if;
              if ((dout_insert3(key_len_max-1 downto 0)=key_d) and control_out_3b(0)='1') then 
                control_in_3 <= (others => '1');
                memory_write_enable_3<='1';
                updated:=true;
              end if;
              if ((dout_insert4(key_len_max-1 downto 0)=key_d) and control_out_4b(0)='1') then 
                control_in_4 <= (others => '1');
                memory_write_enable_4<='1';
                updated:=true;
              end if;
            end if;
              if ((not updated) and (insert_d='1')) then
            -- If item is not present
                if control_out_1b(0) = '0' then
                     control_in_1 <= (others => '1');   
        --             count_item_next <= count_item+1;
                     memory_write_enable_1<='1';
                elsif control_out_2b(0) = '0' then
                     control_in_2 <= (others => '1');   
      --               count_item_next <= count_item+1;
                     memory_write_enable_2<='1';
                elsif control_out_3b(0) = '0' then
                     control_in_3 <= (others => '1');   
      --               count_item_next <= count_item+1;
                     memory_write_enable_3<='1';
                elsif control_out_4b(0) = '0' then
                     control_in_4 <= (others => '1');   
      --               count_item_next <= count_item+1;
                     memory_write_enable_4<='1';
                else
                     report "insertion failed" & LF ; 
     --                count_collision_next <= count_collision+1;
                     if count_select_kick(1 downto 0)="00" then
                         control_in_1 <= (others => '1');   
                         kicked  <='1';
                         kicked_value<=dout_insert1(key_len_max+value_len_max-1 downto key_len_max); 
                         kicked_key <=dout_insert1(key_len_max-1 downto 0);  
                         memory_write_enable_1<='1';
                    elsif count_select_kick(1 downto 0)="01" then
                         control_in_2 <= (others => '1');   
                         kicked  <='1';
                         kicked_value<=dout_insert2(key_len_max+value_len_max-1 downto key_len_max); 
                         kicked_key <=dout_insert2(key_len_max-1 downto 0);  
                         memory_write_enable_2<='1';
                    elsif count_select_kick(1 downto 0)="10" then
                         control_in_3 <= (others => '1');   
                         kicked  <='1';
                         kicked_value<=dout_insert3(key_len_max+value_len_max-1 downto key_len_max); 
                         kicked_key <=dout_insert3(key_len_max-1 downto 0);  
                         memory_write_enable_3<='1';
                    else 
                         control_in_4 <= (others => '1');   
                         kicked  <='1';
                         kicked_value<=dout_insert4(key_len_max+value_len_max-1 downto key_len_max); 
                         kicked_key <=dout_insert4(key_len_max-1 downto 0);  
                         memory_write_enable_4<='1';
                    end if;
                end if;
            end if;

      
          end process;



end Behavioral;
