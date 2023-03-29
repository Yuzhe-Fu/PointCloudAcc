Dram=[\
    {'scale_zeropoint': [32768]  }, \
    {'convBias':        [33792]  }, \
    {'xyz':             [65536]  }, \

    {'model_encoder_encoder_0_0_convs_0_0' :[262144, 1048576, [3, 1024],  [32, 3, 1]]   }, \
    {'model_encoder_encoder_1_0_skipconv_0':[278528, 1114112, [32, 512],  [16, 32, 1]]  }, \
    {'model_encoder_encoder_1_0_convs_0_0' :[294912, 1179648, [35, 512],  [16, 35, 1]]   }, \
    {'model_encoder_encoder_1_0_convs_1_0' :[311296, 1245184, [16, 512],  [16, 16, 1]]   }, \
    {'model_encoder_encoder_2_0_skipconv_0':[327680, 1310720, [16, 256],  [48, 16, 1]]  }, \
    {'model_encoder_encoder_2_0_convs_0_0' :[344064, 1376256, [19, 256],  [16, 19, 1]]  }, \
    {'model_encoder_encoder_2_0_convs_1_0' :[360448, 1441792, [16, 256],  [48, 14, 1]]  }, \
    {'model_encoder_encoder_3_0_skipconv_0':[376832, 1507328, [34, 128],  [48, 34, 1]]  }, \
    {'model_encoder_encoder_3_0_convs_0_0' :[393216, 1572864, [37, 128],  [32, 37, 1]]  }, \
    {'model_encoder_encoder_3_0_convs_1_0' :[409600, 1638400, [32, 128],  [48, 31, 1]]  }, \
    {'model_encoder_encoder_4_0_skipconv_0':[425984, 1703936, [22,  64],  [48, 22, 1]]  }, \
    {'model_encoder_encoder_4_0_convs_0_0' :[442368, 1769472, [25,  64],  [112, 25, 1]] }, \
    {'model_encoder_encoder_4_0_convs_1_0' :[458752, 1835008, [112, 64],  [48, 118, 1]] }, \
    {'model_encoder_encoder_5_0_convs_0_0' :[475136, 1900544, [64,  64],  [172, 60, 1]] }, \
    {'model_encoder_encoder_5_0_convs_1_0' :[491520, 1966080, [113, 64],  [144, 113, 1]]}, \
    {'model_prediction_head_0_0'           :[507904, 2031616, [1,  144],  [128, 144, 1]]}, \
    {'model_prediction_head_2_0'           :[524288, 2097152, [1,  128],  [128, 128, 1]]}, \
    {'model_prediction_head_4_0'           :[540672, 2162688, [1,  128],  [40, 128, 1]] }]

# 'name': [start_line]
# 'layer_name': [weight_start_line, act_start_line, act_size, weight_size]

# BaseAddr_scale = 2**15
# BaseAddr_xyz = 2**16
# BaseAddr_wei = 2**18
# BaseAddr_act = 2**20
# mem_limit = 2**22
# Dram_bits = 128

# scaleStored_bits = 16
# scaleDram_height = 2**10

# Conv_Bias_Stored_bits = 8
# Conv_Bias_Dram_height = 2**10

# XYZ_Stored_bits = 8
# XYZ_Height = 2**10

# Act_Stored_bits = 8
# Act_Dram_height = 2**16

# Weight_Stored_bits = 8
# Weight_Dram_height = 2**14