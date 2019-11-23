import random

import math


def writeFile(name, text):
    with open(name, 'w') as file_object:
        file_object.write(text)
        file_object.close()


def genVerilog(func, times=1, power=1):
    rad = 0.017453292519943295 / times
    rads = []
    content = []

    for i in range(1, 360*times+1):
        r = i * rad
        idx = str(i).rjust(4)

        result = str(round(eval("math." + func + "(" + str(r) + ")") * power))
        keyIdx = result.find("-") + 1
        forward = result[:keyIdx] + "10'd"  # .replace("0x", "10'd")
        backward = result[keyIdx:].zfill(5)
        value = forward + backward
        code = "        10'd " + idx + ": lut_data <= {" + value + "};" + "\n"
        content.append(code)

    codes = ''.join(content)
    template = "\
module lut_" + str(times) + func + str(power) + "(\n\
    input[9:0]             lut_index,\n\
    output reg[31:0]       lut_data\n\
);\n\
\n\
always@(*) begin\n\
    case(lut_index)\n\
" + codes + "\
        default: lut_data <= {10'd99999};\n\
    endcase\n\
end\n\
endmodule\n"

    writeFile(str(times) + "_" + func + "_" + str(power) + ".v", template)


def CMP():
    rd = random.random()
    a = round(1024 * rd)
    b = 1024 * round(rd)
    return a, b, a == b


def DCM():
    rd = random.random()
    a = (round(1024 * rd) + 100) >> 10
    b = round((1024 * rd + 100) / 1024)
    return a, b, a == b


if __name__ == "__main__":
    # genVerilog("cos", 4, 2**14)
    # genVerilog("sin", 4, 2**14)
    for i in range(10):
        print(DCM())
