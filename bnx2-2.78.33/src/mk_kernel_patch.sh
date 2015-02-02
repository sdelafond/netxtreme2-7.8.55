#!/bin/sh
# Copyright (c) 2008-2012 Broadcom Corporation

if [ $# -lt 1 ]; then
	echo "$0: No kernel version provided." 1>&2
	KVER=$(uname -r)
	echo "$0: Using $KVER." 1>&2
else
	KVER=$1
fi

KSRC="/lib/modules/$KVER/source"

if [ -e "$KSRC/drivers/net/ethernet/broadcom" ]; then
	BSRC="$KSRC/drivers/net/ethernet/broadcom/"
	ALOCAL="a/drivers/net/ethernet/broadcom"
	BLOCAL="b/drivers/net/ethernet/broadcom"
elif [ -e "$KSRC/drivers/net" ]; then
	BSRC="$KSRC/drivers/net/"
	ALOCAL="a/drivers/net/"
	BLOCAL="b/drivers/net/"
else
	echo "$0: kernel tree not found." 1>&2
	exit 255
fi

UAPI=
if [ -d $srcdir/include/uapi ]
then
	UAPI=uapi
fi

mkdir -p $ALOCAL
mkdir -p $BLOCAL

cp $BSRC/bnx2.[ch] $ALOCAL
cp $BSRC/bnx2_fw*.h $ALOCAL
cp bnx2.[ch] $BLOCAL
cp bnx2_fw*.h $BLOCAL
cp bnx2_compat*.h $BLOCAL

if grep -q "skb_transport_offset" $KSRC/include/linux/skbuff.h ; then
  echo "#define NEW_SKB" > $BLOCAL/bnx2_compat00.h
fi

if grep -q "static inline struct iphdr \*ip_hdr" $KSRC/include/linux/ip.h ; then
  echo "#define HAVE_IP_HDR" >> $BLOCAL/bnx2_compat00.h
fi

if grep -q "__le32" $KSRC/include/$UAPI/linux/types.h ; then
  echo "#define HAVE_LE32" >> $BLOCAL/bnx2_compat00.h
fi

if grep -q "gfp_t" $KSRC/include/linux/types.h ; then
  echo "#define HAVE_GFP" >> $BLOCAL/bnx2_compat00.h
elif grep -q "gfp_t" $KSRC/include/linux/gfp.h ; then
  echo "#define HAVE_GFP" >> $BLOCAL/bnx2_compat00.h
fi

if grep -q "bool" $KSRC/include/linux/types.h ; then
  echo "#define HAVE_BOOL" >> $BLOCAL/bnx2_compat00.h
fi

if [ -e $KSRC/include/linux/aer.h ] ; then
  echo "#define HAVE_AER" >> $BLOCAL/bnx2_compat00.h
fi

if grep -q "dev_err" $KSRC/include/linux/device.h ; then
  echo "#define HAVE_DEV_ERR" >> $BLOCAL/bnx2_compat00.h
fi

if grep -q "dev_printk" $KSRC/include/linux/device.h ; then
  echo "#define HAVE_DEV_PRINTK" >> $BLOCAL/bnx2_compat00.h
fi

if grep -q "netif_set_real_num_tx" $KSRC/include/linux/netdevice.h ; then
  echo "#define HAVE_REAL_TX" >> $BLOCAL/bnx2_compat00.h
fi

if grep -q "netif_set_real_num_rx" $KSRC/include/linux/netdevice.h ; then
  echo "#define HAVE_REAL_RX" >> $BLOCAL/bnx2_compat00.h
fi

if grep -q "ndo_vlan_rx_register" $KSRC/include/linux/netdevice.h ; then
  echo "#define HAVE_NDO_VLAN_RX_REGISTER" >> $BLOCAL/bnx2_compat00.h
fi

if grep -q "ndo_fix_features" $KSRC/include/linux/netdevice.h ; then
  echo "#define HAVE_FIX_FEATURES" >> $BLOCAL/bnx2_compat00.h
fi

if grep -q "netdev_features_t" $KSRC/include/linux/netdevice.h ; then
  echo "#define HAVE_NETDEV_FEATURES" >> $BLOCAL/bnx2_compat00.h
fi

if ! grep -q "ethtool_op_get_tx_csum" $KSRC/include/$UAPI/linux/ethtool.h ; then
  echo "#define NEW_ETHTOOL" >> $BLOCAL/bnx2_compat00.h
fi

if grep -q "skb_frag_size" $KSRC/include/linux/skbuff.h ; then
  echo "#define HAVE_SKB_FRAG" >> $BLOCAL/bnx2_compat00.h
fi

if grep -q "skb_frag_page" $KSRC/include/linux/skbuff.h ; then
  echo "#define HAVE_SKB_FRAG_PAGE" >> $BLOCAL/bnx2_compat00.h
fi

if grep -q "ethtool_adv_to_mii_adv_t" $KSRC/include/linux/mii.h ; then
  echo "#define HAVE_ETHTOOL_TO_MII" >> $BLOCAL/bnx2_compat00.h
fi

if grep -q "pci_is_pcie" $KSRC/include/linux/pci.h ; then
  echo "#define HAVE_IS_PCIE" >> $BLOCAL/bnx2_compat00.h
fi

if grep -q "device_set_wakeup_capable" $KSRC/include/linux/pm*.h ; then
  echo "#define HAVE_DEVICE_SET_WAKEUP_CAP" >> $BLOCAL/bnx2_compat00.h
fi

if grep -q "pci_pme_capable" $KSRC/include/linux/pci.h ; then
  echo "#define HAVE_PCI_PME_CAPABLE" >> $BLOCAL/bnx2_compat00.h
fi

if grep -q "pci_wake_from_d3" $KSRC/include/linux/pci.h ; then
  echo "#define HAVE_PCI_WAKE_FROM_D3" >> $BLOCAL/bnx2_compat00.h
fi

sed -e 's/#define BCM_CNIC 1//' \
    -e 's/#include "cnic_if.h"//' \
    -e '/#include <linux\/version.h>/ a\
#include "bnx2_compat00.h"
' < bnx2.c > $BLOCAL/bnx2.c

diff -Nrup a b > bnx2-$KVER.patch

rm -rf a b
