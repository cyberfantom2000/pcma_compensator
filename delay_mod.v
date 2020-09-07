/*-----------------------------------------------------------------------
Моудуль задержки по валидам. Для задержки по тактам 
вмсто валида поставить клоку.

ВАЖНО: длина входных данных должна быть МЕНЬШЕ или РАВНА выходной длине !!!!
------------------------------------------------------------------------*/
module delay_mod #(
	parameter IN_D_WIDTH  = 10,
	parameter OUT_D_WIDTH = 16,
	parameter DELAY	      = 17
)(
	input 				    clk    ,
	input 				    reset_n,
	
	input				    vld    ,  // Задержка по валидам, для задержки на такты присвоить clk
	input [IN_D_WIDTH-1 :0] din    ,
	output[OUT_D_WIDTH-1:0] dout	
);

genvar i;

//Знакорасширение
`ifdef IN_D_WIDTH<OUT_D_WIDTH
	wire signed[OUT_D_WIDTH-1:0] din_w = din[IN_D_WIDTH-1]  ?  $signed({{(OUT_D_WIDTH-IN_D_WIDTH){1'b1}}, din[IN_D_WIDTH-1:0]}) : $signed({{(OUT_D_WIDTH-IN_D_WIDTH){1'b0}}, din[IN_D_WIDTH-1:0]});
`else
	wire signed[OUT_D_WIDTH-1:0] din_w = $signed(din);
`endif
	
	

generate
	for(i=0; i<DELAY; i=i+1)begin:tap
		reg signed [OUT_D_WIDTH-1:0] r = 0;
		if(i==0) begin
			always@(posedge clk) begin
				if(!reset_n) r <= 0;
				else if(vld) r <= din_w;
			end
		end else begin
			always@(posedge clk) begin
				if(!reset_n) tap[i].r <= 0;
				else if(vld) tap[i].r <= tap[i-1].r;
			end
		end
	end
endgenerate

assign dout  = tap[DELAY-1].r;

endmodule