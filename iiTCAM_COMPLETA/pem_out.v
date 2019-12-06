////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2015 ; The University of British Columbia ; All rights reserved. //
//                                                                                //
// Redistribution  and  use  in  source   and  binary  forms,   with  or  without //
// modification,  are permitted  provided that  the following conditions are met: //
//   * Redistributions   of  source   code  must  retain   the   above  copyright //
//     notice,  this   list   of   conditions   and   the  following  disclaimer. //
//   * Redistributions  in  binary  form  must  reproduce  the  above   copyright //
//     notice, this  list  of  conditions  and the  following  disclaimer in  the //
//     documentation and/or  other  materials  provided  with  the  distribution. //
//   * Neither the name of the University of British Columbia (UBC) nor the names //
//     of   its   contributors  may  be  used  to  endorse  or   promote products //
//     derived from  this  software without  specific  prior  written permission. //
//                                                                                //
// THIS  SOFTWARE IS  PROVIDED  BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" //
// AND  ANY EXPRESS  OR IMPLIED WARRANTIES,  INCLUDING,  BUT NOT LIMITED TO,  THE //
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE //
// DISCLAIMED.  IN NO  EVENT SHALL University of British Columbia (UBC) BE LIABLE //
// FOR ANY DIRECT,  INDIRECT,  INCIDENTAL,  SPECIAL,  EXEMPLARY, OR CONSEQUENTIAL //
// DAMAGES  (INCLUDING,  BUT NOT LIMITED TO,  PROCUREMENT OF  SUBSTITUTE GOODS OR //
// SERVICES;  LOSS OF USE,  DATA,  OR PROFITS;  OR BUSINESS INTERRUPTION) HOWEVER //
// CAUSED AND ON ANY THEORY OF LIABILITY,  WHETHER IN CONTRACT, STRICT LIABILITY, //
// OR TORT  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE //
// OF  THIS SOFTWARE,  EVEN  IF  ADVISED  OF  THE  POSSIBILITY  OF  SUCH  DAMAGE. //
////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////
//    pem_out: Recursive priority encoder match (PEM); Automatically generated   //
//                                                                                //
//   Author: Ameer M.S. Abdelhadi (ameer@ece.ubc.ca; ameer.abdelhadi@gmail.com)   //
//   BRAM-based II-TCAM ; The University of British Columbia (UBC) ;  Dec. 2015   //
////////////////////////////////////////////////////////////////////////////////////

// pem4_out: 4-bit priority encoder match sub-module; Automatically generated
module pem4_out(input clk, input rst, input [4-1:0] oht, output [2-1:0] bin, output vld);
  assign {bin,vld} = {!(oht[0]||oht[1]),!oht[0]&&(oht[1]||!oht[2]),|oht};
endmodule
// pem16_out: 16-bit priority encoder match sub-module; Automatically generated
module pem16_out(input clk, input rst, input [16-1:0] oht, output [4-1:0] bin, output vld);
  // recursive calls for four narrower (fourth the inout width) priority encoders
  wire [4-3:0] binI[3:0];
  wire [   3:0] vldI     ;
  pem4_out pem4_out_in0(clk, rst, oht[  16/4-1:0        ],binI[0],vldI[0]);
  pem4_out pem4_out_in1(clk, rst, oht[  16/2-1:  16/4 ],binI[1],vldI[1]);
  pem4_out pem4_out_in2(clk, rst, oht[3*16/4-1:  16/2 ],binI[2],vldI[2]);
  pem4_out pem4_out_in3(clk, rst, oht[  16  -1:3*16/4 ],binI[3],vldI[3]);
  // register input priority encoders outputs if pipelining is required; otherwise assign only
  wire [4-3:0] binII[3:0];
  wire [   3:0] vldII     ;
  assign {binII[3],binII[2],binII[1],binII[0],vldII} = {binI[3],binI[2],binI[1],binI[0],vldI};
  // output pem4 to generate indices from valid bits
  pem4_out pem4_out_out0(clk,rst,vldII,bin[4-1:4-2],vld);
  // a 4->1 mux to steer indices from the narrower pe's
  reg [4-3:0] binO;
  always @(*)
    case (bin[4-1:4-2])
      2'b00: binO = binII[0];
      2'b01: binO = binII[1];
      2'b10: binO = binII[2];
      2'b11: binO = binII[3];
  endcase
  assign bin[4-3:0] = binO;
