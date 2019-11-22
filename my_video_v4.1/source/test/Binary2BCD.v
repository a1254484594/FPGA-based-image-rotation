//������תBCD
//֧��0-999
//��λ��outData[11:8]��ʮλ��[7:4]����λ��[3:0]
//ˢ���źź���Ҫ9��ʱ�Ӹ������
module Binary2BCD(
  input clk,
  input flash,
  input [9:0] inData,
  output reg [11:0] outData
);

reg [3:0]  count10;
reg [11:0] ShiftReg;

always@(posedge clk)
begin
    if(flash == 1'b1)
        count10 <= 4'd9;
    else if(count10 >= 0 && count10 <= 9)
        count10 <= count10 - 1'b1;
    else
        count10 <= 4'd15;
end

always @(posedge clk)
begin
    //for(i = 9; i >= 0; i = i - 1)
    if(flash == 1'b1)
        ShiftReg = 12'd0;
    else if(count10 >= 0 && count10 <= 9)
    begin
    		outData = outData;
        //adjust by add 3
        if(ShiftReg[11:8] > 4)
            ShiftReg[11:8] = ShiftReg[11:8] + 2'd3;
        else
            ShiftReg[11:8] = ShiftReg[11:8];            
    
        if(ShiftReg[7:4] > 4)
            ShiftReg[7:4] = ShiftReg[7:4] + 2'd3;
        else
            ShiftReg[7:4] = ShiftReg[7:4];
    
        if(ShiftReg[3:0] > 4)
            ShiftReg[3:0] = ShiftReg[3:0] + 2'd3;
        else
            ShiftReg[3:0] = ShiftReg[3:0];
        
        // shift left 
        ShiftReg = {ShiftReg[10:0],inData[count10]};
    end
    else
    begin
        ShiftReg = ShiftReg;
        outData = ShiftReg;
    end
end
        
endmodule