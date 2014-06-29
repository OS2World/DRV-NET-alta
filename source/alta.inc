; === sundance st201 alta specific definition ===

; +++ registers definition +++
alta_registers	struc
DMACtrl		dd	?	; 00
TxDMAListPtr	dd	?	; 04
TxDMABurstThr	db	?	; 08
TxDMAUrgentThr	db	?	; 09
TxDMAPollPeriod	db	?	; 0A
		db	?	; 0B reserve
RxDMAStatus	dd	?	; 0C
RxDMAListPtr	dd	?	; 10
RxDMABurstThr	db	?	; 14
RxDMAUrgentThr	db	?	; 15
RxDMAPollPeriod	db	?	; 16
		db	?	; 17 reserve
		dw	?	; 18 reserve
DebugCtrl	dw	?	; 1a
		dd	5 dup(?) ; 1C-2F reserve
AsicCtrl	dd	?	; 30
EepromData	dw	?	; 34
EepromCtrl	dw	?	; 36
		dw	?	; 38 reserve
FIFOCtrl	dw	?	; 3A
TxStartThr	dw	?	; 3C
RxEarlyThr	dw	?	; 3E
ExpRomAddr	dd	?	; 40
ExpRomData	db	?	; 44
WakeEvent	db	?	; 45
TxStatus	dw	?	; 46
Countdown	dw	?	; 48
IntStatusAck	dw	?	; 4A
IntEnable	dw	?	; 4C
IntStatus	dw	?	; 4E
MACCtrl0	dw	?	; 50
MACCtrl1	dw	?	; 52
StationAddr0	dw	?	; 54
StationAddr1	dw	?	; 56
StationAddr2	dw	?	; 58
MaxFrameSize	dw	?	; 5A
ReceiveMode	db	?	; 5C
TxReleaseThr	db	?	; 5D
PhyCtrl		db	?	; 5E
		db	?	; 5F reserve
HashTable0	dw	?	; 60
HashTable1	dw	?	; 62
HashTable2	dw	?	; 64
HashTable3	dw	?	; 66

OctRxOk0	dw	?	; 68
OctRxOk1	dw	?	; 6A
OctTxOk0	dw	?	; 6C
OctTxOk1	dw	?	; 6E
FrmTxOk		dw	?	; 70
FrmRxOk		dw	?	; 72
CRSErr		db	?	; 74
LateCol		db	?	; 75
MultiCol	db	?	; 76
SingleCol	db	?	; 77
TxDeffer	db	?	; 78
RxLost		db	?	; 79
TxExDeffer	db	?	; 7A
AbortExCol	db	?	; 7B
BcstFrmTxOk	db	?	; 7C
BcstFrmRxOk	db	?	; 7D
McstFrmTxOk	db	?	; 7E
McstFrmRxOk	db	?	; 7F
alta_registers	ends


; --- AsicCtrl 30h dword ---
ExpRomSize	equ	      2	; 0:32K 1:64K
TxLargeEnable	equ	      4	; Tx larger than FIFO
RxLargeEnable	equ	      8	; Rx Larger than FIFO
ExpRomDisable	equ	     10h	; 
PhySpeed10	equ	     20h	; RO
PhySpeed100	equ	     40h	; RO
PhyMedia	equ	     80h	; RO 0:twist-pair 1:fiber
ForceConfig	equ	    700h	; mask 00:normal 01:force 1xx:alternate id
D3ResetDisable	equ	    800h	; 
SpeedupMode	equ	   2000h	; for simulation
LEDMode		equ	   4000h	; 
RstOutPolarity	equ	   8000h	; 
GlobalReset	equ	  10000h	; SC [24..19]
RxReset		equ	  20000h	; SC [21..19]
TxReset		equ	  40000h	; SC [21..19]
DMA		equ	  80000h	; SC
FIFO		equ	 100000h	; SC
Network		equ	 200000h	; SC
Host		equ	 400000h	; SC
AutoInit	equ	 800000h	; SC
RstOut		equ	1000000h	; SC
IntRequest	equ	2000000h	; SC
ResetBusy	equ	4000000h	; indicator