endmodule
// pem64_out: 64-bit priority encoder match sub-module; Automatically generated
module pem64_out(input clk, input rst, input [64-1:0] oht, output [6-1:0] bin, output vld);
  // recursive calls for four narrower (fourth the inout width) priority encoders
  wire [6-3:0] binI[3:0];
  wire [   3:0] vldI     ;
  pem16_out pem16_out_in0(clk, rst, oht[  64/4-1:0        ],binI[0],vldI[0]);
  pem16_out pem16_out_in1(clk, rst, oht[  64/2-1:  64/4 ],binI[1],vldI[1]);
  pem16_out pem16_out_in2(clk, rst, oht[3*64/4-1:  64/2 ],binI[2],vldI[2]);
  pem16_out pem16_out_in3(clk, rst, oht[  64  -1:3*64/4 ],binI[3],vldI[3]);
  // register input priority encoders outputs if pipelining is required; otherwise assign only
  wire [6-3:0] binII[3:0];
  wire [   3:0] vldII     ;
  assign {binII[3],binII[2],binII[1],binII[0],vldII} = {binI[3],binI[2],binI[1],binI[0],vldI};
  // output pem4 to generate indices from valid bits
  pem4_out pem4_out_out0(clk,rst,vldII,bin[6-1:6-2],vld);
  // a 4->1 mux to steer indices from the narrower pe's
  reg [6-3:0] binO;
  always @(*)
    case (bin[6-1:6-2])
      2'b00: binO = binII[0];
      2'b01: binO = binII[1];
      2'b10: binO = binII[2];
      2'b11: binO = binII[3];
  endcase
  assign bin[6-3:0] = binO;
endmodule
// pem256_out: 256-bit priority encoder match sub-module; Automatically generated
module pem256_out(input clk, input rst, input [256-1:0] oht, output [8-1:0] bin, output vld);
  // recursive calls for four narrower (fourth the inout width) priority encoders
  wire [8-3:0] binI[3:0];
  wire [   3:0] vldI     ;
  pem64_out pem64_out_in0(clk, rst, oht[  256/4-1:0        ],binI[0],vldI[0]);
  pem64_out pem64_out_in1(clk, rst, oht[  256/2-1:  256/4 ],binI[1],vldI[1]);
  pem64_out pem64_out_in2(clk, rst, oht[3*256/4-1:  256/2 ],binI[2],vldI[2]);
  pem64_out pem64_out_in3(clk, rst, oht[  256  -1:3*256/4 ],binI[3],vldI[3]);
  // register input priority encoders outputs if pipelining is required; otherwise assign only
  wire [8-3:0] binII[3:0];
  wire [   3:0] vldII     ;
  assign {binII[3],binII[2],binII[1],binII[0],vldII} = {binI[3],binI[2],binI[1],binI[0],vldI};
  // output pem4 to generate indices from valid bits
  pem4_out pem4_out_out0(clk,rst,vldII,bin[8-1:8-2],vld);
  // a 4->1 mux to steer indices from the narrower pe's
  reg [8-3:0] binO;
  always @(*)
    case (bin[8-1:8-2])
      2'b00: binO = binII[0];
      2'b01: binO = binII[1];
      2'b10: binO = binII[2];
      2'b11: binO = binII[3];
  endcase
  assign bin[8-3:0] = binO;
endmodule
// pem1024_out: 1024-bit priority encoder match sub-module; Automatically generated
module pem1024_out(input clk, input rst, input [1024-1:0] oht, output [10-1:0] bin, output vld);
  // recursive calls for four narrower (fourth the inout width) priority encoders
  wire [10-3:0] binI[3:0];
  wire [   3:0] vldI     ;
  pem256_out pem256_out_in0(clk, rst, oht[  1024/4-1:0        ],binI[0],vldI[0]);
  pem256_out pem256_out_in1(clk, rst, oht[  1024/2-1:  1024/4 ],binI[1],vldI[1]);
  pem256_out pem256_out_in2(clk, rst, oht[3*1024/4-1:  1024/2 ],binI[2],vldI[2]);
  pem256_out pem256_out_in3(clk, rst, oht[  1024  -1:3*1024/4 ],binI[3],vldI[3]);
  // register input priority encoders outputs if pipelining is required; otherwise assign only
  wire [10-3:0] binII[3:0];
  wire [   3:0] vldII     ;
  assign {binII[3],binII[2],binII[1],binII[0],vldII} = {binI[3],binI[2],binI[1],binI[0],vldI};
  // output pem4 to generate indices from valid bits
  pem4_out pem4_out_out0(clk,rst,vldII,bin[10-1:10-2],vld);
  // a 4->1 mux to steer indices from the narrower pe's
  reg [10-3:0] binO;
  always @(*)
    case (bin[10-1:10-2])
      2'b00: binO = binII[0];
      2'b01: binO = binII[1];
      2'b10: binO = binII[2];
      2'b11: binO = binII[3];
  endcase
  assign bin[10-3:0] = binO;
