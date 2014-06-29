; *** Resident part: Hardware dependent ***

include	NDISdef.inc
include	alta.inc
include	MIIdef.inc
include	misc.inc
include	DrvRes.inc
include	Pci0Res.inc

public	DrvMajVer, DrvMinVer
DrvMajVer	equ	1
DrvMinVer	equ	0

.386

_REGSTR	segment	use16 dword AT 'RGST'
	org	0
Reg	alta_registers <>
_REGSTR	ends

_DATA	segment	public word use16 'DATA'

; --- DMA Descriptor management ---
public	TxHead, TxTail, TxFreeHead, TxFreeTail
TxHead		dw	0
TxTail		dw	0
TxFreeHead	dw	0
TxFreeTail	dw	0

public	RxHead, RxTail, RxBusyHead, RxBusyTail, RxInProg
RxInProg	dw	0
RxHead		dw	0
RxTail		dw	0
RxBusyHead	dw	0
RxBusyTail	dw	0

; --- System(PCI) Resource ---
public	MEMSel, MEMaddr, IRQlevel
public	CacheLine, Latency, PPMaddr, BusDevFunc
;IOaddr		dw	?
MEMSel		dw	?
MEMaddr		dd	?
IRQlevel	db	?
CacheLine	db	0	; [0..3] <- [0,8,16,32]
Latency		db	0
PPMaddr		db	0	; power management address
BusDevFunc	dw	?

align	2
; --- Physical information ---
PhyInfo		_PhyInfo <>

public	MediaSpeed, MediaDuplex, MediaPause, MediaLink	; << for debug >>
MediaSpeed	db	0
MediaDuplex	db	0
MediaPause	db	0
MediaLink	db	0

; --- Register Contents ---
public	regIntMask		; << for debug info >>
regIntMask	dw	0

; --- ReceiveChain Frame Descriptor ---
public	RxFrameLen, RxDesc	; << for debug info >>
RxFrameLen	dw	0
;RxDesc		RxFrameDesc	<>
RxDesc		label	RxFrameDesc
		dw	1	; RxDataCount  single fragment
		dw	?	; RxDataLen
		dd	?	; RxDataPtr

; --- Configuration Memory Image Parameters ---
public	cfgSLOT, cfgTXQUEUE, cfgRXQUEUE, cfgMAXFRAMESIZE
public	cfgTxStartThresh, cfgRxEarlyThresh

cfgSLOT		db	0
cfgTXQUEUE	db	8
cfgRXQUEUE	db	16
cfgTxStartThresh	dw	1536	; byte  4..1ffc
cfgRxEarlyThresh	dw	256	; byte  8..1ffc


public	cfgTxBurstThresh, cfgTxUrgentThresh, cfgTxPollPeriod
public	cfgTxReleaseThresh
public	cfgRxBurstThresh, cfgRxUrgentThresh, cfgRxPollPeriod

cfgTxBurstThresh	db	256/32	; n*32byte  1..1f
cfgTxUrgentThresh	db	128/32	; n*32byte  1..3f
cfgTxPollPeriod		db	127	; n*320ns  0..7f
cfgTxReleaseThresh	db	128/16	; n*16byte  4..ff

cfgRxBurstThresh	db	256/32	; n*32byte  1..ff
cfgRxUrgentThresh	db	128/32	; n*32byte  1..3f
cfgRxPollPeriod		db	127	; n*320ns  1..7f

cfgMAXFRAMESIZE	dw	1514

; --- Receive Buffer address ---
public	RxBufferLin, RxBufferPhys, RxBufferSize, RxBufferSelCnt, RxBufferSel
RxBufferLin	dd	?
RxBufferPhys	dd	?
RxBufferSize	dd	?
RxBufferSelCnt	dw	?
RxBufferSel	dw	2 dup (?)	; max is 2.

; ---Vendor Adapter Description ---
public	AdapterDesc
AdapterDesc	db	'Sundance ST201 alta Fast Ethernet Adapter',0


_DATA	ends

_TEXT	segment	public word use16 'CODE'
	assume	ds:_DATA, gs:_REGSTR
	
; USHORT hwTxChain(TxFrameDesc *txd, USHORT rqh, USHORT pid)
_hwTxChain	proc	near
	push	bp
	mov	bp,sp
	push	fs
	lfs	bx,[bp+4]
	mov	ax,fs:[bx].TxFrameDesc.TxImmedLen
	mov	cx,fs:[bx].TxFrameDesc.TxDataCount
	dec	cx
	jl	short loc_2
loc_1:
	add	ax,fs:[bx].TxFrameDesc.TxBufDesc1.TxDataLen
	add	bx,sizeof(TxBufDesc)
	dec	cx
	jge	short loc_1
loc_2:
;	cmp	ax,[cfgMAXFRAMESIZE]	; (max frame size)
	cmp	ax,1536			; buffer size
	mov	ax,INVALID_PARAMETER
	ja	short loc_ip		; invalid parameter
	push	offset semTx
	call	_EnterCrit
	mov	bx,[TxFreeHead]
	cmp	bx,[TxFreeTail]
	jnz	short loc_3		; no TFD. out of resource
	call	_LeaveCrit
	mov	ax,OUT_OF_RESOURCE
	pop	cx	; stack adjust
loc_ip:
	pop	fs
	pop	bp
	retn

loc_3:
	mov	ax,[bx].TFD.vlink
	mov	[TxFreeHead],ax		; next TFD
	call	_LeaveCrit

	mov	ax,[bp+8]		; ReqHandle
	mov	cx,[bp+10]		; ProtID
	mov	bp,[bp+4]		; fs:bp =  TxFrameDesc
	mov	[bx].TFD.ReqHandle,ax
	mov	[bx].TFD.ProtID,cx
	mov	[bx].TFD.vlink,0	; null vlink

	mov	cx,fs:[bp].TxFrameDesc.TxImmedLen
	lea	di,[bx].TFD.FragInfo1
	or	cx,cx
	jz	short loc_4		; no immediate data

	push	cx	; --- copy immediate data ---
	push	di
	push	ds
	push	ds
	pop	es
	lds	si,fs:[bp].TxFrameDesc.TxImmedPtr
	mov	ax,cx
	lea	di,[bx].TFD.immed
	shr	cx,2
	and	ax,3
	rep	movsd
	mov	cx,ax
	rep	movsb
	pop	ds
	pop	di
	pop	cx
	mov	ax,word ptr [bx].TFD.PhysAddr
	mov	dx,word ptr [bx].TFD.PhysAddr[2]
	add	ax,offset TFD.immed
	mov	[di].FragInfo.FragLen,cx
	mov	[di].FragInfo.FragIndic,0	; clear FragLast bit
	mov	word ptr [di].FragInfo.FragAddr,ax
	mov	word ptr [di].FragInfo.FragAddr[2],dx
	add	di,sizeof(FragInfo)

loc_4:
	mov	si,fs:[bp].TxFrameDesc.TxDataCount
	lea	bp,[bp].TxFrameDesc.TxBufDesc1
	dec	si
	jl	short loc_7			; no buffer descriptor
loc_5:
	cmp	fs:[bp].TxBufDesc.TxPtrType,0	; physical ?
	mov	ax,word ptr fs:[bp].TxBufDesc.TxDataPtr
	mov	dx,word ptr fs:[bp].TxBufDesc.TxDataPtr[2]
	jz	short loc_6
	push	dx
	push	ax
	call	_VirtToPhys
	add	sp,4
