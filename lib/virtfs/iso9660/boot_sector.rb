require 'sys-uname'

module VirtFS::ISO9660
  class BootSector
    attr_accessor :bs, :blk_device

    def initialize(blk_device)
      raise "block device cannot be nil" if blk_device.nil?
      self.blk_device = blk_device
      self.bs = VOLUME_DESCRIPTOR.decode(blk_device.read(SIZEOF_VOLUME_DESCRIPTOR))
      validate_boot_sector!
    end

    def suffix
      @suffix ||= Sys::Platform::ARCH == :x86 ? arch_suffix : non_arch_suffix
    end

    def arch_suffix
      'LE'
    end

    def non_arch_suffix
      # Other architectures are bi-endian and must be determined at run time.
      [0xaa, 0x55].pack('N').unpack('L') == 0xaa55 ? 'BE' : 'LE'
    end

    def sector_size
      @sector_size ||= bs["log_block_size#{suffix}"]
    end

    def volume_id
      @volume_id ||= begin
        vi = bs['volume_id']
        vi.Ucs2ToAscii! if joilet?
        vi
      end
    end

    def desc_type
      @desc_type ||= bs['desc_type']
    end

    def valid_desc_type?
      desc_type == self.class.desc_type
    end

    def id
      @id ||= bs['id']
    end

    def valid_id?
      id == "CD001"
    end

    def version
      @version ||= bs['version']
    end

    def valid_version?
      version == 1
    end

    def file_structure_version
      @fsv ||= bs['file_structure_version']
    end

    def valid_file_structure_version?
      file_structure_version == 1
    end

    def c_time
      @c_time ||= Util.IsoToRubyDate(bs['creation_date'])
    end

    def m_time
      @m_time ||= Util.IsoToRubyDate(bs['modification_date'])
    end

    def expiration_date
      @expiration_date ||= Util.IsoToRubyDate(bs['expiration_date'])
    end

    def effective_date
      @effective_date  ||= Util.IsoToRubyDate(bs['effective_date'])
    end

    def root_dir_record
      @root_dir_record ||= bs['root_dir_record']
    end

    def validate_boot_sector!
      raise "Descriptor type mismatch (type is #{desc_type})" unless valid_desc_type?
      raise "Descriptor ID mismatch"                          unless valid_id?
      raise "Descriptor version mismatch"                     unless valid_version?
      raise "File structure version mismatch"                 unless valid_file_structure_version?
    end

    def sectors(sector, num = 1)
      blk_device.seek(sector * sector_size)
      blk_device.read(sector_size * num)
    end
  end # class BootSector

  class JolietBootSector < BootSector
    def joliet?
      true
    end

    def self.desc_type
      TYPE_SUPP_DESC
    end
  end

  class PrimaryBootSector < BootSector
    def joliet?
      false
    end

    def self.desc_type
      TYPE_PRIM_DESC
    end
  end # class BootSector
end # module VirtFS::ISO9660
