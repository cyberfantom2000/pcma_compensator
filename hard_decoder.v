/*------------------------------------------------------
--	Жесткий декодер.								  --
--	1) Для QPSK решение принимает по знаку.			  -- 
--	2) Для 8-PSK решение принимается по знаку и 	  --
--	   расположению относительно прямой x=y.		  --
--	3) Модуль имеет задержку 2 такта.				  --
-------------------------------------------------------*/
module hard_decoder #(
	parameter IQ_WIDTH = 10
)(
	input	clk,
	input   reset_n,
	
	input  [2         :0]  psk_type,  // 001 - QPSK, 010 - 8-PSK
	
	input   			   iq_val,
	input  [IQ_WIDTH-1:0]  i_data_I,
	input  [IQ_WIDTH-1:0]  i_data_Q,
	
	output 				   o_val,
	output [IQ_WIDTH-1:0]  o_data_I,
	output [IQ_WIDTH-1:0]  o_data_Q
);


//****** Constant and Parameters ******//
localparam[2:0] QPSK  = 3'b001;
localparam[2:0] PSK_8 = 3'b010;


//************ Declaration ************//
reg signed[IQ_WIDTH-1:0] reg_I, reg_Q;
reg signed[IQ_WIDTH-1:0] out_I, out_Q;
reg 			   	     e_o;
reg 			         even = 1;


genvar i;
generate
	for(i=0; i<2; i=i+1) begin : sh
		reg val;
		if(i==0) begin
			always@(posedge clk) begin
				if(!reset_n) val <= 0;
				else         val <= iq_val;
			end
		end else begin
			always@(posedge clk) begin
				if(!reset_n) sh[i].val <= 0;
				else         sh[i].val <= sh[i-1].val;
			end	
		end
	end
endgenerate

always@(posedge clk) begin
	if(!reset_n) begin
		reg_I  <= 0;
		reg_Q  <= 0;
	end else begin
		reg_I  <= i_data_I;
		reg_Q  <= i_data_Q;
	end
end

// Прореживание валида, чтобы брать только четные символы.
always@(posedge clk) begin
	if(!reset_n) begin
		e_o   <= 0;
		even  <= 1;
	end else if(iq_val) begin
		if(even)  e_o <= 1;     // Для смены четный/нечетный убрать/добавить инверсию в условии
		else      e_o <= 0;		
		
		if(even) even <= 0;
		else	 even <= 1;
	end else begin
		e_o <= 0;
	end
end

// Main section
always@(posedge clk) begin
	if(!reset_n) begin
		out_I <= 0;
		out_Q <= 0;
	end else begin
		case(psk_type)
			QPSK: begin
				if(e_o) begin
					if( ~reg_I[IQ_WIDTH-1] && ~reg_Q[IQ_WIDTH-1] ) begin		  // 11
						out_I <= $signed( 10'd180);
						out_Q <= $signed( 10'd180);
					end else if( reg_I[IQ_WIDTH-1] && ~reg_Q[IQ_WIDTH-1] ) begin  // 01
						out_I <= $signed(-10'd180);
						out_Q <= $signed( 10'd180);					
					end else if( ~reg_I[IQ_WIDTH-1] && reg_Q[IQ_WIDTH-1] ) begin  // 10
						out_I <= $signed( 10'd180);
						out_Q <= $signed(-10'd180);
					end else begin												  // 00
						out_I <= $signed(-10'd180);
						out_Q <= $signed(-10'd180);
					end
				end else if(sh[0].val) begin
						out_I <= 10'd0;
						out_Q <= 10'd0;
				end
			end
			
			PSK_8: begin
				if(e_o) begin
					if( ~reg_I[IQ_WIDTH-1] && ~reg_Q[IQ_WIDTH-1] ) begin			  
						if( reg_I >= reg_Q ) begin							// 111
							out_I <= $signed( 10'd256);
							out_Q <= $signed( 10'd98 );
						end else begin										// 110
							out_I <= $signed( 10'd98 );
							out_Q <= $signed( 10'd256);
						end
					end else if( reg_I[IQ_WIDTH-1] && ~reg_Q[IQ_WIDTH-1] ) begin  
						if( -reg_I >= reg_Q ) begin						   // 011
							out_I <= $signed(-10'd256);
							out_Q <= $signed( 10'd98 );
						end else begin									   // 010
							out_I <= $signed(-10'd98 );
							out_Q <= $signed( 10'd256);
						end
					end else if( ~reg_I[IQ_WIDTH-1] && reg_Q[IQ_WIDTH-1] ) begin
						if( reg_I >= -reg_Q ) begin						   // 101
							out_I <= $signed( 10'd256);
							out_Q <= $signed(-10'd98 );
						end else begin									   // 100
							out_I <= $signed( 10'd98 );
							out_Q <= $signed(-10'd256);
						end
					end else begin
						if( reg_I <= reg_Q ) begin						   // 001
							out_I <= $signed(-10'd256);
							out_Q <= $signed(-10'd98 );
						end else begin									   // 000
							out_I <= $signed(-10'd98 );
							out_Q <= $signed(-10'd256);
						end
					end
				end else if(sh[0].val) begin
						out_I <= 10'd0;
						out_Q <= 10'd0;
				end
			end

			default: begin // QPSK
				if(e_o) begin
					if( ~reg_I[IQ_WIDTH-1] && ~reg_Q[IQ_WIDTH-1] ) begin		  // 11
						out_I <= $signed( 10'd180);
						out_Q <= $signed( 10'd180);
					end else if( reg_I[IQ_WIDTH-1] && ~reg_Q[IQ_WIDTH-1] ) begin  // 01
						out_I <= $signed(-10'd180);
						out_Q <= $signed( 10'd180);					
					end else if( ~reg_I[IQ_WIDTH-1] && reg_Q[IQ_WIDTH-1] ) begin  // 10
						out_I <= $signed( 10'd180);
						out_Q <= $signed(-10'd180);
					end else begin												  // 00
						out_I <= $signed(-10'd180);
						out_Q <= $signed(-10'd180);
					end
				end else if(sh[0].val) begin
						out_I <= 10'd0;
						out_Q <= 10'd0;
				end
			end
		endcase
	end
end

/************************ Assign out port section ************************/
assign o_data_I = out_I;
assign o_data_Q = out_Q;
assign o_val    = sh[1].val;

endmodule