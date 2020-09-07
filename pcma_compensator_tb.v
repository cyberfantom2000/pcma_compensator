`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 13.08.2020 13:02:24
// Design Name: 
// Module Name: pcma_compensator_tb
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


module pcma_compensator_tb();


	localparam IQ_DATA_WIDTH = 10;
	localparam VAL_CNT_WIDTH = 1;
	
	reg CLK 	= 0;
	reg nRESET  = 0;
	reg I_DATA_VAL = 0;
	reg VAL_REG = 1;

	reg [31:0]  word_ascii;
	reg [31:0]  memory [5000000:0];

	
	reg signed [IQ_DATA_WIDTH-1:0] I_DATA_I=100;
	reg signed [IQ_DATA_WIDTH-1:0] I_DATA_Q=100;

	reg [VAL_CNT_WIDTH-1:0] VAL_REG_CNT=0;
	
	reg[31:0] cntr = 0;
	
	

	
	wire signed[15:0] dout_I, dout_Q;
	wire 			  out_val;	
	
	/*****************************************/
	
	integer	fid;
	integer fout, fout1;
	integer N,i=0;
	
	initial forever #8  CLK <= !CLK;	//125 MHz
	initial 		#20 nRESET <= 1;
	
//блок генерации прореженного велида(чтобы данные не шли сплошным потоком.)	
initial  begin		
    while (1) begin	
		@ (posedge CLK);			
			VAL_REG_CNT <= VAL_REG_CNT+1;
			VAL_REG     <= ( VAL_REG_CNT==0 );
			
    end
end
	
	
	// ***************    ФАЙЛ 1    *************** //
	initial begin	
        fid = $fopen("rrc_data.bin" , "rb");
		
		if (fid == 0) begin
			$display("Error: Input TB File 1  could not be opened.\nExiting Simulation.");	//если файл прочитан неверно
			$finish;
		end

			
		N = $fread(memory, fid);
		$fclose(fid);
	end
	

//`define  IQ_INVERT		0						//инверсия
	initial begin
 	    while (1) begin
		   @(posedge CLK);			
				if (VAL_REG) begin		   
				   cntr <= cntr + 1;
				   
				   word_ascii = memory[i];		//по клоку и велиду записываем 32битное слово в переменную, далее разбираем это слово на I,Q состовляющие, согласно формату интел.

				   
				   if (i==N/4-4) i=0; else i = i + 1;		//счетчик слов.  N -всего слов в массиве memory.  в 32битном слов 4 байта, поэтому делим на 4.  минус 4 тк счет от нуля.
			   
				
/*`ifdef	IQ_INVERT		//инверсия. активируется дефайном в начале файла.  наличие инверсии зависит от того как записан файл .bin.  У нас во всей апаратуре есть возможность вкл/выкл инверсию
			I_DATA_Q <= {word_ascii_1[17:16],word_ascii_1[31:24]} ;	  
			I_DATA_I <= {word_ascii_1[1:0]  ,word_ascii_1[15:8] } ;

`else*/
			I_DATA_I <= {word_ascii[17:16],word_ascii[31:24]} ;	  
		    I_DATA_Q <= {word_ascii[1:0]  ,word_ascii[15:8] } ;

//`endif
				end
			//end
        end    
	end
	
	
	
	
// Запись в файл
initial begin
	fout = $fopen("result.bin", "wb");
	if(fout == 0) begin
		$display("Error: output TB File  could not be opened.\nExiting Simulation.");
		$finish;
	end
	#10000000								//ожидание перед концом записи и закрытием файла(ставте ровно столько, сколько будете симулировать)
											//если это значение будет больше чем пройденное время симуляции файл не будет записан.
	$fclose(fout);
end
	
always@(posedge CLK) begin
	if(out_val)
		$fwrite(fout,"%c%c%c%c", dout_I[7:0], dout_I[15:8], dout_Q[7:0], dout_Q[15:8]);

end




// Запись в файл 2
wire[29:0] test_I, test_Q;
wire test_val;

