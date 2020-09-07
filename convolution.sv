`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/30/2017 03:22:08 PM
// Design Name: 
// Module Name: convolution
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
`include "aux_func.svh"

module convolution #(
    parameter                   _HALF_BAND      = 0 ,
    parameter                   _SYMMETRY_COE   = 0 ,
    parameter                   _DATA_WIDTH     = 16,
    parameter                   _COE_WIDTH      = 16,
    parameter                   _COE_NUM        = 17,
    parameter                   _PHASE_NUM      = 1 ,
    parameter                   _DECIMATION     = 1 
)
(
    input                           clk             ,
    input                           reset           ,
// Coefficients
    input   [_COE_WIDTH*_COE_NUM-1      :0]                             i_h_port ,
// Input Data               
    input   [_DATA_WIDTH*_PHASE_NUM-1   :0]                             i_dtin  ,
    input                                                               i_vldin ,
// Output Data  
    output  [(_DATA_WIDTH+_COE_WIDTH+3+1)*_PHASE_NUM/_DECIMATION-1:0]   o_dout  ,
    output                                                              o_vldout
    );

//*************** CONSTANTS AND PARAMETERS **********
integer i;
localparam _DEC_MULT    = _HALF_BAND      ?  4 :
                          _SYMMETRY_COE   ?  2 :
                                             1 ;

localparam _ACT_COE_NUM = _HALF_BAND      ?  int'(aux_ceil(real'(_COE_NUM)/2.0)):
                          _SYMMETRY_COE   ?  int'(aux_ceil(real'(_COE_NUM)/2.0)):
                                             _COE_NUM                           ;

localparam _SHIFT_REG_DEPTH = _PHASE_NUM*(int'(aux_ceil(real'(_COE_NUM)/real'(_PHASE_NUM)))+1)  ;
localparam _MULT_NUM        = ((_COE_NUM-1)/_DEC_MULT) + 1                                      ;
localparam _OUT_PHASE_NUM   = _PHASE_NUM/_DECIMATION                                            ;
localparam _OUT_DWIDTH      = _DATA_WIDTH+_COE_WIDTH+3+1                                        ;
localparam _SHIFT_NXT_PH    = _SHIFT_REG_DEPTH-_PHASE_NUM                                       ;
localparam _MAX_COE_WIDTH   = 16                                                                ;

localparam _SUM_STAGE       = $clog2(_MULT_NUM) ;
localparam _VALID_DELAY     = 5 + _SUM_STAGE    ;
// Assign Depth for each SUMM Stage
function bit [_SUM_STAGE - 1 : 0] [_SUM_STAGE - 1 : 0] STAGE_CLC(input integer sum_num);
    bit [_SUM_STAGE - 1 : 0] [_SUM_STAGE - 1 : 0] val_out;
    integer ii;
    val_out[0] = int'(aux_ceil(real'(sum_num) / 2));
    for(ii=1;ii<_SUM_STAGE; ii++)begin
        val_out[ii] = int'(aux_ceil(real'(val_out[ii-1]) / 2));
    end
    STAGE_CLC = val_out;
endfunction
   
localparam bit [_SUM_STAGE - 1 : 0] [_SUM_STAGE - 1 : 0] _SUM_IN_STAGE =  STAGE_CLC(_MULT_NUM);//'{1, 2, 3, 5};//
// ******************* Declarations *****************
generate
    genvar idx;
    for(idx=0; idx<_SUM_STAGE; idx++) begin : gen_sum
        reg signed [_DATA_WIDTH+_COE_WIDTH+idx :0] SUM_STAGE [_OUT_PHASE_NUM-1     :0] [_SUM_IN_STAGE[idx]-1 :0];
    end
endgenerate

reg                         VLDIN_REG      ;
//reg [_VALID_DELAY-1  :0]    VLDIN_SHIFT_REG;
//reg         [4  :0]     RRST_SHIFT_REG

