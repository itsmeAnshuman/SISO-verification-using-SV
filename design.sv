module siso(clk, rst, in, out);
  
  input clk, rst, in;       // Clock, Reset, and Serial Input
  output reg out;           // Serial Output
  
  parameter N = 4;          // Depth/width of the shift register
  
  reg [N-1:0] temp;         // Internal shift register to hold the data

  // Sequential logic for shift operation
  always @(posedge clk or posedge rst) begin
    if (rst == 1)
      temp <= 0;            // On reset, clear all bits in the register
    else begin
      temp <= temp >> 1;    // Right shift the data
      temp[N-1] <= in;      // Insert new data at the MSB
    end
  end

  // Output the LSB as the serial output
  assign out = temp[0];

endmodule

interface siso_if();
  logic clock,rst;
  logic in;
  logic out;
endinterface

