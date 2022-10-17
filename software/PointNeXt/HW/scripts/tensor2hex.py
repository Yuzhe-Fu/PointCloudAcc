import torch
import os
import pdb
def dec2width_hex (dec,width):
    hex_str = hex(dec).lstrip('0x').zfill(width)
    return hex_str

def actToSYA_allBatch (Act, Row):
    # only can handle (Batch,Chi,Nip), and type is int
    # Act: the input data, type is int.
    # Batch: the batch size of input
    # Nip: the number of input point
    # Chi: the channle of input
    # Row: the row of systolic array
    # Col: the col of systolic array
    # ===============================
    # if input size is (64,64,256,32)=>(Batch=64,Chi=64, Nip=256*32)
    print('in actToSYA')
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
        print('finish batch at', batch)
    for i in range(Row):
        for j in range(Row-i-1):
            act_store[i].append(0)
    
    # assert len(act_store)==Row
    # for i in range(Row):
    #     assert len(act_store[i])==len(act_store[0])
    actMemHex=[]
    length = len(act_store[0])
    for i in range(length):
        hex_temp=''
        for index in range(Row-1,-1,-1):
            hex_temp = hex_temp + dec2width_hex(act_store[index][i],2)
        actMemHex.append(hex_temp)
    return actMemHex

def actToSYA_oneBatch (Act, Row):
    # only can handle (Chi,Nip), and type is int
    # Act: the input data, type is int.
    # Batch: the batch size of input
    # Nip: the number of input point
    # Chi: the channle of input
    # Row: the row of systolic array
    # Col: the col of systolic array
    # ===============================
    # if input size is (64,64,256,32)=>(Batch=64,Chi=64, Nip=256*32)
    print('in actToSYA_oneBatch')
    [Chi, Nip]=Act.size()
    act_store = []
    for i in range(Row):
        act_store.append([])
        for j in range(i):
            act_store[i].append(0)
    
    for nip in range(Nip):
        index = nip%Row
        for chi in range(Chi):
            act_store[index].append(Act[chi,nip])
        
    for i in range(Row):
        for j in range(Row-i-1):
            act_store[i].append(0)
    
    # assert len(act_store)==Row
    # for i in range(Row):
    #     assert len(act_store[i])==len(act_store[0])
    actMemHex=[]
    length = len(act_store[0])
    for i in range(length):
        hex_temp=''
        for index in range(Row-1,-1,-1):
            hex_temp = hex_temp + dec2width_hex(act_store[index][i],2)
        actMemHex.append(hex_temp)
    return actMemHex

def xyzToSYA_oneBatch (Xyz):
  # only can handle (Nip,3), and type is int
  # Xyz: the input data, type is int.
  # ===============================
  # input is [[x0,y0,z0], [x1,y1,z1], ..., [xn,yn,zn]]
  # output is  [[z15,y15,x15,z14,y14,x14,...,z0,y0,x0], [z31,y31,x31,z30,...,z16,y16,x16], ...]
    print('in xyzToSYA_oneBatch')
    [Nip, _]=Xyz.size()
    xyz_store = []
    for i in range(Nip):
        for j in range(3):
            xyz_store.append(dec2width_hex(Xyz[i][j], 2))

    assert len(xyz_store)%16==0

    xyzMemHex = []
    for i in range(int(len(xyz_store)/16)):
        temp = ''
        for j in range(16):
            temp = temp + xyz_store[15+16*i-j]
        xyzMemHex.append(temp)
    return xyzMemHex

def weiToSYA (Wei, Col):
    # only can handle the size like (Fil,Chi,1), and type is int
    # Wei: the input weight, type is int.
    # Fil: the filter of weight
    # Chi: the channle of weight
    # Col: the col of systolic array
    # ===============================
    # if input size is (128,64,1,1)=>(Fil=64,Chi=64, Nip=1*1)
    print('in weiToSYA')
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
    # assert len(wei_store)==Col
    # for i in range(Col):
    #     assert len(wei_store[i])==len(wei_store[0])

    weiMemHex=[]
    length=len(wei_store[0])
    for i in range(length):
        hex_temp=''
        for index in range(Col-1,-1,-1):
            hex_temp = hex_temp + dec2width_hex(wei_store[index][i],2)
        weiMemHex.append(hex_temp)
    return weiMemHex