loc_6:
	mov	cx,fs:[bp].TxBufDesc.TxDataLen
	mov	word ptr [di].FragInfo.FragAddr,ax
	mov	word ptr [di].FragInfo.FragAddr[2],dx
	mov	[di].FragInfo.FragLen,cx
	mov	[di].FragInfo.FragIndic,0

	add	di,sizeof(FragInfo)
	add	bp,sizeof(TxBufDesc)
	dec	si
	jge	short loc_5
loc_7:
	xor	ax,ax
	mov	[di-sizeof(FragInfo)].FragInfo.FragIndic,FragLast
	mov	al,[bx].TFD.TFDId
	shl	ax,2
	or	ax,TxIndicate or 1	; IntReq and Byte align
	mov	word ptr [bx].TFD.TFC,ax
	mov	word ptr [bx].TFD.TFC[2],0	; clear DMA Complete
	mov	ecx,[bx].TFD.PhysAddr
	mov	[bx].TFD.NextPtr,0	; null link

	call	_EnterCrit
	mov	di,[TxTail]
	or	di,di
	jz	short loc_8
	mov	[di].TFD.NextPtr,ecx	; link to previous TFD
	cmp	[TxHead],0
	jz	short loc_9
	mov	[di].TFD.vlink,bx	; vlink
	jmp	short loc_10
loc_8:
	mov	gs:[Reg.TxDMAListPtr],ecx  ; set TFD List Ptr
loc_9:
	mov	[TxHead],bx
loc_10:
	mov	[TxTail],bx
	mov	gs:[Reg.MACCtrl1],TxEnable

	call	_LeaveCrit
	mov	ax,REQUEST_QUEUED
	pop	cx	; stack adjust
	pop	fs
	pop	bp
	retn
_hwTxChain	endp


_hwRxRelease	proc	near
	push	bp
	mov	bp,sp
	push	si
	push	di
	push	offset semRx
	call	_EnterCrit

	mov	ax,[bp+4]		; ReqHandle = RFD offset
	mov	bx,[RxInProg]
	test	bx,bx
	jz	short loc_1		; no frame in progress
	cmp	ax,bx
	jnz	short loc_1
	mov	[RxInProg],0		; ReqHandle = RxInProg
	jmp	short loc_4

loc_1:
	mov	bx,[RxBusyHead]
loc_2:
	or	bx,bx
	jz	short loc_ex		; not found
	cmp	ax,bx
	jz	short loc_3		; found frame id matched
	mov	si,bx			; previous RFD
	mov	bx,[bx].RFD.vlink
	jmp	short loc_2
loc_3:
	mov	cx,[bx].RFD.vlink	; next RFD / null
	cmp	ax,[RxBusyHead]
	jz	short loc_h
	cmp	ax,[RxBusyTail]
	jnz	short loc_m
loc_t:
	mov	[RxBusyTail],si
loc_m:
	mov	[si].RFD.vlink,cx
	jmp	short loc_4
loc_h:
	mov	[RxBusyHead],cx
loc_4:
	mov	si,[RxTail]
	mov	[bx].RFD.NextPtr,0		; null link
	mov	word ptr [bx].RFD.RFS,sRxDMAComplete ; terminate
	mov	word ptr [bx].RFD.RFS[2],0
	mov	eax,[bx].RFD.PhysAddr
	mov	[si].RFD.NextPtr,eax		; link
	mov	word ptr [si].RFD.RFS,0		; clear DMAComplete
	mov	[si].RFD.vlink,bx		; vlink
	mov	[bx].RFD.vlink,0		; null vlink
	mov	[RxTail],bx

IF 0
	cmp	si,[RxHead]			; no RFD?
	jnz	short loc_ex
	or	gs:[Reg.DMACtrl],RxDMAResume
ENDIF
;	mov	gs:[Reg.MACCtrl1],RxEnable
loc_ex:
	call	_LeaveCrit
	pop	cx	; stack adjust
	mov	ax,SUCCESS
	pop	di
	pop	si
	pop	bp
	retn
_hwRxRelease	endp


_ServiceIntTx	proc	near
	enter	8,0
	push	offset semTx
	mov	word ptr [bp-2],0
	call	_EnterCrit
	mov	ax,gs:[Reg.TxStatus]
	test	ax,sTxComplete
	jz	short loc_4		; nothing done
loc_1:
	mov	[bp-2],ax
	mov	gs:[Reg.TxStatus],ax	; next status
	mov	ax,gs:[Reg.TxStatus]
	test	ax,sTxComplete
	jnz	short loc_1
	mov	bx,[TxHead]
	mov	[bp-6],bx		; head
	shr	ax,8			; FrameId
loc_2:
	mov	cx,bx
	or	bx,bx
	jz	short loc_3		; match TFD is not found !?
	cmp	[bx].TFD.TFDId,al
	mov	bx,[bx].TFD.vlink
	jnz	short loc_2
	mov	[TxHead],bx		; next TFD
loc_3:
	mov	[bp-4],cx		; tail
loc_4:
	call	_LeaveCrit

	test	word ptr [bp-2],sTxComplete
	jz	short loc_ex
	mov	bx,[bp-6]		; head
	or	bx,bx
	jz	short loc_ex		; no TFD
	cmp	word ptr [bp-4],0
	jz	short loc_ex		; no matching ID !?

loc_5:
	mov	[bp-8],bx		; current
	xor	ax,ax
	cmp	bx,[bp-4]
	jnz	short loc_6
	test	word ptr [bp-2],TxReleaseError or TxStatusOverflw or \
		  MaxCollisions or TxUnderrun
	jz	short loc_6
	mov	ax,GENERAL_FAILURE
loc_6:
	mov	cx,[bx].TFD.ReqHandle
	mov	dx,[bx].TFD.ProtID
	mov	di,[CommonChar.moduleID]
	mov	si,[ProtDS]

	push	dx	; ProtID
	push	di	; MACID
	push	cx	; ReqHandle
	push	ax	; Status
	push	si	; ProtDS
	call	dword ptr [LowDisp.txconfirm]
	mov	gs,[MEMSel]	; fix gs selector

	mov	bx,[bp-8]
	cmp	bx,[bp-4]
	mov	bx,[bx].TFD.vlink
	jnz	short loc_5

	call	_EnterCrit
	mov	bx,[TxFreeTail]
	mov	ax,[bp-6]
	mov	si,[bp-4]
	mov	[bx].TFD.vlink,ax
	mov	[si].TFD.vlink,0
	mov	[TxFreeTail],si
	call	_LeaveCrit

	test	word ptr [bp-2],TxReleaseError or TxStatusOverflw or \
		  MaxCollisions or TxUnderrun
	jnz	short loc_err
loc_ex:
;	pop	cx	; stack adjust
	leave
	retn

loc_err:
	mov	ax,gs:[Reg.MACCtrl1]
	test	ax,TxError
	jz	short loc_reset
;	mov	eax,gs:[Reg.DMACtrl]
	mov	ax,word ptr gs:[Reg.DMACtrl]
	test	ax,TxDMAHalted
	jz	short loc_ex		; what error !?
;	or	ax,TxDMAResume
;	mov	gs:[Reg.DMACtrl],eax
	mov	word ptr gs:[Reg.DMACtrl],lowword TxDMAResume
	mov	gs:[Reg.MACCtrl1],TxEnable
	jmp	short loc_ex

loc_reset:
	call	_EnterCrit
	mov	gs:[Reg.MACCtrl1],TxDisable
	mov	word ptr [bp-8],256
loc_r1:
	test	gs:[Reg.MACCtrl1],TxInProg	; tx stop ?
	jz	short loc_r2
	push	2
	call	__IODelayCnt
	pop	ax	; stack adjust
	dec	word ptr [bp-8]
	jnz	short loc_r1

