module VirtFS::ISO9660
  class File
    def initialize(dir_entry, boot_sector)
      raise "nil directory entry" if dir_entry.nil?
      raise "nil boot sector"     if boot_sector.nil?

      @bs = boot_sector
      @de = dir_entry

      rewind
    end

    def last_sector
      @last_sector ||= begin
        ls = @de.fileSize.divmod(@bs.sectorSize)
        ls[0] += 1 if ls[1] > 0
        ls[0]
      end
    end

    def rewind
      @pos = 0
    end

    def seek(offset, method = IO::SEEK_SET)
      @pos = case method
             when IO::SEEK_SET then offset
             when IO::SEEK_CUR then @pos + offset
             when IO::SEEK_END then @de.length - offset
             end
      @pos = 0 if @pos < 0
      @pos = @de.file_size if @pos > @de.file_size
      @pos
    end

    def read(bytes = @de.file_size)
      return nil if @pos >= @de.file_size
      bytes = @de.file_size - @pos if @pos + bytes > @de.file_size

      # Get start & end locs.
      ss = @bs.sector_size
      start_sector, start_offset = @pos.divmod(ss)
      end_sector, end_offset = (@pos + (bytes - 1)).divmod(ss)

      # Single sector.
      if start_sector == end_sector
        @pos += (end_offset - start_offset)
        return get_sector(start_sector)[start_offset..end_offset]
      end

      # Span sectors.
      out = MemoryBuffer.create(bytes)
      total_len = 0
      (start_sector..end_sector).each do |sect|
        offset = 0; len = ss
        if sect == start_sector
          offset = start_offset
          len -= offset
        end
        len -= (ss - (end_offset + 1)) if sect == end_sector
        out[total_len, len] = get_sector(sect)[offset, len]
        total_len += len
        @pos += len
      end
      out[0..total_len]
    end

    def get_sector(vsn)
      lsn = get_lsn(vsn)
      raise "No logical sector for virtual sector #{vsn}." if lsn == -1
      @bs.sectors(lsn, 1)
    end

    def get_lsn(vsn)
      return -1 if vsn > last_sect
      @de.file_start + vsn
    end

    def to_h
      { :directory? => @de.dir?,
        :file?      => @de.file?,
        :symlink?   => @de.symlink? }
    end
  end # class File
end # module VirtFS::ISO9660
