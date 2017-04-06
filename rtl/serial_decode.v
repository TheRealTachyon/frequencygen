/*	Copyright (c) 2012, Stephen J. Leary
	All rights reserved.

	Redistribution and use in source and binary forms, with or without
	modification, are permitted provided that the following conditions are met:
		 * Redistributions of source code must retain the above copyright
			notice, this list of conditions and the following disclaimer.
		 * Redistributions in binary form must reproduce the above copyright
			notice, this list of conditions and the following disclaimer in the
			documentation and/or other materials provided with the distribution.
		 * Neither the name of the Stephen J. Leary nor the
			names of its contributors may be used to endorse or promote products
			derived from this software without specific prior written permission.

	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
	ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
	DISCLAIMED. IN NO EVENT SHALL STEPHEN J. LEARY BE LIABLE FOR ANY
	DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
	(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
	LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
	ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
	(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
	SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. */

`timescale 1ns / 1ps

module serial_decode (
           input 	       clk,
           input 	       reset_n,

           // input fifo stream
           output 	       rd_en,
           output reg       wr_en,

           input 	       rd_empty,
           input [7:0]      rd_data,

           // output fifo stream.
           input 	       wr_full,
           output reg [7:0] wr_data,

           output reg [7:0] multiplier,
           output reg [7:0] divider,
           output reg       change
       );



/*Function to convert a single hex char to a 4 bit value */
function [3:0] char_to_nibble;
    // no error checking. just try and convert.
    input [7:0] ascii;
    begin
        char_to_nibble = (ascii < 8'h41) ? ascii[3:0] : ascii[2:0] + 4'd9;
    end
endfunction //

/* Function to convert 4 bits of data to hex */
function [7:0] nibble_to_char;
    input [3:0] data;
    begin
        nibble_to_char =  (data < 4'd10) ? 8'h30 | {4'd0, data} : 8'h5f + {4'd0,data[2:0]};
    end
endfunction // convert_nibble_to_char

localparam EX_IDLE = 0,
           EX_COMMAND = 1;
   
   
localparam 	RD_IDLE 	= 0,
            RD_INPUT 	= 1,
            RD_CHECKHI	= 2,
            RD_CHECKLO	= 3;

localparam      WR_IDLE         = 0,
                WR_RESP  	= 1,
                WR_OUT  	= 2,
                WR_CHECKHI 	= 3,
                WR_CHECKLO  	= 4,
                WR_ERROR        = 5,
                WR_GOOD	        = 6,
                WR_NEWLINE  	= 7;


reg [7:0] input_buf[0:7];
reg [7:0] input_buf_pos;
reg [7:0] input_buf_csum;

reg [7:0] response_buf[0:10];
reg [7:0] response_buf_pos;
reg [7:0] response_buf_size;
reg [7:0] response_buf_csum;

task SendOK;
    begin
        // OK
        wr_state <= WR_RESP; // acknowledge
        response_buf[0] <= "O";
        response_buf[1] <= "K";
        response_buf_pos      <= 0;
        response_buf_size   	 <= 2;
    end
endtask // SendOK


reg [7:0] rd_state;
reg [7:0] ex_state;
reg [7:0] wr_state;
   
reg rd_empty_r;

wire writing = wr_state != WR_IDLE;
wire reading = !writing;

initial begin

    rd_state = RD_IDLE;
    wr_state = WR_IDLE;
    wr_en    = 'b0;

    input_buf_pos = 'd0;
    input_buf_csum = 'd0;

    response_buf_pos = 'd0;
    response_buf_csum = 'd0;
    response_buf_size = 'd0;

end

always @(posedge clk) begin

    change <= 1'b0;

    if (reset_n === 1'b0) begin

        wr_data		 <= 'd0;
        wr_en		 <= 'b0;

        rd_empty_r 	 <= 'b0;

        rd_state 	<= RD_IDLE;
        wr_state	<= WR_IDLE;

        input_buf_pos		<= 0;
        input_buf_csum		<= 0;

        response_buf_size 		<= 0;
        response_buf_csum             <= 0;
        response_buf_pos 		<= 0;

        multiplier <= 'd0;
        divider <= 'd0;

    end else begin

        // fifo flow control
        rd_empty_r  <= rd_empty;

        // delayed read for fifo output
        if (reading & !rd_empty_r) begin

            case (rd_state)

                RD_IDLE: begin // wait

                    if (rd_data == "$") begin

                        // start reading a new command.
                        rd_state 		<= RD_INPUT;
                        input_buf_pos 	<= 'd0;
                        input_buf_csum <= 8'd0;

                    end

                end

                RD_INPUT: begin // read

                    // read the data stream.

                    if (rd_data == "#")  begin

                        // if we get the checksum marker start the
                        // checksum compare.
                        if (input_buf_pos == 'd4) begin
                            rd_state <= RD_CHECKHI;
                        end else begin

                            // wrong packet length
                            $display("bad packet length");

                            rd_state <= RD_IDLE;
                            wr_state <= WR_ERROR;

                        end


                    end else if (rd_data == "$") begin

                        // if we get the start of a new packet something went wrong.
                        rd_state <= RD_IDLE;
                        wr_state <= WR_ERROR;

                    end else begin

                        // otherwise enter the data and
                        // increment the counts and checksumssums
                        input_buf[input_buf_pos] <= rd_data;
                        input_buf_csum <= input_buf_csum + rd_data;
                        input_buf_pos <= input_buf_pos + 'd1;

                    end

                end

                RD_CHECKHI: begin

                    if (input_buf_csum[7:4] == char_to_nibble(rd_data)) begin

                        // the first part of the checksum was good.
                        // check the second part.
                        rd_state <= RD_CHECKLO;

                    end else begin

                        // there was an error in the checksum
                        // acknowledge the error and reset.
                        rd_state <= RD_IDLE;
                        wr_state <= WR_ERROR;

                    end

                end

                RD_CHECKLO: begin

                    if (input_buf_csum[3:0] == char_to_nibble(rd_data)) begin

                        // the second part of the checksum was good.
                        // acknowledge and process the data.
                        rd_state <= RD_IDLE;
                        wr_state <= WR_GOOD;
		        ex_state <= EX_COMMAND;
		       
                    end else begin

                        // there was an error in the checksum
                        // acknowledge the error and reset.
                        rd_state <= RD_IDLE;
                        wr_state <= WR_ERROR;

                    end

                end

            endcase

        end // if (reading & !rd_empty_r)

        //**************************
        // EXECUTE
        //**************************

        if ((writing != 1'b1) & (ex_state != EX_IDLE)) begin

            case (ex_state)

                EX_COMMAND: begin

                    // we're now looking for the command character
                    ex_state <= EX_IDLE;		    
                    change <= 1'b1;
		    SendOK();
		    
 		    multiplier[7:4] <= char_to_nibble(input_buf[0]);
 		    multiplier[3:0] <= char_to_nibble(input_buf[1]);
 		    divider[7:4] <= char_to_nibble(input_buf[2]);
		    divider[3:0] <= char_to_nibble(input_buf[3]);
		    
            end

            endcase // case (ex_state)

        end // if ((writing != 1'b1) & (ex_state != EX_IDLE))


        //**************************
        // WRITE
        //**************************

        if (wr_full == 1'b0) begin

            case (wr_state)

                WR_IDLE: wr_en <= 1'b0;

                WR_RESP: begin

                    wr_en	  <= 1'b1;

                    wr_data <= "$";
                    wr_state <= WR_OUT;

                    response_buf_csum <= 8'd0;
                end

                WR_OUT: begin // write out the payload.

                    wr_en <= 1'b1;

                    if (response_buf_pos < response_buf_size) begin

                        wr_data          <= response_buf[response_buf_pos];
                        response_buf_csum <= response_buf_csum + response_buf[response_buf_pos];
                        response_buf_pos  <= response_buf_pos + 7'd1;

                    end else begin

                        wr_data <= "#";
                        wr_state <= WR_CHECKHI;

                    end

                end

                WR_CHECKHI: begin // write the hi nibble of the checksum

                    wr_en 	<= 1'b1;
                    wr_data 	<= nibble_to_char(response_buf_csum[7:4]);
                    wr_state <= WR_CHECKLO;

                end

                WR_CHECKLO: begin // write the lo nibble of the checksum

                    wr_en 	<= 1'b1;
                    wr_data 	<= nibble_to_char(response_buf_csum[3:0]);
                    wr_state <= WR_IDLE;

                end

                WR_ERROR: begin

                    wr_en		<= 1'b1;
                    wr_data	<= "-";
                    wr_state <= WR_NEWLINE;

                end

                WR_GOOD: begin

                    wr_en		<= 1'b1;
                    wr_data	<= "+";
                    wr_state <= WR_NEWLINE;

                end

                WR_NEWLINE: begin

                    wr_en		<= 1'b1;
                    wr_data	<= "\r";
                    wr_state <= WR_IDLE;

                end

            endcase
        end
    end

end

assign rd_en = reading & !rd_empty;

endmodule
