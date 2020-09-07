//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 13.08.2020 11:11:02
// Design Name: 
// Module Name: pcma_compensator
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
//////////////////////////////////////////////////////////////////////////////////
module pcma_compensator#(
	parameter IN_D_WIDTH    = 10,
	parameter OUT_D_WIDTH   = 16,
	parameter COE_WIDTH     = 16,
	parameter INV_COE_WIDTH = 8,
	parameter EQ_LEN		= 19
)(
	input                                 clk		,
    input                                 reset_n	,
	
	input                                 teach_en	,
	input  [9                        :0]  norm_per  ,   // Период нормировки
	
	input  [2                        :0]  psk_type  ,   //Type of modulation. 001 - QPSK, 010 - 8-PSK
	
	input 								  preset_coe,	// Сброс коэф. эквалайзер к виду ...00100....
	input 								  load_coe	,   // Загрузка коэф. Подается EQ_LEN раз для загрузки EQ_LEN коэффициентов
	input  [COE_WIDTH+INV_COE_WIDTH-1:0]  i_init_coe,	// Загружаемые коэфф.
	
	input 								  iq_val	,
	input  [IN_D_WIDTH-1             :0]  i_data_I	,	// Суммарный сигнал (нижний+верхний) I
	input  [IN_D_WIDTH-1             :0]  i_data_Q	,	// Суммарный сигнал (нижний+верхний) Q
	
	output [OUT_D_WIDTH-1            :0]  o_dout_I  ,		
	output [OUT_D_WIDTH-1            :0]  o_dout_Q  ,
	output 								  o_vld	    
);


//****** Constant and Parameters ******//
localparam FULL_COE_WIDTH = COE_WIDTH + INV_COE_WIDTH;
localparam HD_DELAY	      = 4;


//************ Declaration ************//
wire signed[IN_D_WIDTH-1:0] hd_I_w, hd_Q_w;
reg  signed[IN_D_WIDTH-1:0] hd_I_r, hd_Q_r;
reg  signed[IN_D_WIDTH-1:0] comm_I_r, comm_Q_r;
wire					    hd_val_w;
reg							hd_val_r1, hd_val_r2;
reg						    iq_val_r;

reg  signed[FULL_COE_WIDTH-1:0] coe_r;
reg 						    load_coe_r;

genvar i;
generate
	for(i=0; i<HD_DELAY; i=i+1) begin : tap
		reg signed[IN_D_WIDTH-1:0] dly_I_r, dly_Q_r;
        
		if(i==0) begin			
			always@(posedge clk) begin
				if(!reset_n) begin
					dly_I_r <= 0;
					dly_Q_r <= 0;
				end else begin
					dly_I_r <= i_data_I;
					dly_Q_r <= i_data_Q;			
				end
			end
		end else begin
			always@(posedge clk) begin
				if(!reset_n) begin
					tap[i].dly_I_r <= 0;
					tap[i].dly_Q_r <= 0;
				end else begin 
					tap[i].dly_I_r <= tap[i-1].dly_I_r;
					tap[i].dly_Q_r <= tap[i-1].dly_Q_r;			
				end			
			end
		end
	end
endgenerate

// Pipeling, delay and resyns
always@(posedge clk) begin
	if(!reset_n) begin		
		coe_r      <= 0;
		load_coe_r <= 0;
		hd_I_r     <= 0;
		hd_Q_r     <= 0;
        hd_val_r1  <= 0;
		hd_val_r2  <= 0;
		comm_I_r   <= 0;
		comm_Q_r   <= 0;
        iq_val_r   <= 0;
	end else begin				
		coe_r      <= i_init_coe;
		load_coe_r <= load_coe;
		hd_I_r     <= hd_I_w;
		hd_Q_r	   <= hd_Q_w;
        hd_val_r1  <= hd_val_w;
        hd_val_r2  <= hd_val_r1;
        iq_val_r   <= iq_val;
		
		if(hd_val_r2) begin
			comm_I_r <= tap[HD_DELAY-1].dly_I_r;
			comm_Q_r <= tap[HD_DELAY-1].dly_Q_r;
		end
 	end
end


hard_decoder#(
	.IQ_WIDTH (IN_D_WIDTH)
)hard_decoder_inst(
	.clk	  (clk     ),
	.reset_n  (reset_n ),
	
	.psk_type (psk_type),
	
	.iq_val   (iq_val_r      ),
	.i_data_I (tap[0].dly_I_r),
	.i_data_Q (tap[0].dly_Q_r),
	
	.o_val    (hd_val_w),
	.o_data_I (hd_I_w  ),
	.o_data_Q (hd_Q_w  )	
);

pcma_equalizer#(
	.IQ_WIDTH      (IN_D_WIDTH   ),
	.OUT_D_WIDTH   (OUT_D_WIDTH  ),
	.COE_WIDTH     (COE_WIDTH    ),
	.INV_COE_WIDTH (INV_COE_WIDTH),
	.EQ_LEN		   (EQ_LEN       )
)pcma_equalizer_inst(
	.clk 	 	   (clk        ),
	.reset_n 	   (reset_n    ),
	
	.teach_en	   (teach_en   ),
	.i_norm_per    (norm_per   ),
	
	.preset_coe	   (preset_coe ),
	.load_coe	   (load_coe_r ),
	.i_init_coe    (coe_r      ),	
	
	.iq_val        (hd_val_r2  ),
	.i_comm_I	   (comm_I_r   ),	// Суммарный сигнал
	.i_comm_Q	   (comm_Q_r   ),
	.i_data_I      (hd_I_r     ),	// Верхний восстановленный сигнал
	.i_data_Q      (hd_Q_r     ),	
	
	.o_dout_I	   (o_dout_I   ),
	.o_dout_Q	   (o_dout_Q   ),
	.o_vld         (o_vld      )
);

endmodule


