`timescale 1ns / 1ps

module RGB_controller(GCLK, RGB_LED_1_O, RGB_LED_2_O);
   input            GCLK;
   output [2:0]     RGB_LED_1_O;
   output [2:0]     RGB_LED_2_O;
   
   parameter [7:0]  window = 8'b11111111;
   reg [7:0]        windowcount;
   
   parameter [19:0] deltacountMax = 1000000;
   reg [19:0]       deltacount;
   
   parameter [8:0]  valcountMax = 9'b101111111;
   reg [8:0]        valcount;
   
   wire [7:0]       incVal;
   wire [7:0]       decVal;
   
   wire [7:0]       redVal;
   wire [7:0]       greenVal;
   wire [7:0]       blueVal;
   
   wire [7:0]       redVal2;
   wire [7:0]       greenVal2;
   wire [7:0]       blueVal2;
   
   reg [2:0]        rgbLedReg1;
   reg [2:0]        rgbLedReg2;
   
   
   always @(posedge GCLK)
   begin: window_counter
      
      begin
         if (windowcount < (window))
            windowcount <= windowcount + 1;
         else
            windowcount <= {8{1'b0}};
      end
   end
   
   
   always @(posedge GCLK)
   begin: color_change_counter
      
      begin
         if (deltacount < deltacountMax)
            deltacount <= deltacount + 1;
         else
            deltacount <= {20{1'b0}};
      end
   end
   
   
   always @(posedge GCLK)
   begin: color_intensity_counter
      
      begin
         if (deltacount == 0)
         begin
            if (valcount < valcountMax)
               valcount <= valcount + 1;
            else
               valcount <= {9{1'b0}};
         end
      end
   end
   
   assign incVal = {1'b0, valcount[6:0]};
   
   assign decVal[7] = 1'b0;
   assign decVal[6] = (~(valcount[6]));
   assign decVal[5] = (~(valcount[5]));
   assign decVal[4] = (~(valcount[4]));
   assign decVal[3] = (~(valcount[3]));
   assign decVal[2] = (~(valcount[2]));
   assign decVal[1] = (~(valcount[1]));
   assign decVal[0] = (~(valcount[0]));
   
   assign redVal = ((valcount[8:7] == 2'b00)) ? incVal : 
                   ((valcount[8:7] == 2'b01)) ? decVal : 
                   {8{1'b0}};
   assign greenVal = ((valcount[8:7] == 2'b00)) ? decVal : 
                     ((valcount[8:7] == 2'b01)) ? {8{1'b0}} : 
                     incVal;
   assign blueVal = ((valcount[8:7] == 2'b00)) ? {8{1'b0}} : 
                    ((valcount[8:7] == 2'b01)) ? incVal : 
                    decVal;
   
   assign redVal2 = ((valcount[8:7] == 2'b00)) ? incVal : 
                    ((valcount[8:7] == 2'b01)) ? decVal : 
                    {8{1'b0}};
   assign greenVal2 = ((valcount[8:7] == 2'b00)) ? decVal : 
                      ((valcount[8:7] == 2'b01)) ? {8{1'b0}} : 
                      incVal;
   assign blueVal2 = ((valcount[8:7] == 2'b00)) ? {8{1'b0}} : 
                     ((valcount[8:7] == 2'b01)) ? incVal : 
                     decVal;
   
   
   always @(posedge GCLK)
   begin: red_comp
      
      begin
         if ((redVal) > windowcount)
            rgbLedReg1[2] <= 1'b1;
         else
            rgbLedReg1[2] <= 1'b0;
      end
   end
   
   
   always @(posedge GCLK)
   begin: green_comp
      
      begin
         if ((greenVal) > windowcount)
            rgbLedReg1[1] <= 1'b1;
         else
            rgbLedReg1[1] <= 1'b0;
      end
   end
   
   
   always @(posedge GCLK)
   begin: blue_comp
      
      begin
         if ((blueVal) > windowcount)
            rgbLedReg1[0] <= 1'b1;
         else
            rgbLedReg1[0] <= 1'b0;
      end
   end
   
   
   always @(posedge GCLK)
   begin: red2_comp
      
      begin
         if ((redVal2) > windowcount)
            rgbLedReg2[2] <= 1'b1;
         else
            rgbLedReg2[2] <= 1'b0;
      end
   end
   
   
   always @(posedge GCLK)
   begin: green2_comp
      
      begin
         if ((greenVal2) > windowcount)
            rgbLedReg2[1] <= 1'b1;
         else
            rgbLedReg2[1] <= 1'b0;
      end
   end
   
   
   always @(posedge GCLK)
   begin: blue2_comp
      
      begin
         if ((blueVal2) > windowcount)
            rgbLedReg2[0] <= 1'b1;
         else
            rgbLedReg2[0] <= 1'b0;
      end
   end
   
   assign RGB_LED_1_O = rgbLedReg1;
   assign RGB_LED_2_O = rgbLedReg2;
   
endmodule

