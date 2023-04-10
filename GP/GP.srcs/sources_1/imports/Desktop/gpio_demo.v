`timescale 1ns / 1ps

module GPIO_demo(SW, BTN, CLK, LED, SSEG_CA, SSEG_AN, UART_TXD, RGB1_Red, RGB1_Green, RGB1_Blue, RGB2_Red, RGB2_Green, RGB2_Blue, micClk, micLRSel, micData, ampPWM, ampSD);
   input [15:0]     SW;
   input [4:0]      BTN;
   input            CLK;
   output [15:0]    LED;
   output [7:0]     SSEG_CA;
   output [7:0]     SSEG_AN;
   output           UART_TXD;
   output           RGB1_Red;
   output           RGB1_Green;
   output           RGB1_Blue;
   output           RGB2_Red;
   output           RGB2_Green;
   output           RGB2_Blue;
   output           micClk;
   output           micLRSel;
   input            micData;
   output           ampPWM;
   output           ampSD;
   
   
   parameter [2:0]       UART_STATE_TYPE_RST_REG = 0,
                         UART_STATE_TYPE_LD_INIT_STR = 1,
                         UART_STATE_TYPE_SEND_CHAR = 2,
                         UART_STATE_TYPE_RDY_LOW = 3,
                         UART_STATE_TYPE_WAIT_RDY = 4,
                         UART_STATE_TYPE_WAIT_BTN = 5,
                         UART_STATE_TYPE_LD_BTN_STR = 6;
   
   
   parameter [26:0] TMR_CNTR_MAX = 27'b101111101011110000100000000;
   parameter [3:0]  TMR_VAL_MAX = 4'b1001;
   
   parameter [17:0] RESET_CNTR_MAX = 18'b110000110101000000;
   
   parameter        MAX_STR_LEN = 16;
   
   parameter        WELCOME_STR_LEN = 16;
   parameter        BTN_STR_LEN = 15;

   reg [16*8-1:0]    WELCOME_STR;
   reg [15*8-1:0]    BTN_STR;
   initial begin 
        WELCOME_STR ="\n\rHello World!\r\n"; 
        BTN_STR = "\rHello, Xunxun\n";
    end 
   
   reg [26:0]       tmrCntr;
   
   reg [3:0]        tmrVal;
   
   reg [16*8-1:0]   sendStr;
   
   integer          strEnd;
   
   integer          strIndex;
   
   reg [3:0]        btnReg;
   wire             btnDetect;
   
   wire             uartRdy;
   reg              uartSend;
   reg [7:0]        uartData;
   wire             uartTX;
   
   reg [2:0]        uartState;
   
   wire [4:0]       btnDeBnc;
   
   reg [4:0]        clk_cntr_reg;
   
   reg              pwm_val_reg;
   
   reg [17:0]       reset_cntr;
   
   // LED and 7-segment control
   assign LED = (BTN[4] == 1'b0) ? SW : 16'b0000000000000000;
   assign SSEG_AN[3:0] = (BTN[4] == 1'b0) ? btnDeBnc[3:0] : 4'b1111;
   assign SSEG_AN[7:4] = (BTN[4] == 1'b0) ? btnDeBnc[3:0] : 4'b1111;
                         

   
   //counter 100,000,000 and then resets
   always @(posedge CLK)
   begin: timer_counter_process
      
      begin
         if ((tmrCntr == TMR_CNTR_MAX) | (BTN[4] == 1'b1))
            tmrCntr <= {27{1'b0}};
         else
            tmrCntr <= tmrCntr + 1;
      end
   end
   
   //display on 7-segment in every second
   always @(posedge CLK)
   begin: timer_inc_process
      
      begin
         if (BTN[4] == 1'b1)
            tmrVal <= {4{1'b0}};
         else if (tmrCntr == TMR_CNTR_MAX)
         begin
            // if tmrVal == 9 set to 0
            if (tmrVal == TMR_VAL_MAX)
               tmrVal <= {4{1'b0}};
            else
               tmrVal <= tmrVal + 1;
         end
      end
   end
   
   //select statements encodes the value of tmrVal to the cathode signals to display on 7-segment
   assign SSEG_CA = (tmrVal == 4'b0000) ? 8'b11000000 : 
                    (tmrVal == 4'b0001) ? 8'b11111001 : 
                    (tmrVal == 4'b0010) ? 8'b10100100 : 
                    (tmrVal == 4'b0011) ? 8'b10110000 : 
                    (tmrVal == 4'b0100) ? 8'b10011001 : 
                    (tmrVal == 4'b0101) ? 8'b10010010 : 
                    (tmrVal == 4'b0110) ? 8'b10000010 : 
                    (tmrVal == 4'b0111) ? 8'b11111000 : 
                    (tmrVal == 4'b1000) ? 8'b10000000 : 
                    (tmrVal == 4'b1001) ? 8'b10010000 : 
                    8'b11111111;
   
   
   //debounce the btn
   debouncer #((2 ** 16), 5) Inst_btn_debounce(
        .SIGNAL_I(BTN), 
        .CLK_I(CLK), 
        .SIGNAL_O(btnDeBnc));
   
   //Registers the debounced button signals, for edge detection.
   always @(posedge CLK)
   begin: btn_reg_process
         btnReg <= btnDeBnc[3:0];
   end
   
   //btnDetect goes high for a single clock cycle when a btn press is detected. 
   //This triggers a UART message to begin being sent.
   assign btnDetect = 
        ((
        (btnReg[0] == 1'b0 & btnDeBnc[0] == 1'b1) | 
        (btnReg[1] == 1'b0 & btnDeBnc[1] == 1'b1) | 
        (btnReg[2] == 1'b0 & btnDeBnc[2] == 1'b1) | 
        (btnReg[3] == 1'b0 & btnDeBnc[3] == 1'b1))) ? 1'b1 : 1'b0;
   
 
//----------------------------------------------------------
//------              UART Control                   -------
//----------------------------------------------------------
   
//   Messages are sent on reset and when a button is pressed.
//   This counter holds the UART state machine in reset for ~2 milliseconds.
//   This will complete transmission of any byte that may have been initiated during
 //  FPGA configuration due to the UART_TX line being pulled low, preventing a
 //  frame shift error from occuring during the first message.
   
   always @(posedge CLK)
      
      begin
         if ((reset_cntr == RESET_CNTR_MAX) | (uartState != UART_STATE_TYPE_RST_REG))
            reset_cntr <= {18{1'b0}};
         else
            reset_cntr <= reset_cntr + 1;
      end
   
   //Next Uart state logic
   always @(posedge CLK)
   begin: next_uartState_process
      
      begin
         //BTNC
         if (btnDeBnc[4] == 1'b1)
            uartState <= UART_STATE_TYPE_RST_REG;
         else
            case (uartState)
               UART_STATE_TYPE_RST_REG :
                  if (reset_cntr == RESET_CNTR_MAX)
                     uartState <= UART_STATE_TYPE_LD_INIT_STR;
               UART_STATE_TYPE_LD_INIT_STR :
                  uartState <= UART_STATE_TYPE_SEND_CHAR;
               UART_STATE_TYPE_SEND_CHAR :
                  uartState <= UART_STATE_TYPE_RDY_LOW;
               UART_STATE_TYPE_RDY_LOW :
                  uartState <= UART_STATE_TYPE_WAIT_RDY;
               UART_STATE_TYPE_WAIT_RDY :
                  if (uartRdy == 1'b1)
                  begin
                     if (strEnd == strIndex)
                        uartState <= UART_STATE_TYPE_WAIT_BTN;
                     else
                        uartState <= UART_STATE_TYPE_SEND_CHAR;
                  end
               UART_STATE_TYPE_WAIT_BTN :
                  if (btnDetect == 1'b1)
                     uartState <= UART_STATE_TYPE_LD_BTN_STR;
               UART_STATE_TYPE_LD_BTN_STR :
                  uartState <= UART_STATE_TYPE_SEND_CHAR;
               default :
                  uartState <= UART_STATE_TYPE_RST_REG;
            endcase
      end
   end
   
   //Loads the sendStr and strEnd signals when a LD state is is reached.
   always @(posedge CLK)
   begin: string_load_process
      
      begin
         if (uartState == UART_STATE_TYPE_LD_INIT_STR)
         begin
            sendStr <= WELCOME_STR;
            strEnd <= WELCOME_STR_LEN;
         end
         else if (uartState == UART_STATE_TYPE_LD_BTN_STR)
         begin
            sendStr <= BTN_STR;
            strEnd <= BTN_STR_LEN;
         end
      end
   end
   
   //Controls the strIndex signal so that it contains the index 
   //of the next character that needs to be sent over uart
   always @(posedge CLK)
   begin: char_count_process
      
      begin
         if (uartState == UART_STATE_TYPE_LD_INIT_STR | uartState == UART_STATE_TYPE_LD_BTN_STR)
            strIndex <= 0;
         else if (uartState == UART_STATE_TYPE_SEND_CHAR)
            strIndex <= strIndex + 1;
      end
   end
   
   //Controls the UART_TX_CTRL signals
   always @(posedge CLK)
   begin: char_load_process
      
      begin
         if (uartState == UART_STATE_TYPE_SEND_CHAR)
         begin
            uartSend <= 1'b1;
            uartData <= sendStr[strIndex];
         end
         else
            uartSend <= 1'b0;
      end
   end
   
   //Component used to send a byte of data over a UART line.
   UART_TX_CTRL Inst_UART_TX_CTRL(
       .SEND(uartSend), 
       .DATA(uartData), 
       .CLK(CLK), 
       .READY(uartRdy), 
       .UART_TX(uartTX));
   
   assign UART_TXD = uartTX;
   
   //RGB LED control
//   RGB_controller RGB_Core(
//       .GCLK(CLK), 
//       .RGB_LED_1_O({RGB1_Green, RGB1_Blue, RGB1_Red}), 
//       .RGB_LED_2_O({RGB2_Green, RGB2_Blue, RGB2_Red}));
   
   
//----------------------------------------------------------
//------              MIC Control                    -------
//----------------------------------------------------------

    //PDM data from the microphone is registered on the rising 
    //edge of every micClk, converting it to PWM. The PWM data
    //is then connected to the mono audio out circuit, causing 
    //the sound captured by the microphone to be played over 
    //the audio out port.
   always @(posedge CLK) 
        clk_cntr_reg <= clk_cntr_reg + 1;
   
   //micClk = 100MHz / 32 = 3.125 MHz
   assign micClk = clk_cntr_reg[4];
   
   
   always @(posedge CLK)
      begin
         if (clk_cntr_reg == 5'b01111)
            pwm_val_reg <= micData;
      end
   
   //assign micLRSel = 1'b0;
   assign ampPWM = pwm_val_reg;
   //assign ampSD = 1'b1;
   
endmodule
