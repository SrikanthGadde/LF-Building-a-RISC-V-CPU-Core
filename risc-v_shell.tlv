\m4_TLV_version 1d: tl-x.org
\SV
   // This code can be found in: https://github.com/stevehoover/LF-Building-a-RISC-V-CPU-Core/risc-v_shell.tlv
   
   m4_include_lib(['https://raw.githubusercontent.com/stevehoover/warp-v_includes/1d1023ccf8e7b0a8cf8e8fc4f0a823ebb61008e3/risc-v_defs.tlv'])
   m4_include_lib(['https://raw.githubusercontent.com/stevehoover/LF-Building-a-RISC-V-CPU-Core/main/lib/risc-v_shell_lib.tlv'])

   m4_test_prog()

\SV
   m4_makerchip_module   // (Expanded in Nav-TLV pane.)
   /* verilator lint_on WIDTH */
\TLV
   
   $reset = *reset;
   
   //PC
   $next_pc[31:0] = $reset ? 32'd0 :
                    $taken_br ? $br_tgt_pc :
                                $pc+32'd4;
   $pc[31:0] = >>1$next_pc;
   
   //IMEM
   `READONLY_MEM($pc, $$instr[31:0]);
   
   //INSTR_TYPE
   $is_u_instr = $instr[6:2] ==? 5'b0x101;
   $is_b_instr = $instr[6:2] ==? 5'b11000;
   $is_j_instr = $instr[6:2] ==? 5'b11011;
   $is_s_instr = $instr[6:2] ==? 5'b0100x;
   $is_i_instr = $instr[6:2] ==? 5'b0000x || 
                 $instr[6:2] ==? 5'b001x0 || 
                 $instr[6:2] == 5'b11001;
   $is_r_instr = $instr[6:2] ==? 5'b011x0 || 
                 $instr[6:2] == 5'b01011 || 
                 $instr[6:2] == 5'b10100;
   
   //FIELDS
   $opcode[6:0] = $instr[6:0];
   $rd[4:0] = $instr[11:7];
   $rs2[4:0] = $instr[24:20];
   $rs1[4:0] = $instr[19:15];
   $funct3[2:0] = $instr[14:12];
   $funct7[6:0] = $instr[31:25];
   
   //FIELDS_VALID
   $rd_valid = $is_r_instr || $is_i_instr || $is_u_instr || $is_j_instr;
   $rs2_valid = $is_r_instr || $is_s_instr || $is_b_instr;
   $rs1_valid = $is_r_instr || $is_i_instr || $is_s_instr || $is_b_instr;
   $funct3_valid = $is_r_instr || $is_i_instr || $is_s_instr || $is_b_instr;
   $funct7_valid = $is_r_instr;
   $imm_valid = ~$is_r_instr;
   
   //IMM
   $imm[31:0] = $is_i_instr ? { {21{$instr[31]}}, $instr[30:20] } :
                $is_s_instr ? { {21{$instr[31]}}, $instr[30:25], $instr[11:7] } :
                $is_b_instr ? { {20{$instr[31]}}, $instr[7], $instr[30:25], $instr[11:8], 1'b0 } :
                $is_u_instr ? { $instr[31:12], 12'b0 } :
                $is_j_instr ? { {12{$instr[31]}}, $instr[19:12], $instr[20], $instr[30:21], 1'b0 } :
                32'b0;  // Default
   
   //Instruction decoding
   $dec_bits[10:0] = {$funct7[5],$funct3,$opcode};
   
   //SUBSET_INSTRS
   $is_beq = $dec_bits ==? 11'bx_000_1100011;
   $is_bne = $dec_bits ==? 11'bx_001_1100011;
   $is_blt = $dec_bits ==? 11'bx_100_1100011;
   $is_bge = $dec_bits ==? 11'bx_101_1100011;
   $is_bltu = $dec_bits ==? 11'bx_110_1100011;
   $is_bgeu = $dec_bits ==? 11'bx_111_1100011;
   $is_addi = $dec_bits ==? 11'bx_000_0010011;
   $is_add = $dec_bits ==? 11'b0_000_0110011;
   
   //RF_READ
   $rd1_en = $rs1_valid;
   $rd2_en = $rs2_valid;
   $rd1_index[4:0] = $rs1[4:0];
   $rd2_index[4:0] = $rs2[4:0];
   $src1_value[31:0] = $rd1_data[31:0];
   $src2_value[31:0] = $rd2_data[31:0];
   
   //SUBSET_ALU
   $result[31:0] = $is_addi ? $src1_value + $imm :
                   $is_add ? $src1_value + $src2_value :
                             32'b0;
   
   //RF_WRITE
   $wr_en = $rd_valid && ($rd != 5'b0);
   $wr_index[4:0] = $rd[4:0];
   $wr_data[31:0] = $result;
   
   //TAKEN_BR
   $taken_br = $is_beq ? $src1_value == $src2_value :
               $is_bne ? $src1_value != $src2_value :
               $is_blt ? ($src1_value < $src2_value) ^ ($src1_value[31] != $src2_value[31]) :
               $is_bge ? ($src1_value >= $src2_value) ^ ($src1_value[31] != $src2_value[31]) :
               $is_bltu ? $src1_value < $src2_value :
               $is_bgeu ? $src1_value >= $src2_value :
                          1'b0;
   
   //BR_REDIR
   $br_tgt_pc[31:0] = $pc + $imm;
   
   `BOGUS_USE($imm_valid $funct3_valid $funct7_valid);
   
   // Assert these to end simulation (before Makerchip cycle limit).
   //TB
   m4+tb()
   *failed = *cyc_cnt > M4_MAX_CYC;
   
   m4+rf(32, 32, $reset, $wr_en, $wr_index[4:0], $wr_data[31:0], $rd1_en, $rd1_index[4:0], $rd1_data, $rd2_en, $rd2_index[4:0], $rd2_data)
   //m4+dmem(32, 32, $reset, $addr[4:0], $wr_en, $wr_data[31:0], $rd_en, $rd_data)
   m4+cpu_viz()
\SV
   endmodule