; --- DMACtrl 00h dword ---
RxDMAHalted	equ	       1	; RO clear by RxDMAResume
TxDMAcmplReq	equ	       2	; RO
TxDMAHalted	equ	       4	; RO clear by TxDMAResume
dRxDMAComplete	equ	       8	; RO (same IntStatus)
dTxDMAComplete	equ	      10h	; RO (same IntStatus)
RxDMAHalt	equ	     100h	; SC
RxDMAResume	equ	     200h	; SC
TxDMAHalt	equ	     400h	; SC
TxDMAResume	equ	     800h	; SC
TxDMAInProg	equ	    4000h	; RO
DMAHaltBusy	equ	    8000h	; RO
RxEarlyEnable	equ	   20000h	; RxEarlyThr enable
CntdwnSpeed	equ	   40000h	; 0:3.2us  1:320ns
CntdwnMode	equ	   80000h	; 0:soon  1:TxDMAComplete
MWIDisable	equ	  100000h	; 
RxDMAOverrun	equ	  400000h	; copy overrun frame
CntdwnEnable	equ	  800000h	; RO
TargetAbort	equ	40000000h	; RO
MasterAbort	equ	80000000h	; RO

; --- EepromCtrl 36h word ---
EepromAddr	equ	 0ffh	; mask
EepromOpcode	equ	 300h	; mask
EepromOpcode_Read	equ	200h	; register read opecode
EepromBusy	equ	8000h	; RO

; --- FIFOCtrl 3ah word ---
RAMTestMode	equ	   1
RxOverrunFrame	equ	 200h	; copy overrun data
RxFIFOFull	equ	 800h	; RO
Transmitting	equ	4000h	; RO
Receiving	equ	8000h	; RO  receiving into FIFO

; --- IntStatusAck/IntEnable/IntStatus 4ah/4ch/4eh word ---
InterruptStatus	equ	   1	; interrupt signaling
HostError	equ	   2	; target/master abort
iTxComplete	equ	   4	; TxOk or errored
MACCtrlFrms	equ	   8	; received Pause
RxComplete	equ	  10h	; Into FIFO. should be disabled.
RxEarly		equ	  20h	; 
IntRequested	equ	  40h	; InterruptRequest or Countdown
UpdateStats	equ	  80h	; statistics
iLinkEvent	equ	 100h	; 
iTxDMAComplete	equ	 200h	; 
iRxDMAComplete	equ	 400h	; 

; --- MACCtrl0 50h word ---
IFSSelect	equ	   3	; mask  00:standard
FDXEnable	equ	  20h	; full duplex enable
RcvLargeFrames	equ	  40h	; 0:1514  1:4491
FlowCtrlEnable	equ	 100h	; rx pause enable
RcvFCS		equ	 200h	; 0:strip  1:into data
FIFOLoopback	equ	 400h	; 
MACLoopback	equ	 800h	;

; --- MACCtrl1 52h word ---
CollisionDetect	equ	   1	; RO
CarrierSense	equ	   2	; RO
TxInProg	equ	   4	; RO
TxError		equ	   8	; RO  TxReset is required
StatsEnable	equ	  20h	; SC
StatsDisable	equ	  40h	; SC
StatsEnabled	equ	  80h	; RO
TxEnable	equ	 100h	; SC
TxDisable	equ	 200h	; SC
TxEnabled	equ	 400h	; RO
RxEnable	equ	 800h	; SC
RxDisable	equ	1000h	; SC
RxEnabled	equ	2000h	; RO
Paused		equ	4000h	; RO

