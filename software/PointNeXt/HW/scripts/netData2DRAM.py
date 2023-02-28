import torch
import math
import pdb
import math

layer_list=[\
        {'layer_name': 'model_encoder_encoder_0_0_convs_0_0',         'isIdentity':False, 'isGrouper': False,   'isWeight': True,      'isBias': True,     'isFakeQ': False, 'isBN': False}, \
        {'layer_name': 'model_encoder_encoder_1_0_skipconv_0',        'isIdentity':False, 'isGrouper': False,   'isWeight': True,      'isBias': True,     'isFakeQ': False, 'isBN': False}, \
        {'layer_name': 'model_encoder_encoder_1_0_act_fake_q',        'isIdentity':False, 'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': True,  'isBN': False}, \
        {'layer_name': 'model_encoder_encoder_1_0_convs_0_0',         'isIdentity':False, 'isGrouper': False,   'isWeight': True,      'isBias': False,    'isFakeQ': False, 'isBN': False}, \
        {'layer_name': 'model_encoder_encoder_1_0_convs_0_1',         'isIdentity':True, 'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': False, 'isBN': True}, \
        {'layer_name': 'model_encoder_encoder_1_0_convs_0_2_fake_q',  'isIdentity':False, 'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': True,  'isBN': False}, \
        {'layer_name': 'model_encoder_encoder_1_0_convs_1_0',         'isIdentity':False, 'isGrouper': False,   'isWeight': True,      'isBias': False,    'isFakeQ': False, 'isBN': False}, \
        {'layer_name': 'model_encoder_encoder_1_0_convs_1_1',         'isIdentity':True, 'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': False, 'isBN': True}, 
        {'layer_name': 'model_encoder_encoder_2_0_skipconv_0',        'isIdentity':False, 'isGrouper': False,   'isWeight': True,      'isBias': True,     'isFakeQ': False, 'isBN': False}, \
        {'layer_name': 'model_encoder_encoder_2_0_act_fake_q',        'isIdentity':False, 'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': True,  'isBN': False}, \
        {'layer_name': 'model_encoder_encoder_2_0_convs_0_0',         'isIdentity':False, 'isGrouper': False,   'isWeight': True,      'isBias': False,    'isFakeQ': False, 'isBN': False}, \
        {'layer_name': 'model_encoder_encoder_2_0_convs_0_1',         'isIdentity':True, 'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': False, 'isBN': True}, \
        {'layer_name': 'model_encoder_encoder_2_0_convs_0_2_fake_q',  'isIdentity':False, 'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': True,  'isBN': False}, \
        {'layer_name': 'model_encoder_encoder_2_0_convs_1_0',         'isIdentity':False, 'isGrouper': False,   'isWeight': True,      'isBias': False,    'isFakeQ': False, 'isBN': False}, \
        {'layer_name': 'model_encoder_encoder_2_0_convs_1_1',         'isIdentity':True, 'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': False, 'isBN': True}, \
        {'layer_name': 'model_encoder_encoder_3_0_skipconv_0',        'isIdentity':False, 'isGrouper': False,   'isWeight': True,      'isBias': True,     'isFakeQ': False, 'isBN': False}, \
        {'layer_name': 'model_encoder_encoder_3_0_act_fake_q',        'isIdentity':False, 'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': True,  'isBN': False}, \
        {'layer_name': 'model_encoder_encoder_3_0_convs_0_0',         'isIdentity':False, 'isGrouper': False,   'isWeight': True,      'isBias': False,    'isFakeQ': False, 'isBN': False}, \
        {'layer_name': 'model_encoder_encoder_3_0_convs_0_1',         'isIdentity':True, 'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': False, 'isBN': True }, \
        {'layer_name': 'model_encoder_encoder_3_0_convs_0_2_fake_q',  'isIdentity':False, 'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': True,  'isBN': False}, \
        {'layer_name': 'model_encoder_encoder_3_0_convs_1_0',         'isIdentity':False, 'isGrouper': False,   'isWeight': True,      'isBias': False,    'isFakeQ': False, 'isBN': False}, \
        {'layer_name': 'model_encoder_encoder_3_0_convs_1_1',         'isIdentity':True, 'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': False, 'isBN': True}, \
        {'layer_name': 'model_encoder_encoder_4_0_skipconv_0',        'isIdentity':False, 'isGrouper': False,   'isWeight': True,      'isBias': True,     'isFakeQ': False, 'isBN': False}, \
        {'layer_name': 'model_encoder_encoder_4_0_act_fake_q',        'isIdentity':False, 'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': True,  'isBN': False}, \
        {'layer_name': 'model_encoder_encoder_4_0_convs_0_0',         'isIdentity':False, 'isGrouper': False,   'isWeight': True,      'isBias': False,    'isFakeQ': False, 'isBN': False}, \
        {'layer_name': 'model_encoder_encoder_4_0_convs_0_1',         'isIdentity':True, 'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': False, 'isBN': True}, \
        {'layer_name': 'model_encoder_encoder_4_0_convs_0_2_fake_q',  'isIdentity':False, 'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': True,  'isBN': False}, \
        {'layer_name': 'model_encoder_encoder_4_0_convs_1_0',         'isIdentity':False, 'isGrouper': False,   'isWeight': True,      'isBias': False,    'isFakeQ': False, 'isBN': False}, \
        {'layer_name': 'model_encoder_encoder_4_0_convs_1_1',         'isIdentity':True, 'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': False, 'isBN': True}, \
        {'layer_name': 'model_encoder_encoder_5_0_convs_0_0',         'isIdentity':False, 'isGrouper': False,   'isWeight': True,      'isBias': False,    'isFakeQ': False, 'isBN': False}, \
        {'layer_name': 'model_encoder_encoder_5_0_convs_0_1',         'isIdentity':True, 'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': False, 'isBN': True}, \
        {'layer_name': 'model_encoder_encoder_5_0_convs_0_2_fake_q',  'isIdentity':False, 'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': True,  'isBN': False}, \
        {'layer_name': 'model_encoder_encoder_5_0_convs_1_0',         'isIdentity':False, 'isGrouper': False,   'isWeight': True,      'isBias': False,    'isFakeQ': False, 'isBN': False}, \
        {'layer_name': 'model_encoder_encoder_5_0_convs_1_1',         'isIdentity':True, 'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': False, 'isBN': True}, \
        {'layer_name': 'model_encoder_encoder_5_0_convs_1_2_fake_q',  'isIdentity':False, 'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': True,  'isBN': False}, \
        {'layer_name': 'model_prediction_head_0_0',                   'isIdentity':False, 'isGrouper': False,   'isWeight': True,      'isBias': False,    'isFakeQ': False, 'isBN': False}, \
        {'layer_name': 'model_prediction_head_0_1',                   'isIdentity':False, 'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': False, 'isBN': True}, \
        {'layer_name': 'model_prediction_head_0_2_fake_q',            'isIdentity':False, 'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': True,  'isBN': False}, \
        {'layer_name': 'model_prediction_head_2_0',                   'isIdentity':False, 'isGrouper': False,   'isWeight': True,      'isBias': False,    'isFakeQ': False, 'isBN': False}, \
        {'layer_name': 'model_prediction_head_2_1',                   'isIdentity':False, 'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': False, 'isBN': True}, \
        {'layer_name': 'model_prediction_head_2_2_fake_q',            'isIdentity':False, 'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': True,  'isBN': False}, \
        {'layer_name': 'model_prediction_head_4_0',                   'isIdentity':False, 'isGrouper': False,   'isWeight': True,      'isBias': True,     'isFakeQ': False, 'isBN': False}]

