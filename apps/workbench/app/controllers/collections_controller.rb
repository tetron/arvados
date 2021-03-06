class CollectionsController < ApplicationController
  skip_before_filter :find_object_by_uuid, :only => [:graph]

  def graph
    index
  end

  def index
    @collections = Collection.limit(100).to_hash
    @links = Link.eager.limit(100).where(head_kind: 'arvados#collection', link_class: 'resources', name: 'wants') |
      Link.eager.limit(100).where(tail_kind: 'arvados#collection', link_class: 'data_origin')
    @collections.merge!(Collection.
                        limit(100).
                        where(uuid: @links.select{|x|x.head_kind=='arvados#collection'}.collect(&:head_uuid) |
                              @links.select{|x|x.tail_kind=='arvados#collection'}.collect(&:tail_uuid)).
                        to_hash)
    @collection_info = {}
    @collections.each do |uuid, c|
      ci = (@collection_info[uuid] ||= {uuid: uuid})
      ci[:created_at] = c.created_at
    end
    @links.each do |l|
      if l.head_kind == 'arvados#collection'
        c = (@collection_info[l.head_uuid] ||= {uuid: l.head_uuid})
        if l.link_class == 'resources' and l.name == 'wants'
          if l.head.respond_to? :created_at
            c[:created_at] = l.head.created_at
          end
          c[:wanted] = true
          if l.owner_uuid == current_user.uuid
            c[:wanted_by_me] = true
          end
        end
      end
      if l.tail_kind == 'arvados#collection'
        c = (@collection_info[l.tail_uuid] ||= {uuid: l.tail_uuid})
        if l.link_class == 'data_origin'
          c[:origin] = l
        end
      end
    end
  end

  def show
    return super if !@object
    @provenance = []
    @output2job = {}
    @output2colorindex = {}
    @sourcedata = {params[:uuid] => {uuid: params[:uuid]}}
    @protected = {}

    colorindex = -1
    any_hope_left = true
    while any_hope_left
      any_hope_left = false
      Job.where(output: @sourcedata.keys).sort_by { |a| a.finished_at || a.created_at }.reverse.each do |job|
        if !@output2colorindex[job.output]
          any_hope_left = true
          @output2colorindex[job.output] = (colorindex += 1) % 10
          @provenance << {job: job, output: job.output}
          @sourcedata.delete job.output
          @output2job[job.output] = job
          job.dependencies.each do |new_source_data|
            unless @output2colorindex[new_source_data]
              @sourcedata[new_source_data] = {uuid: new_source_data}
            end
          end
        end
      end
    end

    Link.where(head_uuid: @sourcedata.keys | @output2job.keys).each do |link|
      if link.link_class == 'resources' and link.name == 'wants'
        @protected[link.head_uuid] = true
      end
    end
    Link.where(tail_uuid: @sourcedata.keys).each do |link|
      if link.link_class == 'data_origin'
        @sourcedata[link.tail_uuid][:data_origins] ||= []
        @sourcedata[link.tail_uuid][:data_origins] << [link.name, link.head_kind, link.head_uuid]
      end
    end
    Collection.where(uuid: @sourcedata.keys).each do |collection|
      if @sourcedata[collection.uuid]
        @sourcedata[collection.uuid][:collection] = collection
      end
    end
  end
end
