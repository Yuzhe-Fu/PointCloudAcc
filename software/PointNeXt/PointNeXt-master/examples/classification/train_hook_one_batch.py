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
activation = {}
def get_activation(name):
    def hook(model,input,output):
        # output_data[name] = output.numpy()
        input_data[name] = input[0].detach() # input type is tulple, only has one element, which is the tensor
        output_data[name] = output.detach()  # output type is tensor
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
                macc, oa, accs, cm = validate_fn(model, test_loader, cfg)
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
    
    # ==================================
    # From Prune_quant.py
    # ==================================
    # pdb.set_trace()
    # if save_name:
    #     msglogger = apputils.config_pylogger('logging.conf',experiment_name=save_name,output_dir='./msglogger_out')
    #     tflogger = TensorBoardLogger(msglogger.logdir)
    #     tflogger.log_gradients = True
    #     pylogger = PythonLogger(msglogger)

    train_loader = build_dataloader_from_cfg(cfg.batch_size,
                                             cfg.dataset,
                                             cfg.dataloader,
                                             datatransforms_cfg=cfg.datatransforms,
                                             split='train',
                                             distributed=cfg.distributed,
                                             )
    logging.info(f"length of training dataset: {len(train_loader.dataset)}")

    # ===> start training
    val_macc, val_oa, val_accs, best_val, macc_when_best, best_epoch = 0., 0., [], 0., 0., 0
    model.zero_grad()
    for epoch in range(cfg.start_epoch, cfg.epochs + 1):
        # ==================================
        # From Train_model.py
        # ==================================
        if compression_scheduler:
            print('compression is valid')
            compression_scheduler.on_epoch_begin(epoch)

        if cfg.distributed:
            train_loader.sampler.set_epoch(epoch)
        if hasattr(train_loader.dataset, 'epoch'):
            train_loader.dataset.epoch = epoch - 1

        model.encoder.encoder[1][0].convs[1][0].register_forward_hook(get_activation('conv2d_0'))

        train_loss, train_macc, train_oa, _, _, compression_scheduler = \
            train_one_epoch(model, train_loader, criterion,
                            optimizer, scheduler, epoch, cfg, compression_scheduler)

        # is_best = False
        # if epoch % cfg.val_freq == 0:
        #     val_macc, val_oa, val_accs, val_cm = validate_fn(
        #         model, val_loader, cfg)
        #     is_best = val_oa > best_val
        #     if is_best:
        #         best_val = val_oa
        #         macc_when_best = val_macc
        #         best_epoch = epoch
        #         logging.info(f'Find a better ckpt @E{epoch}')
        #         print_cls_results(val_oa, val_macc, val_accs, epoch, cfg)

        # lr = optimizer.param_groups[0]['lr']
        # logging.info(f'Epoch {epoch} LR {lr:.6f} '
        #              f'train_oa {train_oa:.2f}, val_oa {val_oa:.2f}, best val oa {best_val:.2f}')
        # if writer is not None:
        #     writer.add_scalar('train_loss', train_loss, epoch)
        #     writer.add_scalar('train_oa', train_macc, epoch)
        #     writer.add_scalar('lr', lr, epoch)
        #     writer.add_scalar('val_oa', val_oa, epoch)
        #     writer.add_scalar('mAcc_when_best', macc_when_best, epoch)
        #     writer.add_scalar('best_val', best_val, epoch)
        #     writer.add_scalar('epoch', epoch, epoch)

        # if cfg.sched_on_epoch:
        #     scheduler.step(epoch)
        # if cfg.rank == 0:
        #     save_checkpoint(cfg, model, epoch, optimizer, scheduler,
        #                     additioanl_dict={'best_val': best_val},
        #                     is_best=is_best
        #                     )
    # # test the last epoch
    # test_macc, test_oa, test_accs, test_cm = validate(model, test_loader, cfg)
    # print_cls_results(test_oa, test_macc, test_accs, best_epoch, cfg)
    # if writer is not None:
    #     writer.add_scalar('test_oa', test_oa, epoch)
    #     writer.add_scalar('test_macc', test_macc, epoch)

    # # test the best validataion model
    # best_epoch, _ = load_checkpoint(model, pretrained_path=os.path.join(
    #     cfg.ckpt_dir, f'{cfg.run_name}_ckpt_best.pth'))
    # test_macc, test_oa, test_accs, test_cm = validate(model, test_loader, cfg)
    # if writer is not None:
    #     writer.add_scalar('test_oa', test_oa, best_epoch)
    #     writer.add_scalar('test_macc', test_macc, best_epoch)
    # print_cls_results(test_oa, test_macc, test_accs, best_epoch, cfg)

    if writer is not None:
        writer.close()


