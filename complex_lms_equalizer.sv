module complex_lms_equalizer #(
    parameter                   _DATA_WIDTH     = 16,
    parameter                   _COE_WIDTH      = 16,
    parameter                   _INV_COE_WIDTH  = 8,
    parameter                   _COE_NUM        = 19,
    parameter                   _PHASE_NUM      = 2 ,
    parameter                   _CROSS_EQ_TYPE  = 0 ,
    parameter                   _IN_SYM_DLY     = 7 
)(
    input                           clk             ,
    input                           reset           ,
    input                           preset_coe      ,   // reset coef to mind ...00100...
    input                           load_coe        ,   // load init coef. Ставится на 1 такт для загрузки 1 коэф.

// Equalization Error
    input                           i_error_I       ,
    input                           i_error_Q       ,
    input                           i_sym_vld       ,
    input                           i_teach_en      ,
    input   [9         :0]          i_norm_period   ,
// Input Data               
    input   [_DATA_WIDTH*_PHASE_NUM-1               :0] i_dtin_I   ,
    input   [_DATA_WIDTH*_PHASE_NUM-1               :0] i_dtin_Q   ,
    input                                               i_vldin    ,
	input   [_COE_WIDTH+_INV_COE_WIDTH-1            :0] i_coedata  ,  // preset coef data
// Output Data      
    output  [(_DATA_WIDTH+_COE_WIDTH+4)*_PHASE_NUM-1:0] o_dout_II  ,
    output  [(_DATA_WIDTH+_COE_WIDTH+4)*_PHASE_NUM-1:0] o_dout_QQ  ,
    output  [(_DATA_WIDTH+_COE_WIDTH+4)*_PHASE_NUM-1:0] o_dout_IQ  ,
    output  [(_DATA_WIDTH+_COE_WIDTH+4)*_PHASE_NUM-1:0] o_dout_QI  ,
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
reg     [_COE_WIDTH*_COE_NUM - 1       :0] H_COE_I, H_COE_Q                                      ;
wire    [_COE_WIDTH - 1                :0] H_COE_ROUND_I [_COE_NUM-1 :0]                         ;
wire    [_COE_WIDTH - 1                :0] H_COE_ROUND_Q [_COE_NUM-1 :0]                         ;
wire    [_FULL_DOUT_WIDTH*_PHASE_NUM- 1:0] DOUT_FULL_II, DOUT_FULL_QQ, DOUT_FULL_IQ, DOUT_FULL_QI;
reg     [_IN_SYM_DLY-1                 :0] DELAY_SIGSYM_SHFT_REG_I, DELAY_SIGSYM_SHFT_REG_Q      ;
reg     [_COE_NUM-1                    :0] SIGSYM_SHFT_REG_I, SIGSYM_SHFT_REG_Q                  ;
reg     [_COE_NUM-1                    :0] EQ_ERROR_I, EQ_ERROR_Q                                ; 
reg     [9                             :0] NORM_PERIOD_CNT                                       ;
reg     [9                             :0] NORM_PERIOD_VAL_REG                                   ;
reg     [_FULL_COE_WIDTH-1             :0] H_COE_FULL_I  [_COE_NUM-1 :0]                         ;
reg     [_FULL_COE_WIDTH-1             :0] H_COE_FULL_Q  [_COE_NUM-1 :0]                         ;
reg     PRESET_EQUAL_REG    ;
reg     TEACH_EN_REG        ;
wire    RST_NORM_PERIOD_CNT ;
wire    EN_COE_COUNT        ;
wire    NORMOLIZE_COE       ;
reg     sreset_eq         =1;

reg signed[_FULL_COE_WIDTH-1:0] INIT_EQ_COE [_COE_NUM-1 :0] ; // Регистр для последовательной загрузки коэф.
reg                             LOAD_EQ_COE                 ;

always@(posedge clk) begin
    if (reset)
        sreset_eq <= 1;
    else
        sreset_eq <= 0;
end

// ******************* MAIN Section ***************** //
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

// Convolution II
convolution #(
    ._HALF_BAND     (0          ),
    ._SYMMETRY_COE  (0          ),
    ._DATA_WIDTH    (_DATA_WIDTH),
    ._COE_WIDTH     (_COE_WIDTH ),
    ._COE_NUM       (_COE_NUM   ),
    ._PHASE_NUM     (_PHASE_NUM ),
    ._DECIMATION    (1          )
)
_CONVOLUTION_II(
    .clk            (clk         ),
    .reset          (sreset_eq   ),
    .i_h_port       (H_COE_I     ),
    .i_dtin         (i_dtin_I    ),
    .i_vldin        (i_vldin     ),
    .o_dout         (DOUT_FULL_II),
    .o_vldout       (o_vldout    )
);

