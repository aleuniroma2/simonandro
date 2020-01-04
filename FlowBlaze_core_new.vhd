-- ----------------------------------------------------------------------------
--                             Entity declaration
-- ----------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all; 

Library UNISIM;
use UNISIM.vcomponents.all;
use work.salutil.all;

Library cam;

entity FlowBlaze_core_new is 
    generic (
        key_len : integer := 128;
        value_len : integer := 126;
        logsize : integer := 10;
    
-- Parameters of AxiStream Slave Bus Interface S00_AXIS
                C_S00_AXIS_DATA_WIDTH  : integer   := 256;
                C_S00_AXIS_TUSER_WIDTH : integer   := 128;
-- Parameters of AxiStream Master Bus Interface M00_AXIS
                C_M00_AXIS_DATA_WIDTH  : integer   := 256;
                C_M00_AXIS_TUSER_WIDTH : integer   := 128;
-- Parameters of Axi Slave Bus Interface S00_AXIS
                C_S00_AXI_DATA_WIDTH  : integer   := 32;
                C_S00_AXI_ADDR_WIDTH  : integer   := 32;
                C_BASEADDR  : std_logic_vector(31 downto 0)   := x"80000000"
--                C_HIGHADDR  : std_logic_vector(31 downto 0)   := x"9FFFFFFF"
            );
    port (
-- Ports of Axi Master Bus Interface M00_AXIS

-- Global ports
             ACLK    : in std_logic;
             ARESETN : in std_logic;
             
--             M0_AXIS_ACLK : in std_logic;
--             M0_AXIS_ARESETN  : in std_logic;

-- Master Stream Ports.
             M0_AXIS          : out axis;  
             M0_AXIS_TREADY   : in std_logic;

-- Master Stream Ports.
--	         M_DEBUG   : out axis;

-- Ports of Axi Stream Slave Bus Interface S00_AXIS

             S0_AXIS         : in axis;
             S0_AXIS_TREADY  : out std_logic;

-- Ports of Axi Slave Bus Interface S_AXI
             s_axi_in          : in  axi_m2s;
             s_axi_out         : out axi_s2m     
        
         );
end entity;

architecture full of FlowBlaze_core_new is



component fallthrough_small_fifo 
  generic (
  WIDTH: integer := 72;
  MAX_DEPTH_BITS: integer := 3;
  PROG_FULL_THRESHOLD: integer := 0
  );
  port(
       din   : in  std_logic_vector(WIDTH-1 downto 0); --data in
       wr_en : in  std_logic;
       rd_en : in  std_logic;  
       dout: out  std_logic_vector(WIDTH-1 downto 0); --data out
       full: out  std_logic;
       nearly_full: out  std_logic;
       prog_full: out  std_logic;
       empty : out  std_logic;  
       reset : in  std_logic;
       clk : in  std_logic
       );
end component;


    type  dq_fsm is (IDLE,WAIT_EOP);
    signal dedue_state, dedue_state_next: dq_fsm;
    type  out_fsm is (WRITE,MODIFY,DELETE);
    signal out_field :out_fsm;

    
    signal write_in,write_out,modify_out,del_out,modify_in: axis;
    signal vlan_axis_in, v2v, v2v2, vlan_axis_out: axis;
    signal v2v_TREADY,v2v2_TREADY: std_logic;
    
    
    signal fifo_out: std_logic_vector(416 downto 0);
    signal write_TREADY,write_in_TREADY,write_out_TREADY,modify_in_TREADY,modify_out_TREADY,del_in_TREADY,del_out_TREADY:std_logic;
    signal enable_write,enable_modify,enable_del: std_logic;
    
    function myror (L: std_logic_vector; R: integer) return std_logic_vector is
    begin
        return to_stdlogicvector(to_bitvector(L) ror R);
    end function myror;

    signal RESETN,RESET   : std_logic;

-- ----------------------------------------------------------------------------
-- signals for AXI Lite
-- ----------------------------------------------------------------------------

--type axi_states is (addr_wait, read_state, write_state, response_state);
--signal axi_state : axi_states;
    signal axi_state :std_logic_vector(2 downto 0);
    signal address : std_logic_vector(C_S00_AXI_ADDR_WIDTH-1 downto 0);
    signal write_enable: std_logic;
    signal read_enable: std_logic;
    signal int_S_AXI_BVALID: std_logic;

-- ----------------------------------------------------------------------------
-- signals for ETH decoding 
-- ----------------------------------------------------------------------------

    type fsm_states is (IDLE, PKT1,PKT2,WAIT5);
    --type fsm_states is (IDLE, PKT1,PKT2,PKT3,PKT4,PKT5);
    type full_header_type is array (11 downto 0) of std_logic_vector(431 downto 0);


    signal curr_state, next_state : fsm_states;
    --signal FSMnowait,step: boolean;
    signal FSMnowait,step: boolean;
    
-- ----------------------------------------------------------------------------
-- signals for packet classification 
-- ----------------------------------------------------------------------------
    signal is_IP,is_UDP,is_TCP: boolean;
    signal src_if: std_logic_vector(7 downto 0);
    signal dst_if: std_logic_vector(7 downto 0);
    signal pkt_len: std_logic_vector(15 downto 0);
    signal metadata1: std_logic_vector(31 downto 0);
    signal metadata2: std_logic_vector(31 downto 0);
    signal random: std_logic_vector(31 downto 0);
    signal timer: std_logic_vector(63 downto 0);
    signal timestamp: std_logic_vector(31 downto 0);
    signal threshold: std_logic_vector(31 downto 0);
    signal conditions: std_logic_vector(15 downto 0);
    signal src_mac,dst_mac: std_logic_vector(47 downto 0);
    signal src_ip,dst_ip: std_logic_vector(31 downto 0);
    signal src_port,dst_port: std_logic_vector(15 downto 0);
    signal full_header: std_logic_vector(431 downto 0);
    signal full_header_d: full_header_type;
    signal full_input_1: std_logic_vector(127 downto 0);
    signal full_input_ht: std_logic_vector(127 downto 0);
    --signal full_input_2: std_logic_vector(119 downto 0);
    signal full_input_2: std_logic_vector(87 downto 0);
    --signal data_ht: std_logic_vector(255 downto 0);
     signal data_ht: std_logic_vector(255 downto 0);


-- ----------------------------------------------------------------------------
-- stats  
-- ----------------------------------------------------------------------------
    signal out_not_ready_stall_count, in_not_ready_stall_count, res_count,pkt_count,byte_count,ip_count,tcp_count,udp_count:std_logic_vector(31 downto 0);
    --signal ip_count1,tcp_count1,udp_count1:std_logic_vector(31 downto 0);
    --signal ip_count2,tcp_count2,udp_count2:std_logic_vector(31 downto 0);
    --signal ip_count3,tcp_count3,udp_count3:std_logic_vector(31 downto 0);
    --signal ip_count4,tcp_count4,udp_count4:std_logic_vector(31 downto 0);

    signal  match_ht,match_t1, match_t2: std_logic;
    signal  startd     : std_logic_vector(11 downto 0);
    signal  start      : std_logic;
    signal  release_number,release_date: std_logic_vector(31 downto 0);
    signal  match_addr_tcam1, match_addr_tcam2: std_logic_vector (4 downto 0);	
    signal  addr_ram1, addr_ram2,addr_ram3: std_logic_vector (4 downto 0);	
    signal  flow_state_tcam1: std_logic_vector (31 downto 0);	
    signal  flow_state_tcam2: std_logic_vector (31 downto 0);
    signal  flow_state_tcam2_d3: std_logic_vector (31 downto 0);		

    --signal  flow_context: std_logic_vector (103 downto 0);
      signal  flow_context: std_logic_vector (125 downto 0);

    signal  R1: std_logic_vector (31 downto 0);
    signal  R1d: std_logic_vector (31 downto 0);
    signal  R1dd: std_logic_vector (31 downto 0);
    signal  R1ddd: std_logic_vector (31 downto 0);
    signal  O1: std_logic_vector (31 downto 0);
    signal  Res1: std_logic_vector (31 downto 0);

    signal  R2: std_logic_vector (31 downto 0);
    signal  R2d: std_logic_vector (31 downto 0);
    signal  R2dd: std_logic_vector (31 downto 0);
    signal  R2ddd: std_logic_vector (31 downto 0);
    signal  O2: std_logic_vector (31 downto 0);
    signal  Res2: std_logic_vector (31 downto 0);

    signal  R3: std_logic_vector (31 downto 0);
    signal  R3d: std_logic_vector (31 downto 0);
    signal  R3dd: std_logic_vector (31 downto 0);
    signal  R3ddd: std_logic_vector (31 downto 0);
    signal  O3: std_logic_vector (31 downto 0);
    signal  Res3: std_logic_vector (31 downto 0);

    signal  OffO1: std_logic_vector (5 downto 0);
    signal  LenO1: std_logic_vector (1 downto 0);

    signal  OffO2: std_logic_vector (5 downto 0);
    signal  LenO2: std_logic_vector (1 downto 0);

    signal  OffO3: std_logic_vector (5 downto 0);
    signal  LenO3: std_logic_vector (1 downto 0);



    --signal  update_context: std_logic_vector (103 downto 0);
       signal  update_context: std_logic_vector (125 downto 0);	



    signal  we_r1,we_r2,we_r3,we_r4,we_pipealu:std_logic;
    signal  ht_rd: std_logic;
    signal color_scale:	std_logic_vector(31 downto 0);
    signal color:	std_logic_vector(2 downto 0);
    signal  ht_en,ht_we,cam1_we,cam2_we:std_logic;
    signal  tcam_mask : std_logic_vector(255 downto 0);
    signal  tcam_data_in : std_logic_vector(255 downto 0);
    signal 	read_from_ram1,read_from_ram2,read_from_ram3,read_from_ram4 :std_logic_vector(31 downto 0);
    signal  ht_data_in : std_logic_vector(257 downto 0);


    signal  lookup_scope: std_logic_vector(31 downto 0);
    signal  FSM_scope:    std_logic_vector(31 downto 0);
    signal  update_scope: std_logic_vector(31 downto 0);
    signal  action_value: std_logic_vector(31 downto 0);
    signal  pause,reg_test0,configuration_register: std_logic_vector(31 downto 0);
    signal  pause_short_pkt: std_logic_vector(31 downto 0);
    
        


    signal  aluGR0, GR0: std_logic_vector(31 downto 0);
    signal  aluGR1, GR1: std_logic_vector(31 downto 0);
    signal  aluGR2, GR2: std_logic_vector(31 downto 0);
    signal  aluGR3, GR3: std_logic_vector(31 downto 0);