grouper_list=[\
        { 'layer_name': 'model_encoder_encoder_1_0_grouper',  'isGrouper': True, 'isQueryAndGroup': True, 'isGroupAll': False}, \
        { 'layer_name': 'model_encoder_encoder_2_0_grouper',  'isGrouper': True, 'isQueryAndGroup': True, 'isGroupAll': False}, \
        { 'layer_name': 'model_encoder_encoder_3_0_grouper',  'isGrouper': True, 'isQueryAndGroup': True, 'isGroupAll': False}, \
        { 'layer_name': 'model_encoder_encoder_4_0_grouper',  'isGrouper': True, 'isQueryAndGroup': True, 'isGroupAll': False}, \
        { 'layer_name': 'model_encoder_encoder_5_0_grouper',  'isGrouper': True, 'isQueryAndGroup': False, 'isGroupAll': True}]


conv_layer_list=[\
        {'layer_name': 'model_encoder_encoder_0_0_convs_0_0',    'act_channle_spar': 'no' , 'quanti_status': 'yes',    'last_weight_layer': 'null', 'last_layer': 'model_inputs_quant' }, \
        {'layer_name': 'model_encoder_encoder_1_0_skipconv_0',   'act_channle_spar': 'no' , 'quanti_status': 'no',     'last_weight_layer': 'null', 'last_layer': 'model_inputs_quant'}, \
        {'layer_name': 'model_encoder_encoder_1_0_convs_0_0',    'act_channle_spar': 'no' , 'quanti_status': 'no',     'last_weight_layer': 'null', 'last_layer': 'model_inputs_quant'}, \
        {'layer_name': 'model_encoder_encoder_1_0_convs_1_0',    'act_channle_spar': 'yes', 'quanti_status': 'yes',    'last_weight_layer': 'null', 'last_layer': 'model_encoder_encoder_1_0_convs_0_2_fake_q'}, \
        {'layer_name': 'model_encoder_encoder_2_0_skipconv_0',   'act_channle_spar': 'yes', 'quanti_status': 'yes',    'last_weight_layer': 'null', 'last_layer': 'model_encoder_encoder_1_0_act_fake_q'}, \
        {'layer_name': 'model_encoder_encoder_2_0_convs_0_0',    'act_channle_spar': 'yes', 'quanti_status': 'no-yes', 'last_weight_layer': 'null', 'last_layer': 'model_encoder_encoder_1_0_act_fake_q'}, \
        {'layer_name': 'model_encoder_encoder_2_0_convs_1_0',    'act_channle_spar': 'yes', 'quanti_status': 'yes',    'last_weight_layer': 'null', 'last_layer': 'model_encoder_encoder_2_0_convs_0_2_fake_q'}, \
        {'layer_name': 'model_encoder_encoder_3_0_skipconv_0',   'act_channle_spar': 'yes', 'quanti_status': 'yes',    'last_weight_layer': 'null', 'last_layer': 'model_encoder_encoder_2_0_act_fake_q'}, \
        {'layer_name': 'model_encoder_encoder_3_0_convs_0_0',    'act_channle_spar': 'yes', 'quanti_status': 'no-yes', 'last_weight_layer': 'null', 'last_layer': 'model_encoder_encoder_2_0_act_fake_q'}, \
        {'layer_name': 'model_encoder_encoder_3_0_convs_1_0',    'act_channle_spar': 'yes', 'quanti_status': 'yes',    'last_weight_layer': 'null', 'last_layer': 'model_encoder_encoder_3_0_convs_0_2_fake_q'}, \
        {'layer_name': 'model_encoder_encoder_4_0_skipconv_0',   'act_channle_spar': 'yes', 'quanti_status': 'yes',    'last_weight_layer': 'null', 'last_layer': 'model_encoder_encoder_3_0_act_fake_q'}, \
        {'layer_name': 'model_encoder_encoder_4_0_convs_0_0',    'act_channle_spar': 'yes', 'quanti_status': 'no-yes', 'last_weight_layer': 'null', 'last_layer': 'model_encoder_encoder_3_0_act_fake_q'}, \
        {'layer_name': 'model_encoder_encoder_4_0_convs_1_0',    'act_channle_spar': 'yes', 'quanti_status': 'yes',    'last_weight_layer': 'null', 'last_layer': 'model_encoder_encoder_4_0_convs_0_2_fake_q'}, \
        {'layer_name': 'model_encoder_encoder_5_0_convs_0_0',    'act_channle_spar': 'yes', 'quanti_status': 'yes',    'last_weight_layer': 'null', 'last_layer': 'model_encoder_encoder_4_0_act_fake_q'}, \
        {'layer_name': 'model_encoder_encoder_5_0_convs_1_0',    'act_channle_spar': 'yes', 'quanti_status': 'yes',    'last_weight_layer': 'null', 'last_layer': 'model_encoder_encoder_5_0_convs_0_2_fake_q'}, \
        {'layer_name': 'model_prediction_head_0_0',              'act_channle_spar': 'yes', 'quanti_status': 'yes',    'last_weight_layer': 'model_encoder_encoder_5_0_convs_1_0', 'last_layer': 'model_encoder_encoder_5_0_convs_1_2_fake_q'}, \
        {'layer_name': 'model_prediction_head_2_0',              'act_channle_spar': 'no',  'quanti_status': 'yes',    'last_weight_layer': 'model_prediction_head_0_0', 'last_layer': 'model_prediction_head_0_2_fake_q'}, \
        {'layer_name': 'model_prediction_head_4_0',              'act_channle_spar': 'no',  'quanti_status': 'yes',    'last_weight_layer': 'model_prediction_head_2_0', 'last_layer': 'model_prediction_head_2_2_fake_q'}]


