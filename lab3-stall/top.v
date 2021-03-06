`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    19:45:05 04/20/2015 
// Design Name: 
// Module Name:    top 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module top(
input CCLK, BTN0,BTN1,BTN2,BTN3, 
input [3:0] SW, 
output LCDRS, LCDRW, LCDE, 
output [3:0] LCDDAT, 
output [7:0] LED
    );
	`include "mips.vh"
	//anti_jitter & inp	ut signals
	wire BTN0Out,BTN1Out,BTN2Out,BTN3Out,RST,CLK,REGCHOOSE;
	
	//anti_jitter button0(CCLK, BTN0, BTN0Out); 	//RESET
	//anti_jitter button1(CCLK, BTN1, BTN1Out);	//CLK
	//anti_jitter button2(CCLK, BTN2, BTN2Out);	//CHOOSE REGISTER
	//anti_jitter button3(CCLK, BTN3, BTN3Out);	//BAKCUP
	
	assign BTN0Out=BTN0;
	assign BTN1Out=BTN1;
	assign BTN2Out=BTN2;
	assign BTN3Out=BTN3;
	
	wire[2:0]ctrl_4out;
	
	assign RST=BTN0Out;
	assign CLK=BTN1Out;
	assign REGCHOOSE=BTN2Out;
	
	wire jumpSignal,branchSignal,bne,beq;
	
	//Control signals' defination
	wire if_valid,id_valid,exe_valid,mem_valid,wb_valid;
	wire if_en,id_en,exe_en,mem_en,wb_en;
	wire if_rst,id_rst,exe_rst,mem_rst,wb_rst;
	wire imm_ext;
	wire exe_b_src;
	wire [3:0]exe_alu_oper;
	wire mem_ren;
	wire mem_wen;
	wire wb_addr_src;
	wire wb_data_src;
	wire is_branch;
	wire rs_used;
	wire rd_used;
	wire unrecognized;
	reg reg_stall;
	reg single_stall;
	wire [7:0] op_type_if, op_type_id, op_type_exe, op_type_mem, op_type_wb;
	
	wire [14:0]ctrl_2in,ctrl_2out;
	
	wire [4:0]regw_addr_exe, regw_addr_mem, regw_addr_wb;
	wire wb_wen, wb_wen_exe, wb_wen_mem, wb_wen_wb;

	wire [31:0]instr,memDataOut;
	
	//IF TinyPipeLine
	wire [31:0]instr_1in,instr_1out;
	wire [31:0]pc_1in,pc_1out;
	reg [31:0] pc_in;
	wire [31:0]pc_out;
	
	reg [31:0]pc_tmp=0;
	wire ip_rst,ip_en;
	reg control_stall;
	
	wire [31:0] pc_next_if, pc_next_id, pc_next_exe, pc_next_mem; 
	
	IF if_stage(
		.en(if_en),
		.clk(CLK),
		.rst(if_rst),
		.ipc(pc_in), /////
		.opc(pc_out),
		.valid(if_valid),
		.pc_next_out(pc_next_if)
	);
	
	//singlePcPlus pcplus0(pc_out,pc_1in); 

	//instr_rom  //tmp ~clk
	IP ip0(
		.clka(~CLK),
		.addra(pc_out[9:0]),
		.douta(instr)
	);
	
	instrType type0(instr, op_type_if);
	
	assign instr_1in=instr;
	ID id_stage(
		.en(id_en),
		.clk(CLK),
		.rst(id_rst),
		.instr_in(instr_1in),
		.instr_out(instr_1out),
		.pc_in(pc_out),
		.pc_out(pc_1out),
		.valid_in(if_valid),
		.valid(id_valid),
		.pc_next_in(pc_next_if),
		.pc_next_out(pc_next_id)
	);
	
	//CTRL TinyPipeLine
	pipeController ctrl0(
		.clk(CLK),
		.rst(RST),
		.instr(instr_1out),
		.out(ctrl_2in),
		.imm_ext(imm_ext),
		.exe_b_src(exe_b_src),
		.exe_alu_oper(exe_alu_oper),
		.mem_ren(mem_ren),
		.mem_wen(mem_wen),
		.wb_addr_src(wb_addr_src),
		.wb_data_src(wb_data_src),
		.wb_wen(wb_wen),
		.is_branch(is_branch),
		.rs_used(rs_used),
		.rt_used(rt_used),
		.unrecognized(),
		.reg_stall(reg_stall),
		.if_rst(if_rst),
		.if_en(if_en),
		.if_valid(if_valid),
		.id_rst(id_rst),
		.id_en(id_en),
		.id_valid(id_valid),
		.exe_rst(exe_rst),
		.exe_en(exe_en),
		.exe_valid(exe_valid),
		.mem_rst(mem_rst),
		.mem_en(mem_en),
		.mem_valid(mem_valid),
		.wb_rst(wb_rst),
		.wb_en(wb_en),
		.wb_valid(wb_valid),
		.control_stall(control_stall),
		.ip_rst(ip_rst),
		.ip_en(ip_en),
		.single_stall(single_stall),
		.op_type(op_type_id)
	);
	
	//regFile
	wire [4:0]reg1,reg2,reg3,regAddr;
	wire writeReg;
	wire [31:0]regOut1,regOut2,regOut3,writeRegData;
	assign reg1=instr_1out[25:21];
	assign reg2=instr_1out[20:16];
	assign reg3={REGCHOOSE,SW[3:0]};
	assign writeReg=ctrl_4out[2]; 
	regFile regfile0(
		.clk(CLK),
		.rst(RST),
		.wreg(wb_wen_wb),
		.n1(reg1),.n2(reg2),.n3(reg3),
		.writeReg(regAddr),
		.regData(writeRegData),
		.op1(regOut1),.op2(regOut2),.op3(regOut3)
	);
	
	//save write reg addr
	reg [4:0]regw_addr;
	initial begin regw_addr=0; end
	always @(*) begin
		regw_addr = instr_1out[15:11];
		case (wb_addr_src)
			WB_ADDR_RD: regw_addr = instr_1out[15:11];
			WB_ADDR_RT: regw_addr = instr_1out[20:16];
		endcase
	end
	
	//stall
	reg AFromExe, BFromExe, AFromMem, BFromMem, SFromAddr, CFromMem, CFromExe, CFromWb;
	initial begin reg_stall=0; control_stall=0; single_stall=0; end
	always @(*) begin
		reg_stall = 0;
		AFromExe = rs_used && (reg1 != 0) && (regw_addr_exe == reg1) && wb_wen_exe;
		BFromExe = rt_used && (reg2 != 0) && (regw_addr_exe == reg2) && wb_wen_exe;
		AFromMem = rs_used && (reg1 != 0) && (regw_addr_mem == reg1) && wb_wen_mem;
		BFromMem = rt_used && (reg2 != 0) && (regw_addr_mem == reg2) && wb_wen_mem;
		reg_stall = AFromExe || BFromExe || AFromMem || BFromMem ;	
		single_stall = AFromMem || BFromMem;
		CFromExe = op_type_exe==8'h0D || op_type_exe==8'h0E || op_type_exe==8'h0F;
		CFromMem = op_type_mem==8'h0D || op_type_mem==8'h0E || op_type_mem==8'h0F;
		CFromWb = op_type_wb==8'h0D || op_type_wb==8'h0E || op_type_wb==8'h0F;
		control_stall = CFromExe ;//|| CFromMem ;
	end

	wire [31:0]sign_ext_2in,sign_ext_2out,zero_ext_2in,zero_ext_2out;
	wire [31:0]pc_2out,instr_2out;
	wire [4:0]shift_2out;
	wire [31:0]opa_id_exe,opb_id_exe;
	
	zeroExtend zero0(instr_1out[15:0],zero_ext_2in);
	signExtend sign0(instr_1out[15:0],sign_ext_2in);
	
	wire [31:0]data_imm;
	assign data_imm = imm_ext ? sign_ext_2in : zero_ext_2in; 
	
	reg [31:0]opa_id, opb_id, data_rt;
	initial begin opa_id=0; opb_id=0; end
	always @(*) begin
		opa_id = regOut1;
		opb_id = regOut2;
		data_rt = regOut2;
		case (exe_b_src)
			EXE_B_RT: opb_id = regOut2;
			EXE_B_IMM: opb_id = data_imm;
		endcase
	end
	
	wire [31:0] data_rt_exe;

	//EXE TinyPipeLine
	wire mem_wen_exe;
	EXE exe_stage(
		.en(exe_en),
		.clk(CLK),
		.rst(exe_rst),
		.valid(exe_valid),
		.valid_in(id_valid),
		.pc_in(pc_1out),
		.pc_out(pc_2out),
		.sign_ext_in(sign_ext_2in),
		.sign_ext_out(sign_ext_2out),
		.zero_ext_in(zero_ext_2in),
		.zero_ext_out(zero_ext_2out),
		.opa_in(opa_id),
		.opa_out(opa_id_exe),
		.opb_in(opb_id),
		.opb_out(opb_id_exe),
		.ctrl_in(ctrl_2in),
		.data_rt_in(data_rt),
		.data_rt_out(data_rt_exe),
		.ctrl_out(ctrl_2out),
		.instr_in(instr_1out),
		.instr_out(instr_2out),
		.regw_addr_in(regw_addr),
		.regw_addr_out(regw_addr_exe),
		.shift_out(shift_2out),
		.wb_wen_in(wb_wen),
		.wb_wen_out(wb_wen_exe),
		.mem_wen_in(mem_wen),
		.mem_wen_out(mem_wen_exe),
		.op_type_in(op_type_id),
		.op_type_out(op_type_exe),
		.pc_next_in(pc_next_id),
		.pc_next_out(pc_next_exe)
	);

	wire [31:0]aluA,aluB,aluOut;
	wire [3:0]aluCtrl;
	wire [4:0]sa;
	wire zero;
	assign sa=shift_2out;
	assign aluA=opa_id_exe;
	assign aluB=opb_id_exe;
	//mux32_2 alub0(opb_2out,sign_ext_2out,zero_ext_2out,ctrl_2out[1],ctrl_2out[8],aluB);

	aluC alc0(ctrl_2out[13:9],instr_2out[5:0],aluCtrl);
	
	//ALU TinyPipeLine
	alu a0(
		.opa(aluA),
		.opb(aluB),
		.alu_ctrl(aluCtrl),
		.sa(sa),
		.zero(zero),
		.alu_out(aluOut)
	);

	wire [31:0]jmp_pc,opb_id_mem,alu_3out,pc_3out,im_pc_3out,jmp_pc_3out;
	wire [7:0]ctrl_3out;
	wire [31:0]im_pc;
	wire zero_3out;
	assign im_pc=sign_ext_2out+pc_2out;
	assign jmp_pc={pc_2out[31:26],instr_2out[25:0]};

	wire [31:0] data_rt_mem;
	//MEM TinyPipeLine
	wire mem_wen_mem;
	MEM mem_stage(
		.en(mem_en),
		.clk(CLK),
		.rst(mem_rst),
		.valid(mem_valid),
		.valid_in(exe_valid),
		.pc_in(pc_2out),
		.pc_out(pc_3out),
		.zero_in(zero),
		.zero_out(zero_3out),
		.alu_res_in(aluOut),
		.alu_res_out(alu_3out),
		.opb_in(opb_id_exe),
		.opb_out(opb_id_mem),
		.data_rt_in(data_rt_exe),
		.data_rt_out(data_rt_mem),
		.regw_addr_in(regw_addr_exe),
		.regw_addr_out(regw_addr_mem),
		.im_pc_in(im_pc),
		.im_pc_out(im_pc_3out),
		.jmp_pc_in(jmp_pc),
		.jmp_pc_out(jmp_pc_3out),
		.ctrl_in(ctrl_2out),
		.ctrl_out(ctrl_3out),
		.wb_wen_in(wb_wen_exe),
		.wb_wen_out(wb_wen_mem),
		.mem_wen_in(mem_wen_exe),
		.mem_wen_out(mem_wen_mem),
		.op_type_in(op_type_exe),
		.op_type_out(op_type_mem),
		.pc_next_in(pc_next_exe),
		.pc_next_out(pc_next_mem)
	);
	
	//reg 
	//always @(*) begin
		
	//end
	
	//data_ram
	wire memWrite;
	wire [31:0]memAddr,memDataIn;
	//assign memDataIn=alu_3out;
	assign memDataIn=data_rt_mem;
	assign memWrite=mem_wen_mem;
	//assign memAddr=opb_id_mem;	
	assign memAddr=alu_3out;
	
	assign jumpSignal=ctrl_3out[6];
	assign bne=ctrl_3out[5]&&~zero_3out;
	assign beq=ctrl_3out[4]&&zero_3out;
	assign branchSignal=beq|bne;

	DATA data0(
		.clka(~CLK),
		.addra(memAddr[9:0]),
		.wea(memWrite),
		.dina(memDataIn),
		.douta(memDataOut)
	);

	//WB TinyPipeLine
	wire branch_wb;
	wire[31:0]alu_4out,memdata_4in,memdata_4out;
	assign memdata_4in=memDataOut;
	WB wb_stage(
		.en(wb_en),
		.clk(CLK),
		.rst(wb_rst),
		.valid(wb_valid),
		.valid_in(mem_valid),
		.regw_addr_in(regw_addr_mem),
		.regw_addr_out(regw_addr_wb),
		.ctrl_in(ctrl_3out),
		.ctrl_out(ctrl_4out),
		.alu_res_in(alu_3out),
		.alu_res_out(alu_4out),
		.memdata_in(memdata_4in),
		.memdata_out(memdata_4out),
		.wb_wen_in(wb_wen_mem),
		.wb_wen_out(wb_wen_wb),
		.op_type_in(op_type_mem),
		.op_type_out(op_type_wb),
		.b_in(branchSignal),
		.b_out(branch_wb)
	);
	assign regAddr = regw_addr_wb;
	
	//wire [31:0]tmpPc;
	
	mux32 
		regdata0(alu_4out,memdata_4out,writeRegData,ctrl_4out[1]);
		//branch0(pc_next_if, im_pc_3out,tmpPc,branchSignal),
		//jump0(tmpPc,jmp_pc_3out,pc_in,jumpSignal);
		
	always @(*) begin
		if(CFromMem || CFromExe) begin
			pc_in = jumpSignal ? jmp_pc_3out : branchSignal ? im_pc_3out : pc_next_mem;
		end
		else begin
			pc_in = pc_next_if;
		end
	end	

	//refresh the screen
	wire clk_refresh;
	clock clock2 (CCLK, 2000000, clk_refresh);	
	
	reg [7:0]clock_count=0;
	
	always@(posedge CLK)begin
		if(RST)begin 
			clock_count=0;
		end
		else begin
			clock_count=clock_count+1;
		end
	end
	
	wire [3:0]temp=0;
	//display
	assign LED[0] = SW[0];
	assign LED[1] = SW[1];
	assign LED[2] = SW[2];
	assign LED[3] = SW[3];
	assign LED[4] = temp[0];
	assign LED[5] = temp[1];
	assign LED[6] = temp[2];
	assign LED[7] = temp[3];
	
	wire [3:0] lcdd;
	wire rslcd, rwlcd, elcd;

	assign LCDDAT[3]=lcdd[3];
	assign LCDDAT[2]=lcdd[2];
	assign LCDDAT[1]=lcdd[1];
	assign LCDDAT[0]=lcdd[0];

	assign LCDRS=rslcd;
	assign LCDRW=rwlcd;
	assign LCDE=elcd;

	//wire [255:0]strdata = "PC:0000-00000000Register00000000";

	wire [255:0]strdata;

	itoa instruction7(CCLK, instr[31:28], strdata[255:248]);
	itoa instruction6(CCLK, instr[27:24], strdata[247:240]);
	itoa instruction5(CCLK, instr[23:20], strdata[239:232]);
	itoa instruction4(CCLK, instr[19:16], strdata[231:224]);
	itoa instruction3(CCLK, instr[15:12], strdata[223:216]);
	itoa instruction2(CCLK, instr[11:8], strdata[215:208]);
	itoa instruction1(CCLK, instr[7:4], strdata[207:200]);
	itoa instruction0(CCLK, instr[3:0], strdata[199:192]);

	assign strdata[191:184]=" ";
	
	//clock count
	itoa count1(CCLK, clock_count[7:4], strdata[183:176]);
	itoa count2(CCLK, clock_count[3:0], strdata[175:168]);

	//space
	assign strdata[167:160]=" ";

	//reg content
	itoa register3(CCLK, regOut3[15:12], strdata[159:152]);
	itoa register2(CCLK, regOut3[11:8], strdata[151:144]);
	itoa register1(CCLK, regOut3[7:4], strdata[143:136]);
	itoa register0(CCLK, regOut3[3:0], strdata[135:128]);

	assign strdata[127:120]="F";
	itoa op_if1(CCLK, op_type_if[7:4], strdata[119:112]);
	itoa op_if0(CCLK, op_type_if[3:0], strdata[111:104]);

	
	assign strdata[103:96]="D";
	itoa op_id1(CCLK, op_type_id[7:4], strdata[95:88]);
	itoa op_id0(CCLK, op_type_id[3:0], strdata[87:80]);
	
	assign strdata[79:72]="E";
	itoa op_exe1(CCLK, op_type_exe[7:4], strdata[71:64]);
	itoa op_exe0(CCLK, op_type_exe[3:0], strdata[63:56]);
	
	assign strdata[55:48]="M";
	itoa op_mem1(CCLK, op_type_mem[7:4], strdata[47:40]);
	itoa op_mem0(CCLK, op_type_mem[3:0], strdata[39:32]);
	
	assign strdata[31:24]="W";
	itoa op_wb1(CCLK, op_type_wb[7:4], strdata[23:16]);
	itoa op_wb0(CCLK, op_type_wb[3:0], strdata[15:8]);
	
	assign strdata[7:0]="+";

	//PC COUNT 231:200
	
	//REGISTER VALUE
	// itoa register7(CCLK, regOut3[31:28],strdata[63:56]);
	// itoa register6(CCLK, regOut3[27:24],strdata[55:48]);
	// itoa register5(CCLK, regOut3[23:20],strdata[47:40]);
	// itoa register4(CCLK, regOut3[19:16],strdata[39:32]);
	// itoa register3(CCLK, regOut3[15:12],strdata[31:24]);
	// itoa register2(CCLK, regOut3[11:8],strdata[23:16]);
	// itoa register1(CCLK, regOut3[7:4],strdata[15:8]);
	// itoa register0(CCLK, regOut3[3:0],strdata[7:0]);
	
	//DISPLAY MODULE
	display SHOW(CCLK, clk_refresh, strdata, rslcd, rwlcd, elcd, lcdd);          
	
endmodule
