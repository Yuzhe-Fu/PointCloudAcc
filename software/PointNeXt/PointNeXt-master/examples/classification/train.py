#                       _oo0oo_
#                      o8888888o
#                      88" . "88
#                      (| -_- |)
#                      0\  =  /0
#                    ___/`---'\___
#                  .' \\|     |// '.
#                 / \\|||  :  |||// \
#                / _||||| -:- |||||- \
#               |   | \\\  -  /// |   |
#               | \_|  ''\---/''  |_/ |
#               \  .-\__  '-'  ___/-. /
#             ___'. .'  /--.--\  `. .'___
#          ."" '<  `.___\_<|>_/___.' >' "".
#         | | :  `- \`.;`\ _ /`;.`/ - ` : | |
#         \  \ `_.   \_ __\ /__ _/   .-` /  /
#     =====`-.____`.___ \_____/___.-`___.-'=====
#                       `=---='
#     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#      Blessed by Buddha, there will be no bugs

import os, logging, csv, numpy as np, wandb
from tqdm import tqdm
import torch, torch.nn as nn
from torch import distributed as dist
from torch.utils.tensorboard import SummaryWriter
from openpoints.utils import set_random_seed, save_checkpoint, load_checkpoint, resume_checkpoint, setup_logger_dist, \
    cal_model_parm_nums, Wandb
from openpoints.utils import AverageMeter, ConfusionMatrix, get_mious
from openpoints.dataset import build_dataloader_from_cfg
from openpoints.transforms import build_transforms_from_cfg
from openpoints.optim import build_optimizer_from_cfg
from openpoints.scheduler import build_scheduler_from_cfg
from openpoints.loss import build_criterion_from_cfg
from openpoints.models import build_model_from_cfg
from openpoints.models.layers import furthest_point_sample, fps

# ==================================
# loading the Prune_quant.py library~
# ==================================
import time    
import sys
sys.setrecursionlimit(1000000)
sys.path.append("./distiller/")
# import train_model #FIXME
import argparse
from distiller.data_loggers import *
from torch.utils.data import DataLoader
import distiller.apputils.image_classifier as ic
import distiller
from distiller.quantization.range_linear import PostTrainLinearQuantizer
from distiller.quantization.range_linear import RangeLinearQuantWrapper
import distiller.apputils as apputils
from distiller.apputils.image_classifier import test
import shutil, timeit, glob, socket, math
# import C3D_model #FIXME
from datetime import datetime
import torch.onnx
from torch import optim
from torch.autograd import Variable
import pandas as pd


# ==================================
# loading the train_model.py library~
# ==================================
from fnmatch import fnmatch
# from Function_self import Function_self

import pdb, csv


def get_features(input_features_dim, data):
    if input_features_dim == 3:
        features = data['pos']
    elif input_features_dim == 4:
        features = torch.cat(
            (data['pos'], data['heights']), dim=-1)
        raise NotImplementedError("error")
    return features.transpose(1, 2).contiguous()


def write_to_csv(oa, macc, accs, best_epoch, cfg, write_header=True):
    accs_table = [f'{item:.2f}' for item in accs]
    header = ['method', 'OA', 'mAcc'] + \
        cfg.classes + ['best_epoch', 'log_path', 'wandb link']
    data = [cfg.exp_name, f'{oa:.3f}', f'{macc:.2f}'] + accs_table + [
        str(best_epoch), cfg.run_dir, wandb.run.get_url() if cfg.wandb.use_wandb else '-']
    with open(cfg.csv_path, 'a', encoding='UTF8', newline='') as f:
        writer = csv.writer(f)
        if write_header:
            writer.writerow(header)
        writer.writerow(data)
        f.close()


def print_cls_results(oa, macc, accs, epoch, cfg):
    s = f'\nClasses\tAcc\n'
    for name, acc_tmp in zip(cfg.classes, accs):
        s += '{:10}: {:3.2f}%\n'.format(name, acc_tmp)
    s += f'E@{epoch}\tOA: {oa:3.2f}\tmAcc: {macc:3.2f}\n'
    logging.info(s)

input_data = {}
output_data = {}
def get_activation(name):
    def hook(model,input,output):
        # output_data[name] = output.numpy()
        input_data[name] = input[0].detach() # input type is tulple, only has one element, which is the tensor
        output_data[name] = output.detach()  # output type is tensor
    return hook

