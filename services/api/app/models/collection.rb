class Collection < ArvadosModel
  include AssignUuid
  include KindAndEtag
  include CommonApiTemplate

  api_accessible :user, extend: :common do |t|
    t.add :data_size
    t.add :files
  end

  def redundancy_status
    if redundancy_confirmed_as.nil?
      'unconfirmed'
    elsif redundancy_confirmed_as < redundancy
      'degraded'
    else
      if redundancy_confirmed_at.nil?
        'unconfirmed'
      elsif Time.now - redundancy_confirmed_at < 7.days
        'OK'
      else
        'stale'
      end
    end
  end

  def assign_uuid
    if self.manifest_text.nil? and self.uuid.nil?
      super
    elsif self.manifest_text and self.uuid
      if self.uuid.gsub(/\+[^,]+/,'') == Digest::MD5.hexdigest(self.manifest_text)
        true
      else
        errors.add :uuid, 'uuid does not match checksum of manifest_text'
        false
      end
    elsif self.manifest_text
      errors.add :uuid, 'checksum for manifest_text not supplied in uuid'
      false
    else
      errors.add :manifest_text, 'manifest_text not supplied'
      false
    end
  end

  def data_size
    inspect_manifest_text if @data_size.nil? or manifest_text_changed?
    @data_size
  end

  def files
    inspect_manifest_text if @files.nil? or manifest_text_changed?
    @files
  end

  def inspect_manifest_text
    if !manifest_text
      @data_size = false
      @files = []
      return
    end
    @data_size = 0
    @files = []
    manifest_text.split("\n").each do |stream|
      toks = stream.split(" ")
      toks[1..-1].each do |tok|
        if (re = tok.match /^[0-9a-f]{32}/)
          blocksize = nil
          tok.split('+')[1..-1].each do |hint|
            if !blocksize and hint.match /^\d+$/
              blocksize = hint.to_i
            end
            if (re = hint.match /^GS(\d+)$/)
              blocksize = re[1].to_i
            end
          end
          @data_size = false if !blocksize
          @data_size += blocksize if @data_size
        else
          if (re = tok.match /^(\d+):(\d+):(\S+)$/)
            @files << [toks[0], re[3], re[2].to_i]
          end
        end
      end
    end
  end
end
