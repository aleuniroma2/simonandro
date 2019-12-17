library ieee;
use ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_unsigned.ALL;
use ieee.std_logic_arith.all;

library work;
use work.hash_pkg.all;
use work.salutil.all;

entity ht128dp is
 generic (
   key_len : integer := 128;
   value_len : integer := 126;
   logsize : integer := 10
   );
  port ( 
         clock : in std_logic;
         reset : in std_logic;
         search   : in std_logic;

         --AXI interface
         we: in std_logic;
         rd: in std_logic;
         input_din: in std_logic_vector(3+key_len+value_len downto 0);
         addr :in std_logic_vector(logsize+1 downto 0);
         data_out :out std_logic_vector(3+key_len+value_len downto 0);

         --Hash Interface
         remove : in std_logic; -- 1 to remove
         insert : in std_logic; -- 1 to insert
         update : in std_logic; -- 1 to update
         key    : in std_logic_vector(key_len-1 downto 0); -- insert key
         value  : in std_logic_vector(value_len-1 downto 0); -- insert value
         search_key : in std_logic_vector(key_len-1 downto 0); -- search key
         current_color : in std_logic_vector(2 downto 0);

         kicked        : out std_logic; -- 1 if a key has been kicked out
         kicked_value  : out std_logic_vector(value_len-1 downto 0); -- kicked value
         kicked_key    : out std_logic_vector(key_len-1 downto 0); -- kicked key
         kicked_color    : out std_logic_vector(2 downto 0); -- kicked color

         out_count_collision :out std_logic_vector(31 downto 0);
         clear_count_collision: in std_logic;
         out_count_item :out std_logic_vector(31 downto 0);

         match  : out std_logic; -- 1 if hit on query
         output : out std_logic_vector(value_len-1 downto 0) -- value associated with the search key
       );

end ht128dp;

architecture behavioral of ht128dp is

  type ht_mem_type is array (2**logsize-1 downto 0) of std_logic_vector(3+key_len+value_len downto 0);
  
  signal dout_query1,dout_query2,dout_query3,dout_query4:std_logic_vector(3+key_len+value_len downto 0);
  signal write_enable_1,write_enable_2, write_enable_3, write_enable_4: std_logic;
  signal memory_write_enable_1,memory_write_enable_2, memory_write_enable_3, memory_write_enable_4: std_logic;

  signal din_insert1:  std_logic_vector(3+key_len+value_len downto 0);
  signal din_insert2:  std_logic_vector(3+key_len+value_len downto 0);
  signal din_insert3:  std_logic_vector(3+key_len+value_len downto 0);
  signal din_insert4:  std_logic_vector(3+key_len+value_len downto 0);
  signal dinb1:  std_logic_vector(3+key_len+value_len downto 0);
  signal dinb2:  std_logic_vector(3+key_len+value_len downto 0);
  signal dinb3:  std_logic_vector(3+key_len+value_len downto 0);
  signal dinb4:  std_logic_vector(3+key_len+value_len downto 0);

  signal dout_insert1,dout_insert2,dout_insert3,dout_insert4,dout1,dout2,dout3,dout4:  std_logic_vector(3+key_len+value_len downto 0);

  signal search_d,key_d    : std_logic_vector(key_len-1 downto 0);
  signal value_d  : std_logic_vector(value_len-1 downto 0);
  signal remove_d :std_logic:='0';
  signal update_d :std_logic:='0';
  signal insert_d :std_logic:='0';
  
  attribute max_fanout: integer;
  attribute max_fanout of output: signal is 1;
  attribute max_fanout of dinb1: signal is 1;
  attribute max_fanout of dinb2: signal is 1;
  attribute max_fanout of dinb3: signal is 1;
  attribute max_fanout of dinb4: signal is 1;
  attribute max_fanout of din_insert1: signal is 1;
  attribute max_fanout of din_insert2: signal is 1;
  attribute max_fanout of din_insert3: signal is 1;
  attribute max_fanout of din_insert4: signal is 1;



  


  signal addr_query1,addr_query2,addr_query3,addr_query4:std_logic_vector(logsize-1 downto 0);
  signal temp_addr_query1,temp_addr_query2,temp_addr_query3,temp_addr_query4:std_logic_vector(15 downto 0);
  signal addrb_1,addrb_2,addrb_3,addrb_4:std_logic_vector(logsize-1 downto 0);
  signal temp_addr_insert1,temp_addr_insert2,temp_addr_insert3,temp_addr_insert4:std_logic_vector(15 downto 0);
  signal addr_insert1,addr_insert2,addr_insert3,addr_insert4:std_logic_vector(logsize-1 downto 0);

  signal ht_mem1: ht_mem_type:= ((others=> (others=>'0'))); --(others => (x"0000000000000000000000000000000000000000" & "00"));
  signal ht_mem2: ht_mem_type:= ((others=> (others=>'0'))); --(others => (x"0000000000000000000000000000000000000000" & "00"));
  signal ht_mem3: ht_mem_type:= ((others=> (others=>'0'))); --(others => (x"0000000000000000000000000000000000000000" & "00"));
  signal ht_mem4: ht_mem_type:= ((others=> (others=>'0'))); --(others => (x"0000000000000000000000000000000000000000" & "00"));
  attribute ram_style:string;
  attribute ram_style of ht_mem1:signal is "block";
    attribute ram_style of ht_mem2:signal is "block";
      attribute ram_style of ht_mem3:signal is "block";
        attribute ram_style of ht_mem4:signal is "block";
        
        attribute max_fanout of addrb_1: signal is 1;
        attribute max_fanout of addrb_2: signal is 1;
        attribute max_fanout of addrb_3: signal is 1;
        attribute max_fanout of addrb_4: signal is 1;  

          signal to_hash: std_logic_vector(key_len-1 downto 0);
          signal hashed_query,hashed_insert: std_logic_vector(63 downto 0);


          signal count_collision_next,count_collision: std_logic_vector(31 downto 0);
          signal count_item_next,count_item: std_logic_vector(31 downto 0);
          signal count_select_kick: std_logic_vector(15 downto 0);

	  signal present1, present2, present3, present4: boolean;
	  signal present_insert1, present_insert2, present_insert3, present_insert4: boolean;

   
        begin

