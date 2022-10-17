import torch
import math

def bin2hex_file (self, file_bin, file_hex, file_sim):
    temp = file_bin.readline().rstrip('\n').rstrip('\r')
    # temp = hex(int(temp,2)).lstrip('0x').rstrip("L").zfill(32)

    file_hex.write(temp + ",\n")
    file_sim.write(temp + "\n")
    return file_bin, file_hex, file_sim

def dec2width_hex (dec,width):
    hex_str = hex(dec).lstrip('0x').zfill(width)
    return hex_str

def actToSYA (Act, Row):
    # only can handle the size like (Batch,Chi,Nip=256*32)
    # Act: the input data, type is int.
    # Batch: the batch size of input
    # Nip: the number of input point
    # Chi: the channle of input
    # Row: the row of systolic array
    # ===============================
    # if input size is (64,64,256,32)=>(Batch=64,Chi=64, Nip=256*32)
    [Batch, Chi, Nip]=Act.size()
    act_store = []
    for i in range(Row):
        act_store.append([])
        for j in range(i):
            act_store[i].append(0)
    for batch in range(Batch):
        for nip in range(Nip):
            index = nip%Row
            for chi in range(Chi):
                act_store[index].append(Act[batch,chi,nip])
    for i in range(Row):
        for j in range(Row-i-1):
            act_store[i].append(0)
    
    assert len(act_store)==Row
    for i in range(Row):
        assert len(act_store[i])==len(act_store[0])

    actMemHex=[]
    for i in range(len(act_store[0])):
        hex_temp=''
        for index in range(Row-1,-1,-1):
            hex_temp = hex_temp + dec2width_hex(act_store[index][i],2)
        actMemHex.append(hex_temp)

    return actMemHex

def weiToSYA (Wei, Col):
    # only can handle the size like (Fil,Chi,1)
    # Wei: the input weight, type is int.
    # Fil: the filter of weight
    # Chi: the channle of weight
    # Col: the col of systolic array
    # ===============================
    # if input size is (128,64,1,1)=>(Fil=64,Chi=64, Nip=1*1)
    [Fil, Chi, Nip]=Wei.size()
    wei_store = []
    for i in range(Col):
        wei_store.append([])
        for j in range(i):
            wei_store[i].append(0)
    for fil in range(Fil):
        index = fil%Col
        for chi in range(Chi):
            wei_store[index].append(Wei[fil,chi,0])
    for i in range(Col):
        for j in range(Col-i-1):
            wei_store[i].append(0)
    
    assert len(wei_store)==Col
    for i in range(Col):
        assert len(wei_store[i])==len(wei_store[0])

    weiMemHex=[]
    for i in range(len(wei_store[0])):
        hex_temp=''
        for index in range(Col-1,-1,-1):
            hex_temp = hex_temp + dec2width_hex(wei_store[index][i],2)
        weiMemHex.append(hex_temp)

    return weiMemHex





in_data = torch.linspace(start=0, end=720).reshape(2,10,6,6)
print(in_data)

in_q=in_q.int()
value = in_q[0,0,0,0]
print(dec2width_bin(value, 2))