`timescale 1ns / 1ps
/*
----------------------------------------------------------------------------
-- This component is used to debounce signals. It is designed to
-- independently debounce a variable number of signals, the number of which
-- are set using the PORT_WIDTH generic. Debouncing is done by only 
-- registering a change in a button state if it remains constant for 
-- the number of clocks determined by the DEBNC_CLOCKS generic. 
--         				
-- Generic Descriptions:
--
--   PORT_WIDTH - The number of signals to debounce. determines the width
--                of the SIGNAL_I and SIGNAL_O std_logic_vectors
--   DEBNC_CLOCKS - The number of clocks (CLK_I) to wait before registering
--                  a change.
--
-- Port Descriptions:
--
--   SIGNAL_I - The input signals. A vector of width equal to PORT_WIDTH
--   CLK_I  - Input clock
--   SIGNAL_O - The debounced signals. A vector of width equal to PORT_WIDTH
--   											
----------------------------------------------------------------------------
*/
module debouncer(SIGNAL_I, CLK_I, SIGNAL_O);
   parameter               DEBNC_CLOCKS = 2 ** 16;
   parameter               PORT_WIDTH = 5;
   input [(PORT_WIDTH-1):0]     SIGNAL_I;
   input                        CLK_I;
   output [(PORT_WIDTH-1):0]    SIGNAL_O;
   
   //to calculate the data width
   function integer log2;                                                   
        input integer number; 
        begin
            log2=0;
            while(2**log2<number) begin 
                log2=log2+1;
            end
        end
    endfunction // log2

   parameter                    CNTR_WIDTH = log2(DEBNC_CLOCKS);
   parameter [(CNTR_WIDTH-1):0] CNTR_MAX = DEBNC_CLOCKS - 1;
   
   reg [(CNTR_WIDTH-1):0]       sig_cntrs_ary[0:(PORT_WIDTH-1)];
   
   reg [(PORT_WIDTH-1):0]       sig_out_reg;
   
   
   always @(posedge CLK_I)
   begin: debounce_process
      integer  index;
      for (index = 0; index <= (PORT_WIDTH - 1); index = index + 1)
        if (sig_cntrs_ary[index] == CNTR_MAX)
           sig_out_reg[index] <= (~(sig_out_reg[index]));
   end
   
   
   always @(posedge CLK_I)
   begin: counter_process
      integer index;
      for (index = 0; index <= (PORT_WIDTH - 1); index = index + 1)
        if ((sig_out_reg[index] == 1'b1) ^ (SIGNAL_I[index] == 1'b1))
        begin
           if (sig_cntrs_ary[index] == CNTR_MAX)
              sig_cntrs_ary[index] <= 1'b0;
           else
              sig_cntrs_ary[index] <= sig_cntrs_ary[index] + 1;
        end
        else
           sig_cntrs_ary[index] <= 1'b0;
   end
   
   assign SIGNAL_O = sig_out_reg;
   
endmodule