def loadLayerToFile(cur_layer, last_layer, SYA_Row, SYA_Col, file_addr, BaseAddr_xyz, BaseAddr_wei, BaseAddr_act, mem_limit):
    in_scale       = torch.load('../Data/'+last_layer+'/scale.pt')
    in_zero_point  = torch.load('../Data/'+last_layer+'/zero_point.pt')

    in_value    = torch.load('../Data/'+cur_layer+'/input.pt') #(64,64,256,32), 0~4.4129
    out_value    = torch.load('../Data/'+cur_layer+'/output.pt') #(64,128,256,32), -4.3205~4.6579
    weight      = torch.load('../Data/'+cur_layer+'/weight.pt')
    scale       = torch.load('../Data/'+cur_layer+'/weight_scale.pt')
    zero_point  = torch.load('../Data/'+cur_layer+'/weight_zero_point.pt')

    xyz_in = torch.load('../Data/model_encoder_encoder_2_0_grouper/support_xyz.pt')
    xyz_scale = torch.load('../Data/model_inputs_quant/scale.pt')
    xyz_bias = torch.load('../Data/model_inputs_quant/zero_point.pt')

    xyz_q = xyz_in*xyz_scale-xyz_bias
    in_q = in_value*in_scale-in_zero_point #(64,64,256,32), 0~203
    weight_q=weight*scale-zero_point #(128,64,1,1), 0~255

    [in_Batch, in_Chi, in_Hei, in_Wid] = in_q.size()
    [wei_Fil, wei_Chi, wei_Hei, wei_Wid] = weight_q.size()

    xyz_q_dec = xyz_q.int()
    print(xyz_q_dec.size())
    in_q_dec = in_q[:, :, :, 0].reshape([in_Batch, in_Chi, -1]).int()
    weight_q_dec = weight_q.reshape([wei_Fil, wei_Chi, -1]).int()

    xyz_hex = xyzToSYA_oneBatch(xyz_q_dec[0,:,:])
    wei_hex = weiToSYA(weight_q_dec, SYA_Col)
    act_hex = actToSYA_oneBatch(in_q_dec[0,:,:], SYA_Row)
  
    # defination the txt files
    counter = 1
    F = open(file_addr+'/dram.txt','w')
    xyz_done = 0
    wei_done = 0
    act_done = 0
    while counter > 0:
        if counter<BaseAddr_xyz:
            F.write(dec2width_hex(0,32)+'\n')
            counter += 1
        elif counter >=  BaseAddr_xyz and counter < BaseAddr_wei:
            if xyz_done ==0:
                for i in xyz_hex:
                    F.write(str(i)+'\n')
                    counter += 1
                xyz_done = 1
            else:
                F.write(dec2width_hex(0,32)+'\n')
                counter += 1
        elif counter >=  BaseAddr_wei and counter < BaseAddr_act:
            if wei_done ==0:
                for i in wei_hex:
                    F.write(str(i)+'\n')
                    counter += 1
                wei_done = 1
            else:
                F.write(dec2width_hex(0,32)+'\n')
                counter += 1
        elif counter >=  BaseAddr_act and counter < mem_limit:
            if act_done ==0:
                # pdb.set_trace()
                for i in act_hex:
                    F.write(str(i)+'\n')
                    counter += 1
                act_done = 1
            else:
                F.write(dec2width_hex(0,32)+'\n')
                counter += 1
        else:
            F.close()
            break

# defination of systolic array
Row = 16
Col = 16

layer_name0 = 'model_encoder_encoder_2_0_convs_0_2_fake_q'
layer_name1 = 'model_encoder_encoder_2_0_convs_1_0'

mem_limit = 2**16
BaseAddr_xyz = 3
BaseAddr_wei = 2**7
BaseAddr_act = 2**10


path=r'../MemFile/'+layer_name1
if not os.path.exists(path):
    os.mkdir(path)

loadLayerToFile(layer_name1,layer_name0,Row,Col,path,BaseAddr_xyz,BaseAddr_wei,BaseAddr_act, mem_limit)

# layer_name = []
# layer_name0 = '../Data/model_encoder_encoder_2_0_convs_0_2_fake_q'
# layer_name1 = '../Data/model_encoder_encoder_2_0_convs_1_0'

# in_scale       = torch.load(layer_name0+'/scale.pt')
# in_zero_point  = torch.load(layer_name0+'/zero_point.pt')

# in_value    = torch.load(layer_name1+'/input.pt') #(64,64,256,32), 0~4.4129
# out_value    = torch.load(layer_name1+'/output.pt') #(64,128,256,32), -4.3205~4.6579
# weight      = torch.load(layer_name1+'/weight.pt')
# scale       = torch.load(layer_name1+'/weight_scale.pt')
# zero_point  = torch.load(layer_name1+'/weight_zero_point.pt')

    
# in_q = in_value*in_scale-in_zero_point #(64,64,256,32), 0~203
# weight_q=weight*scale-zero_point #(128,64,1,1), 0~255

# [in_Batch, in_Chi, in_Hei, in_Wid] = in_q.size()
# [wei_Fil, wei_Chi, wei_Hei, wei_Wid] = weight_q.size()

# in_q_dec = in_q.reshape([in_Batch, in_Chi, -1]).int()
# weight_q_dec = weight_q.reshape([wei_Fil, wei_Chi, -1]).int()

# in_hex = actToSYA_allBatch(in_q_dec, Row)
# wei_hex = weiToSYA(weight_q_dec, Col)

# # defination the txt file
# file_addr = '../MemFile/test.txt'

# F = open(file_addr,'w')
# for i in in_hex:
#     F.write(str(i)+'\n')
# F.close() 

# print(in_q[0,0,0,0])
# print(in_q[0,0,1,0])
# print(in_q[0,0,2,0])


    # print(in_value.size())
    # maxNum=torch.max(out_value)
    # minNum=torch.min(out_value)
    # print(minNum) #0
    # print(maxNum) #255
    # print(out_value.size())


# for layer in layer_name:
#     if layer.endswith('_fake_q'):
#         in_value    = torch.load(layer+'/input.pt')
#         out_value0    = torch.load(layer+'/output.pt')
#         scale       = torch.load(layer+'/scale.pt')
#         zero_point  = torch.load(layer+'/zero_point.pt')
#     elif layer.endswith('_0'):
#         in_value    = torch.load(layer+'/input.pt') #(64,64,256,32), 0~4.4129
#         out_value    = torch.load(layer+'/output.pt') #(64,128,256,32), -4.3205~4.6579
#         weight      = torch.load(layer+'/weight.pt')
#         scale       = torch.load(layer+'/weight_scale.pt')
#         zero_point  = torch.load(layer+'/weight_zero_point.pt')
