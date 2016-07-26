require 'spec_helper'

#
# Class methods.
#
describe "CamcorderFS::File class methods" do
  before(:all) do
    reset_context

    @root = File::SEPARATOR
    @iso  = build(:iso)
    VirtFS.mount(@iso.fs, @root)

    @full_path   = '/IMAGES/EFIBOOT.IMG;1'
    @parent_path = '/IMAGES'
    @rel_path    = 'EFIBOOT.IMG;1'
    @ext         = ".IMG;1"
    @file1_size  = 6467584
    @time        = Time.now
  end

  after(:all) do
    VirtFS.umount(@root)
  end

  describe ".atime" do
    it "should raise Errno::ENOENT when given a nonexistent file" do
      expect do
        VirtFS::VFile.atime("nonexistent_file")
      end.to raise_error(/No such file or directory/)
    end

    it "should return a Time object, when given full path" do
      expect(VirtFS::VFile.atime('/')).to be_kind_of(Time)
    end

    it "should return a Time object, when given relative path" do
      VirtFS.dir_chdir(@parent_path)
      expect(VirtFS::VFile.atime(@rel_path)).to be_kind_of(Time)
    end
  end

  describe ".basename" do
    it "should return the same value as the standard File.basename" do
      expect(VirtFS::VFile.basename(@full_path)).to eq(VfsRealFile.basename(@full_path))
    end
  end

  describe ".chmod" do
    it "should raise error" do
      expect do
        VirtFS::VFile.chmod(0755, "anything")
      end.to raise_error("writes not supported");
    end
  end

  describe ".chown" do
    it "should raise error" do
      expect do
        VirtFS::VFile.chown(1, 2, "anything")
      end.to raise_error("writes not supported");
    end
  end

  describe ".ctime" do
    it "should raise Errno::ENOENT when given a nonexistent file" do
      expect do
        VirtFS::VFile.ctime("nonexistent_file")
      end.to raise_error(
        Errno::ENOENT, /No such file or directory/
      )
    end

    it "should return a Time object, when given full path" do
      expect(VirtFS::VFile.ctime(@full_path)).to be_kind_of(Time)
    end

    it "should return a Time object, when given relative path" do
      VirtFS.dir_chdir(@parent_path)
      expect(VirtFS::VFile.ctime(@rel_path)).to be_kind_of(Time)
    end
  end

  describe ".delete" do
    it "should raise error" do
      expect do
        VirtFS::VFile.delete("anything")
      end.to raise_error("writes not supported");
    end
  end

  describe ".directory?" do
    it "should return false when given a nonexistent directory" do
      expect(VirtFS::VFile.directory?("nonexistent_directory")).to be false
    end

    it "should return false when given a regular file" do
      expect(VirtFS::VFile.directory?(@full_path)).to be false
    end

    it "should return true when given a directory" do
      expect(VirtFS::VFile.directory?(@parent_path)).to be true
    end
  end

  describe ".exist?" do
    it "should return false when given a nonexistent file" do
      expect(VirtFS::VFile.exist?("nonexistent_directory")).to be false
    end

    it "should return true when given a regular file" do
      expect(VirtFS::VFile.exist?(@full_path)).to be true
    end

    it "should return true when given a directory" do
      expect(VirtFS::VFile.exist?(@parent_path)).to be true
    end
  end

  describe ".expand_path" do
    it "should return the same path as the standard File.expand_path, when given a dirstring" do
      expect(VirtFS::VFile.expand_path(@rel_path, @parent_path)).to eq(VfsRealFile.expand_path(@rel_path, @parent_path))
    end

    it "should return the same path as the standard File.expand_path, when using pwd" do
      VirtFS.dir_chdir(@parent_path) do
        VirtFS.cwd = VfsRealDir.getwd
        expect(VirtFS::VFile.expand_path(@rel_path)).to eq(VfsRealFile.expand_path(@rel_path))
      end
    end
  end

  describe ".extname" do
    it "should return the known extension of tempfile 1" do
      expect(VirtFS::VFile.extname(@full_path)).to eq(@ext)
    end
  end

  describe ".file?" do
    it "should return false when given a nonexistent file" do
      expect(VirtFS::VFile.file?("nonexistent_directory")).to be false
    end

    it "should return true when given a regular file" do
      expect(VirtFS::VFile.file?(@full_path)).to be true
    end

    it "should return false when given a directory" do
      expect(VirtFS::VFile.file?(@parent_path)).to be false
    end
  end

  describe ".fnmatch" do
    it "should match representative examples" do
      expect(VirtFS::VFile.fnmatch('cat', 'cat')).to                               be true
      expect(VirtFS::VFile.fnmatch('cat', 'category')).to                          be false
      expect(VirtFS::VFile.fnmatch('c?t', 'cat')).to                               be true
      expect(VirtFS::VFile.fnmatch('c\?t', 'cat')).to                              be false
      expect(VirtFS::VFile.fnmatch('c??t', 'cat')).to                              be false
      expect(VirtFS::VFile.fnmatch('c*', 'cats')).to                               be true
      expect(VirtFS::VFile.fnmatch('c/**/t', 'c/a/b/c/t')).to                      be true
      expect(VirtFS::VFile.fnmatch('c**t', 'c/a/b/c/t')).to                        be true
      expect(VirtFS::VFile.fnmatch('c**t', 'cat')).to                              be true
      expect(VirtFS::VFile.fnmatch('**.txt', 'notes.txt')).to                      be true
      expect(VirtFS::VFile.fnmatch('**.txt', 'some/dir/tree/notes.txt')).to        be true
      expect(VirtFS::VFile.fnmatch('c*t', 'cat')).to                               be true
      expect(VirtFS::VFile.fnmatch('c\at', 'cat')).to                              be true
      expect(VirtFS::VFile.fnmatch('c\at', 'cat', File::FNM_NOESCAPE)).to          be false
      expect(VirtFS::VFile.fnmatch('a?b', 'a/b')).to                               be true
      expect(VirtFS::VFile.fnmatch('a?b', 'a/b', File::FNM_PATHNAME)).to           be false
      expect(VirtFS::VFile.fnmatch('*', '.profile')).to                            be false
      expect(VirtFS::VFile.fnmatch('*', '.profile', File::FNM_DOTMATCH)).to        be true
      expect(VirtFS::VFile.fnmatch('*', 'dave/.profile')).to                       be true
      expect(VirtFS::VFile.fnmatch('*', 'dave/.profile', File::FNM_DOTMATCH)).to   be true
      expect(VirtFS::VFile.fnmatch('*', 'dave/.profile', File::FNM_PATHNAME)).to   be false
      expect(VirtFS::VFile.fnmatch('*/*', 'dave/.profile', File::FNM_PATHNAME)).to be false
      strict = File::FNM_PATHNAME | File::FNM_DOTMATCH
      expect(VirtFS::VFile.fnmatch('*/*', 'dave/.profile', strict)).to             be true
    end
  end

  describe ".lchmod" do
    it "should raise error" do
      expect do
        VirtFS::VFile.lchmod("any", "thing")
      end.to raise_error("writes not supported");
    end
  end

  describe ".lchown" do
    it "should raise error" do
      expect do
        VirtFS::VFile.lchmod("any", "thing")
      end.to raise_error("writes not supported");
    end
  end

  describe ".link" do
    it "should raise error" do
      expect do
        VirtFS::VFile.lchmod('any', 'thing')
      end.to raise_error("writes not supported");
    end
  end

  describe ".lstat" do
    it "should raise Errno::ENOENT when given a nonexistent file" do
      expect do
        VirtFS::VFile.lstat("nonexistent_file1")
      end.to raise_error(/No such file or directory/)
    end

    #it "should return the stat information for the symlink" do
    #  expect(VirtFS::VFile.lstat(@slink_path).symlink?).to be true
    #end
  end

  describe ".mtime" do
    it "should raise Errno::ENOENT when given a nonexistent file" do
      expect do
        VirtFS::VFile.mtime("nonexistent_file")
      end.to raise_error(
        Errno::ENOENT, /No such file or directory/
      )
    end

    it "should return a Time object, when given full path" do
      expect(VirtFS::VFile.mtime(@full_path)).to be_kind_of(Time)
    end

    it "should return a Time object, when given relative path" do
      VirtFS.dir_chdir(@parent_path)
      expect(VirtFS::VFile.mtime(@rel_path)).to be_kind_of(Time)
    end
  end

  describe ".rename" do
  end

  describe ".size" do
    it "should raise Errno::ENOENT when given a nonexistent file" do
      expect do
        VirtFS::VFile.size("nonexistent_file")
      end.to raise_error(
        Errno::ENOENT, /No such file or directory/
      )
    end

    it "should return the known size of the file" do
      expect(VirtFS::VFile.size(@full_path)).to eq(@file1_size)
    end

    #it "should return 0 for empty file" do
    #  expect(VirtFS::VFile.size('something')).to eq(0)
    #end
  end

  describe ".symlink" do
  end

  describe ".symlink?" do
  end

  describe ".world_writable?" do
    it "should return false" do
      expect(VirtFS::VFile.world_writable?("anything")).to be false
    end
  end

  describe ".writable?" do
    it "should return false" do
      expect(VirtFS::VFile.writable?("anything")).to be false
    end
  end

  describe ".writable_real?" do
    it "should return false" do
      expect(VirtFS::VFile.writable_real?("anything")).to be false
    end
  end

  describe ".zero?" do
    it "should return false when given a nonexistent file" do
      expect(VirtFS::VFile.zero?("nonexistent_file")).to be false
    end

    it "should return false when given a non-zero length file" do
      expect(VirtFS::VFile.zero?(@full_path)).to be false
    end

    #it "should return true when given a zero length file" do
    #  expect(VirtFS::VFile.zero?(@full_path2)).to be true
    #end
  end

  describe ".new" do
    it "should raise Errno::ENOENT when the file doesn't exist" do
      expect do
        VirtFS::VFile.new("not_a_file")
      end.to raise_error(
        Errno::ENOENT, /No such file or directory/
      )
    end

    it "should return a File object - given full path" do
      expect(VirtFS::VFile.new(@full_path)).to be_kind_of(VirtFS::VFile)
    end

    it "should return a directory object - given relative path" do
      VirtFS::VDir.chdir(@parent_path)
      expect(VirtFS::VFile.new(@rel_path)).to be_kind_of(VirtFS::VFile)
    end
  end

  describe ".open" do
    it "should raise Errno::ENOENT when file doesn't exist" do
      expect do
        VirtFS::VFile.new("not_a_file")
      end.to raise_error(
        Errno::ENOENT, /No such file or directory/
      )
    end

    it "should return a File object - when no block given" do
      expect(VirtFS::VFile.open(@full_path)).to be_kind_of(VirtFS::VFile)
    end

    it "should yield a file object to the block - when block given" do
      VirtFS::VFile.open(@full_path) { |file_obj| expect(file_obj).to be_kind_of(VirtFS::VFile) }
    end

    it "should return the value of the block - when block given" do
      expect(VirtFS::VFile.open(@full_path) { true }).to be true
    end
  end
end