def train_one_epoch(model, train_loader, criterion, optimizer, scheduler, epoch, cfg, compression_scheduler, tflogger=None, pylogger=None):
    loss_meter = AverageMeter()
    cm = ConfusionMatrix(num_classes=cfg.num_classes)
    npoints = cfg.num_points

    model.eval()  # set model to eval mode
    batch_size = train_loader.__len__()
    pbar = tqdm(enumerate(train_loader), total=train_loader.__len__())
    num_iter = 0
    for idx, data in pbar:
        if idx == 0:
            for key in data.keys():
                data[key] = data[key].cuda(non_blocking=True)
            num_iter += 1
            points = data['x']
            target = data['y']
            """ bebug
            from openpoints.dataset import vis_points 
            vis_points(data['pos'].cpu().numpy()[0])
            """
            num_curr_pts = points.shape[1]
            if num_curr_pts > npoints:  # point resampling strategy
                if npoints == 1024:
                    point_all = 1200
                elif npoints == 4096:
                    point_all = 4800
                elif npoints == 8192:
                    point_all = 8192
                else:
                    raise NotImplementedError()
                if  points.size(1) < point_all:
                    point_all = points.size(1)
                fps_idx = furthest_point_sample(
                    points[:, :, :3].contiguous(), point_all)
                fps_idx = fps_idx[:, np.random.choice(
                    point_all, npoints, False)]
                points = torch.gather(
                    points, 1, fps_idx.unsqueeze(-1).long().expand(-1, -1, points.shape[-1]))

            data['pos'] = points[:, :, :3].contiguous()
            data['x'] = points[:, :, :cfg.model.in_channels].transpose(1, 2).contiguous()

            # ==================================
            # From Train_model.py
            # ==================================
            if compression_scheduler:
                compression_scheduler.on_minibatch_begin(
                epoch,minibatch_id=idx,minibatches_per_epoch=
                batch_size,optimizer=optimizer)

            data = torch.cat((data['pos'], data['x'].transpose(1, 2).contiguous()),2) # (batch, 1024, 6)

            logits = model(data)
            # print(model.encoder.encoder[1][0].skipconv[0].weight) #64,32,1,1 prediction.head.0.0.

            logging.info(f'the size of weight in encoder.encoder[0][0].convs[0][0] is {model.encoder.encoder[0][0].convs[0][0].weight.size()}')
            logging.info(model.encoder.encoder[0][0].convs[0][0].weight)
            logging.info(f'the size of weight scale is {model.encoder.encoder[0][0].convs[0][0].weight_scale.size()}')
            logging.info(f'the weight scale is {model.encoder.encoder[0][0].convs[0][0].weight_scale}')
            logging.info(f'the size of zeropoint is {model.encoder.encoder[0][0].convs[0][0].weight_zero_point.size()}')
            logging.info(f'the zeropoint is {model.encoder.encoder[0][0].convs[0][0].weight_zero_point}')
    
        else: break
        print('finished one batch in one epoch')
    return None, None, None, None, None, None


def validate(model, val_loader, cfg):
    model.eval()  # set model to eval mode
    model.encoder.encoder[1][0].convs[0][0].register_forward_hook(get_activation('encoder_encoder_1_0_convs_0_0'))

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
    # save_Tensor(model.encoder.encoder[1][0].convs[0][0], 'encoder_encoder_1_0_convs_0_0')

    # tp, count = cm.tp, cm.count
    # if cfg.distributed:
    #     dist.all_reduce(tp), dist.all_reduce(count)
    # macc, overallacc, accs = cm.cal_acc(tp, count)
    # return macc, overallacc, accs, cm
    return None, None, None, None


def save_Tensor(layer, layer_name):
    torch.save(layer.weight_scale, './data/TensorData/'+layer_name+'_weight_scale.pt')
    torch.save(layer.weight_zero_point, './data/TensorData/'+layer_name+'_weight_zero_point.pt')
    torch.save(layer.weight, './data/TensorData/'+layer_name+'_weight.pt')
    torch.save(layer.float_weight, './data/TensorData/'+layer_name+'_float_weight.pt')
    torch.save(input_data[layer_name], './data/TensorData/'+layer_name+'_input.pt')
    torch.save(output_data[layer_name], './data/TensorData/'+layer_name+'_output.pt')
    print('successfully saved the '+ layer_name + ' data')
