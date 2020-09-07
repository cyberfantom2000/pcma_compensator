`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 24.07.2020 15:11:02
// Design Name: 
// Module Name: pcma_equalizer
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
// При изменении длины эквалайзер необходимо менять localparam DATA_DELAY
// как его расчитывать не смог понять. Его знчение для некоторых длин эквалйзера приведены рядом с ним,
// для остальных надо подбирать вручную. 
//////////////////////////////////////////////////////////////////////////////////

module pcma_equalizer #(
    parameter IQ_WIDTH  	= 10 ,		// Длина входных данных
	parameter OUT_D_WIDTH   = 16 ,		// Длина выходных данных
    parameter COE_WIDTH 	= 16 ,		// Видимая часть коэфф.
	parameter INV_COE_WIDTH = 8  ,		// Невидимая часть коэфф.
    parameter EQ_LEN    	= 17		// Длина эквалайзера
)(
    input                                clk	   ,
    input                                reset_n   ,
	
	input                                teach_en  ,
	input  [9                        :0] i_norm_per,	// Период нормировки
    
	input 								 preset_coe,    // Сброс коэф. эквалайзер к виду ...00100....
	input 							     load_coe  ,	// Загрузка коэф. Подается EQ_LEN раз для загрузки EQ_LEN коэффициентов
	input  [COE_WIDTH+INV_COE_WIDTH-1:0] i_init_coe,	// значения загружаемых коэффициентов
	
	input 								 iq_val	   ,
	input  [IQ_WIDTH-1               :0] i_comm_I  ,	// Суммарный сигнал (нижний+верхний) I
	input  [IQ_WIDTH-1               :0] i_comm_Q  ,	// Суммарный сигнал (нижний+верхний) Q    
    input  [IQ_WIDTH-1               :0] i_data_I  ,	// Верхний сигнал идеальное созвездие I
	input  [IQ_WIDTH-1               :0] i_data_Q  ,	// Верхний сигнал идеальное созвездие Q
	
    output [OUT_D_WIDTH-1            :0] o_dout_I  ,		
	output [OUT_D_WIDTH-1            :0] o_dout_Q  ,
	output 								 o_vld     
);


//****** Constant and Parameters ******//
localparam 						FULL_COE_WIDTH = COE_WIDTH + INV_COE_WIDTH;
localparam 					    EQ_HIGH_BIT    = IQ_WIDTH  + COE_WIDTH + 3;	 // Старший бит выхода эквалазйера		
localparam [FULL_COE_WIDTH-1:0] COE_ONE_VAL    = (2**(COE_WIDTH-3))-1     ;
localparam 					    DATA_DELAY     = 19                       ; /* | EQ_LEN | DATA_DELAY |
                                                                               |    13   ->  15      |
                                                                               |    15   ->  16      |
                                                                               |    17   ->  18      |
                                                                               |    19   ->  19      |
                                                                               |    21   ->  20      |
                                                                               |    23   ->  21      |
                                                                               |    25   ->  22      |
                                                                               |    27   ->  23      |
                                                                               |    29   ->  24      |
                                                                               |    31   ->  25      |
                                                                               |    33   ->  27      | */
//************ Declaration ************//
reg  signed[IQ_WIDTH-1      :0] comm_I_r, comm_Q_r        ;
reg  signed[IQ_WIDTH-1      :0] data_I_r, data_Q_r        ;
reg  signed[FULL_COE_WIDTH-1:0] init_coe_r                ;
wire signed[EQ_HIGH_BIT     :0] eq_II, eq_QQ, eq_IQ, eq_QI;
reg  signed[EQ_HIGH_BIT     :0] comp_I, comp_Q            ;
wire signed[IQ_WIDTH-1      :0] dly_comm_I, dly_comm_Q    ;   
reg  signed[EQ_HIGH_BIT     :0] mult_comm_I, mult_comm_Q  ;
reg  signed[EQ_HIGH_BIT     :0] subst_I, subst_Q          ;		 // Разница сиганлов суммарного и после эквалйзера
wire signed[OUT_D_WIDTH-1   :0] round_I_w, round_Q_w      ;
reg  signed[OUT_D_WIDTH-1   :0] round_I_r, round_Q_r      ;
reg						        iq_val_r                  ;
reg                             load_coe_r                ;
reg                             preset_coe_r              ;
wire 					        eq_val_w                  ;
reg						        eq_val_r                  ;


// clk delay, resyns and pipeling
always@(posedge clk) begin
	if(!reset_n) begin
		eq_val_r     <= 0;
		round_I_r    <= 0;
		round_Q_r    <= 0;
		iq_val_r     <= 0;
		load_coe_r   <= 0;
		preset_coe_r <= 0;
		comm_I_r     <= 0;
		comm_Q_r     <= 0;
		data_I_r     <= 0;
		data_Q_r     <= 0;
		init_coe_r   <= 0;
	end else begin		
		load_coe_r   <= load_coe;
		preset_coe_r <= preset_coe;
		iq_val_r     <= iq_val;
		comm_I_r     <= i_comm_I;
		comm_Q_r     <= i_comm_Q;
		data_I_r     <= i_data_I;
		data_Q_r     <= i_data_Q;
		init_coe_r   <= i_init_coe;		
		eq_val_r     <= eq_val_w;		
		round_I_r    <= round_I_w;
		round_Q_r    <= round_Q_w;
	end
end


// I summary signal delay on DATA_DELAY SYMBOLS
delay_mod#(
	.IN_D_WIDTH (IQ_WIDTH   ),
	.OUT_D_WIDTH(IQ_WIDTH   ),
	.DELAY		(DATA_DELAY )
)delay_I(
	.clk	 (clk       ),
	.reset_n (reset_n   ),	
	.vld     (iq_val_r  ),	
	.din	 (comm_I_r  ),
	.dout	 (dly_comm_I)
);

// Q summary signal delay on DATA_DELAY SYMBOLS
delay_mod#(
	.IN_D_WIDTH (IQ_WIDTH   ),
	.OUT_D_WIDTH(OUT_D_WIDTH),
	.DELAY		(DATA_DELAY )
)delay_Q(
	.clk	 (clk       ),
	.reset_n (reset_n   ),	
	.vld     (iq_val_r  ),
	.din     (comm_Q_r  ),
	.dout    (dly_comm_Q)
);

// Complex equalizer
complex_lms_equalizer#(
	._DATA_WIDTH    (IQ_WIDTH     ),
	._COE_WIDTH     (COE_WIDTH    ),
	._INV_COE_WIDTH (INV_COE_WIDTH),
	._COE_NUM       (EQ_LEN       ),
	._PHASE_NUM     (1            ),
    ._CROSS_EQ_TYPE (0            ),
    ._IN_SYM_DLY    (10           )
)complex_eq_inst(
	.clk            (clk          ),
    .reset          (!reset_n     ),
    .preset_coe     (preset_coe_r ),
	.load_coe		(load_coe_r   ),	
    
    .i_error_I      ( subst_I[EQ_HIGH_BIT]),
    .i_error_Q      (~subst_Q[EQ_HIGH_BIT]), // инверсия потому что комплексносопряженная ошибка
    .i_sym_vld      (iq_val_r             ),
    .i_teach_en     (teach_en             ),
    .i_norm_period  (i_norm_per           ),
    
    .i_dtin_I       (data_I_r   ),
    .i_dtin_Q       (data_Q_r   ),
    .i_vldin        (iq_val_r   ),
	.i_coedata		(init_coe_r ),
    .o_dout_II      (eq_II      ),
    .o_dout_QQ      (eq_QQ      ),
    .o_dout_IQ      (eq_IQ      ),
    .o_dout_QI      (eq_QI      ),
    .o_vldout       (eq_val_w   )
);

// Complex I/Q calc
always@(posedge clk) begin
	if(!reset_n) begin
		mult_comm_I <= 0;
		mult_comm_Q <= 0;
		subst_I     <= 0;
		subst_Q     <= 0;
        comp_I      <= 0;
        comp_Q      <= 0;
	end else begin
        // Домножение чтобы привести к одной размерности       
        mult_comm_I <= dly_comm_I * $signed(COE_ONE_VAL);
        mult_comm_Q <= dly_comm_Q * $signed(COE_ONE_VAL);
        // Комплексно !!!СОПРЯЖЕННЫЕ!!! I и Q после эквалазйера
        comp_I   <= eq_II + eq_QQ;           
        comp_Q   <= eq_QI - eq_IQ;         
          
		if(iq_val_r) begin		 
        // Нижний сигнал, его знак также является ошибкой для настрйоки эквалайзеров
			subst_I <= mult_comm_I - comp_I;
			subst_Q <= mult_comm_Q - comp_Q;
		end 
	end
end

// round subst I
ROUNDER#(
	.DIN_WIDTH  (EQ_HIGH_BIT+1),
    .DOUT_WIDTH (OUT_D_WIDTH  )
)eq_round_I_inst(
	.CLK        (clk      ),
    .DIN        (subst_I  ),
    .DIN_CE     (eq_val_w ),
    .DOUT       (round_I_w)
);

// round subst Q
ROUNDER#(
	.DIN_WIDTH  (EQ_HIGH_BIT+1),
    .DOUT_WIDTH (OUT_D_WIDTH  )
)eq_round_Q_inst(
	.CLK        (clk      ),
    .DIN        (subst_Q  ),
    .DIN_CE     (eq_val_w ),
    .DOUT       (round_Q_w)
);

/************************ Assign out port section ************************/
assign o_dout_I = round_I_r;
assign o_dout_Q = round_Q_r;
assign o_vld    = eq_val_r;

endmodule
