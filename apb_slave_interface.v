module apb_slave_interface (
    input             PCLK,
    input             PRESETn,
    input      [2:0]  PADDR_i,
    input             PWRITE_i,
    input             PSEL_i,
    input             PENABLE_i,
    input      [7:0]  PWDATA_i,
    input             ss_i,
    input      [7:0]  miso_data_i,
    input             receive_data_i,
    input             tip_i,
    output reg [7:0]  PRDATA_o,
    output            PREADY_o,
    output            PSLVERR_o,
    output            mstr_o,
    output            cpol_o,
    output            cpha_o,
    output            lsbfe_o,
    output     [2:0]  sppr_o,
    output     [2:0]  spr_o,
    output            spiswai_o,
    output reg        spi_interrupt_request_o,
    output reg        send_data_o,
    output reg [7:0]  mosi_data_o,
    output     [1:0]  spi_mode_o
);

    parameter CR1_ADDR = 3'b000;
    parameter CR2_ADDR = 3'b001;
    parameter BR_ADDR  = 3'b010;
    parameter SR_ADDR  = 3'b011;
    parameter DR_ADDR  = 3'b101;

    parameter IDLE=2'b00, SETUP=2'b01, ENABLE=2'b10;
    parameter SPI_RUN=2'b00, SPI_WAIT=2'b01, SPI_STOP=2'b10;

    reg [1:0] state, next_state;
    reg [1:0] spi_state, spi_next;

    reg [7:0] CR1, CR2, BR, DR;
    wire [7:0] SR;

    wire write_en = PSEL_i & PENABLE_i &  PWRITE_i;
    wire read_en  = PSEL_i & PENABLE_i & ~PWRITE_i;

    assign PREADY_o  = (state == ENABLE);
    assign PSLVERR_o = (state == ENABLE) && (PADDR_i > 3'b101 || PADDR_i == 3'b100) ? ~tip_i : 1'b0;

    // APB FSM
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) state <= IDLE;
        else state <= next_state;
    end

    always @(*) begin
        case (state)
            IDLE:   next_state = (PSEL_i && !PENABLE_i) ? SETUP : IDLE;
            SETUP:  next_state = PSEL_i ? (PENABLE_i ? ENABLE : SETUP) : IDLE;
            ENABLE: next_state = PSEL_i ? SETUP : IDLE;
            default: next_state = IDLE;
        endcase
    end

    // CR1, CR2, BR Register Logic (from apb_slave_interface_c1_2_br.PNG)
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            CR1 <= 8'h04;
            CR2 <= 8'h00;
            BR  <= 8'h00;
        end 
        else if (write_en) begin
            case (PADDR_i)
                CR1_ADDR: CR1 <= PWDATA_i;
                CR2_ADDR: CR2 <= PWDATA_i & 8'b00011011;
                BR_ADDR:  BR  <= PWDATA_i & 8'b01110111;
            endcase
        end
    end

    assign mstr_o   = CR1[4];
    assign cpol_o   = CR1[3];
    assign cpha_o   = CR1[2];
    assign lsbfe_o  = CR1[0];

    assign spiswai_o = CR2[1];
    assign sppr_o    = BR[6:4];
    assign spr_o     = BR[2:0];

    wire spe     = CR1[6];
    wire spiswai = CR2[1];
    wire spie    = CR1[7];
    wire sptie   = CR1[5];
    wire ssoe    = CR1[1];
    wire modfen  = CR2[4];

    // SPI Modes FSM (from spi_mode.PNG)
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) spi_state <= SPI_RUN;
        else spi_state <= spi_next;
    end

    always @(*) begin
        case (spi_state)
            SPI_RUN:  spi_next = spe ? SPI_RUN : SPI_WAIT;
            SPI_WAIT: spi_next = (spe) ? SPI_RUN : (spiswai ? SPI_STOP : SPI_WAIT);
            SPI_STOP: spi_next = (spe) ? SPI_RUN : (!spiswai ? SPI_WAIT : SPI_STOP);
            default:  spi_next = SPI_RUN;
        endcase
    end

    assign spi_mode_o = spi_state;

    // Common Matching Condition (from DR, MOSI, and SEND schematics)
    wire comp_cond = (DR == PWDATA_i) & (DR != miso_data_i) & 
                     ((spi_state == SPI_RUN) | (spi_state == SPI_WAIT));

    // DR LOGIC (from apb_slave_interface_sr_archi.PNG)
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            DR <= 8'b0;
        end
        else if (write_en) begin
            if (PADDR_i == 3'b101)
                DR <= PWDATA_i;
            else
                DR <= comp_cond ? 8'b0 : PWDATA_i;
        end
        else begin
            if (receive_data_i & comp_cond)
                DR <= miso_data_i;
            else
                DR <= DR;
        end
    end

    // TRANSMIT LOGIC: send_data (from apb_slave_interface_send_data.PNG)
	// TRANSMIT LOGIC: send_data
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            send_data_o <= 1'b0;
        end
        else if (write_en && (PADDR_i == DR_ADDR)) begin
            // Trigger transmission when writing to DR during RUN or WAIT
            send_data_o <= (spi_state == SPI_RUN) || (spi_state == SPI_WAIT);
        end
        else begin
            send_data_o <= 1'b0;
        end
    end

    // TRANSMIT LOGIC: mosi_data
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            mosi_data_o <= 8'b0;
        end
        else if (write_en && (PADDR_i == DR_ADDR)) begin
            mosi_data_o <= PWDATA_i;
        end
    end

    // STATUS REGISTER LOGIC (from apb_slave_interface_spif_sptf.PNG & sr.PNG)
    wire sptef = (DR == 8'b00000000);
    wire spif  = (DR != 8'b00000000);
    wire modf  = (~ss_i) & mstr_o & modfen & (~ssoe);

    assign SR = (!PRESETn) ? 8'b0010_0000 : {spif, 1'b0, sptef, modf, 4'b0000};

    // READ LOGIC: PRDATA (from apb_slave_interface_prdata.PNG)
    always @(*) begin
        PRDATA_o = 8'h00;
        if (read_en) begin
            case (PADDR_i)
                CR1_ADDR: PRDATA_o = CR1;
                CR2_ADDR: PRDATA_o = CR2;
                BR_ADDR:  PRDATA_o = BR;
                SR_ADDR:  PRDATA_o = SR;
                DR_ADDR:  PRDATA_o = DR;
                default:  PRDATA_o = 8'h00; // Addresses 4, 6, 7
            endcase
        end
    end

    // INTERRUPT LOGIC (from apb_slave_interface_interrupt.PNG)
    wire mux1_out = (~spie & sptie) ? sptef : (spif | modf | sptef);
    wire mux2_out = (spie & ~sptie) ? (spif | modf) : mux1_out;
    wire irq_comb = (~spie & ~sptie) ? 1'b0 : mux2_out;

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            spi_interrupt_request_o <= 1'b0;
        else
            spi_interrupt_request_o <= irq_comb;
    end

endmodule


















//module apb_slave_interface (
//    input PCLK,
//    input PRESETn,
//    input [2:0] PADDR_i,
//    input PWRITE_i,
//    input PSEL_i,
//    input PENABLE_i,
//    input [7:0] PWDATA_i,
//    input ss_i,
//    input [7:0] miso_data_i,
//    input receive_data_i,
//    input tip_i,
//    output reg [7:0] PRDATA_o,
//    output PREADY_o,
//    output PSLVERR_o,
//    output mstr_o,
//    output cpol_o,
//    output cpha_o,
//    output lsbfe_o,
//    output [2:0] sppr_o,
//    output [2:0] spr_o,
//    output spiswai_o,
//    output reg spi_interrupt_request_o,
//    output reg send_data_o,
//    output reg [7:0] mosi_data_o,
//    output [1:0] spi_mode_o
//);
//
//	parameter CR1_ADDR = 3'b000;
//	parameter CR2_ADDR = 3'b001;
//	parameter BR_ADDR  = 3'b010;
//	parameter SR_ADDR  = 3'b011;
//	parameter DR_ADDR  = 3'b101;
//
//	parameter IDLE=2'b00, SETUP=2'b01, ENABLE=2'b10;
//	parameter SPI_STOP=2'b10, SPI_RUN=2'b00, SPI_WAIT=2'b01;
//
//	reg [1:0] state, next_state;
//	reg [1:0] spi_state, spi_next;
//
//	reg [7:0] CR1, CR2, BR, DR, SR;
//
//	wire write_en = PSEL_i & PENABLE_i &  PWRITE_i;
//	wire read_en  = PSEL_i & PENABLE_i & ~PWRITE_i;
//
//	assign PREADY_o  = (state == ENABLE);
//	assign PSLVERR_o = (state == ENABLE) && (PADDR_i > 3'b101 || PADDR_i == 3'b100) ? ~tip_i : 1'b0;
//
//	always @(posedge PCLK or negedge PRESETn) begin
//		 if (!PRESETn) state <= IDLE;
//		 else state <= next_state;
//	end
//
//	always @(*) begin
//		 case (state)
//			  IDLE:   next_state = (PSEL_i && !PENABLE_i) ? SETUP : IDLE;
//			  SETUP:  next_state = PSEL_i ? (PENABLE_i ? ENABLE : SETUP) : IDLE;
//			  //ENABLE: next_state = PSEL_i ? (PENABLE_i ? ENABLE : SETUP) : IDLE;
//			  ENABLE: next_state = PSEL_i ? SETUP : IDLE;
//			  default: next_state = IDLE;
//		 endcase
//	end
//
//	always @(posedge PCLK or negedge PRESETn) begin
//		 if (!PRESETn) begin
//			  CR1 <= 8'h04;
//			  CR2 <= 8'h00;
//			  BR  <= 8'h00;
//		 end 
//		 else if (write_en) begin
//			  case(PADDR_i)
//					CR1_ADDR: CR1 <= PWDATA_i;
//					CR2_ADDR: CR2 <= PWDATA_i & 8'b00011011;
//					BR_ADDR:  BR  <= PWDATA_i & 8'b01110111;
//			  endcase
//		 end
//		 else CR2 <= 8'h04;
//	end
//
//	assign mstr_o   = CR1[4];
//	assign cpol_o   = CR1[3];
//	assign cpha_o   = CR1[2];
//	assign lsbfe_o  = CR1[0];
//
//	assign spiswai_o = CR2[1];
//	assign sppr_o    = BR[6:4];
//	assign spr_o     = BR[2:0];
//
//	wire spe     = CR1[6];
//	wire spiswai = CR2[1];
//
//	always @(posedge PCLK or negedge PRESETn) begin
//		 if (!PRESETn) spi_state <= SPI_RUN;
//		 else spi_state <= spi_next;
//	end
//
//	always @(*) begin
//		case(spi_state)
//			SPI_RUN:  spi_next = spe ? SPI_RUN : SPI_WAIT;
//			SPI_WAIT: spi_next = (spe) ? SPI_RUN : (spiswai ? SPI_STOP : SPI_WAIT);
//				SPI_STOP: spi_next = (spe) ? SPI_RUN : (!spiswai ? SPI_WAIT : SPI_STOP);
//			default:  spi_next = SPI_RUN;
//		endcase
//	end
//
//	assign spi_mode_o = spi_state;
//
//
//	// DR LOGIC
//	wire apb_write_dr = write_en & (PADDR_i == DR_ADDR);
//	reg [7:0] DR_next;
//
//	always @(*) begin
//		 DR_next = DR;
//		 if (apb_write_dr)
//			  DR_next = PWDATA_i;
//		 else if (receive_data_i)
//			  DR_next = miso_data_i;
//		 else if (tip_i)
//			  DR_next = 8'b0;
//	end
//
//	always @(posedge PCLK or negedge PRESETn) begin
//		 if (!PRESETn)
//			  DR <= 8'b0;
//		 else
//			  DR <= DR_next;
//	end
//
//
//	// TRANSMIT
//	always @(posedge PCLK or negedge PRESETn) begin
//		 if (!PRESETn) begin
//			  send_data_o <= 1'b0;
//			  mosi_data_o <= 8'b0;
//		 end
//		 else begin
//			  send_data_o <= (write_en && (PADDR_i == DR_ADDR));
//			  if (write_en && (PADDR_i == DR_ADDR))
//					mosi_data_o <= PWDATA_i;
//		 end
//	end
//
//
//	// STATUS
//	reg spif, sptef;
//	wire modf;
//	wire ssoe   = CR1[1];
//	wire modfen = CR2[4];
//
//	assign modf = (~ss_i) & mstr_o & modfen & (~ssoe);
//
//	always @(*) begin
//		 sptef = (DR == 8'b0);
//		 spif  = (DR != 8'b0);
//	end
//
//	always @(*) begin
//		 SR = {spif,1'b0,sptef,modf,4'b0};
//	end
//
//
//	// READ
//	always @(*) begin
//		 PRDATA_o = 8'h00;
//		 if (read_en) begin
//			  case(PADDR_i)
//					CR1_ADDR: PRDATA_o = CR1;
//					CR2_ADDR: PRDATA_o = CR2;
//					BR_ADDR:  PRDATA_o = BR;
//					SR_ADDR:  PRDATA_o = SR;
//					DR_ADDR:  PRDATA_o = DR;
//			  endcase
//		 end
//	end
//
//
//	// INTERRUPT
//	wire spie;
//	assign spie  = CR1[7];
//
//	always @(posedge PCLK or negedge PRESETn) begin
//		 if (!PRESETn)
//			  spi_interrupt_request_o <= 1'b0;
//		 else
//			  spi_interrupt_request_o <= spie & (spif | sptef | modf);
//	end
//
//	endmodule