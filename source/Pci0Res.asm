; --- PCI access in ring 0 via OEMHLP$ IDC

include	devpac.inc
include	OEMHelp.inc

.386

_DATA	segment	public word use16 'DATA'
public	OEMHLP_Entry, OEMHLP_DS
OEMHLP_Entry	dd	?
OEMHLP_DS	dw	?
_DATA	ends

_TEXT	segment	public word use16 'CODE'
	assume	ds:_DATA

; ULONG pci0ReadD(USHORT BusDevFunc, UCHAR RegAdr);
_pci0ReadD	proc	near
	enter	10,0
	mov	ax,[bp+4]	; Bus/Device/Function Number
	mov	cl,[bp+6]	; Register Address
	mov	byte ptr [bp-5],PCI_ReadConfigSpace	; 3
	mov	[bp-4],ax
	mov	[bp-2],cl
	mov	byte ptr [bp-1],4	; 04:dword
	mov	ax,sp
	lea	bx,[bp-5]
	push	ss
	push	ax
	push	ss
	push	bx
	call	_IDC_OEMHLP
;	add	sp,4*2
	cmp	ax,100h
	jnz	short loc_err
	cmp	[bp-10].D_PCI_ReadConfigSpace.rc,al	; 0
	jnz	short loc_err
	mov	eax,[bp-10].D_PCI_ReadConfigSpace.Data
	mov	dx,word ptr [bp-10].D_PCI_ReadConfigSpace.Data[2]
	leave
	retn
loc_err:
	or	eax,-1
	or	dx,-1
	leave
	retn
_pci0ReadD	endp

; VOID pci0WriteD(USHORT BusDevFunc, UCHAR RegAdr, ULONG data);
_pci0WriteD	proc	near
	enter	10,0
	mov	ax,[bp+4]	; Bus/Device/Function Number
	mov	cl,[bp+6]	; Register Address
	mov	dx,[bp+8]	; Register Data
	mov	bx,[bp+10]
	mov	byte ptr [bp-9],PCI_WriteConfigSpace	; 4
	mov	[bp-8],ax
	mov	[bp-6],cl
	mov	byte ptr [bp-5],4	; 04:dword
	mov	[bp-4],dx
	mov	[bp-2],bx
	mov	ax,sp
	push	ss
	push	ax
	inc	ax
	push	ss
	push	ax
	call	_IDC_OEMHLP
;	add	sp,4*2
	cmp	ax,100h
	jnz	short loc_err
	mov	al,[bp-10].D_PCI_ReadConfigSpace.rc
loc_err:
	leave
	retn
_pci0WriteD	endp


; USHORT IDC_OEMHLP(VOID far *parm, VOID far *data);
_IDC_OEMHLP	proc	near
	enter	30,0
	xor	ax,ax
	mov	[bp-30]._RPH.Len,29
	mov	[bp-30]._RPH.Unit,al
	mov	[bp-30]._RPH.Cmd,CMDGenIOCTL
	mov	[bp-30]._RPH.Status,ax
	mov	word ptr [bp-30]._RPH.Flag,ax
	mov	word ptr [bp-30]._RPH.Flag[2],ax
	mov	word ptr [bp-30]._RPH.Link,ax
	mov	word ptr [bp-30]._RPH.Link[2],ax
	mov	[bp-30]._RP_GENIOCTL2.sfn,ax	; unknown
	mov	[bp-30]._RP_GENIOCTL2.ParmLen,ax ; unknown length
	mov	[bp-30]._RP_GENIOCTL2.DataLen,ax ; unknown length
	mov	[bp-30]._RP_GENIOCTL2.Category,IOCTL_OEMHLP ; 80h
	mov	[bp-30]._RP_GENIOCTL2.Function,OEMHLP_PCI ; 0bh
	mov	ax,[bp+4]
	mov	cx,[bp+6]
	mov	dx,[bp+8]
	mov	bx,[bp+10]
	mov	word ptr [bp-30]._RP_GENIOCTL2.ParmPacket,ax
	mov	word ptr [bp-30]._RP_GENIOCTL2.ParmPacket[2],cx
	mov	word ptr [bp-30]._RP_GENIOCTL2.DataPacket,dx
	mov	word ptr [bp-30]._RP_GENIOCTL2.DataPacket[2],bx
	mov	ax,ss
	mov	cx,ds
	mov	bx,sp
	push	gs
	push	cx
	push	si
	push	di
	push	bp
	mov	es,ax
	mov	gs,cx
	mov	ds,[OEMHLP_DS]
	call	dword ptr gs:[OEMHLP_Entry]
	pop	bp
	pop	di
	pop	si
	pop	ds
	pop	gs
	mov	ax,[bp-30]._RPH.Status
	leave
	retn
_IDC_OEMHLP	endp

_TEXT	ends

end
