
require "algorithms"

class MobME::Infrastructure::Queue::Backends::Memory < MobME::Infrastructure::Queue::Backend
  attr_accessor :scores

  # Initialises the Queue
  # @param [Hash] options all options to pass to the queue
  def initialize(options = {})
    @@queues ||= {}
  end

  def queues
    @@queues
  end

  def add(queue, item, metadata = {})
    metadata = normalize_metadata(metadata)
    score = score_from_metadata(metadata['dequeue-timestamp'], metadata['priority'])
    
    queues[queue] ||= Containers::CRBTreeMap.new
    queues[queue][score] = serialize_item(item, metadata)
  end
  
  # Adds many items together
  def add_bulk(queue, items = [])
    items.each do |item|
      add(queue, item)
    end
  end
  
  def remove(queue, &block)
    score = queues[queue].min_key
    
    item = item_with_score(queue, score)
    
    #If a block is given
    if block_given?
      begin
        block.call(item)
      rescue MobME::Infrastructure::Queue::RemoveAbort
        return
      end
      queues[queue].delete(score) if item
    else
      queues[queue].delete(score) if item
      return item
    end
  end
  
  def peek(queue)
    score = queues[queue].min_key
    
    item_with_score(queue, score)
  end
  
  def list(queue)
    queues[queue].inject([]) { |collect, step| collect << item_with_score(queue, step[0]) }
  end
  
  def empty(queue)
    queues[queue] = nil
    queues[queue] = Containers::CRBTreeMap.new
    
    true
  end
  
  def size(queue)
    queues[queue].size
  end
  
  def remove_queues(*queues_to_delete)
    queues_to_delete = list_queues if queues_to_delete.empty?
    queues_to_delete.each do |queue|
      queues.delete(queue)
    end
  end
  alias :remove_queue :remove_queues
  
  def list_queues
    queues.keys
  end
  
  private
  def item_with_score(queue, score)
    item = if not score
      nil
    elsif score > (Time.now.to_f * 1000000).to_i # We don't return future items!
      nil
    else
      value = queues[queue][score]
      unserialize_item(value)
    end
  end
end