support_xyz = {}
features = {}
grouped_xyz = {}
grouped_features = {}
def get_activation_grouper(name):
    def hook(model,input,output):
        # output_data[name] = output.numpy()
        support_xyz[name] = input[1].detach()
        features[name] = input[2].detach()
        grouped_xyz[name] = output[0].detach()
        grouped_features[name] = output[1].detach()
    return hook

def main(gpu, cfg, profile=False, compress_path=False, save_name=False):

    torch.cuda.empty_cache()
    # parser = argparse.ArgumentParser()
    # parser.add_argument('--compress',dest='compress',type=str,nargs='?',action='store',default='../../../distiller/myfile/prune_quant_sensitivity.yaml')
    # parser.add_argument('--name',dest='name',type=str,default='prune_test')
    # distiller.quantization.add_post_train_quant_args(parser)
    # Check complete args
    # args = parser.parse_args()
    
    if cfg.distributed:
        if cfg.mp:
            cfg.rank = gpu
        dist.init_process_group(backend=cfg.dist_backend,
                                init_method=cfg.dist_url,
                                world_size=cfg.world_size,
                                rank=cfg.rank)
    # logger
    setup_logger_dist(cfg.log_path, cfg.rank, name=cfg.dataset.common.NAME)
    if cfg.rank == 0 :
        Wandb.launch(cfg, cfg.wandb.use_wandb)
        writer = SummaryWriter(log_dir=cfg.run_dir)
    else:
        writer = None
    set_random_seed(cfg.seed + cfg.rank, deterministic=cfg.deterministic)
    torch.backends.cudnn.enabled = True
    # logging.info(cfg)

    model = build_model_from_cfg(cfg.model).to(cfg.rank)
    model_size = cal_model_parm_nums(model)
    # logging.info(model)

    logging.info('Number of params: %.4f M' % (model_size / 1e6))
    criterion = build_criterion_from_cfg(cfg.criterion).cuda()
    if cfg.model.get('in_channels', None) is None:
        cfg.model.in_channels = cfg.model.encoder_args.in_channels

    if cfg.sync_bn:
        model = torch.nn.SyncBatchNorm.convert_sync_batchnorm(model)
        logging.info('Using Synchronized BatchNorm ...')
    if cfg.distributed:
        torch.cuda.set_device(gpu)
        model = nn.parallel.DistributedDataParallel(
            model.cuda(), device_ids=[cfg.rank], output_device=cfg.rank)
        logging.info('Using Distributed Data parallel ...')

    # optimizer & scheduler
    optimizer = build_optimizer_from_cfg(model, lr=cfg.lr, **cfg.optimizer)
    scheduler = build_scheduler_from_cfg(cfg, optimizer)

    compression_scheduler = None
    if compress_path:
        source = compress_path
        # pdb.set_trace()
        compression_scheduler=distiller.file_config(model,optimizer=optimizer,filename=source,resumed_epoch=None)
        compression_scheduler.append_float_weight_after_quantizer()
    if compression_scheduler ==None:
        print('ERROR --------------------------No compress------------------------')

    # build dataset
    val_loader = build_dataloader_from_cfg(cfg.get('val_batch_size', cfg.batch_size),
                                           cfg.dataset,
                                           cfg.dataloader,
                                           datatransforms_cfg=cfg.datatransforms,
                                           split='val',
                                           distributed=cfg.distributed
                                           )
    logging.info(f"length of validation dataset: {len(val_loader.dataset)}")
    test_loader = build_dataloader_from_cfg(cfg.get('val_batch_size', cfg.batch_size),
                                            cfg.dataset,
                                            cfg.dataloader,
                                            datatransforms_cfg=cfg.datatransforms,
                                            split='test',
                                            distributed=cfg.distributed
                                            )
    num_classes = val_loader.dataset.num_classes if hasattr(
        val_loader.dataset, 'num_classes') else None
    num_points = val_loader.dataset.num_points if hasattr(
        val_loader.dataset, 'num_points') else None
    if num_classes is not None:
        assert cfg.num_classes == num_classes
    logging.info(f"number of classes of the dataset: {num_classes}, "
                 f"number of points sampled from dataset: {num_points}, "
                 f"number of points as model input: {cfg.num_points}")
    cfg.classes = cfg.get('classes', None) or val_loader.dataset.classes if hasattr(
        val_loader.dataset, 'classes') else None or np.range(num_classes)
    validate_fn = eval(cfg.get('val_fn', 'validate'))

    # optionally resume from a checkpoint
    if cfg.pretrained_path is not None:
        if cfg.mode == 'resume':
            resume_checkpoint(cfg, model, optimizer, scheduler,
                              pretrained_path=cfg.pretrained_path)
            macc, oa, accs, cm = validate_fn(model, val_loader, cfg)
            print_cls_results(oa, macc, accs, cfg.start_epoch, cfg)
        else:
            if cfg.mode == 'test':
                # test mode
                epoch, best_val = load_checkpoint(model, pretrained_path=cfg.pretrained_path)
                print(model.inputs_quant.scale)
                print(model.inputs_quant.zero_point)
                torch.save(model.inputs_quant.scale, './data/TensorData/model_inputs_quant/scale.pt')
                torch.save(model.inputs_quant.zero_point, './data/TensorData/model_inputs_quant/zero_point.pt')
                # macc, oa, accs, cm = validate_fn(model, test_loader, cfg)
                # print_cls_results(oa, macc, accs, epoch, cfg)
                print('Finish test, data see in data/TensorData')
                return True
            elif cfg.mode == 'val':
                # validation mode
                epoch, best_val = load_checkpoint(model, cfg.pretrained_path)
                macc, oa, accs, cm = validate_fn(model, val_loader, cfg)
                print_cls_results(oa, macc, accs, epoch, cfg)
                return True
            elif cfg.mode == 'finetune':
                # finetune the whole model
                logging.info(f'Finetuning from {cfg.pretrained_path}')
                load_checkpoint(model, cfg.pretrained_path)
            elif cfg.mode == 'finetune_encoder':
                # finetune the whole model
                logging.info(f'Finetuning from {cfg.pretrained_path}')
                load_checkpoint(model.encoder, cfg.pretrained_path)
    else:
        logging.info('Training from scratch')
    




