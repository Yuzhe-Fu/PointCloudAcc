# 综合后仿问题
- SYA只跑一段，可能是OfmWrDatRdy为0了
- KNN无法跑完，跑到什么程度？开始就KNNGLB_CrdRdDatRdy一直为0
- PFS POL同时出现x态，106ms时，SRAM的CEB为z
# 解决
- 已做
    - 只跑一段tcf，保存checkpoint
    - ITF写满所有的SRAM，数据用真实使POL比较器翻转
    - 不须判断空满
- 功耗低
    - 频率上100MHz
    - MAXIMUM Corner
    - FPS策略恢复
    - 可能没跑起来，没跑满，拉波形看看所有核跑了多少
        - SYA: GLBSYA_OfmWrDatRdy强制为1
        - POL：因PLC最短一周期变一次，因此跑满了
        - FPS：LopDist和LopCrd来判断16核是否跑满
