// Unify all unit modules for flexible transfer
// -----------------------------------------------------------------------------
// Copyright (c) 2014-2020 All rights reserved
// -----------------------------------------------------------------------------
// Author : zhouchch@pku.edu.cn
// File   : UNT.v
// Create : 2020-07-14 21:09:52
// Revise : 2020-08-13 10:33:19
// -----------------------------------------------------------------------------
module KUA #(
    // KNN
    parameter KNNISA_WIDTH      = 128*2,
    parameter SRAM_WIDTH        = 256,
    parameter SRAM_MAXPARA      = 1,
    parameter IDX_WIDTH         = 16,
    parameter MAP_WIDTH         = 5,
    parameter CRD_WIDTH         = 8,
    parameter NUM_SORT_CORE     = 8,
    parameter KNNMON_WIDTH      = 128,

    // UNT
    parameter DATA_WIDTH        = 8,
    parameter SHF_ADDR_WIDTH    = 8,
    parameter ADDR_WIDTH        = 16 

    )(
    input                               clk                     ,
    input                               rst_n                   ,

    // Configure
    input                               CCUKNN_CfgVld       ,
    output                              KNNCCU_CfgRdy       ,
    input  [KNNISA_WIDTH        -1 : 0] CCUKNN_CfgInfo      ,

    // Fetch Crd
    output [IDX_WIDTH           -1 : 0] KNNGLB_CrdRdAddr    ,   
    output                              KNNGLB_CrdRdAddrVld , 
    input                               GLBKNN_CrdRdAddrRdy ,
    input  [SRAM_WIDTH          -1 : 0] GLBKNN_CrdRdDat     ,        
    input                               GLBKNN_CrdRdDatVld  ,     
    output                              KNNGLB_CrdRdDatRdy  ,

    // Fetch Mask of Output Points
    output [IDX_WIDTH           -1 : 0] KNNGLB_MaskRdAddr   ,
    output                              KNNGLB_MaskRdAddrVld,
    input                               GLBKNN_MaskRdAddrRdy,
    input  [SRAM_WIDTH          -1 : 0] GLBKNN_MaskRdDat    ,    
    input                               GLBKNN_MaskRdDatVld ,    
    output                              KNNGLB_MaskRdDatRdy ,   

    // Output Map of KNN
    output [IDX_WIDTH           -1 : 0] KNNGLB_MapWrAddr    ,
    output [SRAM_WIDTH          -1 : 0] KNNGLB_MapWrDat     ,   
    output                              KNNGLB_MapWrDatVld  ,     
    input                               GLBKNN_MapWrDatRdy  ,

    output [IDX_WIDTH           -1 : 0] KNNGLB_IdxMaskRdAddr   ,
    output                              KNNGLB_IdxMaskRdAddrVld,
    input                               GLBKNN_IdxMaskRdAddrRdy,
    input  [SRAM_WIDTH          -1 : 0] GLBKNN_IdxMaskRdDat    ,    
    input                               GLBKNN_IdxMaskRdDatVld ,    
    output                              KNNGLB_IdxMaskRdDatRdy ,  

    output [KNNMON_WIDTH        -1 : 0] KNNMON_Dat   
);
//=====================================================================================================================
// Constant Definition :
//=====================================================================================================================
localparam KNNIDX = 0;
localparam SHFIDX = 1;
localparam ADDIDX = 2;
localparam CATIDX = 3;

