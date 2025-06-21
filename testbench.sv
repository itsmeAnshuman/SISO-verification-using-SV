class transaction;
   rand bit in;
  bit out;
  bit clock ,rst;
endclass
//////////////////////
class generator;
  transaction tr;
  mailbox #(transaction) mxb;
  event done;
  event next;
  
  function new(mailbox#(transaction) mxb);
    this.mxb=mxb;
    
  endfunction
  
  task run();
    repeat(10) begin
      tr=new();
      assert(tr.randomize) else $error("Randomization failed");
      mxb.put(tr);
      $display("[GEN] : data sent iin:%0d",tr.in);
    @(next);
    end
    ->done;
  endtask
endclass
////////////////////////////
class driver;
  transaction tr;
  mailbox#(transaction) mxb;
  virtual siso_if sis;
  function new(mailbox#(transaction)mxb);
    this.mxb=mxb;
  endfunction
  
  task reset();
    sis.rst<=1'b1;
      sis.in<=0;
    repeat(5)@(posedge sis.clock);
    sis.rst<=1'b0;
    $display("RESET is done");
    $display("---------------");
  endtask
  
  task run();
    forever begin
      mxb.get(tr);
      sis.in<=tr.in;
      @(posedge sis.clock);
    end
  endtask
endclass
/////////////////////////////
class monitor;
  virtual siso_if sis;
  mailbox#(transaction) mxb;
  transaction tr;
  function new(mailbox#(transaction) mxb);
    this.mxb=mxb;
  endfunction
  
  task run();
   
    forever begin
       tr=new();
      repeat(2) @(posedge sis.clock);
      tr.in=sis.in;
      @(posedge sis.clock);
      tr.out=sis.out;
      mxb.put(tr);
      $display("[MON] : in: %0d out : %0d",tr.in,tr.out);
    end
  endtask
endclass
/////////////////////////////////
class scoreboard;
  transaction tr;
  virtual siso_if sis;
  event next;
  bit [3:0]temp=0;
  mailbox#(transaction) mbx;
  function new(mailbox#(transaction) mbx);
    this.mbx=mbx;
  endfunction
  bit expected;
  task run();
    forever begin
      
      mbx.get(tr);
      temp=(temp>>1)|(tr.in<<3);
       expected = temp[0]; 
      $display("[SCO] : in : %0d out : %0d",tr.in ,tr.out);
      
      if(tr.out==expected) begin
        $display("DATA MATCHED");
      end
        else begin
          $display("DATA MISMATCHED");
        end
      
      $display("------------");
      ->next;
    end
  endtask
endclass
////////////////////////////
class environment;
  generator gen;
  driver drv;
  monitor mon;
  scoreboard scb;
  mailbox #(transaction) gen2drv;
  mailbox #(transaction) mon2scb;
  virtual siso_if sis;
  event next_event;

  function new(virtual siso_if sis);
    this.sis = sis;
    gen2drv = new();
    mon2scb = new();
    gen = new(gen2drv);
    drv = new(gen2drv);
    mon = new(mon2scb);
    scb = new(mon2scb);

    drv.sis = sis;
    mon.sis = sis;
    scb.sis = sis;

    gen.next = next_event;
    scb.next = next_event;
  endfunction
endclass

//================= Test ======================
class test;
  environment env;
  virtual siso_if sis;

  function new(virtual siso_if sis);
    this.sis = sis;
    env = new(sis);
  endfunction

  task run();
    env.drv.reset();             // pre-test phase

    fork                         // test phase
      env.gen.run();
      env.drv.run();
      env.mon.run();
      env.scb.run();
    join_any

    wait(env.gen.done.triggered);
    $display("------ TEST DONE ------");
    $finish();                   // post-test
  endtask
endclass
////////////////////
module tb;
  siso_if sis();                  // Interface instantiation

  siso dut(                       // DUT connection
    .clk(sis.clock),
    .rst(sis.rst),
    .in(sis.in),
    .out(sis.out)
  );

  test t;

  // Clock generation
  initial begin
    sis.clock = 0;
    forever #5 sis.clock = ~sis.clock;
  end

  // Run test
  initial begin
    t = new(sis);
    t.run();
  end

  // Dump waves
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, tb);
  end
endmodule
