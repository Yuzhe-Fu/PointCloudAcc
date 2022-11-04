import torch
import pdb

input_torch = torch.load('../../data/TensorData/model_encoder_encoder_1_0_convs_0_0/input.pt')

group_out0 = torch.load('../../data/grouper_output0.pt')
group_out1 = torch.load('../../data/grouper_output1.pt')


print(input_torch.size()) #64,35,512,32
print(group_out0.size())
print(group_out1.size())

pdb.set_trace()



# print(float_weight_torch[1,:,0,0])
# print(weight_scale[1,:,:,:])
# print(weight_zero_point_torch[1,:,:,:])

