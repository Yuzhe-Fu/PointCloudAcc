from matplotlib.pyplot import sca
import torch
import os
import logging
import pdb

def walkFile(file):
    for root, dirs , _ in os.walk(file):
        for d in dirs:
            layer_name = os.path.join(root, d)
            logging.info(layer_name)
            if layer_name.endswith('grouper'):
                support_xyz = torch.load(layer_name+'/support_xyz.pt')
                feature = torch.load(layer_name+'/features.pt')
                grouped_xyz = torch.load(layer_name+'/grouped_xyz.pt')
                grouped_feature = torch.load(layer_name+'/grouped_features.pt')
                logging.info(f'size of support_xyz is {support_xyz.size()}')
                logging.info(f'size of feature is {feature.size()}')
                logging.info(f'size of grouped_xyz is {grouped_xyz.size()}')
                logging.info(f'size of grouped_feature is {grouped_feature.size()}')
            else:
                in_value = torch.load(layer_name+'/input.pt')
                out_value = torch.load(layer_name+'/output.pt')
                logging.info(f'size of input is {in_value.size()}')
                logging.info(f'size of output is {out_value.size()}')
                if layer_name.endswith('fake_q'):
                    scale = torch.load(layer_name+'/scale.pt')
                    logging.info(f'size of scale is {scale.size()}')
                else:
                    weight = torch.load(layer_name+'/weight.pt')
                    logging.info(f'size of weight is {weight.size()}')


root_logger = logging.getLogger()
for h in root_logger.handlers:
    root_logger.removeHandler(h)

logging.basicConfig(format='%(filename)s[line:%(lineno)d] - %(levelname)s: %(message)s',
                    level=logging.DEBUG,
                    filename='load_tensor.log',
                    filemode='w')

xyz_in = torch.load('../Data/model_encoder_encoder_2_0_grouper/support_xyz.pt')
scale = torch.load('../Data/model_inputs_quant/scale.pt')
zero_point = torch.load('../Data/model_inputs_quant/zero_point.pt')

xyz_q = xyz_in*scale - zero_point
print(xyz_q)
logging.error(xyz_in)
logging.error(xyz_q)
# input_0 = torch.load('../Data/output_0.pt')
# input_1 = torch.load('../Data/output_1.pt')
# input_2 = torch.load('../Data/model_encoder_encoder_1_0_convs_0_0/input.pt')
# temp0 = input_2[:,0:3,:,:]
# temp1 = temp0-input_0

# print(temp1)


# input_3 = torch.load(layer1+'/output.pt')
# print(input_0.size())
# print(input_1.size())
# print(input_3.size())
# print(input_0[0,34,511,:])
# print(input_1.size())


# maxNum=torch.max(temp)
# minNum=torch.min(temp)
# print(minNum) #0
# print(maxNum) #255