reg  signed [_DATA_WIDTH-1              :0] DTIN_REG_PH     [_PHASE_NUM-1       :0]                     ;
wire signed [_COE_WIDTH-1               :0] H_COE           [_COE_NUM-1         :0]                     ;
reg  signed [_DATA_WIDTH-1              :0] PHASE_SHIFT_REG [_SHIFT_REG_DEPTH-1 :0]                     ;
wire signed [_DATA_WIDTH-1              :0] PH_Z_REG        [_PHASE_NUM-1       :0] [_COE_NUM-1     :0] ;
reg  signed [_DATA_WIDTH                :0] SYM_SUM_REG     [_OUT_PHASE_NUM-1   :0] [_MULT_NUM-1    :0] ;
reg  signed [_DATA_WIDTH+_COE_WIDTH-1   :0] MULT_RESULT     [_OUT_PHASE_NUM-1   :0] [_MULT_NUM-1    :0] ;
reg  signed [_DATA_WIDTH+_COE_WIDTH-1   :0] MULT_RESULT_REG [_OUT_PHASE_NUM-1   :0] [_MULT_NUM-1    :0] ;
// ******************* MAIN Section *****************
generate 
    for(idx=0; idx<_COE_NUM; idx++)begin
        assign H_COE[idx] = i_h_port[_COE_WIDTH*(idx+1)-1   :_COE_WIDTH*idx];
    end
endgenerate 
/*************************************************
******************* FIR FILTER *******************
*************************************************/
generate
    genvar k;
    for (k=0; k<_PHASE_NUM; k++)
        // Input Array Phase Regs
        always@(posedge clk)begin
            if (reset) begin
                DTIN_REG_PH[k] <= 0;
            end else begin
                if (i_vldin) begin
                    DTIN_REG_PH[k][_DATA_WIDTH-1:0] <= (i_dtin[_DATA_WIDTH*(k+1)-1:_DATA_WIDTH*k]);
                end
            end
        end
endgenerate
// Input Valid REG
//always@(posedge clk)begin
//    if (reset) begin
//        VLDIN_REG <=0;
//    end else begin
//        VLDIN_REG <= i_vldin;
//    end
//end
// Parallel Shif REG
always@(posedge clk)begin
    if (reset) begin
        for (i=0; i<_SHIFT_REG_DEPTH; i++)
                PHASE_SHIFT_REG[i] <= 0;
    end else if (i_vldin) begin
        for (i=0; i<_SHIFT_NXT_PH; i++) begin
            PHASE_SHIFT_REG[i+_PHASE_NUM] <= PHASE_SHIFT_REG[i];
        end
        for (i=0; i<_PHASE_NUM; i++) begin
            PHASE_SHIFT_REG[i] <= DTIN_REG_PH[_PHASE_NUM-1-i];
        end
    end
end
// Phae Z Delay Buffers
generate
    genvar l;
    for (l=0; l<_PHASE_NUM; l++) begin
        assign PH_Z_REG[_PHASE_NUM-l - 1][_COE_NUM-1:0] = PHASE_SHIFT_REG[_COE_NUM+l-1:l];
    end
endgenerate
// Symmetry Summ
generate
    genvar j;
