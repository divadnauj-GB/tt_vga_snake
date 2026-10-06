module tt_um_vga_example_tb;


reg [7:0] ui_in;    // Dedicated inputs
wire [7:0] uo_out;   // Dedicated outputs
reg [7:0] uio_in;   // IOs: Input path
wire [7:0] uio_out;  // IOs: Output path
wire [7:0] uio_oe;   // IOs: Enable path (active high: 0=input, 1=output)
reg       ena;      // always 1 when the design is powered, so you can ignore it
reg       clk;      // clock
reg       rst_n;     // reset_n - low to reset


initial begin
    $dumpfile("sim.vcd");
    $dumpvars;
end

always begin
    clk = ~clk;
    #5;
end

initial begin
    ui_in = 0;
    clk = 0;
    rst_n = 0;
    ena = 0;
    #10;
    rst_n = 1;
    #9000000;
    $finish;
end



tt_um_vga_example dut(
    .ui_in(ui_in),  
    .uo_out(uo_out), 
    .uio_in(uio_in), 
    .uio_out(uio_out),
    .uio_oe(uio_oe), 
    .ena(ena),    
    .clk(clk),    
    .rst_n(rst_n)   
);



endmodule