loc_r2:
;	or	gs:[Reg.AsicCtrl],TxReset or DMA or FIFO or Network
	mov	word ptr gs:[Reg.AsicCtrl][2],highword \
		  (TxReset or DMA or FIFO or Network)
	mov	word ptr [bp-8],256
loc_r3:
;	test	gs:[Reg.AsicCtrl],TxReset or DMA or FIFO or Network or \
;		  ResetBusy
	test	word ptr gs:[Reg.AsicCtrl][2],highword \
		  (TxReset or DMA or FIFO or Network or ResetBusy)
	jz	short loc_r4
	push	2
	call	__IODelayCnt
	pop	ax	; stack adjust
	dec	word ptr [bp-8]
	jnz	short loc_r3
loc_r4:
	call	_SetTxEnv
	call	_SetMediumEnv

	mov	bx,[TxHead]
	or	bx,bx
	jz	short loc_r5
	mov	eax,[bx].TFD.PhysAddr		; next TFD exist
	mov	gs:[Reg.TxDMAListPtr],eax
	mov	gs:[Reg.MACCtrl1],TxEnable
	jmp	short loc_r_ex
loc_r5:
	mov	[TxTail],bx		; no TFD. unmark tail
loc_r_ex:
	call	_LeaveCrit
	jmp	near ptr loc_ex
_ServiceIntTx	endp


_ServiceIntRx	proc	near
	push	offset semRx
loc_0:
	call	_EnterCrit
	mov	bx,[RxInProg]
loc_1:
	mov	si,[RxHead]
	or	bx,bx
;	jnz	short loc_rty		; retry suspended frame
	jnz	near ptr loc_rty
	cmp	si,[RxTail]
	jz	short loc_ex		; no RFD. exit
	mov	ax,word ptr [si].RFD.RFS
	test	ax,sRxDMAComplete
	jz	short loc_ex		; queue empty

	test	ax,RxFrameError
	jnz	short loc_rej		; errored frame. reject
	and	ax,sRxFrameLen
	cmp	ax,6+6+2
	jc	short loc_rej		; too small length
	cmp	ax,[cfgMAXFRAMESIZE]
	jna	short loc_ok		; too long length
loc_rej:
	mov	ax,[si].RFD.vlink
	mov	bx,[RxTail]
	mov	[RxHead],ax
	mov	[RxTail],si
	mov	[bx].RFD.vlink,si
	mov	[si].RFD.vlink,0
	mov	word ptr [si].RFD.RFS,sRxDMAComplete
	mov	word ptr [si].RFD.RFS,0
	mov	ecx,[si].RFD.PhysAddr
	mov	[si].RFD.NextPtr,0
	mov	[bx].RFD.NextPtr,ecx
	mov	word ptr [bx].RFD.RFS,0
IF 0
	cmp	bx,ax
	jnz	short loc_1
	or	gs:[Reg.DMACtrl],RxDMAResume
ENDIF
	jmp	short loc_1

loc_ex:
	call	_LeaveCrit
	pop	cx	; stack adjust
	retn

loc_ok:
	mov	cx,[si].RFD.vlink
	mov	[RxFrameLen],ax
	mov	[RxInProg],si
	mov	[RxHead],cx
	mov	dx,word ptr [si].RFD.FragVAddr
	mov	cx,word ptr [si].RFD.FragVAddr[2]
	mov	RxDesc.RxDataCount,1
	mov	RxDesc.RxBufDesc1.RxDataLen,ax
	mov	word ptr RxDesc.RxBufDesc1.RxDataPtr,dx
	mov	word ptr RxDesc.RxBufDesc1.RxDataPtr[2],cx
	mov	bx,si
loc_rty:
	call	_LeaveCrit

					; bx = RxInProg
	call	_IndicationChkOFF
	or	ax,ax
	jz	short loc_spd		; indicate off - suspend...

	push	-1
	mov	cx,[RxFrameLen]
	mov	ax,[ProtDS]
	mov	dx,[CommonChar.moduleID]
	mov	di,sp
	push	bx			; current vrxd = handle

	push	dx		; MACID
	push	cx		; FrameSize
	push	bx		; ReqHandle
	push	ds
	push	offset RxDesc	; RxFrameDesc
	push	ss
	push	di		; Indicate
	push	ax		; Protocol DS
	call	dword ptr [LowDisp.rxchain]
	mov	gs,[MEMSel]	; fix gs selector
lock	or	[drvflags],mask df_idcp
	cmp	ax,WAIT_FOR_RELEASE
	jz	short loc_3
	call	_hwRxRelease
loc_2:
	pop	cx	; stack adjust
	pop	ax	; indicate
	cmp	al,-1
	jnz	short loc_spd		; indication remains OFF - suspend
	call	_IndicationON
	jmp	near ptr loc_0
loc_3:
	call	_RxPutBusyQueue
	jmp	short loc_2

loc_spd:
lock	or	[drvflags],mask df_rxsp
	pop	cx	; stack adjust
	pop	bp
	retn

_RxPutBusyQueue	proc	near
	push	offset semRx
	call	_EnterCrit
	mov	bx,[RxInProg]
	or	bx,bx
	jz	short loc_ex		; no progress frame
	cmp	[RxBusyHead],0
	jnz	short loc_1
	mov	[RxBusyHead],bx
	jmp	short loc_2
loc_1:
	mov	si,[RxBusyTail]
	mov	[si].RFD.vlink,bx
loc_2:
	mov	[RxBusyTail],bx
	mov	[bx].RFD.vlink,0
loc_ex:
	call	_LeaveCrit
	pop	bx	; stack adjust
	retn
_RxPutBusyQueue	endp

_ServiceIntRx	endp


_hwServiceInt	proc	near
	enter	2,0
loc_0:
	mov	ax,gs:[Reg.IntStatus]
	and	ax,[regIntMask]
	jz	short loc_ex
	mov	[bp-2],ax
	or	ax,InterruptStatus
	mov	gs:[Reg.IntStatus],ax

loc_1:
	test	word ptr [bp-2],iTxComplete or IntRequested
	jz	short loc_2
	call	_ServiceIntTx

loc_2:
	test	word ptr [bp-2],iRxDMAComplete or IntRequested
	jz	short loc_3
	call	_ServiceIntRx

loc_3:
	test	word ptr [bp-2],UpdateStats
	jz	short loc_4
	call	_hwUpdateStat

loc_4:
lock	btr	[drvflags],df_rxsp
	jnc	short loc_0

loc_ex:
	leave
	retn
_hwServiceInt	endp

_hwCheckInt	proc	near
	mov	ax,gs:[Reg.IntStatus]
	and	ax,InterruptStatus
	retn
_hwCheckInt	endp

_hwEnableInt	proc	near
	mov	ax,[regIntMask]
	mov	gs:[Reg.IntEnable],ax
	retn
_hwEnableInt	endp

_hwDisableInt	proc	near
	mov	gs:[Reg.IntEnable],0
	mov	ax,gs:[Reg.IntEnable]	; ensure write register
	retn
_hwDisableInt	endp

_hwIntReq	proc	near
;	mov	eax,gs:[Reg.AsicCtrl]
;	or	eax,IntRequest
;	mov	gs:[Reg.AsicCtrl],eax
	mov	word ptr gs:[Reg.AsicCtrl][2],highword IntRequest
	retn
_hwIntReq	endp

_hwEnableRxInd	proc	near
	push	ax
lock	or	[regIntMask],iRxDMAComplete
	cmp	[semInt],0
	jnz	short loc_1
	mov	ax,[regIntMask]
	mov	gs:[Reg.IntEnable],ax
