`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/30/2017 03:22:08 PM
// Design Name: 
// Module Name: lms_equalizer
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
module lms_equalizer #(
    parameter                   _DATA_WIDTH     = 16,
    parameter                   _COE_WIDTH      = 16,
    parameter                   _INV_COE_WIDTH  = 8,
    parameter                   _COE_NUM        = 17,
    parameter                   _PHASE_NUM      = 2 ,
    parameter                   _CROSS_EQ_TYPE  = 0 ,
    parameter                   _IN_SYM_DLY     = 7 
)
(
    input                           clk             ,
    input                           reset           ,
    input                           preset_coe      ,   // reset coef to mind ...00100...
    input                           load_coe        ,   // load init coef. Ставится на 1 такт для загрузки 1 коэф.

// Equalization Error
    input                           i_error         ,
    input                           i_sym_vld       ,
    input                           i_teach_en      ,
    input   [9         :0]          i_norm_period   ,
// Input Data               
    input   [_DATA_WIDTH*_PHASE_NUM-1               :0] i_dtin     ,
    input                                               i_vldin    ,
	input   [_COE_WIDTH+_INV_COE_WIDTH-1            :0] i_coedata  ,  // preset coef data
// Output Data      
    output  [(_DATA_WIDTH+_COE_WIDTH+4)*_PHASE_NUM-1:0] o_dout     ,
    output                                              o_vldout   
    );
    
//*************** CONSTANTS AND PARAMETERS **********
genvar  idx ;
integer i   ;
localparam  _SYM_DECIMATION     = 2;
localparam  _FULL_COE_WIDTH     = _INV_COE_WIDTH + _COE_WIDTH;
localparam  _FULL_DOUT_WIDTH    = _DATA_WIDTH+_COE_WIDTH+3+1;
localparam [_FULL_COE_WIDTH-1:0] _COE_ONE_VAL        = (_CROSS_EQ_TYPE)  ? 0 : ((2**(_FULL_COE_WIDTH-3))-1);
// ******************* Declarations *****************
reg     [_COE_WIDTH*_COE_NUM - 1:0] H_COE                                   ;
wire    [_COE_WIDTH - 1:0]          H_COE_ROUND             [_COE_NUM-1 :0] ;
wire    [_FULL_DOUT_WIDTH*_PHASE_NUM- 1    :0] DOUT_FULL                    ;
reg     [_IN_SYM_DLY-1      :0]     DELAY_SIGSYM_SHFT_REG                   ;
reg     [_COE_NUM-1         :0]     SIGSYM_SHFT_REG                         ;
reg     [_COE_NUM-1         :0]     EQ_ERROR                                ;
reg     [9                  :0]     NORM_PERIOD_CNT                         ;
reg     [_FULL_COE_WIDTH-1  :0]     H_COE_FULL              [_COE_NUM-1 :0] ;
reg     [9                  :0]     NORM_PERIOD_VAL_REG;
reg     PRESET_EQUAL_REG    ;
reg     TEACH_EN_REG        ;
wire    RST_NORM_PERIOD_CNT ;
wire    EN_COE_COUNT        ;
wire    NORMOLIZE_COE       ;
reg     sreset_eq         =1;

reg signed[_FULL_COE_WIDTH-1:0]     INIT_EQ_COE            [_COE_NUM-1 :0] ; // Регистр для последовательной загрузки коэф.
reg                                 LOAD_EQ_COE                            ;


always@(posedge clk) begin
    if (reset)
        sreset_eq <= 1;
    else
        sreset_eq <= 0;
end

// ******************* MAIN Section *****************
//generate
//    if (_DELAY_MEASUR_MOD==32'h00000001) begin
//        reg [_FULL_DOUT_WIDTH-1: 0] DELAY_DATA;
//        
//        always@(posedge clk)begin
//            if (sreset_eq)
//                DELAY_DATA <= 0;
//            else if (i_vldin) begin
//                DELAY_DATA[_FULL_DOUT_WIDTH-1: _FULL_DOUT_WIDTH-_DATA_WIDTH] <= i_dtin;
//                DELAY_DATA[_FULL_DOUT_WIDTH-_DATA_WIDTH-1 :0] <= 0;
//            end
//        end
//        assign DOUT_FULL = DELAY_DATA;
//    end else begin

// Input Control Pipe REGs
always@(posedge clk) begin
    if (sreset_eq) begin
        PRESET_EQUAL_REG    <= 1;
        TEACH_EN_REG        <= 0;
        NORM_PERIOD_VAL_REG <= 10'd4;
        LOAD_EQ_COE         <= 0;      
    end else begin
        PRESET_EQUAL_REG    <= preset_coe;
        TEACH_EN_REG        <= i_teach_en;
        NORM_PERIOD_VAL_REG <= i_norm_period;
        LOAD_EQ_COE         <= load_coe;       
    end
end

        // Convolution
        convolution #(
            ._HALF_BAND     (0          ),
            ._SYMMETRY_COE  (0          ),
            ._DATA_WIDTH    (_DATA_WIDTH),
            ._COE_WIDTH     (_COE_WIDTH ),
            ._COE_NUM       (_COE_NUM   ),
            ._PHASE_NUM     (_PHASE_NUM ),
            ._DECIMATION    (1          )
        )
        _CONVOLUTION(
            .clk            (clk        ),
            .reset          (sreset_eq  ),
            .i_h_port       (H_COE      ),
            .i_dtin         (i_dtin     ),
            .i_vldin        (i_vldin    ),
            .o_dout         (DOUT_FULL  ),
            .o_vldout       (o_vldout   )
            );
//    end
//endgenerate

always@(posedge clk) begin
    if(sreset_eq) begin        
		for(i=0; i<_COE_NUM; i++)
			INIT_EQ_COE[i] <= 0;
    end else if(load_coe) begin
        INIT_EQ_COE[0] <= $signed(i_coedata);
        for(i=0; i<_COE_NUM; i++)
            INIT_EQ_COE[i+1] <= INIT_EQ_COE[i];
    end
end


generate
    for(idx=0; idx<_PHASE_NUM; idx++)
        assign o_dout[_FULL_DOUT_WIDTH*(idx+1)-1 :_FULL_DOUT_WIDTH*idx] = DOUT_FULL[_FULL_DOUT_WIDTH*(idx+1)-1 :_FULL_DOUT_WIDTH*idx];
endgenerate
//*******************************Сalculating NEW Error
// Sig Symbol Line For 
always@(posedge clk) begin
    if (sreset_eq) begin
        for (i=0; i<_IN_SYM_DLY; i++)
            DELAY_SIGSYM_SHFT_REG[i] <= 0;
    end else if (i_vldin) begin
        DELAY_SIGSYM_SHFT_REG[0] <= i_dtin[_DATA_WIDTH-1];
        for (i=0; i<(_IN_SYM_DLY-1); i++)
            DELAY_SIGSYM_SHFT_REG[i+1] <= DELAY_SIGSYM_SHFT_REG[i];
    end
end
// Sig Symbol Shift REG
always@(posedge clk) begin
    if (sreset_eq) begin
        for (i=0; i<_COE_NUM; i++)
            SIGSYM_SHFT_REG[i] <= 0;
    end else if (i_sym_vld) begin
        SIGSYM_SHFT_REG[0] <= DELAY_SIGSYM_SHFT_REG[_IN_SYM_DLY-1];
        for (i=0; i<(_COE_NUM-1); i++)
            SIGSYM_SHFT_REG[i+1] <= SIGSYM_SHFT_REG[i];
    end
end
// NEW Equalization Error
generate
    for(idx = 0; idx < _COE_NUM; idx++) begin
        always@(posedge clk) begin
            if (sreset_eq)
                EQ_ERROR[idx] <= 0;
            else if (i_sym_vld)
                EQ_ERROR[idx] <= SIGSYM_SHFT_REG[idx] ^ i_error;
        end
     end
endgenerate

//******************************* Training Scheme
// Normalization Period Counter
always@(posedge clk) begin
    if (sreset_eq)
        NORM_PERIOD_CNT <= 0;
    else if (RST_NORM_PERIOD_CNT == 1)
        NORM_PERIOD_CNT <= 0;
    else if (i_sym_vld)
        NORM_PERIOD_CNT <= NORM_PERIOD_CNT + 1;
end
assign RST_NORM_PERIOD_CNT = (NORM_PERIOD_CNT == NORM_PERIOD_VAL_REG) ? i_sym_vld : 0;
assign NORMOLIZE_COE = RST_NORM_PERIOD_CNT;
// Enable Counting Neq COE
//always@(posedge clk) begin
//    if (sreset_eq)
//        EN_COE_COUNT<=0;
//    else
//        EN_COE_COUNT<= i_sym_vld;
//end
    assign EN_COE_COUNT= i_sym_vld;
// COE Counting
generate
    for(idx=0; idx<_COE_NUM; idx++) begin
        if (idx == (_COE_NUM/2)) begin
            always@(posedge clk) begin
                if (sreset_eq | PRESET_EQUAL_REG)
                    H_COE_FULL[idx] <= _COE_ONE_VAL;
                else if (LOAD_EQ_COE)
                    H_COE_FULL[idx] <= INIT_EQ_COE[idx];
                else if (NORMOLIZE_COE & H_COE_FULL[idx][_FULL_COE_WIDTH-1] & TEACH_EN_REG)
                    H_COE_FULL[idx] <= $signed(H_COE_FULL[idx]) + 1;
                else if (NORMOLIZE_COE & ~H_COE_FULL[idx][_FULL_COE_WIDTH-1] & TEACH_EN_REG)
                    H_COE_FULL[idx] <= $signed(H_COE_FULL[idx]) - 1;
                else if (EN_COE_COUNT & ~EQ_ERROR[idx] & TEACH_EN_REG)
                    H_COE_FULL[idx] <= $signed(H_COE_FULL[idx]) + 1;
                else if (EN_COE_COUNT & EQ_ERROR[idx] & TEACH_EN_REG)
                    H_COE_FULL[idx] <= $signed(H_COE_FULL[idx]) - 1;
            end
            
        // Rounding H_COE
            ROUNDER #(
                .DIN_WIDTH  (_FULL_COE_WIDTH ),
                .DOUT_WIDTH (_COE_WIDTH      )
            )_H_COE_RND(                 
                .CLK        (clk             ),
                .DIN        (H_COE_FULL[idx] ),
                .DIN_CE     (EN_COE_COUNT    ),
                .DOUT       (H_COE_ROUND[idx])
            );
            
            // Coe For Convolution
            always@(posedge clk) begin
                if (sreset_eq | PRESET_EQUAL_REG)
                    H_COE[_COE_WIDTH*(idx+1) - 1:_COE_WIDTH*idx] <= _COE_ONE_VAL[_FULL_COE_WIDTH-1:_FULL_COE_WIDTH-_COE_WIDTH];
                else if (i_sym_vld)
                    H_COE[_COE_WIDTH*(idx+1) - 1:_COE_WIDTH*idx] <= H_COE_ROUND[idx];
            end
        end else begin
            always@(posedge clk) begin
                if (sreset_eq | PRESET_EQUAL_REG)
                    H_COE_FULL[idx] <= 0;
                else if (LOAD_EQ_COE)
                    H_COE_FULL[idx] <= INIT_EQ_COE[idx];
                else if (NORMOLIZE_COE & H_COE_FULL[idx][_FULL_COE_WIDTH-1] & TEACH_EN_REG)
                    H_COE_FULL[idx] <= $signed(H_COE_FULL[idx]) + 1;
                else if (NORMOLIZE_COE & ~H_COE_FULL[idx][_FULL_COE_WIDTH-1] & TEACH_EN_REG)
                    H_COE_FULL[idx] <= $signed(H_COE_FULL[idx]) - 1;
                else if (EN_COE_COUNT & ~EQ_ERROR[idx] & TEACH_EN_REG)
                    H_COE_FULL[idx] <= $signed(H_COE_FULL[idx]) + 1;
                else if (EN_COE_COUNT & EQ_ERROR[idx] & TEACH_EN_REG)
                    H_COE_FULL[idx] <= $signed(H_COE_FULL[idx]) - 1;
            end
            
        // Rounding H_COE
            ROUNDER #(
                .DIN_WIDTH  (_FULL_COE_WIDTH ),
                .DOUT_WIDTH (_COE_WIDTH      )
            )_H_COE_RND(                 
                .CLK        (clk             ),
                .DIN        (H_COE_FULL[idx] ),
                .DIN_CE     (EN_COE_COUNT    ),
                .DOUT       (H_COE_ROUND[idx])
            );
            
            // Coe For Convolution
            always@(posedge clk) begin
                if (sreset_eq | PRESET_EQUAL_REG)
                    H_COE[_COE_WIDTH*(idx+1) - 1:_COE_WIDTH*idx] <= 0;
                else if (i_sym_vld)
                    H_COE[_COE_WIDTH*(idx+1) - 1:_COE_WIDTH*idx] <= H_COE_ROUND[idx];
            end
        end
        
    end
endgenerate

endmodule