def dec2anywidth_hex (dec,width):
    hex_str = hex(dec).lstrip('0x').zfill(width)
    return hex_str

def dec2width_hex (dec, width):
    inta = int(dec)
    if width==16:
        hex_num =   hex(inta & 0xFFFF).lstrip('0x').rstrip("L").zfill(4)
    elif width == 8:
        hex_num =   hex(inta & 0xFF).lstrip('0x').rstrip("L").zfill(2)
    else:
        hex_num = 0
    return hex_num

def truncTo8b (x):
    sec0 = x < -128
    sec1 = (x >= -128) & (x <= 127)
    sec2 = x >= 127
    x_sec0 = -128
    x_sec1 = torch.trunc(x)
    x_sec2 = 127
    x_out = x_sec0*sec0 + x_sec1*sec1 + x_sec2*sec2
    return x_out

def skipSparinAct (x):
    # Act is 3 dimentional, [batch, channel, nip]
    [Batch, Chi, Nip]=x.size()
    spar_cut = 0
    non_spar_tensor_list = torch.tensor([], device = 'cuda')

    for i in range (Chi): # skip the 0 channle
        if torch.sum(x[0,i,:]).item() == 0:
            spar_cut += 1
        else:
            non_spar_tensor_list = torch.cat((non_spar_tensor_list, x[0,i,:].reshape(1,Nip)), 0)
    non_spar_cnt = Chi - spar_cut
    return non_spar_tensor_list, non_spar_cnt

def getChanSparInformInAct (x):
    actSparInform = []
    sparCnt = 0
    for i in range(x.size()[1]):
        if torch.sum(x[0,i,:]).item() == 0:
            actSparInform.append(i)
            sparCnt += 1
        else:
            continue
    return actSparInform, sparCnt

def getFilterSparInformInWeight (x):
    weightSparInform = []
    sparCnt = 0

    for i in range(x.size()[0]):
        if torch.sum(x[i,:]).item() == 0:
            weightSparInform.append(i)
            sparCnt += 1
        else:
            continue
    return weightSparInform, sparCnt