--         out_count_collision  <= count_collision; 
--         out_count_item <=count_item; 


g1_128: if key_len=128 generate
     hashed_query <= search_key(63 downto 0 ) xor myror(search_key(127 downto 64),7);
end generate;
g1_64: if key_len=64 generate
     hashed_query <= search_key(63 downto 0 ) xor myror(search_key(63 downto 0),7);
end generate;
g1_48: if key_len=48 generate
     hashed_query <= ( search_key(47 downto 32 ) xor search_key(31 downto 16 ) xor search_key(15 downto 0 ) ) & search_key(47 downto 0 );
end generate;


g2_128: if key_len=128 generate
          hashed_insert <= (key_d(63 downto 0 ) xor myror(key_d(127 downto 64),7)) when write_enable_1='1' else
                           (key_d(63 downto 0 ) xor myror(key_d(127 downto 64),7)) when write_enable_2='1' else
                           (key_d(63 downto 0 ) xor myror(key_d(127 downto 64),7)) when write_enable_3='1' else
                           (key_d(63 downto 0 ) xor myror(key_d(127 downto 64),7)) when write_enable_4='1' else
                           (key(63 downto 0 ) xor myror(key(127 downto 64),7));
end generate;

g2_64: if key_len=64 generate
          hashed_insert <= (key_d(63 downto 0 ) xor myror(key_d(63 downto 0),7)) when write_enable_1='1' else
                           (key_d(63 downto 0 ) xor myror(key_d(63 downto 0),7)) when write_enable_2='1' else
                           (key_d(63 downto 0 ) xor myror(key_d(63 downto 0),7)) when write_enable_3='1' else
                           (key_d(63 downto 0 ) xor myror(key_d(63 downto 0),7)) when write_enable_4='1' else
                           (key(63 downto 0 ) xor myror(key(63 downto 0),7));
