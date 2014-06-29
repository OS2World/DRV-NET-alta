; --- PCI access in ring 0 via OEMHLP$ IDC definition
extern	OEMHLP_Entry : dword
extern	OEMHLP_DS : word

extern	_pci0ReadD : near
extern	_pci0WriteD : near
