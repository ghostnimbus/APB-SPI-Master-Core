`timescale 1ns/1ps

module tb;
    reg PCLK;
    reg PRESETn;
    reg [2:0] PADDR;
    reg PWRITE;
    reg PSEL;
    reg PENABLE;
    reg [7:0] PWDATA;
    reg miso;
    wire [7:0] PRDATA;
    wire PREADY;
    wire PSLVERR;
    wire ss;
    wire sclk;
    wire spi_interrupt_request;
    wire mosi;

    // DUT
    apb_spi_master_core dut (
        .PCLK(PCLK),
        .PRESETn(PRESETn),
        .PADDR(PADDR),
        .PWRITE(PWRITE),
        .PSEL(PSEL),
        .PENABLE(PENABLE),
        .PWDATA(PWDATA),
        .miso(miso),
        .PRDATA(PRDATA),
        .PREADY(PREADY),
        .PSLVERR(PSLVERR),
        .ss(ss),
        .sclk(sclk),
        .spi_interrupt_request(spi_interrupt_request),
        .mosi(mosi)
    );


    // APB WRITE TASK
    task apb_write(input [2:0] addr, input [7:0] data);
    begin
        @(posedge PCLK);
        PADDR   <= addr;
        PWDATA  <= data;
        PWRITE  <= 1;
        PSEL    <= 1;
        PENABLE <= 0;

        @(posedge PCLK);
        PENABLE <= 1;

        @(posedge PCLK);
        //PSEL    <= 0;
        PENABLE <= 0;
    end
    endtask

    // APB READ TASK
    task apb_read(input [2:0] addr);
    begin
        @(posedge PCLK);
        PADDR   <= addr;
        PWRITE  <= 0;
        PSEL    <= 1;
        PENABLE <= 0;

        @(posedge PCLK);
        PENABLE <= 1;

        @(posedge PCLK);
        $display("READ [%0d] = %h", addr, PRDATA);

        //PSEL    <= 0;
        PENABLE <= 0;
    end
    endtask

    // SEND DATA TASK
    task spi_send(input [7:0] data);
    begin
        $display("Sending Data: %h", data);
        apb_write(3'b101, data); // DR
    end
    endtask

    // MISO TASK
    // MISO TASK (Supports both MSB and LSB First)
    // UNIVERSAL SLAVE RESPONSE TASK (Auto-fetches CPOL, CPHA, LSBFE from DUT CR1)
    task spi_slave_response(input [7:0] data);
        integer i;
        reg cpol, cpha, lsbfe;
    begin
        // Automatically probe mode settings directly from the slave interface CR1
        cpol  = dut.cpol_s;
        cpha  = dut.cpha_s;
        lsbfe = dut.lsbfe_s;

        // Wait for Slave Select to assert low
        @(negedge ss);

        if (cpha == 1'b0) begin
            // -------------------------------------------------------------
            // CPHA = 0: First bit is output immediately on ss falling edge.
            // Subsequent bits shift on the trailing edge of each SCLK cycle.
            // -------------------------------------------------------------
            if (lsbfe) begin
                // LSB First
                miso <= data[0];
                for (i = 1; i < 8; i = i + 1) begin
                    if (cpol == 1'b0) @(negedge sclk); // Mode 0: trailing edge is falling
                    else              @(posedge sclk); // Mode 2: trailing edge is rising
                    miso <= data[i];
                end
            end else begin
                // MSB First
                miso <= data[7];
                for (i = 6; i >= 0; i = i - 1) begin
                    if (cpol == 1'b0) @(negedge sclk); // Mode 0
                    else              @(posedge sclk); // Mode 2
                    miso <= data[i];
                end
            end
        end else begin
            // -------------------------------------------------------------
            // CPHA = 1: First bit (and subsequent bits) shift on leading edge.
            // Master samples on the trailing edge.
            // -------------------------------------------------------------
            if (lsbfe) begin
                // LSB First
                for (i = 0; i < 8; i = i + 1) begin
                    if (cpol == 1'b0) @(posedge sclk); // Mode 1: leading edge is rising
                    else              @(negedge sclk); // Mode 3: leading edge is falling
                    miso <= data[i];
                end
            end else begin
                // MSB First
                for (i = 7; i >= 0; i = i - 1) begin
                    if (cpol == 1'b0) @(posedge sclk); // Mode 1
                    else              @(negedge sclk); // Mode 3
                    miso <= data[i];
                end
            end
        end

        // Wait for transfer complete and release MISO
        @(posedge ss);
        miso <= 1'b0;
    end
    endtask

    initial begin
        $dumpfile("spi_tb.vcd"); 
        $dumpvars(0, tb);
        PCLK = 0;
        PRESETn = 0;
        PSEL = 0;
        PENABLE = 0;
        PWRITE = 0;
        PADDR = 0;
        PWDATA = 0;
        miso = 0;

        // Reset
        repeat(2) @(posedge PCLK);
        PRESETn = 1;
        
		  //CR1
        apb_write(3'b000, 8'b0111_1000);

        // CR2: 
        apb_write(3'b001, 8'b00000000);

        // BR
        apb_write(3'b010, 8'b00010001);
		  
//		  repeat(10) @(posedge PCLK);
//		  // CR2: 
//        apb_write(3'b001, 8'b00000000);
//		  
//		  //CR1
//		  apb_write(3'b000, 8'b11110001);

        // TEST 1
        fork
            spi_send(8'hB1);
            spi_slave_response(8'h56);
        join
        #200;

        // Read received data
        apb_read(3'b101);
/*
        // TEST 2
        fork
            spi_send(8'h69);
            spi_slave_response(8'hAA);
        join

        #200;
        apb_read(3'b101); 
        */
        repeat(3) @(posedge PCLK);
        $finish;
    end
	// Clock generation
   always #5 PCLK = ~PCLK;
endmodule