def validate(model, val_loader, cfg):
    model.eval()  # set model to eval mode
    # layer = model.encoder.encoder[1][0].act.fake_q
    # layer_name = 'encoder_encoder_1_0_act_fake_q'

    # for conv layer
    # layer0  =   model.encoder.encoder[0][0].convs[0][0]
    # layer1  =   model.encoder.encoder[1][0].skipconv[0]
    # layer2  =   model.encoder.encoder[1][0].act.fake_q
    # layer3  =   model.encoder.encoder[1][0].convs[0][0]
    # layer4  =   model.encoder.encoder[1][0].convs[0][1]
    # layer5  =   model.encoder.encoder[1][0].convs[0][2].fake_q
    # layer6  =   model.encoder.encoder[1][0].convs[1][0]
    # layer7  =   model.encoder.encoder[1][0].convs[1][1]
    # layer8  =   model.encoder.encoder[2][0].skipconv[0]
    # layer9  =   model.encoder.encoder[2][0].act.fake_q
    # layer10 =   model.encoder.encoder[2][0].convs[0][0]
    # layer11 =   model.encoder.encoder[2][0].convs[0][1]
    # layer12 =   model.encoder.encoder[2][0].convs[0][2].fake_q
    # layer13 =   model.encoder.encoder[2][0].convs[1][0]
    # layer14 =   model.encoder.encoder[2][0].convs[1][1]
    # layer15 =   model.encoder.encoder[3][0].skipconv[0]
    # layer16 =   model.encoder.encoder[3][0].act.fake_q
    # layer17 =   model.encoder.encoder[3][0].convs[0][0]
    # layer18 =   model.encoder.encoder[3][0].convs[0][1]
    # layer19 =   model.encoder.encoder[3][0].convs[0][2].fake_q
    # layer20 =   model.encoder.encoder[3][0].convs[1][0]
    # layer21 =   model.encoder.encoder[3][0].convs[1][1]
    # layer22 =   model.encoder.encoder[4][0].skipconv[0]
    # layer23 =   model.encoder.encoder[4][0].act.fake_q
    # layer24 =   model.encoder.encoder[4][0].convs[0][0]
    # layer25 =   model.encoder.encoder[4][0].convs[0][1]
    # layer26 =   model.encoder.encoder[4][0].convs[0][2].fake_q
    # layer27 =   model.encoder.encoder[4][0].convs[1][0]
    # layer28 =   model.encoder.encoder[4][0].convs[1][1]
    # layer29 =   model.encoder.encoder[5][0].convs[0][0]
    # layer30 =   model.encoder.encoder[5][0].convs[0][1]
    # layer31 =   model.encoder.encoder[5][0].convs[0][2].fake_q
    # layer32 =   model.encoder.encoder[5][0].convs[1][0]
    # layer33 =   model.encoder.encoder[5][0].convs[1][1]
    # layer34 =   model.encoder.encoder[5][0].convs[1][2].fake_q
    # layer35 =   model.prediction.head[0][0]
    # layer36 =   model.prediction.head[0][1]
    # layer37 =   model.prediction.head[0][2].fake_q
    # layer38 =   model.prediction.head[2][0]
    # layer39 =   model.prediction.head[2][1]
    # layer40 =   model.prediction.head[2][2].fake_q
    # layer41 =   model.prediction.head[4][0]


    # list=[\
    #     {'layer': layer0,   'layer_name': 'model_encoder_encoder_0_0_convs_0_0',          'isGrouper': False,   'isWeight': True,      'isBias': True,     'isFakeQ': False, 'isBN': False}, \
    #     {'layer': layer1,   'layer_name': 'model_encoder_encoder_1_0_skipconv_0',         'isGrouper': False,   'isWeight': True,      'isBias': True,     'isFakeQ': False, 'isBN': False}, \
    #     {'layer': layer2,   'layer_name': 'model_encoder_encoder_1_0_act_fake_q',         'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': True,  'isBN': False}, \
    #     {'layer': layer3,   'layer_name': 'model_encoder_encoder_1_0_convs_0_0',          'isGrouper': False,   'isWeight': True,      'isBias': False,    'isFakeQ': False, 'isBN': False}, \
    #     {'layer': layer4,   'layer_name': 'model_encoder_encoder_1_0_convs_0_1',          'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': False, 'isBN': True}, \
    #     {'layer': layer5,   'layer_name': 'model_encoder_encoder_1_0_convs_0_2_fake_q',   'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': True,  'isBN': False}, \
    #     {'layer': layer6,   'layer_name': 'model_encoder_encoder_1_0_convs_1_0',          'isGrouper': False,   'isWeight': True,      'isBias': False,    'isFakeQ': False, 'isBN': False}, \
    #     {'layer': layer7,   'layer_name': 'model_encoder_encoder_1_0_convs_1_1',          'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': False, 'isBN': True}, 
    #     {'layer': layer8,   'layer_name': 'model_encoder_encoder_2_0_skipconv_0',         'isGrouper': False,   'isWeight': True,      'isBias': True,     'isFakeQ': False, 'isBN': False}, \
    #     {'layer': layer9,   'layer_name': 'model_encoder_encoder_2_0_act_fake_q',         'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': True,  'isBN': False}, \
    #     {'layer': layer10,  'layer_name': 'model_encoder_encoder_2_0_convs_0_0',          'isGrouper': False,   'isWeight': True,      'isBias': False,    'isFakeQ': False, 'isBN': False}, \
    #     {'layer': layer11,  'layer_name': 'model_encoder_encoder_2_0_convs_0_1',          'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': False, 'isBN': True}, \
    #     {'layer': layer12,  'layer_name': 'model_encoder_encoder_2_0_convs_0_2_fake_q',   'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': True,  'isBN': False}, \
    #     {'layer': layer13,  'layer_name': 'model_encoder_encoder_2_0_convs_1_0',          'isGrouper': False,   'isWeight': True,      'isBias': False,    'isFakeQ': False, 'isBN': False}, \
    #     {'layer': layer14,  'layer_name': 'model_encoder_encoder_2_0_convs_1_1',          'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': False, 'isBN': True}, \
    #     {'layer': layer15,  'layer_name': 'model_encoder_encoder_3_0_skipconv_0',         'isGrouper': False,   'isWeight': True,      'isBias': True,     'isFakeQ': False, 'isBN': False}, \
    #     {'layer': layer16,  'layer_name': 'model_encoder_encoder_3_0_act_fake_q',         'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': True,  'isBN': False}, \
    #     {'layer': layer17,  'layer_name': 'model_encoder_encoder_3_0_convs_0_0',          'isGrouper': False,   'isWeight': True,      'isBias': False,    'isFakeQ': False, 'isBN': False}, \
    #     {'layer': layer18,  'layer_name': 'model_encoder_encoder_3_0_convs_0_1',          'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': False, 'isBN': True }, \
    #     {'layer': layer19,  'layer_name': 'model_encoder_encoder_3_0_convs_0_2_fake_q',   'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': True,  'isBN': False}, \
    #     {'layer': layer20,  'layer_name': 'model_encoder_encoder_3_0_convs_1_0',          'isGrouper': False,   'isWeight': True,      'isBias': False,    'isFakeQ': False, 'isBN': False}, \
    #     {'layer': layer21,  'layer_name': 'model_encoder_encoder_3_0_convs_1_1',          'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': False, 'isBN': True}, \
    #     {'layer': layer22,  'layer_name': 'model_encoder_encoder_4_0_skipconv_0',         'isGrouper': False,   'isWeight': True,      'isBias': True,     'isFakeQ': False, 'isBN': False}, \
    #     {'layer': layer23,  'layer_name': 'model_encoder_encoder_4_0_act_fake_q',         'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': True,  'isBN': False}, \
    #     {'layer': layer24,  'layer_name': 'model_encoder_encoder_4_0_convs_0_0',          'isGrouper': False,   'isWeight': True,      'isBias': False,    'isFakeQ': False, 'isBN': False}, \
    #     {'layer': layer25,  'layer_name': 'model_encoder_encoder_4_0_convs_0_1',          'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': False, 'isBN': True}, \
    #     {'layer': layer26,  'layer_name': 'model_encoder_encoder_4_0_convs_0_2_fake_q',   'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': True,  'isBN': False}, \
    #     {'layer': layer27,  'layer_name': 'model_encoder_encoder_4_0_convs_1_0',          'isGrouper': False,   'isWeight': True,      'isBias': False,    'isFakeQ': False, 'isBN': False}, \
    #     {'layer': layer28,  'layer_name': 'model_encoder_encoder_4_0_convs_1_1',          'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': False, 'isBN': True}, \
    #     {'layer': layer29,  'layer_name': 'model_encoder_encoder_5_0_convs_0_0',          'isGrouper': False,   'isWeight': True,      'isBias': False,    'isFakeQ': False, 'isBN': False}, \
    #     {'layer': layer30,  'layer_name': 'model_encoder_encoder_5_0_convs_0_1',          'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': False, 'isBN': True}, \
    #     {'layer': layer31,  'layer_name': 'model_encoder_encoder_5_0_convs_0_2_fake_q',   'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': True,  'isBN': False}, \
    #     {'layer': layer32,  'layer_name': 'model_encoder_encoder_5_0_convs_1_0',          'isGrouper': False,   'isWeight': True,      'isBias': False,    'isFakeQ': False, 'isBN': False}, \
    #     {'layer': layer33,  'layer_name': 'model_encoder_encoder_5_0_convs_1_1',          'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': False, 'isBN': True}, \
    #     {'layer': layer34,  'layer_name': 'model_encoder_encoder_5_0_convs_1_2_fake_q',   'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': True,  'isBN': False}, \
    #     {'layer': layer35,  'layer_name': 'model_prediction_head_0_0',                    'isGrouper': False,   'isWeight': True,      'isBias': False,    'isFakeQ': False, 'isBN': False}, \
    #     {'layer': layer36,  'layer_name': 'model_prediction_head_0_1',                    'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': False, 'isBN': True}, \
    #     {'layer': layer37,  'layer_name': 'model_prediction_head_0_2_fake_q',             'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': True,  'isBN': False}, \
    #     {'layer': layer38,  'layer_name': 'model_prediction_head_2_0',                    'isGrouper': False,   'isWeight': True,      'isBias': False,    'isFakeQ': False, 'isBN': False}, \
    #     {'layer': layer39,  'layer_name': 'model_prediction_head_2_1',                    'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': False, 'isBN': True}, \
    #     {'layer': layer40,  'layer_name': 'model_prediction_head_2_2_fake_q',             'isGrouper': False,   'isWeight': False,     'isBias': False,    'isFakeQ': True,  'isBN': False}, \
    #     {'layer': layer41,  'layer_name': 'model_prediction_head_4_0',                    'isGrouper': False,   'isWeight': True,      'isBias': True,     'isFakeQ': False, 'isBN': False}]

    # for dic in list:
    #     dic['layer'].register_forward_hook(get_activation(dic['layer_name']))
    
    # for grouper layer
    grouper_0 = model.encoder.encoder[1][0].grouper 
    grouper_1 = model.encoder.encoder[2][0].grouper
    grouper_2 = model.encoder.encoder[3][0].grouper
    grouper_3 = model.encoder.encoder[4][0].grouper
    grouper_4 = model.encoder.encoder[5][0].grouper # GroupAll

    grouper_list=[\
        {'layer': grouper_0,   'layer_name': 'model_encoder_encoder_1_0_grouper',  'isGrouper': True, 'isQueryAndGroup': True, 'isGroupAll': False}, \
        {'layer': grouper_1,   'layer_name': 'model_encoder_encoder_2_0_grouper',  'isGrouper': True, 'isQueryAndGroup': True, 'isGroupAll': False}, \
        {'layer': grouper_2,   'layer_name': 'model_encoder_encoder_3_0_grouper',  'isGrouper': True, 'isQueryAndGroup': True, 'isGroupAll': False}, \
        {'layer': grouper_3,   'layer_name': 'model_encoder_encoder_4_0_grouper',  'isGrouper': True, 'isQueryAndGroup': True, 'isGroupAll': False}, \
        {'layer': grouper_4,   'layer_name': 'model_encoder_encoder_5_0_grouper',  'isGrouper': True, 'isQueryAndGroup': False, 'isGroupAll': True}]

    for dic in grouper_list:
        dic['layer'].register_forward_hook(get_activation_grouper(dic['layer_name']))

    cm = ConfusionMatrix(num_classes=cfg.num_classes)
    npoints = cfg.num_points
    # pbar = tqdm(enumerate(val_loader), total=val_loader.__len__())
    pbar = tqdm(enumerate(val_loader), total=1)
    for idx, data in pbar:
        if idx==0:
            for key in data.keys():
                data[key] = data[key].cuda(non_blocking=True)
            target = data['y']
            points = data['x']
            points = points[:, :npoints]
            data['pos'] = points[:, :, :3].contiguous()
            data['x'] = points[:, :, :cfg.model.in_channels].transpose(1, 2).contiguous()
            data = torch.cat((data['pos'], data['x'].transpose(1, 2).contiguous()),2) # (batch, 1024, 6)
            logits = model(data)
            cm.update(logits.argmax(dim=1), target)
        else:
            print('finish one batch test')
            break
        
    # save the hooked tesnsor value
    # for dic in list:
    #     save_Tensor(layer=dic['layer'], layer_name=dic['layer_name'], isGrouper=dic['isGrouper'],isWeight=dic['isWeight'], isBias=dic['isBias'], isFakeQ=dic['isFakeQ'], isBN=dic['isBN'])
    
    for dic in grouper_list:
        save_Tensor(layer=dic['layer'], layer_name=dic['layer_name'], isGrouper=dic['isGrouper'], isQueryAndGroup=dic['isQueryAndGroup'], isGroupAll=dic['isGroupAll'])

    # tp, count = cm.tp, cm.count
    # if cfg.distributed:
    #     dist.all_reduce(tp), dist.all_reduce(count)
    # macc, overallacc, accs = cm.cal_acc(tp, count)
    # return macc, overallacc, accs, cm
    return None, None, None, None