endmodule
// pem4096_out: 4096-bit priority encoder match sub-module; Automatically generated
module pem4096_out(input clk, input rst, input [4096-1:0] oht, output [12-1:0] bin, output vld);
  // recursive calls for four narrower (fourth the inout width) priority encoders
  wire [12-3:0] binI[3:0];
  wire [   3:0] vldI     ;
  pem1024_out pem1024_out_in0(clk, rst, oht[  4096/4-1:0        ],binI[0],vldI[0]);
  pem1024_out pem1024_out_in1(clk, rst, oht[  4096/2-1:  4096/4 ],binI[1],vldI[1]);
  pem1024_out pem1024_out_in2(clk, rst, oht[3*4096/4-1:  4096/2 ],binI[2],vldI[2]);
  pem1024_out pem1024_out_in3(clk, rst, oht[  4096  -1:3*4096/4 ],binI[3],vldI[3]);
  // register input priority encoders outputs if pipelining is required; otherwise assign only
  wire [12-3:0] binII[3:0];
  wire [   3:0] vldII     ;
  assign {binII[3],binII[2],binII[1],binII[0],vldII} = {binI[3],binI[2],binI[1],binI[0],vldI};
  // output pem4 to generate indices from valid bits
  pem4_out pem4_out_out0(clk,rst,vldII,bin[12-1:12-2],vld);
  // a 4->1 mux to steer indices from the narrower pe's
  reg [12-3:0] binO;
  always @(*)
    case (bin[12-1:12-2])
      2'b00: binO = binII[0];
      2'b01: binO = binII[1];
      2'b10: binO = binII[2];
      2'b11: binO = binII[3];
  endcase
  assign bin[12-3:0] = binO;
endmodule
// pem16384_out: 16384-bit priority encoder match sub-module; Automatically generated
module pem16384_out(input clk, input rst, input [16384-1:0] oht, output [14-1:0] bin, output vld);
  // recursive calls for four narrower (fourth the inout width) priority encoders
  wire [14-3:0] binI[3:0];
  wire [   3:0] vldI     ;
  pem4096_out pem4096_out_in0(clk, rst, oht[  16384/4-1:0        ],binI[0],vldI[0]);
  pem4096_out pem4096_out_in1(clk, rst, oht[  16384/2-1:  16384/4 ],binI[1],vldI[1]);
  pem4096_out pem4096_out_in2(clk, rst, oht[3*16384/4-1:  16384/2 ],binI[2],vldI[2]);
  pem4096_out pem4096_out_in3(clk, rst, oht[  16384  -1:3*16384/4 ],binI[3],vldI[3]);
  // register input priority encoders outputs if pipelining is required; otherwise assign only
  wire [14-3:0] binII[3:0];
  wire [   3:0] vldII     ;
  assign {binII[3],binII[2],binII[1],binII[0],vldII} = {binI[3],binI[2],binI[1],binI[0],vldI};
  // output pem4 to generate indices from valid bits
  pem4_out pem4_out_out0(clk,rst,vldII,bin[14-1:14-2],vld);
  // a 4->1 mux to steer indices from the narrower pe's
  reg [14-3:0] binO;
  always @(*)
    case (bin[14-1:14-2])
      2'b00: binO = binII[0];
      2'b01: binO = binII[1];
      2'b10: binO = binII[2];
      2'b11: binO = binII[3];
  endcase
  assign bin[14-3:0] = binO;
endmodule
// pem_out.v: priority encoder top module file; Automatically generated
module pem_out(input clk, input rst, input [8192-1:0] oht, output [13-1:0] bin, output vld);
  wire [8192-1:0] ohtR = oht;
  wire [13-1:0] binII;
  wire          vldI ;
  // instantiate peiority encoder
  wire [16384-1:0] ohtI = {{(16384-8192){1'b0}},ohtR};
  wire [14-1:0] binI ;
  pem16384_out pem16384_out_0(clk,rst,ohtI,binI,vldI);
  assign binII = binI[13-1:0];
  assign {bin,vld} = {binII ,vldI };
endmodule