//=====================================================================================================================
// Variable Definition :
//=====================================================================================================================
wire                              KUAKNN_CfgVld             ;
wire                              KNNKUA_CfgRdy             ;
wire [KNNISA_WIDTH        -1 : 0] KUAKNN_CfgInfo            ;
wire [IDX_WIDTH           -1 : 0] KNNKUA_CrdRdAddr          ;   
wire                              KNNKUA_CrdRdAddrVld       ; 
wire                              KUAKNN_CrdRdAddrRdy       ;
wire [SRAM_WIDTH          -1 : 0] KUAKNN_CrdRdDat           ;        
wire                              KUAKNN_CrdRdDatVld        ;     
wire                              KNNKUA_CrdRdDatRdy        ;
wire [IDX_WIDTH           -1 : 0] KNNKUA_MaskRdAddr         ;
wire                              KNNKUA_MaskRdAddrVld      ;
wire                              KUAKNN_MaskRdAddrRdy      ;
wire [SRAM_WIDTH          -1 : 0] KUAKNN_MaskRdDat          ;    
wire                              KUAKNN_MaskRdDatVld       ;    
wire                              KNNKUA_MaskRdDatRdy       ;   
wire [IDX_WIDTH           -1 : 0] KNNKUA_MapWrAddr          ;
wire [SRAM_WIDTH          -1 : 0] KNNKUA_MapWrDat           ;   
wire                              KNNKUA_MapWrDatVld        ;     
wire                              KUAKNN_MapWrDatRdy        ;
wire [IDX_WIDTH           -1 : 0] KNNKUA_IdxMaskRdAddr      ;
wire                              KNNKUA_IdxMaskRdAddrVld   ;
wire                              KUAKNN_IdxMaskRdAddrRdy   ;
wire [SRAM_WIDTH          -1 : 0] KUAKNN_IdxMaskRdDat       ;    
wire                              KUAKNN_IdxMaskRdDatVld    ;    
wire                              KNNKUA_IdxMaskRdDatRdy    ;  

wire                                      CCUSHF_CfgVld     ;
wire                                      SHFCCU_CfgRdy     ;
wire [KNNISA_WIDTH                -1 : 0] CCUSHF_CfgInfo    ;
wire [ADDR_WIDTH                  -1 : 0] SHFGLB_InRdAddr   ;
wire                                      SHFGLB_InRdAddrVld;
wire                                      GLBSHF_InRdAddrRdy;
wire [SRAM_WIDTH                  -1 : 0] GLBSHF_InRdDat    ;    
wire                                      GLBSHF_InRdDatVld ;    
wire                                      SHFGLB_InRdDatRdy ;     
wire [ADDR_WIDTH                  -1 : 0] SHFGLB_OutWrAddr  ;
wire [SRAM_WIDTH                  -1 : 0] SHFGLB_OutWrDat   ;   
wire                                      SHFGLB_OutWrDatVld;
wire                                      GLBSHF_OutWrDatRdy;

wire                                      CCUADD_CfgVld           ;
wire                                      ADDCCU_CfgRdy           ;
wire [KNNISA_WIDTH                -1 : 0] CCUADD_CfgInfo          ;
wire [ADDR_WIDTH                  -1 : 0] ADDGLB_Add0RdAddr       ;
wire                                      ADDGLB_Add0RdAddrVld    ;
wire                                      GLBADD_Add0RdAddrRdy    ;
wire [SRAM_WIDTH                  -1 : 0] GLBADD_Add0RdDat        ;    
wire                                      GLBADD_Add0RdDatVld     ;    
wire                                      ADDGLB_Add0RdDatRdy     ;    
wire [ADDR_WIDTH                  -1 : 0] ADDGLB_Add1RdAddr       ;
wire                                      ADDGLB_Add1RdAddrVld    ;
wire                                      GLBADD_Add1RdAddrRdy    ;
wire [SRAM_WIDTH                  -1 : 0] GLBADD_Add1RdDat        ;    
wire                                      GLBADD_Add1RdDatVld     ;    
wire                                      ADDGLB_Add1RdDatRdy     ;     
wire [ADDR_WIDTH                  -1 : 0] ADDGLB_SumWrAddr        ;
wire [SRAM_WIDTH                  -1 : 0] ADDGLB_SumWrDat         ;   
wire                                      ADDGLB_SumWrDatVld      ;
wire                                      GLBADD_SumWrDatRdy      ;

wire                                      CCUCAT_CfgVld           ;
wire                                      CATCCU_CfgRdy           ;
wire [KNNISA_WIDTH                -1 : 0] CCUCAT_CfgInfo          ;
wire [ADDR_WIDTH                  -1 : 0] CATGLB_Ele0RdAddr       ;
wire                                      CATGLB_Ele0RdAddrVld    ;
wire                                      GLBCAT_Ele0RdAddrRdy    ;
wire [SRAM_WIDTH                  -1 : 0] GLBCAT_Ele0RdDat        ;    
wire                                      GLBCAT_Ele0RdDatVld     ;    
wire                                      CATGLB_Ele0RdDatRdy     ;    
wire [ADDR_WIDTH                  -1 : 0] CATGLB_Ele1RdAddr       ;
wire                                      CATGLB_Ele1RdAddrVld    ;
wire                                      GLBCAT_Ele1RdAddrRdy    ;
wire [SRAM_WIDTH                  -1 : 0] GLBCAT_Ele1RdDat        ;    
wire                                      GLBCAT_Ele1RdDatVld     ;    
wire                                      CATGLB_Ele1RdDatRdy     ;     
wire [ADDR_WIDTH                  -1 : 0] CATGLB_CatWrAddr        ;
wire [SRAM_WIDTH                  -1 : 0] CATGLB_CatWrDat         ;   
wire                                      CATGLB_CatWrDatVld      ;
wire                                      GLBCAT_CatWrDatRdy      ;