def save_Tensor(layer, layer_name, isGrouper=False, isWeight=False, isBias=False, isFakeQ=False, isBN=False, isQueryAndGroup=False, isGroupAll=False):
    path=r'./data/TensorData/'+layer_name
    if not os.path.exists(path):
        os.mkdir(path)
    if isGrouper is False:
        torch.save(input_data[layer_name], path+'/input.pt')
        torch.save(output_data[layer_name],path+'/output.pt')
        
        if isWeight is True:
            torch.save(layer.weight, path+'/weight.pt')
            torch.save(layer.weight_scale, path+'/weight_scale.pt')
            torch.save(layer.weight_zero_point, path+'/weight_zero_point.pt')
        if isBias is True:
            torch.save(layer.bias, path+'/bias.pt')
            torch.save(layer.bias_scale, path+'/bias_scale.pt')
            torch.save(layer.bias_zero_point, path+'/bias_zero_point.pt')
        if isFakeQ is True:
            torch.save(layer.scale, path+'/scale.pt')
            torch.save(layer.zero_point, path+'/zero_point.pt')
        if isBN is True:
            torch.save(layer.weight, path+'/weight.pt')
            torch.save(layer.bias, path+'/bias.pt')
    else:
        torch.save(support_xyz[layer_name], path+'/support_xyz.pt')
        torch.save(features[layer_name], path+'/features.pt')
        torch.save(grouped_xyz[layer_name], path+'/grouped_xyz.pt')
        torch.save(grouped_features[layer_name], path+'/grouped_features.pt')
    print('successfully saved the '+ layer_name + ' data')
