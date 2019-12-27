library ieee;
use ieee.std_logic_1164.all;
use IEEE.STD_LOGIC_unsigned.ALL;
--use ieee.std_logic_arith.all;
use IEEE.NUMERIC_STD.ALL;


library work;
--use work.hash_pkg.all;
use work.ram_pkg.all;

entity cuckoo is

  generic (
    key_len : integer := 128;
    value_len : integer := 126;
    logsize : integer := 10
    );
  port ( 
         clock : in std_logic;
         reset : in std_logic;
         enable: in std_logic;
         
--         --AXI interface

         we: in std_logic;
         rd: in std_logic;
         input_din: in std_logic_vector(1+key_len+value_len downto 0);
         addr :in std_logic_vector(logsize+3 downto 0);
         data_out :out std_logic_vector(255 downto 0);

         --Hash Interface
         pre_insert : in std_logic; -- is '1' 1 cc before insert      
         insert : in std_logic; -- 1 to insert      
         key    : in std_logic_vector(key_len-1 downto 0); -- key to insert
         value  : in std_logic_vector(value_len-1 downto 0); -- value to insert

         current_color : in std_logic_vector(2 downto 0);
         remove : in std_logic; -- 1 to remove
         search : in std_logic; -- 1 to search
         search_key : in std_logic_vector(key_len-1 downto 0); -- key to search
         hit  : out std_logic; 
         tot_num_entry_stash : out std_logic_vector(31 downto 0);
         num_entry_stash : out std_logic_vector(31 downto 0);
         num_present   : out std_logic_vector(31 downto 0);
         clear_count_collision: in std_logic;
         count_collision : out std_logic_vector(31 downto 0);
         count_cuckoo_insert : out std_logic_vector(31 downto 0);  
         count_item      : out std_logic_vector(31 downto 0);
         evicted_entry : out std_logic_vector(31 downto 0);
         search_value    : out std_logic_vector(value_len-1 downto 0); -- value associated with the searched value
         key_len_in:   in std_logic_vector(clogb2(128) downto 0);
         value_len_in: in std_logic_vector(clogb2(128) downto 0)
     
       );

end cuckoo;

architecture behavioral of cuckoo is
  signal int_count_cuckoo_insert:std_logic_vector(31 downto 0);  
  signal hit_stash,hit_ht: std_logic;
  signal search_value_stash, search_value_ht : std_logic_vector(value_len-1 downto 0);
  signal search_color_stash: std_logic_vector(2 downto 0);
  
  signal color_out_stash,kicked_color,color : std_logic_vector(2 downto 0);
  signal update_stash,remove_d,insert_d,kicked            : std_logic;
  signal kicked_key                          : std_logic_vector(key_len-1 downto 0);
  signal kicked_value                        : std_logic_vector(value_len-1 downto 0);

  signal insert_FSM, search_FSM, remove_FSM  : std_logic;
  signal search_key_FSM, key_FSM             : std_logic_vector(key_len-1 downto 0);
  signal stash_not_empty                     : std_logic;
  signal value_FSM                           : std_logic_vector(value_len -1 downto 0);

  signal key_out_stash                       : std_logic_vector(key_len-1 downto 0);
  signal value_out_stash                     : std_logic_vector(value_len -1 downto 0);

  signal temp_data_out                       : std_logic_vector(key_len+value_len+1 downto 0); 


begin
  
  data_out(key_len+value_len+1 downto 0)<=  temp_data_out;
  --data_out(255 downto key_len+value_len+4)<=  (others =>'0');
  
  