--    signal  aluGR4, GR4: std_logic_vector(31 downto 0);
--    signal  aluGR5, GR5: std_logic_vector(31 downto 0);
--    signal  aluGR6, GR6: std_logic_vector(31 downto 0);
--    signal  aluGR7, GR7: std_logic_vector(31 downto 0);
--    signal  aluGR8, GR8: std_logic_vector(31 downto 0);
--    signal  aluGR9, GR9: std_logic_vector(31 downto 0);
--    signal  aluGR10, GR10: std_logic_vector(31 downto 0);
--    signal  aluGR11, GR11: std_logic_vector(31 downto 0);
--    signal  aluGR12, GR12: std_logic_vector(31 downto 0);
--    signal  aluGR13, GR13: std_logic_vector(31 downto 0);
--    signal  aluGR14, GR14: std_logic_vector(31 downto 0);
--    signal  aluGR15, GR15: std_logic_vector(31 downto 0);

-- ----------------------------------------------------------------------------
-- action signals 
-- ----------------------------------------------------------------------------
    signal  mask_lookup:   std_logic_vector(127 downto 0);
    signal  mask_update:   std_logic_vector(127 downto 0);
    signal  action_header: std_logic_vector(127 downto 0);
    signal  update_key: std_logic_vector(127 downto 0);
    signal  slot_delayer,enable_delay  : std_logic;
    signal  enable_ht     : std_logic;
    signal  remove_action: std_logic;
    signal  insert_action: std_logic;
    signal  drop_action:   std_logic;
    
    signal  enable_debug_pkts:   std_logic_vector(31 downto 0);
        
    signal modify_offset :std_logic_vector(13 downto 0);
    signal modify_size   :std_logic_vector(1 downto 0);
    signal modify_field  :std_logic_vector(31 downto 0);


    signal int_M0_AXIS_TUSER: std_logic_vector(C_M00_AXIS_TUSER_WIDTH-1 downto 0);
    signal int_M0_AXIS_TVALID,int_S0_AXIS_TVALID,int_S0_AXIS_TREADY: std_logic;

    signal 	action:std_logic_vector(31 downto 0);



-- 
--  [31:24] --> out port
--  [23:16] --> action for packet
--  [15:0]  --> action for HT
    signal action_d3:std_logic_vector(31 downto 0);
    

-- 
--  [31:16] --> Immediate modify field
--  [15:14] --> modify size
--  [13:0]  --> modify offest

    signal action_value_d3:std_logic_vector(31 downto 0);


-- ----------------------------------------------------------------------------
-- checksum signals 
-- ----------------------------------------------------------------------------
    signal oldIPchksum,oldTCPchksum: std_logic_vector(17 downto 0);
    signal newIPchksum,newTCPchksum: std_logic_vector(15 downto 0);
    signal out_dst_ip,t1,tt1: std_logic_vector(17 downto 0);
    signal t2,tt2: std_logic_vector(16 downto 0);
    signal t3,tt3: std_logic_vector(15 downto 0);



    signal tot_num_entry_stash,num_entry_stash,num_present : std_logic_vector(31 downto 0);
    signal count_cuckoo_insert : std_logic_vector(31 downto 0);
    signal count_collision : std_logic_vector(31 downto 0);
    signal count_item      : std_logic_vector(31 downto 0);
    signal evicted_entry : std_logic_vector(31 downto 0);  
    signal clear_count_collision : std_logic;
         

    signal id: std_logic_vector(1 downto 0):=(others=>'0');
     signal LFSR_Data: std_logic_vector(31 downto 0):=(others=>'0');
     
     
     signal CR: cr_type;
     --signal CR1: std_logic_vector(31 downto 0):=(others=>'0');
     --signal CR2: std_logic_vector(31 downto 0):=(others=>'0');
     --signal CR3: std_logic_vector(31 downto 0):=(others=>'0');
     --signal CR4: std_logic_vector(31 downto 0):=(others=>'0');
     
     
     
  
     signal count_frames: std_logic_vector(31 downto 0);
     
     signal wr_en,rd_en,command_rd_en,command_empty,empty_fifo,nearly_full_fifo: std_logic;
     signal fifo_out_command: std_logic_vector(64 downto 0);
     signal enable_remover : std_logic;

     signal key_len_in: std_logic_vector (7 downto 0);
     signal value_len_in: std_logic_vector (7 downto 0);


--  attribute mark_debug: string;
--  attribute max_fanout:integer;
--  attribute keep:string;
--  attribute dont_touch:string;
  
  
----  attribute keep of s_axi_out   :signal is "TRUE";
----  attribute keep of int_S_AXI_BVALID   :signal is "TRUE";
----  attribute keep of axi_state    :signal is "TRUE";
----  attribute keep of address   :signal is "TRUE";
----  attribute keep of write_enable   :signal is "TRUE";
----  attribute keep of read_enable   :signal is "TRUE";
----  attribute keep of s_axi_in   :signal is "TRUE";
  
----  attribute dont_touch of s_axi_out   :signal is "TRUE";
----  attribute dont_touch of int_S_AXI_BVALID   :signal is "TRUE";
----  attribute dont_touch of axi_state    :signal is "TRUE";
----  attribute dont_touch of address   :signal is "TRUE";
----  attribute dont_touch of write_enable   :signal is "TRUE";
----  attribute dont_touch of read_enable   :signal is "TRUE";
----  attribute dont_touch of s_axi_in   :signal is "TRUE";
    
----  attribute mark_debug of s_axi_out   :signal is "TRUE";
----  attribute mark_debug of int_S_AXI_BVALID   :signal is "TRUE";
----  attribute mark_debug of axi_state    :signal is "TRUE";
----  attribute mark_debug of address   :signal is "TRUE";
----  attribute mark_debug of write_enable   :signal is "TRUE";
----  attribute mark_debug of read_enable   :signal is "TRUE";
----  attribute mark_debug of s_axi_in   :signal is "TRUE";
        
--  attribute keep of startd   :signal is "TRUE";
--  attribute dont_touch of startd   :signal is "TRUE";
--  attribute mark_debug of startd   :signal is "TRUE";
    
--  attribute keep of start    :signal is "TRUE";
--  attribute dont_touch of start    :signal is "TRUE";
--  attribute mark_debug of start    :signal is "TRUE";
    
--  attribute keep of step    :signal is "TRUE";
--  attribute dont_touch of step    :signal is "TRUE";
--  attribute mark_debug of step    :signal is "TRUE";
    
--  attribute keep of curr_state          :signal is "TRUE";
--  attribute dont_touch of curr_state    :signal is "TRUE";
--  attribute mark_debug of curr_state    :signal is "TRUE";
  
--  attribute keep of count_frames          :signal is "TRUE";
--  attribute dont_touch of count_frames    :signal is "TRUE";
--  attribute mark_debug of count_frames    :signal is "TRUE";
  
--  --attribute keep of S0_AXIS_TVALID          :signal is "TRUE";
--  --attribute dont_touch of S0_AXIS_TVALID    :signal is "TRUE";
--  --attribute mark_debug of S0_AXIS_TVALID    :signal is "TRUE";
    
----  attribute keep of int_S0_AXIS_TREADY          :signal is "TRUE";
----  attribute dont_touch of int_S0_AXIS_TREADY    :signal is "TRUE";
----  attribute mark_debug of int_S0_AXIS_TREADY    :signal is "TRUE";
      
----  attribute keep of int_S0_AXIS_TVALID          :signal is "TRUE";
----  attribute dont_touch of int_S0_AXIS_TVALID    :signal is "TRUE";
----  attribute mark_debug of int_S0_AXIS_TVALID    :signal is "TRUE";
    
--  attribute keep of full_input_1          :signal is "TRUE";
--  attribute dont_touch of full_input_1    :signal is "TRUE";
--  attribute mark_debug of full_input_1    :signal is "TRUE";
          
--  attribute keep of full_input_2          :signal is "TRUE";
--  attribute dont_touch of full_input_2    :signal is "TRUE";
--  attribute mark_debug of full_input_2    :signal is "TRUE";


--  attribute keep of  flow_state_tcam1       :signal is "TRUE";
--  attribute dont_touch of flow_state_tcam1  :signal is "TRUE";
--  attribute mark_debug of flow_state_tcam1  :signal is "TRUE";

--  attribute keep of  flow_context       :signal is "TRUE";
--  attribute dont_touch of flow_context  :signal is "TRUE";
--  attribute mark_debug of flow_context   :signal is "TRUE";
      
--  attribute keep of  match_ht       :signal is "TRUE";
--  attribute dont_touch of match_ht  :signal is "TRUE";
--  attribute mark_debug of match_ht   :signal is "TRUE";

--  attribute keep of insert_action          :signal is "TRUE";
--  attribute dont_touch of insert_action    :signal is "TRUE";
--  attribute mark_debug of insert_action    :signal is "TRUE";
    
----  attribute keep of action          :signal is "TRUE";
----  attribute dont_touch of action    :signal is "TRUE";
----  attribute mark_debug of action    :signal is "TRUE";
     
   
--  attribute keep of action_d3          :signal is "TRUE";
--  attribute dont_touch of action_d3    :signal is "TRUE";
--  attribute mark_debug of action_d3    :signal is "TRUE";


--  attribute keep of action_value_d3          :signal is "TRUE";
--  attribute dont_touch of action_value_d3    :signal is "TRUE";
--  attribute mark_debug of action_value_d3    :signal is "TRUE";



--   attribute keep of update_key :signal is "TRUE";
--   attribute dont_touch of  update_key :signal is "TRUE";
--   attribute mark_debug of  update_key :signal is "TRUE";
   
--   attribute keep of update_context :signal is "TRUE";
--   attribute dont_touch of  update_context :signal is "TRUE";
--   attribute mark_debug of  update_context :signal is "TRUE";

--  --attribute max_fanout of match_ht         :signal is 50; --fo=102
--  --attribute max_fanout of startd           :signal is 100;
    
--  attribute keep of M0_AXIS  :signal is "TRUE";
--  attribute dont_touch of  M0_AXIS  :signal is "TRUE";
--  attribute mark_debug of  M0_AXIS  :signal is "TRUE";

-- ----------------------------------------------------------------------------
--                             Architecture body
-- ----------------------------------------------------------------------------