loc_1:
	pop	ax
	retn
_hwEnableRxInd	endp

_hwDisableRxInd	proc	near
	push	ax
lock	and	[regIntMask],not iRxDMAComplete
	cmp	[semInt],0
	jnz	short loc_1
	mov	ax,[regIntMask]
	mov	gs:[Reg.IntEnable],ax
loc_1:
	pop	ax
	retn
_hwDisableRxInd	endp


_hwPollLink	proc	near
	call	_ChkLink
	test	al,MediaLink
	jz	short loc_0	; Link status change/down
	retn
loc_0:
	or	al,al
	mov	MediaLink,al
	jnz	short loc_1	; change into Link Active
	call	_ChkLink	; link down. check again.
	or	al,al
	mov	MediaLink,al
	jnz	short loc_1	; short time link down
	retn

loc_1:
	call	_GetPhyMode

	cmp	al,MediaSpeed
	jnz	short loc_2
	cmp	ah,MediaDuplex
	jnz	short loc_2
	cmp	dl,MediaPause
	jz	short loc_3
loc_2:
	mov	MediaSpeed,al
	mov	MediaDuplex,ah
	mov	MediaPause,dl
	call	_SetMediumEnv
loc_3:
	retn
_hwPollLink	endp

_hwOpen		proc	near	; call in protocol bind process?
	enter	2,0
;	or	gs:[Reg.AsicCtrl],RxReset or TxReset or \ 
;		  DMA or FIFO or Network	; reset tx/rx
	mov	word ptr gs:[Reg.AsicCtrl][2],highword \
		  (RxReset or TxReset or DMA or FIFO or Network)

	call	_ClearTxQueue
	call	_ClearRxQueue

	call	_AutoNegotiate
	mov	MediaSpeed,al
	mov	MediaDuplex,ah
	mov	MediaPause,dl

	mov	word ptr [bp-2],16
loc_1:
;	test	gs:[Reg.AsicCtrl],RxReset or TxReset or \ 
;		  DMA or FIFO or Network or ResetBusy	; reset complete?
	test	word ptr gs:[Reg.AsicCtrl][2],highword (ResetBusy or \
		  RxReset or TxReset or DMA or FIFO or Network)
	jz	short loc_2
	push	96
	call	_Delay1ms
	pop	ax
	dec	word ptr [bp-2]
	jnz	short loc_1
	mov	ax,HARDWARE_FAILURE	; reset timeout. critical error
	jmp	short loc_ex

loc_2:
	call	_hwUpdatePktFlt
	call	_hwUpdateMulticast
	call	_SetMacEnv

	push	offset semRx
	call	_EnterCrit
	mov	bx,[RxHead]
	mov	eax,[bx].RFD.PhysAddr
	mov	gs:[Reg.RxDMAListPtr],eax
	mov	gs:[Reg.MACCtrl1],RxEnable or StatsEnable
	call	_LeaveCrit
;	pop	cx	; stack adjust

	mov	ax,iTxComplete or iRxDMAComplete or \
		  IntRequested or UpdateStats
	mov	[regIntMask],ax
	mov	gs:[Reg.IntEnable],ax

	mov	ax,SUCCESS
loc_ex:
	leave
	retn
_hwOpen		endp

_SetMacEnv	proc	near
	call	_SetTxEnv
	call	_SetRxEnv
	call	_SetMediumEnv
	retn
_SetMacEnv	endp

_SetTxEnv	proc	near
	mov	ax,[cfgTxStartThresh]
	mov	gs:[Reg.TxStartThr],ax

	mov	al,[cfgTxBurstThresh]
	mov	gs:[Reg.TxDMABurstThr],al

	mov	al,[cfgTxUrgentThresh]
	mov	gs:[Reg.TxDMAUrgentThr],al

	mov	al,[cfgTxPollPeriod]
	mov	gs:[Reg.TxDMAPollPeriod],al

	mov	al,[cfgTxReleaseThresh]
	mov	gs:[Reg.TxReleaseThr],al

	retn
_SetTxEnv	endp

_SetRxEnv	proc	near
	mov	ax,[cfgRxEarlyThresh]
	mov	gs:[Reg.RxEarlyThr],ax

	mov	al,[cfgRxBurstThresh]
	mov	gs:[Reg.RxDMABurstThr],al

	mov	al,[cfgRxUrgentThresh]
	mov	gs:[Reg.RxDMAUrgentThr],al

	mov	al,[cfgRxPollPeriod]
	mov	gs:[Reg.RxDMAPollPeriod],al

;	mov	eax,gs:[Reg.DMACtrl]
;	or	eax,RxEarlyEnable
;	and	eax,not RxDMAOverrun
;	mov	gs:[Reg.DMACtrl],eax
	mov	ax,word ptr gs:[Reg.DMACtrl][2]
	or	ax,highword RxEarlyEnable
	and	ax,not (highword RxDMAOverrun)
	mov	word ptr gs:[Reg.DMACtrl][2],ax

	retn
_SetRxEnv	endp

_ClearTxQueue	proc	near
	push	offset semTx
	call	_EnterCrit
	xor	ax,ax
	mov	cx,[TxHead]
	mov	dx,[TxTail]
	mov	[TxHead],ax
	mov	[TxTail],ax
	call	_LeaveCrit

	or	cx,cx
	jz	short loc_ex		; TX queue is clean
	enter	6,0
	mov	[bp-6],cx		; current
	mov	[bp-4],cx		; head
	mov	[bp-2],dx		; tail
loc_1:
	mov	bx,[bp-6]
	movzx	eax,[bx].TFD.TFDId
	shl	ax,2
	or	ax,TxIndicate or 1
	mov	[bx].TFD.TFC,eax
	mov	cx,[bx].TFD.ProtID
	mov	dx,[bx].TFD.ReqHandle
	mov	bx,[bx].TFD.vlink
	mov	[bp-6],bx
	test	dx,dx
	jz	short loc_2		; null request handle - no confirm
	mov	ax,[CommonChar.moduleID]
	mov	bx,[ProtDS]

	push	cx	; ProtID
	push	ax	; MACID
	push	dx	; ReqHandle
	push	0ffh	; Status
	push	bx	; ProtDS
	call	dword ptr [LowDisp.txconfirm]

	mov	gs,[MEMSel]	; fix gs selector
loc_2:
	cmp	word ptr [bp-6],0
	jnz	short loc_1

	mov	cx,[bp-4]
	mov	ax,[bp-2]
	leave

	call	_EnterCrit
	mov	bx,[TxFreeTail]
	mov	[bx].TFD.vlink,cx
	mov	[TxFreeTail],ax
	call	_LeaveCrit
loc_ex:
	pop	cx	; stack adjust
	retn
_ClearTxQueue	endp

_ClearRxQueue	proc	near
	push	di
	push	offset semRx
	call	_EnterCrit
	mov	bx,[RxHead]
	or	bx,bx
	jz	short loc_ex		; no RFD!?  This case never occur.
loc_1:
	cmp	bx,[RxTail]
	jz	short loc_2		; desc. tail
	mov	word ptr [bx].RFD.RFS,0	; clear RxDMAComplete bit
	mov	word ptr [bx].RFD.RFS[2],0
	mov	di,bx
	mov	bx,[bx].RFD.vlink
	mov	eax,[bx].RFD.PhysAddr
	mov	[di].RFD.NextPtr,eax	; physical link
	jmp	short loc_1
