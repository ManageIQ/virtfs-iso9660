require 'rufus-lru'

module VirtFS::ISO9660
  class FS
    attr_accessor :mount_point, :blk_device

    def self.match?(blk_device)
      blk_device.seek(SUPER_OFFSET + MAGIC_OFFSET)
      blk_device.read(MAGIC_SIZE) == MAGIC
    end

    def thin_interface?
      true
    end

    def initialize(blk_device)
      @blk_device   = blk_device
      validate_boot_sector!
    end

    def umount
      @mount_point = nil
    end

    def joliet_boot_sector
      @joliet_boot_sector ||= begin
        begin
          blk_device.seek(JOLIET_SECTOR * SECTOR_SIZE)
          JolietBootSector.new(blk_device)
        rescue
          nil
        end
      end
    end

    def joliet?
      @joliet ||= !joliet_boot_sector.nil?
    end

    def primary_boot_sector
      @primary_boot_sector ||= begin
        begin
          blk_device.seek(PRIMARY_SECTOR * SECTOR_SIZE)
          PrimaryBootSector.new(blk_device)
        rescue
          nil
        end
      end
    end

    def primary?
      @primary ||= !primary_boot_sector.nil?
    end

    def boot_sector?
      joliet? || primary?
    end

    def boot_sector
      @boot_sector ||= joliet_boot_sector || primary_boot_sector
    end

    def validate_boot_sector!
      raise "Couldn't find boot sector" unless boot_sector?
    end

    def dir_cache
      @dir_cache ||= LruHash.new(DEF_CACHE_SIZE)
    end

    def cache_hits
      @cache_hits ||= 0
    end

    def cache_hits=(val)
      @cache_hits = val
    end

    def drive_root_entry
      @drive_root_entry ||= DirectoryEntry.new(boot_sector.root_dir_record, boot_sector.suffix, self)
    end

    def drive_root
      @drive_root ||= Directory.new(boot_sector, drive_root_entry, self)
    end

    # Wack leading drive leter & colon.
    def unnormalize_path(p)
      p[1] == 58 ? p[2, p.size] : p
    end
  end # class FS
end # module VirtFS::ISO9660
