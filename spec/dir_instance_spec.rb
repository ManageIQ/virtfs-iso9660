require 'spec_helper'

describe "VirtFS::ISO9660::Dir instance methods" do
  before(:all) do
    reset_context

    @root = File::SEPARATOR
    @iso  = build(:iso)
    VirtFS.mount(@iso.fs, @root)
  end

  describe "#close" do
    it "should return nil" do
      dir = VirtFS::VDir.new(@root)
      expect(dir.close).to be_nil
    end

    it "should cause subsequent access to raise IOError: closed directory" do
      dir = VirtFS::VDir.new(@root)
      dir.close

      expect { dir.close     }.to raise_error(IOError, "closed directory")
      expect { dir.each.to_a }.to raise_error(IOError, "closed directory")
      expect { dir.pos = 0   }.to raise_error(IOError, "closed directory")
      expect { dir.read      }.to raise_error(IOError, "closed directory")
      expect { dir.rewind    }.to raise_error(IOError, "closed directory")
      expect { dir.seek(0)   }.to raise_error(IOError, "closed directory")
      expect { dir.tell      }.to raise_error(IOError, "closed directory")
    end
  end

  describe "#each" do
    it "should return an enum when no block is given" do
      VirtFS::VDir.open(@root) { |dir| expect(dir.each).to be_kind_of(Enumerator) }
    end

    it "should return the directory object when block is given" do
      VirtFS::VDir.open(@root) do |dir|
        expect(dir.each { true }).to eq(dir)
      end
    end

    it "should enumerate the same files as the standard Dir method" do
      VirtFS::VDir.open(@root) do |dir|
        expect(dir.each.to_a.collect { |de| de.name }).to match_array(@iso.root_dir + [".", ".."])
      end
    end
  end
end
