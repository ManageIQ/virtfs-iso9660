module VirtFS::ISO9660
  class DirectoryEntry
    attr_accessor :data, :suffix, :fs, :flags

    def close
    end

    def de
      @de ||= DIR_ENT.decode(data)
    end

    def length
      @length ||= de['length']
    end

    def entry
      @entry ||= data[0...length]
    end

    def date
      @date ||= Util.IsoShortToRubyDate(de['date'])
    end

    alias :atime :date
    alias :ctime :date
    alias :mtime :date

    def chmod(mode)
      raise "writes not supported"
    end

    def chown(owner, group)
      raise "writes not supported"
    end

    def truncate(len)
      raise "writes not supported"
    end

    def name_len
      @name_len ||= de['name_len']
    end

    def file_start
      @file_start ||= de["extent#{suffix}"]
    end

    def name_offset
      @name_offset ||= SIZEOF_DIR_ENT
    end

    def has_name?
      name_len > 0
    end

    def name_data
      data[name_offset...(name_offset + name_len)]
    end

    def name
      @name ||= convert_name(name_data) if has_name?
    end

    def is_single_dot(name)
      name[0].ord == 0
    end

    def is_double_dot(name)
      name[0].ord == 1
    end

    def is_dot(name)
      is_single_dot(name) || is_double_dot(name)
    end

    def convert_name(name)
      if name_len == 1 && is_dot(name)
        return "."  if is_single_dot(name)
        return ".." if is_double_dot(name)

      elsif joliet?
        return name.Ucs2ToAscii
      end

      name
    end

    def sua_offset
      @sua_offset ||= name_offset + name_len + (even? ? 1 : 0)
    end

    def sua_data
      data[sua_offset...length-1]
    end

    def has_sua?
      sua_offset < length
    end

    def sua
      @sua ||= sua_data if has_sua?
    end

    def file?
      de['flags'] & FB_DIRECTORY == 0
    end

    def dir?
      de['flags'] & FB_DIRECTORY == FB_DIRECTORY
    end

    def joliet?
      (flags & EXT_JOLIET) == EXT_JOLIET
    end

    def rock_ridge?
      (flags & EXT_ROCKRIDGE) == EXT_ROCKRIDGE
    end

    def even?
      name_len & 1 == 0 && !joliet? # Cheap test for even/odd.
    end

    def initialize(data, suffix, fs, flags = EXT_NONE)
      raise "data is nil" if data.nil?
      self.data   = data
      self.suffix = suffix
      self.fs     = fs
      self.flags  = flags

      #process_rock_ridge if rock_ridge?
    end

    def file_size
      @rr.nil? ? de["size#{suffix}"] : rock_ridge_file_size
    end

    alias :size :file_size

    def rock_ridge_file_size
      size = rock_ridge_ext("linkData")
      size.nil? ? de["size#{suffix}"] : size.size
    end

    def symlink?
      @rr.nil? ? false : has_rock_ridge_extension?("linkData")
    end

    def has_rock_ridge_extension?(ext)
      !rock_ridge_ext(ext).nil?
    end

    def rock_ridge_ext(sym)
      return nil if @rr.nil?
      res = nil
      @rr.extensions.each do |extension|
        ext = extension.ext
        begin
          res = ext.send(sym)
        rescue
          break unless res.nil?
        end
      end
      res
    end

    def process_rock_ridge
      return if length == 0
      @rr = RockRidgeAdapter.new(self, suffix)

      # Check for alternate name.
      @name = rock_ridge_ext("name") if has_rock_ridge_ext?("name")
    end
  end # class DirectoryEntry
end # module VirtFS::ISO9660
