module VirtFS::ISO9660
  # SUSP extensions are present if the first two characters of the SUA of
  # the first directory entry are "SP". After SUSP is identified, if the
  # first two characters of any directory entry's SUA are "RR" a Rock Ridge
  # extension is active for that entry. The particular extension is
  # identified by the two characters after the next two bytes following "RR".

  # NOTE: This implementation is sufficient for Rock Ridge extensions. It will
  # not identify or process any other System Use Sharing Protocol extensions.
  # In particular, SUSP CE (continuation area) records are not processed.

  class PosixAttributes
    attr_reader :flags

    def initialize(data, suff)
      @flags = 0
      @suff = suff
      @px = RR_PX.decode(data)
    end

    def mode
      @px["mode#{@suff}"]
    end

    def nlinks
      @px["links#{@suff}"]
    end

    def user
      @px["user#{@suff}"]
    end

    def group
      @px["group#{@suff}"]
    end

    def isFile?
      mode & RR_EXT_SL_FM_FILE != 0
    end

    def isDir?
      mode & RR_EXT_SL_FM_DIR != 0
    end

    def isSymLink?
      mode & RR_EXT_SL_FM_LINK != 0
    end
  end # class PosixAttributes

  class SymbolicLink
    attr_reader :flags
    attr_accessor :linkData

    def initialize(data, _suff)
      sl = RR_SL.decode(data)

      # Reader data.
      @flags = sl['flags']
      @linkData = assembleComponents(sl['components'])
    end

    def assembleComponents(data)
      out = ""; offset = 0
      loop do
        comp = RR_SL_COMPONENT.decode(data[offset..-1])

        # Check for referential flags.
        out += "./" if comp['flags'] & RR_EXT_SLCOMPF_CURRENT != 0
        out += "../" if comp['flags'] & RR_EXT_SLCOMPF_PARENT != 0
        out += "/" if comp['flags'] & RR_EXT_SLCOMPF_ROOT != 0

        # Advance offset, append content (if any) & check for done.
        # puts "Component content:"
        # comp['content'][0, comp['length']].hex_dump(:obj => STDOUT, :meth => :puts, :newline => false)
        # puts "\n\n"
        offset += comp['length'] + 2 # compensate for first two bytes of component.
        next if comp['length'] == 0
        out = File.join(out, comp['content'][0, comp['length']])
        # break if comp['flags'] & RR_EXT_SLCOMPF_CONTINUE == 0
        # Analysis of real data shows the condition is offset >= data len.
        break if offset >= data.length
      end
      # puts "Total content:"
      # out.hex_dump(:obj => STDOUT, :meth => :puts, :newline => false)
      # puts "\n\n"
      out
    end
  end # class SymbolicLink

  class AlternateName
    attr_reader :flags
    attr_accessor :name

    def initialize(data, _suff)
      an = RR_NM.decode(data)

      # Check for referential flags.
      @name = ""
      @name += "./" if an['flags'] & RR_EXT_NMF_CURRENT != 0
      @name += "../" if an['flags'] & RR_EXT_NMF_PARENT != 0
      raise "RR extension NM: RESERVED3 flag is set." if an['flags'] & RR_EXT_NMF_RESERVED3 != 0

      # Reader data.
      @flags = an['flags']
      @name += an['content']
    end
  end # class AlternateName

  # Sparse File.
  RR_SF_SIGNATURE = "SF"
  RR_SF = BinaryStruct.new([
    'L',  'size_hiLE',
    'L',  'size_hiBE',
    'L',  'size_loLE',
    'L',  'size_loBE',
    'C',  'table_depth',
  ])

  # Um, sparse file is pretty complicated so I'm just going to get the
  # first three going and then worry about this.

  class SparseFile
    attr_reader :length, :fileData, :flags

    def initialize(data, suff)
      @sf = RR_SF.decode(data)
      @flags = 0
      @suff = suff
      raise "Sparse file."
    end

    def length
      (@sf["size_hi#{@suff}"] << 32) + @sf["size_lo#{@suff}"]
    end
  end # class AlternateName

  class Extension
    attr_reader :length, :ext

    def initialize(data, suff)
      # Get extension header, length & data.
      @header = RR_EXT_HEADER.decode(data)
      @length = @header['length']
      data = data[RR_EXT_HEADER_SIZE, @length - RR_EXT_HEADER_SIZE]
      # puts "Extension data (from Extension):"
      # data.hex_dump(:obj => STDOUT, :meth => :puts, :newline => false)
      # puts "\n\n"

      # Delegate to extension.
      @ext = case @header['signature']
             when RR_PX_SIGNATURE then PosixAttributes.new(data, suff)
             when RR_PN_SIGNATURE then warnAbout(RR_PN_SIGNATURE, data)
             when RR_SL_SIGNATURE then SymbolicLink.new(data, suff)
             when RR_NM_SIGNATURE then AlternateName.new(data, suff)
             when RR_CL_SIGNATURE then warnAbout(RR_CL_SIGNATURE, data)
             when RR_PL_SIGNATURE then warnAbout(RR_PL_SIGNATURE, data)
             when RR_RE_SIGNATURE then warnAbout(RR_RE_SIGNATURE, data)
             when RR_TF_SIGNATURE then warnAbout(RR_TF_SIGNATURE, data)
             when RR_SF_SIGNATURE then SparseFile.new(data, suff)
             end
    end

    def warnAbout(ext, data)
      if $log
        $log.debug("RR extension #{ext} found, not processed. Data is:")
        data.hex_dump(:obj => $log, :meth => :debug, :newline => false)
      end
      nil
    end
  end # class Extension

  class RockRidgeAdapter
    SUSP_SIZE = 7
    CONTINUE  = 1

    attr_reader :extensions

    def initialize(de, suff)
      raise "No DirectoryEntry specified." if de.nil?
      raise "The specified DirectoryEntry has no System Use Area." if de.sua.nil?

      # Root directories need to skip SUSP header.
      offset = de.name == "." ? SUSP_SIZE : 0

      # Get the RR header from the DirectoryEntry & verify.
      @header = RR_HEADER.decode(de.sua[offset..-1])
      raise "This is not a Rock Ridge extension record" if @header['signature'] != RR_SIGNATURE

      # Loop through extensions.
      offset += RR_HEADER_SIZE
      @extensions = []
      loop do
        # puts "Extension data:
        # de.sua[offset..-1].hex_dump(:obj => STDOUT, :meth => :puts, :newline => false)
        # puts "\n\n"
        ext = Extension.new(de.sua[offset..-1], suff)
        @extensions << ext
        offset += ext.length
        break if offset >= de.sua.length
      end

      # Handle continuations.
      0.upto(@extensions.size - 1) do |idx|
        obj = @extensions[idx]
        next if obj.nil?

        # TODO: Simplify this - the meat of all extensions is .data
        if obj.flags & CONTINUE
          if obj.kind_of?(AlternateName)
            obj.name += @extensions[idx + 1].name
            @extensions[idx + 1] = nil
          end
          if obj.kind_of?(SymbolicLink)
            obj.linkData += @extensions[idx + 1].linkData
            @extensions[idx + 1] = nil
          end
        end
      end
      @extensions.delete(nil)
    end
  end # class RockRidge
end # module VirtFS::ISO9660
