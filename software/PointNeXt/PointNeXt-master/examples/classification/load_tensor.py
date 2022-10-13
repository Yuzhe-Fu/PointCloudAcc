import torch

output_torch = torch.load('./data/TensorData/encoder_encoder_3_0_convs_0_2_fake_q_output.pt')
scale = torch.load('./data/TensorData/encoder_encoder_3_0_convs_0_2_fake_q_scale.pt')
zero_point = torch.load('./data/TensorData/encoder_encoder_3_0_convs_0_2_fake_q_zero_point.pt')

# print(input_torch.size()) #64,35,512,32
# print(input_torch)
# print(torch.max(input_torch)) #6.6333
# print(torch.min(input_torch)) #-6.6333

print(output_torch.size()) #64,35,512,32
# print(output_torch)
print(scale) #2.9694
print(zero_point) #-3.8613

# print(output_torch.size()) #64,32,512,32
# print(weight_torch.size()) #32,35,1,1
# print(weight_scale.size()) #32,1,1,1
# print(weight_zero_point_torch.size()) #32,1,1,1

# print(weight_torch[0,:,0,0])
# print(weight_scale[0,:,:,:])
# print(weight_zero_point_torch[0,:,:,:])

temp = output_torch*scale
print(temp[0,0,0,:])
maxNum=torch.max(temp)
minNum=torch.min(temp)
print(minNum) #0
print(maxNum) #255



# print(float_weight_torch[1,:,0,0])
# print(weight_scale[1,:,:,:])
# print(weight_zero_point_torch[1,:,:,:])