loc_2:
	mov	word ptr [bx].RFD.RFS,sRxDMAComplete	; terminate
	mov	word ptr [bx].RFD.RFS[2],0
	mov	word ptr [bx].RFD.vlink,0
	mov	[bx].RFD.NextPtr,0	; null link
loc_ex:
	call	_LeaveCrit
	pop	cx	; stack adjust
	pop	di
	retn
_ClearRxQueue	endp

_SetMediumEnv	proc	near
	xor	ax,ax
	cmp	[MediaDuplex],0		; half duplex?
	jz	short loc_1
	or	ax,FDXEnable
	test	[MediaPause],2		; rx pause?
	jz	short loc_1
	or	ax,FlowCtrlEnable
loc_1:
	mov	gs:[Reg.MACCtrl0],ax

	call	_SetSpeedStat
	retn
_SetMediumEnv	endp

_SetSpeedStat	proc	near
	mov	al,[MediaSpeed]
	mov	ah,0
	dec	ax
	jz	short loc_10M
	dec	ax
	jz	short loc_100M
;	dec	ax
;	jz	short loc_1G
	xor	ax,ax
	sub	cx,cx
	jmp	short loc_1
loc_10M:
	mov	cx,highword 10000000
	mov	ax,lowword  10000000
	jmp	short loc_1
loc_100M:
	mov	cx,highword 100000000
	mov	ax,lowword  100000000
;	jmp	short loc_1
loc_1G:
;	mov	cx,highword 1000000000
;	mov	ax,lowword  1000000000
loc_1:
	mov	word ptr [MacChar.linkspeed],ax
	mov	word ptr [MacChar.linkspeed][2],cx
	retn
_SetSpeedStat	endp


_ChkLink	proc	near
	push	miiBMSR
	push	[PhyInfo.Phyaddr]
	call	_miiRead
	and	ax,miiBMSR_LinkStat
	add	sp,2*2
	shr	ax,2
	retn
_ChkLink	endp


_AutoNegotiate	proc	near
	enter	2,0
	push	0
	push	miiBMCR
	push	[PhyInfo.Phyaddr]
	call	_miiWrite		; clear ANEnable bit
	add	sp,3*2

	push	33
	call	_Delay1ms
;	push	miiBMCR_ANEnable or miiBMCR_RestartAN
	push	miiBMCR_ANEnable	; remove restart bit??
	push	miiBMCR
	push	[PhyInfo.Phyaddr]
	call	_miiWrite		; restart Auto-Negotiation
	add	sp,(1+3)*2

	mov	word ptr [bp-2],12*30	; about 12sec.
loc_1:
	push	33
	call	_Delay1ms
	push	miiBMCR
	push	[PhyInfo.Phyaddr]
	call	_miiRead
	add	sp,(1+2)*2
	test	ax,miiBMCR_RestartAN	; AN in progress?
	jz	short loc_2
	dec	word ptr [bp-2]
	jnz	short loc_1
	jmp	short loc_f
loc_2:
	push	33
	call	_Delay1ms
	push	miiBMSR
	push	[PhyInfo.Phyaddr]
	call	_miiRead
	add	sp,(1+2)*2
	test	ax,miiBMSR_ANComp	; AN Base Page exchange complete?
	jnz	short loc_3
	dec	word ptr [bp-2]
	jnz	short loc_2
	jmp	short loc_f
loc_3:
	push	33
	call	_Delay1ms
	push	miiBMSR
	push	[PhyInfo.Phyaddr]
	call	_miiRead
	add	sp,(1+2)*2
	test	ax,miiBMSR_LinkStat	; link establish?
	jnz	short loc_4
	dec	word ptr [bp-2]
	jnz	short loc_3
loc_f:
	xor	ax,ax			; AN failure.
	xor	dx,dx
	leave
	retn
loc_4:
	call	_GetPhyMode
	leave
	retn
_AutoNegotiate	endp

_GetPhyMode	proc	near
	push	miiANLPAR
	push	[PhyInfo.Phyaddr]
	call	_miiRead		; read base page
	add	sp,2*2
	mov	[PhyInfo.ANLPAR],ax

	test	[PhyInfo.BMSR],miiBMSR_ExtStat
	jz	short loc_2

	push	mii1KSTSR
	push	[PhyInfo.Phyaddr]
	call	_miiRead
	add	sp,2*2
	mov	[PhyInfo.GSTSR],ax
;	shl	ax,2
;	and	ax,[PhyInfo.GSCR]
	shr	ax,2
	and	ax,[PhyInfo.GTCR]
;	test	ax,mii1KSCR_1KTFD
	test	ax,mii1KTCR_1KTFD
	jz	short loc_1
	mov	al,3			; media speed - 1000Mb
	mov	ah,1			; media duplex - full
	jmp	short loc_p
loc_1:
;	test	ax,mii1KSCR_1KTHD
	test	ax,mii1KTCR_1KTHD
	jz	short loc_2
	mov	al,3			; 1000Mb
	mov	ah,0			; half duplex
	jmp	short loc_p
loc_2:
	mov	ax,[PhyInfo.ANAR]
	and	ax,[PhyInfo.ANLPAR]
	test	ax,miiAN_100FD
	jz	short loc_3
	mov	al,2			; 100Mb
	mov	ah,1			; full duplex
	jmp	short loc_p
loc_3:
	test	ax,miiAN_100HD
	jz	short loc_4
	mov	al,2			; 100Mb
	mov	ah,0			; half duplex
	jmp	short loc_p
loc_4:
	test	ax,miiAN_10FD
	jz	short loc_5
	mov	al,1			; 10Mb
	mov	ah,1			; full duplex
	jmp	short loc_p
loc_5:
	test	ax,miiAN_10HD
	jz	short loc_e
	mov	al,1			; 10Mb
	mov	ah,0			; half duplex
	jmp	short loc_p
loc_e:
	xor	ax,ax
	sub	dx,dx
	retn
loc_p:
	cmp	ah,1			; full duplex?
	mov	dh,0
	jnz	short loc_np
	mov	cx,[PhyInfo.ANLPAR]
	test	cx,miiAN_PAUSE		; symmetry
	mov	dl,3			; tx/rx pause
	jnz	short loc_ex
	test	cx,miiAN_ASYPAUSE	; asymmetry
	mov	dl,2			; rx pause
	jnz	short loc_ex
loc_np:
	mov	dl,0			; no pause
loc_ex:
	retn
_GetPhyMode	endp


_ResetPhy	proc	near
	enter	2,0
;	call	_miiReset	; Reset Interface

	call	_SearchMedium
	cmp	ax,20h
	jc	short loc_2
loc_1:
	mov	ax,HARDWARE_FAILURE
	leave
	retn
loc_2:
	mov	[PhyInfo.Phyaddr],ax
	push	miiBMCR_Reset
	push	miiBMCR
	push	[PhyInfo.Phyaddr]
	call	_miiWrite	; Reset PHY
	add	sp,3*2

	push	1536		; wait for about 1.5sec.
	call	_Delay1ms
	pop	ax

;	call	_miiReset	; interface reset again
	mov	word ptr [bp-2],64  ; about 2sec.
loc_3:
	push	miiBMCR
	push	[PhyInfo.Phyaddr]
	call	_miiRead
	add	sp,2*2
	test	ax,miiBMCR_Reset
	jz	short loc_4
	push	33
	call	_Delay1ms	; wait reset complete.
	pop	ax
	dec	word ptr [bp-2]
	jnz	short loc_3
	jmp	short loc_1	; PHY Reset Failure