begin

    RESETN<=ARESETN;
    RESET<=not (ARESETN);



    --M_DEBUG_TVALID<='0';
    --M_DEBUG.TUSER(127 downto 32)  <= (others =>'0');
    --M_DEBUG.TUSER(31 downto 0) <= x"02100060";
    --M_DEBUG.TKEEP  <= (others =>'1');
    --M_DEBUG.TLAST  <= startd(3);--startd(5);
    --M_DEBUG.TVALID <= startd(1) or startd(2) or startd(3) when (enable_debug_pkts/=x"00000000") else '0';
    --M_DEBUG.TDATA  <= match_ht & "0000000" &  full_input_ht(31 downto 0) & full_input_2(31 downto 0) & "000" & match_addr_tcam2 & flow_state_tcam2 & x"3200" & x"0045" & x"0008" & x"010c42363996" & x"3633159196B4";




-- -------------------------------------------------------------------------
--
-- process to detect if the next word is available
--
-- -------------------------------------------------------------------------

    step_assign: step<= true when (S0_AXIS.TVALID='1') and (nearly_full_fifo = '0') else false;


-- -------------------------------------------------------------------------
--
-- extract Header ETH-IP-TCP/UDP
--
-- -------------------------------------------------------------------------

      process(ACLK)
    begin
        if (ACLK'event and ACLK = '1') then
            if (ARESETN = '0') then
                --FSMnowait<=true;
                curr_state <= IDLE;
                full_header <= (others => '0');
                start <='0';
                --startd<= (others => '0');
                in_not_ready_stall_count<= (others => '0');
                out_not_ready_stall_count<= (others => '0');
                pkt_count<= (others => '0');
                byte_count<= (others => '0');
                ip_count<= (others => '0');
                udp_count<= (others => '0');
                tcp_count<= (others => '0');
                count_frames<=  (others => '0');
            else              
		        count_frames<= count_frames+1;
		        
		        in_not_ready_stall_count<= in_not_ready_stall_count + (S0_AXIS.TVALID and nearly_full_fifo);
		        out_not_ready_stall_count<= out_not_ready_stall_count + (modify_out.TVALID and not M0_AXIS_TREADY);
                if res_count=x"00000000" then 
                      in_not_ready_stall_count<= (others => '0');
                      out_not_ready_stall_count<= (others => '0');
                end if;
                
		start <='0';
                case curr_state is
                    when IDLE =>
			            
                        --FSMnowait<=true;
                        if (step) then
                            curr_state <= PKT1;
                            pkt_len <= S0_AXIS.TUSER(15 downto 0);
                            pkt_count <= pkt_count +1;
			    byte_count <= byte_count+(x"0000" & S0_AXIS.TUSER(15 downto 0));
                            dst_if <= S0_AXIS.TUSER(31 downto 24);
                            src_if <= S0_AXIS.TUSER(23 downto 16);
                            metadata1 <= S0_AXIS.TUSER(63 downto 32);
                            
                            if configuration_register(0)='0' then 
                                metadata2 <= timer(31 downto 0);
                            else 
                                metadata2 <= S0_AXIS.TUSER(95 downto 64);
                            end if;
                            
                            dst_mac <= S0_AXIS.TDATA(47 downto 0);
                            src_mac <= S0_AXIS.TDATA(95 downto 48);
                            full_header(255 downto 0) <=S0_AXIS.TDATA;
                            src_ip <= (others => '0');
                            dst_ip <= (others => '0');
                            src_port <= (others => '0');
                            dst_port <= (others => '0');
                            is_ip<=false;
                            is_UDP<=false;
                            is_TCP<=false;
                            if (S0_AXIS.TDATA(111 downto 96)=x"0008") then --> 0x0800 reversed
                                ip_count <= ip_count+1;
                                is_ip<=true;
                                if (S0_AXIS.TDATA(191 downto 184)=x"11") then --FIXME does not check eth header lenght
                                    udp_count <= udp_count+1;
                                    is_UDP<=true;
                                end if;
                                if (S0_AXIS.TDATA(191 downto 184)=x"06") then --FIXME does not check eth header lenght
                                    tcp_count <= tcp_count+1;
                                    is_TCP<=true;
                                end if;
                                src_ip <= S0_AXIS.TDATA(239 downto 208);
                                dst_ip(15 downto 0) <=S0_AXIS.TDATA(255 downto 240);
                            end if; --IS_IP 
                        end if;
                    when PKT1 =>
                        count_frames<=  x"00000002";
                        if (step) then
                            dst_ip(31 downto 16) <=S0_AXIS.TDATA(15 downto 0);
                            --full_header(431 downto 256) <= metadata2 & metadata1 & dst_if & timer(38 downto 7) &  S0_AXIS.TDATA(159 downto 144) & src_if & S0_AXIS.TDATA(47 downto 0);
                            full_header(431 downto 256) <= metadata2 & metadata1 & dst_if &  S0_AXIS.TDATA(191 downto 144) & src_if & S0_AXIS.TDATA(47 downto 0);
                            start <='1';
                            if (is_TCP or is_UDP) then
                                src_port <= S0_AXIS.TDATA(31 downto 16);
                                dst_port <= S0_AXIS.TDATA(47 downto 32);
                            end if;
                            if ((S0_AXIS.TLAST='1') and (pause_short_pkt/=x"00000000")) then
				curr_state <= WAIT5;
                            elsif ((S0_AXIS.TLAST='1') and (pause_short_pkt=x"00000000")) then
                                curr_state <= IDLE;
                            else
				curr_state <= PKT2;
                            end if;
                        end if;
                    when PKT2 =>
                        if (step and S0_AXIS.TLAST='1') then
                            if ((count_frames< conv_integer(pause_short_pkt(3 downto 0))) and (pause_short_pkt/=x"00000000")) then
				curr_state <= WAIT5;
                            else
				curr_state <= IDLE;
                            end if;
                        end if;
                    when WAIT5 =>
                        if (count_frames> conv_integer(pause_short_pkt(3 downto 0))) then  --7
                            curr_state <= IDLE;
                        end if;
                end case;
            end if;
        end if;
    end process;


    process (ACLK)
    begin
        if (rising_edge(ACLK)) then
            if (RESET = '1') then
                random<= x"25C827F1";
                timer<=(others => '0'); --x"00000000000f4240"; --(others => '0');
            else
                random <= random xor myror(random,19) xor myror(random,8); 
                timer <= timer+1;
            end if;
        end if;
    end process;


    process (ACLK)
    begin
        if (rising_edge(ACLK)) then
            if (RESET = '1') then
                full_header_d <= (others =>(others => '0'));
                R1d<= (others => '0');
                R1dd<= (others => '0');
                R2d<= (others => '0');
                R2dd<= (others => '0');
                R3d<= (others => '0');
                R3dd<= (others => '0');
                startd<= (others => '0');
            else 

                startd<=startd(10 downto 0) & start;
                full_header_d<=full_header_d(10 downto 0) & full_header;
                
                R1d<= R1;
                R1dd<= R1d;
                R1ddd<=R1dd;
                R2d<= R2;
                R2dd<= R2d;
                R2ddd<=R2dd;
                R3d<= R3;
                R3dd<= R3d; 
                R3ddd<=R3dd;                    
            end if;
        end if;
    end process;







    -- -------------------------------------------------------------------------
    --  ADDRESS:
    -- 0x8000 0000 : Release number
    -- 0x8000 0004 : Release DATE 
    -- 0x8000 0008 : reg_test0
    -- 0x8000 000C : timer
    -- 0x8000 0010 : lookup_scope 
    -- 0x8000 0020 : update_scope
    -- 0x8000 0024 : 
    -- 0x8000 0030 : mask_lookup 
    -- 0x8000 0040 : mask_update
    -- 0x8000 0050 : FSM_scope
    -- 0x8000 0060 : OffO1-LenO1
    -- 0x8000 0070 : OffO2-LenO2
    -- 0x8000 0080 : OffO3-LenO3
    -- 0x8000 0090 : pause
    -- 0x8000 0094 : pause_short_pkt
    -- 0x8000 0100 : GR0
    -- 0x8000 0104 : GR1
    -- ..
    -- 0x8000 013C : GR15
    
    -- ..
    -- 0x8000 8000 : ip_count 
    -- 0x8000 8004 : udp_count
    -- 0x8000 8008 : tcp_count
    -- 0x8000 800C : 
    -- 0x8000 8010 : ip_count1 
    -- 0x8000 8014 : udp_count1
    -- 0x8000 8018 : tcp_count1
    -- 0x8000 801C : 
    -- 0x8000 8020 : ip_count2 
    -- 0x8000 8024 : udp_count2
    -- 0x8000 8028 : tcp_count2
    -- 0x8000 802C : 
    -- 0x8000 8030 : ip_count3
    -- 0x8000 8034 : udp_count3
    -- 0x8000 8038 : tcp_count3
    -- 0x8000 803C : 
    -- 0x8000 8040 : ip_count4
    -- 0x8000 8044 : udp_count4
    -- 0x8000 8048 : tcp_count4
    -- 0x8000 804C : 
    -- ..
    -- 0x8001 0000 : tcam1 32x128 ADDR 0 DIN[31:0]
    -- 0x8001 0004 : tcam1 32x128 ADDR 0 DIN[63:32]
    -- 0x8001 0008 : tcam1 32x128 ADDR 0 DIN[95:64]
    -- 0x8001 000C : tcam1 32x128 ADDR 0 DIN[127:96]
    -- 0x8001 0010 : tcam1 32x128 ADDR 0 DIN[159:128]
    -- [...]
    -- 0x8001 001C : tcam1 32x128 ADDR 0 DIN[255:223]

    -- 0x8001 0020 : tcam1 32x128 ADDR 0 DMASK[31:0]
    -- 0x8001 0024 : tcam1 32x128 ADDR 0 DMASK[63:32]
    -- 0x8001 0028 : tcam1 32x128 ADDR 0 DMASK[95:64]
    -- 0x8001 002C : tcam1 32x128 ADDR 0 DMASK[127:96]
    -- [...]
    -- 0x8001 003C : tcam1 32x128 ADDR 0 DMASK[255:223]

    -- 0x8001 0040 : tcam1 32x128 ADDR 1
    -- 0x8001 07F0 : tcam1 32x128 ADDR 31

    -- ..
    -- 0x8001 1000 : tcam2 32x161 ADDR 0
    -- 0x8001 1040 : tcam2 32x161 ADDR 1
    -- ..
    -- 0x8001 17F0 : tcam2 32x161 ADDR 31

    -- ..
    -- 0x8002 0000 : ram 32x32 ram1 ADDR0
    -- 0x8002 0004 : ram 32x32 ram1 ADDR1
    -- ..
    -- 0x8002 1000 : ram 32x32 ram2 ADDR 0
    -- ..
    -- 0x8002 2000 : ram 32x32 ram3 ADDR 0
    -- ..
    -- 0x8002 3000 : ram 32x32 ram4 ADDR 0
    -- ..
    -- 0x8003 0000 : pipe_alu ram: 256x512 ADDR 0
    -- 0x8003 3FFF : pipe_alu ram: 256x512 ADDR 255
    -- ..
    -- 0x8010 0000 : hash table
    -- ..
    -- 0x8020 0000 : num_entry_stash 
    -- 0x8020 0004 : count_collision
    -- 0x8020 0008 : count_item
    -- 0x8020 000C : tot_num_entry_stash      
    -- 0x8020 0010 : num evicted entry  
    -- 0x8020 0014 : num_present        
    -- 0x8020 0018 : count_cuckoo_insert  
    -- -------------------------------------------------------------------------


    -- unused signals
    s_axi_out.AXI_BRESP <= "00";
    s_axi_out.AXI_RRESP <= "00";
    
    -- axi-lite slave state machine
    AXI_SLAVE_FSM: process (ACLK)
    begin
        if rising_edge(ACLK) then
            if  ARESETN='0' then -- slave reset state
                s_axi_out.AXI_RVALID <= '0';
                int_S_AXI_BVALID <= '0';
                s_axi_out.AXI_ARREADY <= '0';
                s_axi_out.AXI_WREADY <= '0';
                s_axi_out.AXI_AWREADY <= '0';
                --axi_state <= addr_wait;
                axi_state <= "000";
                address <= (others=>'0');
                write_enable <= '0';
            else
                case axi_state is
                    --when addr_wait => 
                    when "000" => 
                        s_axi_out.AXI_AWREADY <= '0';
                        s_axi_out.AXI_ARREADY <= '0';
                        s_axi_out.AXI_WREADY <= '0';
                        s_axi_out.AXI_RVALID <= '0';
                        int_S_AXI_BVALID <= '0';
                        read_enable <= '0';
                        write_enable <= '0';
                        -- wait for a read or write address and latch it in
                        
                        if (s_axi_in.AXI_ARVALID = '1') then -- read
                            --axi_state <= read_state;
                            axi_state <= "001";   -- TODO: only when curr_state=IDLE. Also put pause=1
                            address <= s_axi_in.AXI_ARADDR - (C_BASEADDR -x"80000000");
                            s_axi_out.AXI_ARREADY <= '1';
                            read_enable <= '1';
                        elsif (s_axi_in.AXI_AWVALID = '1' and s_axi_in.AXI_WVALID = '1' ) then -- write
                            --axi_state <= write_state;
                            axi_state <= "100";  
                            s_axi_out.AXI_WREADY <= '1';
                            s_axi_out.AXI_AWREADY <= '1';
                            address <= s_axi_in.AXI_AWADDR - (C_BASEADDR -x"80000000");
                        else
                            --axi_state <= addr_wait;
                            axi_state <= "000";
                        end if;

                    --when read_state (wait1) =>
                    when "001" =>
                        read_enable <= '1';
                        s_axi_out.AXI_WREADY <= '0';
                        s_axi_out.AXI_AWREADY <= '0';
                        s_axi_out.AXI_ARREADY <= '0';
                        -- place correct data on bus and generate valid pulse
                        int_S_AXI_BVALID <= '0';
                        s_axi_out.AXI_RVALID <= '0';
                        --axi_state <= read_wait2;
                        axi_state <= "010";

                    --when read_state (wait2) =>
                    when "010" =>
                        read_enable <= '1';
                        s_axi_out.AXI_WREADY <= '0';
                        s_axi_out.AXI_AWREADY <= '0';
                        s_axi_out.AXI_ARREADY <= '0';
                        -- place correct data on bus and generate valid pulse
                        int_S_AXI_BVALID <= '0';
                        s_axi_out.AXI_RVALID <= '0';
                        --axi_state <= response_state;
                        axi_state <= "011";

                    --when read_state =>
                    when "011" =>
                        read_enable <= '1';
                        s_axi_out.AXI_WREADY <= '0';
                        s_axi_out.AXI_AWREADY <= '0';
                        s_axi_out.AXI_ARREADY <= '0';
                        -- place correct data on bus and generate valid pulse
                        int_S_AXI_BVALID <= '0';
                        s_axi_out.AXI_RVALID <= '1';
                        --axi_state <= response_state;
                        axi_state <= "111";

                    --when write_state =>
                    when "100" =>
                        -- generate a write pulse
                        write_enable <= '1';
                        s_axi_out.AXI_AWREADY <= '0';
                        s_axi_out.AXI_ARREADY <= '0';
                        s_axi_out.AXI_WREADY <= '0';
                        int_S_AXI_BVALID <= '1';
                        --axi_state <= response_state;
                        axi_state <= "111";

                    --when response_state =>
                    when "111" =>
                        read_enable <= '0';
                        write_enable <= '0';
                        s_axi_out.AXI_AWREADY <= '0';
                        s_axi_out.AXI_ARREADY <= '0';
                        s_axi_out.AXI_WREADY <= '0';
                        -- wait for response from master
                      --if ( s_axi_in.AXI_RREADY = '1') or (int_S_AXI_BVALID = '1' and s_axi_in.AXI_BREADY = '1') then 
                     if (( int_S_AXI_BVALID = '0' and s_axi_in.AXI_RREADY = '1') or (int_S_AXI_BVALID = '1' and s_axi_in.AXI_BREADY = '1')) then ---
                            s_axi_out.AXI_RVALID <= '0';
                            int_S_AXI_BVALID <= '0';
                            --axi_state <= addr_wait;
                          axi_state <= "000";
                        else
                            --axi_state <= response_state;
                            axi_state <= "111";
                        end if;
                    when others =>
                        null; 
                end case;
            end if;
        end if;
    end process;
    s_axi_out.AXI_BVALID <= int_S_AXI_BVALID;


    REG_WRITE_PROCESS: process(ACLK)
    begin
        if (ACLK'event and ACLK = '1') then
            clear_count_collision <='0';
            if (ARESETN = '0') then
                --mask_lookup(127 downto 48)   <=(others =>'0');
                --mask_lookup(47 downto 0)   <=(others =>'1');
                --mask_update(127 downto 48)   <=(others =>'0');
                --mask_update(47 downto 0)   <=(others =>'1');
                 
                clear_count_collision <='0';
                pause_short_pkt<= (others =>'0');
                reg_test0      <= (others =>'0');
                pause          <= (others =>'0');
                configuration_register <= (others =>'0');
                tcam_data_in   <= (others =>'0');
                tcam_mask      <= (others =>'0');
                ht_data_in     <= (others =>'0');
                cr             <= (others =>(others =>'0'));
--                CR1            <= (others =>'0');
--                CR2            <= (others =>'0');
--                CR3            <= (others =>'0');
--                CR4            <= (others =>'0');
                lookup_scope          <= x"0000001A";
                GR0                   <= x"00000000";--1
                GR1                   <= x"00000000";--64
                GR2                   <= x"00000000";
                GR3                   <= x"00000000";
--                GR4                   <= x"00000000";
--                GR5                   <= x"00000000";
--                GR6                   <= x"00000000";
--                GR7                   <= x"00000000";
--                GR8                   <= x"00000000";
--                GR9                   <= x"00000000";
--                GR10                  <= x"00000000";
--                GR11                  <= x"00000000";
--                GR12                  <= x"00000000";
--                GR13                  <= x"00000000";
--                GR14                  <= x"00000000";
--                GR15                  <= x"00000000";
                  key_len_in  <=x"80";
                  value_len_in<=x"80";
                
                update_scope          <= x"0000001A";
                FSM_scope             <= x"0000002E";
                mask_lookup           <= x"000000000000000000000000ffffffff"; 
                mask_update           <= x"000000000000000000000000ffffffff"; 
                OffO1                 <= "101000";
                LenO1                 <= "11";
                OffO2                 <= "101000";
                LenO2                 <= "11";
                OffO3                 <= "010000";
                LenO3                 <= "01";
         else
            if ((write_enable='0') and (startd(10)='1')) then --8
                GR0                   <= aluGR0;
                GR1                   <= aluGR1;
                GR2                   <= aluGR2;
                GR3                   <= aluGR3;
--                GR4                   <= aluGR4;
--                GR5                   <= aluGR5;
--                GR6                   <= aluGR6;
--                GR7                   <= aluGR7;
--                GR8                   <= aluGR8;
--                GR9                   <= aluGR9;
--                GR10                  <= aluGR10;
--                GR11                  <= aluGR11;
--                GR12                  <= aluGR12;
--                GR13                  <= aluGR13;
--                GR14                  <= aluGR14;
--                GR15                  <= aluGR15;
            elsif (write_enable='1' and (startd(8)/='1')) then
                if (address=x"80000008") then
                    reg_test0 <= s_axi_in.AXI_WDATA;
                end if;
                --if (address=x"8000000C") then
                --    reg_test1 <= S_AXI_WDATA;
                --end if;
                if (address=x"80000010") then
                    lookup_scope <= s_axi_in.AXI_WDATA;
                end if;
                if (address=x"80000020") then
                    update_scope <= s_axi_in.AXI_WDATA;
                end if;
                if (address=x"80000024") then
		            null;
                end if;
                if (address=x"80000030") then
                    mask_lookup(31 downto 0) <= s_axi_in.AXI_WDATA;
                end if;
                if (address=x"80000034") then
                    mask_lookup(63 downto 32) <= s_axi_in.AXI_WDATA;
                end if;
                if (address=x"80000038") then
                    mask_lookup(95 downto 64) <= s_axi_in.AXI_WDATA;
                end if;
                if (address=x"8000003C") then
                    mask_lookup(127 downto 96) <= s_axi_in.AXI_WDATA;
                end if;
                if (address=x"80000040") then
                    mask_update(31 downto 0) <= s_axi_in.AXI_WDATA;
                end if;
                if (address=x"80000044") then
                    mask_update(63 downto 32) <= s_axi_in.AXI_WDATA;
                end if;
                if (address=x"80000048") then
                    mask_update(95 downto 64) <= s_axi_in.AXI_WDATA;
                end if;
                if (address=x"8000004C") then
                    mask_update(127 downto 96) <= s_axi_in.AXI_WDATA;
                end if;
                if (address=x"80000050") then
                    FSM_scope <= s_axi_in.AXI_WDATA;
                end if;
                if (address=x"80000060") then
                    OffO1 <= s_axi_in.AXI_WDATA(5 downto 0);
                    LenO1 <= s_axi_in.AXI_WDATA(7 downto 6);
                end if;
                if (address=x"80000070") then
                    OffO2 <= s_axi_in.AXI_WDATA(5 downto 0);
                    LenO2 <= s_axi_in.AXI_WDATA(7 downto 6);
                end if;
                if (address=x"80000080") then
                    OffO3 <= s_axi_in.AXI_WDATA(5 downto 0);
                    LenO3 <= s_axi_in.AXI_WDATA(7 downto 6);
                end if;
                if (address=x"80000090") then
                    pause  <= s_axi_in.AXI_WDATA;
                end if;
                if (address=x"80000094") then                
                    pause_short_pkt<= s_axi_in.AXI_WDATA;
                end if;                                
                if (address=x"80000100") then
                    GR0 <= s_axi_in.AXI_WDATA;
                end if;
                if (address=x"80000104") then
                    GR1 <= s_axi_in.AXI_WDATA;
                end if;
                if (address=x"80000108") then
                    GR2 <= s_axi_in.AXI_WDATA;
                end if;
                if (address=x"8000010C") then
                    GR3 <= s_axi_in.AXI_WDATA;
                end if;
                if address = x"80008000" then
                    res_count<= s_axi_in.AXI_WDATA ;
                end if;        
                if address = x"80009000" then
                    color_scale<= s_axi_in.AXI_WDATA ;
                end if;        
                if address = x"80009004" then                 
                    enable_debug_pkts<= s_axi_in.AXI_WDATA ;
                end if; 
                
                if address = x"8000A000" then
                    configuration_register<= s_axi_in.AXI_WDATA ;
                end if;        
                
                if ((address(31 downto 16)=x"8001") and address(5 downto 0)="000000") then
                    tcam_data_in(31 downto 0)<= s_axi_in.AXI_WDATA;
                end if;
                if ((address(31 downto 16)=x"8001") and address(5 downto 0)="000100") then
                    tcam_data_in(63 downto 32)<= s_axi_in.AXI_WDATA;
                end if;
                if ((address(31 downto 16)=x"8001") and address(5 downto 0)="001000") then
                    tcam_data_in(95 downto 64)<= s_axi_in.AXI_WDATA;
                end if;
                if ((address(31 downto 16)=x"8001") and address(5 downto 0)="001100") then
                    tcam_data_in(127 downto 96)<= s_axi_in.AXI_WDATA;
                end if;
                if ((address(31 downto 16)=x"8001") and address(5 downto 0)="010000") then
                    tcam_data_in(159 downto 128)<= s_axi_in.AXI_WDATA;
                end if;
                if ((address(31 downto 16)=x"8001") and address(5 downto 0)="010100") then
                    tcam_data_in(191 downto 160)<= s_axi_in.AXI_WDATA;
                end if;
                if ((address(31 downto 16)=x"8001") and address(5 downto 0)="011000") then
                    tcam_data_in(223 downto 192)<= s_axi_in.AXI_WDATA;
                end if;
                if ((address(31 downto 16)=x"8001") and address(5 downto 0)="011100") then
                    tcam_data_in(255 downto 224)<= s_axi_in.AXI_WDATA;
                end if;
                if ((address(31 downto 16)=x"8001") and address(5 downto 0)="100000") then
                    tcam_mask(31 downto 0)<= s_axi_in.AXI_WDATA;
                end if;
                if ((address(31 downto 16)=x"8001") and address(5 downto 0)="100100") then
                    tcam_mask(63 downto 32)<= s_axi_in.AXI_WDATA;
                end if;
                if ((address(31 downto 16)=x"8001") and address(5 downto 0)="101000") then
                    tcam_mask(95 downto 64)<= s_axi_in.AXI_WDATA;
                end if;
                if ((address(31 downto 16)=x"8001") and address(5 downto 0)="101100") then
                    tcam_mask(127 downto 96)<= s_axi_in.AXI_WDATA;
                end if;
                if ((address(31 downto 16)=x"8001") and address(5 downto 0)="110000") then
                    tcam_mask(159 downto 128)<= s_axi_in.AXI_WDATA;
                end if;
                if ((address(31 downto 16)=x"8001") and address(5 downto 0)="110100") then
                    tcam_mask(191 downto 160)<= s_axi_in.AXI_WDATA;
                end if;
                if ((address(31 downto 16)=x"8001") and address(5 downto 0)="111000") then
                    tcam_mask(223 downto 192)<= s_axi_in.AXI_WDATA;
                end if;
                if ((address(31 downto 16)=x"8001") and address(5 downto 0)="111100") then
                    tcam_mask(255 downto 224)<= s_axi_in.AXI_WDATA;
                end if;
                --if (address(31 downto 23)="100000000" and address(4 downto 2)="000") then    
                --if (address(31 downto 22)="1000000000" and address(4 downto 2)="000") then    
                --if (address(31 downto 21)="10000000000" and address(4 downto 2)="000") then    
                if (address(31 downto 20)=x"801" and address(4 downto 2)="000") then    
                    ht_data_in(31 downto 0)<=s_axi_in.AXI_WDATA;
                end if;        
                if (address(31 downto 20)=x"801" and address(4 downto 2)="001") then    
                    ht_data_in(63 downto 32)<=s_axi_in.AXI_WDATA;
                end if;        
                if (address(31 downto 20)=x"801" and address(4 downto 2)="010") then    
                    ht_data_in(95 downto 64)<=s_axi_in.AXI_WDATA;
                end if;        
                if (address(31 downto 20)=x"801" and address(4 downto 2)="011") then    
                    ht_data_in(127 downto 96)<=s_axi_in.AXI_WDATA;
                end if;        
                if (address(31 downto 20)=x"801" and address(4 downto 2)="100") then    
                    ht_data_in(159 downto 128)<=s_axi_in.AXI_WDATA;
                end if;        
                if (address(31 downto 20)=x"801" and address(4 downto 2)="101") then    
                    ht_data_in(191 downto 160)<=s_axi_in.AXI_WDATA;
                end if;
                if (address(31 downto 20)=x"801" and address(4 downto 2)="110") then    
                    ht_data_in(223 downto 192)<=s_axi_in.AXI_WDATA;
                end if;        
                if (address(31 downto 20)=x"801" and address(4 downto 2)="111") then    
                    ht_data_in(255 downto 224)<=s_axi_in.AXI_WDATA;
                end if;
                if address =x"80200004" then 
                    clear_count_collision<='1';
                end if;
                if address =x"80ffff48" then 
                     --CR1<=s_axi_in.AXI_WDATA;
                     cr(0)<=s_axi_in.AXI_WDATA;
                end if;
                 if address =x"80ffff4c" then 
                      cr(1)<=s_axi_in.AXI_WDATA;
                end if;
                 if address =x"80ffff50" then 
                      cr(2)<=s_axi_in.AXI_WDATA;
                end if;
                 if address =x"80ffff54" then 
                      cr(3)<=s_axi_in.AXI_WDATA;
                 end if;
                 if address =x"80ffff58" then 
                      cr(4)<=s_axi_in.AXI_WDATA;
                 end if;
                 if address =x"80ffff5c" then 
                      cr(5)<=s_axi_in.AXI_WDATA;
                 end if;
                 if address =x"80ffff60" then 
                      cr(6)<=s_axi_in.AXI_WDATA;
                 end if;
                 if address =x"80ffff64" then 
                      cr(7)<=s_axi_in.AXI_WDATA;
                 end if;
                 if address =x"80ffff68" then 
                      cr(8)<=s_axi_in.AXI_WDATA;
                 end if;
                 if address =x"80ffff6c" then 
                      cr(9)<=s_axi_in.AXI_WDATA;
                 end if;
                 if address =x"80ffff70" then 
                      cr(10)<=s_axi_in.AXI_WDATA;
                 end if;
                 if address =x"80ffff74" then 
                      cr(11)<=s_axi_in.AXI_WDATA;
                 end if;
                 if address =x"80ffff78" then 
                      cr(12)<=s_axi_in.AXI_WDATA;
                 end if;
                 if address =x"80ffff7c" then 
                      cr(13)<=s_axi_in.AXI_WDATA;
                 end if;
                 if address =x"80ffff80" then 
                      cr(14)<=s_axi_in.AXI_WDATA;
                 end if;
                 if address =x"80ffff84" then 
                      cr(15)<=s_axi_in.AXI_WDATA;
                 end if;
                 if address =x"80ffff88" then 
                    key_len_in  <=s_axi_in.AXI_WDATA(7 downto 0);
                    value_len_in<=s_axi_in.AXI_WDATA(15 downto 8); 
                 end if;
             
          
            
              end if;
            end if;
        end if;
    end process;

    release_number<=x"12345678";


    USR_ACCESS_inst: if C_BASEADDR=x"80000000" generate
        U0: USR_ACCESSE2 port map( DATA => release_date);
    end generate;
    USR_ACCESS_noinst: if C_BASEADDR/=x"80000000" generate
        release_date <=x"11223344";
    end generate;




s_axi_out.AXI_RDATA <= release_number  when  address=x"80000000" else
        release_date                   when  address=x"80000004" else
        reg_test0                      when  address=x"80000008" else
        timer(47 downto 16)            when  address=x"8000000C" else
        lookup_scope                   when  address=x"80000010" else
        update_scope                   when  address=x"80000020" else
        mask_lookup(31  downto 0)      when  address=x"80000030" else
        mask_lookup(63  downto 32)     when  address=x"80000034" else
        mask_lookup(95  downto 64)     when  address=x"80000038" else
        mask_lookup(127 downto 96)     when  address=x"8000003C" else
        mask_update(31  downto 0)      when  address=x"80000040" else
        mask_update(63  downto 32)     when  address=x"80000044" else
        mask_update(95  downto 64)     when  address=x"80000048" else
        mask_update(127 downto 96)     when  address=x"8000004C" else
        FSM_scope                      when  address=x"80000050" else
        x"000000" & LenO1 & OffO1      when  address=x"80000060" else
        x"000000" & LenO2 & OffO2      when  address=x"80000070" else
        x"000000" & LenO3 & OffO3      when  address=x"80000080" else
        pause                          when  address=x"80000090" else
        pause_short_pkt                when  address=x"80000094" else
        GR0                            when  address=x"80000100" else
        GR1                            when  address=x"80000104" else
        GR2                            when  address=x"80000108" else
        GR3                            when  address=x"8000010C" else
        ip_count                       when  address=x"80000800" else
        res_count                      when  address=x"80008000" else
        udp_count                      when  address=x"80008004" else
        tcp_count                      when  address=x"80008008" else
        pkt_count                      when  address=x"80008010" else
        byte_count                     when  address=x"80008014" else
        in_not_ready_stall_count       when  address=x"80008020" else   
        out_not_ready_stall_count      when  address=x"80008030" else
        color_scale                    when  address=x"80009000" else
        enable_debug_pkts              when  address=x"80009004" else                             
        configuration_register         when  address=x"8000A000" else                                       
        read_from_ram1                 when  (address(31 downto 8)=x"800200" and address(7)='0') else 
        read_from_ram2                 when  (address(31 downto 8)=x"800210" and address(7)='0') else
        read_from_ram3                 when  (address(31 downto 8)=x"800220" and address(7)='0') else
        read_from_ram4                 when  (address(31 downto 8)=x"800230" and address(7)='0') else

        data_ht(31 downto 0)           when  (address(31 downto 20)=x"801" and address(4 downto 2)="000" ) else 
        data_ht(63 downto 32)          when  (address(31 downto 20)=x"801" and address(4 downto 2)="001" ) else 
        data_ht(95 downto 64)          when  (address(31 downto 20)=x"801" and address(4 downto 2)="010" ) else 
        data_ht(127 downto 96)         when  (address(31 downto 20)=x"801" and address(4 downto 2)="011" ) else 
        data_ht(159 downto 128)        when  (address(31 downto 20)=x"801" and address(4 downto 2)="100" ) else 
        data_ht(191 downto 160)        when  (address(31 downto 20)=x"801" and address(4 downto 2)="101" ) else 
        data_ht(223 downto 192)        when  (address(31 downto 20)=x"801" and address(4 downto 2)="110" ) else 
        data_ht(255 downto 224)        when  (address(31 downto 20)=x"801" and address(4 downto 2)="111" ) else 

        num_entry_stash                when  address=x"80200000" else                               
        count_collision                when  address=x"80200004" else                               
        count_item                     when  address=x"80200008" else                                    
        tot_num_entry_stash            when  address=x"8020000C" else                           
        evicted_entry                  when  address=x"80200010" else                                 
        num_present                    when  address=x"80200014" else                                   
        count_cuckoo_insert            when  address=x"80200018" else                           
        --CR1                            when  address=x"80ffff48" else                                           
        cr(0)                          when  address=x"80ffff48" else                                           
        cr(1)                          when  address=x"80ffff4C" else                                           
        cr(2)                          when  address=x"80ffff50" else                                           
        cr(3)                          when  address=x"80ffff54" else                                           
        cr(4)                          when  address=x"80ffff58" else                                           
        cr(5)                          when  address=x"80ffff5c" else                                           
        cr(6)                          when  address=x"80ffff60" else                                           
        cr(7)                          when  address=x"80ffff64" else                                           
        cr(8)                          when  address=x"80ffff68" else                                           
        cr(9)                          when  address=x"80ffff6c" else                                           
        cr(10)                          when  address=x"80ffff70" else                                           
        cr(11)                          when  address=x"80ffff74" else                                           
        cr(12)                          when  address=x"80ffff78" else                                           
        cr(13)                          when  address=x"80ffff7c" else                                           
        cr(14)                          when  address=x"80ffff80" else                                           
        cr(15)                          when  address=x"80ffff84" else  
       x"0000"&value_len_in & key_len_in  when address =x"80ffff88" else
                                           
        x"deadeeef";                                                                                                                     


    SAMls1: entity work.sam64 port map(full_header_d(0),lookup_scope(5 downto 0),full_input_1(63 downto 0));    --
    SAMls2: entity work.sam64 port map(full_header_d(0),lookup_scope(21 downto 16),full_input_1(127 downto 64));

    full_input_ht <= (full_input_1 and mask_lookup); 
-- process (ACLK)
--begin
--    if (rising_edge(ACLK)) then
--        if (RESET = '1') then
--            full_header <= (others =>'0');

--        else 
            
--               full_header_t <= full_header ; 
      
--        end if;
--    end if;
--end process;

    -- un cc dopo che lookup-key è pronta
    ht_en <=  startd(1); --or startd(1);-- or startd(2);  --0                

    enable_ht<= '1' when (pause=x"00000000") else '0'; 
    
    
    
    color <= 
             timer(15 downto 13) when color_scale(7 downto 0)=x"00000001" else
             timer(16 downto 14) when color_scale(7 downto 0)=x"00000002" else
             timer(17 downto 15) when color_scale(7 downto 0)=x"00000003" else
             timer(18 downto 16) when color_scale(7 downto 0)=x"00000004" else
             timer(19 downto 17) when color_scale(7 downto 0)=x"00000005" else
             timer(20 downto 18) when color_scale(7 downto 0)=x"00000006" else
             timer(21 downto 19) when color_scale(7 downto 0)=x"00000007" else
             timer(22 downto 20) when color_scale(7 downto 0)=x"00000008" else
             timer(23 downto 21) when color_scale(7 downto 0)=x"00000009" else
             timer(24 downto 22) when color_scale(7 downto 0)=x"0000000A" else
             timer(25 downto 23) when color_scale(7 downto 0)=x"0000000B" else
             timer(26 downto 24) when color_scale(7 downto 0)=x"0000000C" else
             timer(27 downto 25) when color_scale(7 downto 0)=x"0000000D" else
             timer(28 downto 26) when color_scale(7 downto 0)=x"0000000E" else
             "000";
    
    
    HT1: entity work.cuckoo
    --HT1: entity work.ht128dp
    generic map  (key_len,value_len,logsize)
    port map(
                clock => ACLK,
                reset => RESET,
                enable => enable_ht,
                
                current_color => color,                 
                --MI interface
                we => ht_we,
                rd => ht_rd,
              --  input_din => ht_data_in(3+key_len+value_len downto 0),
                input_din => ht_data_in(1+key_len+value_len downto 0),
                addr  => address(logsize+8 downto 5), --logsize ???
                data_out => data_ht, -- extended to 256
                
                num_entry_stash => num_entry_stash,
                num_present => num_present,
                count_cuckoo_insert => count_cuckoo_insert,  
                count_collision => count_collision,
                clear_count_collision => clear_count_collision,
                count_item => count_item,
                tot_num_entry_stash => tot_num_entry_stash,
                evicted_entry => evicted_entry,                         
                
                remove => remove_action,
                insert => insert_action,
                pre_insert => startd(9), --7     
                key    => update_key(key_len-1 downto 0),  --key_len-1 downto 0
                value  => update_context,
                search_key => full_input_ht(key_len-1 downto 0), --key_len-1 downto 0
                hit  => match_ht,
                search_value => flow_context,
                search  => ht_en,
                key_len_in=>key_len_in,
                value_len_in=>value_len_in
            );
     --R1<=x"aaaaaaaa"  when match_ht='1' else x"00000000";
    R1<=flow_context(31 downto 0)  when match_ht='1' else x"00000000";
    R2<=flow_context(63 downto 32) when match_ht='1' else x"00000000";
    R3<=flow_context(95 downto 64) when match_ht='1' else x"00000000";
         


    -- critical path qui!!!
    -- posso provare con:
    -- SAM1: entity work.sam32_c port map(S0_AXIS_ACLK,RESET,full_header_d(0),'0' & OffO1,LenO1,O1);
        
     
--    SAM1: entity work.sam32 port map(full_header_d(1),'0' & OffO1,LenO1,O1);
--    SAM2: entity work.sam32 port map(full_header_d(1),'0' & OffO2,LenO2,O2);
--    SAM3: entity work.sam32 port map(full_header_d(1),'0' & OffO3,LenO3,O3);
    SAM1: entity work.sam32_c port map(ACLK,RESET,full_header_d(0),'0' & OffO1,LenO1,O1);
    SAM2: entity work.sam32_c port map(ACLK,RESET,full_header_d(0),'0' & OffO2,LenO2,O2);
    SAM3: entity work.sam32_c port map(ACLK,RESET,full_header_d(0),'0' & OffO3,LenO3,O3);


    conditions_i: entity work.conditions
        port map(
        CR=>cr, --CR1, 
        GR0=>GR0,
        GR1=>GR1,
        GR2=>GR2,
        GR3=>GR3,
        R1=>R1,
        R2=>R2,
        R3=>R3,
        O1=>O1,
        O2=>O2,
        O3=>O3,
        timer=>timer(38 downto 7),

        conditions=>conditions 
    
        );





    Tcam1bis: entity cam.cam_top
    generic map (
                    --C_DEPTH =>32,
                    C_DEPTH =>8,
                    C_WIDTH =>128,
                    C_MEM_INIT_FILE  => "./init_cam_1.mif"
                )
    port map(
                CLK => ACLK,
                CMP_DIN => full_input_1,
                CMP_DATA_MASK => x"00000000000000000000000000000000",
                BUSY => open,    
                MATCH  => match_t1,
                MATCH_ADDR  => match_addr_tcam1(2 downto 0),
                WE       =>   cam1_we,
                WR_ADDR  => address(8 downto 6),
                DATA_MASK => tcam_mask(127 downto 0),
                DIN => tcam_data_in(127 downto 0),
                EN  => '1'
            );
            
    match_addr_tcam1(4 downto 3)<="00";


    -- from 0x8001_0000 to 0x8001_07FF
    cam1_we <=  write_enable when ((address(31 downto 12)=x"80010") and (address(11 downto 9 )="000")  and (address(5 downto 0)="111100")) else '0';

    -- from 0x8001_1000 to 0x8001_3FFF
    cam2_we <=  write_enable when ((address(31 downto 12)=x"80011") and (address(11)='0')  and (address(5 downto 0)="111100")) else '0';



    -- from 0x8010_0000 to 0x801f_ffff
    ht_we <= write_enable when ((address(31 downto 20)=x"801") and (address(4 downto 2)="111")) else '0';          
    ht_rd <= read_enable when (address(31 downto 20)=x"801") else '0';


    --  O3,O2,O1,conditions,state --120 bits
    --full_input_2<= O3 & O2 & O1 & conditions & flow_context(103 downto 96) when match_ht='1' else
    --               O3 & O2 & O1 & conditions & flow_state_tcam1(7 downto 0);
--    full_input_2<= O2 & O1 & conditions & flow_context(103 downto 96) when match_ht='1' else
--                   O2 & O1 & conditions & flow_state_tcam1(7 downto 0);
    process (ACLK)
begin
    if (rising_edge(ACLK)) then
        if (RESET = '1') then
            full_input_2 <= (others =>'0');

        else 
            if(match_ht='1') then
              full_input_2<= O2 & O1 & conditions & flow_context(103 downto 96);
            else
              full_input_2<= O2 & O1 & conditions & flow_state_tcam1(7 downto 0);
            end if;       
        end if;
    end if;
end process;


                         
    Tcam2bis: entity cam.cam_top
    generic map (
                    C_DEPTH =>32,
                    C_WIDTH =>88,
                    C_MEM_INIT_FILE  => "./init_cam_2.mif"
                )
    port map(
                CLK => ACLK,
                CMP_DIN => full_input_2,
                --CMP_DATA_MASK =>x"000000000000000000000000000000",
                CMP_DATA_MASK =>x"0000000000000000000000",
                BUSY => open,    
                MATCH  => match_t2,
                MATCH_ADDR  =>match_addr_tcam2 ,
                WE       =>   cam2_we,
                WR_ADDR  => address(10 downto 6), 
                --DATA_MASK =>tcam_mask(119 downto 0),
                --DIN =>tcam_data_in(119 downto 0),
                DATA_MASK =>tcam_mask(87 downto 0),
                DIN =>tcam_data_in(87 downto 0),
                EN  => '1'
            );


    we_r1 <= write_enable when ((address(31 downto 8)=x"800200") and (address(7)='0') ) else '0';
    we_r2 <= write_enable when ((address(31 downto 8)=x"800210") and (address(7)='0')) else '0';
    we_r3 <= write_enable when ((address(31 downto 8)=x"800220") and (address(7)='0')) else '0';
    we_r4 <= write_enable when ((address(31 downto 8)=x"800230") and (address(7)='0')) else '0';
    we_pipealu <= write_enable when ((address(31 downto 16)=x"8003") and (address(15)='0') and (address(14)='0')) else '0';



    --this ram provides the default state for the keys not in the flow context table (cuckoo) 
    r1dp:  entity work.ram32x32dp
    generic map (init_file => "./init_ram_1.mif")
    port map 
    (

        --AXI interface
        axi_clock => ACLK,
        we =>we_r1,
        axi_addr => address(6 downto 2), 
        axi_data_in => s_axi_in.AXI_WDATA,
        axi_data_out => read_from_ram1,

        -- AXIS interface
        clock => ACLK,
        addr    => match_addr_tcam1,
        data_out => flow_state_tcam1
    );

    --this ram provides the next state [7:0] and the instruction for pipe ALU [15:8] 
    r2dp:entity work.ram32x32dp
    generic map (init_file => "./init_ram_2.mif")
    port map 
    (

        --AXI interface
        axi_clock => ACLK,
        we =>we_r2,
        axi_addr => address(6 downto 2), 
        axi_data_in => s_axi_in.AXI_WDATA,
        axi_data_out => read_from_ram2,

        -- AXIS interface
        clock => ACLK,
        addr     => match_addr_tcam2,
        data_out => flow_state_tcam2
    );

    --this ram provides the 3 actions to apply to the packet [15:0] for table update, [23:16] push/modify pkt, [31:24] select dst_if
    r3dp:entity work.ram32x32dp
    generic map (init_file => "./init_ram_3.mif")
    port map 
    (

        --AXI interface
        axi_clock => ACLK,
        we =>we_r3,
        axi_addr => address(6 downto 2), 
        axi_data_in => s_axi_in.AXI_WDATA,
        axi_data_out => read_from_ram3,

        -- AXIS interface
        clock => ACLK,
        addr     => match_addr_tcam2,
        data_out => action
    );

    --this ram provides the action values to apply to the packet
    r4dp:entity work.ram32x32dp
    generic map (init_file => "./init_ram_4.mif")
    port map 
    (

        --AXI interface
        axi_clock => ACLK,
        we =>we_r4,
        axi_addr => address(6 downto 2), 
        axi_data_in => s_axi_in.AXI_WDATA,
        axi_data_out => read_from_ram4,

        -- AXIS interface
        clock => ACLK,
        addr     => match_addr_tcam2,
        data_out => action_value
    );

    --SAM1a: entity work.sam32 port map(full_header_d(X),OFF1_I1,"11",OPa_I1);
    --SAM1b: entity work.sam32 port map(full_header_d(X),OFF2_I1,"11",OPb_I1);
    --ALU1:  entity work.alu port map(OPa_I1,OPb_I1,Opcode_I1,Res1);

    --N.B.: controllare se prende i valori giusti di R1,R2,R3

    --Res1 <= R1dd+flow_state_tcam2(15 downto 8);
    --Res2 <= R2dd+flow_state_tcam2(23 downto 16);
    --Res3 <= R3dd+flow_state_tcam2(31 downto 24);

    -- latency= 2 CLK
    --Res3(31 downto 24)<=x"00";
    --d0: entity work.div_gen_0 port map (CLK,'1',R1dd(7 downto 0),'1',R2dd(15 downto 0),open,Res3(23 downto 0));


    Pipealu_i: entity work.pipealu port map(
                                               clk   => ACLK,
                                               reset => RESET,
                                               wea   => we_pipealu, --: IN STD_LOGIC;
                                               addra => address(13 downto 2), --: IN STD_LOGIC_VECTOR(11 DOWNTO 0);
                                               dina => s_axi_in.AXI_WDATA, -- : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
                                               pipe_enable   => '1',
                                               header => full_header_d(6), --: in std_logic_vector(367 downto 0); --3 --4 --5
                                               instruction => flow_state_tcam2(15 downto 8),  --: in std_logic_vector(7 downto 0);
                                               inGR0 => GR0,
                                               inGR1 => GR1,
                                               inGR2 => GR2,
                                               inGR3 => GR3,
                                                                                              
                                               GR0 => aluGR0,
                                               GR1 => aluGR1,
                                               GR2 => aluGR2,
                                               GR3 => aluGR3,
--                                               GR4 => aluGR4,
--                                               GR5 => aluGR5,
--                                               GR6 => aluGR6,
--                                               GR7 => aluGR7,
--                                               GR8 => aluGR8,
--                                               GR9 => aluGR9,
--                                               GR10 => aluGR10,
--                                               GR11 => aluGR11,
--                                               GR12 => aluGR12,
--                                               GR13 => aluGR13,
--                                               GR14 => aluGR14,
--                                               GR15 => aluGR15,
                                               Rina => R1ddd,-- : in STD_LOGIC_VECTOR (31 downto 0); --R1dd
                                               Rinb => R2ddd,-- : in STD_LOGIC_VECTOR (31 downto 0); --R2dd
                                               Rinc => R3ddd,-- : in STD_LOGIC_VECTOR (31 downto 0); --R3dd
                                               Res3a => Res1, --: out STD_LOGIC_VECTOR (31 downto 0);
                                               Res3b => Res2, --: out STD_LOGIC_VECTOR (31 downto 0);
                                               Res3c => Res3  --: out STD_LOGIC_VECTOR (31 downto 0);
     --Res3d : out STD_LOGIC_VECTOR (31 downto 0)
                                           );




    



-- ----------------------------------------------------------------------------
--                              Feedback for HT 
-- ----------------------------------------------------------------------------

    sh4:  entity work.shrege generic map (5,32) port map (ACLK,'1',flow_state_tcam2,flow_state_tcam2_d3); --sync con startd(8) --5       -----7
    insert_action <= startd(10) when action_d3(15 downto 0)= x"FF00" else '0';  --sync con Res3 .. Res1  --9
    remove_action <= startd(10) when action_d3(15 downto 0)= x"FFFF"  else '0'; --sync con Res3 .. Res1 --9
    SAMus1: entity work.sam64 port map(full_header_d(10),update_scope(5 downto 0),action_header(63 downto 0)); --8 --9   --11
    SAMus2: entity work.sam64 port map(full_header_d(10),update_scope(21 downto 16),action_header(127 downto 64)); -- --9 --11
    update_key <= action_header and mask_update;
    update_context(95 downto 0) <=  Res3 & Res2 & Res1;
    --set the next state
    update_context(103 downto 96) <=  flow_state_tcam2_d3(7 downto 0); 
    update_context(125 downto 104) <= (others => '0');


-- ----------------------------------------------------------------------------
--                              ACTIONS 
-- ----------------------------------------------------------------------------

    sh2:  entity work.shrege generic map (5,32) port map (ACLK,'1',action,action_d3); --sync con startd(8) 
    sh3:  entity work.shrege generic map (5,32) port map (ACLK,'1',action_value,action_value_d3); --sync con startd(8)



--    enable_modify <='1'  when ((startd(10)='1') and (action_d3(23 downto 16)=x"0B")) else --8 
--                    '1'  when ((startd(10)='1') and (action_d3(23 downto 16)=x"1B")) else --8
--                    '1'  when ((startd(10)='1') and (action_d3(23 downto 16)=x"2B")) else --8
--                    '1'  when ((startd(10)='1') and (action_d3(23 downto 16)=x"3B")) else  --8
--                    '0'; 
                    
    enable_modify <='1'  when ((startd(10)='1') and (action_d3(19 downto 16)=x"A")) else --8 
                    '1'  when ((startd(10)='1') and (action_d3(19 downto 16)=x"B")) else --8
                    '1'  when ((startd(10)='1') and (action_d3(19 downto 16)=x"C")) else --8
                    '1'  when ((startd(10)='1') and (action_d3(19 downto 16)=x"D")) else  --8
                    '0';
                   
    modify_offset<=action_value_d3(13 downto 0);
    modify_size<=action_value_d3(15 downto 14);
--    modify_field<=x"0000" & action_value_d3(31 downto 16) when action_d3(23 downto 16)=x"0" else  
--                  Res1 when action_d3(23 downto 20)=x"1" else
--                  Res2 when action_d3(23 downto 20)=x"2" else
--                  Res3;
    modify_field<=x"0000" & action_value_d3(31 downto 16) when (action_d3(23 downto 16)=x"0B" or action_d3(23 downto 16)=x"0C" or action_d3(23 downto 16)=x"0D") else  
                   action_value_d3(23 downto 16)&action_value_d3(31 downto 24) & x"0081"  when action_d3(23 downto 16)=x"0A" else
                  Res1 when action_d3(23 downto 20)=x"1" else
                  Res2 when action_d3(23 downto 20)=x"2" else
                  Res3;
                                    

output_fifo_i: fallthrough_small_fifo
generic map (
           WIDTH => (1+256+32+128),
           MAX_DEPTH_BITS => 9,
           PROG_FULL_THRESHOLD => 448 -- 512x32B-64x32B
           )
port map
        (
         -- Outputs
         dout                           => fifo_out,
         --full                           
         --nearly_full                    
 	     prog_full                      => nearly_full_fifo,
         empty                          => empty_fifo,
         -- Inputs                
         -- Slave Stream ports.
         din(416)                       => S0_AXIS.TLAST,
         din(415 downto 160)            => S0_AXIS.TDATA,
         din(159 downto 128)            => S0_AXIS.TKEEP,
         din(127 downto 0)              => S0_AXIS.TUSER,
         
                                   
         wr_en                          => wr_en,
         rd_en                          => rd_en,
         clk                            => ACLK,
         reset                          => RESET
        );



-- process to enqueue
S0_AXIS_TREADY <= not nearly_full_fifo when ((curr_state /= WAIT5) and (pause = x"00000000")) else '0';
wr_en  <= (S0_AXIS.TVALID and not nearly_full_fifo) when ((curr_state /= WAIT5) and (pause = x"00000000")) else '0'; 


command_fifo_i:  fallthrough_small_fifo
generic map (
           WIDTH => (8+1+14+2+32+8),
           MAX_DEPTH_BITS => 5
--           PROG_FULL_THRESHOLD => BUFFER_THRESHOLD
           )
port map
        (
         --Outputs
         dout                          => fifo_out_command,
         --full                           (),
         --nearly_full                   => command_full_fifo,
 	 --prog_full                      (),
         empty                         => command_empty,
         -- Inputs
         din(64 downto 49)             => action_d3(31 downto 16),
         din(48)                       => enable_modify,
         din(47 downto 34)             => modify_offset,
         din(33 downto 32)             => modify_size,
         din(31 downto 0)              => modify_field,  

         wr_en                         => startd(10), --8 --
         rd_en                         => command_rd_en,
         clk                           => ACLK,
         reset                         => RESET
     );


-- process to dequeue
  process(dedue_state,dedue_state_next,command_empty,empty_fifo,fifo_out)
    begin
        command_rd_en <='0';
        rd_en <='0';
        dedue_state_next<= dedue_state;
    case dedue_state is
    when IDLE => 
         if ((command_empty='0') and (empty_fifo='0') and write_TREADY='1') then
		command_rd_en <='1';
		rd_en <='1';
                dedue_state_next<= WAIT_EOP;
         end if;
    when WAIT_EOP => 
         if ((empty_fifo='0') and write_TREADY='1') then
		rd_en <='1';
         end if;
         --if ((fifo_out.TLAST='1') and (empty_fifo='0') and write_TREADY='1') then
         if ((fifo_out(416)='1') and (empty_fifo='0') and write_TREADY='1') then
                dedue_state_next<= IDLE;
         end if;
    end case;
  end process;

                                    
process(ACLK)
    begin
        if (ACLK'event and ACLK = '1') then
            if (ARESETN = '0') then
                dedue_state <= IDLE;
            else              
	        dedue_state <= dedue_state_next;
            end if;
        end if;
   end process;


       modify_in.TVALID <= rd_en;
       modify_in.TDATA  <= fifo_out(415 downto 160);
       modify_in.TKEEP  <= fifo_out(159 downto 128);
       modify_in.TLAST  <= fifo_out(416);
                           -- TUSER [127:120] -- TUSER [119:88] --TUSER [87:32] -- TUSER [31:24] -- TUSER [23:0] 
       modify_in.TUSER  <= fifo_out_command(56 downto 49) & fifo_out_command(31 downto 0) & fifo_out(87 downto 32) & fifo_out_command(64 downto 57) &  fifo_out(23 downto 0)  when reg_test0=x"00000000" else 
                           fifo_out(127 downto 32) & reg_test0(7 downto 0) & fifo_out(23 downto 0); 

       write_TREADY     <= modify_in_TREADY or write_in_TREADY or del_in_TREADY;



    
------------------------------
--- azioni oper il pacchetto
------------------------------

    --writer_i: entity work.modify_field
    modify_i: entity work.modify_field
    port map (
		    -- Global ports
		    axis_aclk     => ACLK   ,
		    axis_resetn   => ARESETN,

		    in_offset	  => fifo_out_command(47 downto 34),
		    in_size       => fifo_out_command(33 downto 32),
		    in_field      => fifo_out_command(31 downto 0),
		    enable        => fifo_out_command(48),
		    -- Slave Stream ports.
		    s_axis        => modify_in,
		    s_axis_tready => modify_in_TREADY,  

		    -- Master Stream ports.
		    m_axis        => modify_out,
		    m_axis_tready => modify_out_TREADY
	     );


enable_remover<= '1' when (configuration_register(1)='0' and fifo_out_command(52 downto 49)=x"C" and fifo_out_command(48)='1') else '0';


	  rm_field_i: entity work.del_field
      port map (
              -- Global ports
              axis_aclk     => ACLK   ,
              axis_resetn   => ARESETN,
    
              in_offset      => fifo_out_command(47 downto 34),
              in_size       => fifo_out_command(33 downto 32),
              --in_field      => fifo_out_command(31 downto 0),
              enable        => enable_remover, --fifo_out_command(48),
              -- Slave Stream ports.
              s_axis        => modify_in,
              s_axis_tready => del_in_TREADY,  
    
              -- Master Stream ports.
              m_axis        => del_out,
              m_axis_tready => modify_out_TREADY
           );

	  add_field_i: entity work.add_field
           port map (
                   -- Global ports
                   axis_aclk     => ACLK   ,
                   axis_resetn   => ARESETN,
       
                   in_offset     => fifo_out_command(47 downto 34),
                   in_size       => fifo_out_command(33 downto 32),
                   in_field      => fifo_out_command(31 downto 0),
                   enable        => fifo_out_command(48),
                   -- Slave Stream ports.
                   s_axis        => modify_in,
                   s_axis_tready => write_in_TREADY,  
       
                   -- Master Stream ports.
                   m_axis        => write_out,
                   m_axis_tready => modify_out_TREADY
                );
            


vlan_axis_in <= write_out  when fifo_out_command(52 downto 49)=x"A" else
           del_out    when fifo_out_command(52 downto 49)=x"C" else
           modify_out;


vl1: vlan_remover_ip  
port map (
    axis_aclk => ACLK,
    axis_resetn =>  ARESETN,

    enable        => '1',

    -- Slave Stream Ports (interface to data path)
    s_axis_tdata => vlan_axis_in.TDATA,
    s_axis_tkeep => vlan_axis_in.TKEEP,
    s_axis_tuser => vlan_axis_in.TUSER,
    s_axis_tvalid  => vlan_axis_in.TVALID,
    s_axis_tready  => modify_out_TREADY,
    s_axis_tlast => vlan_axis_in.TLAST,

    -- Master Stream Ports (interface to TX queues)
    m_axis_tdata => v2v.TDATA,
    m_axis_tkeep => v2v.TKEEP,
    m_axis_tuser => v2v.TUSER,
    m_axis_tvalid => v2v.TVALID,
    m_axis_tready => v2v_TREADY,
    m_axis_tlast  => v2v.TLAST
);


vl2: vlan_modder_ip  
port map (
    axis_aclk => ACLK,
    axis_resetn =>  ARESETN,

    --enable        => '1',

    -- Slave Stream Ports (interface to data path)
    s_axis_tdata => v2v.TDATA,
    s_axis_tkeep => v2v.TKEEP,
    s_axis_tuser => v2v.TUSER,
    s_axis_tvalid  => v2v.TVALID,
    s_axis_tready  => v2v_TREADY,
    s_axis_tlast => v2v.TLAST,

    -- Master Stream Ports (interface to TX queues)
    m_axis_tdata => v2v2.TDATA,
    m_axis_tkeep => v2v2.TKEEP,
    m_axis_tuser => v2v2.TUSER,
    m_axis_tvalid => v2v2.TVALID,
    m_axis_tready => v2v2_TREADY,
    m_axis_tlast  => v2v2.TLAST
);

vl3: vlan_adder_ip  
port map (
    axis_aclk => ACLK,
    axis_resetn =>  ARESETN,

    --enable        => '1',

    -- Slave Stream Ports (interface to data path)
    s_axis_tdata => v2v2.TDATA,
    s_axis_tkeep => v2v2.TKEEP,
    s_axis_tuser => v2v2.TUSER,
    s_axis_tvalid  => v2v2.TVALID,
    s_axis_tready  => v2v2_TREADY,
    s_axis_tlast => v2v2.TLAST,

    -- Master Stream Ports (interface to TX queues)
    m_axis_tdata => vlan_axis_out.TDATA,
    m_axis_tkeep => vlan_axis_out.TKEEP,
    m_axis_tuser => vlan_axis_out.TUSER,
    m_axis_tvalid => vlan_axis_out.TVALID,
    m_axis_tready => M0_AXIS_TREADY,
    m_axis_tlast  => vlan_axis_out.TLAST
);


M0_AXIS <= vlan_axis_out;

                 
--process(ACLK)
--    begin
--        if (ACLK'event and ACLK = '1') then
--            if (ARESETN = '0') then
--                out_field <= MODIFY;
--            else
--                if ((fifo_out_command(48)='1')and (fifo_out_command(52 downto 49)=x"A")) then
--                      out_field <= WRITE;
--                elsif ((fifo_out_command(48)='1')and (fifo_out_command(52 downto 49)=x"B")) then
--                      out_field <= MODIFY;
--                elsif ((fifo_out_command(48)='1')and (fifo_out_command(52 downto 49)=x"C")) then
--                      out_field <= DELETE;
--                else
--                      null;
--                end if;
--            end if;
--        end if;
--   end process;


--M0_AXIS <= write_out   when (fifo_out_command(52 downto 49)=x"A" and fifo_out_command(48)='1') else
--           modify_out  when (fifo_out_command(52 downto 49)=x"B" and fifo_out_command(48)='1') else
--           del_out     when (fifo_out_command(52 downto 49)=x"C" and fifo_out_command(48)='1') else
--           write_out   when (out_field=WRITE) else
--           modify_out  when (out_field=MODIFY) else
--           del_out     when (out_field=DELETE) else
--           modify_out  ;

--modify_out_TREADY <= M0_AXIS_TREADY;


----------------------------------------------------------------
---                      ILA
----------------------------------------------------------------


ila_gen_i: if IN_SYNTHESIS generate
ila_i: ila_0 port map(
    CLK => ACLK,
    PROBE0 => write_out.TDATA, --256
    PROBE1 => vlan_axis_in.TDATA, --256
    PROBE2 => (others =>'0'), --32
    PROBE3 => action_d3, --32
    PROBE4 => fifo_out_command(31 downto 0), --32
    PROBE5(15 downto 0) => fifo_out_command(64 downto 49), --32
    PROBE5(31 downto 16) =>   (others =>'0'), --32
    PROBE6 => fifo_out(31 downto 0), --32, --32
    PROBE7 => (others =>'0'), --32
    PROBE8 => write_out.TLAST, --1
    PROBE9 => vlan_axis_in.TLAST, --1
    PROBE10 => fifo_out_command(56), --1
    PROBE11 => command_rd_en --1
);

end generate;


end architecture full;

