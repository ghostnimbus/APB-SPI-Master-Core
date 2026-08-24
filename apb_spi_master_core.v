`define DATA_WIDTH 8
`define ADDR_WIDTH 3

module apb_spi_master_core(
    input PCLK,
    input PRESETn,
    input [`ADDR_WIDTH-1:0] PADDR,
    input PWRITE,
    input PSEL,
    input PENABLE,
    input [`DATA_WIDTH-1:0] PWDATA,
    input miso,
    output [`DATA_WIDTH-1:0] PRDATA,
    output PREADY,
    output PSLVERR,
    output ss,
    output sclk,
    output spi_interrupt_request,
    output mosi
);

    // internal data paths
    wire [`DATA_WIDTH-1:0] data_miso_s;
    wire [`DATA_WIDTH-1:0] data_mosi_s;

    // control signals
    wire send_data_s;
    wire receive_data_s;
    wire tip_s;
    wire [1:0] spi_mode_s;

    wire mstr_s;
    wire cpol_s;
    wire cpha_s;
    wire lsbfe_s;
    wire spiswai_s;
    wire [2:0] sppr_s;
    wire [2:0] spr_s;
    wire [11:0] BaudRateDivisor_s;

    // clock signals from baud generator
    wire miso_receive_sclk_s;
    wire miso_receive_sclk0_s;
    wire mosi_send_sclk_s;
    wire mosi_send_sclk0_s;
	 
	 baud_generator bg ( .PCLK(PCLK),
				.PRESET_n(PRESETn),
				.spi_mode_i(spi_mode_s),
				.spiswai_i(spiswai_s),
				.sppr_i(sppr_s),
				.spr_i(spr_s),
				.cpol_i(cpol_s),
				.cpha_i(cpha_s),
				.ss_i (ss),
				.sclk_o(sclk), 
				.miso_receive_sclk_o(miso_receive_sclk_s),
				.miso_receive_sclk0_o(miso_receive_sclk0_s),
				.mosi_send_sclk_o(mosi_send_sclk_s),
				.mosi_send_sclk0_o(mosi_send_sclk0_s),
				.BaudRateDivisor_o(BaudRateDivisor_s)
				);
		
		apb_slave_interface si (.PCLK(PCLK),
				.PRESETn(PRESETn),
				.PADDR_i(PADDR),
				.PWRITE_i(PWRITE),
				.PSEL_i(PSEL),
				.PENABLE_i(PENABLE),
				.PWDATA_i(PWDATA),
				.ss_i(ss),
				.miso_data_i(data_miso_s),
				.receive_data_i(receive_data_s),
				.tip_i(tip_s),
				.PRDATA_o(PRDATA),
				.mstr_o(mstr_s),
				.cpol_o(cpol_s),
				.cpha_o(cpha_s),
				.lsbfe_o(lsbfe_s),
				.spiswai_o(spiswai_s),
				.sppr_o(sppr_s),
				.spr_o(spr_s),
				.spi_interrupt_request_o(spi_interrupt_request),
				.PREADY_o(PREADY),
				.PSLVERR_o(PSLVERR),
				.send_data_o(send_data_s),
				.mosi_data_o(data_mosi_s),
				.spi_mode_o(spi_mode_s)
	 );
	 
	 
	shift_register spi_shifter(
        .PCLK(PCLK),
        .PRESETn(PRESETn),
        .ss_i(ss),
        .send_data_i(send_data_s),
        .lsbfe_i(lsbfe_s),
        .cpha_i(cpha_s),
        .cpol_i(cpol_s),
        .miso_receive_sclk_i(miso_receive_sclk_s),
        .miso_receive_sclk0_i(miso_receive_sclk0_s),
        .mosi_send_sclk_i(mosi_send_sclk_s),
        .mosi_send_sclk0_i(mosi_send_sclk0_s),
        .data_mosi_i(data_mosi_s),
        .miso_i(miso),
        .receive_data_i(receive_data_s),
        .data_miso_o(data_miso_s),
        .mosi_o(mosi)
    );
	 
	 slave_control_select spi_select(
        .PCLK(PCLK),
        .PRESETn(PRESETn),
        .spi_mode_i(spi_mode_s),
        .mstr_i(mstr_s),
        .spiswai_i(spiswai_s),
        .send_data_i(send_data_s),
        .BaudRateDivisor_i(BaudRateDivisor_s),
        .ss_o(ss),
        .receive_data_o(receive_data_s),
        .tip_o(tip_s)
    );
endmodule 

	
