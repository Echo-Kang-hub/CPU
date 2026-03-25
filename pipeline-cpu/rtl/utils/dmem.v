`ifndef __DM_V__   
`define __DM_V__
`timescale 1ns / 1ps
`include "definition.vh"

module dmem (
    input  wire        clk,
    input  wire        DMWr,
    input  wire [2:0]  DMType, 
    input  wire [31:0] addr, 
    input  wire [31:0] din,
    output wire [31:0] dout
);
    reg [31:0] RAM [0:127];
    
    integer i;
    initial begin
        for (i = 0; i < 128; i = i + 1) RAM[i] = 32'h0;
    end

    // 同步写(Store)
    wire [6:0] word_addr = addr[8:2]; 
    
    always @(posedge clk) begin
        if (DMWr) begin
            case (DMType)
                `DM_BYTE, `DM_BYTEU: begin 
                    case (addr[1:0])
                        2'b00: RAM[word_addr][7:0]   <= din[7:0];
                        2'b01: RAM[word_addr][15:8]  <= din[7:0];
                        2'b10: RAM[word_addr][23:16] <= din[7:0];
                        2'b11: RAM[word_addr][31:24] <= din[7:0];
                    endcase
                end
                `DM_HALF, `DM_HALFU: begin
                    case (addr[1])
                        1'b0: RAM[word_addr][15:0]  <= din[15:0];
                        1'b1: RAM[word_addr][31:16] <= din[15:0];
                    endcase
                end
                `DM_WORD: begin
                    RAM[word_addr] <= din;
                end
                default: RAM[word_addr] <= din;
            endcase
        end
    end

    // 异步读 (Load)
    wire [31:0] raw_word = RAM[word_addr]; 
    reg  [31:0] read_data;

    always @(*) begin
        case (DMType)
            `DM_BYTE: begin
                case (addr[1:0])
                    2'b00: read_data = {{24{raw_word[7]}},  raw_word[7:0]};
                    2'b01: read_data = {{24{raw_word[15]}}, raw_word[15:8]};
                    2'b10: read_data = {{24{raw_word[23]}}, raw_word[23:16]};
                    2'b11: read_data = {{24{raw_word[31]}}, raw_word[31:24]};
                endcase
            end
            `DM_BYTEU: begin
                case (addr[1:0])
                    2'b00: read_data = {24'b0, raw_word[7:0]};
                    2'b01: read_data = {24'b0, raw_word[15:8]};
                    2'b10: read_data = {24'b0, raw_word[23:16]};
                    2'b11: read_data = {24'b0, raw_word[31:24]};
                endcase
            end
            `DM_HALF: begin
                case (addr[1])
                    1'b0: read_data = {{16{raw_word[15]}}, raw_word[15:0]};
                    1'b1: read_data = {{16{raw_word[31]}}, raw_word[31:16]};
                endcase
            end
            `DM_HALFU: begin
                case (addr[1])
                    1'b0: read_data = {16'b0, raw_word[15:0]};
                    1'b1: read_data = {16'b0, raw_word[31:16]};
                endcase
            end
            `DM_WORD: begin
                read_data = raw_word;
            end
            default: read_data = raw_word;
        endcase
    end

    assign dout = read_data;

endmodule
`endif