initial begin
	fout1 = $fopen("test.bin", "wb");
	if(fout1 == 0) begin
		$display("Error: output TB File  could not be opened.\nExiting Simulation.");
		$finish;
	end
	#10000000								//ожидание перед концом записи и закрытием файла(ставте ровно столько, сколько будете симулировать)
											//если это значение будет больше чем пройденное время симуляции файл не будет записан.
	$fclose(fout1);
end
	
always@(posedge CLK) begin
	if(test_val)
		$fwrite(fout1,"%c%c%c%c", test_I[21:14], test_I[29:22], test_Q[21:14], test_Q[29:22]);

end


//============================================================================================================//
//												Test block's											      //
//============================================================================================================//
localparam[2:0] QPSK   = 3'b001;
localparam[2:0] PSK_8  = 3'b010;
localparam      EQ_LEN = 19;

reg 			  reset_coe = 0;
reg 			  load_coe  = 0;
reg signed [25:0] h_arr[0:EQ_LEN-1];
reg signed [25:0] h_coef;

integer j, k;
initial begin
    /*h_arr[0]  = $signed( 26'd1      );
    h_arr[1]  = $signed(-26'd1282   );
    h_arr[2]  = $signed( 26'd1      );
    h_arr[3]  = $signed(-26'd3385   );
    h_arr[4]  = $signed( 26'd1      );
    h_arr[5]  = $signed( 26'd8538   );
    h_arr[6]  = $signed(-26'd1      );*/
    h_arr[0]  = $signed(-26'd3881   );
	h_arr[1]  = $signed( 26'd1      );
	h_arr[2]  = $signed(-26'd28991  );
	h_arr[3]  = $signed( 26'd1      );
	h_arr[4]  = $signed( 26'd119608 );
	h_arr[5]  = $signed( 26'd1      );
	h_arr[6]  = $signed(-26'd340650 );
	h_arr[7] = $signed(-26'd1      );
	h_arr[8] = $signed( 26'd1297264);
	h_arr[9] = $signed( 26'd2097151);
	h_arr[10] = $signed( 26'd1297264);
	h_arr[11] = $signed(-26'd1      );
	h_arr[12] = $signed(-26'd340650 );
	h_arr[13] = $signed( 26'd1      );
	h_arr[14] = $signed( 26'd119608 );
	h_arr[15] = $signed( 26'd1      );
	h_arr[16] = $signed(-26'd28991  );
	h_arr[17] = $signed( 26'd1      );
    h_arr[18] = $signed(-26'd3881   );
    /*h_arr[26] = $signed(-26'd1      );
    h_arr[27] = $signed( 26'd8538   );
    h_arr[28] = $signed( 26'd1      );
    h_arr[29] = $signed(-26'd3385   );
    h_arr[30] = $signed( 26'd1      );
    h_arr[31] = $signed(-26'd1282   );
    h_arr[32] = $signed( 26'd1      );*/
end	

initial begin
	#20
	for(j=0; j<EQ_LEN; j=j+1)		
		#32 h_coef[25:0] = h_arr[j][25:0];			
end

initial begin
	#30
	//#8 reset_coe <= 1;
	//#8 reset_coe <= 0;
	for(k=0; k<EQ_LEN; k=k+1) begin
		#16 load_coe <= 1;
		#16 load_coe <= 0;
	end
end

pcma_compensator#(
	.IN_D_WIDTH   (10    ),
	.OUT_D_WIDTH  (16    ),
	.COE_WIDTH    (16    ),
	.INV_COE_WIDTH(8     ),
	.EQ_LEN       (EQ_LEN)
)compensator_inst(
	.clk       (CLK   ),
	.reset_n   (nRESET),
	
	.teach_en  (1      ),
	.norm_per  (10'd16 ),	
	.psk_type  (QPSK   ),
	
	.preset_coe(reset_coe),
	.load_coe  (load_coe ),
	.i_init_coe(h_coef   ),
	
	.iq_val    (VAL_REG  ),
	.i_data_I  (I_DATA_I ),
	.i_data_Q  (I_DATA_Q ),
	
	.o_dout_I  (dout_I   ),
	.o_dout_Q  (dout_Q   ),
	.o_vld     (out_val  ),
    
    .o_test_I  (test_I),
    .o_test_Q  (test_Q),
    .o_test_vld(test_val)
);

endmodule
