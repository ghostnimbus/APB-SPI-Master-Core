module shift_register (
    input PCLK,
    input PRESETn,
    input ss_i,
    input send_data_i,
    input lsbfe_i,
    input cpha_i,
    input cpol_i,
    input miso_receive_sclk_i,
    input miso_receive_sclk0_i,
    input mosi_send_sclk_i,
    input mosi_send_sclk0_i,
    input [7:0] data_mosi_i,
    input miso_i,
    input receive_data_i,
    output reg mosi_o,
    output [7:0] data_miso_o
);

    reg [7:0] shift_reg;
    reg [7:0] temp_reg;
    reg [2:0] count, count1;
    reg [2:0] count2, count3;

    // Load Shift Register (send_data pulse)
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            shift_reg <= 8'b0;
        else if (send_data_i)
            shift_reg <= data_mosi_i;
		  else shift_reg <= shift_reg;
    end

    //MOSI
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            count  <= 3'd0;
            count1 <= 3'd7;
            mosi_o <= 1'b0;
        end
        else if (!ss_i) begin
            case ({cpol_i, cpha_i, lsbfe_i})
    
                // MODE 0 (0,0) → posedge
                3'b001: if (mosi_send_sclk0_i) begin
                    mosi_o <= shift_reg[count];
                    count <= (count==3'd7)? 3'd0 : count+1'b1 ;
                end
                3'b000: if (mosi_send_sclk0_i) begin
                    mosi_o <= shift_reg[count1];
                    count1 <= (count1==3'd0)? 3'd7 : count1-1'b1;
                end
    
                // MODE 1 (0,1) → negedge
                3'b011: if (mosi_send_sclk_i) begin
                    mosi_o <= shift_reg[count];
                    count <= (count==3'd7)?3'd0:count+1;
                end
                3'b010: if (mosi_send_sclk_i) begin
                    mosi_o <= shift_reg[count1];
                    count1 <= (count1==3'd0)?3'd7:count1-1;
                end
    
                // MODE 2 (1,0) → negedge
                3'b101: if (mosi_send_sclk_i) begin
                    mosi_o <= shift_reg[count];
                    count <= (count==3'd7)?3'd0:count+1;
                end
                3'b100: if (mosi_send_sclk_i) begin
                    mosi_o <= shift_reg[count1];
                    count1 <= (count1==3'd0)?3'd7:count1-1;
                end
    
                // MODE 3 (1,1) → posedge
                3'b111: if (mosi_send_sclk0_i) begin
                    mosi_o <= shift_reg[count];
                    count <= (count==3'd7)?3'd0:count+1;
                end
                3'b110: if (mosi_send_sclk0_i) begin
                    mosi_o <= shift_reg[count1];
                    count1 <= (count1==3'd0)?3'd7:count1-1;
                end
    
            endcase
        end
    end
    // MISO LOGIC (CPOL, CPHA, LSB/MSB)
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            count2   <= 3'd0;
            count3   <= 3'd7;
            temp_reg <= 8'b0;
        end
        else if (!ss_i) begin
            case ({cpol_i, cpha_i, lsbfe_i})
                // MODE 0
                3'b001: if (miso_receive_sclk_i) begin
                    temp_reg[count2] <= miso_i;
                    count2 <= (count2==3'd7)?3'd0:count2+1;
                end
                3'b000: if (miso_receive_sclk_i) begin
                    temp_reg[count3] <= miso_i;
                    count3 <= (count3==3'd0)?3'd7:count3-1;
                end
                // MODE 1
                3'b011: if (miso_receive_sclk0_i) begin
                    temp_reg[count2] <= miso_i;
                    count2 <= (count2==3'd7)?3'd0:count2+1;
                end
                3'b010: if (miso_receive_sclk0_i) begin
                    temp_reg[count3] <= miso_i;
                    count3 <= (count3==3'd0)?3'd7:count3-1;
                end
                // MODE 2
                3'b101: if (miso_receive_sclk0_i) begin
                    temp_reg[count2] <= miso_i;
                    count2 <= (count2==3'd7)?3'd0:count2+1;
                end
                3'b100: if (miso_receive_sclk0_i) begin
                    temp_reg[count3] <= miso_i;
                    count3 <= (count3==3'd0)?3'd7:count3-1;
                end
                // MODE 3
                3'b111: if (miso_receive_sclk_i) begin
                    temp_reg[count2] <= miso_i;
                    count2 <= (count2==3'd7)?3'd0:count2+1;
                end
                3'b110: if (miso_receive_sclk_i) begin
                    temp_reg[count3] <= miso_i;
                    count3 <= (count3==3'd0)?3'd7:count3-1;
                end
            endcase
        end
    end

    assign data_miso_o = (receive_data_i) ? temp_reg : 8'h00;
endmodule