loc_4:
	push	miiBMSR
	push	[PhyInfo.Phyaddr]
	call	_miiRead
	add	sp,2*2
	mov	[PhyInfo.BMSR],ax
	push	miiANAR
	push	[PhyInfo.Phyaddr]
	call	_miiRead
	add	sp,2*2
	mov	[PhyInfo.ANAR],ax
	test	[PhyInfo.BMSR],miiBMSR_ExtStat
	jz	short loc_5	; extended status exist?
	push	mii1KTCR
	push	[PhyInfo.Phyaddr]
	call	_miiRead
	add	sp,2*2
	mov	[PhyInfo.GTCR],ax
	push	mii1KSCR
	push	[PhyInfo.Phyaddr]
	call	_miiRead
	add	sp,2*2
	mov	[PhyInfo.GSCR],ax
	xor	cx,cx
	test	ax,mii1KSCR_1KTFD or mii1KSCR_1KXFD
	jz	short loc_41
	or	cx,mii1KTCR_1KTFD
loc_41:
			; kill 1000BASE half-duplex advertisement
;	test	ax,mii1KSCR_1KTHD or mii1KSCR_1KXHD
;	jz	short loc_42
;	or	cx,mii1KTCR_1KTHD
loc_42:
	mov	ax,[PhyInfo.GTCR]
	and	ax,not (mii1KTCR_MSE or mii1KTCR_Port or \
		  mii1KTCR_1KTFD or mii1KTCR_1KTHD)
	or	ax,cx
	mov	[PhyInfo.GTCR],ax
	push	ax
	push	mii1KTCR
	push	[PhyInfo.Phyaddr]
	call	_miiWrite
	add	sp,2*2
loc_5:
	mov	ax,[PhyInfo.BMSR]
	mov	cx,miiAN_PAUSE
	test	ax,miiBMSR_100FD
	jz	short loc_61
	or	cx,miiAN_100FD
loc_61:
	test	ax,miiBMSR_100HD
	jz	short loc_62
	or	cx,miiAN_100HD
loc_62:
	test	ax,miiBMSR_10FD
	jz	short loc_63
	or	cx,miiAN_10FD
loc_63:
	test	ax,miiBMSR_10HD
	jz	short loc_64
	or	cx,miiAN_10HD
loc_64:
	mov	ax,[PhyInfo.ANAR]
	and	ax,not (miiAN_ASYPAUSE + miiAN_T4 + \
	  miiAN_100FD + miiAN_100HD + miiAN_10FD + miiAN_10HD)
	or	ax,cx
	mov	[PhyInfo.ANAR],ax
	push	ax
	push	miiANAR
	push	[PhyInfo.Phyaddr]
	call	_miiWrite
	add	sp,3*2
	mov	ax,SUCCESS
	leave
	retn

_SearchMedium	proc	near
	push	miiPHYID2
	push	0		; phyaddr [0..1f]
loc_1:
;	call	_miiReset
	call	_miiRead
	or	ax,ax		; ID2 = 0
	jz	short loc_next
	inc	ax		; ID2 = -1
	jnz	short loc_found
loc_next:
	pop	ax
	inc	ax		; next phyaddr
	cmp	al,20h
	push	ax
	jc	short loc_1
loc_found:
	pop	ax		; phyaddr checked
	pop	cx	; stack adjust
	retn
_SearchMedium	endp

_ResetPhy	endp


_hwUpdateMulticast	proc	near
	enter	10,0
	push	offset semFlt
	call	_EnterCrit
	push	di

	bt	[MacStatus.sstRxFilter],fltprms
	sbb	ax,ax
	mov	[bp-8],ax
	mov	[bp-6],ax
	mov	[bp-4],ax
	mov	[bp-2],ax

	mov	cx,[MCSTList.curnum]
	dec	cx
	jl	short loc_2
	mov	[bp-10],cx
loc_1:
	mov	ax,[bp-10]
	shl	ax,4		; 16bytes
	add	ax,offset MCSTList.multicastaddr1
	push	ax
	call	_CRC32
	and	ax,3fh		; the 6 least significant bits
	pop	dx	; stack adjust
	mov	di,ax
	mov	cx,ax
	shr	di,4
	and	cl,0fh		; the bit index in word
	mov	ax,1
	add	di,di		; the word index (2byte)
	shl	ax,cl
	or	word ptr [bp+di-8],ax
	dec	word ptr [bp-10]
	jge	short loc_1
loc_2:
	mov	di,[bp-8]
	mov	ax,[bp-6]
	mov	cx,[bp-4]
	mov	dx,[bp-2]
	mov	gs:[Reg.HashTable0],di
	mov	gs:[Reg.HashTable1],ax
	mov	gs:[Reg.HashTable2],cx
	mov	gs:[Reg.HashTable3],dx

	pop	di
	call	_LeaveCrit
;	pop	cx
	mov	ax,SUCCESS
	leave
	retn
_hwUpdateMulticast	endp

_CRC32		proc	near
POLYNOMIAL_be   equ  04C11DB7h
POLYNOMIAL_le   equ 0EDB88320h

	push	bp
	mov	bp,sp

	push	si
	push	di
	or	ax,-1
	mov	bx,[bp+4]
	mov	ch,3
	cwd

loc_1:
	mov	bp,[bx]
	mov	cl,10h
	inc	bx
loc_2:
IF 0
		; big endian

	ror	bp,1
	mov	si,dx
	xor	si,bp
	shl	ax,1
	rcl	dx,1
	sar	si,15
	mov	di,si
	and	si,highword POLYNOMIAL_be
	and	di,lowword POLYNOMIAL_be
ELSE
		; litte endian
	mov	si,ax
	ror	bp,1
	ror	si,1
	shr	dx,1
	rcr	ax,1
	xor	si,bp
	sar	si,15
	mov	di,si
	and	si,highword POLYNOMIAL_le
	and	di,lowword POLYNOMIAL_le
ENDIF
	xor	dx,si
	xor	ax,di
	dec	cl
	jnz	short loc_2
	inc	bx
	dec	ch
	jnz	short loc_1
	push	dx
	push	ax
	pop	eax
	pop	di
	pop	si
	pop	bp
	retn
_CRC32		endp

_hwUpdatePktFlt	proc	near
	push	offset semFlt
	call	_EnterCrit

	mov	cx,[MacStatus.sstRxFilter]
	xor	ax,ax

	test	cl,mask fltdirect
	jz	short loc_1
	or	al,ReceiveUnicast or ReceiveHash
loc_1:
	test	cl,mask fltbroad
	jz	short loc_2
	or	al,ReceiveBroad
loc_2:
	test	cl,mask fltprms
	jz	short loc_3
	or	al,ReceiveAll
loc_3:
	mov	gs:[Reg.ReceiveMode],al

	call	_LeaveCrit
	pop	cx
	mov	ax,SUCCESS
	retn
_hwUpdatePktFlt	endp

_hwSetMACaddr	proc	near
	push	si
	push	offset semFlt
	call	_EnterCrit

	mov	bx,offset MacChar.mctcsa
	mov	ax,[bx]
	mov	si,ax
	mov	cx,[bx+2]
	or	si,cx
	mov	dx,[bx+4]
	or	si,dx
	jnz	short loc_1		; current address may be good

	mov	si,offset MacChar.mctpsa
	mov	ax,[si]
	mov	cx,[si+2]
	mov	dx,[si+4]
	mov	[bx],ax			; copy parmanent address
	mov	[bx+2],cx
	mov	[bx+4],dx
loc_1:
	mov	gs:[Reg.StationAddr0],ax
	mov	gs:[Reg.StationAddr1],cx
	mov	gs:[Reg.StationAddr2],dx

	call	_LeaveCrit
	pop	cx
	pop	si
	mov	ax,SUCCESS
	retn
