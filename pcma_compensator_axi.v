`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:  eea
// 
// Create Date: 16.12.2019 18:21:09
// Design Name: 
// Module Name: 		llr_former_axi
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//	Обвязка LLR_Former-а для управление по AXI
//
//
//////////////////////////////////////////////////////////////////////////////////

import math_pkg::*;


module pcma_compensator_axi	#(
	
	parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 7,
	
	
	parameter IN_D_WIDTH     = 10,
	parameter OUT_D_WIDTH    = 16,
	parameter COE_WIDTH      = 16,
	parameter INV_COE_WIDTH  = 8,
    parameter FULL_COE_WIDTH = COE_WIDTH + INV_COE_WIDTH,
	parameter EQ_LEN		 = 19
	
	parameter DEBUG       	 = 1    				//ILA Enable
)(

//-----------------------AXI_INTERFACE-----------------------
    input 	wire 								S_AXI_ACLK,
    input 	wire 								S_AXI_ARESETN,
    input 	wire [C_S_AXI_ADDR_WIDTH-1:0] 		S_AXI_AWADDR,
    input 	wire [2:0] 							S_AXI_AWPROT,
    input 	wire 								S_AXI_AWVALID,
    output 	wire 								S_AXI_AWREADY,
    input 	wire [C_S_AXI_DATA_WIDTH-1:0] 		S_AXI_WDATA,
    input 	wire [(C_S_AXI_DATA_WIDTH/8)-1:0]	S_AXI_WSTRB,
    input 	wire 								S_AXI_WVALID,
    output 	wire 								S_AXI_WREADY,
    output 	wire [1:0] 							S_AXI_BRESP,
    output 	wire 								S_AXI_BVALID,
    input 	wire  								S_AXI_BREADY,
    input 	wire [C_S_AXI_ADDR_WIDTH-1:0] 		S_AXI_ARADDR,
    input 	wire [2:0] 							S_AXI_ARPROT,
    input 	wire 								S_AXI_ARVALID,
    output 	wire 								S_AXI_ARREADY,
    output 	wire [C_S_AXI_DATA_WIDTH-1:0] 		S_AXI_RDATA,
    output 	wire [1:0]							S_AXI_RRESP,
    output 	wire 								S_AXI_RVALID,
    input 	wire 								S_AXI_RREADY,

//-----------------------MY_BLOCK_INTERFACE-----------------------	

	input                       clk,
	input                       reset_n,	
	
	input  [IN_D_WIDTH-1    :0] i_data_I,
	input  [IN_D_WIDTH-1    :0] i_data_Q,
	input                       i_iq_val,    
    
    input                       i_preset_coe,   //!!!
    input                       i_load_coe,
	input  [FULL_COE_WIDTH-1:0] i_init_coe,

	output [OUT_D_WIDTH-1   :0]	o_dout_I,
	output [OUT_D_WIDTH-1   :0]	o_dout_Q,
    output                      o_vld
);
	
	
	
// ---------------------------------------------------------
// ------------------ RESET RESYNC INSTANCES ---------------
// ---------------------------------------------------------

reg  [C_S_AXI_DATA_WIDTH-1 : 0]	reset_reg;
reg                             resync_reset_n;


always(posedge clk) begin
    resync_reset_n <= reset_n & ~reset_reg[0];  // Общий сброс или через cypress
end


	
/****************************************************************/
/*                      axi_clock_converter                     */
/****************************************************************/
wire 			s_axi_aclk_cc;
wire 			s_axi_aresetn_cc;
wire [C_S_AXI_ADDR_WIDTH-1:0] 	s_axi_awaddr_cc;
wire [2 : 0] 	s_axi_awprot_cc;
wire 			s_axi_awvalid_cc;
wire 			s_axi_awready_cc;
wire [31 : 0] 	s_axi_wdata_cc;
wire [3 : 0] 	s_axi_wstrb_cc;
wire 			s_axi_wvalid_cc;
wire 			s_axi_wready_cc;
wire [1 : 0] 	s_axi_bresp_cc;
wire 			s_axi_bvalid_cc;
wire 			s_axi_bready_cc;
wire [C_S_AXI_ADDR_WIDTH-1:0] 	s_axi_araddr_cc;
wire [2 : 0] 	s_axi_arprot_cc;
wire 			s_axi_arvalid_cc;
wire 			s_axi_arready_cc;
wire [31 : 0] 	s_axi_rdata_cc;
wire [1 : 0] 	s_axi_rresp_cc;
wire 			s_axi_rvalid_cc;
wire 			s_axi_rready_cc;


ff_sync 	ff_sync_s_axi_aresetn_inst_0 (
  .i_clka(S_AXI_ACLK),      	// input wire i_clka
  .i_clkb(i_clk),      			// input wire i_clkb
  .i_siga(S_AXI_ARESETN),  		// input wire [0 : 0] i_strobe
  .o_sigb(s_axi_aresetn_cc)  	// output wire [0 : 0] o_strobe
);
assign s_axi_aclk_cc = clk;


axi_clock_converter_0 		axi_clock_converter_llr_former_axi_inst (
  .s_axi_aclk   (S_AXI_ACLK	  ),        // input  wire s_axi_aclk
  .s_axi_aresetn(S_AXI_ARESETN),  // input  wire s_axi_aresetn
  .s_axi_awaddr (S_AXI_AWADDR ),    // input  wire [31 : 0] s_axi_awaddr
  .s_axi_awprot (S_AXI_AWPROT ),    // input  wire [2 : 0] s_axi_awprot
  .s_axi_awvalid(S_AXI_AWVALID),  // input  wire s_axi_awvalid
  .s_axi_awready(S_AXI_AWREADY),  // output wire s_axi_awready
  .s_axi_wdata  (S_AXI_WDATA  ),      // input  wire [31 : 0] s_axi_wdata
  .s_axi_wstrb  (S_AXI_WSTRB  ),      // input  wire [3 : 0] s_axi_wstrb
  .s_axi_wvalid (S_AXI_WVALID ),    // input  wire s_axi_wvalid
  .s_axi_wready (S_AXI_WREADY ),    // output wire s_axi_wready
  .s_axi_bresp  (S_AXI_BRESP  ),      // output wire [1 : 0] s_axi_bresp
  .s_axi_bvalid (S_AXI_BVALID ),    // output wire s_axi_bvalid
  .s_axi_bready (S_AXI_BREADY ),    // input  wire s_axi_bready
  .s_axi_araddr (S_AXI_ARADDR ),    // input  wire [31 : 0] s_axi_araddr
  .s_axi_arprot (S_AXI_ARPROT ),    // input  wire [2 : 0] s_axi_arprot
  .s_axi_arvalid(S_AXI_ARVALID),  // input  wire s_axi_arvalid
  .s_axi_arready(S_AXI_ARREADY),  // output wire s_axi_arready
  .s_axi_rdata  (S_AXI_RDATA  ),      // output wire [31 : 0] s_axi_rdata
  .s_axi_rresp  (S_AXI_RRESP  ),      // output wire [1 : 0] s_axi_rresp
  .s_axi_rvalid (S_AXI_RVALID ),    // output wire s_axi_rvalid
  .s_axi_rready (S_AXI_RREADY ),    // input  wire s_axi_rready
  
  .m_axi_aclk   (s_axi_aclk_cc   ),        // input  	wire m_axi_aclk
  .m_axi_aresetn(s_axi_aresetn_cc),  // input  		wire m_axi_aresetn
  .m_axi_awaddr (s_axi_awaddr_cc ),    // output 	wire [31 : 0] m_axi_awaddr
  .m_axi_awprot (s_axi_awprot_cc ),    // output 	wire [2 : 0] m_axi_awprot
  .m_axi_awvalid(s_axi_awvalid_cc),  // output 		wire m_axi_awvalid
  .m_axi_awready(s_axi_awready_cc),  // input  		wire m_axi_awready
  .m_axi_wdata  (s_axi_wdata_cc  ),      // output 	wire [31 : 0] m_axi_wdata
  .m_axi_wstrb  (s_axi_wstrb_cc  ),      // output 	wire [3 : 0] m_axi_wstrb
  .m_axi_wvalid (s_axi_wvalid_cc ),    // output 	wire m_axi_wvalid
  .m_axi_wready (s_axi_wready_cc ),    // input  	wire m_axi_wready
  .m_axi_bresp  (s_axi_bresp_cc  ),      // input  	wire [1 : 0] m_axi_bresp
  .m_axi_bvalid (s_axi_bvalid_cc ),    // input  	wire m_axi_bvalid
  .m_axi_bready (s_axi_bready_cc ),    // output 	wire m_axi_bready
  .m_axi_araddr (s_axi_araddr_cc ),    // output 	wire [31 : 0] m_axi_araddr
  .m_axi_arprot (s_axi_arprot_cc ),    // output 	wire [2 : 0] m_axi_arprot
  .m_axi_arvalid(s_axi_arvalid_cc),  // output 		wire m_axi_arvalid
  .m_axi_arready(s_axi_arready_cc),  // input  		wire m_axi_arready
  .m_axi_rdata  (s_axi_rdata_cc  ),      // input  	wire [31 : 0] m_axi_rdata
  .m_axi_rresp  (s_axi_rresp_cc  ),      // input  	wire [1 : 0] m_axi_rresp
  .m_axi_rvalid (s_axi_rvalid_cc ),    // input  	wire m_axi_rvalid
  .m_axi_rready (s_axi_rready_cc )    // output  	wire m_axi_rready
);	

	
// ---------------------------------------------------------
// -------------------- AXI-4 Lite Cover -------------------
// ---------------------------------------------------------
localparam AXI_TOTAL_WR_REGS_NUM  = 4;		//Общее кол-во регистров на запись(все каналы)
localparam AXI_WR_REGS_NUM	   	  = 4;		//Кол-во регистров на запись      (один канал)
localparam AXI_RD_REGS_NUM		  = 0;			//AXI_TOTAL_REGS_NUM - AXI_TOTAL_WR_REGS_NUM;		//кол-во регистров на чтение
localparam AXI_TOTAL_REGS_NUM  	  = AXI_TOTAL_WR_REGS_NUM + AXI_RD_REGS_NUM;		//Общее кол-во регистров 		  (все каналы)


wire [AXI_TOTAL_WR_REGS_NUM * C_S_AXI_DATA_WIDTH - 1	: 0] axi_wr_regs_total;		//общая шина(Wr) из axi_cover - куча
wire [AXI_TOTAL_WR_REGS_NUM	 				     - 1	: 0] axi_wr_regs_valid;		//ОБЩАЯ ШпНА  велидов
//wire [AXI_RD_REGS_NUM		* C_S_AXI_DATA_WIDTH - 1	: 0] axi_rd_regs_common;	//общая шина для считываемых данных




wire [C_S_AXI_DATA_WIDTH-1 : 0] axi_wr_regs	[AXI_TOTAL_WR_REGS_NUM-1 : 0];			//массив 32бит шин для рег записи
//wire [C_S_AXI_DATA_WIDTH-1 : 0]	axi_rd_regs	[AXI_RD_REGS_NUM      -1 : 0];			//массив 32бит шин для рег чтения




//назначение шинам конкретных регистров, конкретных каналов   проводников   из   общей шины(кучи)
//genvar regR_idx;
generate
	for (k = 0;	  k < AXI_TOTAL_WR_REGS_NUM; 	k = k + 1) begin : convert_regs
		assign axi_wr_regs[k][C_S_AXI_DATA_WIDTH-1:0] = axi_wr_regs_total[(k+1)*C_S_AXI_DATA_WIDTH - 1	:	k*C_S_AXI_DATA_WIDTH];
	end
endgenerate



//LLR_Former_cover
axi_cover_pcma_comp #(
    .N_REGS					(AXI_TOTAL_REGS_NUM),		//comm num reg
    .N_WR_REGS				(AXI_TOTAL_WR_REGS_NUM),
    .C_S_AXI_DATA_WIDTH		(C_S_AXI_DATA_WIDTH),
    .C_S_AXI_ADDR_WIDTH 	(C_S_AXI_ADDR_WIDTH)
)
axi_cover_pcma_comp_inst (   
    .wr_reg			(axi_wr_regs_total	),
    .wr_reg_valid	(axi_wr_regs_valid	),
	//.rd_reg			(axi_rd_regs),
	
// Do not modify the ports beyond this line
    .S_AXI_ACLK		(s_axi_aclk_cc		),   					//S_AXI_ACLK					s_axi_aclk_cc							S_AXI_ACLK		
    .S_AXI_ARESETN	(s_axi_aresetn_cc	),                      //S_AXI_ARESETN	                    s_axi_aresetn_cc	                    S_AXI_ARESETN	
    .S_AXI_AWADDR	(s_axi_awaddr_cc	),                      //S_AXI_AWADDR	                    s_axi_awaddr_cc	                        S_AXI_AWADDR	
    .S_AXI_AWPROT	(s_axi_awprot_cc	),                      //S_AXI_AWPROT	                    s_axi_awprot_cc	                        S_AXI_AWPROT	
    .S_AXI_AWVALID	(s_axi_awvalid_cc	),                      //S_AXI_AWVALID	                    s_axi_awvalid_cc	                    S_AXI_AWVALID	
    .S_AXI_AWREADY	(s_axi_awready_cc	),                      //S_AXI_AWREADY	                    s_axi_awready_cc	                    S_AXI_AWREADY	
    .S_AXI_WDATA	(s_axi_wdata_cc		),                      //S_AXI_WDATA	                    s_axi_wdata_cc		                    S_AXI_WDATA	
    .S_AXI_WSTRB	(s_axi_wstrb_cc		),                      //S_AXI_WSTRB	                    s_axi_wstrb_cc		                    S_AXI_WSTRB	
    .S_AXI_WVALID	(s_axi_wvalid_cc	),                      //S_AXI_WVALID	                    s_axi_wvalid_cc	                        S_AXI_WVALID	
    .S_AXI_WREADY	(s_axi_wready_cc	),                      //S_AXI_WREADY	                    s_axi_wready_cc	                        S_AXI_WREADY	
    .S_AXI_BRESP	(s_axi_bresp_cc		),                      //S_AXI_BRESP	                    s_axi_bresp_cc		                    S_AXI_BRESP	
    .S_AXI_BVALID	(s_axi_bvalid_cc	),                      //S_AXI_BVALID	                    s_axi_bvalid_cc	                        S_AXI_BVALID	
    .S_AXI_BREADY	(s_axi_bready_cc	),                      //S_AXI_BREADY	                    s_axi_bready_cc	                        S_AXI_BREADY	
    .S_AXI_ARADDR	(s_axi_araddr_cc	),                      //S_AXI_ARADDR	                    s_axi_araddr_cc	                        S_AXI_ARADDR	
    .S_AXI_ARPROT	(s_axi_arprot_cc	),                      //S_AXI_ARPROT	                    s_axi_arprot_cc	                        S_AXI_ARPROT	
    .S_AXI_ARVALID	(s_axi_arvalid_cc	),                      //S_AXI_ARVALID	                    s_axi_arvalid_cc	                    S_AXI_ARVALID	
    .S_AXI_ARREADY	(s_axi_arready_cc	),                      //S_AXI_ARREADY	                    s_axi_arready_cc	                    S_AXI_ARREADY	
    .S_AXI_RDATA	(s_axi_rdata_cc		),                      //S_AXI_RDATA	                    s_axi_rdata_cc		                    S_AXI_RDATA	
    .S_AXI_RRESP	(s_axi_rresp_cc		),                      //S_AXI_RRESP	                    s_axi_rresp_cc		                    S_AXI_RRESP	
    .S_AXI_RVALID	(s_axi_rvalid_cc	),                      //S_AXI_RVALID	                    s_axi_rvalid_cc	                        S_AXI_RVALID	
    .S_AXI_RREADY	(s_axi_rready_cc	)                       //S_AXI_RREADY	                    s_axi_rready_cc	                        S_AXI_RREADY	
);

	
	
	
	
	

//названия цепей и их смещение по 32 бита(в точности как в ворде "ОПпСАНпЕ АДРЕСНОГО ПРОСТРАНСТВА")	
localparam RESET_REG_ADDR 			 = 0;		
localparam TEACH_EN_ADDR         	 = 1;		
localparam NORM_PERIOD_ADDR 	     = 2;
localparam PSK_TYPE_ADDR  		     = 3;

reg [C_S_AXI_DATA_WIDTH-1 : 0] teach_en_reg;
reg [C_S_AXI_DATA_WIDTH-1 : 0] norm_period_reg;
reg [C_S_AXI_DATA_WIDTH-1 : 0] psk_type_reg;



//------------------------------------------------------------------------------------
//						Пересинхронизация в именные регистры
//------------------------------------------------------------------------------------


//Регистры управлениея НЕ канальные
//0		RESET_REG_ADDR	
always @ (posedge s_axi_aclk_cc 	or	negedge s_axi_aresetn_cc)	begin
	if(!s_axi_aresetn_cc) 							reset_reg[C_S_AXI_DATA_WIDTH-1 : 0]	<=  0;
	else if(axi_wr_regs_valid[RESET_REG_ADDR]) 		reset_reg[C_S_AXI_DATA_WIDTH-1 : 0]	<=	axi_wr_regs[RESET_REG_ADDR][C_S_AXI_DATA_WIDTH-1 : 0];
end

//1		TEACH_EN_ADDR	
always @ (posedge s_axi_aclk_cc 	or  	negedge s_axi_aresetn_cc) begin
	if(!s_axi_aresetn_cc) 											teach_en_reg[C_S_AXI_DATA_WIDTH-1 : 0]	<=  0;
	else if(axi_wr_regs_valid[AXI_WR_REGS_NUM + TEACH_EN_ADDR]) 	teach_en_reg[C_S_AXI_DATA_WIDTH-1 : 0]	<=  axi_wr_regs[AXI_WR_REGS_NUM + TEACH_EN_ADDR][C_S_AXI_DATA_WIDTH-1 : 0];
end
  
//2		NORM_PERIOD_ADDR	
always @ (posedge s_axi_aclk_cc 	or  	negedge s_axi_aresetn_cc) begin
	if(!s_axi_aresetn_cc) 												norm_period_reg[C_S_AXI_DATA_WIDTH-1 : 0]	<=  0;
	else if(axi_wr_regs_valid[AXI_WR_REGS_NUM + NORM_PERIOD_ADDR]) 		norm_period_reg[C_S_AXI_DATA_WIDTH-1 : 0]	<=  axi_wr_regs[AXI_WR_REGS_NUM + NORM_PERIOD_ADDR][C_S_AXI_DATA_WIDTH-1 : 0];
end  

//3   	PSK_TYPE_ADDR	
always @ (posedge s_axi_aclk_cc 	or  	negedge s_axi_aresetn_cc) begin
	if(!s_axi_aresetn_cc) 												psk_type_reg[C_S_AXI_DATA_WIDTH-1 : 0]	<=  0;
	else if(axi_wr_regs_valid[AXI_WR_REGS_NUM + PSK_TYPE_ADDR]) 		psk_type_reg[C_S_AXI_DATA_WIDTH-1 : 0]	<=  axi_wr_regs[AXI_WR_REGS_NUM + PSK_TYPE_ADDR][C_S_AXI_DATA_WIDTH-1 : 0];
end  
	
	
pcma_compensator#(
	.IN_D_WIDTH   (IN_D_WIDTH   ),
	.OUT_D_WIDTH  (OUT_D_WIDTH  ),
	.COE_WIDTH    (COE_WIDTH    ),
	.INV_COE_WIDTH(INV_COE_WIDTH),
	.EQ_LEN       (EQ_LEN       )
)compensator_inst(
	.clk       (s_axi_aclk_cc  ),
	.reset_n   (resync_reset_n),
	
	.teach_en  (teach_en_reg   [0]  ),
	.norm_per  (norm_period_reg[9:0]),	
	.psk_type  (psk_type_reg   [2:0]),
	
	.preset_coe(i_preset_coe),
	.load_coe  (i_load_coe  ),
	.i_init_coe(i_init_coe  ),

    .iq_val    (i_iq_val ),
	.i_data_I  (i_data_I ),
	.i_data_Q  (i_data_Q ),
	
	.o_dout_I  (o_dout_I ),
	.o_dout_Q  (o_dout_Q ),
	.o_vld     (o_vld    )
);

generate
if(DEBUG) begin
    ila_pcma_comp_axi		ila_pcma_comp_axi_inst (
            .clk(s_axi_aclk_cc),
            .probe0({            
                resync_reset_n,
                
                i_data_I	    [IN_D_WIDTH-1:0], 		
                i_data_Q		[IN_D_WIDTH-1:0], 		
                i_iq_val,
                
                i_load_coe,  	
                i_init_coe		[FULL_COE_WIDTH-1:0],	
                
                reset_reg       [C_S_AXI_DATA_WIDTH-1 : 0],
                teach_en_reg    [C_S_AXI_DATA_WIDTH-1 : 0],
                norm_period_reg [C_S_AXI_DATA_WIDTH-1 : 0],
                psk_type_reg    [C_S_AXI_DATA_WIDTH-1 : 0]
            })
    );
end
endgenerate

endmodule
