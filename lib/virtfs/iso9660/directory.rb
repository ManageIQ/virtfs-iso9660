module VirtFS::ISO9660
  class Directory
    attr_accessor :fs, :bs, :dir_entry

    def initialize(bs, dir_entry, fs)
      raise "Boot sector is nil"                  if bs.nil?
      raise "No directory entry specified"        if dir_entry.nil?
      raise "Given entry is not a DirectoryEntry" unless dir_entry.is_a?(VirtFS::ISO9660::DirectoryEntry)

      self.bs        = bs
      self.dir_entry = dir_entry
      self.fs        = fs

      extract_rock_ridge(DirectoryEntry.new(dir_data, @bs.suffix, fs))
    end

    def close
    end

    def read(pos)
      return cache[pos], pos + 1
    end

    def dir_data
      @dir_data ||= bs.sectors(dir_entry.file_start, dir_entry.file_size / bs.sector_size)
    end

    def glob_names
      @glob_names ||= glob_entries.collect { |de| de.name }
    end

    def find_entry(name, _flags = FE_EITHER)
      # TODO: enable flags
      # Joliet & RR are case sensitive
      # ISO 9660 is ucase only.
      glob_entries.find { |de| [name, name.upcase].include?(de.name) }
    end

    def entries_flags
      @entries_flags ||= begin
        flags  = EXT_NONE
        flags |= EXT_JOLIET    if bs.joliet?
        flags |= EXT_ROCKRIDGE if rock_ridge?
        flags
      end
    end

    def glob_entries
      offset  = 0
      entries = []
      loop do
        de = DirectoryEntry.new(dir_data[offset..-1], bs.suffix, fs, entries_flags)
        break if de.length == 0
        entries << de
        offset += de.length
      end
      entries
    end

    def rock_ridge?
      !@susp.nil?
    end

    def extract_rock_ridge(de)
      return nil unless de.sua
      @susp = SUSP.decode(de.sua)
      return nil                                           if @susp['signature'] != SUSP_SIGNATURE
      return nil                                           if @susp['len']       != SUSP_SIZE
      return nil                                           if @susp['check']     != SUSP_CHECK_WORD
      raise "System Use Sharing Protocol version mismatch" if @susp['version']   != SUSP_VERSION
    end

    private

    def cache
      @cache ||= glob_entries.to_a
    end
  end # class Directory
end # module VirtFS::ISO9660
