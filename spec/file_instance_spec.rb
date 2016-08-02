require 'spec_helper'

describe "VirtFS::ISO9660::File instance methods" do
  before(:all) do
    reset_context

    @root      = File::SEPARATOR
    @iso       = build(:iso)
    @full_path = @iso.glob_dir.first
    VirtFS.mount(@iso.fs, @root)
  end

  after(:all) do
    VirtFS.umount(@root)
  end

  before(:each) do
    VirtFS::VDir.chdir(@root)
  end

  describe "#atime" do
    it "should return a Time object" do
      VirtFS::VFile.open(@full_path) { |vf| expect(vf.atime).to be_kind_of(Time) }
    end
  end

  describe "#chmod" do
    it "should raise error" do
      VirtFS::VFile.open(@full_path) do |vf|
        expect do
          vf.chmod(0755)
        end.to raise_error("writes not supported");
      end
    end
  end

  describe "#chmod" do
    it "should raise error" do
      VirtFS::VFile.open(@full_path) do |vf|
        expect do
          vf.chown(0, 0)
        end.to raise_error("writes not supported");
      end
    end
  end

  describe "#ctime" do
    it "should return a Time object" do
      VirtFS::VFile.open(@full_path) { |vf| expect(vf.ctime).to be_kind_of(Time) }
    end
  end

  #describe "#flock" do
  #  it "should return 0" do
  #    VirtFS::VFile.open(@full_path) do |vf|
  #      expect(vf.flock(File::LOCK_EX)).to eq(0)
  #    end
  #  end
  #end

  #describe "#lstat" do
  #  it "should return the stat information for the symlink" do
  #    VirtFS::VFile.open(@slink_path) do |sl|
  #      expect(sl.lstat.symlink?).to be true
  #    end
  #  end
  #end

  describe "#mtime" do
    it "should return a Time object" do
      VirtFS::VFile.open(@full_path) { |vf| expect(vf.mtime).to be_kind_of(Time) }
    end
  end

  describe "#path :to_path" do
    it "should return full path when opened with full path" do
      VirtFS::VFile.open(@full_path) { |f| expect(f.path).to eq(@full_path) }
    end

    it "should return relative path when opened with relative path" do
      parent, target_file = VfsRealFile.split(@full_path)
      VirtFS::VDir.chdir(parent)
      VirtFS::VFile.open(target_file) { |f| expect(f.path).to eq(target_file) }
    end
  end

  describe "#size" do
    it "should return the known size of the file" do
      VirtFS::VFile.open(@full_path) { |f| expect(f.size).to eq(@iso.boot_size) }
    end
  end

  describe "#truncate" do
    it "should raise error" do
      expect do
        VirtFS::VFile.open(@full_path, "w") { |f| f.truncate(5) }
      end.to raise_error("writes not supported");
    end
  end
end