; --- PHyCtrl 5eh byte ---
MgmtClk		equ	 1
MgmtData	equ	 2
MgmtDir		equ	 4
DisableClk25	equ	 8
PhyDuplexPol	equ	10h
PhyDuplexStat	equ	20h	; RO
PhySpeedStat	equ	40h	; RO
PhyLinkStat	equ	80h	; RO

; --- ReceiveMode 5ch byte ---
ReceiveUnicast	equ	 1	; match station address
ReceiveMult	equ	 2	; all multicast
ReceiveBroad	equ	 4	;
ReceiveAll	equ	 8	; promisucous
ReceiveHash	equ	10h	; multicast with Hash table
ReceiveIPMult	equ	20h	; IP multicast

; --- TxStatus 46h word ---
TxReleaseError	equ	   2	; 
TxStatusOverflw	equ	   4	; status queue overflow
MaxCollisions	equ	   8	; excessive collisions
TxUnderrun	equ	  10h	; TxReset is need
TxIndicateReqd	equ	  40h	; 
sTxComplete	equ	  80h	; status validation
TxFrameId	equ	0ff00h	; mask FrameId

; --- WakeEvent 45h byte ---
WakePktEnable	equ	 1	; 
MagicPktEnable	equ	 2	; 
LinkEventEnable	equ	 4	; 
WakePolarity	equ	 8	; 
WakePktEvent	equ	10h	; 
MagicPktEvent	equ	20h	; 
LinkEvent	equ	40h	; 
WakeOnLanEnable	equ	80h	; force WOL mode


; +++ Frame descriptor +++
; --- Fragments Information ---
FragInfo	struc
FragAddr	dd	?	; physical address of fragment
FragLen		dw	?	; size of fragment. [0..8191] 13bit
FragIndic	dw	?	; for last fragment indicator
FragInfo	ends

FragLast	equ	8000h	; last fragment indicator

; --- Transmit Frame Descriptor ---
TFD		struc
NextPtr		dd	?	; link
TFC		dd	?	; transmit frame control
FragInfo1	FragInfo 9 dup(<>)	; max 9 fragments. immed + blocks
;
PhysAddr	dd	?	; physical address of this TFD
ReqHandle	dw	?	; request packet handle
ProtID		dw	?	; request protocol handle
vlink		dw	?	; virtual link for driver access
TFDId		db	?	; same of FrameId, for convenience
		db	?	; reserve for alignment
immed		db	64 dup(?)	; reserve for immediate data
TFD		ends

; --- Receive Frame Descriptor ---
RFD		struc
NextPtr		dd	?	; link
RFS		dd	?	; receive frame status
FragInfo1	FragInfo <>	; single fragment
; 
PhysAddr	dd	?	; physical address of this RFD
FragVAddr	dd	?	; virtual address of fragment buffer
vlink		dw	?	; virtual link for driver access
		dw	?,?,?	; reserve for 8bytes alignment
RFD		ends

; --- Transmit Frame Control ---
WordAlign	equ	       3	; mask 0:dword 10:word x1:no align
FrameId		equ	     3fch	; mask
FcsAppDisable	equ	    2000h	; FCS append disable
TxIndicate	equ	    8000h	; TxComplete interrupt request
cTxDMAComplete	equ	   10000h	; TxDMA complete
TxDMAIndicate	equ	80000000h	; TxDMAComplete interrupt request

; --- Receive Frame Status ---
sRxFrameLen	equ	    1fffh	; mask received frame length
RxFrameError	equ	    4000h	; summary [16..20]
sRxDMAComplete	equ	    8000h	; DMA complete success or error
RxFIFOOverrun	equ	   10000h	; 
RxRuntFrame	equ	   20000h	; 
RxAlignError	equ	   40000h	; 
RxFCSError	equ	   80000h	; 
RxOversized	equ	  100000h	; 
DrribleBits	equ	  800000h	; 
RxDMAOverflow	equ	 1000000h	; 
ImpliedBuffer	equ	10000000h	; special RFD format

