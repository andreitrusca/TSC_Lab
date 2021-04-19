/***********************************************************************
 * A SystemVerilog testbench for an instruction register.
 * The course labs will convert this to an object-oriented testbench
 * with constrained random test generation, functional coverage, and
 * a scoreboard for self-verification.
 *
 * SystemVerilog Training Workshop.
 * Copyright 2006, 2013 by Sutherland HDL, Inc.
 * Tualatin, Oregon, USA.  All rights reserved.
 * www.sutherland-hdl.com
 **********************************************************************/

module instr_register_test (tb_ifc tbifc);  // interface port

  timeunit 1ns/1ns;

  // user-defined types are defined in instr_register_pkg.sv
  import instr_register_pkg::*;

  int seed = 555;

  class Transaction;
    rand opcode_t       opcode;
    rand operand_t      operand_a, operand_b;
    address_t      write_pointer;
    //, read_pointer;
    //instruction_t  instruction_word;

    constraint operand_a_const{
      operand_a > -16;
      operand_a < 16;
    }

     constraint operand_b_const{
       operand_b > -1;
       operand_b < 16;
     }

     constraint opcode_const{
       opcode >= 0;
       opcode < 8;
     }
    //function void randomize_transaction();
    //  static int temp = 0;
    //  operand_a     = $random(seed)%16;                 // between -15 and 15
    //  operand_b     = $unsigned($random)%16;            // between 0 and 15
    //  opcode        = opcode_t'($unsigned($random)%8);  // between 0 and 7, cast to opcode_t type
    //  write_pointer = temp++;
    //endfunction: randomize_transaction

    virtual function void print_transaction;
      $display("Writing to register location %0d: ", write_pointer);
      $display("  opcode = %0d (%s)", opcode, opcode.name);
      $display("  operand_a = %0d",   operand_a);
      $display("  operand_b = %0d\n", operand_b);
    endfunction: print_transaction

    function void post_randomize();
      static int temp = 0;

      write_pointer = temp++;
    endfunction: post_randomize

  endclass: Transaction

  class Transaction_exp extends Transaction;

    virtual function void print_transaction();
      $display("I am an extended function ");
      super.print_transaction();
    endfunction: print_transaction

  endclass: Transaction_exp

  class Driver;
    virtual tb_ifc vifc;
    Transaction trans;
    Transaction_exp trans_exp;

    function new(virtual tb_ifc vifc);
      this.vifc = vifc; 
      trans = new(); 
      trans_exp =new();
    endfunction

    task generate_transaction;
      $display("\nReseting the instruction register...");
      vifc.cb.write_pointer <= 4'h00;      // initialize write pointer
      vifc.cb.read_pointer  <= 5'h1F;      // initialize read pointer
      vifc.cb.load_en       <= 1'b0;       // initialize load control line
      vifc.cb.reset_n       <= 1'b0;       // assert reset_n (active low)
      repeat (2) @vifc.cb ;  // hold in reset for 2 clock cycles
      vifc.cb.reset_n       <= 1'b1;       // assert reset_n (active low)

      @vifc.cb vifc.load_en <= 1'b1;  // enable writing to register
      repeat (3) begin
        @vifc.cb trans.randomize();
        vifc.cb.operand_a <= trans.operand_a;
        vifc.cb.operand_b <= trans.operand_b;
        vifc.cb.opcode <= trans.opcode;
        vifc.cb.write_pointer <= trans.write_pointer;
        @vifc.cb trans.print_transaction();
        
      end
      @vifc.cb vifc.load_en <= 1'b0;  // turn-off writing to register
      repeat (3) begin
        @vifc.cb trans_exp.randomize();
        vifc.cb.operand_a <= trans_exp.operand_a;
        vifc.cb.operand_b <= trans_exp.operand_b;
        vifc.cb.opcode <= trans_exp.opcode;
        vifc.cb.write_pointer <= trans_exp.write_pointer;
        @vifc.cb trans_exp.print_transaction();
        
      end
    endtask

  endclass: Driver

  class Monitor;
    virtual tb_ifc vifc;

    function new(virtual tb_ifc vifc);
      this.vifc = vifc;  
    endfunction

    function void print_results;
      $display("Read from register location %0d: ", vifc.read_pointer);
      $display("  opcode = %0d (%s)", vifc.instruction_word.opc, vifc.instruction_word.opc.name);
      $display("  operand_a = %0d",   vifc.instruction_word.op_a);
      $display("  operand_b = %0d\n", vifc.instruction_word.op_b);
    endfunction: print_results

    task transaction_monitor();
      $display("\nReading back the same register locations written...");
      for (int i=0; i<=2; i++) begin
        @(this.vifc.cb) this.vifc.cb.read_pointer <= i;
        @(this.vifc.cb) this.print_results();
      end
    endtask

  endclass: Monitor

  initial begin
   
    Driver driver;
    Monitor monitor;

    driver = new(tbifc);
    monitor = new(tbifc);

    driver.generate_transaction();
    monitor.transaction_monitor();

    @(tbifc.cb) $finish;

  end

endmodule: instr_register_test
