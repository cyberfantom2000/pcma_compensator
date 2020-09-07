/********************************************************************************/
// Engineer:        Gushchin Aleksei
// Design Name:     Any
// Module Name:     Auxiliary functions
// Target Device:   Any
// Description:
//      Async BRAM FIFO 
// Dependencies:
//    None
// Revision:
//    $Revision:$
// Additional Comments:
//    None
/********************************************************************************/
`ifndef _AUX_FUNC
`define _AUX_FUNC
//***********************************************
//************************* Define
`define NULL 0
//************************* Functions
//// Simple Ceil Function
function real aux_ceil(input real in_var);
    real res_var;
    if (in_var > int'(in_var))
        res_var = real'(int'(in_var+0.5));
    else
        res_var = real'(int'(in_var));
    aux_ceil = res_var;
endfunction

//// Simple Floor Function
function real aux_floor(input real in_var);
    real res_var;
    if (in_var < int'(in_var))
        res_var = real'(int'(in_var-0.5));
    else
        res_var = real'(int'(in_var));
    aux_floor = res_var;
endfunction
//***********************************************
`endif //_AUXILIARY