wire [4                            -1 : 0] OccIdx;

//=====================================================================================================================
// Logic Design: Input
//=====================================================================================================================
assign OccIdx = CCUKNN_CfgInfo[12 +: 3]; // 0: KNN, 1: SHF, 2: ADD, 3: CAT

assign {
        KUAKNN_CfgVld,
        KUAKNN_CfgInfo,
        KUAKNN_CrdRdAddrRdy,
        KUAKNN_CrdRdDat,    
        KUAKNN_CrdRdDatVld, 
        KUAKNN_MaskRdAddrRdy,
        KUAKNN_MaskRdDat,    
        KUAKNN_MaskRdDatVld, 
        KUAKNN_MapWrDatRdy,
        KUAKNN_IdxMaskRdAddrRdy,
        KUAKNN_IdxMaskRdDat,    
        KUAKNN_IdxMaskRdDatVld
    } = OccIdx == KNNIDX? 
    {
        CCUKNN_CfgVld,
        CCUKNN_CfgInfo,
        GLBKNN_CrdRdAddrRdy,
        GLBKNN_CrdRdDat,    
        GLBKNN_CrdRdDatVld, 
        GLBKNN_MaskRdAddrRdy,
        GLBKNN_MaskRdDat,    
        GLBKNN_MaskRdDatVld, 
        GLBKNN_MapWrDatRdy,
        GLBKNN_IdxMaskRdAddrRdy,
        GLBKNN_IdxMaskRdDat,    
        GLBKNN_IdxMaskRdDatVld  
    } : 0;

assign {
            CCUSHF_CfgVld,
            CCUSHF_CfgInfo,
            GLBSHF_InRdAddrRdy,
            GLBSHF_InRdDat,    
            GLBSHF_InRdDatVld,
            GLBSHF_OutWrDatRdy
        } = OccIdx == SHFIDX? 
        {
            CCUKNN_CfgVld,
            CCUKNN_CfgInfo,
            GLBKNN_CrdRdAddrRdy,
            GLBKNN_CrdRdDat,    
            GLBKNN_CrdRdDatVld,
            GLBKNN_MapWrDatRdy
        }: 0;

assign {
        CCUADD_CfgVld,
        CCUADD_CfgInfo,
        GLBADD_Add0RdAddrRdy,
        GLBADD_Add0RdDat,    
        GLBADD_Add0RdDatVld, 
        GLBADD_Add1RdAddrRdy,
        GLBADD_Add1RdDat,    
        GLBADD_Add1RdDatVld, 
        GLBADD_SumWrDatRdy
    }
 = OccIdx == ADDIDX? {
        CCUKNN_CfgVld,
        CCUKNN_CfgInfo,
        GLBKNN_CrdRdAddrRdy,
        GLBKNN_CrdRdDat,    
        GLBKNN_CrdRdDatVld, 
        GLBKNN_MaskRdAddrRdy,
        GLBKNN_MaskRdDat,    
        GLBKNN_MaskRdDatVld, 
        GLBKNN_MapWrDatRdy
    } : 0;

assign {
        CCUCAT_CfgVld,
        CCUCAT_CfgInfo,
        GLBCAT_Ele0RdAddrRdy,
        GLBCAT_Ele0RdDat,    
        GLBCAT_Ele0RdDatVld,
        GLBCAT_Ele1RdAddrRdy,
        GLBCAT_Ele1RdDat,    
        GLBCAT_Ele1RdDatVld, 
        GLBCAT_CatWrDatRdy
    } = OccIdx == CATIDX? 
    {
        CCUKNN_CfgVld,
        CCUKNN_CfgInfo,
        GLBKNN_CrdRdAddrRdy,
        GLBKNN_CrdRdDat,    
        GLBKNN_CrdRdDatVld, 
        GLBKNN_MaskRdAddrRdy,
        GLBKNN_MaskRdDat,    
        GLBKNN_MaskRdDatVld, 
        GLBKNN_MapWrDatRdy
    } : 0;