end generate;
g2_48: if key_len=48 generate
          hashed_insert <= (key_d(47 downto 32 ) xor key_d(31 downto 16 ) xor key_d(15 downto 0 ) ) & key_d(47 downto 0 ) when write_enable_1='1' else
                           (key_d(47 downto 32 ) xor key_d(31 downto 16 ) xor key_d(15 downto 0 ) ) & key_d(47 downto 0 ) when write_enable_2='1' else
                           (key_d(47 downto 32 ) xor key_d(31 downto 16 ) xor key_d(15 downto 0 ) ) & key_d(47 downto 0 ) when write_enable_3='1' else
                           (key_d(47 downto 32 ) xor key_d(31 downto 16 ) xor key_d(15 downto 0 ) ) & key_d(47 downto 0 ) when write_enable_4='1' else
                           (key(47 downto 32 ) xor key(31 downto 16 ) xor key(15 downto 0 ) ) & key(47 downto 0 );
end generate;

           
          temp_addr_query1<=  hashed_query(15 downto 0)  xor hashed_query(38 downto 23);
          temp_addr_query2<=  hashed_query(31 downto 16) xor hashed_query(55 downto 40);
          temp_addr_query3<=  hashed_query(47 downto 32) xor hashed_query(32 downto 17);
          temp_addr_query4<=  hashed_query(63 downto 48) xor hashed_query(23 downto 8);
          
          addr_query1<= temp_addr_query1(logsize-1 downto 0);
          addr_query2<= temp_addr_query2(logsize-1 downto 0);
          addr_query3<= temp_addr_query3(logsize-1 downto 0);
          addr_query4<= temp_addr_query4(logsize-1 downto 0);
          

          --hashed_insert <= key(63 downto 0 ) xor myror(key(127 downto 64),7);




          temp_addr_insert1<=  hashed_insert(15 downto 0)  xor hashed_insert(38 downto 23);
          temp_addr_insert2<=  hashed_insert(31 downto 16) xor hashed_insert(55 downto 40);
          temp_addr_insert3<=  hashed_insert(47 downto 32) xor hashed_insert(32 downto 17);
          temp_addr_insert4<=  hashed_insert(63 downto 48) xor hashed_insert(23 downto 8);

          addr_insert1<=temp_addr_insert1(logsize-1 downto 0);
          addr_insert2<=temp_addr_insert2(logsize-1 downto 0);
          addr_insert3<=temp_addr_insert3(logsize-1 downto 0);
          addr_insert4<=temp_addr_insert4(logsize-1 downto 0);

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

          --DUAL PORT RAM1
          process(clock)
          begin
            if(clock'event and clock = '1') then
              dout_query1<= ht_mem1(conv_integer(addr_query1));
            end if;
          end process;

          process(clock)
          begin
            if(clock'event and clock = '1') then
              if(write_enable_1 = '1') then
                ht_mem1(conv_integer(addrb_1)) <= dinb1;
              end if;
              dout_insert1 <= ht_mem1(conv_integer(addrb_1));
            end if;
          end process;


          --DUAL PORT RAM2
          process(clock)
          begin
            if(clock'event and clock = '1') then
              dout_query2<= ht_mem2(conv_integer(addr_query2));
            end if;
          end process;

          process(clock)
          begin
            if(clock'event and clock = '1') then
              if(write_enable_2 = '1') then
                ht_mem2(conv_integer(addrb_2)) <= dinb2;
              end if;
              dout_insert2 <= ht_mem2(conv_integer(addrb_2));
            end if;
          end process;


          --DUAL PORT RAM3
          process(clock)
          begin
            if(clock'event and clock = '1') then
              dout_query3<= ht_mem3(conv_integer(addr_query3));
            end if;
          end process;

          process(clock)
          begin
            if(clock'event and clock = '1') then
              if(write_enable_3 = '1') then
                ht_mem3(conv_integer(addrb_3)) <= dinb3;
              end if;
              dout_insert3 <= ht_mem3(conv_integer(addrb_3));
            end if;
          end process;



          --DUAL PORT RAM4
          process(clock)
          begin
            if(clock'event and clock = '1') then
              dout_query4<= ht_mem4(conv_integer(addr_query4));
            end if;
          end process;

          process(clock)
          begin
            if(clock'event and clock = '1') then
              if(write_enable_4 = '1') then
                ht_mem4(conv_integer(addrb_4)) <= dinb4;
              end if;
              dout_insert4 <= ht_mem4(conv_integer(addrb_4));
            end if;
          end process;

--          --AXI Read
          addrb_1<= addr(logsize-1 downto 0) when ((we='1') or (rd='1')) else addr_insert1;
          addrb_2<= addr(logsize-1 downto 0) when ((we='1') or (rd='1')) else addr_insert2;
          addrb_3<= addr(logsize-1 downto 0) when ((we='1') or (rd='1')) else addr_insert3;
          addrb_4<= addr(logsize-1 downto 0) when ((we='1') or (rd='1')) else addr_insert4;
          data_out <= dout_insert1 when addr(logsize+1 downto logsize)="00" else 
                      dout_insert2 when addr(logsize+1 downto logsize)="01" else
                      dout_insert3 when addr(logsize+1 downto logsize)="10" else 
                      dout_insert4;


--          --AXI WRITE
--          --        (AXI)                     OPP
          dinb1 <= input_din when we='1' else din_insert1;
          dinb2 <= input_din when we='1' else din_insert2;
          dinb3 <= input_din when we='1' else din_insert3;
          dinb4 <= input_din when we='1' else din_insert4;

          write_enable_1 <= '1' when we='1' and addr(11 downto 10)="00" else memory_write_enable_1;
          write_enable_2 <= '1' when we='1' and addr(11 downto 10)="01" else memory_write_enable_2;
          write_enable_3 <= '1' when we='1' and addr(11 downto 10)="10" else memory_write_enable_3;
          write_enable_4 <= '1' when we='1' and addr(11 downto 10)="11" else memory_write_enable_4;


          --colors 
          present1 <= true when ((dout_query1(key_len+value_len)='1') and (dout_query1(key_len+value_len+3 downto key_len+value_len+1)=current_color)) else
                      true when ((dout_query1(key_len+value_len)='1') and (dout_query1(key_len+value_len+3 downto key_len+value_len+1)=current_color-1)) else
                      false;
          present2 <= true when ((dout_query2(key_len+value_len)='1') and (dout_query2(key_len+value_len+3 downto key_len+value_len+1)=current_color)) else
                      true when ((dout_query2(key_len+value_len)='1') and (dout_query2(key_len+value_len+3 downto key_len+value_len+1)=current_color-1)) else
                      false;
          present3 <= true when ((dout_query3(key_len+value_len)='1') and (dout_query3(key_len+value_len+3 downto key_len+value_len+1)=current_color)) else
                      true when ((dout_query3(key_len+value_len)='1') and (dout_query3(key_len+value_len+3 downto key_len+value_len+1)=current_color-1)) else
                      false;
          present4 <= true when ((dout_query4(key_len+value_len)='1') and (dout_query4(key_len+value_len+3 downto key_len+value_len+1)=current_color)) else
                      true when ((dout_query4(key_len+value_len)='1') and (dout_query4(key_len+value_len+3 downto key_len+value_len+1)=current_color-1)) else
                      false;

          -- OUTPUT logic: select the query answer
          process(present1,present2,present3,present4,search, dout_query1, dout_query2, dout_query3, dout_query4, search_d )
          begin
              match  <='0';
              output <= (others =>'0');
              if search='1' then
                if ((dout_query1(key_len-1 downto 0)=search_d) and present1) then
                  output <= dout_query1(key_len+value_len-1 downto key_len);
                  match <='1';
                end if;
                if ((dout_query2(key_len-1 downto 0)=search_d) and present2) then
                  output <= dout_query2(key_len+value_len-1 downto key_len);
                  match <='1';
                end if;
                if ((dout_query3(key_len-1 downto 0)=search_d) and present3) then
                  output <= dout_query3(key_len+value_len-1 downto key_len);
                  match <='1';
                end if;
                if ((dout_query4(key_len-1 downto 0)=search_d) and present4) then
                  output <= dout_query4(key_len+value_len-1 downto key_len);
                  match <='1';
                end if;
              end if;
          end process;





--          process(clock)
--          begin
--            if(clock'event and clock = '1') then
--		if (RESET = '1') then
--		    count_collision <= x"00000000";
--		    count_item <=  x"00000000";
--		    count_select_kick <=  x"0000";
--		else
--		    count_select_kick <=  (count_select_kick + 1) xor myror(count_select_kick(15 downto 0),5); --select the item to kick out
--		    if (clear_count_collision='1') then 
--		      count_collision <= x"00000000";
--		    else 
--		      count_collision <= count_collision_next;
--		    end if;  
--		    count_item <= count_item_next;
--		end if;
--	    end if;
--          end process;



          --colors 
          present_insert1 <= true when ((dout_insert1(key_len+value_len)='1') and (dout_insert1(key_len+value_len+3 downto key_len+value_len+1)=current_color)) else
                      true when ((dout_insert1(key_len+value_len)='1') and (dout_insert1(key_len+value_len+3 downto key_len+value_len+1)=current_color-1)) else
                      false;
          present_insert2 <= true when ((dout_insert2(key_len+value_len)='1') and (dout_insert2(key_len+value_len+3 downto key_len+value_len+1)=current_color)) else
                      true when ((dout_insert2(key_len+value_len)='1') and (dout_insert2(key_len+value_len+3 downto key_len+value_len+1)=current_color-1)) else
                      false;
          present_insert3 <= true when ((dout_insert3(key_len+value_len)='1') and (dout_insert3(key_len+value_len+3 downto key_len+value_len+1)=current_color)) else
                      true when ((dout_insert3(key_len+value_len)='1') and (dout_insert3(key_len+value_len+3 downto key_len+value_len+1)=current_color-1)) else
                      false;
          present_insert4 <= true when ((dout_insert4(key_len+value_len)='1') and (dout_insert4(key_len+value_len+3 downto key_len+value_len+1)=current_color)) else
                      true when ((dout_insert4(key_len+value_len)='1') and (dout_insert4(key_len+value_len+3 downto key_len+value_len+1)=current_color-1)) else
                      false;



            din_insert1(key_len+value_len-1 downto 0) <= value_d & key_d;
            din_insert2(key_len+value_len-1 downto 0) <=value_d  & key_d;
            din_insert3(key_len+value_len-1 downto 0) <=value_d  & key_d;
            din_insert4(key_len+value_len-1 downto 0) <=value_d  & key_d;

            din_insert1(key_len+value_len+3 downto key_len+value_len+1) <=current_color;
            din_insert2(key_len+value_len+3 downto key_len+value_len+1) <=current_color;
            din_insert3(key_len+value_len+3 downto key_len+value_len+1) <=current_color;
            din_insert4(key_len+value_len+3 downto key_len+value_len+1) <=current_color;


          -- control logic
          process(count_select_kick,present_insert1,present_insert2,present_insert3,present_insert4,count_item,count_collision,key_d,update_d,remove_d,insert_d,dout_insert1,dout_insert2,dout_insert3,dout_insert4)
          variable updated: boolean;
          begin
            updated:=false;
	    kicked  <='0';
            kicked_value<=(others => '0'); 
            kicked_key <=(others => '0');  
            kicked_color <=(others => '0');  
            --count_collision_next <= count_collision;
            --count_item_next <= count_item;
            din_insert1(key_len+value_len) <= '0'; 
            din_insert2(key_len+value_len) <= '0'; 
            din_insert3(key_len+value_len) <= '0'; 
            din_insert4(key_len+value_len) <= '0'; 

            memory_write_enable_1<='0';
            memory_write_enable_2<='0';
            memory_write_enable_3<='0';
            memory_write_enable_4<='0';

            if (remove_d='1') then
              if ((dout_insert1(key_len-1 downto 0)=key_d) and dout_insert1(key_len+value_len)='1') then 
--                count_item_next <= count_item-1;
                memory_write_enable_1<='1';
              elsif ((dout_insert2(key_len-1 downto 0)=key_d) and dout_insert2(key_len+value_len)='1') then
--                count_item_next <= count_item-1;
                memory_write_enable_2<='1';
              elsif ((dout_insert3(key_len-1 downto 0)=key_d) and dout_insert3(key_len+value_len)='1') then
--                count_item_next <= count_item-1;
                memory_write_enable_3<='1';
              elsif ((dout_insert4(key_len-1 downto 0)=key_d) and dout_insert4(key_len+value_len)='1') then
--                count_item_next <= count_item-1;
                memory_write_enable_4<='1';
              else
                report "remove failed" & LF ; 
              end if;
            end if;

            --if (update_d='1') then
            if ((update_d='1') or (insert_d='1')) then
              -- if the item is already here 
              if ((dout_insert1(key_len-1 downto 0)=key_d) and dout_insert1(key_len+value_len)='1') then 
	        din_insert1(key_len+value_len) <= '1'; 
                memory_write_enable_1<='1';
                updated:=true;
              end if;
              if ((dout_insert2(key_len-1 downto 0)=key_d) and dout_insert2(key_len+value_len)='1') then 
	        din_insert2(key_len+value_len) <= '1'; 
                memory_write_enable_2<='1';
                updated:=true;
              end if;
              if ((dout_insert3(key_len-1 downto 0)=key_d) and dout_insert3(key_len+value_len)='1') then 
	        din_insert3(key_len+value_len) <= '1'; 
                memory_write_enable_3<='1';
                updated:=true;
              end if;
              if ((dout_insert4(key_len-1 downto 0)=key_d) and dout_insert4(key_len+value_len)='1') then 
	        din_insert4(key_len+value_len) <= '1'; 
                memory_write_enable_4<='1';
                updated:=true;
              end if;
            end if;

            -- If item is not present
            if ((not updated) and (insert_d='1')) then
              if ((dout_insert1(key_len+value_len)='0') or (not present_insert1)) then
                din_insert1(key_len+value_len) <= '1'; -- metto a zero con remove;
--                count_item_next <= count_item+1;
                memory_write_enable_1<='1';
              elsif ((dout_insert2(key_len+value_len)='0') or (not present_insert2)) then
                din_insert2(key_len+value_len) <= '1'; -- metto a zero con remove;
--                count_item_next <= count_item+1;
                memory_write_enable_2<='1';
              elsif ((dout_insert3(key_len+value_len)='0') or (not present_insert3)) then
                din_insert3(key_len+value_len) <= '1'; -- metto a zero con remove;
--                count_item_next <= count_item+1;
                memory_write_enable_3<='1';
              elsif ((dout_insert4(key_len+value_len)='0') or (not present_insert4)) then
                din_insert4(key_len+value_len) <= '1'; -- metto a zero con remove;
--                count_item_next <= count_item+1;
                memory_write_enable_4<='1';
              else
                report "insertion failed" & LF ; 
                --count_collision_next <= count_collision+1;
                -- kick out an item randomply (depending on the clock cycle) 
                if count_select_kick(1 downto 0)="00" then
                  din_insert1(key_len+value_len) <= '1'; -- metto a zero con remove;
                  kicked  <='1';
                  kicked_value <=dout_insert1(key_len+value_len-1 downto key_len); 
                  kicked_key   <=dout_insert1(key_len-1 downto 0);  
                  kicked_color <=dout_insert1(key_len+value_len+3 downto key_len+value_len+1);  
                  memory_write_enable_1<='1';
                elsif count_select_kick(1 downto 0)="01" then
                  din_insert2(key_len+value_len) <= '1'; -- metto a zero con remove;
                  kicked  <='1';
                  kicked_value<=dout_insert2(key_len+value_len-1 downto key_len); 
                  kicked_key <=dout_insert2(key_len-1 downto 0);  
                  kicked_color <=dout_insert2(key_len+value_len+3 downto key_len+value_len+1);  
                  memory_write_enable_2<='1';
                elsif count_select_kick(1 downto 0)="10" then
                  din_insert3(key_len+value_len) <= '1'; -- metto a zero con remove;
                  kicked  <='1';
                  kicked_value<=dout_insert3(key_len+value_len-1 downto key_len); 
                  kicked_key <=dout_insert3(key_len-1 downto 0);  
                  kicked_color <=dout_insert3(key_len+value_len+3 downto key_len+value_len+1);  
                  memory_write_enable_3<='1';
                else 
                  din_insert4(key_len+value_len) <= '1'; -- metto a zero con remove;
                  kicked  <='1';
                  kicked_value<=dout_insert4(key_len+value_len-1 downto key_len); 
                  kicked_key <=dout_insert4(key_len-1 downto 0);  
                  kicked_color <=dout_insert4(key_len+value_len+3 downto key_len+value_len+1);  
                  memory_write_enable_4<='1';
                end if;
              end if;
            end if;
          --end if;

        end process;

      end behavioral;


