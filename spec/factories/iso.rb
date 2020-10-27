require 'ostruct'
require 'virtfs/block_io'
require 'virt_disk/block_file'

FactoryBot.define do
  factory :iso, class: OpenStruct do
    path '/var/lib/oz/isos/Fedora22x86_64-url.iso'
    fs { VirtFS::ISO9660::FS.new(VirtFS::BlockIO.new(VirtDisk::BlockFile.new(path))) }
    root_dir ['EFI', 'IMAGES', 'ISOLINUX', 'LIVEOS']
    glob_dir ['EFI/BOOT', 'IMAGES/EFIBOOT.IMG;1', 'IMAGES/MACBOOT.IMG;1', 'IMAGES/PRODUCT.IMG;1', 'IMAGES/PXEBOOT', 'IMAGES/TRANS.TBL;1', 'ISOLINUX/BOOT.CAT;1', 'ISOLINUX/BOOT.MSG;1', 'ISOLINUX/GRUB.CON;1', 'ISOLINUX/INITRD.IMG;1', 'ISOLINUX/ISOLINUX.BIN;1', 'ISOLINUX/ISOLINUX.CFG;1', 'ISOLINUX/LDLINUX.C32;1', 'ISOLINUX/LIBCOM32.C32;1', 'ISOLINUX/LIBUTIL.C32;1', 'ISOLINUX/MEMTEST.;1', 'ISOLINUX/SPLASH.PNG;1', 'ISOLINUX/TRANS.TBL;1', 'ISOLINUX/UPGRADE.IMG;1', 'ISOLINUX/VESAMENU.C32;1', 'LIVEOS/SQUASHFS.IMG;1', 'LIVEOS/TRANS.TBL;1']
    boot_size 2048
  end
end