//=====================================================================================================================
// Logic Design: Output
//=====================================================================================================================
assign {
        KNNCCU_CfgRdy,
        KNNGLB_CrdRdAddr,   
        KNNGLB_CrdRdAddrVld,
        KNNGLB_CrdRdDatRdy,
        KNNGLB_MaskRdAddr,   
        KNNGLB_MaskRdAddrVld,
        KNNGLB_MaskRdDatRdy,
        KNNGLB_MapWrAddr,  
        KNNGLB_MapWrDat,   
        KNNGLB_MapWrDatVld,
        KNNGLB_IdxMaskRdAddr,   
        KNNGLB_IdxMaskRdAddrVld,
        KNNGLB_IdxMaskRdDatRdy
    } = OccIdx == KNNIDX? 
        {
            KNNKUA_CfgRdy,
            KNNKUA_CrdRdAddr,   
            KNNKUA_CrdRdAddrVld,
            KNNKUA_CrdRdDatRdy,
            KNNKUA_MaskRdAddr,   
            KNNKUA_MaskRdAddrVld,
            KNNKUA_MaskRdDatRdy,
            KNNKUA_MapWrAddr,  
            KNNKUA_MapWrDat,   
            KNNKUA_MapWrDatVld,
            KNNKUA_IdxMaskRdAddr,   
            KNNKUA_IdxMaskRdAddrVld,
            KNNKUA_IdxMaskRdDatRdy 
        } : OccIdx == SHFIDX? 
            {
                SHFCCU_CfgRdy,      
                SHFGLB_InRdAddr,   
                SHFGLB_InRdAddrVld,
                SHFGLB_InRdDatRdy, 
                {(IDX_WIDTH + 2){1'b0}}, 
                SHFGLB_OutWrAddr,  
                SHFGLB_OutWrDat,   
                SHFGLB_OutWrDatVld,
                {(IDX_WIDTH + 2){1'b0}} 
            } 
            : OccIdx == ADDIDX? 
                {     
                    ADDCCU_CfgRdy,          
                    ADDGLB_Add0RdAddr,   
                    ADDGLB_Add0RdAddrVld,
                    ADDGLB_Add0RdDatRdy, 
                    ADDGLB_Add1RdAddr ,  
                    ADDGLB_Add1RdAddrVld,
                    ADDGLB_Add1RdDatRdy, 
                    ADDGLB_SumWrAddr,    
                    ADDGLB_SumWrDat,     
                    ADDGLB_SumWrDatVld,
                    {(IDX_WIDTH + 2){1'b0}} 
                } 
                : {      
                    CATCCU_CfgRdy,           
                    CATGLB_Ele0RdAddr,   
                    CATGLB_Ele0RdAddrVld,
                    CATGLB_Ele0RdDatRdy, 
                    CATGLB_Ele1RdAddr,   
                    CATGLB_Ele1RdAddrVld,
                    CATGLB_Ele1RdDatRdy, 
                    CATGLB_CatWrAddr,    
                    CATGLB_CatWrDat,     
                    CATGLB_CatWrDatVld,
                    {(IDX_WIDTH + 2){1'b0}}  
                };

//=====================================================================================================================
// Sub-Module :
//=====================================================================================================================
KNN#(
    .KNNISA_WIDTH         ( KNNISA_WIDTH    ),
    .SRAM_WIDTH           ( SRAM_WIDTH      ),
    .SRAM_MAXPARA         ( SRAM_MAXPARA    ),
    .IDX_WIDTH            ( IDX_WIDTH       ),
    .MAP_WIDTH            ( MAP_WIDTH       ),
    .CRD_WIDTH            ( CRD_WIDTH       ),
    .NUM_SORT_CORE        ( NUM_SORT_CORE   ),
    .KNNMON_WIDTH         ( KNNMON_WIDTH    )
)u_KNN(
    .clk                    ( clk                       ),
    .rst_n                  ( rst_n                     ),
    .CCUKNN_CfgVld          ( KUAKNN_CfgVld             ),
    .KNNCCU_CfgRdy          ( KNNKUA_CfgRdy             ),
    .CCUKNN_CfgInfo         ( KUAKNN_CfgInfo            ),
    .KNNGLB_CrdRdAddr       ( KNNKUA_CrdRdAddr          ),
    .KNNGLB_CrdRdAddrVld    ( KNNKUA_CrdRdAddrVld       ),
    .GLBKNN_CrdRdAddrRdy    ( KUAKNN_CrdRdAddrRdy       ),
    .GLBKNN_CrdRdDat        ( KUAKNN_CrdRdDat           ),
    .GLBKNN_CrdRdDatVld     ( KUAKNN_CrdRdDatVld        ),
    .KNNGLB_CrdRdDatRdy     ( KNNKUA_CrdRdDatRdy        ),
    .KNNGLB_MaskRdAddr      ( KNNKUA_MaskRdAddr         ),
    .KNNGLB_MaskRdAddrVld   ( KNNKUA_MaskRdAddrVld      ),
    .GLBKNN_MaskRdAddrRdy   ( KUAKNN_MaskRdAddrRdy      ),
    .GLBKNN_MaskRdDat       ( KUAKNN_MaskRdDat          ),
    .GLBKNN_MaskRdDatVld    ( KUAKNN_MaskRdDatVld       ),
    .KNNGLB_MaskRdDatRdy    ( KNNKUA_MaskRdDatRdy       ),
    .KNNGLB_MapWrAddr       ( KNNKUA_MapWrAddr          ),
    .KNNGLB_MapWrDat        ( KNNKUA_MapWrDat           ),
    .KNNGLB_MapWrDatVld     ( KNNKUA_MapWrDatVld        ),
    .GLBKNN_MapWrDatRdy     ( KUAKNN_MapWrDatRdy        ),
    .KNNGLB_IdxMaskRdAddr   ( KNNKUA_IdxMaskRdAddr      ),
    .KNNGLB_IdxMaskRdAddrVld( KNNKUA_IdxMaskRdAddrVld   ),
    .GLBKNN_IdxMaskRdAddrRdy( KUAKNN_IdxMaskRdAddrRdy   ),
    .GLBKNN_IdxMaskRdDat    ( KUAKNN_IdxMaskRdDat       ),
    .GLBKNN_IdxMaskRdDatVld ( KUAKNN_IdxMaskRdDatVld    ),
    .KNNGLB_IdxMaskRdDatRdy ( KNNKUA_IdxMaskRdDatRdy    ),
    .KNNMON_Dat             ( KNNMON_Dat                )
);

SHF#(
    .DATA_WIDTH          ( DATA_WIDTH ),
    .SRAM_WIDTH          ( SRAM_WIDTH ),
    .ADDR_WIDTH          ( ADDR_WIDTH ),
    .SHIFTISA_WIDTH      ( KNNISA_WIDTH ),
    .SHF_ADDR_WIDTH      ( SHF_ADDR_WIDTH )
)u_SHF(
    .clk                 ( clk                 ),
    .rst_n               ( rst_n               ),
    .CCUSHF_CfgVld       ( CCUSHF_CfgVld       ),
    .SHFCCU_CfgRdy       ( SHFCCU_CfgRdy       ),
    .CCUSHF_CfgInfo      ( CCUSHF_CfgInfo      ),
    .SHFGLB_InRdAddr     ( SHFGLB_InRdAddr     ),
    .SHFGLB_InRdAddrVld  ( SHFGLB_InRdAddrVld  ),
    .GLBSHF_InRdAddrRdy  ( GLBSHF_InRdAddrRdy  ),
    .GLBSHF_InRdDat      ( GLBSHF_InRdDat      ),
    .GLBSHF_InRdDatVld   ( GLBSHF_InRdDatVld   ),
    .SHFGLB_InRdDatRdy   ( SHFGLB_InRdDatRdy   ),
    .SHFGLB_OutWrAddr    ( SHFGLB_OutWrAddr    ),
    .SHFGLB_OutWrDat     ( SHFGLB_OutWrDat     ),
    .SHFGLB_OutWrDatVld  ( SHFGLB_OutWrDatVld  ),
    .GLBSHF_OutWrDatRdy  ( GLBSHF_OutWrDatRdy  )
);

ADD#(
    .DATA_WIDTH            ( DATA_WIDTH ),
    .SRAM_WIDTH            ( SRAM_WIDTH ),
    .ADDR_WIDTH            ( ADDR_WIDTH ),
    .ADDISA_WIDTH          ( KNNISA_WIDTH )
)u_ADD(
    .clk                   ( clk                   ),
    .rst_n                 ( rst_n                 ),
    .CCUADD_CfgVld         ( CCUADD_CfgVld         ),
    .ADDCCU_CfgRdy         ( ADDCCU_CfgRdy         ),
    .CCUADD_CfgInfo        ( CCUADD_CfgInfo        ),
    .ADDGLB_Add0RdAddr     ( ADDGLB_Add0RdAddr     ),
    .ADDGLB_Add0RdAddrVld  ( ADDGLB_Add0RdAddrVld  ),
    .GLBADD_Add0RdAddrRdy  ( GLBADD_Add0RdAddrRdy  ),
    .GLBADD_Add0RdDat      ( GLBADD_Add0RdDat      ),
    .GLBADD_Add0RdDatVld   ( GLBADD_Add0RdDatVld   ),
    .ADDGLB_Add0RdDatRdy   ( ADDGLB_Add0RdDatRdy   ),
    .ADDGLB_Add1RdAddr     ( ADDGLB_Add1RdAddr     ),
    .ADDGLB_Add1RdAddrVld  ( ADDGLB_Add1RdAddrVld  ),
    .GLBADD_Add1RdAddrRdy  ( GLBADD_Add1RdAddrRdy  ),
    .GLBADD_Add1RdDat      ( GLBADD_Add1RdDat      ),
    .GLBADD_Add1RdDatVld   ( GLBADD_Add1RdDatVld   ),
    .ADDGLB_Add1RdDatRdy   ( ADDGLB_Add1RdDatRdy   ),
    .ADDGLB_SumWrAddr      ( ADDGLB_SumWrAddr      ),
    .ADDGLB_SumWrDat       ( ADDGLB_SumWrDat       ),
    .ADDGLB_SumWrDatVld    ( ADDGLB_SumWrDatVld    ),
    .GLBADD_SumWrDatRdy    ( GLBADD_SumWrDatRdy    )
);

CAT#(
    .SRAM_WIDTH            ( SRAM_WIDTH ),
    .ADDR_WIDTH            ( ADDR_WIDTH ),
    .CATISA_WIDTH          ( KNNISA_WIDTH )
)u_CAT(
    .clk                   ( clk                   ),
    .rst_n                 ( rst_n                 ),
    .CCUCAT_CfgVld         ( CCUCAT_CfgVld         ),
    .CATCCU_CfgRdy         ( CATCCU_CfgRdy         ),
    .CCUCAT_CfgInfo        ( CCUCAT_CfgInfo        ),
    .CATGLB_Ele0RdAddr     ( CATGLB_Ele0RdAddr     ),
    .CATGLB_Ele0RdAddrVld  ( CATGLB_Ele0RdAddrVld  ),
    .GLBCAT_Ele0RdAddrRdy  ( GLBCAT_Ele0RdAddrRdy  ),
    .GLBCAT_Ele0RdDat      ( GLBCAT_Ele0RdDat      ),
    .GLBCAT_Ele0RdDatVld   ( GLBCAT_Ele0RdDatVld   ),
    .CATGLB_Ele0RdDatRdy   ( CATGLB_Ele0RdDatRdy   ),
    .CATGLB_Ele1RdAddr     ( CATGLB_Ele1RdAddr     ),
    .CATGLB_Ele1RdAddrVld  ( CATGLB_Ele1RdAddrVld  ),
    .GLBCAT_Ele1RdAddrRdy  ( GLBCAT_Ele1RdAddrRdy  ),
    .GLBCAT_Ele1RdDat      ( GLBCAT_Ele1RdDat      ),
    .GLBCAT_Ele1RdDatVld   ( GLBCAT_Ele1RdDatVld   ),
    .CATGLB_Ele1RdDatRdy   ( CATGLB_Ele1RdDatRdy   ),
    .CATGLB_CatWrAddr      ( CATGLB_CatWrAddr      ),
    .CATGLB_CatWrDat       ( CATGLB_CatWrDat       ),
    .CATGLB_CatWrDatVld    ( CATGLB_CatWrDatVld    ),
    .GLBCAT_CatWrDatRdy    ( GLBCAT_CatWrDatRdy    )
);

endmodule
