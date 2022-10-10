for epoch in :
    def test_func(model):
        model.eval()
        # start_time = timeit.default_timer()

        # running_loss = 0.0
        # running_corrects = 0.0

        for inputs, labels in tqdm(test_dataloader):
        #     inputs = inputs.to(device)
        #     labels = labels.to(device)

        #     with torch.no_grad():
        #         outputs = model(inputs)
        #     probs = nn.Softmax(dim=1)(outputs)
        #     preds = torch.max(probs, 1)[1]
        #     loss = criterion(outputs, labels)

        #     running_loss += loss.item() * inputs.size(0)
        #     running_corrects += torch.sum(preds == labels.data)

        # epoch_loss = running_loss / test_size
        # epoch_acc = running_corrects.double() / test_size
        # print("############  test_func loss:", epoch_loss, "acc :", epoch_acc)
        return epoch_acc, epoch_acc, epoch_loss
    sparsities = np.arange(0,1,0.05)
    test_func(model =model,test_dataloader= test_dataloader, criterion=criterion, test_size=test_size, device=device )
    which_params = [param_name for param_name, _ in model.named_parameters()]
    sensitivity = distiller.perform_sensitivity_analysis(model = model,
                                                         net_params=which_params,
                                                         sparsities=sparsities,
                                                         test_func=test_func,
                                                         group='element')
    print("sensitivity: {}".format(sensitivity))