// Convolution QQ
convolution #(
    ._HALF_BAND     (0          ),
    ._SYMMETRY_COE  (0          ),
    ._DATA_WIDTH    (_DATA_WIDTH),
    ._COE_WIDTH     (_COE_WIDTH ),
    ._COE_NUM       (_COE_NUM   ),
    ._PHASE_NUM     (_PHASE_NUM ),
    ._DECIMATION    (1          )
)
_CONVOLUTION_QQ(
    .clk            (clk         ),
    .reset          (sreset_eq   ),
    .i_h_port       (H_COE_Q     ),
    .i_dtin         (i_dtin_Q    ),
    .i_vldin        (i_vldin     ),
    .o_dout         (DOUT_FULL_QQ),
    .o_vldout       (            )   // Одинаково с II
);

// Convolution IQ
convolution #(
    ._HALF_BAND     (0          ),
    ._SYMMETRY_COE  (0          ),
    ._DATA_WIDTH    (_DATA_WIDTH),
    ._COE_WIDTH     (_COE_WIDTH ),
    ._COE_NUM       (_COE_NUM   ),
    ._PHASE_NUM     (_PHASE_NUM ),
    ._DECIMATION    (1          )
)
_CONVOLUTION_IQ(
    .clk            (clk         ),
    .reset          (sreset_eq   ),
    .i_h_port       (H_COE_Q     ),
    .i_dtin         (i_dtin_I    ),
    .i_vldin        (i_vldin     ),
    .o_dout         (DOUT_FULL_IQ),
    .o_vldout       (            )   // Одинаково с II
);

// Convolution QI
convolution #(
    ._HALF_BAND     (0          ),
    ._SYMMETRY_COE  (0          ),
    ._DATA_WIDTH    (_DATA_WIDTH),
    ._COE_WIDTH     (_COE_WIDTH ),
    ._COE_NUM       (_COE_NUM   ),
    ._PHASE_NUM     (_PHASE_NUM ),
    ._DECIMATION    (1          )
)
_CONVOLUTION_QI(
    .clk            (clk         ),
    .reset          (sreset_eq   ),
    .i_h_port       (H_COE_I     ),
    .i_dtin         (i_dtin_Q    ),
    .i_vldin        (i_vldin     ),
    .o_dout         (DOUT_FULL_QI),
    .o_vldout       (            )   // Одинаково с II
);

// module output
generate
    for(idx=0; idx<_PHASE_NUM; idx++) begin
        assign o_dout_II[_FULL_DOUT_WIDTH*(idx+1)-1 :_FULL_DOUT_WIDTH*idx] = DOUT_FULL_II[_FULL_DOUT_WIDTH*(idx+1)-1 :_FULL_DOUT_WIDTH*idx];
        assign o_dout_QQ[_FULL_DOUT_WIDTH*(idx+1)-1 :_FULL_DOUT_WIDTH*idx] = DOUT_FULL_QQ[_FULL_DOUT_WIDTH*(idx+1)-1 :_FULL_DOUT_WIDTH*idx];
        assign o_dout_IQ[_FULL_DOUT_WIDTH*(idx+1)-1 :_FULL_DOUT_WIDTH*idx] = DOUT_FULL_IQ[_FULL_DOUT_WIDTH*(idx+1)-1 :_FULL_DOUT_WIDTH*idx];
        assign o_dout_QI[_FULL_DOUT_WIDTH*(idx+1)-1 :_FULL_DOUT_WIDTH*idx] = DOUT_FULL_QI[_FULL_DOUT_WIDTH*(idx+1)-1 :_FULL_DOUT_WIDTH*idx];
    end
