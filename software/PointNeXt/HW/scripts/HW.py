# from re import X
import os


    file = open(os.path.join(self.output_dir, "ROM.coe"), "w")  
    file_sim = open(os.path.join(self.output_dir,"ROM.txt"), "w")
    file.write("memory_initialization_radix=16;\n")

    # write config
    for i in range(64):
        # 00A01002_18022428_22800804_00002012
        file.write(hex(int(config_info,2)).lstrip('0x').rstrip("L").zfill(32) + ",\n")
        file_sim.write(hex(int(config_info,2)).lstrip('0x').rstrip("L").zfill(32) + "\n")

    def bin2hex_file (self, file_bin, file_hex, file_sim):
        temp = file_bin.readline().rstrip('\n').rstrip('\r')
        # temp = hex(int(temp,2)).lstrip('0x').rstrip("L").zfill(32)

        file_hex.write(temp + ",\n")
        file_sim.write(temp + "\n")
        return file_bin, file_hex, file_sim

    def dec2width_bin (self, width, dec):
        bin_str = bin(dec).lstrip('0b').zfill(width)

        return bin_str[-width:]


    data = hex(data & 0xffff) # signed

    # data = hex(data) # signed
    temp = str(data).lstrip('0x').rstrip('L').zfill(NumChar) + temp

if __name__ == "__main__":
    func = cls_gen_coe()
    func.func_gen_coe()