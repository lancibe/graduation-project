`timescale 1ns / 1ps
/*
----------------------------------------------------------------------------
--	This component may be used to transfer data over a UART device. It will
-- serialize a byte of data and transmit it over a TXD line. The serialized
-- data has the following characteristics:
--         *9600 Baud Rate
--         *8 data bits, LSB first
--         *1 stop bit
--         *no parity
--         				
-- Port Descriptions:
--
--    SEND - Used to trigger a send operation. The upper layer logic should 
--           set this signal high for a single clock cycle to trigger a 
--           send. When this signal is set high DATA must be valid . Should 
--           not be asserted unless READY is high.
--    DATA - The parallel data to be sent. Must be valid the clock cycle
--           that SEND has gone high.
--    CLK  - A 100 MHz clock is expected
--   READY - This signal goes low once a send operation has begun and
--           remains low until it has completed and the module is ready to
--           send another byte.
-- UART_TX - This signal should be routed to the appropriate TX pin of the 
--           external UART device.
--   
----------------------------------------------------------------------------
*/
module UART_TX_CTRL(SEND, DATA, CLK, READY, UART_TX);
   input            SEND;
   input [7:0]      DATA;
   input            CLK;
   output           READY;
   output           UART_TX;
   
   
   parameter [1:0]  TX_STATE_TYPE_RDY = 0,
                    TX_STATE_TYPE_LOAD_BIT = 1,
                    TX_STATE_TYPE_SEND_BIT = 2;
   
   parameter [13:0] BIT_TMR_MAX = 14'b10100010110000;
   parameter        BIT_INDEX_MAX = 10;
   
   //Counter that keeps track of the number of clock cycles the current bit has been held stable over the
   //UART TX line. It is used to signal when the ne
   reg [13:0]       bitTmr;
   
   //combinatorial logic that goes high when bitTmr has counted to the proper value to ensure
   //a 9600 baud rate
   wire             bitDone;
   
   //Contains the index of the next bit in txData that needs to be transferred
   integer          bitIndex;
   
   //a register that holds the current data being sent over the UART TX line
   reg              txBit;
   
   //A register that contains the whole data packet to be sent, including start and stop bits. 
   reg [9:0]        txData;
   
   reg [1:0]        txState;
   
   
   //Next state logic
   always @(posedge CLK)
   begin: next_txState_process
      
         case (txState)
            TX_STATE_TYPE_RDY :
               if (SEND == 1'b1)
                  txState <= TX_STATE_TYPE_LOAD_BIT;
            TX_STATE_TYPE_LOAD_BIT :
               txState <= TX_STATE_TYPE_SEND_BIT;
            TX_STATE_TYPE_SEND_BIT :
               if (bitDone == 1'b1)
               begin
                  if (bitIndex == BIT_INDEX_MAX)
                     txState <= TX_STATE_TYPE_RDY;
                  else
                     txState <= TX_STATE_TYPE_LOAD_BIT;
               end
            default : //should never be reached
               txState <= TX_STATE_TYPE_RDY;
         endcase
   end
   
   //counter
   always @(posedge CLK)
   begin: bit_timing_process
      
      begin
         if (txState == TX_STATE_TYPE_RDY)
            bitTmr <= {14{1'b0}};
         else
            if (bitDone == 1'b1)
               bitTmr <= {14{1'b0}};
            else
               bitTmr <= bitTmr + 1;
      end
   end
   
   assign bitDone = (bitTmr == BIT_TMR_MAX) ? 1'b1 : 1'b0;
   
   
   always @(posedge CLK)
   begin: bit_counting_process
      
      begin
         if (txState == TX_STATE_TYPE_RDY)
            bitIndex <= 0;
         else if (txState == TX_STATE_TYPE_LOAD_BIT)
            bitIndex <= bitIndex + 1;
      end
   end
   
   
   always @(posedge CLK)
   begin: tx_data_latch_process
      
      begin
         if (SEND == 1'b1)
            txData <= {1'b1, DATA, 1'b0};
      end
   end
   
   
   always @(posedge CLK)
   begin: tx_bit_process
      
      begin
         if (txState == TX_STATE_TYPE_RDY)
            txBit <= 1'b1;
         else if (txState == TX_STATE_TYPE_LOAD_BIT)
            txBit <= txData[bitIndex];
      end
   end
   
   assign UART_TX = txBit;
   assign READY = ((txState == TX_STATE_TYPE_RDY)) ? 1'b1 : 1'b0;
   
endmodule