def actToSYA (networkAddr, Layer_name, last_Layer_name, last_weight_layer, Dram_bits, Stored_bits, Dram_height):
    # only can handle the size like (Batch,Chi,Nip=256*32)
    # networkAddr: the file address of network data
    # Layer_name: current layer
    # last_Layer_name: to get the scale and zeropoint
    # last_weight_layer: to get the weight's filter sparsity information and to get FC layers' input sparsity channle
    # ===============================
    # if input size is (64,64,256,32)=>(Batch=64,Chi=64, Nip=256*32)
    scale = torch.load(networkAddr+'/'+last_Layer_name+'/scale.pt')
    zeropoint = torch.load(networkAddr+'/'+last_Layer_name+'/zero_point.pt')

    innum = torch.load(networkAddr+'/'+Layer_name+'/input.pt')
    innum_q = innum*scale - zeropoint

    # upper = torch.tensor(127, device='cuda')
    # lowwer = torch.tensor(-128, device='cuda')
    # innum_q_truncUp = torch.where(innum_q > upper, upper, innum_q ) # trunc the upper part
    # innum_q_truncAll = torch.where(innum_q_truncUp < lowwer, lowwer, innum_q_truncUp ) # trunc the upper part
    innum_q = truncTo8b(innum_q)

    if innum_q.dim() == 4:
        [x0, x1, x2, x3]=innum_q.size()
        innum_q = innum_q.reshape(x0, x1, x2*x3)
        non_spar_innum_q, non_spar_cnt = skipSparinAct(innum_q)
    elif innum_q.dim() == 3:
        non_spar_innum_q, non_spar_cnt = skipSparinAct(innum_q)
        
    else: #innum_q.dim() == 2
        # in FC layer, act's one channle only has one element, 
        # need to check the 0 is caused by last layer's filter pruning or just element sparsity.
        # use last layer's weight to get the filter pruning information, to get which channle in FC layer is fixed 0.
        last_layer_weight = torch.load(networkAddr+'/'+last_weight_layer+'/weight.pt')
        sparInform, sparCnt = getFilterSparInformInWeight(last_layer_weight)
        assert len(sparInform)==sparCnt

        non_spar_innum_q = torch.tensor([], device = 'cuda')
        non_spar_cnt = innum_q.size()[1]-sparCnt
        for i in range(innum_q.size()[1]):
            if i in sparInform:
                continue
            else:
                non_spar_innum_q = torch.cat((non_spar_innum_q, innum_q[0,i].reshape(1,1)), 0) 
        non_spar_innum_q = non_spar_innum_q.reshape(1,non_spar_cnt)

    [Chi, Nip]=non_spar_innum_q.size()
    print(Layer_name)
    print('act size is ', non_spar_innum_q.size())
    act_store = []
    Row = int(Dram_bits/Stored_bits)

    for i in range(Row):
        act_store.append([])
        for j in range(i):
            act_store[i].append(0)
    for nip in range(Nip):
        index = nip%Row
        for chi in range(Chi):
            act_store[index].append(non_spar_innum_q[chi,nip].item())
    if Nip%Row != 0:
        temp = Nip%Row
        for i in range(temp, Row):
            for j in range(0, Chi):
                act_store[i].append(0)
    for i in range(Row):
        for j in range(Row-i-1):
            act_store[i].append(0)
    
    assert len(act_store)==Row
    for i in range(Row):
        assert len(act_store[i])==len(act_store[0])

    actMemHex=[]
    cunt = 0
    for i in range(len(act_store[0])):
        hex_temp=''
        for index in range(Row-1,-1,-1):
            hex_temp = hex_temp + dec2width_hex(act_store[index][i],Stored_bits)
        cunt += 1
        actMemHex.append(hex_temp)
    while cunt < Dram_height:
        actMemHex.append(dec2anywidth_hex(0, int(Dram_bits/4)))
        cunt += 1

    return actMemHex, non_spar_cnt

def weiToSYA (networkAddr, Layer_name, last_weight_layer, Dram_bits, Stored_bits, Dram_height):
    # only can handle the size like (Fil,Chi,1)
    # ===============================
    # if input size is (128,64,1,1)=>(Fil=64,Chi=64, Nip=1*1)
    
    weight = torch.load(networkAddr+'/'+Layer_name+'/weight.pt')
    weight_scale = torch.load(networkAddr+'/'+Layer_name+'/weight_scale.pt')
    weight_zp = torch.load(networkAddr+'/'+Layer_name+'/weight_zero_point.pt')

    innum = torch.load(networkAddr+'/'+Layer_name+'/input.pt')

    if weight.dim() == 2:
        last_layer_weight = torch.load(networkAddr+'/'+last_weight_layer+'/weight.pt')
        actSparInform, actSparCnt = getFilterSparInformInWeight(last_layer_weight)
    else:
        actSparInform, actSparCnt = getChanSparInformInAct(innum)
    weiSparInform, weiSparCnt = getFilterSparInformInWeight(weight)

    weight_q = weight*weight_scale-weight_zp

    Fil = weight_q.size()[0]
    Chi = weight_q.size()[1]
    non_sparFilter_wei_q = torch.tensor([], device = 'cuda')
    non_sparFilter_cnt = Fil-weiSparCnt
    
    # skip filter sparsity in weight
    for i in range(Fil):
        if i in weiSparInform:
            continue
        else:
            non_sparFilter_wei_q = torch.cat((non_sparFilter_wei_q, weight_q[i,:].reshape(1,Chi,1)), 0) 
    assert len(non_sparFilter_wei_q)==non_sparFilter_cnt

    non_sparChi_wei_q = torch.tensor([], device = 'cuda')
    non_sparChi_cnt = Chi-actSparCnt
    Fil = non_sparFilter_wei_q.size()[0]

    # skip channle sparsity in weight
    for i in range(Chi):
        if i in actSparInform:
            continue
        else:
            non_sparChi_wei_q = torch.cat((non_sparChi_wei_q, non_sparFilter_wei_q[:,i,:].reshape(Fil,1,1)), 1) 
    assert non_sparChi_wei_q.size()[1]==non_sparChi_cnt

    [Fil, Chi, Nip]=non_sparChi_wei_q.size()
    print('weight size is ', non_sparChi_wei_q.size())
    Col = int(Dram_bits/Stored_bits)
    wei_store = []
    for i in range(Col):
        wei_store.append([])
        for j in range(i):
            wei_store[i].append(0)
    for fil in range(Fil):
        index = fil%Col
        for chi in range(Chi):
            wei_store[index].append(non_sparChi_wei_q[fil,chi,0].item())
    if Fil%Col != 0:
        temp = Fil%Col
        for i in range(temp, Col):
            for j in range(0, Chi):
                wei_store[i].append(0)
    for i in range(Col):
        for j in range(Col-i-1):
            wei_store[i].append(0)
    # pdb.set_trace()
    assert len(wei_store)==Col
    for i in range(Col):
        assert len(wei_store[i])==len(wei_store[0])
    
    weiMemHex=[]
    cunt = 0

    for i in range(len(wei_store[0])):
        hex_temp=''
        for index in range(Col-1,-1,-1):
            hex_temp = hex_temp + dec2width_hex(wei_store[index][i],Stored_bits)
        cunt += 1
        weiMemHex.append(hex_temp)
    while cunt < Dram_height:
        weiMemHex.append(dec2anywidth_hex(0, int(Dram_bits/4)))
        cunt += 1
    
    return weiMemHex, non_sparFilter_cnt, non_sparChi_cnt