endgenerate

// Load initialization coe
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


//************ Сalculating NEW Error ***************
// Sig Symbol Line For 
always@(posedge clk) begin
    if (sreset_eq) begin
        for (i=0; i<_IN_SYM_DLY; i++) begin
            DELAY_SIGSYM_SHFT_REG_I[i] <= 0;
            DELAY_SIGSYM_SHFT_REG_Q[i] <= 0;
        end
    end else if (i_vldin) begin
        DELAY_SIGSYM_SHFT_REG_I[0] <= i_dtin_I[_DATA_WIDTH-1];
        DELAY_SIGSYM_SHFT_REG_Q[0] <= i_dtin_Q[_DATA_WIDTH-1];
        for (i=0; i<(_IN_SYM_DLY-1); i++) begin
            DELAY_SIGSYM_SHFT_REG_I[i+1] <= DELAY_SIGSYM_SHFT_REG_I[i];
            DELAY_SIGSYM_SHFT_REG_Q[i+1] <= DELAY_SIGSYM_SHFT_REG_Q[i];            
        end
    end
end
// Sig Symbol Shift REG
always@(posedge clk) begin
    if (sreset_eq) begin
        for (i=0; i<_COE_NUM; i++) begin
            SIGSYM_SHFT_REG_I[i] <= 0;
            SIGSYM_SHFT_REG_Q[i] <= 0;
        end
    end else if (i_sym_vld) begin
        SIGSYM_SHFT_REG_I[0] <= DELAY_SIGSYM_SHFT_REG_I[_IN_SYM_DLY-1];
        SIGSYM_SHFT_REG_Q[0] <= DELAY_SIGSYM_SHFT_REG_Q[_IN_SYM_DLY-1];
        for (i=0; i<(_COE_NUM-1); i++) begin
            SIGSYM_SHFT_REG_I[i+1] <= SIGSYM_SHFT_REG_I[i];
            SIGSYM_SHFT_REG_Q[i+1] <= SIGSYM_SHFT_REG_Q[i];
        end
    end
end
// NEW Equalization Error
generate
    for(idx = 0; idx < _COE_NUM; idx++) begin
        always@(posedge clk) begin
            if (sreset_eq) begin
                EQ_ERROR_I[idx] <= 0;
                EQ_ERROR_Q[idx] <= 0;
            end else if (i_sym_vld) begin
                EQ_ERROR_I[idx] <= SIGSYM_SHFT_REG_I[idx] ^ i_error_I;
                EQ_ERROR_Q[idx] <= SIGSYM_SHFT_REG_Q[idx] ^ i_error_Q;
            end
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

assign EN_COE_COUNT= i_sym_vld;

