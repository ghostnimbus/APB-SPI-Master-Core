module slave_control_select (
    input PCLK,
    input PRESETn,  
    input mstr_i,
    input spiswai_i,
    input [1:0] spi_mode_i,
    input send_data_i,
    input [11:0] BaudRateDivisor_i,
    output reg receive_data_o,
    output reg ss_o,
    output tip_o
);
    reg [15:0] count;
    reg rcv;
    reg ss_next;
    reg rcv_next;

    wire run_mode  = (spi_mode_i == 2'b00);
    wire wait_mode = (spi_mode_i == 2'b01);
	wire stop_mode = (spi_mode_i == 2'b10);
    wire enable    = (run_mode || wait_mode) && mstr_i && !spiswai_i;

    // Combinational: ss next-state
    always @(*) begin
        ss_next = 1'b1;
        case (enable)
            1'b1 : case (send_data_i)
                        1'b1 : ss_next = 1'b0;
                        1'b0 : case (count <= ((BaudRateDivisor_i * 8) - 16'd1))
                                    1'b1 : ss_next = 1'b0;
                                    1'b0 : ss_next = 1'b1;
                               endcase
                   endcase
            1'b0 : ss_next = ss_o;
        endcase
    end

    // Combinational: rcv next-state
    always @(*) begin
        rcv_next = 1'b0;
        case (enable)
            1'b1 : case (send_data_i)
                        1'b1 : rcv_next = 1'b0;
                        1'b0 : case ({(count <= ((BaudRateDivisor_i * 8) - 16'd1)), (count == ((BaudRateDivisor_i * 8) - 16'd1))})
                                    2'b11   : rcv_next = 1'b1;
                                    default : rcv_next = 1'b0;
                               endcase
                   endcase
            1'b0 : rcv_next = 1'b0;
        endcase
    end

    // Sequential: counter
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            count <= 16'hffff;
        else
            case (enable)
                1'b1 : case (send_data_i)
                            1'b1 : count <= 16'd0;
                            1'b0 : case (count <= ((BaudRateDivisor_i * 8) - 16'd1))
                                        1'b1 : count <= count + 1'b1;
                                        1'b0 : count <= 16'hffff;
                                   endcase
                       endcase
                1'b0 : count <= count;
            endcase
    end

    // Sequential: ss_o
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            ss_o <= 1'b1;
        else
            ss_o <= ss_next;
    end

    // Sequential: rcv
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            rcv <= 1'b0;
        else
            rcv <= rcv_next;
    end

    // Sequential: receive_data_o
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            receive_data_o <= 1'b0;
        else
            receive_data_o <= rcv;
    end

    assign tip_o = ~ss_o;

endmodule