def scaleAndZPToSYA (networkAddr, Layer_list, Dram_bits, Stored_bits, Dram_height):
    # convert scale and ZP to DRAM format
    # Layer_list: the information of layer
    # Dram_bits: the width of Dram (128b in this case)
    # Stored_bits: the width of each element (16b in this case)
    # ===============================
    # first save the inputs_scale and inputs_zeroPoint in scaleMem
    # then convert scaleMem to hex file: scaleAndZPMemHex
    # scaleAndZPMemHex[0] is the lowest row in DRAM, scaleAndZPMemHex[1] is the second lowest row in DRAM
    # each row in DRAM is like: MSB[...,ZP(ly1), scale(ly1),,ZP(ly0),scale(ly0)]LSB
    scaleMem = []
    scaleMem.append(torch.load(networkAddr+'/model_inputs_quant/scale.pt').item())
    scaleMem.append(torch.load(networkAddr+'/model_inputs_quant/zero_point.pt').item())
    # save layers scale and ZP
    for dic in Layer_list:
        if dic['isFakeQ']:
            scaleMem.append(torch.load(networkAddr+'/'+dic['layer_name']+'/scale.pt').item())
            scaleMem.append(torch.load((networkAddr+'/'+dic['layer_name']+'/zero_point.pt')).item())

    num = Dram_bits/Stored_bits # each row store num elements
    iteral = math.ceil(len(scaleMem)/num) # need interal times to through the tensor needed to be stored

    # print(scaleMem)
    # print(iteral)

    scaleAndZPMemHex=[]
    cunt = 0

    for i in range(iteral):
        hex_temp=''
        for index in range(int(num*(i+1)-1),int(num*i-1),-1): # from num*i-1 to 0
            # print(index)
            if index < len(scaleMem):
                # print('scaleMem :', scaleMem[index], ', and the hex is', dec2width_hex(math.trunc(scaleMem[index]), Stored_bits))
                hex_temp = hex_temp + dec2width_hex(math.trunc(scaleMem[index]),Stored_bits)
            else:
                # print('now in 0')
                hex_temp = hex_temp + dec2width_hex(0,Stored_bits)
        cunt += 1
        scaleAndZPMemHex.append(hex_temp)

    while cunt < Dram_height:
        scaleAndZPMemHex.append(dec2anywidth_hex(0, int(Dram_bits/4)))
        cunt += 1 

    return scaleAndZPMemHex

def onelayerConvBiasToSYA (networkAddr, Layer_name, Dram_bits, Stored_bits, Dram_height):
    # convert conv bias to DRAM format
    # Layer_name: the information of layer
    # Dram_bits: the width of Dram (128b in this case)
    # Stored_bits: the width of each element (16b in this case)
    # ===============================
    # first save the bias in biasMem
    # then convert biasMem to hex file: convBiasMemHex
    # convBiasMemHex[0] is the lowest row in DRAM, convBiasMemHex[1] is the second lowest row in DRAM
    # each row in DRAM is like: MSB[...,Bias(ch3), Bias(ch2),Bias(ch1),Bias(ch0)]LSB

    bias = torch.load(networkAddr+'/'+Layer_name+'/bias.pt')
    bias_scale = torch.load(networkAddr+'/'+Layer_name+'/bias_scale.pt')
    bias_zp = torch.load(networkAddr+'/'+Layer_name+'/bias_zero_point.pt')

    bias_q = (bias*bias_scale-bias_zp).tolist()

    num = Dram_bits/Stored_bits # each row store num elements
    iteral = math.ceil(len(bias_q)/num) # need interal times to through the tensor needed to be stored

    convBiasMemHex=[]
    cunt = 0

    for i in range(iteral):
        hex_temp=''
        for index in range(int(num*(i+1)-1),int(num*i-1),-1): # from num*i-1 to 0
            # print(index)
            if index < len(bias_q):
                # print('scaleMem :', scaleMem[index], ', and the hex is', dec2width_hex(math.trunc(scaleMem[index]), Stored_bits))
                hex_temp = hex_temp + dec2width_hex(math.trunc(bias_q[index]),Stored_bits)
            else:
                # print('now in 0')
                hex_temp = hex_temp + dec2width_hex(0,Stored_bits)
        cunt += 1
        convBiasMemHex.append(hex_temp)

    while cunt < Dram_height:
        convBiasMemHex.append(dec2anywidth_hex(0, int(Dram_bits/4)))
        cunt += 1 
    return convBiasMemHex


