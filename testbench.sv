interface mux_if;
    logic [3:0] I;
    logic [1:0] S;
    logic Y;
    logic sample;
endinterface

class transaction;
    bit [3:0] I;
    bit [1:0] S;
    bit Y;
endclass

class generator;
    mailbox #(transaction) gen2drv;
    function new(mailbox #(transaction) gen2drv);
        this.gen2drv = gen2drv;
    endfunction
    task run();
        transaction tr;
        for (int i = 0; i < 16; i++) begin
            for (int j = 0; j < 4; j++) begin
                tr = new();
                tr.I = i;
                tr.S = j;
                gen2drv.put(tr);
            end
        end
    endtask
endclass

class driver;
    virtual mux_if vif;
    mailbox #(transaction) gen2drv;
    function new(virtual mux_if vif,
                 mailbox #(transaction) gen2drv);
        this.vif = vif;
        this.gen2drv = gen2drv;
    endfunction
    task run();
        transaction tr;
        vif.sample = 0;
        repeat (64) begin
            gen2drv.get(tr);
            vif.I = tr.I;
            vif.S = tr.S;
            #1;
            vif.sample = 1;
            #1;
            vif.sample = 0;
        end
    endtask
endclass

class monitor;
    virtual mux_if vif;
    mailbox #(transaction) mon2scb;
    function new(virtual mux_if vif,
                 mailbox #(transaction) mon2scb);
        this.vif = vif;
        this.mon2scb = mon2scb;
    endfunction
    task run();
        transaction tr;
        repeat (64) begin
            @(posedge vif.sample);
            tr = new();
            tr.I = vif.I;
            tr.S = vif.S;
            tr.Y = vif.Y;
            mon2scb.put(tr);
        end
    endtask
endclass

class scoreboard;
    mailbox #(transaction) mon2scb;
    int pass_count = 0;
    int fail_count = 0;
    function new(mailbox #(transaction) mon2scb);
        this.mon2scb = mon2scb;
    endfunction
    task run();
        transaction tr;
        bit expected;
        repeat (64) begin
            mon2scb.get(tr);
            expected = tr.I[tr.S];
            if (tr.Y === expected) begin
                pass_count++;
                $display("PASS: I=%b S=%b Y=%b",
                         tr.I, tr.S, tr.Y);
            end
            else begin
                fail_count++;
                $display("FAIL: I=%b S=%b Expected=%b Actual=%b",
                         tr.I, tr.S, expected, tr.Y);
            end
        end
        $display("--------------------------------");
        $display("SIMULATION SUMMARY");
        $display("Total tests : 64");
        $display("Passed      : %0d", pass_count);
        $display("Failed      : %0d", fail_count);
        $display("--------------------------------");
    endtask
endclass

class environment;
    mailbox #(transaction) gen2drv;
    mailbox #(transaction) mon2scb;
    generator gen;
    driver drv;
    monitor mon;
    scoreboard scb;
    function new(virtual mux_if vif);
        gen2drv = new();
        mon2scb = new();
        gen = new(gen2drv);
        drv = new(vif, gen2drv);
        mon = new(vif, mon2scb);
        scb = new(mon2scb);
    endfunction
    task run();
        fork
            gen.run();
            drv.run();
            mon.run();
            scb.run();
        join
    endtask
endclass

class test;
    environment env;
    function new(virtual mux_if vif);
        env = new(vif);
    endfunction
    task run();
        env.run();
    endtask
endclass

module tb;
    mux_if vif();
    mux_4to1 dut (.I(vif.I), .S(vif.S), .Y(vif.Y));
    test t;
    initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, tb);
    t = new(vif);
    t.run();
    $display("TEST COMPLETED");
    $finish;
end
endmodule