// COE Counting
generate
    for(idx=0; idx<_COE_NUM; idx++) begin
        if (idx == (_COE_NUM/2)) begin
            // I
            always@(posedge clk) begin
                if (sreset_eq | PRESET_EQUAL_REG)
                    H_COE_FULL_I[idx] <= _COE_ONE_VAL;                    
                else if (LOAD_EQ_COE) 
                    H_COE_FULL_I[idx] <= INIT_EQ_COE[idx];               
                else if (NORMOLIZE_COE & H_COE_FULL_I[idx][_FULL_COE_WIDTH-1] & TEACH_EN_REG)
                    H_COE_FULL_I[idx] <= $signed(H_COE_FULL_I[idx]) + 1;                
                else if (NORMOLIZE_COE & ~H_COE_FULL_I[idx][_FULL_COE_WIDTH-1] & TEACH_EN_REG)
                    H_COE_FULL_I[idx] <= $signed(H_COE_FULL_I[idx]) - 1;
                else if (EN_COE_COUNT & ~EQ_ERROR_I[idx] & TEACH_EN_REG)
                    H_COE_FULL_I[idx] <= $signed(H_COE_FULL_I[idx]) + 1;
                else if (EN_COE_COUNT & EQ_ERROR_I[idx] & TEACH_EN_REG)
                    H_COE_FULL_I[idx] <= $signed(H_COE_FULL_I[idx]) - 1;
            end
            // Q
            always@(posedge clk) begin
                if (sreset_eq | PRESET_EQUAL_REG)
                    H_COE_FULL_Q[idx] <= 0;//_COE_ONE_VAL;
                else if (LOAD_EQ_COE)
                    H_COE_FULL_Q[idx] <= 0;//INIT_EQ_COE[idx];
                else if (NORMOLIZE_COE & H_COE_FULL_Q[idx][_FULL_COE_WIDTH-1] & TEACH_EN_REG)
                    H_COE_FULL_Q[idx] <= $signed(H_COE_FULL_Q[idx]) + 1;
                else if (NORMOLIZE_COE & ~H_COE_FULL_Q[idx][_FULL_COE_WIDTH-1] & TEACH_EN_REG)
                    H_COE_FULL_Q[idx] <= $signed(H_COE_FULL_Q[idx]) - 1;
                else if (EN_COE_COUNT & ~EQ_ERROR_Q[idx] & TEACH_EN_REG)
                    H_COE_FULL_Q[idx] <= $signed(H_COE_FULL_Q[idx]) + 1;                    
                else if (EN_COE_COUNT & EQ_ERROR_Q[idx] & TEACH_EN_REG)
                    H_COE_FULL_Q[idx] <= $signed(H_COE_FULL_Q[idx]) - 1;                    
            end
            
        // Rounding H_COE_I
            ROUNDER #(
                .DIN_WIDTH  (_FULL_COE_WIDTH ),
                .DOUT_WIDTH (_COE_WIDTH      )
            )_H_COE_RND_I(                 
                .CLK        (clk               ),
                .DIN        (H_COE_FULL_I[idx] ),
                .DIN_CE     (EN_COE_COUNT      ),
                .DOUT       (H_COE_ROUND_I[idx])
            );
            
        // Rounding H_COE_Q
            ROUNDER #(
                .DIN_WIDTH  (_FULL_COE_WIDTH ),
                .DOUT_WIDTH (_COE_WIDTH      )
            )_H_COE_RND_Q(                 
                .CLK        (clk               ),
                .DIN        (H_COE_FULL_Q[idx] ),
                .DIN_CE     (EN_COE_COUNT      ),
                .DOUT       (H_COE_ROUND_Q[idx])
            );
            
            // Coe For Convolution
            always@(posedge clk) begin
                if (sreset_eq | PRESET_EQUAL_REG) begin
                    H_COE_I[_COE_WIDTH*(idx+1) - 1:_COE_WIDTH*idx] <= _COE_ONE_VAL[_FULL_COE_WIDTH-1:_FULL_COE_WIDTH-_COE_WIDTH];
                    H_COE_Q[_COE_WIDTH*(idx+1) - 1:_COE_WIDTH*idx] <= _COE_ONE_VAL[_FULL_COE_WIDTH-1:_FULL_COE_WIDTH-_COE_WIDTH];
                end else if (i_sym_vld) begin
                    H_COE_I[_COE_WIDTH*(idx+1) - 1:_COE_WIDTH*idx] <= H_COE_ROUND_I[idx];
                    H_COE_Q[_COE_WIDTH*(idx+1) - 1:_COE_WIDTH*idx] <= H_COE_ROUND_Q[idx];
                end
            end
        end else begin
            // I
            always@(posedge clk) begin
                if (sreset_eq | PRESET_EQUAL_REG)
                    H_COE_FULL_I[idx] <= 0;
                else if (LOAD_EQ_COE)
                    H_COE_FULL_I[idx] <= INIT_EQ_COE[idx];
                else if (NORMOLIZE_COE & H_COE_FULL_I[idx][_FULL_COE_WIDTH-1] & TEACH_EN_REG)
                    H_COE_FULL_I[idx] <= $signed(H_COE_FULL_I[idx]) + 1;
                else if (NORMOLIZE_COE & ~H_COE_FULL_I[idx][_FULL_COE_WIDTH-1] & TEACH_EN_REG)
                    H_COE_FULL_I[idx] <= $signed(H_COE_FULL_I[idx]) - 1;
                else if (EN_COE_COUNT & ~EQ_ERROR_I[idx] & TEACH_EN_REG)
                    H_COE_FULL_I[idx] <= $signed(H_COE_FULL_I[idx]) + 1;
                else if (EN_COE_COUNT & EQ_ERROR_I[idx] & TEACH_EN_REG)
                    H_COE_FULL_I[idx] <= $signed(H_COE_FULL_I[idx]) - 1;
            end
            // Q
            always@(posedge clk) begin
                if (sreset_eq | PRESET_EQUAL_REG)
                    H_COE_FULL_Q[idx] <= 0;
                else if (LOAD_EQ_COE)
                    H_COE_FULL_Q[idx] <= 0;//INIT_EQ_COE[idx];
                else if (NORMOLIZE_COE & H_COE_FULL_Q[idx][_FULL_COE_WIDTH-1] & TEACH_EN_REG)
                    H_COE_FULL_Q[idx] <= $signed(H_COE_FULL_Q[idx]) + 1;
                else if (NORMOLIZE_COE & ~H_COE_FULL_Q[idx][_FULL_COE_WIDTH-1] & TEACH_EN_REG)
                    H_COE_FULL_Q[idx] <= $signed(H_COE_FULL_Q[idx]) - 1;
                else if (EN_COE_COUNT & ~EQ_ERROR_Q[idx] & TEACH_EN_REG)
                    H_COE_FULL_Q[idx] <= $signed(H_COE_FULL_Q[idx]) + 1;                    
                else if (EN_COE_COUNT & EQ_ERROR_Q[idx] & TEACH_EN_REG)
                    H_COE_FULL_Q[idx] <= $signed(H_COE_FULL_Q[idx]) - 1;                    
            end

        // Rounding H_COE_I
            ROUNDER #(
                .DIN_WIDTH  (_FULL_COE_WIDTH ),
                .DOUT_WIDTH (_COE_WIDTH      )
            )_H_COE_RND_I(                 
                .CLK        (clk               ),
                .DIN        (H_COE_FULL_I[idx] ),
                .DIN_CE     (EN_COE_COUNT      ),
                .DOUT       (H_COE_ROUND_I[idx])
            );
            
        // Rounding H_COE_Q
            ROUNDER #(
                .DIN_WIDTH  (_FULL_COE_WIDTH ),
                .DOUT_WIDTH (_COE_WIDTH      )
            )_H_COE_RND_Q(                 
                .CLK        (clk               ),
                .DIN        (H_COE_FULL_Q[idx] ),
                .DIN_CE     (EN_COE_COUNT      ),
                .DOUT       (H_COE_ROUND_Q[idx])
            );
            
            // Coe For Convolution
            always@(posedge clk) begin
                if (sreset_eq | PRESET_EQUAL_REG) begin
                    H_COE_I[_COE_WIDTH*(idx+1) - 1:_COE_WIDTH*idx] <= 0;
                    H_COE_Q[_COE_WIDTH*(idx+1) - 1:_COE_WIDTH*idx] <= 0;
                end else if (i_sym_vld) begin
                    H_COE_I[_COE_WIDTH*(idx+1) - 1:_COE_WIDTH*idx] <= H_COE_ROUND_I[idx];
                    H_COE_Q[_COE_WIDTH*(idx+1) - 1:_COE_WIDTH*idx] <= H_COE_ROUND_Q[idx];
                end
            end
        end  
        
    end
endgenerate

endmodule