def onelayerXYZToSYA (networkAddr, Layer_name, scale, zp, Dram_bits, Stored_bits, Dram_height):
    # convert xyz to 256b DRAM format, need to conver 256b to 128b in the out function
    # Layer_name: the name of layer
    # Dram_bits: the width of Dram (can support 128b or 256b)
    # Stored_bits: the width of each element (8b in this case)
    # ===============================
    # first load layer's xyz, then convert one point's xyz from tensor to hex(z,y,x), which stored in xyzMem
    # convert xyzMem to 256b DRAM format, the height is Dram_height/2, which is hex_temp
    # convert 256b DRAM to 128b DRAM, and like this [16b0, ... , (z2,y2,x2), (z1,y1,x1), (z0,y1,x0)]
    xyzMem = []
    # save layers scale and ZP
    in_xyz_q = torch.load(networkAddr+'/'+Layer_name+'/support_xyz.pt')[0,:,:]*scale - zp
    # print(in_xyz_q.size())
    # print(in_xyz_q[0,:].tolist())
    point_num = in_xyz_q.size()[0]
    # print(point_num)

    for i in range(point_num):
        hex_temp = ''
        for j in range(2,-1,-1):
            hex_temp += dec2width_hex(int(in_xyz_q[i,j].item()), Stored_bits)
        # print('the xyz is ', in_xyz_q[i,:].tolist())
        # print('the hex is ', hex_temp)
        xyzMem.append(hex_temp)
    
    xyzHexMem = []
    numPer256 = math.trunc(256/(3*Stored_bits))
    zero_num = 256%(3*Stored_bits)
    for i in range(int(Dram_height/(256/Dram_bits))):
        hex_temp = dec2width_hex(0, zero_num) # add zero in MSB
        for j in range( numPer256*(i+1)-1, numPer256*i-1, -1 ):
            if j<point_num:
                hex_temp += xyzMem[j]
            else:
                hex_temp += '000000'
        # the following is to convert 256b to 128b
        xyzHexMem.append(hex_temp[32:64])
        xyzHexMem.append(hex_temp[0:32])
    return xyzHexMem


def NetworkDataToFile( networkAddr, OutputFileAddr, Layer_list, Group_list, Conv_layer_list, \
        BaseAddr_scale, BaseAddr_xyz, BaseAddr_wei, BaseAddr_act, mem_limit, Dram_bits, \
        scaleStored_bits, scaleDram_height, Conv_Bias_Stored_bits, Conv_Bias_Dram_height, \
        XYZ_Stored_bits, XYZ_Height, Weight_Stored_bits, Weight_Dram_height, Act_Stored_bits, Act_Dram_height):

    # get the scale and zeropoint hex data
    print('begin convert scale and zp')
    scaleAndZPHexList_oneDim = scaleAndZPToSYA(networkAddr, Layer_list, Dram_bits, scaleStored_bits, scaleDram_height)
    print('successful !!! ^_^')

    # get the conv bias hex data
    print('begin convert conv bias')
    convBiasMemHex_twoDim = []
    for dic in Layer_list:
        if dic['isBias'] and dic['isBN']==False:
            convBiasMemHex_twoDim.append(onelayerConvBiasToSYA (networkAddr, dic['layer_name'], Dram_bits, Conv_Bias_Stored_bits, Conv_Bias_Dram_height))
    print('successful !!! ^_^')

    # get each layers xyz hex data
    print('begin convert xyz')
    scale = torch.load(networkAddr+'/model_inputs_quant/scale.pt')
    zp = torch.load(networkAddr+'/model_inputs_quant/zero_point.pt')
    xyz_hex_list_twoDim = []
    for dic in Group_list:
        temp = onelayerXYZToSYA(networkAddr, dic['layer_name'], scale, zp, Dram_bits, XYZ_Stored_bits, XYZ_Height)
        xyz_hex_list_twoDim.append(temp)
    print('successful !!! ^_^')

    # get activation hex data
    actMemHex_twoDim = []
    weightMemHex_twoDim = []

    non_spar_cnt_list = []
    non_sparFilter_cnt_list = []
    non_sparChi_cnt_list = []
    print('begin convert activation and weight')
    for dic in Conv_layer_list:
        actMemHex_temp, non_spar_cnt = actToSYA (networkAddr, dic['layer_name'], dic['last_layer'], dic['last_weight_layer'], Dram_bits, Act_Stored_bits, Act_Dram_height)
        actMemHex_twoDim.append(actMemHex_temp)
        non_spar_cnt_list.append(non_spar_cnt)

        weiMemHex_temp, non_sparFilter_cnt_temp, non_sparChi_cnt_temp = weiToSYA (networkAddr, dic['layer_name'], dic['last_weight_layer'], Dram_bits, Weight_Stored_bits, Weight_Dram_height)
        weightMemHex_twoDim.append(weiMemHex_temp)
        non_sparFilter_cnt_list.append(non_sparFilter_cnt_temp)
        non_sparChi_cnt_list.append(non_sparChi_cnt_temp)
    print('successful !!! ^_^')


    # defination the txt files
    # counter = 1
    # F = open(OutputFileAddr,'w')
    # scale_zp_convBias_done = 0
    # xyz_done = 0
    # wei_done = 0
    # act_done = 0
    # while counter > 0:
    #     if counter<BaseAddr_scale:
    #         F.write(dec2anywidth_hex(0,int(Dram_bits/4))+'\n')
    #         counter += 1
    #     elif counter >= BaseAddr_scale and counter < BaseAddr_xyz: # write the scale, ZP, and convBias into dram
    #         if scale_zp_convBias_done == 0:
    #             for scale_hex in scaleAndZPHexList_oneDim:
    #                 F.write(scale_hex+'\n')
    #                 counter += 1
    #             for i in range(len(convBiasMemHex_twoDim)):
    #                 for convBias_hex in convBiasMemHex_twoDim[i]:
    #                     F.write(convBias_hex+'\n')
    #                     counter += 1
    #             scale_zp_convBias_done = 1
    #             print('finish storing scale, zp, and convBias')
    #         else:
    #             F.write(dec2anywidth_hex(0,int(Dram_bits/4))+'\n')
    #             counter += 1
    #     elif counter >=  BaseAddr_xyz and counter < BaseAddr_wei:
    #         if xyz_done ==0:
    #             for i in range(len(xyz_hex_list_twoDim)):
    #                 for xyz_hex in xyz_hex_list_twoDim[i]:
    #                     F.write(xyz_hex+'\n')
    #                     counter += 1
    #             xyz_done = 1
    #             print('finish storing xyz')
    #         else:
    #             F.write(dec2anywidth_hex(0,int(Dram_bits/4))+'\n')
    #             counter += 1
    #     elif counter >=  BaseAddr_wei and counter < BaseAddr_act:
    #         if wei_done ==0:
    #             for i in range(len(weightMemHex_twoDim)):
    #                 for wei_hex in weightMemHex_twoDim[i]:
    #                     F.write(wei_hex+'\n')
    #                     counter += 1
    #             wei_done = 1
    #             print('finish storing conv weight')
    #         else:
    #             F.write(dec2anywidth_hex(0,int(Dram_bits/4))+'\n')
    #             counter += 1
    #     elif counter >=  BaseAddr_act and counter < mem_limit:
    #         if act_done ==0:
    #             for i in range(len(actMemHex_twoDim)):
    #                 for act_hex in actMemHex_twoDim[i]:
    #                     F.write(act_hex+'\n')
    #                     counter += 1
    #             act_done = 1
    #             print('finish storing conv act')
    #         else:
    #             F.write(dec2anywidth_hex(0,int(Dram_bits/4))+'\n')
    #             counter += 1
    #     else:
    #         print('something error, dont write in')
    #         break
    # F.close()