// Polyphase Convilution
    for(l=0; l<_OUT_PHASE_NUM; l++)begin
        for (j=0; j<_MULT_NUM; j++)begin
            if (_HALF_BAND) begin
            // IF HALFEBAND Filter
            // ***********************************
                if (j == _MULT_NUM-1) begin
                    always@(posedge clk) begin
                        if (reset)
                            SYM_SUM_REG[l][j] <= 0;
                        else if (i_vldin)
                            SYM_SUM_REG[l][j] <= PH_Z_REG[l*_DECIMATION][2*j];
                    end
                    always@(posedge clk) begin
                        if (reset)
                            MULT_RESULT[l][j]<= 0;
                        else if (i_vldin)
                            MULT_RESULT[l][j]<= (SYM_SUM_REG[l][j]>>>1);
                    end
                end else begin
                    always@(posedge clk) begin
                        if (reset)
                            SYM_SUM_REG[l][j] <= 0;
                        else if (i_vldin)
                            SYM_SUM_REG[l][j] <= PH_Z_REG[l*_DECIMATION][2*j+1] + PH_Z_REG[l*_DECIMATION][(_COE_NUM-2) - 2*j];
                    end
                    always@(posedge clk) begin
                        if (reset)
                            MULT_RESULT[l][j]<= 0;
                        else if (i_vldin)
                            MULT_RESULT[l][j]<= SYM_SUM_REG[l][j]*H_COE[2*j+1];
                    end
                end
            end else if (_SYMMETRY_COE) begin
            // IF simple SYMMETRY Filter
            // ***********************************
                always@(posedge clk) begin
                    if (reset)
                        SYM_SUM_REG[l][j] <= 0;
                    else if (i_vldin)
                        SYM_SUM_REG[l][j] <= PH_Z_REG[l*_DECIMATION][j] + PH_Z_REG[l*_DECIMATION][(_COE_NUM-1) - j];
                end
                always@(posedge clk) begin
                    if (reset)
                        MULT_RESULT[l][j]<= 0;
                    else if (i_vldin)
                        MULT_RESULT[l][j]<= SYM_SUM_REG[l][j]*H_COE[j];
                end
            end else begin
            // IF ASYMMETRY Filter
            // ***********************************
                 always@(posedge clk) begin
                    if (reset)
                        SYM_SUM_REG[l][j] <= 0;
                    else if (i_vldin)
                        SYM_SUM_REG[l][j] <= PH_Z_REG[l*_DECIMATION][j];
                 end
                 always@(posedge clk) begin
                    if (reset)
                        MULT_RESULT[l][j]<= 0;
                    else if (i_vldin)
                        MULT_RESULT[l][j]<= SYM_SUM_REG[l][j]*H_COE[j];
                 end
            end
            // Pipe Reg After Multiplication
            always@(posedge clk) begin
                if (reset)
                    MULT_RESULT_REG[l][j]<= 0;
                else if (i_vldin)
                    MULT_RESULT_REG[l][j]<= MULT_RESULT[l][j];
            end
        end
    // SUM Comnvolution Pipe .loop1.loop2
        genvar idx2;
        for(idx=0; idx<_SUM_STAGE; idx++) begin
            if (idx == 0) begin
                for(idx2=0; idx2<_SUM_IN_STAGE[idx]; idx2++) begin
                    if ((idx2 == (_SUM_IN_STAGE[idx] - 1) && (_MULT_NUM % 2)) || (_SUM_IN_STAGE[idx] == 1)) begin
                        always@(posedge clk) begin
                            if (reset)
                                gen_sum[idx].SUM_STAGE[l][idx2] <= 0;
                            else if (i_vldin)
                                gen_sum[idx].SUM_STAGE[l][idx2] <=MULT_RESULT_REG[l][2*idx2];
                        end
                    end else begin
                       always@(posedge clk) begin
                            if (reset)
                                gen_sum[idx].SUM_STAGE[l][idx2] <= 0;
                            else if (i_vldin)
                                gen_sum[idx].SUM_STAGE[l][idx2] <= MULT_RESULT_REG[l][2*idx2] + MULT_RESULT_REG[l][2*idx2+1];
                       end
                    end
                end
            end else if (idx == (_SUM_STAGE-1)) begin
                always@(posedge clk)begin
                    if (reset)
                        gen_sum[_SUM_STAGE-1].SUM_STAGE[l][0] <= 0;
                    else if (i_vldin)
                        gen_sum[_SUM_STAGE-1].SUM_STAGE[l][0] <=gen_sum[idx-1].SUM_STAGE[l][0] + gen_sum[idx-1].SUM_STAGE[l][1];
                end
            end else begin
                for(idx2=0; idx2<_SUM_IN_STAGE[idx]; idx2++) begin
                    if (((idx2 == (_SUM_IN_STAGE[idx] - 1))&&(_SUM_IN_STAGE[idx-1] % 2))|| (_SUM_IN_STAGE[idx] == 1)) begin
                        always@(posedge clk) begin
                            if (reset)
                                gen_sum[idx].SUM_STAGE[l][idx2] <= 0;
                            else if (i_vldin)
                                gen_sum[idx].SUM_STAGE[l][idx2] <= gen_sum[idx-1].SUM_STAGE[l][2*idx2];
                        end
                    end else begin
                       always@(posedge clk) begin
                            if (reset)
                                gen_sum[idx].SUM_STAGE[l][idx2] <= 0;
                            else if (i_vldin)
                                gen_sum[idx].SUM_STAGE[l][idx2] <= gen_sum[idx-1].SUM_STAGE[l][2*idx2] + gen_sum[idx-1].SUM_STAGE[l][2*idx2+1];
                       end
                    end
                end
            end
        end
        
        assign o_dout[_OUT_DWIDTH*(l+1)-1:_OUT_DWIDTH*l] = gen_sum[_SUM_STAGE-1].SUM_STAGE[l][0];
    end
endgenerate

// Valid Data Shift REG
//always@(posedge clk)begin
//    if (reset)begin
//        for(i=0; i<8; i++)
//            VLDIN_SHIFT_REG[i] <= 0;
//    end else begin
//        for (i=0; i<(_VALID_DELAY-1); i++)
//            VLDIN_SHIFT_REG[i+1] <= VLDIN_SHIFT_REG[i];
//        VLDIN_SHIFT_REG[0] <= VLDIN_REG;
//    end
//end
assign o_vldout = i_vldin;

endmodule
