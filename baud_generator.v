module baud_generator (
    input PCLK,
    input PRESET_n,
    input [1:0] spi_mode_i,
    input spiswai_i,
    input [2:0] sppr_i,
    input [2:0] spr_i,
    input cpol_i,
    input cpha_i,
    input ss_i,
    output reg sclk_o,
    output reg miso_receive_sclk_o,
    output reg miso_receive_sclk0_o,
    output reg mosi_send_sclk_o,
    output reg mosi_send_sclk0_o,
    output [11:0] BaudRateDivisor_o
);

    reg [11:0] count;
    reg pre_sclk;
    reg miso_receive_sclk_next, miso_receive_sclk0_next;
    reg mosi_send_sclk_next, mosi_send_sclk0_next;

    assign BaudRateDivisor_o = (sppr_i + 3'd1) * (12'd1 << (spr_i + 3'd1));

    wire run_mode  = (spi_mode_i == 2'b00);
    wire wait_mode = (spi_mode_i == 2'b01);
    wire enable    = (run_mode || wait_mode) && (~ss_i) && (~spiswai_i);

    // pre-sclk
    always @(*) begin
        case (cpol_i)
            1'b1 : pre_sclk = 1'b1;
            1'b0 : pre_sclk = 1'b0;
        endcase
    end

    // Combinational: miso logic
    always @(*) begin
        miso_receive_sclk_next  = 1'b0;
        miso_receive_sclk0_next = 1'b0;
        case ({cpol_i, cpha_i})
            2'b00, 2'b11 : begin
                miso_receive_sclk0_next = 1'b0;
                case ({~sclk_o, (count == (BaudRateDivisor_o / 2) - 1'b1)})
                    2'b11   : miso_receive_sclk_next = 1'b1;
                    default : miso_receive_sclk_next = 1'b0;
                endcase
            end
            2'b01, 2'b10 : begin
                miso_receive_sclk_next = 1'b0;
                case ({sclk_o, (count == (BaudRateDivisor_o / 2) - 1'b1)})
                    2'b11   : miso_receive_sclk0_next = 1'b1;
                    default : miso_receive_sclk0_next = 1'b0;
                endcase
            end
        endcase
    end

    // Combinational: mosi logic
    always @(*) begin
        mosi_send_sclk_next  = 1'b0;
        mosi_send_sclk0_next = 1'b0;
        case ({cpol_i, cpha_i})
            2'b00, 2'b11 : begin
                mosi_send_sclk_next = 1'b0;
                case ({~sclk_o, (count == (BaudRateDivisor_o / 2) - 2'd2)})
                    2'b11   : mosi_send_sclk0_next = 1'b1;
                    default : mosi_send_sclk0_next = 1'b0;
                endcase
            end
            2'b01, 2'b10 : begin
                mosi_send_sclk0_next = 1'b0;
                case ({sclk_o, (count == (BaudRateDivisor_o / 2) - 2'd2)})
                    2'b11   : mosi_send_sclk_next = 1'b1;
                    default : mosi_send_sclk_next = 1'b0;
                endcase
            end
        endcase
    end

    // Sequential: counter
    always @(posedge PCLK or negedge PRESET_n) begin
        if (!PRESET_n)
            count <= 12'd0;
        else
            case (enable)
                1'b1 : case (count == (BaudRateDivisor_o / 2) - 1'b1)
                            1'b1 : count <= 12'd0;
                            1'b0 : count <= count + 1'b1;
                        endcase
                1'b0 : count <= 12'd0;
            endcase
    end

    // Sequential: SCLK
    always @(posedge PCLK or negedge PRESET_n) begin
        if (!PRESET_n)
            sclk_o <= pre_sclk;
        else
            case (enable)
                1'b1 : case (count == (BaudRateDivisor_o / 2) - 1'b1)
                            1'b1 : sclk_o <= ~sclk_o;
                            1'b0 : sclk_o <= sclk_o;
                        endcase
                1'b0 : sclk_o <= pre_sclk;
            endcase
    end

    // Sequential: MISO
    always @(posedge PCLK or negedge PRESET_n) begin
        if (!PRESET_n) begin
            miso_receive_sclk_o  <= 1'b0;
            miso_receive_sclk0_o <= 1'b0;
        end else begin
            miso_receive_sclk_o  <= miso_receive_sclk_next;
            miso_receive_sclk0_o <= miso_receive_sclk0_next;
        end
    end

    // Sequential: MOSI
    always @(posedge PCLK or negedge PRESET_n) begin
        if (!PRESET_n) begin
            mosi_send_sclk_o  <= 1'b0;
            mosi_send_sclk0_o <= 1'b0;
        end else begin
            mosi_send_sclk_o  <= mosi_send_sclk_next;
            mosi_send_sclk0_o <= mosi_send_sclk0_next;
        end
    end

endmodule