--  HT: entity work.ht128dp generic map (key_len,value_len,logsize) 
--                    port map (
--                    clock => clock,
--                    reset => reset,

--				     we => we,
--				     rd => rd,
--				     input_din => input_din, 
--				     addr  => addr,
--				     data_out  => temp_data_out,


--                                     kicked => kicked,
--                                     kicked_value  => kicked_value,
--                                     kicked_key    => kicked_key,
--                                     kicked_color    => kicked_color,

--				                     current_color  => color,
--                                     insert => insert_FSM,
--                                     key    => key_FSM,
--                                     value  =>value_FSM,

--                                     search    => search_FSM,
--                                     update  => '0',
--                                     remove => remove, 
--                                     search_key =>  search_key,
--                                     output => search_value_ht,
--                                     out_count_collision  => count_collision,
--                                     clear_count_collision => clear_count_collision,
--                                     out_count_item => count_item,
--                                     match => hit_ht
--                                   );
                                   
   HT_ale: entity work.ht128newa 
   
   Port map ( 
                    clock => clock,
   reset => reset,

    we => we,
    rd => rd,
    input_din => input_din(255 downto 0), 
    addr  => addr,
    data_out  => temp_data_out,


                    kicked => kicked,
                    kicked_value  => kicked_value,
                    kicked_key    => kicked_key,
                    
                     key_len=> key_len_in,
                     value_len=> value_len_in,

                
                    insert => insert_FSM,
                    key    => key_FSM,
                    value  =>value_FSM,

                    search    => search_FSM,
                    update  => '0',
                    remove => remove, 
                    search_key =>  search_key,
                    output => search_value_ht,
                    out_count_collision  => count_collision,
                    clear_count_collision => clear_count_collision,
                    out_count_item => count_item,
                    match => hit_ht
   );                                
                                   
                                   
                                   
                                   
                                   
                                   

  ST: entity work.stash  generic map (key_len,value_len+3) 
      port map (
                                    clk    => clock,
                                    reset  => reset,
                                    insert => kicked,
                                    key => kicked_key,
                                    --value => kicked_value, 
                                    value(value_len+2 downto value_len) =>(others=>'0'), --kicked_color, 
                                    value(value_len-1 downto 0) => kicked_value,
                                    not_empty => stash_not_empty,
                                    search    => search_FSM,
                                    update  => update_stash,
                                    remove => remove_FSM, 
                                    key_out => key_out_stash,
                                    --value_out => value_out_stash, 
                                    value_out(value_len+2 downto value_len) => color_out_stash,
                                    value_out(value_len-1 downto 0) => value_out_stash, 
                                    search_key  =>  search_key_FSM,
                                    search_value(value_len+2 downto value_len) => search_color_stash,
                                    search_value(value_len-1 downto 0) => search_value_stash,
                                    num_entry => num_entry_stash,
                                    num_present => num_present,
                                    tot_num_entry => tot_num_entry_stash,
                                    evicted_entry => evicted_entry,
                                    hit    => hit_stash
                                  );




process (clock)
  begin 
  if (clock='1' and clock'event) then  
  	if reset='1' then
	    hit<='0';
            search_value <= (others =>'0');
            insert_d<='0';
            remove_d<='0';
            int_count_cuckoo_insert <=  (others =>'0');
        else
            insert_d<=insert;
            remove_d<=remove;
	    hit <= hit_stash or hit_ht ;
            if insert='1' then 
                int_count_cuckoo_insert <= int_count_cuckoo_insert + 1;
            end if;
	    if (search ='1' and hit_ht='1') then 
		search_value <= search_value_ht;
	    elsif (search ='1' and hit_stash='1') then 
		search_value <= search_value_stash;
            else
                search_value <= (others =>'0');
		end if;
       end if;
  end if;
end process;

count_cuckoo_insert <=int_count_cuckoo_insert;

CARONTE_FSM: process (color_out_stash,current_color,enable,search_key,pre_insert,remove,remove_d,search,insert,insert_d,key_out_stash,value_out_stash,key,value, stash_not_empty)
  begin

    key_FSM <= key; --  by default key_in to HT
    value_FSM <= value; -- by default value_in to HT
    remove_FSM <= remove;
    search_FSM <= search;
    search_key_FSM <= search_key;
    insert_FSM <= insert;
    update_stash  <= insert;
    color <= current_color; 
    
    if (enable='1') and (search='0') and (pre_insert='0') and (insert='0') and (insert_d='0') and (remove='0') and (remove_d='0') then
      --doing anything -> clear the stash
      if (stash_not_empty = '1') then
        remove_FSM <='1'; -- remove from stash
        search_key_FSM <= key_out_stash; -- key to remove

        insert_FSM <= '1'; -- insert in HT
        key_FSM <= key_out_stash; -- key to HT
        value_FSM <= value_out_stash; -- key to HT
        color <= color_out_stash; 
      end if;
    end if; 
    
end process;

end behavioral;