networkAddr = '/workspace/ln_PointNext-master/data/TensorData_FilterPrune'
OutputFileAddr = '../MemFile/dram-all.txt'
Layer_list = layer_list
Group_list = grouper_list
Conv_layer_list = conv_layer_list

BaseAddr_scale = 2**15
BaseAddr_xyz = 2**16
BaseAddr_wei = 2**18
BaseAddr_act = 2**20
mem_limit = 2**22
Dram_bits = 128

scaleStored_bits = 16
scaleDram_height = 2**10

Conv_Bias_Stored_bits = 8
Conv_Bias_Dram_height = 2**10

XYZ_Stored_bits = 8
XYZ_Height = 2**10

Act_Stored_bits = 8
Act_Dram_height = 2**16

Weight_Stored_bits = 8
Weight_Dram_height = 2**14

print('scale start at: ', BaseAddr_scale)
print('convBias start at: ', BaseAddr_scale+scaleDram_height)
print('xyz start at: ', BaseAddr_xyz)

out_cnt = 0
for dic in conv_layer_list:
    print(dic['layer_name'], ': ', BaseAddr_wei+Weight_Dram_height*out_cnt, ', ', BaseAddr_act+Act_Dram_height*out_cnt)
    out_cnt += 1




NetworkDataToFile (networkAddr, OutputFileAddr, Layer_list, Group_list, Conv_layer_list, \
        BaseAddr_scale, BaseAddr_xyz, BaseAddr_wei, BaseAddr_act, mem_limit, Dram_bits, \
        scaleStored_bits, scaleDram_height, Conv_Bias_Stored_bits, Conv_Bias_Dram_height, \
        XYZ_Stored_bits, XYZ_Height, Weight_Stored_bits, Weight_Dram_height, Act_Stored_bits, Act_Dram_height)

# last_weight_layer = 'model_prediction_head_0_0'
# weiMemHex, non_sparFilter_cnt, non_sparChi_cnt = weiToSYA (networkAddr, Layer_name, last_weight_layer, Dram_bits, Weight_Stored_bits, Weight_Dram_height)

# print('the non_spar Fil is ', non_sparFilter_cnt)
# print('the non_spar Chi is ', non_sparChi_cnt)



# print('quanti value is ', innum_q[0,0:10,0,0:3].tolist())




# model_encoder_encoder_0_0_convs_0_0 the input size is : torch.Size([64, 3, 1024]) , 
# and quanti value is  [[128.0, 88.0, 160.0], [85.0, 124.0, 201.0], [107.0, 87.0, 157.0]]


# model_encoder_encoder_1_0_skipconv_0 the input size is : torch.Size([64, 32, 512]) , 
# and quanti value is  [[201.90335083007812, 216.95111083984375, 229.91452026367188], [211.1585693359375, 193.30508422851562, 217.88430786132812], [203.87725830078125, 189.56008911132812, 211.82781982421875], [74.0540771484375, 70.73877716064453, 78.83055114746094], [56.169944763183594, 90.13330078125, 61.11219024658203], [88.99417114257812, 103.09031677246094, 84.54922485351562], [185.13084411621094, 130.20745849609375, 161.180908203125], [28.782249450683594, 54.22406768798828, 27.093902587890625], [152.1868896484375, 121.27482604980469, 144.86868286132812], [98.74360656738281, 82.79335021972656, 92.34017944335938]]