_hwSetMACaddr	endp

_hwUpdateStat	proc	near
	push	bp
	push	si
	push	di
	push	offset semStat
	call	_EnterCrit

	xor	bp,bp
	mov	di,offset MacStatus

	mov	ax,gs:[Reg.OctRxOk0]
	mov	cx,gs:[Reg.OctRxOk1]
	mov	dx,gs:[Reg.OctTxOk0]
	mov	bx,gs:[Reg.OctTxOk1]
	add	word ptr [di].mst.rxbyte,ax
	adc	word ptr [di].mst.rxbyte[2],cx
	add	word ptr [di].mst.txbyte,dx
	adc	word ptr [di].mst.txbyte[2],bx

	mov	ax,gs:[Reg.FrmTxOk]
	mov	cx,gs:[Reg.FrmRxOk]
	mov	dx,bp
	mov	bx,bp
	add	word ptr [di].mst.txframe,ax
	adc	word ptr [di].mst.txframe[2],bp
	add	word ptr [di].mst.rxframe,cx
	adc	word ptr [di].mst.rxframe[2],bp

	mov	dl,gs:[Reg.CRSErr]
	mov	bl,gs:[Reg.LateCol]
	mov	ax,bp
	mov	cx,bp
	mov	al,gs:[Reg.MultiCol]
	mov	cl,gs:[Reg.SingleCol]
	mov	dl,gs:[Reg.TxDeffer]
	mov	bl,gs:[Reg.RxLost]

	mov	al,gs:[Reg.TxExDeffer]
	mov	cl,gs:[Reg.AbortExCol]
	add	word ptr [di].mst.rxframebuf,bx
	adc	word ptr [di].mst.rxframebuf[2],bp
	add	word ptr [di].mst.txframeto,cx
	adc	word ptr [di].mst.txframeto[2],bp

	mov	al,gs:[Reg.BcstFrmTxOk]
	mov	cl,gs:[Reg.BcstFrmRxOk]
	mov	dl,gs:[Reg.McstFrmTxOk]
	mov	bl,gs:[Reg.McstFrmRxOk]
	add	word ptr [di].mst.txframebroad,ax
	adc	word ptr [di].mst.txframebroad[2],bp
	add	word ptr [di].mst.rxframebroad,cx
	adc	word ptr [di].mst.rxframebroad[2],bp
	add	word ptr [di].mst.txframemulti,dx
	adc	word ptr [di].mst.txframemulti[2],bp
	add	word ptr [di].mst.rxframemulti,bx
	adc	word ptr [di].mst.rxframemulti[2],bp

	call	_LeaveCrit
	mov	ax,SUCCESS
	pop	bp	; stack adjust
	pop	di
	pop	si
	pop	bp
	retn
_hwUpdateStat	endp

_hwClearStat	proc	near
	push	offset semStat
	call	_EnterCrit

	push	ds
	mov	ds,[MEMSel]
	mov	si,offset Reg.OctRxOk0
	mov	cx,(offset Reg.CRSErr - offset Reg.OctRxOk0)/2
	rep	lodsw
	mov	cx,offset Reg.McstFrmRxOk - offset Reg.CRSErr +1
	rep	lodsb
	pop	ds

	call	_LeaveCrit
	pop	cx	; stack adjust
	mov	ax,SUCCESS
	retn
_hwClearStat	endp

_hwClose	proc	near
	xor	ax,ax
	mov	[regIntMask],ax
	mov	gs:[Reg.IntEnable],ax
	dec	ax
	mov	gs:[Reg.IntStatus],ax

	mov	gs:[Reg.MACCtrl1],TxDisable or RxDisable or StatsDisable
	call	_hwUpdateStat
	call	_ClearTxQueue

	mov	ax,SUCCESS
	retn
_hwClose	endp

_hwReset	proc	near	; call in bind process
	enter	6,0

	mov	gs:[Reg.IntEnable],0
	mov	gs:[Reg.IntStatus],-1

;	mov	gs:[Reg.AsicCtrl],GlobalReset or DMA or FIFO or \
;		  Network or Host or AutoInit
	mov	word ptr gs:[Reg.AsicCtrl][2],highword(GlobalReset or\
		  DMA or FIFO or Network or Host or AutoInit)
	mov	word ptr [bp-2],32
loc_1:
	push	192
	call	_Delay1ms
	pop	cx
;	test	gs:[Reg.AsicCtrl],GlobalReset or DMA or FIFO or \
;		  Network or Host or AutoInit or ResetBusy
	test	word ptr gs:[Reg.AsicCtrl][2],highword (GlobalReset or\
		  DMA or FIFO or Network or Host or AutoInit or ResetBusy)
	jz	short loc_2
	dec	word ptr [bp-2]
	jnz	short loc_1		; reset timeout

	mov	ax,HARDWARE_FAILURE
	leave
	retn

loc_2:
	mov	gs:[Reg.IntEnable],0
	mov	gs:[Reg.IntStatus],-1
	mov	al,gs:[Reg.WakeEvent]	; clear WOL event
	mov	gs:[Reg.WakeEvent],0	; disable WOL

;	mov	eax,gs:[Reg.DMACtrl]
;	and	eax,not(MWIDisable or RxDMAOverrun)
;	or	eax,RxEarlyEnable
	mov	ax,word ptr gs:[Reg.DMACtrl][2]
	and	ax,not highword (MWIDisable or RxDMAOverrun)
	or	ax,highword RxEarlyEnable
	cmp	[CacheLine],0
	jnz	short loc_3
;	or	eax,MWIDisable
	or	ax,highword MWIDisable
loc_3:
;	mov	gs:[Reg.DMACtrl],eax
	mov	word ptr gs:[Reg.DMACtrl][2],ax

	mov	ax,[cfgMAXFRAMESIZE]	; 1514 only
	mov	gs:[Reg.MaxFrameSize],ax

	push	10h		; station address 0
	call	_eepRead
	mov	[bp-6],ax
	push	11h		; 1
	call	_eepRead
	mov	[bp-4],ax
	push	12h		; 2
	call	_eepRead
	mov	[bp-2],ax

	push	offset semFlt
	call	_EnterCrit
	mov	ax,[bp-6]
	mov	cx,[bp-4]
	mov	dx,[bp-2]
	mov	word ptr MacChar.mctpsa,ax	; parmanent
	mov	word ptr MacChar.mctpsa[2],cx
	mov	word ptr MacChar.mctpsa[4],dx
;	mov	word ptr MacChar.mctcsa,ax	; current
;	mov	word ptr MacChar.mctcsa[2],cx
;	mov	word ptr MacChar.mctcsa[4],dx
	mov	word ptr MacChar.mctVendorCode,ax ; vendor
	mov	byte ptr MacChar.mctVendorCode[2],cl
	call	_LeaveCrit
;	add	sp,(3+1)*2

	call	_hwSetMACaddr
;	call	_hwUpdatePktFlt
;	call	_hwUpdateMulticast
;	call	_hwClearStat

	call	_ResetPhy

	leave
	retn
_hwReset	endp

_hwSetupWoL	proc	near
	enter	2,0
	mov	gs:[Reg.MACCtrl1],TxDisable or RxDisable or StatsDisable
	mov	word ptr [bp-2],384
loc_1:
	test	gs:[Reg.MACCtrl1],TxEnabled or RxEnabled ; tx/rx stop?
	jz	short loc_2
	push	4
	call	__IODelayCnt
	pop	ax
	dec	word ptr [bp-2]
	jnz	short loc_1

