import torch

layer0 = '../Data/model_encoder_encoder_2_0_skipconv_0'
layer1 = '../Data/model_encoder_encoder_2_0_convs_0_0'

layer3 = '../Data/model_encoder_encoder_1_0_act_fake_q'


input_0 = torch.load(layer0+'/input.pt')
input_1 = torch.load(layer1+'/input.pt')

input_3 = torch.load(layer1+'/output.pt')

print(input_0.size())
print(input_1.size())
print(input_3.size())
# print(input_0[0,34,511,:])
# print(input_1.size())


# maxNum=torch.max(temp)
# minNum=torch.min(temp)
# print(minNum) #0
# print(maxNum) #255