# model_encoder_encoder_1_0_convs_0_0 the input size is : torch.Size([64, 35, 512, 32]) , 
# and quanti value is  [[133.6666717529297, 113.66666412353516, 100.33333587646484], [-153.0, -153.0, -153.0], [-6.3333282470703125, -92.99998474121094, 73.66667175292969], [201.90335083007812, 197.15142822265625, 206.07508850097656], [211.1585693359375, 208.5308837890625, 213.39332580566406], [203.87725830078125, 201.05311584472656, 206.19796752929688], [74.0540771484375, 72.114013671875, 75.36791229248047], [56.169944763183594, 57.717079162597656, 55.02800750732422], [88.99417114257812, 90.679443359375, 87.46238708496094], [185.13084411621094, 186.3986358642578, 183.9367218017578]] 
# and the max min in 0:3 is  647.0   -312.9999694824219


# model_encoder_encoder_1_0_convs_1_0 the input size is : torch.Size([64, 32, 512, 32]) , 
# and quanti value is  [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]] and the max min in 0:3 is  0.0   0.0


# model_encoder_encoder_2_0_skipconv_0 the input size is : torch.Size([64, 64, 256]) , 
# and quanti value is  [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [52.0, 31.0, 41.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [139.0, 154.0, 194.0], [176.0, 115.0, 189.0]]


# model_encoder_encoder_2_0_convs_0_0 the input size is : torch.Size([64, 67, 256, 32]) , and quanti value is  [[6.342289447784424, -76.10748291015625, 38.053741455078125], [-266.3761901855469, -266.3761901855469, -266.3761901855469], [-126.84579467773438, -50.73831558227539, -19.026870727539062], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [52.0, 50.0, 48.0], [0.0, 0.0, 0.0]] and the max min in 0:3 is  494.6986389160156   -418.5911560058594

# model_encoder_encoder_2_0_convs_1_0 the input size is : torch.Size([64, 64, 256, 32]) , and quanti value is  [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [16.0, 10.0, 17.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]] and the max min in 0:3 is  0.0   0.0
# model_encoder_encoder_3_0_skipconv_0 the input size is : torch.Size([64, 128, 128]) , and quanti value is  [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]]

# model_encoder_encoder_3_0_convs_0_0 the input size is : torch.Size([64, 131, 128, 32]) , and quanti value is  [[5.04231595993042, 115.9732666015625, -70.5924301147461], [-211.77728271484375, -211.77728271484375, -211.77728271484375], [-100.84632110595703, -40.33852767944336, -191.60800170898438], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]] 
# and the max min in 0:3 is  393.3006896972656   -332.79290771484375


# model_encoder_encoder_3_0_convs_1_0 the input size is : torch.Size([64, 128, 128, 32]) , and quanti value is  [[0.0, 0.0, 0.0], [146.0, 118.0, 176.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [55.0, 46.0, 66.0], [0.0, 0.0, 0.0], [93.0, 101.0, 82.0], [0.0, 0.0, 0.0]] and the max min in 0:3 is  211.0   0.0
# model_encoder_encoder_4_0_skipconv_0 the input size is : torch.Size([64, 256, 64]) , and quanti value is  [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]]


# model_encoder_encoder_4_0_convs_0_0 the input size is : torch.Size([64, 259, 64, 32]) , and quanti value is  [[6.006144046783447, -258.2641906738281, 198.2027587890625], [-252.258056640625, -246.25189208984375, -198.2027587890625], [-120.12288665771484, -114.11673736572266, -174.1781768798828], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]] 
# and the max min in 0:3 is  468.479248046875   -396.405517578125


# model_encoder_encoder_4_0_convs_1_0 the input size is : torch.Size([64, 256, 64, 32]) , and quanti value is  [[29.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 68.0, 59.0], [0.0, 0.0, 35.0], [0.0, 0.0, 0.0], [133.0, 0.0, 0.0], [0.0, 0.0, 0.0]] 
# and the max min in 0:3 is  131.0   0.0


# model_encoder_encoder_5_0_convs_0_0 the input size is : torch.Size([64, 515, 1, 64]) , and quanti value is  [[0.7670368552207947, 22.244070053100586, -37.58480453491211], [-32.21554946899414, 59.828880310058594, -3.8351845741271973], [-15.340738296508789, 23.011106491088867, 49.857398986816406], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]] 
# and the max min in 0:3 is  59.828880310058594   -47.5562858581543


# model_encoder_encoder_5_0_convs_1_0 the input size is : torch.Size([64, 512, 1, 64]) , and quanti value is  [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [33.0, 2.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]] 
# and the max min in 0:3 is  33.0   0.0


# model_prediction_head_0_0 the input size is : torch.Size([64, 512]) , and quanti value is  [[0.0, 0.0, 77.0], [0.0, 0.0, 81.0], [0.0, 0.0, 91.0], [0.0, 0.0, 69.0], [0.0, 0.0, 76.0], [0.0, 0.0, 100.0]]
# model_prediction_head_2_0 the input size is : torch.Size([64, 512]) , and quanti value is  [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]]
# model_prediction_head_4_0 the input size is : torch.Size([64, 256]) , and quanti value is  [[0.0, 0.0, 0.0], [88.0, 0.0, 0.0], [0.0, 0.0, 52.0], [0.0, 0.0, 71.0], [55.0, 0.0, 103.0], [0.0, 0.0, 59.0]]