loc_2:
	mov	word ptr gs:[Reg.AsicCtrl][2],highword \
		  (RxReset or TxReset or DMA or FIFO or Network)
	mov	word ptr [bp-2],384
loc_3:
	test	word ptr gs:[Reg.AsicCtrl][2],highword (ResetBusy or\
		  RxReset or TxReset or DMA or FIFO or Network)
	jz	short loc_4
	push	4
	call	__IODelayCnt
	pop	ax
	dec	word ptr [bp-2]
	jnz	short loc_3

loc_4:
	mov	gs:[Reg.ReceiveMode], ReceiveUnicast or ReceiveBroad or\
		  ReceiveIPMult		; accept type

	mov	al,gs:[Reg.WakeEvent]	; clear
	mov	gs:[Reg.WakeEvent],MagicPktEnable or WakeOnLanEnable
	mov	gs:[Reg.MACCtrl1],RxEnable

	movzx	ax,[PPMaddr]
	cmp	ax,40h
	jc	short loc_5		; invalid address
	add	ax,4
	push	ax
	push	[BusDevFunc]
	call	_pci0ReadD
;	add	sp,2*2
	movzx	cx,[PPMaddr]
	or	ax,8103h	; clear status, set pme enable and D3
	add	cx,4
	push	dx
	push	ax
	push	cx
	push	[BusDevFunc]
	call	_pci0WriteD
;	add	sp,4*2
loc_5:
	leave
	retn
_hwSetupWoL	endp

; USHORT miiRead( UCHAR phyaddr, UCHAR phyreg)
_miiRead	proc	near
	push	bp
	mov	bp,sp
	push	offset semMii
	call	_EnterCrit

	call	_miiReset

	push	1
	mov	bx,offset Reg.PhyCtrl
	mov	al,gs:[bx]
	and	al,not(MgmtClk or MgmtData or MgmtDir)
	mov	ah,al

	or	al,MgmtData or MgmtDir
	mov	gs:[bx],al
	call	__IODelayCnt
	or	al,MgmtClk
	mov	gs:[bx],al		; idle
	call	__IODelayCnt

	mov	dl,[bp+4]	; phyaddr (5bit)
	mov	cl,[bp+6]	; phyreg  (5bit)
	shl	dx,5
	and	cx,1fh
	and	dx,1fh shl 5
	or	cx,0110b shl 10	; start(01) +opcode(10)
	or	dx,cx
	mov	cx,2+2+5+5-1

loc_1:
	bt	dx,cx
	sbb	al,al
	and	al,MgmtData
	or	al,ah
	or	al,MgmtDir
	mov	gs:[bx],al
	call	__IODelayCnt
	or	al,MgmtClk
	mov	gs:[bx],al
	call	__IODelayCnt
	dec	cx
	jge	short loc_1

	mov	al,ah
	mov	gs:[bx],al	; TA(z0)
	call	__IODelayCnt
	or	al,MgmtClk
	mov	gs:[bx],al
	call	__IODelayCnt

	mov	cx,16
loc_2:
	mov	al,ah
	mov	gs:[bx],al
	call	__IODelayCnt
	or	al,MgmtClk
	mov	gs:[bx],al
	call	__IODelayCnt
	mov	al,gs:[bx]
	bt	ax,1		; MgmtData bit
	rcl	dx,1
	dec	cx
	jnz	short loc_2

	mov	al,ah
	mov	gs:[bx],al	; idle
	call	__IODelayCnt
	or	al,MgmtClk
	mov	gs:[bx],al
	call	__IODelayCnt

	pop	cx	; stack adjust
	mov	ax,dx		; data
	call	_LeaveCrit
	leave
	retn
_miiRead	endp

; VOID miiWrite( UCHAR phyaddr, UCHAR phyreg, USHORT value)
_miiWrite	proc	near
	push	bp
	mov	bp,sp
	push	offset semMii
	call	_EnterCrit

	call	_miiReset

	push	1
	mov	bx,offset Reg.PhyCtrl
	mov	al,gs:[bx]
	and	al,not(MgmtClk or MgmtData or MgmtDir)
	mov	ah,al

	or	al,MgmtData or MgmtDir
	mov	gs:[bx],al
	call	__IODelayCnt
	or	al,MgmtClk
	mov	gs:[bx],al	; idle
	call	__IODelayCnt

	mov	dl,[bp+4]	; phyaddr (5bit)
	mov	cl,[bp+6]	; phyreg  (5bit)
	shl	dx,5+2
	and	cx,1fh
	and	dx,1fh shl (5+2)
	shl	cx,2
	or	dx,cx
	or	dx,0101000000000010b  ; start(01) +opecode(01) +TA(10)
	mov	cx,2+2+5+5+2-1

loc_1:
	bt	dx,cx
	sbb	al,al		; 0 / -1
	and	al,MgmtData	; 0 / 2
	or	al,MgmtDir
	or	al,ah
	mov	gs:[bx],al
	call	__IODelayCnt
	or	al,MgmtClk
	mov	gs:[bx],al
	call	__IODelayCnt
	dec	cx
	jge	short loc_1

	mov	dx,[bp+8]	; write value
	mov	cx,16-1
loc_2:
	bt	dx,cx
	sbb	al,al
	and	al,MgmtData
	or	al,MgmtDir
	or	al,ah
	mov	gs:[bx],al
	call	__IODelayCnt
	or	al,MgmtClk
	mov	gs:[bx],al
	call	__IODelayCnt
	dec	cx
	jge	short loc_2

	mov	al,ah
	or	al,MgmtData or MgmtDir
	mov	gs:[bx],al
	call	__IODelayCnt
	or	al,MgmtClk
	mov	gs:[bx],al	; idle
	call	__IODelayCnt

	pop	cx	; stack adjust
	call	_LeaveCrit
	leave
	retn
_miiWrite	endp

; call from _miiRead and _miiWrite
; I don't understand why the MII interface reset is need at each access.
; uzai kedo, wake wakame... 
; VOID miiReset( VOID )
_miiReset	proc	near
;	push	offset semMii
;	call	_EnterCrit
	push	1
	mov	cx,32*2		; 32clocks high

	mov	bx,offset Reg.PhyCtrl
	mov	al,gs:[bx]

	or	al,MgmtData or MgmtDir
	and	al,not MgmtClk
loc_1:
	mov	gs:[bx],al
	call	__IODelayCnt
	xor	al,MgmtClk
	dec	cx
	jnz	short loc_1

	pop	ax	; stack adjust
;	call	_LeaveCrit
;	pop	ax
	retn
_miiReset	endp

; USHORT eepRead( UCHAR addr )
_eepRead	proc	near
	push	bp
	mov	bp,sp

	mov	cx,64
	push	2
loc_1:
	mov	ax,gs:[Reg.EepromCtrl]
	test	ax,EepromBusy		; busy?
	jz	short loc_2
	call	__IODelayCnt
	dec	cx			; timeout
	jnz	short loc_1

loc_2:
	mov	al,[bp+4]		; address
	mov	ah,high EepromOpcode_Read  ; opcode Read
	and	al,3fh			; address mask
	mov	gs:[Reg.EepromCtrl],ax

	mov	cx,128
loc_3:
	call	__IODelayCnt
	mov	ax,gs:[Reg.EepromCtrl]
	test	ax,EepromBusy		; read complete?
	jz	short loc_4
	dec	cx			; timeout
	jnz	short loc_3

loc_4:
	mov	ax,gs:[Reg.EepromData]
	pop	cx	; stack adjust

	pop	bp
	retn
_eepRead	endp


_TEXT	ends
end
