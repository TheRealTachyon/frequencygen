module freqgen_top (
		    input  SYS_CLK,
		    output OUT_CLK,

			 input  RX,
			 output TX,
			 
			 
			 output LED
			 
		    
   );
   
   wire       reset_n;
   wire 		  pclk_lckd;
   wire [7:0]		  pclk_M;
   wire [7:0]		  pclk_D;
   wire 		  gopclk;
   
   wire 		  progdone;
   wire 		  progen;
   wire 		  progdata;
   
   wire 		  clk50m;
   wire 		  clkfx;
   
   BUFG sysclk_buf (.I(SYS_CLK), .O(clk50m));
   OBUF outclk     (.I(clkfx), .O(OUT_CLK));

    // uart signals
    wire			is_transmitting;
    wire 		received;   
    wire			transmit;
    reg	      transmit_r;

    // rx fifo signals
    wire       rd_en;
  
    wire  		rx_full;
    wire  		rx_empty;
    wire [7:0] rx_data;
    wire [7:0]  rd_data;
   
    // tx fifo signals
    wire [7:0] tx_data;
    wire [7:0]  wr_data;
   
    wire       wr_en;
    wire		   tx_full;
    wire 		tx_empty;

	 por POR(
		.clk	(clk50m),
		.rst_o(reset_n)
    );

    fifo_uart TXFIFO
    (
	    .clk		(clk50m),
	    .srst		(!reset_n),
	    .din		(wr_data),
	    .dout		(tx_data),
	    .rd_en		(transmit),
	    .wr_en		(wr_en),
	    .full		(tx_full),
	    .empty	(tx_empty)
    );

    fifo_uart RXFIFO
    (
	    .clk		(clk50m),
	    .srst		(!reset_n),
	    .din		   (rx_data),
	    .dout		(rd_data),
	    .wr_en		(received),
	    .rd_en		(rd_en),
	    .empty		(rx_empty),
	    .full		(rx_full)
    );

    uart UART(
	    .clk		(clk50m),
	    .rst		(!reset_n),
	
	    .rx		    (RX),
	    .tx		    (TX),
	
	    .tx_byte	(tx_data),
	    .rx_byte	(rx_data),
	
	    .received(received),
	    .transmit(transmit_r),
	
	    .is_transmitting(is_transmitting)
    );

   
   serial_decode DECODER(
	
			 // control lines
			 .clk        ( clk50m),
			 .reset_n    ( reset_n     ),
			 // uart controls. 
			 
			 .rd_data	 ( rd_data		),
			 .wr_data	 ( wr_data		),
			 
			 .rd_en		 ( rd_en       ),
			 .wr_en      ( wr_en       ),
			 
			 .rd_empty	 ( rx_empty		),
			 .wr_full	 ( tx_full	   ),

			 // clockgen outputs
			 .multiplier ( pclk_M      ),
			 .divider    ( pclk_D      ),
			 .change     ( gopclk      )

			 );
   
   
   //
   // DCM_CLKGEN SPI controller
   //
   
  dcmspi dcmspi_0 (
    .RST(!reset_n),          //Synchronous Reset
    .PROGCLK(clk50m), //SPI clock
    .PROGDONE(progdone),   //DCM is ready to take next command
    .DFSLCKD(pclk_lckd),
    .M(pclk_M),            //DCM M value
    .D(pclk_D),            //DCM D value
    .GO(gopclk),           //Go programme the M and D value into DCM(1 cycle pulse)
    .BUSY(busy),
    .PROGEN(progen),       //SlaveSelect,
    .PROGDATA(progdata)    //CommandData
  );

  //
  // DCM_CLKGEN to generate a pixel clock with a variable frequency
  //
  DCM_CLKGEN #(
    .CLKFX_DIVIDE (3),
    .CLKFX_MULTIPLY (2),
    .CLKIN_PERIOD(31.25)
  )
  PCLK_GEN_INST (
    .CLKFX(clkfx),
    .CLKFX180(),
    .CLKFXDV(),
    .LOCKED(pclk_lckd),
    .PROGDONE(progdone),
    .STATUS(),
    .CLKIN(clk50m),
    .FREEZEDCM(1'b0),
    .PROGCLK(clk50m),
    .PROGDATA(progdata),
    .PROGEN(progen),
    .RST(1'b0)
  );

always @(posedge clk50m) begin
	
	if (reset_n === 1'b0) begin
		// reset logic
		transmit_r <= 1'b0;

	end else begin
		
		transmit_r <= transmit;

	end

end

assign transmit = !tx_empty & !is_transmitting & !transmit_r;

assign LED = pclk_lckd;

endmodule
